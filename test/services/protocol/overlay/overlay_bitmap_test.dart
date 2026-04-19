// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for [OverlayBitmap] — the SPP v0.2 chunk-receipt bitmap.
///
/// Covers byte-width rounding, LSB-first packing order, missing-chunk
/// enumeration, decode robustness at edge chunk counts (1, 64, 512,
/// 8191), and malformed-input rejection.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_bitmap.dart';

void main() {
  group('OverlayBitmap.byteLength', () {
    test('packs 0 chunks into 0 bytes', () {
      expect(OverlayBitmap.byteLength(0), 0);
    });

    test('rounds up to a whole byte', () {
      expect(OverlayBitmap.byteLength(1), 1);
      expect(OverlayBitmap.byteLength(7), 1);
      expect(OverlayBitmap.byteLength(8), 1);
      expect(OverlayBitmap.byteLength(9), 2);
      expect(OverlayBitmap.byteLength(64), 8);
      expect(OverlayBitmap.byteLength(512), 64);
      expect(OverlayBitmap.byteLength(8191), 1024);
    });

    test('rejects negative input', () {
      expect(() => OverlayBitmap.byteLength(-1), throwsArgumentError);
    });
  });

  group('OverlayBitmap.encode', () {
    test('LSB-first within each byte (golden vector for 16 chunks)', () {
      // chunks {0, 3, 7, 8, 11} → byte0 = 10001001 (0x89), byte1 = 0b00001001 (0x09).
      final bitmap = OverlayBitmap.encode({0, 3, 7, 8, 11}, 16);
      expect(bitmap, equals(Uint8List.fromList([0x89, 0x09])));
    });

    test('out-of-range indexes are silently ignored', () {
      final bitmap = OverlayBitmap.encode({-1, 0, 16}, 8);
      // only index 0 is valid → byte0 bit0 = 1
      expect(bitmap, equals(Uint8List.fromList([0x01])));
    });

    test('empty input yields zero-filled buffer of correct width', () {
      final bitmap = OverlayBitmap.encode(const <int>{}, 20);
      expect(bitmap, equals(Uint8List(3)));
    });

    test('encodeBools matches encode(Set) for the same logical input', () {
      final flags = List<bool>.generate(16, (i) => i == 0 || i == 3 || i == 11);
      final a = OverlayBitmap.encodeBools(flags);
      final b = OverlayBitmap.encode({0, 3, 11}, 16);
      expect(a, equals(b));
    });
  });

  group('OverlayBitmap.decode', () {
    test('decodes the golden 16-chunk vector', () {
      final bitmap = Uint8List.fromList([0x89, 0x09]);
      final received = OverlayBitmap.decode(bitmap, 16);
      expect(received, equals({0, 3, 7, 8, 11}));
    });

    test('ignores trailing padding bits', () {
      // byte0 = 0xFF, only 3 chunks valid → expect {0, 1, 2}
      final bitmap = Uint8List.fromList([0xFF]);
      expect(OverlayBitmap.decode(bitmap, 3), equals({0, 1, 2}));
    });

    test('decode rejects buffers that are too short', () {
      final bitmap = Uint8List.fromList([0xFF]);
      expect(() => OverlayBitmap.decode(bitmap, 16), throwsFormatException);
    });

    test('encode → decode roundtrips for 1 / 64 / 512 / 8191 chunks', () {
      for (final n in [1, 64, 512, 8191]) {
        final received = <int>{};
        // pick a few indexes across the range
        for (var i = 0; i < n; i += (n ~/ 13).clamp(1, n)) {
          received.add(i);
        }
        received.add(n - 1);
        final bitmap = OverlayBitmap.encode(received, n);
        expect(bitmap.length, OverlayBitmap.byteLength(n));
        final decoded = OverlayBitmap.decode(bitmap, n);
        expect(decoded, equals(received), reason: 'roundtrip failed at n=$n');
      }
    });
  });

  group('OverlayBitmap.missingIndexes', () {
    test('returns ordered missing indexes for a partial bitmap', () {
      final bitmap = OverlayBitmap.encode({0, 2, 5}, 8);
      final missing = OverlayBitmap.missingIndexes(bitmap, 8);
      expect(missing, equals([1, 3, 4, 6, 7]));
    });

    test('returns empty for a fully-received bitmap', () {
      final bitmap = OverlayBitmap.encode({0, 1, 2, 3, 4, 5, 6, 7}, 8);
      expect(OverlayBitmap.missingIndexes(bitmap, 8), isEmpty);
    });

    test('returns the full range for an empty bitmap', () {
      final bitmap = Uint8List(1);
      expect(OverlayBitmap.missingIndexes(bitmap, 5), equals([0, 1, 2, 3, 4]));
    });
  });

  group('OverlayBitmap.isComplete / popcount', () {
    test('isComplete is true when all bits set', () {
      expect(OverlayBitmap.isComplete(Uint8List.fromList([0xFF]), 8), isTrue);
    });

    test('isComplete is false when any bit is missing', () {
      expect(OverlayBitmap.isComplete(Uint8List.fromList([0xFE]), 8), isFalse);
    });

    test('popcount counts set bits correctly', () {
      final bitmap = OverlayBitmap.encode({0, 3, 7, 8, 11}, 16);
      expect(OverlayBitmap.popcount(bitmap, 16), 5);
    });

    test('popcount ignores trailing padding', () {
      final bitmap = Uint8List.fromList([0xFF]);
      expect(OverlayBitmap.popcount(bitmap, 3), 3);
    });
  });
}
