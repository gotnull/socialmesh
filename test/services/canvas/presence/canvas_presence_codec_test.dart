// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// canvas.v1 presence (action 0x0007) codec byte-vector tests.
//
// Source of truth: docs/canvas/CANVAS_PRESENCE_V0_1.md §2.2 / §2.3.
// Decoder MUST reject any payload that violates the wire spec; this
// file pins those rejections plus byte-exact round-trip vectors for
// each presence state.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/canvas/canvas_codec.dart';
import 'package:socialmesh/services/canvas/canvas_constants.dart';

List<int> _u64Le(int v) {
  final out = List<int>.filled(8, 0);
  var rem = v;
  for (var i = 0; i < 8; i++) {
    out[i] = rem & 0xFF;
    rem >>>= 8;
  }
  return out;
}

List<int> _u32Le(int v) => [
  v & 0xFF,
  (v >> 8) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 24) & 0xFF,
];

List<int> _u16Le(int v) => [v & 0xFF, (v >> 8) & 0xFF];

/// Hand-craft a 24-byte presence payload byte-by-byte. Defaults match
/// a well-formed `viewing` frame so a caller need only override the
/// one field under test.
Uint8List _craftPresence({
  int magic = 0xCA,
  int version = 0x01,
  int opType = 0x07,
  int flags = 0,
  int canvasId = 0x1122334455667788,
  int authorId = 0xAABBCCDD,
  int state = 0x00,
  int emitTs = 0x11223344,
  int ttlSeconds = 180,
  int reserved = 0,
}) {
  final buf = ByteData(24);
  buf.setUint8(0, magic);
  buf.setUint8(1, version);
  buf.setUint8(2, opType);
  buf.setUint8(3, flags);
  buf.setUint64(4, canvasId, Endian.little);
  buf.setUint32(12, authorId, Endian.little);
  buf.setUint8(16, state);
  buf.setUint32(17, emitTs, Endian.little);
  buf.setUint16(21, ttlSeconds, Endian.little);
  buf.setUint8(23, reserved);
  return buf.buffer.asUint8List();
}

void main() {
  group('presence (action 0x0007) byte vectors', () {
    test('sniffAction recognises 0x07 as CanvasAction.presence', () {
      final buf = Uint8List(12)
        ..[0] = 0xCA
        ..[1] = 0x01
        ..[2] = 0x07;
      expect(CanvasCodec.sniffAction(buf), CanvasAction.presence);
    });

    test('byte-exact vector for state=viewing', () {
      const op = CanvasPresenceOp(
        canvasId: 0x1122334455667788,
        authorId: 0xAABBCCDD,
        state: PresenceState.viewing,
        emitTs: 0x11223344,
        ttlSeconds: 180,
      );
      final encoded = CanvasCodec.encodePresence(op);
      expect(encoded, isNotNull);
      expect(encoded!.length, 24);
      expect(encoded, <int>[
        // common prefix
        0xCA, 0x01, 0x07, 0x00,
        ..._u64Le(0x1122334455667788),
        // author_id
        ..._u32Le(0xAABBCCDD),
        // state
        0x00,
        // emit_ts
        ..._u32Le(0x11223344),
        // ttl_seconds
        ..._u16Le(180),
        // reserved
        0x00,
      ]);
    });

    test('byte-exact vector for state=active', () {
      const op = CanvasPresenceOp(
        canvasId: 0x0102030405060708,
        authorId: 0x10203040,
        state: PresenceState.active,
        emitTs: 60,
        ttlSeconds: 60,
      );
      final encoded = CanvasCodec.encodePresence(op);
      expect(encoded, isNotNull);
      expect(encoded!.length, 24);
      expect(encoded, <int>[
        0xCA,
        0x01,
        0x07,
        0x00,
        ..._u64Le(0x0102030405060708),
        ..._u32Le(0x10203040),
        0x01,
        ..._u32Le(60),
        ..._u16Le(60),
        0x00,
      ]);
    });

    test('byte-exact vector for state=painting', () {
      const op = CanvasPresenceOp(
        canvasId: 0xDEADBEEFCAFEBABE,
        authorId: 0xFFFFFFFE,
        state: PresenceState.painting,
        emitTs: 0xFFFFFFFF,
        ttlSeconds: 600,
      );
      final encoded = CanvasCodec.encodePresence(op);
      expect(encoded, isNotNull);
      expect(encoded!.length, 24);
      expect(encoded, <int>[
        0xCA,
        0x01,
        0x07,
        0x00,
        ..._u64Le(0xDEADBEEFCAFEBABE),
        ..._u32Le(0xFFFFFFFE),
        0x02,
        ..._u32Le(0xFFFFFFFF),
        ..._u16Le(600),
        0x00,
      ]);
    });

    test('byte-exact vector for state=leaving', () {
      const op = CanvasPresenceOp(
        canvasId: 0x00,
        authorId: 0x00,
        state: PresenceState.leaving,
        emitTs: 0x00,
        ttlSeconds: CanvasPresenceLimits.ttlSecondsDefault,
      );
      final encoded = CanvasCodec.encodePresence(op);
      expect(encoded, isNotNull);
      expect(encoded!.length, 24);
      expect(encoded, <int>[
        0xCA,
        0x01,
        0x07,
        0x00,
        ..._u64Le(0),
        ..._u32Le(0),
        0x03,
        ..._u32Le(0),
        ..._u16Le(180),
        0x00,
      ]);
    });
  });

  group('presence round-trip', () {
    for (final state in PresenceState.values) {
      test('round-trip preserves state=${state.name}', () {
        final op = CanvasPresenceOp(
          canvasId: 0x1122334455667788,
          authorId: 0xAABBCCDD,
          state: state,
          emitTs: 1_700_000_000,
          ttlSeconds: 240,
        );
        final encoded = CanvasCodec.encodePresence(op);
        expect(encoded, isNotNull);
        final decoded = CanvasCodec.decodePresence(encoded!);
        expect(decoded, isNotNull);
        expect(decoded!.canvasId, op.canvasId);
        expect(decoded.authorId, op.authorId);
        expect(decoded.state, op.state);
        expect(decoded.emitTs, op.emitTs);
        expect(decoded.ttlSeconds, op.ttlSeconds);
      });
    }
  });

  group('presence decoder rejections', () {
    test('rejects payload with anonymous_author flag (bit1) set', () {
      final payload = _craftPresence(flags: 0x02);
      expect(CanvasCodec.decodePresence(payload), isNull);
    });

    test('rejects payload with batch flag (bit0) set', () {
      final payload = _craftPresence(flags: 0x01);
      expect(CanvasCodec.decodePresence(payload), isNull);
    });

    test('rejects payload with reserved flag bits (2..7) set', () {
      // 0x04 = bit2, 0x80 = bit7. Either should be rejected via the
      // common-prefix validator's reserved-flag-bits check.
      expect(CanvasCodec.decodePresence(_craftPresence(flags: 0x04)), isNull);
      expect(CanvasCodec.decodePresence(_craftPresence(flags: 0x80)), isNull);
    });

    test('rejects payload with reserved trailing byte != 0', () {
      expect(
        CanvasCodec.decodePresence(_craftPresence(reserved: 0x01)),
        isNull,
      );
      expect(
        CanvasCodec.decodePresence(_craftPresence(reserved: 0xFF)),
        isNull,
      );
    });

    test('rejects ttl_seconds == 0', () {
      expect(CanvasCodec.decodePresence(_craftPresence(ttlSeconds: 0)), isNull);
    });

    test('rejects ttl_seconds == 59 (just below lower bound)', () {
      expect(
        CanvasCodec.decodePresence(_craftPresence(ttlSeconds: 59)),
        isNull,
      );
    });

    test('accepts ttl_seconds == 60 (inclusive lower bound)', () {
      final decoded = CanvasCodec.decodePresence(
        _craftPresence(ttlSeconds: 60),
      );
      expect(decoded, isNotNull);
      expect(decoded!.ttlSeconds, 60);
    });

    test('accepts ttl_seconds == 600 (inclusive upper bound)', () {
      final decoded = CanvasCodec.decodePresence(
        _craftPresence(ttlSeconds: 600),
      );
      expect(decoded, isNotNull);
      expect(decoded!.ttlSeconds, 600);
    });

    test('rejects ttl_seconds == 601 (just above upper bound)', () {
      expect(
        CanvasCodec.decodePresence(_craftPresence(ttlSeconds: 601)),
        isNull,
      );
    });

    test('rejects ttl_seconds == 0xFFFF (well above upper bound)', () {
      expect(
        CanvasCodec.decodePresence(_craftPresence(ttlSeconds: 0xFFFF)),
        isNull,
      );
    });

    test('rejects unknown state byte 0x04', () {
      expect(CanvasCodec.decodePresence(_craftPresence(state: 0x04)), isNull);
    });

    test('rejects unknown state byte 0x05', () {
      expect(CanvasCodec.decodePresence(_craftPresence(state: 0x05)), isNull);
    });

    test('rejects unknown state byte 0xFF', () {
      expect(CanvasCodec.decodePresence(_craftPresence(state: 0xFF)), isNull);
    });

    test('rejects wrong magic', () {
      expect(CanvasCodec.decodePresence(_craftPresence(magic: 0xAB)), isNull);
      expect(CanvasCodec.decodePresence(_craftPresence(magic: 0x00)), isNull);
    });

    test('rejects wrong wire version', () {
      expect(CanvasCodec.decodePresence(_craftPresence(version: 0x02)), isNull);
      expect(CanvasCodec.decodePresence(_craftPresence(version: 0x00)), isNull);
    });

    test('rejects wrong op_type', () {
      // 0x06 (canvas_info) is the closest valid neighbour; 0x08 is the
      // next-action-id-after-presence sentinel; both should be rejected.
      expect(CanvasCodec.decodePresence(_craftPresence(opType: 0x06)), isNull);
      expect(CanvasCodec.decodePresence(_craftPresence(opType: 0x08)), isNull);
      expect(CanvasCodec.decodePresence(_craftPresence(opType: 0x00)), isNull);
    });

    test('rejects every truncated length 0..23', () {
      final full = _craftPresence();
      for (var len = 0; len < 24; len++) {
        final truncated = Uint8List.fromList(full.sublist(0, len));
        expect(
          CanvasCodec.decodePresence(truncated),
          isNull,
          reason: 'truncated length $len should be rejected',
        );
      }
    });

    test('accepts a well-formed 24-byte payload (sanity)', () {
      final decoded = CanvasCodec.decodePresence(_craftPresence());
      expect(decoded, isNotNull);
      expect(decoded!.canvasId, 0x1122334455667788);
      expect(decoded.authorId, 0xAABBCCDD);
      expect(decoded.state, PresenceState.viewing);
      expect(decoded.emitTs, 0x11223344);
      expect(decoded.ttlSeconds, 180);
    });
  });

  group('presence encoder rejections', () {
    test('rejects ttl_seconds == 59 at encode time', () {
      const op = CanvasPresenceOp(
        canvasId: 1,
        authorId: 2,
        state: PresenceState.viewing,
        emitTs: 3,
        ttlSeconds: 59,
      );
      expect(CanvasCodec.encodePresence(op), isNull);
    });

    test('rejects ttl_seconds == 601 at encode time', () {
      const op = CanvasPresenceOp(
        canvasId: 1,
        authorId: 2,
        state: PresenceState.viewing,
        emitTs: 3,
        ttlSeconds: 601,
      );
      expect(CanvasCodec.encodePresence(op), isNull);
    });

    test('encodes the minimum ttl boundary (60)', () {
      const op = CanvasPresenceOp(
        canvasId: 1,
        authorId: 2,
        state: PresenceState.viewing,
        emitTs: 3,
        ttlSeconds: 60,
      );
      expect(CanvasCodec.encodePresence(op), isNotNull);
    });

    test('encodes the maximum ttl boundary (600)', () {
      const op = CanvasPresenceOp(
        canvasId: 1,
        authorId: 2,
        state: PresenceState.viewing,
        emitTs: 3,
        ttlSeconds: 600,
      );
      expect(CanvasCodec.encodePresence(op), isNotNull);
    });
  });

  group('PresenceState.fromCode', () {
    test('maps known codes', () {
      expect(PresenceState.fromCode(0x00), PresenceState.viewing);
      expect(PresenceState.fromCode(0x01), PresenceState.active);
      expect(PresenceState.fromCode(0x02), PresenceState.painting);
      expect(PresenceState.fromCode(0x03), PresenceState.leaving);
    });

    test('returns null on unknown codes', () {
      expect(PresenceState.fromCode(0x04), isNull);
      expect(PresenceState.fromCode(0xFF), isNull);
      expect(PresenceState.fromCode(-1), isNull);
    });
  });
}
