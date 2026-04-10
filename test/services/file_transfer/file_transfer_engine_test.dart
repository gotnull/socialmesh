// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/file_transfer/file_transfer_engine.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_constants.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_file_transfer.dart';
import 'package:socialmesh/services/security/stl_envelope.dart';

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

  group('FileTransferEngine - STL chunk sizing', () {
    late FileTransferEngine engine;

    setUp(() {
      engine = FileTransferEngine(
        sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async {
          return true;
        },
        onStateChanged: (_) {},
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test('uses default chunk size when no chunkSize specified', () {
      final bytes = Uint8List.fromList(List.generate(500, (i) => i % 256));
      final result = engine.initiateTransfer(
        filename: 'test.bin',
        mimeType: 'application/octet-stream',
        fileBytes: bytes,
      );

      expect(result, isNotNull);
      expect(result!.chunkSize, SmFileTransferLimits.defaultChunkSize);
    });

    test('uses custom chunk size when specified', () {
      final bytes = Uint8List.fromList(List.generate(500, (i) => i % 256));
      final result = engine.initiateTransfer(
        filename: 'test.bin',
        mimeType: 'application/octet-stream',
        fileBytes: bytes,
        chunkSize: 116,
      );

      expect(result, isNotNull);
      expect(result!.chunkSize, 116);
      // 500 bytes / 116 = 5 chunks (ceil)
      expect(result.chunkCount, 5);
    });

    test('STL-aware chunk size fits within LoRa MTU', () {
      final stlAwareChunkSize = computeStlAwareChunkSize(
        mtu: SmPayloadLimit.loraMtu,
        sppHeaderOverhead: SmFileTransferLimits.chunkHeaderOverhead,
        stlEnabled: true,
      );
      expect(stlAwareChunkSize, 116);

      final bytes = Uint8List.fromList(List.generate(500, (i) => i % 256));
      final result = engine.initiateTransfer(
        filename: 'test.bin',
        mimeType: 'application/octet-stream',
        fileBytes: bytes,
        chunkSize: stlAwareChunkSize,
      );

      expect(result, isNotNull);
      expect(result!.chunkSize, 116);

      // Each chunk wire size: chunkSize + header + STL = MTU
      final wireSize =
          result.chunkSize +
          SmFileTransferLimits.chunkHeaderOverhead +
          StlOverhead.wireOverheadSignedOnly;
      expect(wireSize, SmPayloadLimit.loraMtu);
    });

    test('STL encrypted chunk size fits within LoRa MTU', () {
      final encryptedChunkSize = computeStlAwareChunkSize(
        mtu: SmPayloadLimit.loraMtu,
        sppHeaderOverhead: SmFileTransferLimits.chunkHeaderOverhead,
        stlEnabled: true,
        stlEncrypted: true,
      );
      expect(encryptedChunkSize, 88);

      final bytes = Uint8List.fromList(List.generate(500, (i) => i % 256));
      final result = engine.initiateTransfer(
        filename: 'test.bin',
        mimeType: 'application/octet-stream',
        fileBytes: bytes,
        chunkSize: encryptedChunkSize,
      );

      expect(result, isNotNull);
      expect(result!.chunkSize, 88);

      // Wire: 88 + 23 + 126 = 237 = MTU
      final wireSize =
          result.chunkSize +
          SmFileTransferLimits.chunkHeaderOverhead +
          StlOverhead.wireOverheadEncrypted;
      expect(wireSize, SmPayloadLimit.loraMtu);
    });
  });

  // ─── Regression: sender completion & NACK recovery ──────────────────

  group('FileTransferEngine - sender completion deferral', () {
    test('sender stays active after sending all chunks (awaits ACK)', () {
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

        // Create a small 2-chunk file.
        final fileBytes = Uint8List.fromList(
          List.generate(400, (i) => i % 256),
        );
        final transfer = engine.initiateTransfer(
          filename: 'stay_active.bin',
          mimeType: 'application/octet-stream',
          fileBytes: fileBytes,
          targetNodeNum: 0x1234,
        )!;
        final idHex = transfer.fileIdHex;

        // Start → offer sent → awaitingAccept.
        engine.startTransfer(idHex);
        async.flushMicrotasks();

        // Simulate receiver ACCEPT → chunking.
        engine.resumeTransfer(idHex);

        // Advance enough for all chunks to send (2 chunks × 2s + margin).
        async.elapse(const Duration(seconds: 6));

        // All chunks sent but transfer must NOT be complete yet.
        final afterSend = engine.getTransfer(idHex)!;
        expect(afterSend.completedChunks.length, transfer.chunkCount);
        expect(afterSend.isActive, isTrue);
        expect(afterSend.state, isNot(TransferState.complete));

        // Simulate receiver ACK → now complete.
        engine.handleIncomingAck(
          SmFileAck(fileId: transfer.fileId, status: FileAckStatus.complete),
        );

        final completed = engine.getTransfer(idHex)!;
        expect(completed.state, TransferState.complete);
        expect(completed.completedAt, isNotNull);
      });
    });

    test('sender serves late NACK after all chunks sent', () {
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

        final fileBytes = Uint8List.fromList(
          List.generate(400, (i) => i % 256),
        );
        final transfer = engine.initiateTransfer(
          filename: 'late_nack.bin',
          mimeType: 'application/octet-stream',
          fileBytes: fileBytes,
          targetNodeNum: 0x1234,
        )!;
        final idHex = transfer.fileIdHex;

        engine.startTransfer(idHex);
        async.flushMicrotasks();
        engine.resumeTransfer(idHex);
        async.elapse(const Duration(seconds: 6));

        // All chunks sent, sender still active.
        expect(engine.getTransfer(idHex)!.isActive, isTrue);

        final packetsBefore = sentPackets.length;

        // Simulate late NACK for chunk 1.
        final nack = SmFileNack(fileId: transfer.fileId, missingIndexes: [1]);
        engine.handleIncomingNack(nack);
        async.flushMicrotasks();

        // NACK was processed (not ignored).
        final afterNack = engine.getTransfer(idHex)!;
        expect(afterNack.nackRounds, 1);
        expect(afterNack.state, TransferState.chunking);

        // Advance to let retransmission send.
        async.elapse(const Duration(seconds: 4));

        // Retransmitted chunk packet was sent.
        expect(sentPackets.length, greaterThan(packetsBefore));

        // Simulate receiver ACK → complete.
        engine.handleIncomingAck(
          SmFileAck(fileId: transfer.fileId, status: FileAckStatus.complete),
        );

        expect(engine.getTransfer(idHex)!.state, TransferState.complete);
      });
    });

    test('sender completion timeout fires when no ACK arrives', () {
      fakeAsync((async) {
        final stateChanges = <FileTransferState>[];
        final engine = FileTransferEngine(
          sendPacket:
              (payload, portnum, {destinationNode, hopLimit = 3}) async {
                return true;
              },
          onStateChanged: stateChanges.add,
        );
        addTearDown(engine.dispose);

        final fileBytes = Uint8List.fromList(
          List.generate(400, (i) => i % 256),
        );
        final transfer = engine.initiateTransfer(
          filename: 'timeout.bin',
          mimeType: 'application/octet-stream',
          fileBytes: fileBytes,
          targetNodeNum: 0x1234,
        )!;
        final idHex = transfer.fileIdHex;

        engine.startTransfer(idHex);
        async.flushMicrotasks();
        engine.resumeTransfer(idHex);

        // Send all chunks (2 chunks × 2s interval → finish at t=4s).
        async.elapse(const Duration(seconds: 6));
        expect(engine.getTransfer(idHex)!.isActive, isTrue);

        // Completion timeout starts at t=4, fires at t=64.
        // Advance to t=63 — should still be active.
        async.elapse(const Duration(seconds: 57));
        expect(engine.getTransfer(idHex)!.isActive, isTrue);

        // Advance to t=65 — past the timeout.
        async.elapse(const Duration(seconds: 2));

        // Sender marks complete as safety valve.
        final completed = engine.getTransfer(idHex)!;
        expect(completed.state, TransferState.complete);
        expect(completed.completedAt, isNotNull);
      });
    });

    test('sender completion timeout is cancelled by ACK', () {
      fakeAsync((async) {
        final engine = FileTransferEngine(
          sendPacket:
              (payload, portnum, {destinationNode, hopLimit = 3}) async {
                return true;
              },
          onStateChanged: (_) {},
        );
        addTearDown(engine.dispose);

        final fileBytes = Uint8List.fromList(
          List.generate(400, (i) => i % 256),
        );
        final transfer = engine.initiateTransfer(
          filename: 'ack_cancels_timeout.bin',
          mimeType: 'application/octet-stream',
          fileBytes: fileBytes,
          targetNodeNum: 0x1234,
        )!;
        final idHex = transfer.fileIdHex;

        engine.startTransfer(idHex);
        async.flushMicrotasks();
        engine.resumeTransfer(idHex);
        async.elapse(const Duration(seconds: 6));

        // ACK arrives 10s after all chunks sent.
        async.elapse(const Duration(seconds: 10));
        engine.handleIncomingAck(
          SmFileAck(fileId: transfer.fileId, status: FileAckStatus.complete),
        );
        expect(engine.getTransfer(idHex)!.state, TransferState.complete);

        // Advance past original timeout — state should not change.
        async.elapse(SmRateLimit.senderCompletionTimeout);
        expect(engine.getTransfer(idHex)!.state, TransferState.complete);
      });
    });

    test('sender completion timeout resets after NACK retransmission', () {
      fakeAsync((async) {
        final engine = FileTransferEngine(
          sendPacket:
              (payload, portnum, {destinationNode, hopLimit = 3}) async {
                return true;
              },
          onStateChanged: (_) {},
        );
        addTearDown(engine.dispose);

        final fileBytes = Uint8List.fromList(
          List.generate(400, (i) => i % 256),
        );
        final transfer = engine.initiateTransfer(
          filename: 'timeout_reset.bin',
          mimeType: 'application/octet-stream',
          fileBytes: fileBytes,
          targetNodeNum: 0x1234,
        )!;
        final idHex = transfer.fileIdHex;

        engine.startTransfer(idHex);
        async.flushMicrotasks();
        engine.resumeTransfer(idHex);
        async.elapse(const Duration(seconds: 6));

        // All chunks sent. Wait 30s then send NACK.
        async.elapse(const Duration(seconds: 30));
        engine.handleIncomingNack(
          SmFileNack(fileId: transfer.fileId, missingIndexes: [0]),
        );
        async.flushMicrotasks();

        // Let retransmission send.
        async.elapse(const Duration(seconds: 4));

        // The completion timeout should have restarted from
        // the retransmission, not from the original send.
        // Advance 30s — should still be active (timeout = 60s from now).
        async.elapse(const Duration(seconds: 30));
        expect(engine.getTransfer(idHex)!.isActive, isTrue);

        // Advance past the new timeout.
        async.elapse(const Duration(seconds: 40));
        expect(engine.getTransfer(idHex)!.state, TransferState.complete);
      });
    });
  });

  group('FileTransferEngine - receiver NACK round progression', () {
    test('receiver fires multiple NACK rounds automatically', () {
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
          filename: 'multi_nack.bin',
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

        // Send chunks 0 and 2, skip chunk 1.
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

        // Round 1: inactivity timeout → auto-NACK.
        async.elapse(
          SmRateLimit.chunkInactivityTimeout +
              const Duration(milliseconds: 100),
        );
        expect(engine.getTransfer(idHex)!.nackRounds, 1);
        expect(engine.getTransfer(idHex)!.state, TransferState.waitingMissing);

        // Round 2: no retransmission arrives → timer fires again.
        async.elapse(
          SmRateLimit.chunkInactivityTimeout +
              const Duration(milliseconds: 100),
        );
        expect(engine.getTransfer(idHex)!.nackRounds, 2);

        // Round 3: third NACK sent → nackRounds reaches maxNackRounds.
        async.elapse(
          SmRateLimit.chunkInactivityTimeout +
              const Duration(milliseconds: 100),
        );
        expect(engine.getTransfer(idHex)!.nackRounds, 3);

        // Round 4: guard check hits nackRounds >= maxNackRounds → failed.
        async.elapse(
          SmRateLimit.chunkInactivityTimeout +
              const Duration(milliseconds: 100),
        );
        final failed = engine.getTransfer(idHex)!;
        expect(failed.state, TransferState.failed);
        expect(failed.failReason, TransferFailReason.maxRetries);
      });
    });

    test(
      'receiver resets inactivity timer on retransmitted chunk during waitingMissing',
      () {
        fakeAsync((async) {
          final engine = FileTransferEngine(
            sendPacket:
                (payload, portnum, {destinationNode, hopLimit = 3}) async {
                  return true;
                },
            onStateChanged: (_) {},
          );
          addTearDown(engine.dispose);

          final fileId = generateFileId();
          final offer = SmFileOffer(
            fileId: fileId,
            filename: 'timer_reset.bin',
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

          // Receive chunks 0 and 2 (missing 1).
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

          // NACK round 1 fires.
          async.elapse(
            SmRateLimit.chunkInactivityTimeout +
                const Duration(milliseconds: 100),
          );
          expect(engine.getTransfer(idHex)!.nackRounds, 1);
          expect(
            engine.getTransfer(idHex)!.state,
            TransferState.waitingMissing,
          );

          // Retransmitted chunk 1 arrives while in waitingMissing,
          // but with WRONG data (simulating partial multi-chunk recovery).
          // Actually, let's send a duplicate of chunk 0 instead
          // (chunk 1 is still missing). This should reset the timer.
          async.elapse(const Duration(seconds: 5));
          engine.handleIncomingChunk(
            SmFileChunk(
              fileId: fileId,
              chunkIndex: 0,
              chunkCount: 3,
              payload: Uint8List(200),
            ),
            sourceNodeNum: 0xABCD,
          );

          // Timer should have been reset by the chunk arrival.
          // 5 more seconds should not trigger the next NACK.
          async.elapse(const Duration(seconds: 5));
          expect(engine.getTransfer(idHex)!.nackRounds, 1);

          // But 6 more seconds (total 11 from chunk arrival) should.
          async.elapse(const Duration(seconds: 6));
          expect(engine.getTransfer(idHex)!.nackRounds, 2);
        });
      },
    );
  });

  group('FileTransferEngine - lost final chunk recovery', () {
    test('lost final chunk recovers via NACK and completes successfully', () {
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

        // Build file and compute valid SHA-256.
        final fileBytes = Uint8List.fromList(
          List.generate(400, (i) => i % 256),
        );
        final refOffer = SmFileOffer.fromFile(
          filename: 'recover_final.bin',
          mimeType: 'application/octet-stream',
          fileBytes: fileBytes,
          isDirected: true,
        );

        final fileId = generateFileId();
        final offer = SmFileOffer(
          fileId: fileId,
          filename: 'recover_final.bin',
          mimeType: 'application/octet-stream',
          totalBytes: fileBytes.length,
          chunkSize: refOffer.chunkSize,
          chunkCount: refOffer.chunkCount,
          sha256Hash: refOffer.sha256Hash,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          expiresAt:
              DateTime.now()
                  .add(const Duration(hours: 24))
                  .millisecondsSinceEpoch ~/
              1000,
        );

        engine.handleIncomingOffer(offer, sourceNodeNum: 0x5678);
        final idHex = fileIdToHex(fileId);

        // Send all chunks EXCEPT the last one (simulate mesh drop).
        for (var i = 0; i < refOffer.chunkCount - 1; i++) {
          final start = i * refOffer.chunkSize;
          final end = (start + refOffer.chunkSize).clamp(0, fileBytes.length);
          engine.handleIncomingChunk(
            SmFileChunk(
              fileId: fileId,
              chunkIndex: i,
              chunkCount: refOffer.chunkCount,
              payload: Uint8List.sublistView(fileBytes, start, end),
            ),
            sourceNodeNum: 0x5678,
          );
        }

        // Receiver has N-1 of N chunks.
        final partial = engine.getTransfer(idHex)!;
        expect(partial.completedChunks.length, refOffer.chunkCount - 1);
        expect(partial.state, TransferState.chunking);

        // Inactivity timeout → NACK round 1.
        async.elapse(
          SmRateLimit.chunkInactivityTimeout +
              const Duration(milliseconds: 100),
        );
        expect(engine.getTransfer(idHex)!.nackRounds, 1);
        expect(engine.getTransfer(idHex)!.state, TransferState.waitingMissing);

        // Simulate the retransmitted final chunk arriving.
        final lastIdx = refOffer.chunkCount - 1;
        final lastStart = lastIdx * refOffer.chunkSize;
        final lastEnd = (lastStart + refOffer.chunkSize).clamp(
          0,
          fileBytes.length,
        );
        engine.handleIncomingChunk(
          SmFileChunk(
            fileId: fileId,
            chunkIndex: lastIdx,
            chunkCount: refOffer.chunkCount,
            payload: Uint8List.sublistView(fileBytes, lastStart, lastEnd),
          ),
          sourceNodeNum: 0x5678,
        );

        // Transfer should complete — hash matches.
        final completed = engine.getTransfer(idHex)!;
        expect(completed.state, TransferState.complete);
        expect(completed.fileBytes, isNotNull);
        expect(completed.fileBytes!.length, fileBytes.length);

        // ACK was sent to sender.
        expect(sentPackets, isNotEmpty);
      });
    });

    test('lost middle chunk recovers via NACK', () {
      fakeAsync((async) {
        final engine = FileTransferEngine(
          sendPacket:
              (payload, portnum, {destinationNode, hopLimit = 3}) async {
                return true;
              },
          onStateChanged: (_) {},
        );
        addTearDown(engine.dispose);

        final fileBytes = Uint8List.fromList(
          List.generate(600, (i) => i % 256),
        );
        final refOffer = SmFileOffer.fromFile(
          filename: 'recover_mid.bin',
          mimeType: 'application/octet-stream',
          fileBytes: fileBytes,
          isDirected: true,
        );

        final fileId = generateFileId();
        final offer = SmFileOffer(
          fileId: fileId,
          filename: 'recover_mid.bin',
          mimeType: 'application/octet-stream',
          totalBytes: fileBytes.length,
          chunkSize: refOffer.chunkSize,
          chunkCount: refOffer.chunkCount,
          sha256Hash: refOffer.sha256Hash,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          expiresAt:
              DateTime.now()
                  .add(const Duration(hours: 24))
                  .millisecondsSinceEpoch ~/
              1000,
        );

        engine.handleIncomingOffer(offer, sourceNodeNum: 0xABCD);
        final idHex = fileIdToHex(fileId);

        // Send chunks 0 and 2, skip chunk 1.
        for (var i = 0; i < refOffer.chunkCount; i++) {
          if (i == 1) continue; // Skip middle chunk.
          final start = i * refOffer.chunkSize;
          final end = (start + refOffer.chunkSize).clamp(0, fileBytes.length);
          engine.handleIncomingChunk(
            SmFileChunk(
              fileId: fileId,
              chunkIndex: i,
              chunkCount: refOffer.chunkCount,
              payload: Uint8List.sublistView(fileBytes, start, end),
            ),
            sourceNodeNum: 0xABCD,
          );
        }

        expect(engine.getTransfer(idHex)!.missingChunks, [1]);

        // NACK fires.
        async.elapse(
          SmRateLimit.chunkInactivityTimeout +
              const Duration(milliseconds: 100),
        );
        expect(engine.getTransfer(idHex)!.nackRounds, 1);

        // Retransmit chunk 1.
        final start = 1 * refOffer.chunkSize;
        final end = (start + refOffer.chunkSize).clamp(0, fileBytes.length);
        engine.handleIncomingChunk(
          SmFileChunk(
            fileId: fileId,
            chunkIndex: 1,
            chunkCount: refOffer.chunkCount,
            payload: Uint8List.sublistView(fileBytes, start, end),
          ),
          sourceNodeNum: 0xABCD,
        );

        expect(engine.getTransfer(idHex)!.state, TransferState.complete);
      });
    });

    test('duplicate retransmission is safe', () {
      fakeAsync((async) {
        final engine = FileTransferEngine(
          sendPacket:
              (payload, portnum, {destinationNode, hopLimit = 3}) async {
                return true;
              },
          onStateChanged: (_) {},
        );
        addTearDown(engine.dispose);

        final payload = Uint8List.fromList([0x48, 0x69]);
        final refOffer = SmFileOffer.fromFile(
          filename: 'dedup.bin',
          mimeType: 'application/octet-stream',
          fileBytes: payload,
          isDirected: true,
        );

        final fileId = generateFileId();
        final offer = SmFileOffer(
          fileId: fileId,
          filename: 'dedup.bin',
          mimeType: 'application/octet-stream',
          totalBytes: payload.length,
          chunkSize: refOffer.chunkSize,
          chunkCount: refOffer.chunkCount,
          sha256Hash: refOffer.sha256Hash,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          expiresAt:
              DateTime.now()
                  .add(const Duration(hours: 24))
                  .millisecondsSinceEpoch ~/
              1000,
        );

        engine.handleIncomingOffer(offer, sourceNodeNum: 0x1111);
        final idHex = fileIdToHex(fileId);

        // Send the only chunk.
        final chunk = SmFileChunk(
          fileId: fileId,
          chunkIndex: 0,
          chunkCount: 1,
          payload: payload,
        );
        engine.handleIncomingChunk(chunk, sourceNodeNum: 0x1111);
        expect(engine.getTransfer(idHex)!.state, TransferState.complete);

        // Send it again — should be ignored (transfer not active).
        engine.handleIncomingChunk(chunk, sourceNodeNum: 0x1111);
        expect(engine.getTransfer(idHex)!.state, TransferState.complete);
      });
    });
  });

  group('FileTransferEngine - off-by-one boundary cases', () {
    test('1-chunk file completes correctly on receiver', () {
      final payload = Uint8List.fromList([0xCA, 0xFE]);
      final refOffer = SmFileOffer.fromFile(
        filename: 'tiny.bin',
        mimeType: 'application/octet-stream',
        fileBytes: payload,
        isDirected: true,
      );
      expect(refOffer.chunkCount, 1);

      final stateChanges = <FileTransferState>[];
      final engine = FileTransferEngine(
        sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async {
          return true;
        },
        onStateChanged: stateChanges.add,
      );
      addTearDown(engine.dispose);

      final fileId = generateFileId();
      final offer = SmFileOffer(
        fileId: fileId,
        filename: 'tiny.bin',
        mimeType: 'application/octet-stream',
        totalBytes: payload.length,
        chunkSize: refOffer.chunkSize,
        chunkCount: 1,
        sha256Hash: refOffer.sha256Hash,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expiresAt:
            DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch ~/
            1000,
      );

      engine.handleIncomingOffer(offer, sourceNodeNum: 0x2222);
      final idHex = fileIdToHex(fileId);

      engine.handleIncomingChunk(
        SmFileChunk(
          fileId: fileId,
          chunkIndex: 0,
          chunkCount: 1,
          payload: payload,
        ),
        sourceNodeNum: 0x2222,
      );

      final completed = engine.getTransfer(idHex)!;
      expect(completed.state, TransferState.complete);
      expect(completed.fileBytes!.length, payload.length);
    });

    test('exact chunk-boundary file (no short final chunk)', () {
      // 400 bytes / 200-byte chunks = exactly 2 chunks, no remainder.
      final payload = Uint8List.fromList(List.generate(400, (i) => i % 256));
      final refOffer = SmFileOffer.fromFile(
        filename: 'exact.bin',
        mimeType: 'application/octet-stream',
        fileBytes: payload,
        isDirected: true,
      );
      expect(refOffer.chunkCount, 2);

      final engine = FileTransferEngine(
        sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async {
          return true;
        },
        onStateChanged: (_) {},
      );
      addTearDown(engine.dispose);

      final fileId = generateFileId();
      final offer = SmFileOffer(
        fileId: fileId,
        filename: 'exact.bin',
        mimeType: 'application/octet-stream',
        totalBytes: payload.length,
        chunkSize: refOffer.chunkSize,
        chunkCount: refOffer.chunkCount,
        sha256Hash: refOffer.sha256Hash,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expiresAt:
            DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch ~/
            1000,
      );

      engine.handleIncomingOffer(offer, sourceNodeNum: 0x3333);
      final idHex = fileIdToHex(fileId);

      for (var i = 0; i < refOffer.chunkCount; i++) {
        final start = i * refOffer.chunkSize;
        final end = (start + refOffer.chunkSize).clamp(0, payload.length);
        engine.handleIncomingChunk(
          SmFileChunk(
            fileId: fileId,
            chunkIndex: i,
            chunkCount: refOffer.chunkCount,
            payload: Uint8List.sublistView(payload, start, end),
          ),
          sourceNodeNum: 0x3333,
        );
      }

      expect(engine.getTransfer(idHex)!.state, TransferState.complete);
    });

    test('short final chunk file (41 chunks for 8KB)', () {
      // 8192 bytes / 200-byte chunks = 41 chunks, last is 192 bytes.
      final payload = Uint8List.fromList(
        List.generate(SmFileTransferLimits.maxFileSize, (i) => i % 256),
      );
      final refOffer = SmFileOffer.fromFile(
        filename: 'max_file.bin',
        mimeType: 'application/octet-stream',
        fileBytes: payload,
        isDirected: true,
      );
      expect(refOffer.chunkCount, 41);

      final engine = FileTransferEngine(
        sendPacket: (payload, portnum, {destinationNode, hopLimit = 3}) async {
          return true;
        },
        onStateChanged: (_) {},
      );
      addTearDown(engine.dispose);

      final fileId = generateFileId();
      final offer = SmFileOffer(
        fileId: fileId,
        filename: 'max_file.bin',
        mimeType: 'application/octet-stream',
        totalBytes: payload.length,
        chunkSize: refOffer.chunkSize,
        chunkCount: refOffer.chunkCount,
        sha256Hash: refOffer.sha256Hash,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        expiresAt:
            DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch ~/
            1000,
      );

      engine.handleIncomingOffer(offer, sourceNodeNum: 0x4444);
      final idHex = fileIdToHex(fileId);

      // Send all 41 chunks including short last chunk.
      for (var i = 0; i < refOffer.chunkCount; i++) {
        final start = i * refOffer.chunkSize;
        final end = (start + refOffer.chunkSize).clamp(0, payload.length);
        engine.handleIncomingChunk(
          SmFileChunk(
            fileId: fileId,
            chunkIndex: i,
            chunkCount: refOffer.chunkCount,
            payload: Uint8List.sublistView(payload, start, end),
          ),
          sourceNodeNum: 0x4444,
        );
      }

      final completed = engine.getTransfer(idHex)!;
      expect(completed.state, TransferState.complete);
      expect(completed.fileBytes!.length, payload.length);

      // Verify last chunk was short.
      final lastChunkSize =
          payload.length - (refOffer.chunkCount - 1) * refOffer.chunkSize;
      expect(lastChunkSize, 192);
      expect(lastChunkSize, lessThan(refOffer.chunkSize));
    });

    test('40/41 receiver recovers final chunk via NACK', () {
      fakeAsync((async) {
        final engine = FileTransferEngine(
          sendPacket:
              (payload, portnum, {destinationNode, hopLimit = 3}) async {
                return true;
              },
          onStateChanged: (_) {},
        );
        addTearDown(engine.dispose);

        // 8KB file → 41 chunks.
        final payload = Uint8List.fromList(
          List.generate(SmFileTransferLimits.maxFileSize, (i) => i % 256),
        );
        final refOffer = SmFileOffer.fromFile(
          filename: 'forty_one.bin',
          mimeType: 'application/octet-stream',
          fileBytes: payload,
          isDirected: true,
        );

        final fileId = generateFileId();
        final offer = SmFileOffer(
          fileId: fileId,
          filename: 'forty_one.bin',
          mimeType: 'application/octet-stream',
          totalBytes: payload.length,
          chunkSize: refOffer.chunkSize,
          chunkCount: refOffer.chunkCount,
          sha256Hash: refOffer.sha256Hash,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          expiresAt:
              DateTime.now()
                  .add(const Duration(hours: 24))
                  .millisecondsSinceEpoch ~/
              1000,
        );

        engine.handleIncomingOffer(offer, sourceNodeNum: 0x5555);
        final idHex = fileIdToHex(fileId);

        // Send chunks 0-39 (40 of 41), skip last chunk.
        for (var i = 0; i < 40; i++) {
          final start = i * refOffer.chunkSize;
          final end = (start + refOffer.chunkSize).clamp(0, payload.length);
          engine.handleIncomingChunk(
            SmFileChunk(
              fileId: fileId,
              chunkIndex: i,
              chunkCount: refOffer.chunkCount,
              payload: Uint8List.sublistView(payload, start, end),
            ),
            sourceNodeNum: 0x5555,
          );
        }

        expect(engine.getTransfer(idHex)!.completedChunks.length, 40);
        expect(engine.getTransfer(idHex)!.missingChunks, [40]);

        // Inactivity timeout → NACK.
        async.elapse(
          SmRateLimit.chunkInactivityTimeout +
              const Duration(milliseconds: 100),
        );
        expect(engine.getTransfer(idHex)!.nackRounds, 1);

        // Retransmit the last (short) chunk.
        final lastStart = 40 * refOffer.chunkSize;
        final lastEnd = (lastStart + refOffer.chunkSize).clamp(
          0,
          payload.length,
        );
        engine.handleIncomingChunk(
          SmFileChunk(
            fileId: fileId,
            chunkIndex: 40,
            chunkCount: refOffer.chunkCount,
            payload: Uint8List.sublistView(payload, lastStart, lastEnd),
          ),
          sourceNodeNum: 0x5555,
        );

        final completed = engine.getTransfer(idHex)!;
        expect(completed.state, TransferState.complete);
        expect(completed.fileBytes!.length, payload.length);
      });
    });
  });
}
