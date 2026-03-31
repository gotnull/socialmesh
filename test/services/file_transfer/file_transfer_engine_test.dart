// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/file_transfer/file_transfer_engine.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_constants.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_file_transfer.dart';

void main() {
  group('FileTransferEngine - outbound', () {
    late FileTransferEngine engine;
    late List<FileTransferState> stateChanges;
    late List<Uint8List> sentPackets;

    setUp(() {
      stateChanges = [];
      sentPackets = [];

      engine = FileTransferEngine(
        sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(payload);
          return true;
        },
        onStateChanged: (state) {
          stateChanges.add(state);
        },
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test('rejects oversized files', () {
      final bytes = Uint8List(SmFileTransferLimits.maxFileSize + 1);
      final result = engine.initiateTransfer(
        filename: 'too_big.bin',
        mimeType: 'application/octet-stream',
        fileBytes: bytes,
      );
      expect(result, isNull);
    });

    test('rejects empty files', () {
      final result = engine.initiateTransfer(
        filename: 'empty.txt',
        mimeType: 'text/plain',
        fileBytes: Uint8List(0),
      );
      expect(result, isNull);
    });

    test('initiates transfer with correct metadata', () {
      final bytes = Uint8List.fromList(List.generate(100, (i) => i));
      final result = engine.initiateTransfer(
        filename: 'test.txt',
        mimeType: 'text/plain',
        fileBytes: bytes,
        targetNodeNum: 0x12345678,
      );

      expect(result, isNotNull);
      expect(result!.filename, 'test.txt');
      expect(result.mimeType, 'text/plain');
      expect(result.totalBytes, 100);
      expect(result.direction, TransferDirection.outbound);
      expect(result.state, TransferState.created);
      expect(result.targetNodeNum, 0x12345678);
      expect(result.progress, 0.0);
      expect(result.isActive, isTrue);
    });

    test('tracks transfer in engines map', () {
      final bytes = Uint8List(50);
      final result = engine.initiateTransfer(
        filename: 'f.bin',
        mimeType: 'application/octet-stream',
        fileBytes: bytes,
      );

      expect(engine.transfers, hasLength(1));
      expect(engine.getTransfer(result!.fileIdHex), isNotNull);
    });

    test('limits concurrent outbound transfers', () {
      for (var i = 0; i < SmRateLimit.maxConcurrentTransfers; i++) {
        final result = engine.initiateTransfer(
          filename: 'file$i.bin',
          mimeType: 'application/octet-stream',
          fileBytes: Uint8List(10),
        );
        expect(result, isNotNull);
      }

      // One more should fail
      final extra = engine.initiateTransfer(
        filename: 'extra.bin',
        mimeType: 'application/octet-stream',
        fileBytes: Uint8List(10),
      );
      expect(extra, isNull);
    });

    test('cancel sets state to cancelled', () {
      final bytes = Uint8List(50);
      final result = engine.initiateTransfer(
        filename: 'cancel_me.txt',
        mimeType: 'text/plain',
        fileBytes: bytes,
      );

      engine.cancelTransfer(result!.fileIdHex);

      final cancelled = engine.getTransfer(result.fileIdHex);
      expect(cancelled!.state, TransferState.cancelled);
      expect(cancelled.failReason, TransferFailReason.userCancelled);
      expect(cancelled.isActive, isFalse);
    });
  });

  group('FileTransferEngine - inbound', () {
    late FileTransferEngine engine;
    late List<FileTransferState> stateChanges;
    late List<Uint8List> sentPackets;

    setUp(() {
      stateChanges = [];
      sentPackets = [];

      engine = FileTransferEngine(
        sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async {
          sentPackets.add(payload);
          return true;
        },
        onStateChanged: (state) {
          stateChanges.add(state);
        },
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test('rejects oversized offers', () {
      final fileId = generateFileId();
      final offer = SmFileOffer(
        fileId: fileId,
        filename: 'huge.bin',
        mimeType: 'application/octet-stream',
        totalBytes: SmFileTransferLimits.maxFileSize + 1,
        chunkSize: 200,
        chunkCount: 100,
        sha256Hash: Uint8List(32),
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expiresAt:
            DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch ~/
            1000,
      );

      engine.handleIncomingOffer(offer, sourceNodeNum: 0xABCD);
      expect(engine.transfers, isEmpty);
    });

    test('accepts valid offer and creates inbound transfer', () {
      final fileId = generateFileId();
      final offer = SmFileOffer(
        fileId: fileId,
        filename: 'tiny.txt',
        mimeType: 'text/plain',
        totalBytes: 5,
        chunkSize: 200,
        chunkCount: 1,
        sha256Hash: Uint8List(32),
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expiresAt:
            DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch ~/
            1000,
      );

      engine.handleIncomingOffer(offer, sourceNodeNum: 0xABCD);
      expect(engine.transfers, hasLength(1));

      final idHex = fileIdToHex(fileId);
      final transfer = engine.getTransfer(idHex);
      expect(transfer, isNotNull);
      expect(transfer!.direction, TransferDirection.inbound);
      expect(transfer.state, TransferState.chunking);
      expect(transfer.sourceNodeNum, 0xABCD);
    });

    test('rejects duplicate offers', () {
      final fileId = generateFileId();
      final offer = SmFileOffer(
        fileId: fileId,
        filename: 'dup.txt',
        mimeType: 'text/plain',
        totalBytes: 5,
        chunkSize: 200,
        chunkCount: 1,
        sha256Hash: Uint8List(32),
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expiresAt:
            DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch ~/
            1000,
      );

      engine.handleIncomingOffer(offer, sourceNodeNum: 0xABCD);
      engine.handleIncomingOffer(offer, sourceNodeNum: 0xABCD);
      expect(engine.transfers, hasLength(1));
    });

    test('handles incoming ACK complete', () {
      // First create an outbound transfer
      final bytes = Uint8List(10);
      final transfer = engine.initiateTransfer(
        filename: 'ack_test.txt',
        mimeType: 'text/plain',
        fileBytes: bytes,
      )!;

      final ack = SmFileAck(
        fileId: transfer.fileId,
        status: FileAckStatus.complete,
      );

      engine.handleIncomingAck(ack);

      final updated = engine.getTransfer(transfer.fileIdHex);
      expect(updated!.state, TransferState.complete);
      expect(updated.completedAt, isNotNull);
    });

    test('handles incoming ACK rejected', () {
      final bytes = Uint8List(10);
      final transfer = engine.initiateTransfer(
        filename: 'reject_test.txt',
        mimeType: 'text/plain',
        fileBytes: bytes,
      )!;

      final ack = SmFileAck(
        fileId: transfer.fileId,
        status: FileAckStatus.rejected,
      );

      engine.handleIncomingAck(ack);

      final updated = engine.getTransfer(transfer.fileIdHex);
      expect(updated!.state, TransferState.failed);
      expect(updated.failReason, TransferFailReason.invalid);
    });

    test('offer with autoAccept false creates offerPending state', () {
      final fileId = generateFileId();
      final offer = SmFileOffer(
        fileId: fileId,
        filename: 'pending.txt',
        mimeType: 'text/plain',
        totalBytes: 5,
        chunkSize: 200,
        chunkCount: 1,
        sha256Hash: Uint8List(32),
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expiresAt:
            DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch ~/
            1000,
      );

      engine.handleIncomingOffer(
        offer,
        sourceNodeNum: 0xABCD,
        autoAccept: false,
      );

      final idHex = fileIdToHex(fileId);
      final transfer = engine.getTransfer(idHex);
      expect(transfer, isNotNull);
      expect(transfer!.state, TransferState.offerPending);
      expect(transfer.isActive, isTrue);
    });

    test('acceptTransfer transitions from offerPending to chunking', () {
      final fileId = generateFileId();
      final offer = SmFileOffer(
        fileId: fileId,
        filename: 'accept_me.txt',
        mimeType: 'text/plain',
        totalBytes: 5,
        chunkSize: 200,
        chunkCount: 1,
        sha256Hash: Uint8List(32),
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expiresAt:
            DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch ~/
            1000,
      );

      engine.handleIncomingOffer(
        offer,
        sourceNodeNum: 0xABCD,
        autoAccept: false,
      );
      final idHex = fileIdToHex(fileId);

      engine.acceptTransfer(idHex);

      final transfer = engine.getTransfer(idHex);
      expect(transfer!.state, TransferState.chunking);
    });

    test('rejectTransfer cancels pending offer and sends rejection ACK', () {
      final fileId = generateFileId();
      final offer = SmFileOffer(
        fileId: fileId,
        filename: 'reject_me.txt',
        mimeType: 'text/plain',
        totalBytes: 5,
        chunkSize: 200,
        chunkCount: 1,
        sha256Hash: Uint8List(32),
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expiresAt:
            DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch ~/
            1000,
      );

      engine.handleIncomingOffer(
        offer,
        sourceNodeNum: 0xABCD,
        autoAccept: false,
      );
      final idHex = fileIdToHex(fileId);
      final packetsBefore = sentPackets.length;

      engine.rejectTransfer(idHex);

      final transfer = engine.getTransfer(idHex);
      expect(transfer!.state, TransferState.cancelled);
      expect(transfer.failReason, TransferFailReason.userCancelled);

      // Rejection ACK was sent
      expect(sentPackets.length, packetsBefore + 1);
    });

    test('chunks buffered during offerPending do not auto-complete', () {
      // Use a known SHA-256 so completion can verify
      final payload = Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]);
      final fileId = generateFileId();
      final offer = SmFileOffer.fromFile(
        filename: 'buffered.txt',
        mimeType: 'text/plain',
        fileBytes: payload,
        isDirected: true,
      );

      // Create pending offer with matching metadata
      final pendingOffer = SmFileOffer(
        fileId: fileId,
        filename: 'buffered.txt',
        mimeType: 'text/plain',
        totalBytes: payload.length,
        chunkSize: offer.chunkSize,
        chunkCount: offer.chunkCount,
        sha256Hash: offer.sha256Hash,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expiresAt:
            DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch ~/
            1000,
      );

      engine.handleIncomingOffer(
        pendingOffer,
        sourceNodeNum: 0x1234,
        autoAccept: false,
      );
      final idHex = fileIdToHex(fileId);

      // Send all chunks while still pending
      for (var i = 0; i < pendingOffer.chunkCount; i++) {
        final chunk = SmFileChunk(
          fileId: fileId,
          chunkIndex: i,
          chunkCount: pendingOffer.chunkCount,
          payload: payload,
        );
        engine.handleIncomingChunk(chunk, sourceNodeNum: 0x1234);
      }

      // Transfer should still be pending (not auto-completed)
      final pending = engine.getTransfer(idHex);
      expect(pending!.state, TransferState.offerPending);
      expect(pending.completedChunks.length, pendingOffer.chunkCount);
    });

    test('acceptTransfer auto-completes if all chunks already received', () {
      final payload = Uint8List.fromList([0x48, 0x69]);
      final fileId = generateFileId();
      final offer = SmFileOffer.fromFile(
        filename: 'instant.txt',
        mimeType: 'text/plain',
        fileBytes: payload,
        isDirected: true,
      );

      final pendingOffer = SmFileOffer(
        fileId: fileId,
        filename: 'instant.txt',
        mimeType: 'text/plain',
        totalBytes: payload.length,
        chunkSize: offer.chunkSize,
        chunkCount: offer.chunkCount,
        sha256Hash: offer.sha256Hash,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expiresAt:
            DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch ~/
            1000,
      );

      engine.handleIncomingOffer(
        pendingOffer,
        sourceNodeNum: 0x1234,
        autoAccept: false,
      );
      final idHex = fileIdToHex(fileId);

      // Send the chunk (payload IS the file for single-chunk)
      final chunk = SmFileChunk(
        fileId: fileId,
        chunkIndex: 0,
        chunkCount: 1,
        payload: payload,
      );
      engine.handleIncomingChunk(chunk, sourceNodeNum: 0x1234);

      // Now accept — should auto-complete and verify hash
      engine.acceptTransfer(idHex);

      final transfer = engine.getTransfer(idHex);
      expect(transfer!.state, TransferState.complete);
      expect(transfer.fileBytes, isNotNull);
      expect(transfer.fileBytes!.length, payload.length);
    });
  });

  group('FileTransferEngine - purge', () {
    test('purges expired active transfers', () {
      final stateChanges = <FileTransferState>[];
      final engine = FileTransferEngine(
        sendPacket: (_, _, {destinationNode, hopLimit = 3}) async => true,
        onStateChanged: stateChanges.add,
      );
      addTearDown(engine.dispose);

      // Create a transfer with an already-expired time
      final fileId = generateFileId();
      final idHex = fileIdToHex(fileId);

      // Manually inject an expired transfer using the offer path
      final offer = SmFileOffer(
        fileId: fileId,
        filename: 'expired.txt',
        mimeType: 'text/plain',
        totalBytes: 5,
        chunkSize: 200,
        chunkCount: 1,
        sha256Hash: Uint8List(32),
        createdAt:
            DateTime.now()
                .subtract(const Duration(hours: 48))
                .millisecondsSinceEpoch ~/
            1000,
        expiresAt:
            DateTime.now()
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
      );

      engine.handleIncomingOffer(offer);
      expect(engine.transfers, hasLength(1));

      engine.purgeExpired();

      final transfer = engine.getTransfer(idHex);
      expect(transfer!.state, TransferState.failed);
      expect(transfer.failReason, TransferFailReason.expired);
    });
  });

  group('FileTransferState', () {
    test('progress calculates correctly', () {
      final state = FileTransferState(
        fileIdHex: 'test',
        fileId: Uint8List(16),
        direction: TransferDirection.outbound,
        state: TransferState.chunking,
        filename: 'test.bin',
        mimeType: 'application/octet-stream',
        totalBytes: 400,
        chunkSize: 200,
        chunkCount: 2,
        sha256Hash: Uint8List(2),
        completedChunks: {0},
        nackRounds: 0,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      expect(state.progress, 0.5);
    });

    test('missingChunks returns correct indexes', () {
      final state = FileTransferState(
        fileIdHex: 'test',
        fileId: Uint8List(16),
        direction: TransferDirection.inbound,
        state: TransferState.chunking,
        filename: 'test.bin',
        mimeType: 'application/octet-stream',
        totalBytes: 600,
        chunkSize: 200,
        chunkCount: 3,
        sha256Hash: Uint8List(2),
        completedChunks: {0, 2},
        nackRounds: 0,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      expect(state.missingChunks, [1]);
    });

    test('isActive for terminal states', () {
      for (final terminalState in [
        TransferState.complete,
        TransferState.failed,
        TransferState.cancelled,
      ]) {
        final state = FileTransferState(
          fileIdHex: 'test',
          fileId: Uint8List(16),
          direction: TransferDirection.outbound,
          state: terminalState,
          filename: 'test.bin',
          mimeType: 'application/octet-stream',
          totalBytes: 100,
          chunkSize: 100,
          chunkCount: 1,
          sha256Hash: Uint8List(2),
          completedChunks: const {},
          nackRounds: 0,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );
        expect(state.isActive, isFalse);
      }
    });

    test('copyWith preserves unchanged fields', () {
      final original = FileTransferState(
        fileIdHex: 'abc123',
        fileId: Uint8List(16),
        direction: TransferDirection.outbound,
        state: TransferState.created,
        filename: 'important.txt',
        mimeType: 'text/plain',
        totalBytes: 500,
        chunkSize: 200,
        chunkCount: 3,
        sha256Hash: Uint8List(2),
        completedChunks: const {},
        nackRounds: 0,
        createdAt: DateTime(2025),
        expiresAt: DateTime(2025, 1, 2),
        targetNodeNum: 42,
      );

      final updated = original.copyWith(
        state: TransferState.chunking,
        completedChunks: {0},
      );

      expect(updated.fileIdHex, 'abc123');
      expect(updated.filename, 'important.txt');
      expect(updated.targetNodeNum, 42);
      expect(updated.state, TransferState.chunking);
      expect(updated.completedChunks, {0});
    });
  });

  group('FileTransferEngine - auto-NACK on inactivity', () {
    test('sends NACK when chunks stop arriving with gaps', () {
      fakeAsync((async) {
        final sentPackets = <Uint8List>[];
        final stateChanges = <FileTransferState>[];
        final engine = FileTransferEngine(
          sendPacket:
              (payload, portnum, {destinationNode, hopLimit = 3}) async {
                sentPackets.add(payload);
                return true;
              },
          onStateChanged: stateChanges.add,
        );
        addTearDown(engine.dispose);

        final fileId = generateFileId();
        final offer = SmFileOffer(
          fileId: fileId,
          filename: 'gaps.bin',
          mimeType: 'application/octet-stream',
          totalBytes: 600,
          chunkSize: 200,
          chunkCount: 3,
          sha256Hash: Uint8List(32),
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          expiresAt:
              DateTime.now()
                  .add(const Duration(hours: 24))
                  .millisecondsSinceEpoch ~/
              1000,
        );

        engine.handleIncomingOffer(offer, sourceNodeNum: 0xABCD);
        final idHex = fileIdToHex(fileId);

        // Send chunks 0 and 2, skip chunk 1 (simulating mesh drop)
        engine.handleIncomingChunk(
          SmFileChunk(
            fileId: fileId,
            chunkIndex: 0,
            chunkCount: 3,
            payload: Uint8List(200),
          ),
          sourceNodeNum: 0xABCD,
        );
        engine.handleIncomingChunk(
          SmFileChunk(
            fileId: fileId,
            chunkIndex: 2,
            chunkCount: 3,
            payload: Uint8List(200),
          ),
          sourceNodeNum: 0xABCD,
        );

        // Before timeout: still chunking, no NACK sent
        final transfer = engine.getTransfer(idHex);
        expect(transfer!.state, TransferState.chunking);
        expect(transfer.completedChunks.length, 2);
        final packetsBefore = sentPackets.length;

        // Advance past the inactivity timeout
        async.elapse(
          SmRateLimit.chunkInactivityTimeout +
              const Duration(milliseconds: 100),
        );

        // Now a NACK should have been sent and state → waitingMissing
        final updated = engine.getTransfer(idHex);
        expect(updated!.state, TransferState.waitingMissing);
        expect(updated.nackRounds, 1);
        // A NACK packet was sent
        expect(sentPackets.length, greaterThan(packetsBefore));
      });
    });

    test('does not NACK when all chunks received', () {
      fakeAsync((async) {
        final sentPackets = <Uint8List>[];
        final engine = FileTransferEngine(
          sendPacket:
              (payload, portnum, {destinationNode, hopLimit = 3}) async {
                sentPackets.add(payload);
                return true;
              },
          onStateChanged: (_) {},
        );
        addTearDown(engine.dispose);

        // Single-chunk transfer: all data arrives
        final payload = Uint8List.fromList([0x48, 0x69]);
        final fromFile = SmFileOffer.fromFile(
          filename: 'complete.bin',
          mimeType: 'application/octet-stream',
          fileBytes: payload,
          isDirected: true,
        );
        final fileId = generateFileId();
        final offer = SmFileOffer(
          fileId: fileId,
          filename: 'complete.bin',
          mimeType: 'application/octet-stream',
          totalBytes: payload.length,
          chunkSize: fromFile.chunkSize,
          chunkCount: fromFile.chunkCount,
          sha256Hash: fromFile.sha256Hash,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          expiresAt:
              DateTime.now()
                  .add(const Duration(hours: 24))
                  .millisecondsSinceEpoch ~/
              1000,
        );

        engine.handleIncomingOffer(offer, sourceNodeNum: 0xABCD);
        final idHex = fileIdToHex(fileId);

        // Send the only chunk
        engine.handleIncomingChunk(
          SmFileChunk(
            fileId: fileId,
            chunkIndex: 0,
            chunkCount: 1,
            payload: payload,
          ),
          sourceNodeNum: 0xABCD,
        );

        // Transfer should be complete (not chunking)
        final transfer = engine.getTransfer(idHex);
        expect(transfer!.state, TransferState.complete);

        // Advance past timeout — nothing should break
        final packetsBefore = sentPackets.length;
        async.elapse(SmRateLimit.chunkInactivityTimeout * 2);

        // No extra NACK packets sent
        // (only the ACK from completion was sent)
        expect(sentPackets.length, packetsBefore);
      });
    });

    test('inactivity timer resets on each new chunk', () {
      fakeAsync((async) {
        final sentPackets = <Uint8List>[];
        final engine = FileTransferEngine(
          sendPacket:
              (payload, portnum, {destinationNode, hopLimit = 3}) async {
                sentPackets.add(payload);
                return true;
              },
          onStateChanged: (_) {},
        );
        addTearDown(engine.dispose);

        final fileId = generateFileId();
        final offer = SmFileOffer(
          fileId: fileId,
          filename: 'slow.bin',
          mimeType: 'application/octet-stream',
          totalBytes: 600,
          chunkSize: 200,
          chunkCount: 3,
          sha256Hash: Uint8List(32),
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          expiresAt:
              DateTime.now()
                  .add(const Duration(hours: 24))
                  .millisecondsSinceEpoch ~/
              1000,
        );

        engine.handleIncomingOffer(offer, sourceNodeNum: 0xABCD);
        final idHex = fileIdToHex(fileId);

        // Chunk 0 arrives
        engine.handleIncomingChunk(
          SmFileChunk(
            fileId: fileId,
            chunkIndex: 0,
            chunkCount: 3,
            payload: Uint8List(200),
          ),
          sourceNodeNum: 0xABCD,
        );

        // Wait 8 seconds (< 10s timeout)
        async.elapse(const Duration(seconds: 8));

        // Chunk 2 arrives (still missing 1) — timer resets
        engine.handleIncomingChunk(
          SmFileChunk(
            fileId: fileId,
            chunkIndex: 2,
            chunkCount: 3,
            payload: Uint8List(200),
          ),
          sourceNodeNum: 0xABCD,
        );

        // 8s later — no NACK yet because timer was reset
        async.elapse(const Duration(seconds: 8));
        final transfer = engine.getTransfer(idHex);
        expect(transfer!.state, TransferState.chunking);
        expect(transfer.nackRounds, 0);

        // 3 more seconds — now past timeout since last chunk
        async.elapse(const Duration(seconds: 3));
        final updated = engine.getTransfer(idHex);
        expect(updated!.state, TransferState.waitingMissing);
        expect(updated.nackRounds, 1);
      });
    });
  });
}
