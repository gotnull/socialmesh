// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Byte-accurate tests for the SPP v0.2 resource-frame codec.
///
/// Vectors here are authoritative per `docs/sip/OVERLAY_V0_2.md` §11.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_constants.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_codec.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

void main() {
  group('OverlayResourceCodec golden vectors', () {
    test(
      'OFFER with 4 B payload → header[type=0x01, v=0x02, rid LE, 0, 0]',
      () {
        final body = Uint8List.fromList(<int>[0xAA, 0xBB, 0xCC, 0xDD]);
        final frame = OverlayResourceFrame(
          type: OverlayResourceMsgType.offer,
          resourceId: 0x01020304,
          payload: body,
        );
        final bytes = OverlayResourceCodec.encode(frame)!;
        expect(
          bytes,
          equals(
            Uint8List.fromList(<int>[
              0x01, // OFFER
              0x02, // version
              0x04, 0x03, 0x02, 0x01, // resourceId LE
              0x00, 0x00, // chunkIndex
              0x00, 0x00, // chunkCount
              0xAA, 0xBB, 0xCC, 0xDD,
            ]),
          ),
        );
      },
    );

    test('CHUNK encodes chunkIndex and chunkCount at correct offsets', () {
      final body = Uint8List.fromList(<int>[0xDE, 0xAD]);
      final frame = OverlayResourceFrame(
        type: OverlayResourceMsgType.chunk,
        resourceId: 0x000000FF,
        chunkIndex: 0x000A,
        chunkCount: 0x0100,
        payload: body,
      );
      final bytes = OverlayResourceCodec.encode(frame)!;
      expect(bytes.length, 12);
      expect(bytes[0], 0x04); // CHUNK
      expect(bytes.sublist(6, 8), equals(Uint8List.fromList([0x0A, 0x00])));
      expect(bytes.sublist(8, 10), equals(Uint8List.fromList([0x00, 0x01])));
    });

    test('COMPLETE carries only header + SHA-256', () {
      final sha = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        sha[i] = i;
      }
      final frame = OverlayResourceFrame(
        type: OverlayResourceMsgType.complete,
        resourceId: 1,
        chunkCount: 512,
        payload: sha,
      );
      final bytes = OverlayResourceCodec.encode(frame)!;
      expect(bytes.length, 42);
      expect(bytes[0], 0x07);
    });
  });

  group('OverlayResourceCodec roundtrips', () {
    test('roundtrip all 10 msg types with small bodies', () {
      for (final type in OverlayResourceMsgType.values) {
        final body = Uint8List.fromList(<int>[type.code, 0x42]);
        final frame = OverlayResourceFrame(
          type: type,
          resourceId: 0xFEEDFACE,
          chunkIndex: type.code,
          chunkCount: 0,
          payload: body,
        );
        final bytes = OverlayResourceCodec.encode(frame)!;
        final result = OverlayResourceCodec.decode(bytes);
        expect(result.isOk, isTrue, reason: 'type=${type.name}');
        expect(result.frame!.type, type);
        expect(result.frame!.resourceId, 0xFEEDFACE);
        expect(result.frame!.chunkIndex, type.code);
        expect(result.frame!.payload, equals(body));
      }
    });

    test('roundtrip CHUNK at unsigned ceiling (177 B)', () {
      final body = Uint8List.fromList(
        List<int>.generate(
          OverlayResourceConstants.chunkPayloadCeilUnsigned,
          (i) => i & 0xFF,
        ),
      );
      final frame = OverlayResourceFrame(
        type: OverlayResourceMsgType.chunk,
        resourceId: 0x01,
        chunkIndex: 0,
        chunkCount: 1,
        payload: body,
      );
      final bytes = OverlayResourceCodec.encode(frame)!;
      expect(
        bytes.length,
        OverlayResourceConstants.headerLen +
            OverlayResourceConstants.chunkPayloadCeilUnsigned,
      );
      final decoded = OverlayResourceCodec.decode(bytes).frame!;
      expect(decoded.payload, equals(body));
    });
  });

  group('OverlayResourceCodec.isResourceFrame sniffer', () {
    test('accepts a valid OFFER', () {
      final frame = OverlayResourceFrame(
        type: OverlayResourceMsgType.offer,
        resourceId: 0,
        payload: Uint8List(0),
      );
      final bytes = OverlayResourceCodec.encode(frame)!;
      expect(OverlayResourceCodec.isResourceFrame(bytes), isTrue);
    });

    test('rejects short input', () {
      expect(OverlayResourceCodec.isResourceFrame(Uint8List(5)), isFalse);
    });

    test('rejects wrong version', () {
      final bytes = OverlayResourceCodec.encode(
        OverlayResourceFrame(
          type: OverlayResourceMsgType.offer,
          resourceId: 0,
          payload: Uint8List(0),
        ),
      )!;
      bytes[1] = 0x01;
      expect(OverlayResourceCodec.isResourceFrame(bytes), isFalse);
    });

    test('rejects unknown type', () {
      final bytes = OverlayResourceCodec.encode(
        OverlayResourceFrame(
          type: OverlayResourceMsgType.offer,
          resourceId: 0,
          payload: Uint8List(0),
        ),
      )!;
      bytes[0] = 0xFF;
      expect(OverlayResourceCodec.isResourceFrame(bytes), isFalse);
    });
  });

  group('OverlayResourceCodec decode negatives', () {
    test('short buffer → DecodeError.short', () {
      final result = OverlayResourceCodec.decode(Uint8List(3));
      expect(result.error, OverlayResourceDecodeError.short);
    });

    test('bad type → DecodeError.badType', () {
      final bytes = OverlayResourceCodec.encode(
        OverlayResourceFrame(
          type: OverlayResourceMsgType.offer,
          resourceId: 0,
          payload: Uint8List(0),
        ),
      )!;
      bytes[0] = 0xFF;
      final result = OverlayResourceCodec.decode(bytes);
      expect(result.error, OverlayResourceDecodeError.badType);
    });

    test('bad version → DecodeError.badVersion', () {
      final bytes = OverlayResourceCodec.encode(
        OverlayResourceFrame(
          type: OverlayResourceMsgType.offer,
          resourceId: 0,
          payload: Uint8List(0),
        ),
      )!;
      bytes[1] = 0x01;
      final result = OverlayResourceCodec.decode(bytes);
      expect(result.error, OverlayResourceDecodeError.badVersion);
    });

    test('payload larger than ceiling → DecodeError.badPayloadLen', () {
      final oversized = Uint8List(
        OverlayResourceConstants.headerLen +
            OverlayResourceConstants.chunkPayloadCeilUnsigned +
            1,
      );
      oversized[0] = OverlayResourceMsgType.chunk.code;
      oversized[1] = OverlayResourceConstants.version;
      final result = OverlayResourceCodec.decode(oversized);
      expect(result.error, OverlayResourceDecodeError.badPayloadLen);
    });
  });

  group('OverlayResourceCodec encode negatives', () {
    test('rejects wrong version', () {
      final frame = OverlayResourceFrame(
        type: OverlayResourceMsgType.offer,
        version: 0x01,
        resourceId: 0,
        payload: Uint8List(0),
      );
      expect(OverlayResourceCodec.encode(frame), isNull);
    });

    test('rejects oversized payload', () {
      final body = Uint8List(
        OverlayResourceConstants.chunkPayloadCeilUnsigned + 1,
      );
      final frame = OverlayResourceFrame(
        type: OverlayResourceMsgType.chunk,
        resourceId: 0,
        payload: body,
      );
      expect(OverlayResourceCodec.encode(frame), isNull);
    });
  });
}
