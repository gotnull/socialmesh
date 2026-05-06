// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// D12 inbound parser tests. Canned firmware-shaped payloads, asserted
// against the upstream wire format documented in
// `MeshCore/examples/companion_radio/MyMesh.cpp`. Each case pins a
// specific defect that the pre-D12 widget code shipped with so a
// regression cannot silently revert.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/features/meshcore/parsers/meshcore_message_frame_parser.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';

/// Build a V3 channel-receive frame: [snr][rsv1][rsv2][chan][path][txt]
/// [ts:u32 LE][text].
Uint8List _v3ChannelPayload({
  required int snrQuarter,
  required int channelIndex,
  required int pathLen,
  required int txtType,
  required int timestamp,
  required String text,
}) {
  final body = BytesBuilder();
  body.addByte(snrQuarter & 0xFF);
  body.addByte(0); // reserved1
  body.addByte(0); // reserved2
  body.addByte(channelIndex);
  body.addByte(pathLen);
  body.addByte(txtType);
  final ts = ByteData(4)..setUint32(0, timestamp, Endian.little);
  body.add(ts.buffer.asUint8List());
  body.add(Uint8List.fromList(text.codeUnits));
  return body.toBytes();
}

/// Build a legacy channel-receive frame: [chan][path][txt][ts:u32 LE]
/// [text].
Uint8List _legacyChannelPayload({
  required int channelIndex,
  required int pathLen,
  required int txtType,
  required int timestamp,
  required String text,
}) {
  final body = BytesBuilder();
  body.addByte(channelIndex);
  body.addByte(pathLen);
  body.addByte(txtType);
  final ts = ByteData(4)..setUint32(0, timestamp, Endian.little);
  body.add(ts.buffer.asUint8List());
  body.add(Uint8List.fromList(text.codeUnits));
  return body.toBytes();
}

/// Build a V3 contact-receive frame: [snr][rsv1][rsv2][prefix:6][path]
/// [txt][ts:u32 LE][text].
Uint8List _v3ContactPayload({
  required int snrQuarter,
  required List<int> senderPrefix,
  required int pathLen,
  required int txtType,
  required int timestamp,
  required String text,
}) {
  assert(senderPrefix.length == 6, 'sender prefix must be 6 bytes');
  final body = BytesBuilder();
  body.addByte(snrQuarter & 0xFF);
  body.addByte(0);
  body.addByte(0);
  body.add(senderPrefix);
  body.addByte(pathLen);
  body.addByte(txtType);
  final ts = ByteData(4)..setUint32(0, timestamp, Endian.little);
  body.add(ts.buffer.asUint8List());
  body.add(Uint8List.fromList(text.codeUnits));
  return body.toBytes();
}

/// Build a legacy contact-receive frame: [prefix:6][path][txt][ts:u32
/// LE][text].
Uint8List _legacyContactPayload({
  required List<int> senderPrefix,
  required int pathLen,
  required int txtType,
  required int timestamp,
  required String text,
}) {
  assert(senderPrefix.length == 6, 'sender prefix must be 6 bytes');
  final body = BytesBuilder();
  body.add(senderPrefix);
  body.addByte(pathLen);
  body.addByte(txtType);
  final ts = ByteData(4)..setUint32(0, timestamp, Endian.little);
  body.add(ts.buffer.asUint8List());
  body.add(Uint8List.fromList(text.codeUnits));
  return body.toBytes();
}

void main() {
  group('parseChannelMessage: V3 (cmd 0x11)', () {
    test('parses a realistic V3 payload of length 10 + text', () {
      final payload = _v3ChannelPayload(
        snrQuarter: 36, // SNR = 9 dB
        channelIndex: 0,
        pathLen: 0xFF, // direct
        txtType: 0, // TXT_TYPE_PLAIN
        timestamp: 1_700_000_000,
        text: 'sim bridge test',
      );
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.channelMsgRecvV3,
        payload: payload,
      );
      final result = MeshCoreMessageFrameParser.parseChannelMessage(frame);
      expect(result.ok, isTrue, reason: result.rejectReason);
      final v = result.value!;
      expect(v.protocol, MeshCoreMessageProtocol.v3);
      expect(v.snrQuarter, 36);
      expect(v.channelIndex, 0);
      expect(v.pathLen, 0xFF);
      expect(v.txtType, 0);
      expect(v.timestamp.millisecondsSinceEpoch, 1_700_000_000 * 1000);
      expect(v.text, 'sim bridge test');
    });

    test('does NOT require >= 38 bytes (the pre-D12 bug)', () {
      // Minimum V3 channel payload with empty text is exactly 10 bytes.
      // Pre-D12 dropped this with `< 38` guard.
      final payload = _v3ChannelPayload(
        snrQuarter: 0,
        channelIndex: 1,
        pathLen: 0,
        txtType: 0,
        timestamp: 1,
        text: '',
      );
      expect(payload.length, 10);
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.channelMsgRecvV3,
        payload: payload,
      );
      final result = MeshCoreMessageFrameParser.parseChannelMessage(frame);
      expect(result.ok, isTrue);
      expect(result.value!.text, isEmpty);
    });

    test('reads channelIndex from offset 3, NOT offset 0 (SNR)', () {
      // High non-zero SNR ensures payload[0] != channelIndex by chance.
      final payload = _v3ChannelPayload(
        snrQuarter: 80, // SNR 20 dB. Would alias to chan 80 if buggy.
        channelIndex: 2,
        pathLen: 0,
        txtType: 0,
        timestamp: 0,
        text: 'x',
      );
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.channelMsgRecvV3,
        payload: payload,
      );
      final result = MeshCoreMessageFrameParser.parseChannelMessage(frame);
      expect(result.ok, isTrue);
      expect(result.value!.channelIndex, 2);
      expect(result.value!.snrQuarter, 80);
    });

    test('reads timestamp from offset 6 (NOT offset 33)', () {
      final payload = _v3ChannelPayload(
        snrQuarter: 0,
        channelIndex: 0,
        pathLen: 0,
        txtType: 0,
        timestamp: 0xCAFEBABE,
        text: 'hi',
      );
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.channelMsgRecvV3,
        payload: payload,
      );
      final result = MeshCoreMessageFrameParser.parseChannelMessage(frame);
      expect(result.ok, isTrue);
      expect(result.value!.timestamp.millisecondsSinceEpoch, 0xCAFEBABE * 1000);
    });

    test('text starts at offset 10 (NOT offset 38)', () {
      const body = 'abc';
      final payload = _v3ChannelPayload(
        snrQuarter: 0,
        channelIndex: 0,
        pathLen: 0,
        txtType: 0,
        timestamp: 0,
        text: body,
      );
      // payload bytes 10..end should equal body bytes.
      expect(
        Uint8List.sublistView(payload, 10),
        equals(Uint8List.fromList(body.codeUnits)),
      );
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.channelMsgRecvV3,
        payload: payload,
      );
      final result = MeshCoreMessageFrameParser.parseChannelMessage(frame);
      expect(result.value!.text, body);
    });

    test('preserves SNR (signed), pathLen, txtType', () {
      final payload = _v3ChannelPayload(
        snrQuarter: -8, // -2 dB
        channelIndex: 0,
        pathLen: 3,
        txtType: 2,
        timestamp: 0,
        text: '',
      );
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.channelMsgRecvV3,
        payload: payload,
      );
      final result = MeshCoreMessageFrameParser.parseChannelMessage(frame);
      expect(result.value!.snrQuarter, -8);
      expect(result.value!.pathLen, 3);
      expect(result.value!.txtType, 2);
    });

    test('rejects payload shorter than 10 with clear reason', () {
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.channelMsgRecvV3,
        payload: Uint8List.fromList([0, 0, 0, 0]),
      );
      final result = MeshCoreMessageFrameParser.parseChannelMessage(frame);
      expect(result.ok, isFalse);
      expect(result.rejectReason, contains('v3_channel_too_short'));
      expect(result.rejectReason, contains('len=4'));
    });

    test('decodes UTF-8 text without trailing null (firmware does not '
        'null-terminate, but legacy might; both shapes accepted)', () {
      // No trailing null
      var payload = _v3ChannelPayload(
        snrQuarter: 0,
        channelIndex: 0,
        pathLen: 0,
        txtType: 0,
        timestamp: 0,
        text: 'no null',
      );
      var frame = MeshCoreFrame(
        command: MeshCoreResponses.channelMsgRecvV3,
        payload: payload,
      );
      var result = MeshCoreMessageFrameParser.parseChannelMessage(frame);
      expect(result.value!.text, 'no null');

      // With trailing null (legacy-style)
      payload = Uint8List.fromList([
        ...payload,
        0, // trailing null
      ]);
      frame = MeshCoreFrame(
        command: MeshCoreResponses.channelMsgRecvV3,
        payload: payload,
      );
      result = MeshCoreMessageFrameParser.parseChannelMessage(frame);
      expect(result.value!.text, 'no null');
    });
  });

  group('parseChannelMessage: legacy (cmd 0x08)', () {
    test('parses canonical legacy payload', () {
      final payload = _legacyChannelPayload(
        channelIndex: 0,
        pathLen: 0xFF,
        txtType: 0,
        timestamp: 1_700_000_000,
        text: 'old client',
      );
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.channelMsgRecv,
        payload: payload,
      );
      final result = MeshCoreMessageFrameParser.parseChannelMessage(frame);
      expect(result.ok, isTrue, reason: result.rejectReason);
      expect(result.value!.protocol, MeshCoreMessageProtocol.legacy);
      expect(result.value!.snrQuarter, isNull);
      expect(result.value!.channelIndex, 0);
      expect(result.value!.text, 'old client');
    });

    test('rejects payload shorter than 7', () {
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.channelMsgRecv,
        payload: Uint8List.fromList([0, 0, 0]),
      );
      final result = MeshCoreMessageFrameParser.parseChannelMessage(frame);
      expect(result.ok, isFalse);
      expect(result.rejectReason, contains('legacy_channel_too_short'));
    });
  });

  group('parseChannelMessage: unknown command rejected safely', () {
    test('arbitrary command code returns rejected, never crashes', () {
      final frame = MeshCoreFrame(command: 0x42, payload: Uint8List(20));
      final result = MeshCoreMessageFrameParser.parseChannelMessage(frame);
      expect(result.ok, isFalse);
      expect(result.rejectReason, contains('unknown_channel_command'));
      expect(result.rejectReason, contains('0x42'));
    });
  });

  group('parseContactMessage: V3 (cmd 0x10)', () {
    final senderPrefix = const [0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6];

    test('parses a realistic V3 payload of length 15 + text', () {
      final payload = _v3ContactPayload(
        snrQuarter: 12,
        senderPrefix: senderPrefix,
        pathLen: 0xFF,
        txtType: 0,
        timestamp: 1_700_000_000,
        text: 'hello',
      );
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.contactMsgRecvV3,
        payload: payload,
      );
      final result = MeshCoreMessageFrameParser.parseContactMessage(frame);
      expect(result.ok, isTrue, reason: result.rejectReason);
      final v = result.value!;
      expect(v.protocol, MeshCoreMessageProtocol.v3);
      expect(v.snrQuarter, 12);
      expect(v.senderPrefixHex, 'a1a2a3a4a5a6');
      expect(v.senderPrefixHex.length, 12);
      expect(v.pathLen, 0xFF);
      expect(v.text, 'hello');
    });

    test('senderPrefixHex is exactly 12 lowercase hex chars at offset 3', () {
      final payload = _v3ContactPayload(
        snrQuarter: 0,
        senderPrefix: const [0xFF, 0x00, 0xAB, 0xCD, 0xEF, 0x42],
        pathLen: 0,
        txtType: 0,
        timestamp: 0,
        text: '',
      );
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.contactMsgRecvV3,
        payload: payload,
      );
      final result = MeshCoreMessageFrameParser.parseContactMessage(frame);
      expect(result.value!.senderPrefixHex, 'ff00abcdef42');
      // Critically: never the lowercased SNR byte at offset 0.
      expect(result.value!.senderPrefixHex.startsWith('00'), isFalse);
    });

    test('reads timestamp from offset 11 (NOT offset 32)', () {
      final payload = _v3ContactPayload(
        snrQuarter: 0,
        senderPrefix: senderPrefix,
        pathLen: 0,
        txtType: 0,
        timestamp: 0x12345678,
        text: 'x',
      );
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.contactMsgRecvV3,
        payload: payload,
      );
      final result = MeshCoreMessageFrameParser.parseContactMessage(frame);
      expect(result.value!.timestamp.millisecondsSinceEpoch, 0x12345678 * 1000);
    });

    test('text starts at offset 15 (NOT offset 37)', () {
      const body = 'msg body';
      final payload = _v3ContactPayload(
        snrQuarter: 0,
        senderPrefix: senderPrefix,
        pathLen: 0,
        txtType: 0,
        timestamp: 0,
        text: body,
      );
      expect(payload.length, 15 + body.length);
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.contactMsgRecvV3,
        payload: payload,
      );
      final result = MeshCoreMessageFrameParser.parseContactMessage(frame);
      expect(result.value!.text, body);
    });

    test(
      'full contact public key matches by 6-byte prefix (NOT exact full-hex equality)',
      () {
        final fullPubKeyHex =
            'a1a2a3a4a5a6'
            '${'00' * 26}'; // 32-byte hex
        const senderPrefixHex = 'a1a2a3a4a5a6';
        expect(
          MeshCoreMessageFrameParser.senderPrefixMatches(
            contactPublicKeyHex: fullPubKeyHex,
            senderPrefixHex: senderPrefixHex,
          ),
          isTrue,
        );

        // Different first 6 bytes; should not match.
        const wrongPrefix = 'b1b2b3b4b5b6';
        expect(
          MeshCoreMessageFrameParser.senderPrefixMatches(
            contactPublicKeyHex: fullPubKeyHex,
            senderPrefixHex: wrongPrefix,
          ),
          isFalse,
        );
      },
    );

    test('rejects payload shorter than 15 with clear reason', () {
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.contactMsgRecvV3,
        payload: Uint8List.fromList(List.filled(10, 0)),
      );
      final result = MeshCoreMessageFrameParser.parseContactMessage(frame);
      expect(result.ok, isFalse);
      expect(result.rejectReason, contains('v3_contact_too_short'));
      expect(result.rejectReason, contains('len=10'));
    });
  });

  group('parseContactMessage: legacy (cmd 0x07)', () {
    final senderPrefix = const [0xb1, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6];

    test('parses canonical legacy payload', () {
      final payload = _legacyContactPayload(
        senderPrefix: senderPrefix,
        pathLen: 0xFF,
        txtType: 0,
        timestamp: 1_700_000_000,
        text: 'legacy',
      );
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.contactMsgRecv,
        payload: payload,
      );
      final result = MeshCoreMessageFrameParser.parseContactMessage(frame);
      expect(result.ok, isTrue, reason: result.rejectReason);
      expect(result.value!.protocol, MeshCoreMessageProtocol.legacy);
      expect(result.value!.snrQuarter, isNull);
      expect(result.value!.senderPrefixHex, 'b1b2b3b4b5b6');
      expect(result.value!.text, 'legacy');
    });

    test('rejects payload shorter than 12', () {
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.contactMsgRecv,
        payload: Uint8List.fromList(List.filled(8, 0)),
      );
      final result = MeshCoreMessageFrameParser.parseContactMessage(frame);
      expect(result.ok, isFalse);
      expect(result.rejectReason, contains('legacy_contact_too_short'));
    });
  });

  group('parseContactMessage: unknown command', () {
    test('arbitrary command code returns rejected, never crashes', () {
      final frame = MeshCoreFrame(command: 0xAB, payload: Uint8List(20));
      final result = MeshCoreMessageFrameParser.parseContactMessage(frame);
      expect(result.ok, isFalse);
      expect(result.rejectReason, contains('unknown_contact_command'));
    });
  });
}
