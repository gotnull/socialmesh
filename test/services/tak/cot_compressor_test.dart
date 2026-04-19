// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/tak/cot_compressor.dart';

void main() {
  group('CotCompressor', () {
    test('compress/decompress round-trip preserves data', () {
      // Create a payload large enough to compress (>100 bytes)
      final original = Uint8List.fromList(
        List.generate(200, (i) => i % 10), // repetitive = compressible
      );
      final compressed = CotCompressor.compress(original);
      expect(compressed, isNotNull);
      final decompressed = CotCompressor.decompress(compressed!);
      expect(decompressed, original);
    });

    test('skips payload below threshold', () {
      final small = Uint8List(50);
      expect(CotCompressor.compress(small), isNull);
    });

    test('skips payload at exactly threshold', () {
      final exact = Uint8List(CotCompressor.compressionThreshold - 1);
      expect(CotCompressor.compress(exact), isNull);
    });

    test('skips if compressed >= original (random data)', () {
      // Random data does not compress well
      final random = Uint8List.fromList(
        List.generate(120, (i) => (i * 37 + 13) % 256),
      );
      // May or may not compress; if it doesn't, returns null
      final result = CotCompressor.compress(random);
      if (result != null) {
        expect(result.length, lessThan(random.length));
      }
    });

    test('compresses repetitive data effectively', () {
      final repetitive = Uint8List.fromList(
        List.generate(200, (_) => 0x41), // 'AAAA...'
      );
      final compressed = CotCompressor.compress(repetitive);
      expect(compressed, isNotNull);
      expect(compressed!.length, lessThan(repetitive.length));
    });

    test('rejects if compressed still exceeds max mesh payload', () {
      // Create data that's large but compresses to just above limit
      // 500 bytes of pseudo-random data unlikely to compress below 237
      final large = Uint8List.fromList(
        List.generate(500, (i) => (i * 53 + 7) % 256),
      );
      final result = CotCompressor.compress(large);
      // If compressed is still > 237, should return null
      if (result != null) {
        expect(result.length, lessThanOrEqualTo(CotCompressor.maxMeshPayload));
      }
    });

    test('decompress handles valid zlib data', () {
      final data = Uint8List.fromList(List.generate(150, (i) => i % 5));
      final compressed = CotCompressor.compress(data)!;
      final result = CotCompressor.decompress(compressed);
      expect(result, data);
    });
  });
}
