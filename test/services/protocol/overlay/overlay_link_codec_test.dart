// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Byte-accurate tests for the MRRP v0.2 link-frame codec.
///
/// Includes golden vectors for each link `msg_type`, roundtrip checks
/// at boundary payload sizes, and negative tests covering every
/// [OverlayLinkDecodeError]. Vectors here are authoritative per
/// `docs/sip/OVERLAY_V0_2.md` §10.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_constants.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_codec.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

OverlayLinkFrame _linkOpen({int linkId = 0xCAFEBABE}) => OverlayLinkFrame(
  msgType: OverlayLinkMsgType.linkOpen,
  flags: OverlayLinkFlags.linkFrame | OverlayLinkFlags.ackRequired,
  requestId: 0x11223344,
  serviceId: 0,
  actionId: 0,
  payloadLen: 0,
  linkId: linkId,
  seq: 0,
  ackHi: 0,
  payload: Uint8List(0),
);

void main() {
  group('OverlayLinkCodec golden vectors', () {
    test('LINK_OPEN empty payload → 28 byte frame', () {
      final frame = _linkOpen();
      final bytes = OverlayLinkCodec.encode(frame)!;
      expect(bytes.length, 28);
      // Header bytes are deterministic.
      expect(
        bytes,
        equals(
          Uint8List.fromList(<int>[
            0x4D, 0x52, // magic 'MR'
            0x00, 0x02, // version 0.2
            0x20, // msg_type linkOpen
            0x03, // flags: linkFrame | ackRequired
            0x1C, 0x00, // header_len 28
            0x44, 0x33, 0x22, 0x11, // request_id 0x11223344 LE
            0x00, 0x00, 0x00, 0x00, // service_id 0
            0x00, 0x00, // action_id 0
            0x00, 0x00, // payload_len 0
            0xBE, 0xBA, 0xFE, 0xCA, // link_id 0xCAFEBABE LE
            0x00, 0x00, // seq 0
            0x00, 0x00, // ack_hi 0
          ]),
        ),
      );
    });

    test('LINK_DATA with 8 byte payload', () {
      final payload = Uint8List.fromList(List<int>.generate(8, (i) => i + 1));
      final frame = OverlayLinkFrame(
        msgType: OverlayLinkMsgType.linkData,
        flags: OverlayLinkFlags.linkFrame,
        requestId: 0,
        serviceId: 0x0000FFFF,
        actionId: 0x0042,
        payloadLen: payload.length,
        linkId: 0x11111111,
        seq: 0x0005,
        ackHi: 0x0004,
        payload: payload,
      );
      final bytes = OverlayLinkCodec.encode(frame)!;
      expect(bytes.length, 28 + 8);
      // Expected header bytes:
      expect(
        bytes.sublist(0, 28),
        equals(
          Uint8List.fromList(<int>[
            0x4D, 0x52,
            0x00, 0x02,
            0x26, // linkData
            0x01, // flags: linkFrame only
            0x1C, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0xFF, 0xFF, 0x00, 0x00,
            0x42, 0x00,
            0x08, 0x00,
            0x11, 0x11, 0x11, 0x11,
            0x05, 0x00,
            0x04, 0x00,
          ]),
        ),
      );
      expect(bytes.sublist(28), equals(payload));
    });

    test('LINK_CLOSE with reason byte payload', () {
      final payload = Uint8List.fromList(<int>[
        OverlayLinkCloseReason.normal.code,
      ]);
      final frame = OverlayLinkFrame(
        msgType: OverlayLinkMsgType.linkClose,
        flags: OverlayLinkFlags.linkFrame,
        requestId: 0,
        serviceId: 0,
        actionId: 0,
        payloadLen: 1,
        linkId: 0xDEADBEEF,
        seq: 42,
        ackHi: 41,
        payload: payload,
      );
      final bytes = OverlayLinkCodec.encode(frame)!;
      expect(bytes.length, 29);
      expect(bytes[4], 0x25); // linkClose
      expect(bytes[28], 0x00); // normal close reason
    });
  });

  group('OverlayLinkCodec roundtrips', () {
    test('roundtrip LINK_OPEN', () {
      final original = _linkOpen();
      final bytes = OverlayLinkCodec.encode(original)!;
      final result = OverlayLinkCodec.decode(bytes);
      expect(result.isOk, isTrue);
      final decoded = result.frame!;
      expect(decoded.msgType, OverlayLinkMsgType.linkOpen);
      expect(decoded.linkId, 0xCAFEBABE);
      expect(decoded.requestId, 0x11223344);
      expect(decoded.payload.length, 0);
    });

    test('roundtrip LINK_DATA at maximum unsigned payload (187 B)', () {
      final payload = Uint8List.fromList(
        List<int>.generate(
          OverlayLinkConstants.payloadCeilUnsigned,
          (i) => i & 0xFF,
        ),
      );
      final frame = OverlayLinkFrame(
        msgType: OverlayLinkMsgType.linkData,
        flags: OverlayLinkFlags.linkFrame,
        requestId: 0,
        serviceId: 0,
        actionId: 0,
        payloadLen: payload.length,
        linkId: 1,
        seq: 1,
        ackHi: 0,
        payload: payload,
      );
      final bytes = OverlayLinkCodec.encode(frame)!;
      expect(bytes.length, OverlayLinkConstants.headerLen + payload.length);
      final result = OverlayLinkCodec.decode(bytes);
      expect(result.isOk, isTrue);
      expect(result.frame!.payload, equals(payload));
    });

    test('roundtrip all 8 v0.2 msg types with empty payloads', () {
      for (final type in OverlayLinkMsgType.values) {
        final frame = OverlayLinkFrame(
          msgType: type,
          flags: OverlayLinkFlags.linkFrame,
          requestId: type.code,
          serviceId: 0,
          actionId: 0,
          payloadLen: 0,
          linkId: 0xABCDEF01,
          seq: 7,
          ackHi: 6,
          payload: Uint8List(0),
        );
        final bytes = OverlayLinkCodec.encode(frame)!;
        final result = OverlayLinkCodec.decode(bytes);
        expect(result.isOk, isTrue, reason: 'type=${type.name}');
        expect(result.frame!.msgType, type);
        expect(result.frame!.seq, 7);
        expect(result.frame!.ackHi, 6);
      }
    });
  });

  group('OverlayLinkCodec.isLinkFrame sniffer', () {
    test('accepts a well-formed frame', () {
      final bytes = OverlayLinkCodec.encode(_linkOpen())!;
      expect(OverlayLinkCodec.isLinkFrame(bytes), isTrue);
    });

    test('rejects short input', () {
      expect(
        OverlayLinkCodec.isLinkFrame(Uint8List.fromList([0x4D, 0x52])),
        isFalse,
      );
    });

    test('rejects MRRP v0.1 frames (version minor != 2)', () {
      final v01 = Uint8List(28);
      v01[0] = 0x4D;
      v01[1] = 0x52;
      v01[2] = 0x00;
      v01[3] = 0x01; // v0.1
      v01[4] = 0x20;
      v01[5] = OverlayLinkFlags.linkFrame;
      expect(OverlayLinkCodec.isLinkFrame(v01), isFalse);
    });

    test('rejects unknown msg_type (e.g. 0x99)', () {
      final bytes = OverlayLinkCodec.encode(_linkOpen())!;
      bytes[4] = 0x99;
      expect(OverlayLinkCodec.isLinkFrame(bytes), isFalse);
    });

    test('rejects frame without linkFrame flag set', () {
      final bytes = OverlayLinkCodec.encode(_linkOpen())!;
      bytes[5] = 0x00; // clear flags
      expect(OverlayLinkCodec.isLinkFrame(bytes), isFalse);
    });
  });

  group('OverlayLinkCodec decode negatives', () {
    test('short buffer → DecodeError.short', () {
      final result = OverlayLinkCodec.decode(Uint8List(10));
      expect(result.error, OverlayLinkDecodeError.short);
    });

    test('bad magic → DecodeError.badMagic', () {
      final bytes = OverlayLinkCodec.encode(_linkOpen())!;
      bytes[0] = 0x00;
      final result = OverlayLinkCodec.decode(bytes);
      expect(result.error, OverlayLinkDecodeError.badMagic);
    });

    test('bad version → DecodeError.badVersion', () {
      final bytes = OverlayLinkCodec.encode(_linkOpen())!;
      bytes[3] = 0x01;
      final result = OverlayLinkCodec.decode(bytes);
      expect(result.error, OverlayLinkDecodeError.badVersion);
    });

    test('unknown msg_type → DecodeError.badMsgType', () {
      final bytes = OverlayLinkCodec.encode(_linkOpen())!;
      bytes[4] = 0x99;
      final result = OverlayLinkCodec.decode(bytes);
      expect(result.error, OverlayLinkDecodeError.badMsgType);
    });

    test('reserved flag bits set → DecodeError.badFlags', () {
      final bytes = OverlayLinkCodec.encode(_linkOpen())!;
      bytes[5] = OverlayLinkFlags.linkFrame | 0x80;
      final result = OverlayLinkCodec.decode(bytes);
      expect(result.error, OverlayLinkDecodeError.badFlags);
    });

    test('linkFrame bit clear → DecodeError.badFlags', () {
      final bytes = OverlayLinkCodec.encode(_linkOpen())!;
      bytes[5] = 0x00;
      final result = OverlayLinkCodec.decode(bytes);
      expect(result.error, OverlayLinkDecodeError.badFlags);
    });

    test('bad header_len → DecodeError.badHeaderLen', () {
      final bytes = OverlayLinkCodec.encode(_linkOpen())!;
      bytes[6] = 0x14; // 20 - v0.1 header len
      bytes[7] = 0x00;
      final result = OverlayLinkCodec.decode(bytes);
      expect(result.error, OverlayLinkDecodeError.badHeaderLen);
    });

    test(
      'payloadLen exceeding unsigned ceiling → DecodeError.badPayloadLen',
      () {
        final bytes = OverlayLinkCodec.encode(_linkOpen())!;
        bytes[18] = 0xFF;
        bytes[19] = 0xFF;
        final result = OverlayLinkCodec.decode(bytes);
        expect(result.error, OverlayLinkDecodeError.badPayloadLen);
      },
    );

    test('payloadLen exceeds buffer → DecodeError.badPayloadLen', () {
      final bytes = OverlayLinkCodec.encode(_linkOpen())!;
      bytes[18] = 10; // claim 10 bytes of payload
      bytes[19] = 0;
      // buffer still only 28 long
      final result = OverlayLinkCodec.decode(bytes);
      expect(result.error, OverlayLinkDecodeError.badPayloadLen);
    });
  });

  group('OverlayLinkCodec encode negatives', () {
    test('rejects oversized payload', () {
      final tooBig = Uint8List(OverlayLinkConstants.payloadCeilUnsigned + 1);
      final frame = OverlayLinkFrame(
        msgType: OverlayLinkMsgType.linkData,
        flags: OverlayLinkFlags.linkFrame,
        requestId: 0,
        serviceId: 0,
        actionId: 0,
        payloadLen: tooBig.length,
        linkId: 1,
        seq: 0,
        ackHi: 0,
        payload: tooBig,
      );
      expect(OverlayLinkCodec.encode(frame), isNull);
    });

    test('rejects header_len mismatch', () {
      final frame = OverlayLinkFrame(
        msgType: OverlayLinkMsgType.linkPing,
        flags: OverlayLinkFlags.linkFrame,
        headerLen: 20, // wrong
        requestId: 0,
        serviceId: 0,
        actionId: 0,
        payloadLen: 0,
        linkId: 0,
        seq: 0,
        ackHi: 0,
        payload: Uint8List(0),
      );
      expect(OverlayLinkCodec.encode(frame), isNull);
    });

    test('rejects payload.length / payloadLen mismatch', () {
      final frame = OverlayLinkFrame(
        msgType: OverlayLinkMsgType.linkPing,
        flags: OverlayLinkFlags.linkFrame,
        requestId: 0,
        serviceId: 0,
        actionId: 0,
        payloadLen: 4,
        linkId: 0,
        seq: 0,
        ackHi: 0,
        payload: Uint8List(0),
      );
      expect(OverlayLinkCodec.encode(frame), isNull);
    });

    test('rejects missing linkFrame flag', () {
      final frame = OverlayLinkFrame(
        msgType: OverlayLinkMsgType.linkPing,
        flags: 0,
        requestId: 0,
        serviceId: 0,
        actionId: 0,
        payloadLen: 0,
        linkId: 0,
        seq: 0,
        ackHi: 0,
        payload: Uint8List(0),
      );
      expect(OverlayLinkCodec.encode(frame), isNull);
    });

    test('rejects reserved flag bits', () {
      final frame = OverlayLinkFrame(
        msgType: OverlayLinkMsgType.linkPing,
        flags: OverlayLinkFlags.linkFrame | 0x80,
        requestId: 0,
        serviceId: 0,
        actionId: 0,
        payloadLen: 0,
        linkId: 0,
        seq: 0,
        ackHi: 0,
        payload: Uint8List(0),
      );
      expect(OverlayLinkCodec.encode(frame), isNull);
    });
  });
}
