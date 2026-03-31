// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/logging.dart';
import '../protocol/socialmesh/sm_constants.dart';
import '../protocol/socialmesh/sm_file_transfer.dart';

/// Transfer direction.
enum TransferDirection { outbound, inbound }

/// State of a file transfer.
enum TransferState {
  /// Transfer created but offer not yet sent.
  created,

  /// Offer sent, waiting for receiver to begin accepting chunks.
  offerSent,

  /// Inbound offer awaiting user acceptance.
  offerPending,

  /// Actively sending/receiving chunks.
  chunking,

  /// Waiting for missing chunks after initial pass (NACK phase).
  waitingMissing,

  /// Transfer completed and verified.
  complete,

  /// Transfer failed.
  failed,

  /// Transfer cancelled by user.
  cancelled,

  /// Outbound: offer sent, waiting for receiver's ACCEPT before sending
  /// chunks. This is a hard gate — no chunk transmission is permitted
  /// until the negotiation layer confirms acceptance.
  awaitingAccept,
}

/// Reason codes for transfer failure.
enum TransferFailReason {
  /// File exceeds size limit.
  oversized,

  /// Transfer timed out.
  timeout,

  /// Invalid data (chunk mismatch, bad hash, etc.).
  invalid,

  /// User cancelled the transfer.
  userCancelled,

  /// Rate limit exceeded.
  rateLimited,

  /// SHA-256 verification failed.
  hashMismatch,

  /// Too many retries.
  maxRetries,

  /// Transfer expired TTL.
  expired,
}

/// Immutable state snapshot of a file transfer.
class FileTransferState {
  /// Unique file transfer ID (hex string).
  final String fileIdHex;

  /// Raw 128-bit file ID.
  final Uint8List fileId;

  /// Direction (outbound = sending, inbound = receiving).
  final TransferDirection direction;

  /// Current state.
  final TransferState state;

  /// File metadata.
  final String filename;
  final String mimeType;
  final int totalBytes;
  final int chunkSize;
  final int chunkCount;
  final Uint8List sha256Hash;

  /// Target node number (for directed transfers), or null for broadcast.
  final int? targetNodeNum;

  /// Source node number (for inbound transfers).
  final int? sourceNodeNum;

  /// Set of chunk indexes that have been sent/received.
  final Set<int> completedChunks;

  /// Number of NACK rounds completed.
  final int nackRounds;

  /// Failure reason (only set when state == failed).
  final TransferFailReason? failReason;

  /// Timestamps.
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? completedAt;

  /// Transport mode preference.
  final FileTransportMode transportMode;

  /// Phase 3: fetch hint for store-and-forward.
  final String fetchHint;

  /// Raw file bytes (for outbound: full file, for inbound: reassembled).
  final Uint8List? fileBytes;

  /// Path to the file saved on device storage after transfer completion.
  ///
  /// Set automatically when a transfer completes and bytes are auto-saved
  /// to the app documents directory. Persisted to SQLite so the file
  /// survives app restarts without needing bytes in memory.
  final String? savedFilePath;

  const FileTransferState({
    required this.fileIdHex,
    required this.fileId,
    required this.direction,
    required this.state,
    required this.filename,
    required this.mimeType,
    required this.totalBytes,
    required this.chunkSize,
    required this.chunkCount,
    required this.sha256Hash,
    required this.completedChunks,
    required this.nackRounds,
    required this.createdAt,
    required this.expiresAt,
    this.targetNodeNum,
    this.sourceNodeNum,
    this.failReason,
    this.completedAt,
    this.transportMode = FileTransportMode.auto,
    this.fetchHint = '',
    this.fileBytes,
    this.savedFilePath,
  });

  /// Progress as a fraction [0.0, 1.0].
  double get progress =>
      chunkCount > 0 ? completedChunks.length / chunkCount : 0.0;

  /// Whether the transfer is still active (not terminal).
  bool get isActive =>
      state != TransferState.complete &&
      state != TransferState.failed &&
      state != TransferState.cancelled;

  /// Whether the transfer has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Missing chunk indexes for inbound transfers.
  List<int> get missingChunks {
    final missing = <int>[];
    for (var i = 0; i < chunkCount; i++) {
      if (!completedChunks.contains(i)) missing.add(i);
    }
    return missing;
  }

  FileTransferState copyWith({
    TransferState? state,
    Set<int>? completedChunks,
    int? nackRounds,
    TransferFailReason? failReason,
    DateTime? completedAt,
    Uint8List? fileBytes,
    String? savedFilePath,
    bool clearSavedFilePath = false,
  }) {
    return FileTransferState(
      fileIdHex: fileIdHex,
      fileId: fileId,
      direction: direction,
      state: state ?? this.state,
      filename: filename,
      mimeType: mimeType,
      totalBytes: totalBytes,
      chunkSize: chunkSize,
      chunkCount: chunkCount,
      sha256Hash: sha256Hash,
      completedChunks: completedChunks ?? this.completedChunks,
      nackRounds: nackRounds ?? this.nackRounds,
      createdAt: createdAt,
      expiresAt: expiresAt,
      targetNodeNum: targetNodeNum,
      sourceNodeNum: sourceNodeNum,
      failReason: failReason ?? this.failReason,
      completedAt: completedAt ?? this.completedAt,
      transportMode: transportMode,
      fetchHint: fetchHint,
      fileBytes: fileBytes ?? this.fileBytes,
      savedFilePath: clearSavedFilePath
          ? null
          : (savedFilePath ?? this.savedFilePath),
    );
  }
}

/// Callback for sending a packet over the mesh transport.
typedef SendPacketCallback =
    Future<bool> Function(
      Uint8List payload,
      int portnum, {
      int? destinationNode,
      int hopLimit,
    });

/// The file transfer engine manages all active transfers.
///
/// It enforces:
/// - Size limits
/// - Rate limits (global + per-transfer)
/// - Chunk spacing
/// - Retry limits
/// - TTL expiry
class FileTransferEngine {
  final SendPacketCallback _sendPacket;
  final void Function(FileTransferState) _onStateChanged;

  /// Active transfers keyed by file ID hex.
  final Map<String, FileTransferState> _transfers = {};

  /// Inbound chunk buffers keyed by file ID hex.
  final Map<String, Map<int, Uint8List>> _chunkBuffers = {};

  /// Per-transfer rate limiter: last chunk send time.
  final Map<String, DateTime> _lastChunkSent = {};

  /// Global rate limiter: last any-file-transfer send time.
  DateTime? _lastGlobalSend;

  /// Timer for scheduling chunk sends.
  Timer? _chunkTimer;

  /// Inactivity timers for inbound transfers.
  ///
  /// When a chunk arrives, the timer is (re)started. If no new chunk
  /// arrives within [SmRateLimit.chunkInactivityTimeout] and the transfer
  /// still has missing chunks, a NACK is automatically sent.
  final Map<String, Timer> _chunkInactivityTimers = {};

  /// Queue of (fileIdHex, chunkIndex) to send.
  final List<(String, int)> _sendQueue = [];

  FileTransferEngine({
    required SendPacketCallback sendPacket,
    required void Function(FileTransferState) onStateChanged,
  }) : _sendPacket = sendPacket,
       _onStateChanged = onStateChanged;

  /// All active transfers.
  Map<String, FileTransferState> get transfers => Map.unmodifiable(_transfers);

  /// Get a specific transfer state.
  FileTransferState? getTransfer(String fileIdHex) => _transfers[fileIdHex];

  /// Validate and initiate an outbound file transfer.
  ///
  /// Returns the transfer state or null if validation fails.
  FileTransferState? initiateTransfer({
    required String filename,
    required String mimeType,
    required Uint8List fileBytes,
    int? targetNodeNum,
    FileTransportMode transportMode = FileTransportMode.auto,
  }) {
    // Validate size
    if (fileBytes.length > SmFileTransferLimits.maxFileSize) {
      AppLogging.fileTransfer(
        'initiateTransfer REJECTED: size ${fileBytes.length} exceeds '
        'max ${SmFileTransferLimits.maxFileSize}',
      );
      return null;
    }
    if (fileBytes.isEmpty) {
      AppLogging.fileTransfer('initiateTransfer REJECTED: empty file');
      return null;
    }

    // Check concurrent transfer limit
    final activeCount = _transfers.values
        .where((t) => t.isActive && t.direction == TransferDirection.outbound)
        .length;
    if (activeCount >= SmRateLimit.maxConcurrentTransfers) {
      AppLogging.fileTransfer(
        'initiateTransfer REJECTED: concurrent limit '
        '($activeCount/${SmRateLimit.maxConcurrentTransfers})',
      );
      return null;
    }

    // Build offer
    final offer = SmFileOffer.fromFile(
      filename: filename,
      mimeType: mimeType,
      fileBytes: fileBytes,
      isDirected: targetNodeNum != null,
    );

    final idHex = fileIdToHex(offer.fileId);

    final state = FileTransferState(
      fileIdHex: idHex,
      fileId: offer.fileId,
      direction: TransferDirection.outbound,
      state: TransferState.created,
      filename: filename,
      mimeType: mimeType,
      totalBytes: fileBytes.length,
      chunkSize: offer.chunkSize,
      chunkCount: offer.chunkCount,
      sha256Hash: offer.sha256Hash,
      completedChunks: const {},
      nackRounds: 0,
      createdAt: DateTime.now(),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(offer.expiresAt * 1000),
      targetNodeNum: targetNodeNum,
      transportMode: transportMode,
      fileBytes: fileBytes,
    );

    _transfers[idHex] = state;
    _onStateChanged(state);

    AppLogging.fileTransfer(
      'initiateTransfer OK: id=$idHex, file=$filename, '
      '${fileBytes.length} bytes, ${offer.chunkCount} chunks, '
      'target=${targetNodeNum?.toRadixString(16) ?? "broadcast"}, '
      'mode=${transportMode.name}',
    );

    return state;
  }

  /// Send the offer packet and begin chunking.
  Future<void> startTransfer(String fileIdHex) async {
    final transfer = _transfers[fileIdHex];
    if (transfer == null) {
      AppLogging.fileTransfer('startTransfer: $fileIdHex not found');
      return;
    }
    if (transfer.state != TransferState.created) {
      AppLogging.fileTransfer(
        'startTransfer: $fileIdHex wrong state ${transfer.state.name}',
      );
      return;
    }
    if (transfer.fileBytes == null) {
      AppLogging.fileTransfer('startTransfer: $fileIdHex has no file bytes');
      return;
    }

    // Build and send offer
    final offer = SmFileOffer(
      fileId: transfer.fileId,
      filename: transfer.filename,
      mimeType: transfer.mimeType,
      totalBytes: transfer.totalBytes,
      chunkSize: transfer.chunkSize,
      chunkCount: transfer.chunkCount,
      sha256Hash: transfer.sha256Hash,
      createdAt: transfer.createdAt.millisecondsSinceEpoch ~/ 1000,
      expiresAt: transfer.expiresAt.millisecondsSinceEpoch ~/ 1000,
      isDirected: transfer.targetNodeNum != null,
      fetchHint: transfer.fetchHint,
    );

    final encoded = offer.encode();
    if (encoded == null) {
      AppLogging.fileTransfer('startTransfer: $fileIdHex offer encode failed');
      _failTransfer(fileIdHex, TransferFailReason.invalid);
      return;
    }

    AppLogging.fileTransfer(
      'startTransfer: sending offer for $fileIdHex '
      '(${transfer.filename}, ${transfer.totalBytes} bytes, '
      '${transfer.chunkCount} chunks)',
    );

    // Retry offer send up to maxOfferRetries times.
    // The protocol layer returns false for both rate-limited and
    // not-connected states, so transient failures are expected
    // during connection setup.
    var sent = false;
    for (var attempt = 1; attempt <= SmRateLimit.maxOfferRetries; attempt++) {
      sent = await _sendPacket(
        encoded,
        SmPortnum.fileTransfer,
        destinationNode: transfer.targetNodeNum,
        hopLimit: SmTransport.fileTransferHopLimit,
      );
      if (sent) break;

      AppLogging.fileTransfer(
        'startTransfer: $fileIdHex offer attempt $attempt/'
        '${SmRateLimit.maxOfferRetries} failed, '
        '${attempt < SmRateLimit.maxOfferRetries ? "retrying..." : "giving up"}',
      );

      if (attempt < SmRateLimit.maxOfferRetries) {
        await Future<void>.delayed(SmRateLimit.offerRetryDelay);
        // Check transfer still active after delay
        if (_transfers[fileIdHex]?.isActive != true) return;
      }
    }

    if (!sent) {
      AppLogging.fileTransfer(
        'startTransfer: $fileIdHex offer send failed after '
        '${SmRateLimit.maxOfferRetries} attempts',
      );
      _failTransfer(fileIdHex, TransferFailReason.rateLimited);
      return;
    }

    AppLogging.fileTransfer(
      'startTransfer: $fileIdHex offer sent, '
      'awaiting accept before chunking',
    );

    _updateState(fileIdHex, transfer.copyWith(state: TransferState.offerSent));

    // Record the offer as the last global send so the first chunk send
    // waits for the rate-limit interval instead of failing immediately.
    _lastGlobalSend = DateTime.now();

    // Hard gate: transition to awaitingAccept. No chunks are queued
    // until the negotiation layer confirms the receiver's ACCEPT.
    _updateState(
      fileIdHex,
      _transfers[fileIdHex]!.copyWith(state: TransferState.awaitingAccept),
    );
  }

  /// Cancel an active transfer.
  void cancelTransfer(String fileIdHex) {
    final transfer = _transfers[fileIdHex];
    if (transfer == null || !transfer.isActive) {
      AppLogging.fileTransfer(
        'cancelTransfer: $fileIdHex not found or not active',
      );
      return;
    }

    AppLogging.fileTransfer(
      'cancelTransfer: $fileIdHex '
      '(${transfer.filename}, ${transfer.direction.name})',
    );

    _updateState(
      fileIdHex,
      transfer.copyWith(
        state: TransferState.cancelled,
        failReason: TransferFailReason.userCancelled,
      ),
    );

    // Remove from send queue
    _sendQueue.removeWhere((e) => e.$1 == fileIdHex);
    _chunkBuffers.remove(fileIdHex);
    _cancelInactivityTimer(fileIdHex);
  }

  /// Accept a pending inbound transfer.
  ///
  /// Transitions from [TransferState.offerPending] to
  /// [TransferState.chunking]. If all chunks arrived while pending,
  /// completes immediately.
  void acceptTransfer(String fileIdHex) {
    final transfer = _transfers[fileIdHex];
    if (transfer == null || transfer.state != TransferState.offerPending) {
      AppLogging.fileTransfer(
        'acceptTransfer: $fileIdHex not pending '
        '(${transfer?.state.name ?? "null"})',
      );
      return;
    }

    AppLogging.fileTransfer(
      'acceptTransfer: $fileIdHex accepted by user '
      '(${transfer.completedChunks.length}/${transfer.chunkCount} chunks '
      'buffered)',
    );

    _updateState(fileIdHex, transfer.copyWith(state: TransferState.chunking));

    // If all chunks arrived while pending, complete now
    if (transfer.completedChunks.length == transfer.chunkCount) {
      _tryCompleteInbound(fileIdHex);
    }
  }

  /// Resume an outbound transfer after the receiver's ACCEPT is received.
  ///
  /// Transitions from [TransferState.awaitingAccept] to
  /// [TransferState.chunking], queues all chunks, and starts the send loop.
  void resumeTransfer(String fileIdHex) {
    final transfer = _transfers[fileIdHex];
    if (transfer == null || transfer.state != TransferState.awaitingAccept) {
      AppLogging.fileTransfer(
        'resumeTransfer: $fileIdHex not awaiting accept '
        '(${transfer?.state.name ?? "null"})',
      );
      return;
    }

    AppLogging.fileTransfer(
      'resumeTransfer: $fileIdHex accept received, '
      'queueing ${transfer.chunkCount} chunks',
    );

    // Queue all chunks
    for (var i = 0; i < transfer.chunkCount; i++) {
      _sendQueue.add((fileIdHex, i));
    }

    // Transition to chunking and start the send loop.
    _updateState(fileIdHex, transfer.copyWith(state: TransferState.chunking));
    _scheduleSendLoop();
  }

  /// Reject a pending inbound transfer.
  ///
  /// Sends a rejection ACK to the sender and cancels the transfer.
  void rejectTransfer(String fileIdHex) {
    final transfer = _transfers[fileIdHex];
    if (transfer == null || transfer.state != TransferState.offerPending) {
      AppLogging.fileTransfer(
        'rejectTransfer: $fileIdHex not pending '
        '(${transfer?.state.name ?? "null"})',
      );
      return;
    }

    AppLogging.fileTransfer('rejectTransfer: $fileIdHex rejected by user');

    // Send rejection ACK to sender
    final ack = SmFileAck(
      fileId: transfer.fileId,
      status: FileAckStatus.rejected,
    );
    final encoded = ack.encode();
    if (encoded != null) {
      _sendPacket(
        encoded,
        SmPortnum.fileTransfer,
        destinationNode: transfer.sourceNodeNum,
        hopLimit: SmTransport.fileTransferHopLimit,
      );
    }

    _updateState(
      fileIdHex,
      transfer.copyWith(
        state: TransferState.cancelled,
        failReason: TransferFailReason.userCancelled,
      ),
    );

    // Clean up buffers
    _chunkBuffers.remove(fileIdHex);
  }

  /// Handle an incoming file offer packet.
  ///
  /// When [autoAccept] is true (default), the transfer begins immediately
  /// in [TransferState.chunking]. When false, the transfer is created in
  /// [TransferState.offerPending] and requires [acceptTransfer] to proceed.
  void handleIncomingOffer(
    SmFileOffer offer, {
    int? sourceNodeNum,
    bool autoAccept = true,
  }) {
    final idHex = fileIdToHex(offer.fileId);

    AppLogging.fileTransfer(
      'RX_OFFER: id=$idHex, file=${offer.filename}, '
      '${offer.totalBytes} bytes, ${offer.chunkCount} chunks, '
      'from=${sourceNodeNum?.toRadixString(16) ?? "unknown"}',
    );

    // Reject oversize files
    if (offer.totalBytes > SmFileTransferLimits.maxFileSize) {
      AppLogging.fileTransfer(
        'RX_OFFER REJECTED: $idHex oversize '
        '(${offer.totalBytes} > ${SmFileTransferLimits.maxFileSize})',
      );
      return;
    }

    // Reject if we already have this transfer
    if (_transfers.containsKey(idHex)) {
      AppLogging.fileTransfer('RX_OFFER REJECTED: $idHex duplicate');
      return;
    }

    final initialState = autoAccept
        ? TransferState.chunking
        : TransferState.offerPending;

    final state = FileTransferState(
      fileIdHex: idHex,
      fileId: offer.fileId,
      direction: TransferDirection.inbound,
      state: initialState,
      filename: offer.filename,
      mimeType: offer.mimeType,
      totalBytes: offer.totalBytes,
      chunkSize: offer.chunkSize,
      chunkCount: offer.chunkCount,
      sha256Hash: offer.sha256Hash,
      completedChunks: const {},
      nackRounds: 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(offer.createdAt * 1000),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(offer.expiresAt * 1000),
      sourceNodeNum: sourceNodeNum,
      fetchHint: offer.fetchHint,
    );

    _transfers[idHex] = state;
    _chunkBuffers[idHex] = {};
    _onStateChanged(state);

    AppLogging.fileTransfer(
      autoAccept
          ? 'RX_OFFER ACCEPTED: $idHex, awaiting ${offer.chunkCount} chunks'
          : 'RX_OFFER PENDING: $idHex, awaiting user decision '
                '(${offer.chunkCount} chunks)',
    );
  }

  /// Handle an incoming file chunk.
  void handleIncomingChunk(SmFileChunk chunk, {int? sourceNodeNum}) {
    final idHex = fileIdToHex(chunk.fileId);
    final transfer = _transfers[idHex];
    if (transfer == null) {
      AppLogging.fileTransfer(
        'RX_CHUNK IGNORED: $idHex not tracked '
        '(idx=${chunk.chunkIndex}/${chunk.chunkCount})',
      );
      return;
    }
    if (transfer.direction != TransferDirection.inbound) {
      AppLogging.fileTransfer('RX_CHUNK IGNORED: $idHex is outbound');
      return;
    }
    if (!transfer.isActive) {
      AppLogging.fileTransfer(
        'RX_CHUNK IGNORED: $idHex is ${transfer.state.name}',
      );
      return;
    }

    // Validate chunk against manifest
    if (chunk.chunkIndex >= transfer.chunkCount) {
      AppLogging.fileTransfer(
        'RX_CHUNK REJECTED: $idHex index ${chunk.chunkIndex} '
        '>= chunkCount ${transfer.chunkCount}',
      );
      return;
    }
    if (chunk.chunkCount != transfer.chunkCount) {
      AppLogging.fileTransfer(
        'RX_CHUNK REJECTED: $idHex count mismatch '
        '(got ${chunk.chunkCount}, expected ${transfer.chunkCount})',
      );
      return;
    }

    // Store chunk
    _chunkBuffers[idHex] ??= {};
    _chunkBuffers[idHex]![chunk.chunkIndex] = chunk.payload;

    // Update completed set
    final updated = Set<int>.from(transfer.completedChunks)
      ..add(chunk.chunkIndex);

    _updateState(idHex, transfer.copyWith(completedChunks: updated));

    AppLogging.fileTransfer(
      'RX_CHUNK OK: $idHex [${chunk.chunkIndex}/${transfer.chunkCount}] '
      '${chunk.payload.length} bytes '
      '(${updated.length}/${transfer.chunkCount} complete)',
    );

    // Check if complete (defer if still awaiting user acceptance)
    if (updated.length == transfer.chunkCount &&
        _transfers[idHex]?.state != TransferState.offerPending) {
      _tryCompleteInbound(idHex);
    } else if (_transfers[idHex]?.state == TransferState.chunking) {
      // Restart inactivity timer — if no new chunk arrives within the
      // timeout and we still have gaps, auto-NACK to recover.
      _restartInactivityTimer(idHex);
    }
  }

  /// Handle an incoming NACK (sender side).
  Future<void> handleIncomingNack(SmFileNack nack) async {
    final idHex = fileIdToHex(nack.fileId);
    final transfer = _transfers[idHex];
    if (transfer == null) {
      AppLogging.fileTransfer('RX_NACK IGNORED: $idHex not tracked');
      return;
    }
    if (transfer.direction != TransferDirection.outbound) {
      AppLogging.fileTransfer('RX_NACK IGNORED: $idHex is inbound');
      return;
    }
    if (!transfer.isActive) {
      AppLogging.fileTransfer(
        'RX_NACK IGNORED: $idHex is ${transfer.state.name}',
      );
      return;
    }

    AppLogging.fileTransfer(
      'RX_NACK: $idHex requesting ${nack.missingIndexes.length} missing '
      'chunks (round ${transfer.nackRounds + 1}/${SmRateLimit.maxNackRounds})',
    );

    // Respect max NACK rounds
    if (transfer.nackRounds >= SmRateLimit.maxNackRounds) {
      AppLogging.fileTransfer(
        'RX_NACK FAILED: $idHex max NACK rounds exceeded',
      );
      _failTransfer(idHex, TransferFailReason.maxRetries);
      return;
    }

    _updateState(
      idHex,
      transfer.copyWith(
        state: TransferState.waitingMissing,
        nackRounds: transfer.nackRounds + 1,
      ),
    );

    // Queue retransmission of missing chunks
    for (final idx in nack.missingIndexes) {
      if (idx < transfer.chunkCount) {
        _sendQueue.add((idHex, idx));
      }
    }

    _updateState(
      idHex,
      _transfers[idHex]!.copyWith(state: TransferState.chunking),
    );
    _scheduleSendLoop();
  }

  /// Handle an incoming ACK (sender side).
  void handleIncomingAck(SmFileAck ack) {
    final idHex = fileIdToHex(ack.fileId);
    final transfer = _transfers[idHex];
    if (transfer == null) {
      AppLogging.fileTransfer('RX_ACK IGNORED: $idHex not tracked');
      return;
    }
    if (transfer.direction != TransferDirection.outbound) {
      AppLogging.fileTransfer('RX_ACK IGNORED: $idHex is inbound');
      return;
    }

    AppLogging.fileTransfer('RX_ACK: $idHex status=${ack.status.name}');

    switch (ack.status) {
      case FileAckStatus.complete:
        _updateState(
          idHex,
          transfer.copyWith(
            state: TransferState.complete,
            completedAt: DateTime.now(),
          ),
        );
      case FileAckStatus.rejected:
        _failTransfer(idHex, TransferFailReason.invalid);
      case FileAckStatus.cancelled:
        _updateState(
          idHex,
          transfer.copyWith(
            state: TransferState.cancelled,
            failReason: TransferFailReason.userCancelled,
          ),
        );
    }
  }

  /// Send a NACK for missing chunks (receiver side).
  Future<void> requestMissingChunks(String fileIdHex) async {
    final transfer = _transfers[fileIdHex];
    if (transfer == null) {
      AppLogging.fileTransfer('requestMissingChunks: $fileIdHex not found');
      return;
    }
    if (transfer.direction != TransferDirection.inbound) return;
    if (!transfer.isActive) return;

    if (transfer.nackRounds >= SmRateLimit.maxNackRounds) {
      AppLogging.fileTransfer(
        'requestMissingChunks: $fileIdHex max NACK rounds exceeded '
        '(${transfer.nackRounds}/${SmRateLimit.maxNackRounds})',
      );
      _failTransfer(fileIdHex, TransferFailReason.maxRetries);
      return;
    }

    final missing = transfer.missingChunks;
    if (missing.isEmpty) return;

    // Bound the NACK list
    final bounded = missing.length > SmFileTransferLimits.maxNackIndexes
        ? missing.sublist(0, SmFileTransferLimits.maxNackIndexes)
        : missing;

    final nack = SmFileNack(fileId: transfer.fileId, missingIndexes: bounded);
    final encoded = nack.encode();
    if (encoded == null) {
      AppLogging.fileTransfer(
        'requestMissingChunks: $fileIdHex NACK encode failed',
      );
      return;
    }

    AppLogging.fileTransfer(
      'TX_NACK: $fileIdHex requesting ${bounded.length} missing chunks '
      '(round ${transfer.nackRounds + 1}/${SmRateLimit.maxNackRounds})',
    );

    await _sendPacket(
      encoded,
      SmPortnum.fileTransfer,
      destinationNode: transfer.sourceNodeNum,
      hopLimit: SmTransport.fileTransferHopLimit,
    );

    _updateState(
      fileIdHex,
      transfer.copyWith(
        state: TransferState.waitingMissing,
        nackRounds: transfer.nackRounds + 1,
      ),
    );
  }

  /// Purge expired transfers and free resources.
  void purgeExpired() {
    final expired = <String>[];
    for (final entry in _transfers.entries) {
      if (entry.value.isExpired && entry.value.isActive) {
        expired.add(entry.key);
      }
    }
    if (expired.isNotEmpty) {
      AppLogging.fileTransfer(
        'purgeExpired: removing ${expired.length} expired transfers',
      );
    }
    for (final id in expired) {
      AppLogging.fileTransfer('purgeExpired: $id expired');
      _failTransfer(id, TransferFailReason.expired);
    }
  }

  /// Remove a terminal transfer from engine memory.
  ///
  /// Only removes if the transfer is not active (complete/failed/cancelled).
  void removeTransfer(String fileIdHex) {
    final transfer = _transfers[fileIdHex];
    if (transfer == null) return;
    if (transfer.isActive) {
      AppLogging.fileTransfer(
        'removeTransfer: $fileIdHex still active, skipping',
      );
      return;
    }
    _transfers.remove(fileIdHex);
    _chunkBuffers.remove(fileIdHex);
    AppLogging.fileTransfer('removeTransfer: $fileIdHex removed from engine');
  }

  /// Clean up resources.
  void dispose() {
    AppLogging.fileTransfer(
      'dispose: cleaning up ${_transfers.length} transfers, '
      '${_sendQueue.length} queued chunks',
    );
    _chunkTimer?.cancel();
    for (final timer in _chunkInactivityTimers.values) {
      timer.cancel();
    }
    _chunkInactivityTimers.clear();
    _sendQueue.clear();
    _chunkBuffers.clear();
  }

  // ─── Private ────────────────────────────────────────────────────────

  /// (Re)start the inactivity timer for an inbound transfer.
  ///
  /// When a chunk arrives, this timer resets. If it fires (no new chunk
  /// within [SmRateLimit.chunkInactivityTimeout]), and the transfer still
  /// has missing chunks, we automatically send a NACK.
  void _restartInactivityTimer(String fileIdHex) {
    _chunkInactivityTimers[fileIdHex]?.cancel();
    _chunkInactivityTimers[fileIdHex] = Timer(
      SmRateLimit.chunkInactivityTimeout,
      () => _onChunkInactivityTimeout(fileIdHex),
    );
  }

  void _onChunkInactivityTimeout(String fileIdHex) {
    _chunkInactivityTimers.remove(fileIdHex);
    final transfer = _transfers[fileIdHex];
    if (transfer == null || !transfer.isActive) return;
    if (transfer.direction != TransferDirection.inbound) return;

    final missing = transfer.missingChunks;
    if (missing.isEmpty) return;

    AppLogging.fileTransfer(
      'INACTIVITY: $fileIdHex no chunk received for '
      '${SmRateLimit.chunkInactivityTimeout.inSeconds}s, '
      '${missing.length} chunks missing — auto-NACKing',
    );

    requestMissingChunks(fileIdHex);
  }

  void _cancelInactivityTimer(String fileIdHex) {
    _chunkInactivityTimers.remove(fileIdHex)?.cancel();
  }

  void _scheduleSendLoop() {
    if (_chunkTimer?.isActive ?? false) return;
    _chunkTimer = Timer.periodic(
      SmRateLimit.fileChunkInterval,
      (_) => _processSendQueue(),
    );
    // Also send immediately if rate limit allows
    _processSendQueue();
  }

  Future<void> _processSendQueue() async {
    if (_sendQueue.isEmpty) {
      _chunkTimer?.cancel();
      _chunkTimer = null;
      return;
    }

    // Global rate limit
    if (_lastGlobalSend != null) {
      final elapsed = DateTime.now().difference(_lastGlobalSend!);
      if (elapsed < SmRateLimit.fileChunkInterval) return;
    }

    final (fileIdHex, chunkIndex) = _sendQueue.removeAt(0);
    final transfer = _transfers[fileIdHex];
    if (transfer == null || !transfer.isActive) return;
    if (transfer.fileBytes == null) return;

    // Hard gate: never send chunks unless transfer is in chunking state.
    // This prevents data leakage if a chunk was enqueued before acceptance.
    if (transfer.state != TransferState.chunking) {
      AppLogging.fileTransfer(
        'BLOCKED chunk send: $fileIdHex [$chunkIndex] '
        'state=${transfer.state.name} (expected chunking)',
      );
      return;
    }

    // Calculate chunk boundaries
    final start = chunkIndex * transfer.chunkSize;
    final end = (start + transfer.chunkSize).clamp(0, transfer.totalBytes);
    if (start >= transfer.totalBytes) return;

    final chunkPayload = Uint8List.sublistView(transfer.fileBytes!, start, end);

    final chunk = SmFileChunk(
      fileId: transfer.fileId,
      chunkIndex: chunkIndex,
      chunkCount: transfer.chunkCount,
      payload: chunkPayload,
    );

    final encoded = chunk.encode();
    if (encoded == null) return;

    final sent = await _sendPacket(
      encoded,
      SmPortnum.fileTransfer,
      destinationNode: transfer.targetNodeNum,
      hopLimit: SmTransport.fileTransferHopLimit,
    );

    if (sent) {
      _lastGlobalSend = DateTime.now();
      _lastChunkSent[fileIdHex] = DateTime.now();

      final updatedChunks = Set<int>.from(transfer.completedChunks)
        ..add(chunkIndex);

      AppLogging.fileTransfer(
        'TX_CHUNK OK: $fileIdHex [$chunkIndex/${transfer.chunkCount}] '
        '${chunkPayload.length} bytes '
        '(${updatedChunks.length}/${transfer.chunkCount} complete)',
      );

      _updateState(
        fileIdHex,
        transfer.copyWith(completedChunks: updatedChunks),
      );

      // Check if all chunks sent
      if (updatedChunks.length == transfer.chunkCount) {
        AppLogging.fileTransfer(
          'TX COMPLETE: $fileIdHex all ${transfer.chunkCount} chunks sent',
        );
        _updateState(
          fileIdHex,
          _transfers[fileIdHex]!.copyWith(
            state: TransferState.complete,
            completedAt: DateTime.now(),
          ),
        );
      }
    } else {
      AppLogging.fileTransfer(
        'TX_CHUNK RETRY: $fileIdHex [$chunkIndex] send failed, re-queuing',
      );
      // Re-queue on failure (will respect rate limit on next tick)
      _sendQueue.add((fileIdHex, chunkIndex));
    }
  }

  void _tryCompleteInbound(String fileIdHex) {
    final transfer = _transfers[fileIdHex];
    if (transfer == null) return;

    _cancelInactivityTimer(fileIdHex);

    final chunks = _chunkBuffers[fileIdHex];
    if (chunks == null || chunks.length != transfer.chunkCount) return;

    AppLogging.fileTransfer(
      'REASSEMBLE: $fileIdHex assembling ${transfer.chunkCount} chunks '
      '(expected ${transfer.totalBytes} bytes)',
    );

    // Reassemble file
    final builder = BytesBuilder(copy: false);
    for (var i = 0; i < transfer.chunkCount; i++) {
      final chunk = chunks[i];
      if (chunk == null) {
        AppLogging.fileTransfer(
          'REASSEMBLE FAILED: $fileIdHex missing chunk $i',
        );
        _failTransfer(fileIdHex, TransferFailReason.invalid);
        return;
      }
      builder.add(chunk);
    }

    final fileBytes = builder.toBytes();

    // Verify size
    if (fileBytes.length != transfer.totalBytes) {
      AppLogging.fileTransfer(
        'REASSEMBLE FAILED: $fileIdHex size mismatch '
        '(got ${fileBytes.length}, expected ${transfer.totalBytes})',
      );
      _failTransfer(fileIdHex, TransferFailReason.invalid);
      return;
    }

    // Verify SHA-256
    final hash = sha256.convert(fileBytes);
    final expectedHash = transfer.sha256Hash;
    var hashMatch = hash.bytes.length == expectedHash.length;
    if (hashMatch) {
      for (var i = 0; i < hash.bytes.length; i++) {
        if (hash.bytes[i] != expectedHash[i]) {
          hashMatch = false;
          break;
        }
      }
    }
    if (!hashMatch) {
      AppLogging.fileTransfer('REASSEMBLE FAILED: $fileIdHex SHA-256 mismatch');
      _failTransfer(fileIdHex, TransferFailReason.hashMismatch);
      return;
    }

    AppLogging.fileTransfer(
      'REASSEMBLE OK: $fileIdHex verified ${fileBytes.length} bytes, '
      'sending ACK',
    );

    // Send ACK
    final ack = SmFileAck(
      fileId: transfer.fileId,
      status: FileAckStatus.complete,
    );
    final encoded = ack.encode();
    if (encoded != null) {
      _sendPacket(
        encoded,
        SmPortnum.fileTransfer,
        destinationNode: transfer.sourceNodeNum,
        hopLimit: SmTransport.fileTransferHopLimit,
      );
    }

    _updateState(
      fileIdHex,
      transfer.copyWith(
        state: TransferState.complete,
        completedAt: DateTime.now(),
        fileBytes: Uint8List.fromList(fileBytes),
      ),
    );

    // Free chunk buffer
    _chunkBuffers.remove(fileIdHex);

    AppLogging.fileTransfer(
      'RX COMPLETE: $fileIdHex (${transfer.filename}, '
      '${fileBytes.length} bytes)',
    );
  }

  void _failTransfer(String fileIdHex, TransferFailReason reason) {
    final transfer = _transfers[fileIdHex];
    if (transfer == null) return;

    _cancelInactivityTimer(fileIdHex);

    AppLogging.fileTransfer(
      'FAILED: $fileIdHex reason=${reason.name} '
      '(${transfer.filename}, ${transfer.direction.name})',
    );

    _updateState(
      fileIdHex,
      transfer.copyWith(state: TransferState.failed, failReason: reason),
    );

    _sendQueue.removeWhere((e) => e.$1 == fileIdHex);
    _chunkBuffers.remove(fileIdHex);
  }

  void _updateState(String fileIdHex, FileTransferState state) {
    _transfers[fileIdHex] = state;
    _onStateChanged(state);
  }
}
