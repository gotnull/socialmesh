// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/payload/payload_reassembler.dart';

void main() {
  /// Helper to create a test payload and its SHA-256 hash.
  (Uint8List payload, Uint8List hash) makePayload(int size) {
    final data = Uint8List.fromList(List.generate(size, (i) => i % 256));
    final hash = Uint8List.fromList(sha256.convert(data).bytes);
    return (data, hash);
  }

  group('PayloadReassembler', () {
    test('single chunk completes successfully', () {
      final (payload, hash) = makePayload(50);

      final reassembler = PayloadReassembler(
        payloadIdHex: 'test-001',
        totalBytes: 50,
        chunkCount: 1,
        sha256Hash: hash,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(reassembler.addChunk(0, payload), isTrue);
      expect(reassembler.isComplete, isTrue);

      final result = reassembler.tryReassemble();
      expect(result, isA<ReassemblySuccess>());
      expect((result as ReassemblySuccess).payload, payload);
    });

    test('multiple chunks in order', () {
      final (payload, hash) = makePayload(500);

      final reassembler = PayloadReassembler(
        payloadIdHex: 'test-002',
        totalBytes: 500,
        chunkCount: 3,
        sha256Hash: hash,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      // Split manually: 200 + 200 + 100
      reassembler.addChunk(0, Uint8List.sublistView(payload, 0, 200));
      reassembler.addChunk(1, Uint8List.sublistView(payload, 200, 400));
      reassembler.addChunk(2, Uint8List.sublistView(payload, 400, 500));

      final result = reassembler.tryReassemble();
      expect(result, isA<ReassemblySuccess>());
      expect((result as ReassemblySuccess).payload, payload);
    });

    test('out-of-order chunk arrival', () {
      final (payload, hash) = makePayload(600);

      final reassembler = PayloadReassembler(
        payloadIdHex: 'test-003',
        totalBytes: 600,
        chunkCount: 3,
        sha256Hash: hash,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      // Arrive in reverse order
      reassembler.addChunk(2, Uint8List.sublistView(payload, 400, 600));
      reassembler.addChunk(0, Uint8List.sublistView(payload, 0, 200));
      reassembler.addChunk(1, Uint8List.sublistView(payload, 200, 400));

      final result = reassembler.tryReassemble();
      expect(result, isA<ReassemblySuccess>());
      expect((result as ReassemblySuccess).payload, payload);
    });

    test('duplicate chunks are ignored', () {
      final (payload, hash) = makePayload(200);

      final reassembler = PayloadReassembler(
        payloadIdHex: 'test-004',
        totalBytes: 200,
        chunkCount: 1,
        sha256Hash: hash,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(reassembler.addChunk(0, payload), isTrue);
      expect(reassembler.addChunk(0, payload), isFalse); // Duplicate
      expect(reassembler.receivedCount, 1);
    });

    test('missing chunk blocks completion', () {
      final (_, hash) = makePayload(400);

      final reassembler = PayloadReassembler(
        payloadIdHex: 'test-005',
        totalBytes: 400,
        chunkCount: 2,
        sha256Hash: hash,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      reassembler.addChunk(0, Uint8List(200));
      // Chunk 1 not added

      final result = reassembler.tryReassemble();
      expect(result, isA<ReassemblyIncomplete>());
      final incomplete = result as ReassemblyIncomplete;
      expect(incomplete.receivedCount, 1);
      expect(incomplete.totalCount, 2);
      expect(incomplete.missingIndexes, [1]);
    });

    test('SHA-256 mismatch is detected', () {
      final payload = Uint8List.fromList(List.generate(100, (i) => i));
      final wrongHash = Uint8List(32); // All zeros

      final reassembler = PayloadReassembler(
        payloadIdHex: 'test-006',
        totalBytes: 100,
        chunkCount: 1,
        sha256Hash: wrongHash,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      reassembler.addChunk(0, payload);

      final result = reassembler.tryReassemble();
      expect(result, isA<ReassemblyFailed>());
      expect((result as ReassemblyFailed).reason, contains('SHA-256'));
    });

    test('size mismatch is detected', () {
      final payload = Uint8List(50);
      final hash = Uint8List.fromList(sha256.convert(payload).bytes);

      final reassembler = PayloadReassembler(
        payloadIdHex: 'test-007',
        totalBytes: 100, // Declared 100 but actual is 50
        chunkCount: 1,
        sha256Hash: hash,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      reassembler.addChunk(0, payload);

      final result = reassembler.tryReassemble();
      expect(result, isA<ReassemblyFailed>());
      expect((result as ReassemblyFailed).reason, contains('size mismatch'));
    });

    test('chunk index out of range is rejected', () {
      final reassembler = PayloadReassembler(
        payloadIdHex: 'test-008',
        totalBytes: 200,
        chunkCount: 1,
        sha256Hash: Uint8List(32),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(reassembler.addChunk(1, Uint8List(100)), isFalse);
      expect(reassembler.addChunk(-1, Uint8List(100)), isFalse);
      expect(reassembler.receivedCount, 0);
    });

    test('chunks after finalization are rejected', () {
      final (payload, hash) = makePayload(100);

      final reassembler = PayloadReassembler(
        payloadIdHex: 'test-009',
        totalBytes: 100,
        chunkCount: 1,
        sha256Hash: hash,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      reassembler.addChunk(0, payload);
      reassembler.tryReassemble(); // Finalizes

      expect(reassembler.addChunk(0, payload), isFalse);
      expect(reassembler.isFinalized, isTrue);
    });

    test('double reassembly returns failure', () {
      final (payload, hash) = makePayload(100);

      final reassembler = PayloadReassembler(
        payloadIdHex: 'test-010',
        totalBytes: 100,
        chunkCount: 1,
        sha256Hash: hash,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      reassembler.addChunk(0, payload);
      reassembler.tryReassemble(); // First: success

      final result = reassembler.tryReassemble(); // Second: fail
      expect(result, isA<ReassemblyFailed>());
    });

    test('getMissingIndexes returns correct gaps', () {
      final reassembler = PayloadReassembler(
        payloadIdHex: 'test-011',
        totalBytes: 1000,
        chunkCount: 5,
        sha256Hash: Uint8List(32),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      reassembler.addChunk(0, Uint8List(200));
      reassembler.addChunk(3, Uint8List(200));

      expect(reassembler.getMissingIndexes(), [1, 2, 4]);
    });

    test('progress tracks correctly', () {
      final reassembler = PayloadReassembler(
        payloadIdHex: 'test-012',
        totalBytes: 800,
        chunkCount: 4,
        sha256Hash: Uint8List(32),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(reassembler.progress, 0.0);
      reassembler.addChunk(0, Uint8List(200));
      expect(reassembler.progress, 0.25);
      reassembler.addChunk(1, Uint8List(200));
      expect(reassembler.progress, 0.5);
    });

    test('dispose prevents further operations', () {
      final reassembler = PayloadReassembler(
        payloadIdHex: 'test-013',
        totalBytes: 100,
        chunkCount: 1,
        sha256Hash: Uint8List(32),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      reassembler.dispose();
      expect(reassembler.isFinalized, isTrue);
      expect(reassembler.addChunk(0, Uint8List(100)), isFalse);
    });

    test('isExpired returns true after expiry', () {
      final reassembler = PayloadReassembler(
        payloadIdHex: 'test-014',
        totalBytes: 100,
        chunkCount: 1,
        sha256Hash: Uint8List(32),
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );

      expect(reassembler.isExpired, isTrue);
    });

    test('reconstruction equals original bytes for mixed payload types', () {
      // Simulate image bytes
      final imagePayload = Uint8List.fromList(
        List.generate(2048, (i) => (i * 7 + 13) % 256),
      );
      final imageHash = Uint8List.fromList(sha256.convert(imagePayload).bytes);

      final reassembler = PayloadReassembler(
        payloadIdHex: 'mixed-type',
        totalBytes: 2048,
        chunkCount: 11, // 2048 / 200 = 10.24 -> 11
        sha256Hash: imageHash,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      // Add chunks with correct boundaries
      const chunkSize = 200;
      for (var i = 0; i < 11; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize).clamp(0, 2048);
        reassembler.addChunk(
          i,
          Uint8List.sublistView(imagePayload, start, end),
        );
      }

      final result = reassembler.tryReassemble();
      expect(result, isA<ReassemblySuccess>());
      expect((result as ReassemblySuccess).payload, imagePayload);
    });
  });
}
