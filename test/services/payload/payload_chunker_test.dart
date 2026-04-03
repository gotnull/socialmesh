// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/payload/payload_chunker.dart';
import 'package:socialmesh/services/payload/spp_constants.dart';

void main() {
  group('PayloadChunker', () {
    group('createChunkDefinitions', () {
      test('returns empty list for zero-length payload', () {
        final defs = PayloadChunker.createChunkDefinitions(totalBytes: 0);
        expect(defs, isEmpty);
      });

      test('returns empty list for negative payload size', () {
        final defs = PayloadChunker.createChunkDefinitions(totalBytes: -1);
        expect(defs, isEmpty);
      });

      test('single chunk for small payload', () {
        final defs = PayloadChunker.createChunkDefinitions(totalBytes: 50);
        expect(defs.length, 1);
        expect(defs[0].index, 0);
        expect(defs[0].offset, 0);
        expect(defs[0].length, 50);
      });

      test('exact chunk boundary (no remainder)', () {
        final defs = PayloadChunker.createChunkDefinitions(
          totalBytes: 400,
          chunkSize: 200,
        );
        expect(defs.length, 2);
        expect(defs[0].index, 0);
        expect(defs[0].offset, 0);
        expect(defs[0].length, 200);
        expect(defs[1].index, 1);
        expect(defs[1].offset, 200);
        expect(defs[1].length, 200);
      });

      test('last chunk has remainder bytes', () {
        final defs = PayloadChunker.createChunkDefinitions(
          totalBytes: 350,
          chunkSize: 200,
        );
        expect(defs.length, 2);
        expect(defs[0].length, 200);
        expect(defs[1].length, 150);
        expect(defs[1].offset, 200);
      });

      test('uses default chunk size from SppLimits', () {
        final defs = PayloadChunker.createChunkDefinitions(totalBytes: 500);
        expect(
          defs.length,
          (500 + SppLimits.defaultChunkSize - 1) ~/ SppLimits.defaultChunkSize,
        );
      });

      test('STL overhead reduces effective chunk size', () {
        final defs = PayloadChunker.createChunkDefinitions(
          totalBytes: 400,
          chunkSize: 200,
          stlOverhead: 100,
        );
        // Effective chunk size = 100
        expect(defs.length, 4);
        expect(defs[0].length, 100);
        expect(defs[3].length, 100);
      });

      test('throws on zero effective chunk size', () {
        expect(
          () => PayloadChunker.createChunkDefinitions(
            totalBytes: 100,
            chunkSize: 50,
            stlOverhead: 50,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on negative effective chunk size', () {
        expect(
          () => PayloadChunker.createChunkDefinitions(
            totalBytes: 100,
            chunkSize: 50,
            stlOverhead: 100,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('sequential indexes from 0 to N-1', () {
        final defs = PayloadChunker.createChunkDefinitions(
          totalBytes: 1000,
          chunkSize: 200,
        );
        for (var i = 0; i < defs.length; i++) {
          expect(defs[i].index, i);
        }
      });

      test('total bytes covered equals totalBytes', () {
        final defs = PayloadChunker.createChunkDefinitions(
          totalBytes: 777,
          chunkSize: 200,
        );
        final totalCovered = defs.fold<int>(0, (sum, d) => sum + d.length);
        expect(totalCovered, 777);
      });

      test('single byte payload produces one chunk', () {
        final defs = PayloadChunker.createChunkDefinitions(totalBytes: 1);
        expect(defs.length, 1);
        expect(defs[0].length, 1);
      });
    });

    group('extractChunkBytes', () {
      test('extracts correct bytes for each chunk', () {
        final payload = Uint8List.fromList(List.generate(500, (i) => i % 256));
        final defs = PayloadChunker.createChunkDefinitions(
          totalBytes: 500,
          chunkSize: 200,
        );

        for (final def in defs) {
          final bytes = PayloadChunker.extractChunkBytes(payload, def);
          expect(bytes.length, def.length);
          for (var i = 0; i < bytes.length; i++) {
            expect(bytes[i], payload[def.offset + i]);
          }
        }
      });

      test('reassembled chunks equal original payload', () {
        final payload = Uint8List.fromList(List.generate(777, (i) => i % 256));
        final defs = PayloadChunker.createChunkDefinitions(
          totalBytes: 777,
          chunkSize: 200,
        );

        final builder = BytesBuilder(copy: false);
        for (final def in defs) {
          builder.add(PayloadChunker.extractChunkBytes(payload, def));
        }

        expect(builder.toBytes(), payload);
      });
    });

    group('chunkCount', () {
      test('matches createChunkDefinitions length', () {
        for (final size in [1, 50, 200, 400, 777, 8192]) {
          final count = PayloadChunker.chunkCount(totalBytes: size);
          final defs = PayloadChunker.createChunkDefinitions(totalBytes: size);
          expect(count, defs.length, reason: 'size=$size');
        }
      });

      test('returns 0 for zero-length payload', () {
        expect(PayloadChunker.chunkCount(totalBytes: 0), 0);
      });

      test('accounts for STL overhead', () {
        final count = PayloadChunker.chunkCount(
          totalBytes: 400,
          chunkSize: 200,
          stlOverhead: 100,
        );
        expect(count, 4); // effective = 100, 400/100 = 4
      });
    });
  });
}
