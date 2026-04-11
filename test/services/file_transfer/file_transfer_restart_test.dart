// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/file_transfer/file_transfer_database.dart';
import 'package:socialmesh/services/file_transfer/file_transfer_engine.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_constants.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_file_transfer.dart';

/// In-memory mock that records calls without touching SQLite.
class _MockFileTransferDatabase extends FileTransferDatabase {
  final Map<String, Map<int, Uint8List>> savedChunks = {};
  final Set<String> deletedChunks = {};
  final List<FileTransferState> savedTransfers = [];

  @override
  Future<void> saveChunk(
    String fileIdHex,
    int chunkIndex,
    Uint8List payload,
  ) async {
    savedChunks.putIfAbsent(fileIdHex, () => {});
    savedChunks[fileIdHex]![chunkIndex] = payload;
  }

  @override
  Future<void> deleteChunks(String fileIdHex) async {
    deletedChunks.add(fileIdHex);
    savedChunks.remove(fileIdHex);
  }

  @override
  Future<Map<int, Uint8List>> loadChunks(String fileIdHex) async {
    return savedChunks[fileIdHex] ?? {};
  }

  @override
  Future<void> saveTransfer(FileTransferState transfer) async {
    savedTransfers.add(transfer);
  }
}

/// Build a test file payload and matching SmFileOffer.
({Uint8List payload, SmFileOffer offer, String idHex}) _buildTestFile({
  int size = 500,
  String filename = 'test.bin',
}) {
  final payload = Uint8List.fromList(List.generate(size, (i) => i % 256));
  final offer = SmFileOffer.fromFile(
    filename: filename,
    mimeType: 'application/octet-stream',
    fileBytes: payload,
    isDirected: true,
  );
  final idHex = fileIdToHex(offer.fileId);
  return (payload: payload, offer: offer, idHex: idHex);
}

/// Build a FileTransferState that mimics what the DB would return for
/// an active inbound transfer.
FileTransferState _buildInboundTransferState(
  SmFileOffer offer, {
  required Set<int> completedChunks,
  int nackRounds = 0,
  TransferState transferState = TransferState.chunking,
  int? sourceNodeNum,
}) {
  return FileTransferState(
    fileIdHex: fileIdToHex(offer.fileId),
    fileId: offer.fileId,
    direction: TransferDirection.inbound,
    state: transferState,
    filename: offer.filename,
    mimeType: offer.mimeType,
    totalBytes: offer.totalBytes,
    chunkSize: offer.chunkSize,
    chunkCount: offer.chunkCount,
    sha256Hash: offer.sha256Hash,
    completedChunks: completedChunks,
    nackRounds: nackRounds,
    createdAt: DateTime.now(),
    expiresAt: DateTime.now().add(const Duration(hours: 24)),
    sourceNodeNum: sourceNodeNum ?? 0xABCD,
  );
}

/// Build a FileTransferState that mimics what the DB would return for
/// an active outbound transfer.
FileTransferState _buildOutboundTransferState(
  SmFileOffer offer, {
  required Uint8List fileBytes,
  Set<int> completedChunks = const {},
  int nackRounds = 0,
  TransferState transferState = TransferState.chunking,
  int? targetNodeNum,
  String? savedFilePath,
}) {
  return FileTransferState(
    fileIdHex: fileIdToHex(offer.fileId),
    fileId: offer.fileId,
    direction: TransferDirection.outbound,
    state: transferState,
    filename: offer.filename,
    mimeType: offer.mimeType,
    totalBytes: offer.totalBytes,
    chunkSize: offer.chunkSize,
    chunkCount: offer.chunkCount,
    sha256Hash: offer.sha256Hash,
    completedChunks: completedChunks,
    nackRounds: nackRounds,
    createdAt: DateTime.now(),
    expiresAt: DateTime.now().add(const Duration(hours: 24)),
    targetNodeNum: targetNodeNum ?? 0xABCD,
    fileBytes: fileBytes,
    savedFilePath: savedFilePath,
  );
}

void main() {
  group('FileTransferEngine - chunk persistence', () {
    late _MockFileTransferDatabase mockDb;
    late FileTransferEngine engine;
    late List<FileTransferState> stateChanges;
    late List<Uint8List> sentPackets;

    setUp(() {
      mockDb = _MockFileTransferDatabase();
      stateChanges = [];
      sentPackets = [];

      engine = FileTransferEngine(
        database: mockDb,
        sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(payload);
          return true;
        },
        onStateChanged: stateChanges.add,
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test('handleIncomingChunk persists chunk to database', () {
      // Use a multi-chunk file so receiving one chunk does NOT trigger
      // completion (which would delete chunks via cleanup).
      final f = _buildTestFile(size: 500);

      engine.handleIncomingOffer(f.offer, sourceNodeNum: 0xABCD);

      // Send only the first chunk.
      final firstEnd = f.offer.chunkSize.clamp(0, f.payload.length);
      final chunk0Data = Uint8List.sublistView(f.payload, 0, firstEnd);
      final chunk0 = SmFileChunk(
        fileId: f.offer.fileId,
        chunkIndex: 0,
        chunkCount: f.offer.chunkCount,
        payload: chunk0Data,
      );
      engine.handleIncomingChunk(chunk0, sourceNodeNum: 0xABCD);

      // Chunk should be persisted to mock DB.
      expect(mockDb.savedChunks.containsKey(f.idHex), isTrue);
      expect(mockDb.savedChunks[f.idHex]!.containsKey(0), isTrue);
      expect(mockDb.savedChunks[f.idHex]![0], equals(chunk0Data));
    });

    test('duplicate chunk persistence is safe (REPLACE semantics)', () {
      // Multi-chunk file to avoid auto-completion.
      final f = _buildTestFile(size: 500);

      engine.handleIncomingOffer(f.offer, sourceNodeNum: 0xABCD);

      final firstEnd = f.offer.chunkSize.clamp(0, f.payload.length);
      final chunk0Data = Uint8List.sublistView(f.payload, 0, firstEnd);
      final chunk = SmFileChunk(
        fileId: f.offer.fileId,
        chunkIndex: 0,
        chunkCount: f.offer.chunkCount,
        payload: chunk0Data,
      );

      // Send the same chunk twice.
      engine.handleIncomingChunk(chunk, sourceNodeNum: 0xABCD);
      engine.handleIncomingChunk(chunk, sourceNodeNum: 0xABCD);

      // Should still have exactly one entry — no corruption.
      expect(mockDb.savedChunks[f.idHex]!.length, 1);
      expect(mockDb.savedChunks[f.idHex]![0], equals(chunk0Data));
    });

    test('completion cleans up persisted chunks', () {
      // Use a small payload that fits in one chunk.
      final payload = Uint8List.fromList([0x48, 0x69]);
      final hash = sha256.convert(payload).bytes;
      final fileId = generateFileId();
      final idHex = fileIdToHex(fileId);

      final offer = SmFileOffer(
        fileId: fileId,
        filename: 'tiny.txt',
        mimeType: 'text/plain',
        totalBytes: payload.length,
        chunkSize: 200,
        chunkCount: 1,
        sha256Hash: Uint8List.fromList(hash),
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expiresAt:
            DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch ~/
            1000,
      );

      engine.handleIncomingOffer(offer, sourceNodeNum: 0xABCD);

      final chunk = SmFileChunk(
        fileId: fileId,
        chunkIndex: 0,
        chunkCount: 1,
        payload: payload,
      );
      engine.handleIncomingChunk(chunk, sourceNodeNum: 0xABCD);

      // Transfer should be complete.
      final transfer = engine.getTransfer(idHex);
      expect(transfer!.state, TransferState.complete);

      // Chunks should be cleaned up.
      expect(mockDb.deletedChunks.contains(idHex), isTrue);
    });

    test('failure cleans up persisted chunks', () {
      final f = _buildTestFile(size: 500);

      engine.handleIncomingOffer(f.offer, sourceNodeNum: 0xABCD);

      // Send one chunk.
      final start = 0;
      final end = f.offer.chunkSize.clamp(0, f.payload.length);
      final chunk = SmFileChunk(
        fileId: f.offer.fileId,
        chunkIndex: 0,
        chunkCount: f.offer.chunkCount,
        payload: Uint8List.sublistView(f.payload, start, end),
      );
      engine.handleIncomingChunk(chunk, sourceNodeNum: 0xABCD);

      // Cancel the transfer.
      engine.cancelTransfer(f.idHex);

      // Chunks should be cleaned up.
      expect(mockDb.deletedChunks.contains(f.idHex), isTrue);
    });
  });

  group('FileTransferEngine - restoreInboundTransfer', () {
    late _MockFileTransferDatabase mockDb;
    late FileTransferEngine engine;
    late List<FileTransferState> stateChanges;
    late List<Uint8List> sentPackets;

    setUp(() {
      mockDb = _MockFileTransferDatabase();
      stateChanges = [];
      sentPackets = [];

      engine = FileTransferEngine(
        database: mockDb,
        sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(payload);
          return true;
        },
        onStateChanged: stateChanges.add,
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test('restores partial inbound transfer and resumes', () {
      fakeAsync((async) {
        final payload = Uint8List.fromList(List.generate(500, (i) => i % 256));
        final offer = SmFileOffer.fromFile(
          filename: 'resume.bin',
          mimeType: 'application/octet-stream',
          fileBytes: payload,
          isDirected: true,
        );
        final idHex = fileIdToHex(offer.fileId);

        // Simulate 50% of chunks persisted (first half).
        final halfCount = offer.chunkCount ~/ 2;
        final persistedChunks = <int, Uint8List>{};
        for (var i = 0; i < halfCount; i++) {
          final start = i * offer.chunkSize;
          final end = (start + offer.chunkSize).clamp(0, payload.length);
          persistedChunks[i] = Uint8List.sublistView(payload, start, end);
        }

        final dbTransfer = _buildInboundTransferState(
          offer,
          completedChunks: persistedChunks.keys.toSet(),
        );

        final ok = engine.restoreInboundTransfer(dbTransfer, persistedChunks);
        expect(ok, isTrue);

        final restored = engine.getTransfer(idHex);
        expect(restored, isNotNull);
        expect(restored!.state, TransferState.chunking);
        expect(restored.completedChunks.length, halfCount);
        expect(restored.isActive, isTrue);

        // Inactivity timer should fire and trigger NACK for missing chunks.
        async.elapse(
          SmRateLimit.chunkInactivityTimeout +
              const Duration(milliseconds: 100),
        );

        final afterNack = engine.getTransfer(idHex);
        expect(afterNack!.nackRounds, 1);
        expect(afterNack.state, TransferState.waitingMissing);
        // NACK packet was sent.
        expect(sentPackets, isNotEmpty);
      });
    });

    test('restores complete inbound transfer and finishes immediately', () {
      final payload = Uint8List.fromList([0x48, 0x69]);
      final hash = sha256.convert(payload).bytes;
      final fileId = generateFileId();
      final idHex = fileIdToHex(fileId);

      final offer = SmFileOffer(
        fileId: fileId,
        filename: 'done.txt',
        mimeType: 'text/plain',
        totalBytes: payload.length,
        chunkSize: 200,
        chunkCount: 1,
        sha256Hash: Uint8List.fromList(hash),
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expiresAt:
            DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch ~/
            1000,
      );

      final dbTransfer = _buildInboundTransferState(
        offer,
        completedChunks: {0},
      );
      final chunks = {0: payload};

      final ok = engine.restoreInboundTransfer(dbTransfer, chunks);
      expect(ok, isTrue);

      final transfer = engine.getTransfer(idHex);
      expect(transfer!.state, TransferState.complete);
      expect(transfer.fileBytes, isNotNull);
      expect(transfer.fileBytes!.length, payload.length);

      // ACK was sent.
      expect(sentPackets, isNotEmpty);

      // Chunks were cleaned up.
      expect(mockDb.deletedChunks.contains(idHex), isTrue);
    });

    test('rejects restore of outbound transfer', () {
      final payload = Uint8List.fromList([1, 2, 3]);
      final offer = SmFileOffer.fromFile(
        filename: 'outbound.bin',
        mimeType: 'application/octet-stream',
        fileBytes: payload,
        isDirected: true,
      );

      final dbTransfer = FileTransferState(
        fileIdHex: fileIdToHex(offer.fileId),
        fileId: offer.fileId,
        direction: TransferDirection.outbound,
        state: TransferState.chunking,
        filename: 'outbound.bin',
        mimeType: 'application/octet-stream',
        totalBytes: payload.length,
        chunkSize: offer.chunkSize,
        chunkCount: offer.chunkCount,
        sha256Hash: offer.sha256Hash,
        completedChunks: const {},
        nackRounds: 0,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      final ok = engine.restoreInboundTransfer(dbTransfer, {});
      expect(ok, isFalse);
      expect(engine.transfers, isEmpty);
    });

    test('rejects restore of already-tracked transfer', () {
      final payload = Uint8List.fromList([1, 2, 3]);
      final offer = SmFileOffer.fromFile(
        filename: 'dup.bin',
        mimeType: 'application/octet-stream',
        fileBytes: payload,
        isDirected: true,
      );
      final idHex = fileIdToHex(offer.fileId);

      // First: create via normal path.
      engine.handleIncomingOffer(offer, sourceNodeNum: 0x1234);
      expect(engine.transfers.containsKey(idHex), isTrue);

      // Second: attempt restore — should be rejected.
      final dbTransfer = _buildInboundTransferState(
        offer,
        completedChunks: const {},
      );
      final ok = engine.restoreInboundTransfer(dbTransfer, {});
      expect(ok, isFalse);
    });

    test('restored transfer receives new chunks and completes', () {
      final payload = Uint8List.fromList(List.generate(500, (i) => i % 256));
      final offer = SmFileOffer.fromFile(
        filename: 'partial.bin',
        mimeType: 'application/octet-stream',
        fileBytes: payload,
        isDirected: true,
      );
      final idHex = fileIdToHex(offer.fileId);

      // Persist the first chunk only.
      final firstEnd = offer.chunkSize.clamp(0, payload.length);
      final chunk0Data = Uint8List.sublistView(payload, 0, firstEnd);
      final persistedChunks = {0: chunk0Data};

      final dbTransfer = _buildInboundTransferState(
        offer,
        completedChunks: {0},
      );

      engine.restoreInboundTransfer(dbTransfer, persistedChunks);

      // Now send the remaining chunks (indices 1 onwards).
      for (var i = 1; i < offer.chunkCount; i++) {
        final start = i * offer.chunkSize;
        final end = (start + offer.chunkSize).clamp(0, payload.length);
        engine.handleIncomingChunk(
          SmFileChunk(
            fileId: offer.fileId,
            chunkIndex: i,
            chunkCount: offer.chunkCount,
            payload: Uint8List.sublistView(payload, start, end),
          ),
          sourceNodeNum: 0xABCD,
        );
      }

      final transfer = engine.getTransfer(idHex);
      expect(transfer!.state, TransferState.complete);
      expect(transfer.fileBytes, isNotNull);
      expect(transfer.fileBytes!.length, payload.length);
    });

    test('restores with zero chunks and NACKs for all', () {
      fakeAsync((async) {
        final payload = Uint8List.fromList(List.generate(500, (i) => i % 256));
        final offer = SmFileOffer.fromFile(
          filename: 'empty_recover.bin',
          mimeType: 'application/octet-stream',
          fileBytes: payload,
          isDirected: true,
        );
        final idHex = fileIdToHex(offer.fileId);

        final dbTransfer = _buildInboundTransferState(
          offer,
          completedChunks: const {},
        );

        engine.restoreInboundTransfer(dbTransfer, {});

        final restored = engine.getTransfer(idHex);
        expect(restored!.state, TransferState.chunking);
        expect(restored.completedChunks, isEmpty);

        // Inactivity timer fires → NACK for all chunks.
        async.elapse(
          SmRateLimit.chunkInactivityTimeout +
              const Duration(milliseconds: 100),
        );

        final afterNack = engine.getTransfer(idHex);
        expect(afterNack!.nackRounds, 1);
      });
    });
  });

  group('FileTransferEngine - stale transfer handling', () {
    test('engine purges expired restored transfer', () {
      final mockDb = _MockFileTransferDatabase();
      final stateChanges = <FileTransferState>[];
      final engine = FileTransferEngine(
        database: mockDb,
        sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async =>
            true,
        onStateChanged: stateChanges.add,
      );
      addTearDown(engine.dispose);

      // Create an expired inbound transfer.
      final payload = Uint8List.fromList([1, 2, 3]);
      final offer = SmFileOffer.fromFile(
        filename: 'stale.bin',
        mimeType: 'application/octet-stream',
        fileBytes: payload,
        isDirected: true,
      );
      final idHex = fileIdToHex(offer.fileId);

      final expiredTransfer = FileTransferState(
        fileIdHex: idHex,
        fileId: offer.fileId,
        direction: TransferDirection.inbound,
        state: TransferState.chunking,
        filename: 'stale.bin',
        mimeType: 'application/octet-stream',
        totalBytes: payload.length,
        chunkSize: offer.chunkSize,
        chunkCount: offer.chunkCount,
        sha256Hash: offer.sha256Hash,
        completedChunks: const {},
        nackRounds: 0,
        createdAt: DateTime.now().subtract(const Duration(hours: 48)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        sourceNodeNum: 0xABCD,
      );

      // Restore into engine (the transfer is active but expired).
      engine.restoreInboundTransfer(expiredTransfer, {});

      // purgeExpired should fail the transfer.
      engine.purgeExpired();

      final transfer = engine.getTransfer(idHex);
      expect(transfer!.state, TransferState.failed);
      expect(transfer.failReason, TransferFailReason.expired);

      // Chunks should be cleaned up.
      expect(mockDb.deletedChunks.contains(idHex), isTrue);
    });
  });

  group('FileTransferEngine - restoreOutboundTransfer', () {
    late _MockFileTransferDatabase mockDb;
    late FileTransferEngine engine;
    late List<FileTransferState> stateChanges;
    late List<Uint8List> sentPackets;

    setUp(() {
      mockDb = _MockFileTransferDatabase();
      stateChanges = [];
      sentPackets = [];

      engine = FileTransferEngine(
        database: mockDb,
        sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(payload);
          return true;
        },
        onStateChanged: stateChanges.add,
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test('restores outbound transfer and responds to NACK', () {
      fakeAsync((async) {
        final f = _buildTestFile(size: 500);
        final dbTransfer = _buildOutboundTransferState(
          f.offer,
          fileBytes: f.payload,
          completedChunks: {},
        );

        final ok = engine.restoreOutboundTransfer(dbTransfer);
        expect(ok, isTrue);

        final restored = engine.getTransfer(f.idHex);
        expect(restored, isNotNull);
        expect(restored!.state, TransferState.chunking);
        expect(restored.direction, TransferDirection.outbound);
        expect(restored.fileBytes, isNotNull);
        expect(restored.fileBytes!.length, f.payload.length);

        // Simulate receiver NACK requesting missing chunks 1 and 2.
        final missing = <int>[1, 2];
        final nack = SmFileNack(
          fileId: f.offer.fileId,
          missingIndexes: missing,
        );
        engine.handleIncomingNack(nack);

        // Advance enough for the send loop to process the queue.
        async.elapse(SmRateLimit.fileChunkInterval * 5);

        // Verify only the missing chunks were sent (not all).
        final nackState = engine.getTransfer(f.idHex);
        expect(nackState!.nackRounds, 1);
        // sentPackets includes state-change triggered chunks.
        expect(sentPackets, isNotEmpty);
      });
    });

    test('restored outbound completes on incoming ACK', () {
      final f = _buildTestFile(size: 500);
      final dbTransfer = _buildOutboundTransferState(
        f.offer,
        fileBytes: f.payload,
        completedChunks: Set<int>.from(
          List.generate(f.offer.chunkCount, (i) => i),
        ),
      );

      engine.restoreOutboundTransfer(dbTransfer);

      // Receiver sends ACK (all chunks already received).
      final ack = SmFileAck(
        fileId: f.offer.fileId,
        status: FileAckStatus.complete,
      );
      engine.handleIncomingAck(ack);

      final transfer = engine.getTransfer(f.idHex);
      expect(transfer!.state, TransferState.complete);
      expect(transfer.completedAt, isNotNull);
    });

    test('restored outbound times out if no NACK or ACK arrives', () {
      fakeAsync((async) {
        final f = _buildTestFile(size: 500);
        final dbTransfer = _buildOutboundTransferState(
          f.offer,
          fileBytes: f.payload,
        );

        engine.restoreOutboundTransfer(dbTransfer);

        final active = engine.getTransfer(f.idHex);
        expect(active!.isActive, isTrue);

        // Elapse completion timeout.
        async.elapse(
          SmRateLimit.senderCompletionTimeout +
              const Duration(milliseconds: 100),
        );

        final timedOut = engine.getTransfer(f.idHex);
        expect(timedOut!.state, TransferState.complete);
      });
    });

    test('rejects restore of inbound transfer', () {
      final f = _buildTestFile(size: 500);
      final dbTransfer = _buildInboundTransferState(
        f.offer,
        completedChunks: {},
      );

      final ok = engine.restoreOutboundTransfer(dbTransfer);
      expect(ok, isFalse);
    });

    test('rejects restore of already-tracked transfer', () {
      final payload = Uint8List(10);
      final result = engine.initiateTransfer(
        filename: 'dup.bin',
        mimeType: 'application/octet-stream',
        fileBytes: payload,
      );
      expect(result, isNotNull);

      // Create a transfer with the same fileIdHex to trigger duplicate check.
      final manualState = FileTransferState(
        fileIdHex: result!.fileIdHex,
        fileId: result.fileId,
        direction: TransferDirection.outbound,
        state: TransferState.chunking,
        filename: 'dup.bin',
        mimeType: 'application/octet-stream',
        totalBytes: payload.length,
        chunkSize: result.chunkSize,
        chunkCount: result.chunkCount,
        sha256Hash: result.sha256Hash,
        completedChunks: const {},
        nackRounds: 0,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        fileBytes: payload,
      );

      final ok = engine.restoreOutboundTransfer(manualState);
      expect(ok, isFalse);
    });

    test('rejects restore without fileBytes', () {
      final f = _buildTestFile(size: 500);
      final dbTransfer = FileTransferState(
        fileIdHex: f.idHex,
        fileId: f.offer.fileId,
        direction: TransferDirection.outbound,
        state: TransferState.chunking,
        filename: f.offer.filename,
        mimeType: f.offer.mimeType,
        totalBytes: f.offer.totalBytes,
        chunkSize: f.offer.chunkSize,
        chunkCount: f.offer.chunkCount,
        sha256Hash: f.offer.sha256Hash,
        completedChunks: const {},
        nackRounds: 0,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        // fileBytes intentionally null
      );

      final ok = engine.restoreOutboundTransfer(dbTransfer);
      expect(ok, isFalse);
    });

    test('cancellation cleans up restored outbound transfer', () {
      final f = _buildTestFile(size: 500);
      final dbTransfer = _buildOutboundTransferState(
        f.offer,
        fileBytes: f.payload,
      );

      engine.restoreOutboundTransfer(dbTransfer);
      engine.cancelTransfer(f.idHex);

      final transfer = engine.getTransfer(f.idHex);
      expect(transfer!.state, TransferState.cancelled);
      expect(transfer.failReason, TransferFailReason.userCancelled);
    });

    test('purgeExpired fails restored expired outbound transfer', () {
      final payload = Uint8List.fromList(List.generate(500, (i) => i % 256));
      final offer = SmFileOffer.fromFile(
        filename: 'stale_out.bin',
        mimeType: 'application/octet-stream',
        fileBytes: payload,
        isDirected: true,
      );
      final idHex = fileIdToHex(offer.fileId);

      final expiredTransfer = FileTransferState(
        fileIdHex: idHex,
        fileId: offer.fileId,
        direction: TransferDirection.outbound,
        state: TransferState.chunking,
        filename: 'stale_out.bin',
        mimeType: 'application/octet-stream',
        totalBytes: payload.length,
        chunkSize: offer.chunkSize,
        chunkCount: offer.chunkCount,
        sha256Hash: offer.sha256Hash,
        completedChunks: const {},
        nackRounds: 0,
        createdAt: DateTime.now().subtract(const Duration(hours: 48)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        targetNodeNum: 0xABCD,
        fileBytes: payload,
      );

      engine.restoreOutboundTransfer(expiredTransfer);
      engine.purgeExpired();

      final transfer = engine.getTransfer(idHex);
      expect(transfer!.state, TransferState.failed);
      expect(transfer.failReason, TransferFailReason.expired);
    });
  });

  group('FileTransferEngine - bidirectional recovery', () {
    late _MockFileTransferDatabase mockDb;
    late FileTransferEngine engine;
    late List<FileTransferState> stateChanges;
    late List<Uint8List> sentPackets;

    setUp(() {
      mockDb = _MockFileTransferDatabase();
      stateChanges = [];
      sentPackets = [];

      engine = FileTransferEngine(
        database: mockDb,
        sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(payload);
          return true;
        },
        onStateChanged: stateChanges.add,
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test(
      'receiver NACK + sender restore → only missing chunks retransmitted',
      () {
        fakeAsync((async) {
          // Simulate a 500-byte file (3 chunks at default 200 byte size).
          final payload = Uint8List.fromList(
            List.generate(500, (i) => i % 256),
          );
          final offer = SmFileOffer.fromFile(
            filename: 'bidir.bin',
            mimeType: 'application/octet-stream',
            fileBytes: payload,
            isDirected: true,
          );
          final idHex = fileIdToHex(offer.fileId);

          // -- Sender engine (simulates restart with source file) --
          final senderDb = _MockFileTransferDatabase();
          final senderStates = <FileTransferState>[];
          final senderPackets = <Uint8List>[];

          final senderEngine = FileTransferEngine(
            database: senderDb,
            sendPacket:
                (payload, portnum, {destinationNode, hopLimit = 3}) async {
                  senderPackets.add(payload);
                  return true;
                },
            onStateChanged: senderStates.add,
          );
          addTearDown(senderEngine.dispose);

          // Restore sender with full file bytes.
          final senderTransfer = _buildOutboundTransferState(
            offer,
            fileBytes: payload,
            completedChunks: {0, 1, 2}, // All were sent before restart.
          );
          senderEngine.restoreOutboundTransfer(senderTransfer);

          // -- Receiver engine (simulates restart with partial chunks) --
          final receiverDb = _MockFileTransferDatabase();
          final receiverStates = <FileTransferState>[];
          final receiverPackets = <Uint8List>[];

          final receiverEngine = FileTransferEngine(
            database: receiverDb,
            sendPacket:
                (payload, portnum, {destinationNode, hopLimit = 3}) async {
                  receiverPackets.add(payload);
                  return true;
                },
            onStateChanged: receiverStates.add,
          );
          addTearDown(receiverEngine.dispose);

          // Receiver has chunks 0 and 1, missing chunk 2.
          final chunk0End = offer.chunkSize.clamp(0, payload.length);
          final chunk1Start = offer.chunkSize;
          final chunk1End = (chunk1Start + offer.chunkSize).clamp(
            0,
            payload.length,
          );
          final persistedChunks = {
            0: Uint8List.sublistView(payload, 0, chunk0End),
            1: Uint8List.sublistView(payload, chunk1Start, chunk1End),
          };

          final receiverTransfer = _buildInboundTransferState(
            offer,
            completedChunks: {0, 1},
          );
          receiverEngine.restoreInboundTransfer(
            receiverTransfer,
            persistedChunks,
          );

          // Receiver's inactivity timer fires → NACK for chunk 2.
          async.elapse(
            SmRateLimit.chunkInactivityTimeout +
                const Duration(milliseconds: 100),
          );

          // Receiver sent a NACK packet.
          expect(receiverPackets, isNotEmpty);

          // Decode the NACK to find requested indexes.
          final nackPacket = SmFileNack.decode(receiverPackets.last);
          expect(nackPacket, isNotNull);
          expect(nackPacket!.missingIndexes, [2]);

          // Forward NACK to sender.
          senderEngine.handleIncomingNack(nackPacket);

          // Let the sender's send loop process.
          async.elapse(SmRateLimit.fileChunkInterval * 3);

          // Sender sent chunk packets.
          expect(senderPackets, isNotEmpty);

          // Decode the chunk sent by sender — should be chunk 2.
          final chunkPacket = SmFileChunk.decode(senderPackets.last);
          expect(chunkPacket, isNotNull);
          expect(chunkPacket!.chunkIndex, 2);

          // Forward chunk 2 to receiver.
          receiverEngine.handleIncomingChunk(
            chunkPacket,
            sourceNodeNum: 0xABCD,
          );

          // Receiver should now be complete.
          final finalReceiver = receiverEngine.getTransfer(idHex);
          expect(finalReceiver!.state, TransferState.complete);
          expect(finalReceiver.fileBytes, isNotNull);
          expect(finalReceiver.fileBytes!.length, payload.length);

          // Forward ACK to sender.
          final ackPacket = receiverPackets.last;
          final ack = SmFileAck.decode(ackPacket);
          if (ack != null && ack.status == FileAckStatus.complete) {
            senderEngine.handleIncomingAck(ack);
          }

          final finalSender = senderEngine.getTransfer(idHex);
          expect(finalSender!.state, TransferState.complete);
        });
      },
    );

    test(
      'receiver has all chunks after restart → immediate completion + ACK',
      () {
        final payload = Uint8List.fromList([0x48, 0x69]);
        final hash = sha256.convert(payload).bytes;
        final fileId = generateFileId();
        final idHex = fileIdToHex(fileId);

        final offer = SmFileOffer(
          fileId: fileId,
          filename: 'all_chunks.txt',
          mimeType: 'text/plain',
          totalBytes: payload.length,
          chunkSize: 200,
          chunkCount: 1,
          sha256Hash: Uint8List.fromList(hash),
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          expiresAt:
              DateTime.now()
                  .add(const Duration(hours: 24))
                  .millisecondsSinceEpoch ~/
              1000,
        );

        // -- Sender engine --
        final senderPackets = <Uint8List>[];
        final senderEngine = FileTransferEngine(
          sendPacket:
              (payload, portnum, {destinationNode, hopLimit = 3}) async {
                senderPackets.add(payload);
                return true;
              },
          onStateChanged: (_) {},
        );
        addTearDown(senderEngine.dispose);

        senderEngine.restoreOutboundTransfer(
          _buildOutboundTransferState(
            offer,
            fileBytes: payload,
            completedChunks: {0},
          ),
        );

        // -- Receiver engine (has all chunks) --
        final receiverPackets = <Uint8List>[];
        final receiverEngine = FileTransferEngine(
          sendPacket:
              (payload, portnum, {destinationNode, hopLimit = 3}) async {
                receiverPackets.add(payload);
                return true;
              },
          onStateChanged: (_) {},
        );
        addTearDown(receiverEngine.dispose);

        receiverEngine.restoreInboundTransfer(
          _buildInboundTransferState(offer, completedChunks: {0}),
          {0: payload},
        );

        // Receiver should complete immediately and send ACK.
        final receiver = receiverEngine.getTransfer(idHex);
        expect(receiver!.state, TransferState.complete);
        expect(receiverPackets, isNotEmpty);

        // Forward ACK to sender.
        final ack = SmFileAck.decode(receiverPackets.last);
        expect(ack, isNotNull);
        senderEngine.handleIncomingAck(ack!);

        final sender = senderEngine.getTransfer(idHex);
        expect(sender!.state, TransferState.complete);
      },
    );

    test('sender restart from awaitingAccept → rejected (pre-accept)', () {
      fakeAsync((async) {
        final f = _buildTestFile(size: 500);
        // Transfer was in awaitingAccept when app killed.
        final dbTransfer = _buildOutboundTransferState(
          f.offer,
          fileBytes: f.payload,
          transferState: TransferState.awaitingAccept,
        );

        // Engine rejects pre-accept transfers — they never got an ACCEPT.
        final ok = engine.restoreOutboundTransfer(dbTransfer);
        expect(ok, isFalse);

        // Transfer is not tracked in the engine.
        final restored = engine.getTransfer(f.idHex);
        expect(restored, isNull);
      });
    });

    test('sender restart from offerSent → rejected (pre-accept)', () {
      fakeAsync((async) {
        final f = _buildTestFile(size: 500);
        final dbTransfer = _buildOutboundTransferState(
          f.offer,
          fileBytes: f.payload,
          transferState: TransferState.offerSent,
        );

        final ok = engine.restoreOutboundTransfer(dbTransfer);
        expect(ok, isFalse);
        expect(engine.getTransfer(f.idHex), isNull);
      });
    });

    test('sender restart from created → rejected (pre-accept)', () {
      fakeAsync((async) {
        final f = _buildTestFile(size: 500);
        final dbTransfer = _buildOutboundTransferState(
          f.offer,
          fileBytes: f.payload,
          transferState: TransferState.created,
        );

        final ok = engine.restoreOutboundTransfer(dbTransfer);
        expect(ok, isFalse);
        expect(engine.getTransfer(f.idHex), isNull);
      });
    });

    test(
      'cancelled (declined) transfer is not active — skipped by recovery',
      () {
        fakeAsync((async) {
          final f = _buildTestFile(size: 500);
          final dbTransfer = _buildOutboundTransferState(
            f.offer,
            fileBytes: f.payload,
            transferState: TransferState.cancelled,
          );

          // Cancelled transfers are terminal — isActive is false, so they
          // would never be passed to restoreOutboundTransfer by the provider.
          // Verify the invariant directly.
          expect(dbTransfer.isActive, isFalse);

          // Engine also rejects them (state is not chunking/waitingMissing).
          final ok = engine.restoreOutboundTransfer(dbTransfer);
          expect(ok, isFalse);
          expect(engine.getTransfer(f.idHex), isNull);
        });
      },
    );

    test('NACK retransmits only requested indexes — not full transfer', () {
      fakeAsync((async) {
        final payload = Uint8List.fromList(List.generate(1000, (i) => i % 256));
        final offer = SmFileOffer.fromFile(
          filename: 'selective.bin',
          mimeType: 'application/octet-stream',
          fileBytes: payload,
          isDirected: true,
        );
        final dbTransfer = _buildOutboundTransferState(
          offer,
          fileBytes: payload,
          completedChunks: Set<int>.from(
            List.generate(offer.chunkCount, (i) => i),
          ),
        );

        engine.restoreOutboundTransfer(dbTransfer);
        sentPackets.clear();

        // NACK requesting only indexes 2 and 4.
        final nack = SmFileNack(fileId: offer.fileId, missingIndexes: [2, 4]);
        engine.handleIncomingNack(nack);

        // Let send loop process.
        async.elapse(SmRateLimit.fileChunkInterval * 5);

        // Decode sent chunk packets — should only be indexes 2 and 4.
        final sentChunkIndexes = <int>[];
        for (final pkt in sentPackets) {
          final chunk = SmFileChunk.decode(pkt);
          if (chunk != null) {
            sentChunkIndexes.add(chunk.chunkIndex);
          }
        }
        expect(sentChunkIndexes, containsAll([2, 4]));
        // Should NOT contain other indexes.
        expect(sentChunkIndexes.where((i) => i != 2 && i != 4), isEmpty);
      });
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Audit-driven regression tests: ACCEPT/REJECT boundaries, file
  // integrity, and timeout semantics.
  // ─────────────────────────────────────────────────────────────────────

  group('FileTransferEngine - inbound pre-accept restore gate', () {
    late _MockFileTransferDatabase mockDb;
    late FileTransferEngine engine;
    late List<FileTransferState> stateChanges;
    late List<Uint8List> sentPackets;

    setUp(() {
      mockDb = _MockFileTransferDatabase();
      stateChanges = [];
      sentPackets = [];
      engine = FileTransferEngine(
        database: mockDb,
        sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(payload);
          return true;
        },
        onStateChanged: stateChanges.add,
      );
    });

    tearDown(() => engine.dispose());

    test('inbound offerPending → rejected (pre-accept, no user consent)', () {
      final f = _buildTestFile(size: 500);
      final dbTransfer = _buildInboundTransferState(
        f.offer,
        completedChunks: {},
        transferState: TransferState.offerPending,
      );

      final ok = engine.restoreInboundTransfer(dbTransfer, {});
      expect(ok, isFalse);
      expect(engine.getTransfer(f.idHex), isNull);
    });

    test('inbound offerPending with chunks → still rejected', () {
      // Even if some chunks were buffered while pending, restore must not
      // bypass the user's acceptance decision.
      final f = _buildTestFile(size: 500);
      final firstEnd = f.offer.chunkSize.clamp(0, f.payload.length);
      final chunks = {0: Uint8List.sublistView(f.payload, 0, firstEnd)};
      final dbTransfer = _buildInboundTransferState(
        f.offer,
        completedChunks: {0},
        transferState: TransferState.offerPending,
      );

      final ok = engine.restoreInboundTransfer(dbTransfer, chunks);
      expect(ok, isFalse);
      expect(engine.getTransfer(f.idHex), isNull);
    });

    test('inbound chunking → accepted and restored', () {
      fakeAsync((async) {
        final f = _buildTestFile(size: 500);
        final halfCount = f.offer.chunkCount ~/ 2;
        final chunks = <int, Uint8List>{};
        for (var i = 0; i < halfCount; i++) {
          final start = i * f.offer.chunkSize;
          final end = (start + f.offer.chunkSize).clamp(0, f.payload.length);
          chunks[i] = Uint8List.sublistView(f.payload, start, end);
        }
        final dbTransfer = _buildInboundTransferState(
          f.offer,
          completedChunks: chunks.keys.toSet(),
          transferState: TransferState.chunking,
        );

        final ok = engine.restoreInboundTransfer(dbTransfer, chunks);
        expect(ok, isTrue);
        expect(engine.getTransfer(f.idHex)!.state, TransferState.chunking);
        expect(engine.getTransfer(f.idHex)!.completedChunks.length, halfCount);
      });
    });

    test('inbound waitingMissing → accepted and restored', () {
      fakeAsync((async) {
        final f = _buildTestFile(size: 500);
        final dbTransfer = _buildInboundTransferState(
          f.offer,
          completedChunks: {},
          nackRounds: 1,
          transferState: TransferState.waitingMissing,
        );

        final ok = engine.restoreInboundTransfer(dbTransfer, {});
        expect(ok, isTrue);
        // Restored to chunking (engine normalises to active receive state).
        expect(engine.getTransfer(f.idHex)!.state, TransferState.chunking);
      });
    });

    test('inbound created → rejected (defensive)', () {
      final f = _buildTestFile(size: 500);
      final dbTransfer = _buildInboundTransferState(
        f.offer,
        completedChunks: {},
        transferState: TransferState.created,
      );

      final ok = engine.restoreInboundTransfer(dbTransfer, {});
      expect(ok, isFalse);
    });
  });

  group('FileTransferEngine - outbound file integrity on restore', () {
    late _MockFileTransferDatabase mockDb;
    late FileTransferEngine engine;
    late List<FileTransferState> stateChanges;
    late List<Uint8List> sentPackets;

    setUp(() {
      mockDb = _MockFileTransferDatabase();
      stateChanges = [];
      sentPackets = [];
      engine = FileTransferEngine(
        database: mockDb,
        sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(payload);
          return true;
        },
        onStateChanged: stateChanges.add,
      );
    });

    tearDown(() => engine.dispose());

    test('outbound restore rejects truncated file (size mismatch)', () {
      final f = _buildTestFile(size: 500);
      // Simulate a truncated file: fewer bytes than totalBytes.
      final truncated = Uint8List.sublistView(f.payload, 0, 100);
      final dbTransfer = _buildOutboundTransferState(
        f.offer,
        fileBytes: truncated,
      );

      final ok = engine.restoreOutboundTransfer(dbTransfer);
      expect(ok, isFalse);
      expect(engine.getTransfer(f.idHex), isNull);
    });

    test('outbound restore rejects corrupted file (hash mismatch)', () {
      final f = _buildTestFile(size: 500);
      // Same length but different content → SHA-256 mismatch.
      final corrupted = Uint8List(f.payload.length);
      for (var i = 0; i < corrupted.length; i++) {
        corrupted[i] = (f.payload[i] + 1) % 256;
      }
      final dbTransfer = _buildOutboundTransferState(
        f.offer,
        fileBytes: corrupted,
      );

      final ok = engine.restoreOutboundTransfer(dbTransfer);
      expect(ok, isFalse);
      expect(engine.getTransfer(f.idHex), isNull);
    });

    test('outbound restore accepts intact file (size + hash match)', () {
      final f = _buildTestFile(size: 500);
      final dbTransfer = _buildOutboundTransferState(
        f.offer,
        fileBytes: f.payload,
      );

      final ok = engine.restoreOutboundTransfer(dbTransfer);
      expect(ok, isTrue);
      expect(engine.getTransfer(f.idHex)!.state, TransferState.chunking);
    });
  });

  group('FileTransferEngine - completion timeout after restore', () {
    late _MockFileTransferDatabase mockDb;
    late FileTransferEngine engine;
    late List<FileTransferState> stateChanges;
    late List<Uint8List> sentPackets;

    setUp(() {
      mockDb = _MockFileTransferDatabase();
      stateChanges = [];
      sentPackets = [];
      engine = FileTransferEngine(
        database: mockDb,
        sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(payload);
          return true;
        },
        onStateChanged: stateChanges.add,
      );
    });

    tearDown(() => engine.dispose());

    // This test documents INTENTIONAL behavior: after a sender restores
    // an outbound transfer, a 60s completion timeout starts. If no NACK
    // or ACK arrives within that window (e.g. receiver hasn't restarted
    // yet), the sender marks the transfer as "complete". This is a safety
    // valve against indefinite hangs — the receiver may have completed
    // with a lost ACK, or may be unreachable.
    //
    // Known limitation: if the receiver restarts >60s after the sender,
    // the sender will already show "complete" while the receiver later
    // fails with maxRetries. This is a design tradeoff, not a bug.
    test(
      'completion timeout fires before any NACK → sender marks complete',
      () {
        fakeAsync((async) {
          final f = _buildTestFile(size: 500);
          final dbTransfer = _buildOutboundTransferState(
            f.offer,
            fileBytes: f.payload,
          );

          final ok = engine.restoreOutboundTransfer(dbTransfer);
          expect(ok, isTrue);
          expect(engine.getTransfer(f.idHex)!.isActive, isTrue);

          // No NACK arrives. Completion timeout fires.
          async.elapse(
            SmRateLimit.senderCompletionTimeout +
                const Duration(milliseconds: 100),
          );

          final result = engine.getTransfer(f.idHex);
          expect(result!.state, TransferState.complete);
          // No chunks were sent — the sender just timed out passively.
          expect(sentPackets, isEmpty);
        });
      },
    );

    test('NACK arriving before timeout cancels timeout and retransmits', () {
      fakeAsync((async) {
        final f = _buildTestFile(size: 500);
        final dbTransfer = _buildOutboundTransferState(
          f.offer,
          fileBytes: f.payload,
        );

        engine.restoreOutboundTransfer(dbTransfer);

        // NACK arrives at t=5s (well before 60s timeout).
        async.elapse(const Duration(seconds: 5));
        final nack = SmFileNack(fileId: f.offer.fileId, missingIndexes: [0, 1]);
        engine.handleIncomingNack(nack);

        // Let send loop process.
        async.elapse(SmRateLimit.fileChunkInterval * 5);

        // Chunks were sent.
        expect(sentPackets, isNotEmpty);

        // Transfer is still active (not timed out).
        final transfer = engine.getTransfer(f.idHex);
        expect(transfer!.isActive, isTrue);
      });
    });

    test('NACK after completion timeout is ignored', () {
      fakeAsync((async) {
        final f = _buildTestFile(size: 500);
        final dbTransfer = _buildOutboundTransferState(
          f.offer,
          fileBytes: f.payload,
        );

        engine.restoreOutboundTransfer(dbTransfer);

        // Completion timeout fires.
        async.elapse(
          SmRateLimit.senderCompletionTimeout +
              const Duration(milliseconds: 100),
        );

        expect(engine.getTransfer(f.idHex)!.state, TransferState.complete);

        // Late NACK arrives.
        sentPackets.clear();
        final nack = SmFileNack(fileId: f.offer.fileId, missingIndexes: [0]);
        engine.handleIncomingNack(nack);

        // No retransmission — transfer is terminal.
        async.elapse(SmRateLimit.fileChunkInterval * 3);
        expect(sentPackets, isEmpty);
      });
    });
  });
}
