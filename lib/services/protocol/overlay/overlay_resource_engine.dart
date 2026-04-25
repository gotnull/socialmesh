// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Single-writer owner of SPP v0.2 resource transfer state (P4).
///
/// Mirrors the discipline of `OverlayLinkEngine`: every mutation of
/// a transfer row (and its chunks) flows through this engine. A
/// single async mutex guarantees that inbound frames, sender-side
/// window pushes, policy decisions, restore, expiry ticks, and
/// closes never race against each other.
///
/// P4 scope (per the approved phase boundaries):
///   - State machine + persistence only.
///   - No ProtocolService wiring. No timers. No UI.
///   - Outbound frames go to a narrow [OverlayResourceEgress].
///   - Tests drive `sendWindow`, `tick`, `handleInbound` directly.
///
/// Resource identity binds to the stable peer endpoint hint; `linkId`
/// is an advisory session-context column only, rewritable as links
/// turn over. This is the P4 locked design principle.
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../../core/logging.dart';
import '../../../utils/text_sanitizer.dart';
import 'overlay_bitmap.dart';
import 'overlay_constants.dart';
import 'overlay_resource_codec.dart';
import 'overlay_resource_egress.dart';
import 'overlay_resource_models.dart';
import 'overlay_resource_store.dart';
import 'overlay_types.dart';

/// Wall-clock source for the engine.
typedef OverlayResourceClock = int Function();

/// Random 4-byte resource id generator.
typedef OverlayResourceIdGenerator = int Function();

/// Single-writer resource engine.
class OverlayResourceEngine {
  final OverlayResourceStore _store;
  final OverlayResourceEgress _egress;
  final OverlayResourceClock _clock;
  final OverlayResourceIdGenerator _resourceIdGenerator;
  final int _defaultWindow;

  final StreamController<OverlayResourceEvent> _events =
      StreamController<OverlayResourceEvent>.broadcast();

  Future<void> _mutex = Future<void>.value();
  bool _disposed = false;

  OverlayResourceEngine({
    required OverlayResourceStore store,
    required OverlayResourceEgress egress,
    OverlayResourceClock? clock,
    OverlayResourceIdGenerator? resourceIdGenerator,
    int defaultWindow = OverlayResourceConstants.chunksPerAckWindow,
  }) : _store = store,
       _egress = egress,
       _clock = clock ?? _defaultClock,
       _resourceIdGenerator =
           resourceIdGenerator ?? _defaultResourceIdGenerator,
       _defaultWindow = defaultWindow;

  /// Stream of engine events. Broadcast; late subscribers do not
  /// replay.
  Stream<OverlayResourceEvent> get events => _events.stream;

  static int _defaultClock() => DateTime.now().millisecondsSinceEpoch;

  static final Random _secureRandom = Random.secure();

  static int _defaultResourceIdGenerator() {
    while (true) {
      final c = _secureRandom.nextInt(0xFFFFFFFF) + 1;
      if (c != 0 && c <= 0xFFFFFFFF) return c;
    }
  }

  // ---------------------------------------------------------------
  // Public API (all serialised through [_serialize]).
  // ---------------------------------------------------------------

  /// Sender: advertise a resource to [peerEndpointHint]. Persists the
  /// entire payload into `overlay_transfer_chunks` so the transfer
  /// survives restart. Emits `OFFER` via egress.
  ///
  /// Returns the freshly-created record.
  Future<OverlayResourceRecord> offerLocal({
    required Uint8List peerEndpointHint,
    required int peerNodeNum,
    required Uint8List payload,
    int chunkSize = OverlayResourceConstants.chunkSizeDefault,
    int? linkId,
    String? mimeType,
    String? filename,
  }) {
    return _serialize(
      () => _offerLocalLocked(
        peerEndpointHint: peerEndpointHint,
        peerNodeNum: peerNodeNum,
        payload: payload,
        chunkSize: chunkSize,
        linkId: linkId,
        mimeType: mimeType,
        filename: filename,
      ),
    );
  }

  /// Sender: push up to [windowSize] currently-unacked chunks. When
  /// there are no more unacked chunks and the record is in
  /// `transferring`, the sender transitions to `awaitingVerify` and
  /// emits `COMPLETE`. Returns the number of CHUNK frames actually
  /// emitted.
  Future<int> sendWindow({
    required Uint8List peerEndpointHint,
    required int resourceId,
    int? windowSize,
  }) {
    return _serialize(
      () => _sendWindowLocked(
        peerEndpointHint: peerEndpointHint,
        resourceId: resourceId,
        windowSize: windowSize ?? _defaultWindow,
      ),
    );
  }

  /// Receiver: accept an OFFER that was previously ingested and is
  /// currently in `evaluating`. Transitions the record to `accepting`
  /// and emits `ACCEPT` back to the sender.
  Future<OverlayResourceRecord> acceptOffer({
    required Uint8List peerEndpointHint,
    required int resourceId,
  }) {
    return _serialize(
      () => _acceptOfferLocked(
        peerEndpointHint: peerEndpointHint,
        resourceId: resourceId,
      ),
    );
  }

  /// Receiver: decline an OFFER. Transitions to `declined` and emits
  /// `DECLINE` with the supplied reason byte.
  Future<OverlayResourceRecord> declineOffer({
    required Uint8List peerEndpointHint,
    required int resourceId,
    OverlayLinkCloseReason reason = OverlayLinkCloseReason.declined,
  }) {
    return _serialize(
      () => _declineOfferLocked(
        peerEndpointHint: peerEndpointHint,
        resourceId: resourceId,
        reason: reason,
      ),
    );
  }

  /// Process an inbound SPP v0.2 frame from [senderEndpointHint].
  Future<void> handleInbound(
    OverlayResourceFrame frame, {
    required Uint8List senderEndpointHint,
    required int senderNodeNum,
    int? linkId,
  }) {
    return _serialize(
      () => _handleInboundLocked(
        frame,
        senderEndpointHint: senderEndpointHint,
        senderNodeNum: senderNodeNum,
        linkId: linkId,
      ),
    );
  }

  /// Periodic tick: expire stale non-terminal transfers and prune old
  /// terminal rows + their chunks.
  Future<void> tick() {
    return _serialize(_tickLocked);
  }

  /// Abort a transfer locally. Emits `ABORT` to the peer.
  Future<void> close({
    required Uint8List peerEndpointHint,
    required int resourceId,
    OverlayLinkCloseReason reason = OverlayLinkCloseReason.normal,
  }) {
    return _serialize(
      () => _closeLocked(
        peerEndpointHint: peerEndpointHint,
        resourceId: resourceId,
        reason: reason,
      ),
    );
  }

  /// Startup restore. Per spec §11.8:
  ///   - `receiving` rows stay `receiving` with their bitmap intact.
  ///   - `transferring` rows stay `transferring`; the next caller-
  ///     driven `sendWindow` (or an inbound BITMAP) resumes pushing.
  ///   - Expired rows transition to `failed(timeout)`.
  ///   - Any other non-terminal state (`offering`, `negotiating`,
  ///     `accepting`, `evaluating`, `awaitingVerify`, `verifying`) is
  ///     treated as non-resumable and transitions to `failed(timeout)` —
  ///     those states represent handshakes or in-memory work that
  ///     cannot safely continue mid-flight.
  Future<void> restore() {
    return _serialize(_restoreLocked);
  }

  /// Close the events stream. Does not close the store (provider owns).
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _events.close();
  }

  // ---------------------------------------------------------------
  // Single-writer plumbing.
  // ---------------------------------------------------------------

  Future<T> _serialize<T>(Future<T> Function() fn) {
    if (_disposed) {
      return Future<T>.error(
        StateError('OverlayResourceEngine has been disposed'),
      );
    }
    final prior = _mutex;
    final completer = Completer<T>();
    _mutex = prior.then((_) async {
      try {
        completer.complete(await fn());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  // ---------------------------------------------------------------
  // Sender flow.
  // ---------------------------------------------------------------

  Future<OverlayResourceRecord> _offerLocalLocked({
    required Uint8List peerEndpointHint,
    required int peerNodeNum,
    required Uint8List payload,
    required int chunkSize,
    required int? linkId,
    required String? mimeType,
    required String? filename,
  }) async {
    if (payload.length > OverlayResourceConstants.maxResourceBytes) {
      throw ArgumentError(
        'payload.length=${payload.length} exceeds maxResourceBytes='
        '${OverlayResourceConstants.maxResourceBytes}',
      );
    }
    if (chunkSize <= 0 ||
        chunkSize > OverlayResourceConstants.chunkPayloadCeilUnsigned) {
      throw ArgumentError(
        'chunkSize=$chunkSize out of range (1..'
        '${OverlayResourceConstants.chunkPayloadCeilUnsigned})',
      );
    }
    final resourceId = _resourceIdGenerator();
    final now = _clock();
    final chunkCount = payload.isEmpty
        ? 0
        : ((payload.length + chunkSize - 1) ~/ chunkSize);
    final sha = await _sha256(payload);

    // Persist the source payload as chunk rows so the sender can
    // resume after restart.
    for (var i = 0; i < chunkCount; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize) > payload.length
          ? payload.length
          : (start + chunkSize);
      await _store.putChunk(
        peerEndpointHint: peerEndpointHint,
        resourceId: resourceId,
        chunkIndex: i,
        data: Uint8List.fromList(payload.sublist(start, end)),
      );
    }

    final record = OverlayResourceRecord(
      resourceId: resourceId,
      peerEndpointHint: Uint8List.fromList(peerEndpointHint),
      peerNodeNum: peerNodeNum,
      linkId: linkId,
      role: OverlayResourceRole.sender,
      state: OverlayResourceState.offering,
      totalBytes: payload.length,
      chunkSize: chunkSize,
      chunkCount: chunkCount,
      sha256: sha,
      mimeType: mimeType,
      filename: filename,
      bitmap: OverlayBitmap.encode(const <int>{}, chunkCount),
      createdAtMs: now,
      lastActivityMs: now,
      expiresAtMs: now + OverlayResourceConstants.partialRetentionSec * 1000,
      retryCount: 0,
    );
    await _store.upsertTransfer(record);
    AppLogging.overlay(
      'resource OFFER local id=0x${resourceId.toRadixString(16)} '
      'peer=$peerNodeNum bytes=${payload.length} chunks=$chunkCount',
    );
    _emit(
      OverlayResourceEvent(
        kind: OverlayResourceEventKind.offered,
        record: record,
      ),
    );
    await _egress.sendFrame(
      frame: _buildOffer(record),
      peerEndpointHint: record.peerEndpointHint,
      peerNodeNum: record.peerNodeNum,
      linkId: record.linkId,
    );
    return record;
  }

  Future<int> _sendWindowLocked({
    required Uint8List peerEndpointHint,
    required int resourceId,
    required int windowSize,
  }) async {
    final record = await _store.getTransfer(peerEndpointHint, resourceId);
    if (record == null) return 0;
    if (record.role != OverlayResourceRole.sender) return 0;
    if (record.state != OverlayResourceState.transferring &&
        record.state != OverlayResourceState.negotiating) {
      return 0;
    }

    // Transition negotiating → transferring on the first send call.
    var working = record.state == OverlayResourceState.negotiating
        ? record.copyWith(state: OverlayResourceState.transferring)
        : record;

    final missing = OverlayBitmap.missingIndexes(
      working.bitmap,
      working.chunkCount,
    );
    if (missing.isEmpty) {
      // Sender has confirmation for every chunk — move to verify.
      final now = _clock();
      final advanced = working.copyWith(
        state: OverlayResourceState.awaitingVerify,
        lastActivityMs: now,
      );
      await _store.upsertTransfer(advanced);
      await _egress.sendFrame(
        frame: _buildComplete(advanced),
        peerEndpointHint: advanced.peerEndpointHint,
        peerNodeNum: advanced.peerNodeNum,
        linkId: advanced.linkId,
      );
      _emit(
        OverlayResourceEvent(
          kind: OverlayResourceEventKind.completing,
          record: advanced,
        ),
      );
      return 0;
    }

    final sendCount = missing.length < windowSize ? missing.length : windowSize;
    final now = _clock();
    var sent = 0;
    for (var i = 0; i < sendCount; i++) {
      final idx = missing[i];
      final data = await _store.getChunk(
        peerEndpointHint: working.peerEndpointHint,
        resourceId: working.resourceId,
        chunkIndex: idx,
      );
      if (data == null) {
        AppLogging.overlay(
          'resource sendWindow missing local chunk $idx — abort',
        );
        final failed = working.copyWith(
          state: OverlayResourceState.failed,
          closeReason: OverlayLinkCloseReason.internal,
          closedAtMs: now,
          lastActivityMs: now,
        );
        await _store.upsertTransfer(failed);
        _emit(
          OverlayResourceEvent(
            kind: OverlayResourceEventKind.terminated,
            record: failed,
            detail: 'local_chunk_missing',
          ),
        );
        return sent;
      }
      final ok = await _egress.sendFrame(
        frame: _buildChunk(working, idx, data),
        peerEndpointHint: working.peerEndpointHint,
        peerNodeNum: working.peerNodeNum,
        linkId: working.linkId,
      );
      if (ok) {
        sent++;
      }
    }
    if (sent > 0) {
      working = working.copyWith(lastActivityMs: now);
      await _store.upsertTransfer(working);
    } else if (working.state != record.state) {
      await _store.upsertTransfer(working);
    }
    return sent;
  }

  // ---------------------------------------------------------------
  // Receiver flow.
  // ---------------------------------------------------------------

  Future<OverlayResourceRecord> _acceptOfferLocked({
    required Uint8List peerEndpointHint,
    required int resourceId,
  }) async {
    final record = await _store.getTransfer(peerEndpointHint, resourceId);
    if (record == null) {
      throw StateError(
        'acceptOffer: no record for '
        'resourceId=0x${resourceId.toRadixString(16)}',
      );
    }
    if (record.role != OverlayResourceRole.receiver) {
      throw StateError('acceptOffer: record is not receiver-role');
    }
    if (record.state != OverlayResourceState.evaluating) {
      return record;
    }
    final now = _clock();
    final advanced = record.copyWith(
      state: OverlayResourceState.receiving,
      lastActivityMs: now,
    );
    await _store.upsertTransfer(advanced);
    AppLogging.overlay(
      'resource ACCEPT local '
      'id=0x${resourceId.toRadixString(16)} peer=${record.peerNodeNum}',
    );
    await _egress.sendFrame(
      frame: _buildAccept(advanced),
      peerEndpointHint: advanced.peerEndpointHint,
      peerNodeNum: advanced.peerNodeNum,
      linkId: advanced.linkId,
    );
    _emit(
      OverlayResourceEvent(
        kind: OverlayResourceEventKind.accepted,
        record: advanced,
      ),
    );
    return advanced;
  }

  Future<OverlayResourceRecord> _declineOfferLocked({
    required Uint8List peerEndpointHint,
    required int resourceId,
    required OverlayLinkCloseReason reason,
  }) async {
    final record = await _store.getTransfer(peerEndpointHint, resourceId);
    if (record == null) {
      throw StateError(
        'declineOffer: no record for '
        'resourceId=0x${resourceId.toRadixString(16)}',
      );
    }
    final now = _clock();
    final advanced = record.copyWith(
      state: OverlayResourceState.declined,
      closeReason: reason,
      closedAtMs: now,
      lastActivityMs: now,
    );
    await _store.upsertTransfer(advanced);
    await _egress.sendFrame(
      frame: _buildDecline(advanced, reason),
      peerEndpointHint: advanced.peerEndpointHint,
      peerNodeNum: advanced.peerNodeNum,
      linkId: advanced.linkId,
    );
    _emit(
      OverlayResourceEvent(
        kind: OverlayResourceEventKind.declined,
        record: advanced,
        detail: reason.name,
      ),
    );
    return advanced;
  }

  // ---------------------------------------------------------------
  // Inbound dispatch.
  // ---------------------------------------------------------------

  Future<void> _handleInboundLocked(
    OverlayResourceFrame frame, {
    required Uint8List senderEndpointHint,
    required int senderNodeNum,
    required int? linkId,
  }) async {
    switch (frame.type) {
      case OverlayResourceMsgType.offer:
        await _handleOffer(frame, senderEndpointHint, senderNodeNum, linkId);
      case OverlayResourceMsgType.accept:
        await _handleAccept(frame, senderEndpointHint, senderNodeNum, linkId);
      case OverlayResourceMsgType.decline:
        await _handleDecline(frame, senderEndpointHint);
      case OverlayResourceMsgType.chunk:
        await _handleChunk(frame, senderEndpointHint, senderNodeNum, linkId);
      case OverlayResourceMsgType.bitmap:
        await _handleBitmap(frame, senderEndpointHint);
      case OverlayResourceMsgType.nack:
        await _handleNack(frame, senderEndpointHint);
      case OverlayResourceMsgType.complete:
        await _handleComplete(frame, senderEndpointHint, senderNodeNum);
      case OverlayResourceMsgType.verified:
        await _handleVerified(frame, senderEndpointHint);
      case OverlayResourceMsgType.abort:
        await _handleAbort(frame, senderEndpointHint);
      case OverlayResourceMsgType.resume:
        await _handleResume(frame, senderEndpointHint);
    }
  }

  Future<void> _handleOffer(
    OverlayResourceFrame frame,
    Uint8List senderEndpointHint,
    int senderNodeNum,
    int? linkId,
  ) async {
    final existing = await _store.getTransfer(
      senderEndpointHint,
      frame.resourceId,
    );
    if (existing != null && !existing.isTerminal) {
      // Duplicate OFFER — ignore to preserve the current record.
      AppLogging.overlay(
        'resource OFFER duplicate id=0x${frame.resourceId.toRadixString(16)}',
      );
      return;
    }
    final manifest = _parseOfferPayload(frame.payload);
    if (manifest == null) {
      AppLogging.overlay('resource OFFER malformed payload — dropped');
      return;
    }
    final now = _clock();
    final record = OverlayResourceRecord(
      resourceId: frame.resourceId,
      peerEndpointHint: Uint8List.fromList(senderEndpointHint),
      peerNodeNum: senderNodeNum,
      linkId: linkId,
      role: OverlayResourceRole.receiver,
      state: OverlayResourceState.evaluating,
      totalBytes: manifest.totalBytes,
      chunkSize: manifest.chunkSize,
      chunkCount: frame.chunkCount,
      sha256: manifest.sha256,
      mimeType: manifest.mimeType,
      filename: manifest.filename,
      bitmap: OverlayBitmap.encode(const <int>{}, frame.chunkCount),
      createdAtMs: now,
      lastActivityMs: now,
      expiresAtMs: now + OverlayResourceConstants.partialRetentionSec * 1000,
      retryCount: 0,
    );
    await _store.upsertTransfer(record);
    _emit(
      OverlayResourceEvent(
        kind: OverlayResourceEventKind.offered,
        record: record,
      ),
    );
  }

  Future<void> _handleAccept(
    OverlayResourceFrame frame,
    Uint8List senderEndpointHint,
    int senderNodeNum,
    int? linkId,
  ) async {
    final record = await _store.getTransfer(
      senderEndpointHint,
      frame.resourceId,
    );
    if (record == null || record.role != OverlayResourceRole.sender) return;
    if (record.state != OverlayResourceState.offering) return;
    final now = _clock();
    final advanced = record.copyWith(
      state: OverlayResourceState.transferring,
      linkId: linkId ?? record.linkId,
      peerNodeNum: senderNodeNum,
      lastActivityMs: now,
    );
    await _store.upsertTransfer(advanced);
    _emit(
      OverlayResourceEvent(
        kind: OverlayResourceEventKind.accepted,
        record: advanced,
      ),
    );
  }

  Future<void> _handleDecline(
    OverlayResourceFrame frame,
    Uint8List senderEndpointHint,
  ) async {
    final record = await _store.getTransfer(
      senderEndpointHint,
      frame.resourceId,
    );
    if (record == null ||
        record.role != OverlayResourceRole.sender ||
        record.isTerminal) {
      return;
    }
    final reason = frame.payload.isEmpty
        ? OverlayLinkCloseReason.declined
        : OverlayLinkCloseReason.fromCode(frame.payload[0]) ??
              OverlayLinkCloseReason.declined;
    final now = _clock();
    final advanced = record.copyWith(
      state: OverlayResourceState.declined,
      closeReason: reason,
      closedAtMs: now,
      lastActivityMs: now,
    );
    await _store.upsertTransfer(advanced);
    _emit(
      OverlayResourceEvent(
        kind: OverlayResourceEventKind.declined,
        record: advanced,
        detail: reason.name,
      ),
    );
  }

  Future<void> _handleChunk(
    OverlayResourceFrame frame,
    Uint8List senderEndpointHint,
    int senderNodeNum,
    int? linkId,
  ) async {
    final record = await _store.getTransfer(
      senderEndpointHint,
      frame.resourceId,
    );
    if (record == null ||
        record.role != OverlayResourceRole.receiver ||
        record.isTerminal) {
      return;
    }
    if (frame.chunkIndex >= record.chunkCount) return;
    final existingBit =
        (record.bitmap[frame.chunkIndex >> 3] >> (frame.chunkIndex & 7)) & 0x01;
    if (existingBit == 1) {
      // Duplicate chunk — ignore without penalty.
      return;
    }
    await _store.putChunk(
      peerEndpointHint: record.peerEndpointHint,
      resourceId: record.resourceId,
      chunkIndex: frame.chunkIndex,
      data: frame.payload,
    );
    final newBitmap = Uint8List.fromList(record.bitmap);
    newBitmap[frame.chunkIndex >> 3] |= 1 << (frame.chunkIndex & 7);
    final now = _clock();
    final advanced = record.copyWith(
      bitmap: newBitmap,
      state: record.state == OverlayResourceState.accepting
          ? OverlayResourceState.receiving
          : record.state,
      lastActivityMs: now,
      linkId: linkId ?? record.linkId,
      peerNodeNum: senderNodeNum,
    );
    await _store.upsertTransfer(advanced);
    _emit(
      OverlayResourceEvent(
        kind: OverlayResourceEventKind.chunkStored,
        record: advanced,
      ),
    );

    // Emit a BITMAP every N chunks, and on completion.
    final received = OverlayBitmap.popcount(
      advanced.bitmap,
      advanced.chunkCount,
    );
    if (received == advanced.chunkCount ||
        received % OverlayResourceConstants.chunksPerAckWindow == 0) {
      await _egress.sendFrame(
        frame: _buildBitmap(advanced),
        peerEndpointHint: advanced.peerEndpointHint,
        peerNodeNum: advanced.peerNodeNum,
        linkId: advanced.linkId,
      );
    }
  }

  Future<void> _handleBitmap(
    OverlayResourceFrame frame,
    Uint8List senderEndpointHint,
  ) async {
    final record = await _store.getTransfer(
      senderEndpointHint,
      frame.resourceId,
    );
    if (record == null ||
        record.role != OverlayResourceRole.sender ||
        record.isTerminal) {
      return;
    }
    // Clamp the bitmap width to our chunkCount so peer-side extra
    // padding bits never mutate our view.
    final required = OverlayBitmap.byteLength(record.chunkCount);
    if (frame.payload.length < required) {
      AppLogging.overlay(
        'resource BITMAP too short for chunkCount=${record.chunkCount}',
      );
      return;
    }
    final newBitmap = Uint8List.fromList(frame.payload.sublist(0, required));
    // Mask any padding bits in the trailing byte to keep on-disk
    // bitmaps canonical (spec §11.4).
    final tailBits = record.chunkCount & 0x07;
    if (tailBits != 0 && required > 0) {
      final mask = (1 << tailBits) - 1;
      newBitmap[required - 1] &= mask;
    }
    final now = _clock();
    final advanced = record.copyWith(bitmap: newBitmap, lastActivityMs: now);
    await _store.upsertTransfer(advanced);
    _emit(
      OverlayResourceEvent(
        kind: OverlayResourceEventKind.bitmapObserved,
        record: advanced,
      ),
    );
  }

  Future<void> _handleNack(
    OverlayResourceFrame frame,
    Uint8List senderEndpointHint,
  ) async {
    // P4: NACK and BITMAP carry equivalent information; treat NACK
    // as a bitmap clear for the listed indexes. Reuse bitmap path.
    final record = await _store.getTransfer(
      senderEndpointHint,
      frame.resourceId,
    );
    if (record == null ||
        record.role != OverlayResourceRole.sender ||
        record.isTerminal) {
      return;
    }
    final newBitmap = Uint8List.fromList(record.bitmap);
    for (var i = 0; i + 1 < frame.payload.length; i += 2) {
      final bd = ByteData.view(
        frame.payload.buffer,
        frame.payload.offsetInBytes,
        frame.payload.length,
      );
      final idx = bd.getUint16(i, Endian.little);
      if (idx < record.chunkCount) {
        newBitmap[idx >> 3] &= ~(1 << (idx & 7)) & 0xFF;
      }
    }
    final now = _clock();
    final advanced = record.copyWith(bitmap: newBitmap, lastActivityMs: now);
    await _store.upsertTransfer(advanced);
    _emit(
      OverlayResourceEvent(
        kind: OverlayResourceEventKind.bitmapObserved,
        record: advanced,
        detail: 'nack',
      ),
    );
  }

  Future<void> _handleComplete(
    OverlayResourceFrame frame,
    Uint8List senderEndpointHint,
    int senderNodeNum,
  ) async {
    final record = await _store.getTransfer(
      senderEndpointHint,
      frame.resourceId,
    );
    if (record == null ||
        record.role != OverlayResourceRole.receiver ||
        record.isTerminal) {
      return;
    }
    if (frame.payload.length != 32) {
      AppLogging.overlay('resource COMPLETE bad sha256 length');
      return;
    }
    final now = _clock();
    final staged = record.copyWith(
      sha256: Uint8List.fromList(frame.payload),
      state: OverlayResourceState.verifying,
      lastActivityMs: now,
    );
    await _store.upsertTransfer(staged);
    _emit(
      OverlayResourceEvent(
        kind: OverlayResourceEventKind.completing,
        record: staged,
      ),
    );

    // Only verify if we have every chunk.
    final bitmapReceived = OverlayBitmap.popcount(
      staged.bitmap,
      staged.chunkCount,
    );
    if (bitmapReceived != staged.chunkCount) {
      // Missing chunks — send BITMAP and stay in receiving after
      // rolling the state back.
      final rolledBack = staged.copyWith(
        state: OverlayResourceState.receiving,
        lastActivityMs: now,
      );
      await _store.upsertTransfer(rolledBack);
      await _egress.sendFrame(
        frame: _buildBitmap(rolledBack),
        peerEndpointHint: rolledBack.peerEndpointHint,
        peerNodeNum: senderNodeNum,
        linkId: rolledBack.linkId,
      );
      return;
    }

    final assembled = await _store.assembleResource(
      peerEndpointHint: staged.peerEndpointHint,
      resourceId: staged.resourceId,
      chunkCount: staged.chunkCount,
    );
    if (assembled == null) {
      // Unexpected: bitmap says complete but store disagrees.
      AppLogging.overlay('resource COMPLETE assembly failed — corrupt');
      await _markCorrupt(staged, senderNodeNum);
      return;
    }
    final actualHash = await _sha256(assembled);
    final match = _bytesEqual(actualHash, staged.sha256!);
    if (!match) {
      await _markCorrupt(staged, senderNodeNum);
      return;
    }
    final done = staged.copyWith(
      state: OverlayResourceState.complete,
      closedAtMs: now,
      lastActivityMs: now,
      expiresAtMs:
          now + OverlayResourceConstants.completeMetaRetentionSec * 1000,
    );
    await _store.upsertTransfer(done);
    await _egress.sendFrame(
      frame: _buildVerified(done),
      peerEndpointHint: done.peerEndpointHint,
      peerNodeNum: senderNodeNum,
      linkId: done.linkId,
    );
    _emit(
      OverlayResourceEvent(
        kind: OverlayResourceEventKind.complete,
        record: done,
      ),
    );
  }

  Future<void> _markCorrupt(
    OverlayResourceRecord staged,
    int senderNodeNum,
  ) async {
    final now = _clock();
    final corrupt = staged.copyWith(
      state: OverlayResourceState.corrupt,
      closeReason: OverlayLinkCloseReason.authFailure,
      closedAtMs: now,
      lastActivityMs: now,
    );
    await _store.upsertTransfer(corrupt);
    await _egress.sendFrame(
      frame: _buildAbort(corrupt, OverlayLinkCloseReason.authFailure),
      peerEndpointHint: corrupt.peerEndpointHint,
      peerNodeNum: senderNodeNum,
      linkId: corrupt.linkId,
    );
    _emit(
      OverlayResourceEvent(
        kind: OverlayResourceEventKind.terminated,
        record: corrupt,
        detail: 'integrity_mismatch',
      ),
    );
  }

  Future<void> _handleVerified(
    OverlayResourceFrame frame,
    Uint8List senderEndpointHint,
  ) async {
    final record = await _store.getTransfer(
      senderEndpointHint,
      frame.resourceId,
    );
    if (record == null ||
        record.role != OverlayResourceRole.sender ||
        record.isTerminal) {
      return;
    }
    final now = _clock();
    final done = record.copyWith(
      state: OverlayResourceState.complete,
      closedAtMs: now,
      lastActivityMs: now,
      expiresAtMs:
          now + OverlayResourceConstants.completeMetaRetentionSec * 1000,
    );
    await _store.upsertTransfer(done);
    _emit(
      OverlayResourceEvent(
        kind: OverlayResourceEventKind.complete,
        record: done,
      ),
    );
  }

  Future<void> _handleAbort(
    OverlayResourceFrame frame,
    Uint8List senderEndpointHint,
  ) async {
    final record = await _store.getTransfer(
      senderEndpointHint,
      frame.resourceId,
    );
    if (record == null || record.isTerminal) return;
    final reason = frame.payload.isEmpty
        ? OverlayLinkCloseReason.normal
        : OverlayLinkCloseReason.fromCode(frame.payload[0]) ??
              OverlayLinkCloseReason.normal;
    final now = _clock();
    final advanced = record.copyWith(
      state: OverlayResourceState.cancelled,
      closeReason: reason,
      closedAtMs: now,
      lastActivityMs: now,
    );
    await _store.upsertTransfer(advanced);
    _emit(
      OverlayResourceEvent(
        kind: OverlayResourceEventKind.terminated,
        record: advanced,
        detail: reason.name,
      ),
    );
  }

  Future<void> _handleResume(
    OverlayResourceFrame frame,
    Uint8List senderEndpointHint,
  ) async {
    // Receiver-side: reply with a BITMAP of what we currently have.
    final record = await _store.getTransfer(
      senderEndpointHint,
      frame.resourceId,
    );
    if (record == null ||
        record.role != OverlayResourceRole.receiver ||
        record.isTerminal) {
      return;
    }
    await _egress.sendFrame(
      frame: _buildBitmap(record),
      peerEndpointHint: record.peerEndpointHint,
      peerNodeNum: record.peerNodeNum,
      linkId: record.linkId,
    );
  }

  // ---------------------------------------------------------------
  // Tick / restore / close.
  // ---------------------------------------------------------------

  Future<void> _tickLocked() async {
    final now = _clock();
    final rows = await _store.loadNonTerminal();
    for (final r in rows) {
      if (now >= r.expiresAtMs) {
        final failed = r.copyWith(
          state: OverlayResourceState.failed,
          closeReason: OverlayLinkCloseReason.timeout,
          closedAtMs: now,
          lastActivityMs: now,
        );
        await _store.upsertTransfer(failed);
        _emit(
          OverlayResourceEvent(
            kind: OverlayResourceEventKind.terminated,
            record: failed,
            detail: 'expired',
          ),
        );
      }
    }
    final cutoff =
        now - OverlayResourceConstants.completeMetaRetentionSec * 1000;
    final pruned = await _store.pruneTerminalOlderThan(cutoff);
    if (pruned > 0) {
      AppLogging.overlay('resource GC removed $pruned terminal rows');
    }
  }

  Future<void> _closeLocked({
    required Uint8List peerEndpointHint,
    required int resourceId,
    required OverlayLinkCloseReason reason,
  }) async {
    final record = await _store.getTransfer(peerEndpointHint, resourceId);
    if (record == null || record.isTerminal) return;
    final now = _clock();
    final advanced = record.copyWith(
      state: OverlayResourceState.cancelled,
      closeReason: reason,
      closedAtMs: now,
      lastActivityMs: now,
    );
    await _store.upsertTransfer(advanced);
    await _egress.sendFrame(
      frame: _buildAbort(advanced, reason),
      peerEndpointHint: advanced.peerEndpointHint,
      peerNodeNum: advanced.peerNodeNum,
      linkId: advanced.linkId,
    );
    _emit(
      OverlayResourceEvent(
        kind: OverlayResourceEventKind.terminated,
        record: advanced,
        detail: reason.name,
      ),
    );
  }

  Future<void> _restoreLocked() async {
    final rows = await _store.loadAll();
    final now = _clock();
    for (final r in rows) {
      if (r.isTerminal) continue;
      if (now >= r.expiresAtMs) {
        final failed = r.copyWith(
          state: OverlayResourceState.failed,
          closeReason: OverlayLinkCloseReason.timeout,
          closedAtMs: now,
          lastActivityMs: now,
        );
        await _store.upsertTransfer(failed);
        _emit(
          OverlayResourceEvent(
            kind: OverlayResourceEventKind.restored,
            record: failed,
            detail: 'expired',
          ),
        );
        continue;
      }
      switch (r.state) {
        case OverlayResourceState.receiving:
        case OverlayResourceState.transferring:
          // Resumable: keep state; the next inbound or sendWindow
          // call resumes progress.
          _emit(
            OverlayResourceEvent(
              kind: OverlayResourceEventKind.restored,
              record: r,
              detail: 'resumable',
            ),
          );
        case OverlayResourceState.offering:
        case OverlayResourceState.negotiating:
        case OverlayResourceState.accepting:
        case OverlayResourceState.evaluating:
        case OverlayResourceState.awaitingVerify:
        case OverlayResourceState.verifying:
        case OverlayResourceState.idle:
          final failed = r.copyWith(
            state: OverlayResourceState.failed,
            closeReason: OverlayLinkCloseReason.timeout,
            closedAtMs: now,
            lastActivityMs: now,
          );
          await _store.upsertTransfer(failed);
          _emit(
            OverlayResourceEvent(
              kind: OverlayResourceEventKind.restored,
              record: failed,
              detail: 'non_resumable_state',
            ),
          );
        case OverlayResourceState.complete:
        case OverlayResourceState.failed:
        case OverlayResourceState.cancelled:
        case OverlayResourceState.declined:
        case OverlayResourceState.corrupt:
          // Terminal — keep as-is.
          break;
      }
    }
  }

  // ---------------------------------------------------------------
  // Frame builders.
  // ---------------------------------------------------------------

  OverlayResourceFrame _buildOffer(OverlayResourceRecord r) {
    // Compact manifest: totalBytes(u32 LE) + chunkSize(u16 LE) +
    // sha256(32) + mimeLen(u8) + mime + nameLen(u8) + name.
    final mimeBytes = r.mimeType == null
        ? Uint8List(0)
        : Uint8List.fromList(r.mimeType!.codeUnits);
    final nameBytes = r.filename == null
        ? Uint8List(0)
        : Uint8List.fromList(r.filename!.codeUnits);
    if (mimeBytes.length > 255 || nameBytes.length > 255) {
      throw ArgumentError('mimeType or filename too long (>255 B)');
    }
    final body = BytesBuilder(copy: false);
    final hdr = ByteData(4 + 2 + 32 + 1 + 1);
    hdr.setUint32(0, r.totalBytes, Endian.little);
    hdr.setUint16(4, r.chunkSize, Endian.little);
    body.add(hdr.buffer.asUint8List(0, 6));
    body.add(r.sha256!);
    body.add(Uint8List.fromList(<int>[mimeBytes.length]));
    body.add(mimeBytes);
    body.add(Uint8List.fromList(<int>[nameBytes.length]));
    body.add(nameBytes);
    return OverlayResourceFrame(
      type: OverlayResourceMsgType.offer,
      resourceId: r.resourceId,
      chunkCount: r.chunkCount,
      payload: body.toBytes(),
    );
  }

  OverlayResourceFrame _buildAccept(OverlayResourceRecord r) =>
      OverlayResourceFrame(
        type: OverlayResourceMsgType.accept,
        resourceId: r.resourceId,
        chunkCount: r.chunkCount,
        payload: Uint8List(0),
      );

  OverlayResourceFrame _buildDecline(
    OverlayResourceRecord r,
    OverlayLinkCloseReason reason,
  ) => OverlayResourceFrame(
    type: OverlayResourceMsgType.decline,
    resourceId: r.resourceId,
    payload: Uint8List.fromList(<int>[reason.code]),
  );

  OverlayResourceFrame _buildChunk(
    OverlayResourceRecord r,
    int index,
    Uint8List data,
  ) => OverlayResourceFrame(
    type: OverlayResourceMsgType.chunk,
    resourceId: r.resourceId,
    chunkIndex: index,
    chunkCount: r.chunkCount,
    payload: data,
  );

  OverlayResourceFrame _buildBitmap(OverlayResourceRecord r) =>
      OverlayResourceFrame(
        type: OverlayResourceMsgType.bitmap,
        resourceId: r.resourceId,
        chunkCount: r.chunkCount,
        payload: Uint8List.fromList(r.bitmap),
      );

  OverlayResourceFrame _buildComplete(OverlayResourceRecord r) =>
      OverlayResourceFrame(
        type: OverlayResourceMsgType.complete,
        resourceId: r.resourceId,
        chunkCount: r.chunkCount,
        payload: r.sha256!,
      );

  OverlayResourceFrame _buildVerified(OverlayResourceRecord r) =>
      OverlayResourceFrame(
        type: OverlayResourceMsgType.verified,
        resourceId: r.resourceId,
        payload: Uint8List(0),
      );

  OverlayResourceFrame _buildAbort(
    OverlayResourceRecord r,
    OverlayLinkCloseReason reason,
  ) => OverlayResourceFrame(
    type: OverlayResourceMsgType.abort,
    resourceId: r.resourceId,
    payload: Uint8List.fromList(<int>[reason.code]),
  );

  // ---------------------------------------------------------------
  // Offer payload parsing helper.
  // ---------------------------------------------------------------

  _OfferManifest? _parseOfferPayload(Uint8List payload) {
    try {
      if (payload.length < 6 + 32 + 1 + 1) return null;
      final bd = ByteData.view(
        payload.buffer,
        payload.offsetInBytes,
        payload.length,
      );
      final total = bd.getUint32(0, Endian.little);
      final chunkSize = bd.getUint16(4, Endian.little);
      final sha = Uint8List.fromList(payload.sublist(6, 6 + 32));
      var off = 6 + 32;
      final mimeLen = payload[off++];
      if (off + mimeLen > payload.length) return null;
      final mime = mimeLen == 0
          ? null
          : sanitizeExternalText(
              String.fromCharCodes(payload.sublist(off, off + mimeLen)),
            );
      off += mimeLen;
      if (off >= payload.length) return null;
      final nameLen = payload[off++];
      if (off + nameLen > payload.length) return null;
      final name = nameLen == 0
          ? null
          : sanitizeExternalText(
              String.fromCharCodes(payload.sublist(off, off + nameLen)),
            );
      return _OfferManifest(
        totalBytes: total,
        chunkSize: chunkSize,
        sha256: sha,
        mimeType: mime,
        filename: name,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _sha256(Uint8List data) async {
    final hash = await Sha256().hash(data);
    return Uint8List.fromList(hash.bytes);
  }

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _emit(OverlayResourceEvent event) {
    if (_events.isClosed) return;
    _events.add(event);
  }
}

class _OfferManifest {
  final int totalBytes;
  final int chunkSize;
  final Uint8List sha256;
  final String? mimeType;
  final String? filename;
  const _OfferManifest({
    required this.totalBytes,
    required this.chunkSize,
    required this.sha256,
    required this.mimeType,
    required this.filename,
  });
}
