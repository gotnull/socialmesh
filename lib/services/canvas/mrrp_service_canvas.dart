// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MRRP service handler for canvas.v1 (service_id 0x00000007).
//
// Responsibilities (S5):
//   - Decode inbound paint / paint_batch frames via CanvasCodec.
//   - Apply them through CanvasRepository.applyInboundPaint, which runs
//     the LWW comparator (`canvas_merge.dart`) and the 6-field op-layer
//     dedupe.
//   - Enforce the canvas decoder-side per-sender inbound cap
//     (`canvasMaxInboundFramesPerSenderPer60s = 12`). Keyed by Meshtastic
//     senderNodeId, NOT the canvas payload's author_id (the latter is
//     attacker-controlled).
//   - Enforce the op_ts replay window (`now - 7 d`, `now + 5 min`).
//   - Find or create mesh canvases on first inbound op.
//
// Out of scope for S5 (deferred to S9):
//   - canvas_digest emission / processing.
//   - sync_request / sync_response handling.
//   - canvas_info request / response semantics.
//
// Inbound action handling in S5: paint and paint_batch APPLY. digest,
// sync_request, sync_response, canvas_info are decoded only and produce
// an empty-OK response so peers do not see ERROR(UNSUPPORTED). S9 will
// replace the no-op bodies with real handlers.
//
// Channel index plumbing: the existing MRRP dispatcher does not carry
// Meshtastic `packet.channel` into handlers. S5 exposes two entry
// points:
//
//   - [applyInbound] — direct call with explicit channelIndex. Used by
//     tests, and (in S6) by `ProtocolService` after sniffing
//     canvas.v1 frames out of the inbound SIP path.
//   - [handleRequest] — the standard `MrrpServiceHandler` interface
//     called by the dispatcher. channelIndex is unavailable here, so
//     the frame is logged and dropped (no apply). S6 will add a
//     channel-aware dispatch path; until then, real wire delivery
//     MUST go through `applyInbound`.
library;

import 'dart:typed_data';

import '../../core/logging.dart';
import '../protocol/sip/mrrp_constants.dart';
import '../protocol/sip/mrrp_frame.dart';
import '../protocol/sip/mrrp_service_handler.dart';
import '../protocol/sip/mrrp_types.dart';
import 'canvas_codec.dart';
import 'canvas_constants.dart';
import 'canvas_inbound_limiter.dart';
import 'canvas_models.dart';
import 'canvas_repository.dart';

// ---------------------------------------------------------------------------
// Replay window constants
// ---------------------------------------------------------------------------

/// Reject ops whose `op_ts` is more than this far in the past.
const Duration kCanvasReplayOldThreshold = Duration(days: 7);

/// Reject ops whose `op_ts` is more than this far in the future. Allows
/// for ~5 minutes of clock skew across the mesh, per CANVAS_V0_1.md §9.
const Duration kCanvasReplayFutureThreshold = Duration(minutes: 5);

/// Sentinel passed to [MrrpServiceCanvas.applyInbound] when the caller
/// has no channel context (e.g., the legacy dispatcher path). The
/// service treats this value as "channel unknown — drop after logging".
const int kCanvasChannelIndexUnknown = -1;

// ---------------------------------------------------------------------------
// Apply outcome (telemetry / test introspection)
// ---------------------------------------------------------------------------

/// Per-frame outcome returned by [MrrpServiceCanvas.applyInbound].
/// Exposed for test introspection so the integration suite can assert
/// the exact decision path without scraping log lines.
enum CanvasInboundOutcome {
  /// One or more cell ops were accepted into canonical state.
  applied,

  /// Frame was decoded but contained no applicable ops (e.g., digest /
  /// sync / info action in S5).
  acceptedNoOp,

  /// At least one op fell outside the replay window AND no other ops
  /// were applied. Mixed batches (some applied, some replay-rejected)
  /// report [applied] with [CanvasInboundReport.replayWindowRejectedCount]
  /// populated.
  staleReplayWindow,

  /// Frame was dropped because the per-sender 12/60s cap was exceeded.
  rateLimited,

  /// Frame failed codec validation (wrong magic, truncated, etc.).
  decodeFailed,

  /// channelIndex was [kCanvasChannelIndexUnknown] — handler has no
  /// safe way to bind the canvas, so the frame was dropped.
  noChannelContext,
}

/// Aggregate result of applying one inbound canvas.v1 frame.
///
/// `appliedCount` and `replayWindowRejectedCount` are authoritative.
/// Dup-vs-LWW-stale is intentionally NOT split at this layer — the
/// repository conflates both into "applyInboundPaint returns false",
/// and the distinction is observable via the `applied_op` table
/// (dups skip the row entirely; LWW-stale insert with was_accepted=0).
class CanvasInboundReport {
  final CanvasInboundOutcome outcome;

  /// Number of ops the repository accepted (cell mutated).
  final int appliedCount;

  /// Number of ops dropped because their `op_ts` was outside the
  /// 7d-back / 5min-forward replay window.
  final int replayWindowRejectedCount;

  /// Number of ops the repository did not accept for a non-replay-
  /// window reason (LWW stale OR 6-field dedupe duplicate; not
  /// disambiguated at this layer).
  final int unappliedByRepositoryCount;

  const CanvasInboundReport({
    required this.outcome,
    this.appliedCount = 0,
    this.replayWindowRejectedCount = 0,
    this.unappliedByRepositoryCount = 0,
  });
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

/// MRRP service handler for canvas.v1.
///
/// Stateful per app: owns the per-sender inbound limiter. The repository
/// reference and clock are injected. Safe to register once at boot and
/// keep alive for the app lifetime.
class MrrpServiceCanvas implements MrrpServiceHandler {
  final CanvasRepository _repository;
  final CanvasInboundLimiter _inboundLimiter;
  final int Function() _nowMs;

  /// Optional human-readable channel name lookup, e.g., from
  /// Meshtastic config. Returns null when the channel is unknown or
  /// the caller does not supply a lookup. When null, auto-created
  /// canvases fall back to `"Canvas <channelIndex>"`.
  final String? Function(int channelIndex)? _channelNameForFallback;

  /// Fires once per [applyInbound] call when at least one op was
  /// accepted into canonical state. The provider layer wires this to
  /// invalidate `canvasCellsProvider(canvasLocalId)` so live viewers
  /// repaint without waiting for a local tap. Without it, inbound
  /// paints land in SQLite but no viewer rebuilds — the user only
  /// sees them after they themselves paint and trigger a manual
  /// invalidate.
  final void Function(int canvasLocalId)? _onCellApplied;

  MrrpServiceCanvas({
    required CanvasRepository repository,
    CanvasInboundLimiter? limiter,
    int Function()? nowMs,
    String? Function(int channelIndex)? channelNameForFallback,
    void Function(int canvasLocalId)? onCellApplied,
  }) : _repository = repository,
       _inboundLimiter = limiter ?? CanvasInboundLimiter(nowMs: nowMs),
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       _channelNameForFallback = channelNameForFallback,
       _onCellApplied = onCellApplied;

  @override
  int get serviceId => MrrpServiceId.canvasV1;

  /// All six v0.1 action IDs are claimed so the dispatcher routes them
  /// here instead of returning ERROR(UNSUPPORTED). Actions outside
  /// paint / paint_batch are decoded then no-op'd in S5; full handling
  /// lands in S9.
  @override
  Set<int> get supportedActions => const <int>{
    0x0001, // paint
    0x0002, // paint_batch
    0x0003, // canvas_digest (S5 no-op; S9 implements)
    0x0004, // sync_request (S5 no-op; S9 implements)
    0x0005, // sync_response (S5 no-op; S9 implements)
    0x0006, // canvas_info (S5 no-op; S9 implements)
  };

  /// Dispatcher-routed entry point. Channel context is not available
  /// via the standard `MrrpServiceHandler` contract; the frame is
  /// logged and dropped without applying. Real wire delivery MUST use
  /// [applyInbound] with an explicit channelIndex (S6 wiring task).
  @override
  Future<MrrpFrame> handleRequest(MrrpFrame request, int senderNodeId) async {
    await applyInbound(
      canvasPayload: request.payload,
      senderNodeId: senderNodeId,
      channelIndex: kCanvasChannelIndexUnknown,
    );
    return _emptyOkResponse(request);
  }

  /// Direct apply entry point — used by tests and (post-S6) by the
  /// ProtocolService canvas demux. Returns a [CanvasInboundReport]
  /// describing the outcome.
  ///
  /// [channelIndex] MUST be the Meshtastic channel the originating
  /// packet rode on, or [kCanvasChannelIndexUnknown] when unavailable.
  Future<CanvasInboundReport> applyInbound({
    required Uint8List canvasPayload,
    required int senderNodeId,
    required int channelIndex,
  }) async {
    // Per-sender inbound cap. Drop silently with a debug log when the
    // sender has used its full window allowance.
    if (!_inboundLimiter.allow(senderNodeId)) {
      AppLogging.meshCanvas(
        'inbound dropped: sender=0x${senderNodeId.toRadixString(16)} '
        'exceeded ${_inboundLimiter.capPerSender} frames/'
        '${_inboundLimiter.window.inSeconds}s',
      );
      return const CanvasInboundReport(
        outcome: CanvasInboundOutcome.rateLimited,
      );
    }

    final action = CanvasCodec.sniffAction(canvasPayload);
    if (action == null) {
      AppLogging.meshCanvas(
        'inbound dropped: sender=0x${senderNodeId.toRadixString(16)} '
        'unrecognised canvas.v1 frame (sniff failed)',
      );
      return const CanvasInboundReport(
        outcome: CanvasInboundOutcome.decodeFailed,
      );
    }

    switch (action) {
      case CanvasAction.paint:
        return _handlePaint(
          payload: canvasPayload,
          senderNodeId: senderNodeId,
          channelIndex: channelIndex,
        );
      case CanvasAction.paintBatch:
        return _handlePaintBatch(
          payload: canvasPayload,
          senderNodeId: senderNodeId,
          channelIndex: channelIndex,
        );
      case CanvasAction.canvasDigest:
      case CanvasAction.syncRequest:
      case CanvasAction.syncResponse:
      case CanvasAction.canvasInfo:
        // S5: decode-only no-op. Full handling lands in S9.
        AppLogging.meshCanvas(
          'inbound ${action.name} from sender=0x'
          '${senderNodeId.toRadixString(16)} '
          'channel=$channelIndex — decoded, no-op in S5',
        );
        return const CanvasInboundReport(
          outcome: CanvasInboundOutcome.acceptedNoOp,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // paint
  // ---------------------------------------------------------------------------

  Future<CanvasInboundReport> _handlePaint({
    required Uint8List payload,
    required int senderNodeId,
    required int channelIndex,
  }) async {
    final op = CanvasCodec.decodePaint(payload);
    if (op == null) {
      AppLogging.meshCanvas(
        'inbound paint: decode failed from sender=0x'
        '${senderNodeId.toRadixString(16)}',
      );
      return const CanvasInboundReport(
        outcome: CanvasInboundOutcome.decodeFailed,
      );
    }

    final canvas = await _findOrCreateCanvas(
      canvasId: op.canvasId,
      channelIndex: channelIndex,
      ownerNodeNum: op.authorId,
    );
    if (canvas == null) {
      return const CanvasInboundReport(
        outcome: CanvasInboundOutcome.noChannelContext,
      );
    }

    if (!_passesReplayWindow(op.opTs)) {
      AppLogging.meshCanvas(
        'inbound paint: op_ts=${op.opTs} outside replay window '
        '(now=${_nowMs() ~/ 1000})',
      );
      return const CanvasInboundReport(
        outcome: CanvasInboundOutcome.staleReplayWindow,
        replayWindowRejectedCount: 1,
      );
    }

    final accepted = await _applyOne(
      canvas: canvas,
      x: op.x,
      y: op.y,
      color: op.color,
      authorId: op.authorId,
      opTs: op.opTs,
      opSeq: op.opSeq,
    );

    if (accepted) {
      _onCellApplied?.call(canvas.localId);
    }

    return CanvasInboundReport(
      outcome: accepted
          ? CanvasInboundOutcome.applied
          : CanvasInboundOutcome.acceptedNoOp,
      appliedCount: accepted ? 1 : 0,
      unappliedByRepositoryCount: accepted ? 0 : 1,
    );
  }

  // ---------------------------------------------------------------------------
  // paint_batch
  // ---------------------------------------------------------------------------

  Future<CanvasInboundReport> _handlePaintBatch({
    required Uint8List payload,
    required int senderNodeId,
    required int channelIndex,
  }) async {
    final batch = CanvasCodec.decodePaintBatch(payload);
    if (batch == null) {
      AppLogging.meshCanvas(
        'inbound paint_batch: decode failed from sender=0x'
        '${senderNodeId.toRadixString(16)}',
      );
      return const CanvasInboundReport(
        outcome: CanvasInboundOutcome.decodeFailed,
      );
    }

    final canvas = await _findOrCreateCanvas(
      canvasId: batch.canvasId,
      channelIndex: channelIndex,
      ownerNodeNum: batch.authorId,
    );
    if (canvas == null) {
      return const CanvasInboundReport(
        outcome: CanvasInboundOutcome.noChannelContext,
      );
    }

    var applied = 0;
    var unappliedByRepository = 0;
    var replayWindowRejected = 0;

    for (final record in batch.ops) {
      // Per-op effective timestamp, clamped to >= 0 per spec §6.2.
      final effectiveTs = batch.batchTs + record.tsOffset;
      final opTs = effectiveTs < 0 ? 0 : effectiveTs;

      if (!_passesReplayWindow(opTs)) {
        replayWindowRejected++;
        AppLogging.meshCanvas(
          'inbound paint_batch record: op_ts=$opTs outside replay window '
          '(now=${_nowMs() ~/ 1000})',
        );
        continue;
      }

      final accepted = await _applyOne(
        canvas: canvas,
        x: record.x,
        y: record.y,
        color: record.color,
        authorId: batch.authorId,
        opTs: opTs,
        opSeq: record.opSeq,
      );
      if (accepted) {
        applied++;
      } else {
        unappliedByRepository++;
      }
    }

    AppLogging.meshCanvas(
      'inbound paint_batch from sender=0x'
      '${senderNodeId.toRadixString(16)} canvas=${canvas.localId} '
      'channel=$channelIndex ops=${batch.ops.length} '
      'applied=$applied unapplied=$unappliedByRepository '
      'replay-window=$replayWindowRejected',
    );

    if (applied > 0) {
      _onCellApplied?.call(canvas.localId);
    }

    final CanvasInboundOutcome outcome;
    if (applied > 0) {
      outcome = CanvasInboundOutcome.applied;
    } else if (replayWindowRejected > 0) {
      outcome = CanvasInboundOutcome.staleReplayWindow;
    } else {
      outcome = CanvasInboundOutcome.acceptedNoOp;
    }
    return CanvasInboundReport(
      outcome: outcome,
      appliedCount: applied,
      unappliedByRepositoryCount: unappliedByRepository,
      replayWindowRejectedCount: replayWindowRejected,
    );
  }

  // ---------------------------------------------------------------------------
  // Shared apply path
  // ---------------------------------------------------------------------------

  /// Apply one op through the repository and return whether the cell
  /// was mutated.
  ///
  /// `applyInboundPaint` returns false for two distinct reasons:
  ///   (a) the 6-field dedupe matched an earlier op (no applied_op
  ///       row inserted, no cell mutation), OR
  ///   (b) the LWW comparator rejected the op as stale (applied_op
  ///       row inserted with was_accepted=0, no cell mutation).
  /// At this layer the two cases are intentionally conflated; tests
  /// distinguish them by inspecting the `applied_op` table directly.
  Future<bool> _applyOne({
    required CanvasSummary canvas,
    required int x,
    required int y,
    required int color,
    required int authorId,
    required int opTs,
    required int opSeq,
  }) {
    return _repository.applyInboundPaint(
      canvasLocalId: canvas.localId,
      op: InboundPaintOp(
        x: x,
        y: y,
        color: color,
        authorNodeNum: authorId,
        opTs: opTs,
        opSeq: opSeq,
      ),
      receivedAtMsOverride: _nowMs(),
    );
  }

  // ---------------------------------------------------------------------------
  // Canvas lookup / creation
  // ---------------------------------------------------------------------------

  /// Find an existing mesh canvas, or create one keyed on
  /// `(canvas_id, channel_index)`. Returns null when [channelIndex] is
  /// the unknown sentinel — the dispatcher path lands here.
  Future<CanvasSummary?> _findOrCreateCanvas({
    required int canvasId,
    required int channelIndex,
    required int ownerNodeNum,
  }) async {
    if (channelIndex == kCanvasChannelIndexUnknown) {
      AppLogging.meshCanvas(
        'inbound dropped: no channel context for canvas=0x'
        '${canvasId.toRadixString(16)} (dispatcher path; '
        'S6 will plumb channelIndex)',
      );
      return null;
    }
    if (channelIndex < 0 || channelIndex > CanvasLimits.channelIndexMax) {
      AppLogging.meshCanvas(
        'inbound dropped: invalid channelIndex=$channelIndex for canvas=0x'
        '${canvasId.toRadixString(16)}',
      );
      return null;
    }

    // Look up by exact (canvasId, scope=mesh, channelIndex). The repo
    // unique-key already enforces this triple.
    final existing = await _repository.listCanvases(scope: CanvasScope.mesh);
    for (final row in existing) {
      if (row.canvasId == canvasId && row.channelIndex == channelIndex) {
        return row;
      }
    }

    // Auto-create with a safe fallback name. Prefer the channel's
    // configured name when the host provides one; otherwise fall back
    // to "Canvas <channelIndex>".
    final fallbackName = _channelNameForFallback?.call(channelIndex);
    final created = await _repository.getOrCreateMeshCanvas(
      canvasId: canvasId,
      channelIndex: channelIndex,
      name: (fallbackName != null && fallbackName.isNotEmpty)
          ? fallbackName
          : 'Canvas $channelIndex',
      ownerNodeNum: ownerNodeNum,
    );
    AppLogging.meshCanvas(
      'auto-created mesh canvas localId=${created.localId} '
      'canvas_id=0x${canvasId.toRadixString(16)} channel=$channelIndex '
      'from inbound op',
    );
    return created;
  }

  // ---------------------------------------------------------------------------
  // Replay window
  // ---------------------------------------------------------------------------

  bool _passesReplayWindow(int opTs) {
    final nowSec = _nowMs() ~/ 1000;
    final oldestAcceptableSec = nowSec - kCanvasReplayOldThreshold.inSeconds;
    final newestAcceptableSec = nowSec + kCanvasReplayFutureThreshold.inSeconds;
    return opTs >= oldestAcceptableSec && opTs <= newestAcceptableSec;
  }

  // ---------------------------------------------------------------------------
  // MRRP response framing
  // ---------------------------------------------------------------------------

  MrrpFrame _emptyOkResponse(MrrpFrame request) {
    return MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.response,
      flags: MrrpFlags.isResponse,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: request.serviceId,
      actionId: request.actionId,
      payloadLen: 0,
      payload: Uint8List(0),
    );
  }
}
