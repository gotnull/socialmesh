// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas send coordinator — drains `pending_op` rows, batches them
// into canvas.v1 paint_batch frames via CanvasCodec, and pushes them
// through the rate-limit chain (canvas governor → SIP limiter → wire).
//
// Source-of-truth invariants (CANVAS_V0_1.md §6.2, §13):
//   - paint_batch caps at 21 ops (CanvasWireFormat.paintBatchMaxOps).
//   - one author per batch.
//   - ts_offset is signed i8 relative to batch_ts; this implementation
//     stays inside the 0..127 forward-only sub-range and splits across
//     multiple batches if ops span >127 s of wall clock.
//   - Mesh-canvas-only: Local Device Canvas paints never broadcast.
//   - Anti-starvation: canvas governor budget is consumed ONLY after
//     the outbound channel confirms the bytes hit the SIP gate. SIP
//     denial leaves the canvas governor untouched.
//   - Idempotent under repeated drain: rows transition to inFlight
//     before send, so a concurrent drain re-pick is impossible.
//
// What this layer deliberately does NOT do:
//   - MRRP / SIP frame wrapping: that lives behind the
//     `CanvasOutboundChannel` interface; the production binding (slice
//     S6) will wrap with MrrpCodec + SipCodec and call
//     `ProtocolService.sendSipGated(..., channelIndex:)`.
//   - Inbound op application (slice S5).
//   - Digest emission or sync_request scheduling (slice S9).
library;

import 'package:flutter/foundation.dart';

import '../../core/logging.dart';
import 'canvas_codec.dart';
import 'canvas_models.dart';
import 'canvas_outbound_governor.dart';
import 'canvas_repository.dart';

// ---------------------------------------------------------------------------
// Outbound channel abstraction
// ---------------------------------------------------------------------------

/// Outcome of a single `CanvasOutboundChannel.sendCanvasPayload` call.
enum CanvasSendOutcome {
  /// Bytes were accepted into the outbound pipeline. Pending rows can
  /// be deleted; canvas governor budget should be charged.
  sent,

  /// The **SIP rate limiter** refused the frame. The bytes never hit
  /// the air. Caller MUST NOT charge the canvas governor; the row
  /// stays queued under a backoff.
  sipRateLimited,

  /// Send failed for a reason other than rate-limiting (transport not
  /// connected, encoding rejection, transient I/O error). Caller bumps
  /// `attempts` via `markPendingFailed` and applies the backoff.
  transientFailure,
}

/// Result returned by [CanvasOutboundChannel.sendCanvasPayload].
@immutable
class CanvasSendResult {
  final CanvasSendOutcome outcome;

  /// On-wire byte count (full SIP-wrapped MRRP frame including
  /// headers). Reported for diagnostics / logging; the canvas governor
  /// charges the canvas payload size, not this.
  ///
  /// Zero on any non-`sent` outcome.
  final int wireBytes;

  /// Free-form short reason string. Used as the `last_error` value when
  /// the outcome is [CanvasSendOutcome.transientFailure].
  final String? reason;

  const CanvasSendResult({
    required this.outcome,
    required this.wireBytes,
    this.reason,
  });

  static const CanvasSendResult sipRateLimited = CanvasSendResult(
    outcome: CanvasSendOutcome.sipRateLimited,
    wireBytes: 0,
  );

  static CanvasSendResult sent({required int wireBytes}) =>
      CanvasSendResult(outcome: CanvasSendOutcome.sent, wireBytes: wireBytes);

  static CanvasSendResult failure(String reason) => CanvasSendResult(
    outcome: CanvasSendOutcome.transientFailure,
    wireBytes: 0,
    reason: reason,
  );
}

/// Wire-side adapter for the canvas send pipeline.
///
/// Implementations wrap the canvas-codec payload in an MRRP frame and
/// then a SIP frame, pre-check the SIP rate limiter, and hand the
/// final buffer to `ProtocolService.sendSipGated(..., channelIndex:)`.
/// The S4 layer treats this as a black-box `Future<CanvasSendResult>`
/// so the coordinator stays testable without dragging the full
/// protocol stack into unit tests. The concrete production binding
/// lives in slice S6.
abstract class CanvasOutboundChannel {
  Future<CanvasSendResult> sendCanvasPayload({
    required Uint8List canvasPayload,
    required int channelIndex,
  });
}

// ---------------------------------------------------------------------------
// Send coordinator
// ---------------------------------------------------------------------------

/// Stateful per-app-instance counter for the per-author `batch_seq`
/// field in `paint_batch` frames. Wraps mod-256 per spec §6.2.
class _BatchSeqCounter {
  int _next = 0;

  int takeNext() {
    final value = _next & 0xFF;
    _next = (_next + 1) & 0xFF;
    return value;
  }
}

/// Drains the canvas outbound queue, building paint_batch frames and
/// pushing them through the canvas governor + SIP limiter + wire.
///
/// **Threading note.** Dart isolates are single-threaded. The drain
/// loop awaits DB writes between picking a row and marking it
/// in-flight, but because no other isolate touches `pending_op`, the
/// `state = queued AND next_attempt_at_ms <= now` query is sufficient
/// to keep concurrent in-isolate `drain` invocations from re-picking
/// the same row.
class CanvasSendCoordinator {
  final CanvasRepository _repository;
  final CanvasOutboundGovernor _governor;
  final CanvasOutboundChannel _outbound;
  final int? Function() _localNodeNumProvider;

  /// Participation gate (CANVAS_PARTICIPATION_V0_1.md §5.3). Returns
  /// `true` when the user has opted into mesh participation. `drain`
  /// silently skips when this returns `false` and leaves rows in
  /// `pending_op` untouched (re-enabling participation later resumes
  /// the queue; we never drop user work). Default `() => true` keeps
  /// pre-existing tests that construct the coordinator without the
  /// gate green.
  final bool Function() _canSend;
  final int Function() _nowMs;
  final _BatchSeqCounter _batchSeq = _BatchSeqCounter();

  /// Per-batch backoff schedule: attempt 1 → 1 s, attempt 2 → 2 s,
  /// attempt 3 → 5 s, attempt 4 → 10 s, attempts ≥ 5 → 60 s. See
  /// CANVAS_V0_1.md §2 + the v0.1 plan §9.
  static const List<int> _backoffMsByAttempt = <int>[
    1000,
    2000,
    5000,
    10000,
    60000,
  ];

  /// Backoff applied when the canvas governor (250 B / 60 s) refuses a
  /// frame. Short — the window may free up bytes soon.
  static const Duration _governorBackoff = Duration(seconds: 1);

  /// Backoff applied when the SIP limiter refuses a frame. Slightly
  /// longer than the governor backoff because SIP is a more contended
  /// resource shared with DM / signal / overlay traffic.
  static const Duration _sipBackoff = Duration(seconds: 2);

  /// Reserved error code for ops that the coordinator could not encode.
  static const String _errorEncodeFailed = 'encode-failed';

  CanvasSendCoordinator({
    required CanvasRepository repository,
    required CanvasOutboundGovernor governor,
    required CanvasOutboundChannel outbound,
    required int? Function() localNodeNumProvider,
    bool Function()? canSend,
    int Function()? nowMs,
  }) : _repository = repository,
       _governor = governor,
       _outbound = outbound,
       _localNodeNumProvider = localNodeNumProvider,
       _canSend = canSend ?? (() => true),
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Maximum number of frames to emit in a single drain pass. Caps
  /// the wall-clock cost of one tick so the caller can re-invoke on a
  /// timer without monopolising the isolate.
  static const int defaultMaxFramesPerDrain = 8;

  /// One pass of the outbound queue. Returns the number of frames the
  /// outbound channel reported as accepted into the wire pipeline.
  ///
  /// Stops early when (a) no more ready queued ops remain, (b) the
  /// canvas governor refuses the next batch, (c) the SIP limiter
  /// refuses a frame (returns whatever already shipped), or (d)
  /// [maxFrames] frames have been emitted.
  Future<int> drain({int maxFrames = defaultMaxFramesPerDrain}) async {
    if (maxFrames <= 0) return 0;
    if (!_canSend()) {
      // Participation off — leave `pending_op` rows in place so they
      // resume on re-enable. NEVER drop user work here.
      // CANVAS_PARTICIPATION_V0_1.md §5.3.
      AppLogging.meshCanvas(
        'drain skipped: participation disabled', // lint-allow: hardcoded-string
      );
      return 0;
    }
    final localNodeNum = _localNodeNumProvider();
    if (localNodeNum == null) {
      AppLogging.meshCanvas(
        'drain skipped: local node num unknown', // lint-allow: hardcoded-string
      );
      return 0;
    }

    var framesSent = 0;
    while (framesSent < maxFrames) {
      final nowMs = _nowMs();
      // Fetch a pool of candidates large enough to fully populate one
      // batch from a single canvas. 64 leaves headroom for the
      // "different canvases" scan.
      final pool = await _repository.getQueuedReadyOps(nowMs: nowMs, limit: 64);
      if (pool.isEmpty) {
        AppLogging.meshCanvas('drain idle (frames sent=$framesSent)');
        return framesSent;
      }

      // Pick the canvas of the oldest ready op. Order within a canvas
      // is preserved by `pending_op.created_at_ms ASC, id ASC`.
      final targetCanvasLocalId = pool.first.canvasLocalId;
      final canvas = await _repository.getCanvasByLocalId(targetCanvasLocalId);

      // Defensive cleanup paths: an orphan or non-mesh canvas should
      // never reach `pending_op`. If it does (race with delete or a
      // future regression), silently discard the orphan rows so the
      // queue does not livelock.
      if (canvas == null) {
        await _discardOrphanRows(
          pool: pool,
          canvasLocalId: targetCanvasLocalId,
          reason: 'canvas-not-found', // lint-allow: hardcoded-string
        );
        continue;
      }
      if (canvas.scope != CanvasScope.mesh || canvas.channelIndex == null) {
        await _discardOrphanRows(
          pool: pool,
          canvasLocalId: targetCanvasLocalId,
          reason: 'non-mesh-scope-${canvas.scope.storageName}',
        );
        continue;
      }

      // Take up to 21 ops from this canvas, in oldest-first order.
      final candidates = pool
          .where((op) => op.canvasLocalId == targetCanvasLocalId)
          .toList();

      // Group into at most one paint_batch per drain iteration. The
      // _BatchPlan helper enforces (a) the 21-op cap, (b) the
      // 127-second forward span on `ts_offset`. Remaining candidates
      // wait for the next iteration (or the next drain call).
      final batchPlan = _planNextBatch(candidates);
      if (batchPlan.ops.isEmpty) {
        // Defensive — should never happen given `candidates.isNotEmpty`.
        return framesSent;
      }

      final encoded = _encodeBatch(
        canvas: canvas,
        batchPlan: batchPlan,
        authorId: localNodeNum,
      );
      if (encoded == null) {
        // Encoding rejected by spec invariants (e.g. invalid coord).
        // Treat every contributing row as terminally failed so the
        // queue does not livelock.
        for (final op in batchPlan.ops) {
          await _repository.markPendingFailed(
            op.id,
            error: _errorEncodeFailed,
            nextAttemptAtMs: nowMs + _backoffForAttempts(99),
          );
        }
        continue;
      }

      // Pre-check the canvas governor BEFORE marking rows in-flight so
      // a denied frame leaves the queue untouched and the next drain
      // call can pick the same rows up cleanly.
      if (!_governor.canSend(encoded.length)) {
        for (final op in batchPlan.ops) {
          await _repository.markPendingDeferred(
            op.id,
            nextAttemptAtMs: nowMs + _governorBackoff.inMilliseconds,
          );
        }
        AppLogging.meshCanvas(
          'drain throttled: canvas governor full '
          '(headroom=${_governor.remainingBytes}B, '
          'needed=${encoded.length}B, '
          'rows=${batchPlan.ops.length})',
        );
        return framesSent;
      }

      // Mark every contributing row inFlight so a concurrent drain
      // call cannot re-pick them.
      for (final op in batchPlan.ops) {
        await _repository.markPendingInFlight(op.id);
      }

      AppLogging.meshCanvas(
        'drain send canvas=$targetCanvasLocalId '
        'channel=${canvas.channelIndex} '
        'rows=${batchPlan.ops.length} payload=${encoded.length}B',
      );

      final result = await _outbound.sendCanvasPayload(
        canvasPayload: encoded,
        channelIndex: canvas.channelIndex!,
      );

      switch (result.outcome) {
        case CanvasSendOutcome.sent:
          _governor.recordSend(encoded.length);
          for (final op in batchPlan.ops) {
            await _repository.markPendingSent(op.id);
          }
          framesSent++;
          AppLogging.meshCanvas(
            'drain sent canvas=$targetCanvasLocalId '
            'rows=${batchPlan.ops.length} '
            'wire=${result.wireBytes}B',
          );
        case CanvasSendOutcome.sipRateLimited:
          // SIP refused the frame. The bytes never went on-air, so
          // the canvas governor is NOT charged. Push rows back to
          // queued state with a backoff that does not bump attempts.
          for (final op in batchPlan.ops) {
            await _repository.markPendingDeferred(
              op.id,
              nextAttemptAtMs: nowMs + _sipBackoff.inMilliseconds,
            );
          }
          AppLogging.meshCanvas(
            'drain SIP-throttled: canvas=$targetCanvasLocalId '
            'deferred rows=${batchPlan.ops.length}',
          );
          return framesSent;
        case CanvasSendOutcome.transientFailure:
          // Real failure (transport refused / encoding refused inside
          // the channel impl / etc.). Bump attempts so persistently
          // bad rows eventually hit failedTerminal.
          for (final op in batchPlan.ops) {
            final nextAttemptAtMs = nowMs + _backoffForAttempts(op.attempts);
            await _repository.markPendingFailed(
              op.id,
              error: result.reason ?? 'transient-failure',
              nextAttemptAtMs: nextAttemptAtMs,
            );
          }
          AppLogging.meshCanvas(
            'drain failure canvas=$targetCanvasLocalId '
            'reason=${result.reason ?? '(none)'} '
            'rows=${batchPlan.ops.length}',
          );
          return framesSent;
      }
    }
    return framesSent;
  }

  // ---------------------------------------------------------------------------
  // Test seams
  // ---------------------------------------------------------------------------

  /// Helper exposed for tests to compute the backoff for an `attempts`
  /// value without driving a full failure round-trip.
  @visibleForTesting
  static int debugBackoffMsForAttempts(int attempts) =>
      _backoffForAttempts(attempts);

  @visibleForTesting
  static int get debugGovernorBackoffMs => _governorBackoff.inMilliseconds;

  @visibleForTesting
  static int get debugSipBackoffMs => _sipBackoff.inMilliseconds;

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _discardOrphanRows({
    required List<PendingCanvasOp> pool,
    required int canvasLocalId,
    required String reason,
  }) async {
    final victims = pool.where((op) => op.canvasLocalId == canvasLocalId);
    for (final op in victims) {
      await _repository.markPendingSent(op.id);
    }
    AppLogging.meshCanvas(
      'drain discarded ${victims.length} orphan rows '
      'canvas=$canvasLocalId reason=$reason',
    );
  }

  _BatchPlan _planNextBatch(List<PendingCanvasOp> sameCanvasCandidates) {
    if (sameCanvasCandidates.isEmpty) {
      return const _BatchPlan(ops: <PendingCanvasOp>[], batchTs: 0);
    }
    final first = sameCanvasCandidates.first;
    final batchTs = first.opTs;
    final ops = <PendingCanvasOp>[first];
    for (var i = 1; i < sameCanvasCandidates.length; i++) {
      if (ops.length >= CanvasWireFormat.paintBatchMaxOps) break;
      final op = sameCanvasCandidates[i];
      final offset = op.opTs - batchTs;
      // Stay inside the forward [0, 127] half of the i8 ts_offset
      // range. Negative offsets (op timestamps that ran backwards)
      // close the current batch and wait for the next iteration to
      // re-anchor on a fresh batch_ts.
      if (offset < 0 || offset > 127) break;
      ops.add(op);
    }
    return _BatchPlan(ops: ops, batchTs: batchTs);
  }

  Uint8List? _encodeBatch({
    required CanvasSummary canvas,
    required _BatchPlan batchPlan,
    required int authorId,
  }) {
    final batchSeq = _batchSeq.takeNext();
    try {
      final records = <CanvasBatchedPaintRecord>[];
      for (final op in batchPlan.ops) {
        records.add(
          CanvasBatchedPaintRecord(
            x: op.x,
            y: op.y,
            color: op.color,
            tsOffset: op.opTs - batchPlan.batchTs,
            opSeq: op.opSeq & 0xFF,
          ),
        );
      }
      final batchOp = CanvasPaintBatchOp(
        canvasId: canvas.canvasId,
        authorId: authorId,
        batchTs: batchPlan.batchTs,
        batchSeq: batchSeq,
        ops: List.unmodifiable(records),
      );
      final encoded = CanvasCodec.encodePaintBatch(batchOp);
      if (encoded == null) {
        AppLogging.meshCanvas(
          'encode rejected by codec: canvas=${canvas.localId} '
          'rows=${batchPlan.ops.length}',
        );
      }
      return encoded;
    } on ArgumentError catch (e) {
      // Out-of-range row (corrupted cell coord, etc.). Should never
      // happen because the repository validates inputs on enqueue,
      // but stay defensive.
      AppLogging.meshCanvas('encode threw on canvas=${canvas.localId}: $e');
      return null;
    }
  }

  static int _backoffForAttempts(int attempts) {
    if (attempts <= 0) return _backoffMsByAttempt.first;
    if (attempts >= _backoffMsByAttempt.length) {
      return _backoffMsByAttempt.last;
    }
    return _backoffMsByAttempt[attempts];
  }
}

@immutable
class _BatchPlan {
  final List<PendingCanvasOp> ops;
  final int batchTs;
  const _BatchPlan({required this.ops, required this.batchTs});
}
