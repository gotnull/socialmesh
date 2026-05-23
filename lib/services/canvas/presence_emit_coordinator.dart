// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas presence outbound emitter (P3).
//
// Source of truth: docs/canvas/CANVAS_PRESENCE_V0_1.md §3 + §4.4.
//
// Responsibilities:
//   - Synchronously seed the local "self" entry in PresenceCache on
//     viewer mount (CANVAS_PRESENCE_V0_1.md §4.4 — local viewer
//     appears before any wire echo).
//   - Drive viewing / active / painting / leaving emits through the
//     shared canvas outbound pipeline (canvas governor, then SIP
//     limiter via CanvasOutboundChannel).
//   - Enforce throttling: 5 s duplicate-state suppression, 30 s per-
//     state ceiling for active and painting, 4 frames per 60 s hard
//     cap per canvas.
//   - Enforce anti-starvation gates before each wire emit:
//       1. pending paint queue for this canvas MUST be empty.
//       2. canvas governor headroom MUST be >= 96 bytes.
//       3. SIP limiter capacity is checked inside CanvasOutboundChannel;
//          a sipRateLimited outcome silently drops the frame.
//     Failure on any gate = silent drop. No queue, no retry.
//
// What this layer deliberately does NOT do (out of P3 scope):
//   - Inbound presence handler wiring (P4).
//   - Periodic timer ownership: the provider layer (post-P3) owns the
//     Timer.periodic that calls `tick`. The coordinator stays pure
//     and timer-free so tests can drive cadence deterministically.
//   - UI strip rendering or AppBottomSheet (P5).
//   - Sound, animation, motion (P5 + §7.6).
library;

import 'dart:typed_data';

import '../../core/logging.dart';
import 'canvas_codec.dart';
import 'canvas_constants.dart';
import 'canvas_outbound_governor.dart';
import 'canvas_send_coordinator.dart'
    show CanvasOutboundChannel, CanvasSendOutcome;
import 'presence_cache.dart';
import 'presence_models.dart';

/// Predicate returning whether a canvas has any pending paint ops
/// queued. Wired by the provider layer to a thin repo call; tests
/// pass a controllable stub.
typedef HasPendingPaintsPredicate = Future<bool> Function(int canvasLocalId);

/// Cadence and throttling constants. See CANVAS_PRESENCE_V0_1.md §3.1.
abstract final class PresenceEmitTiming {
  /// Heartbeat cadence: any-state re-emit at least every 90 seconds
  /// while a viewer remains attached. Heartbeats only re-emit
  /// `viewing`; active and painting are event-driven.
  static const int heartbeatPeriodMs = 90 * 1000;

  /// Duplicate-state suppression window. Same state value emitted
  /// twice within this many ms is the second attempt dropped.
  static const int duplicateSuppressMs = 5 * 1000;

  /// Per-state ceiling for `active` emits.
  static const int activeThrottleMs = 30 * 1000;

  /// Per-state ceiling for `painting` emits.
  static const int paintingThrottleMs = 30 * 1000;

  /// Hard ceiling: at most this many presence frames per minute per
  /// canvas, regardless of cadence or state.
  static const int hardCeilingPerWindow = 4;

  /// Sliding window for the hard ceiling.
  static const int hardCeilingWindowMs = 60 * 1000;

  /// Governor headroom reserved for paints. Presence may only send
  /// when canvas governor remainingBytes >= this many bytes.
  /// Equals 4x the presence wire byte count, intentionally
  /// (CANVAS_PRESENCE_V0_1.md §3.1).
  static const int governorHeadroomBytes = 96;

  /// Wire byte count of every presence frame (action 0x0007 is fixed
  /// at 24 bytes). Used by governor accounting.
  static const int presenceFrameBytes = 24;
}

class _ViewerSession {
  final int canvasLocalId;
  final int channelIndex;
  final int canvasId;
  final int localNodeNum;

  /// Last time we successfully emitted ANY frame for this session.
  /// Drives the 90 s heartbeat cadence.
  int? lastAnyEmitMs;

  /// State value of the last successful emit. Drives the 5 s
  /// duplicate-state suppression check.
  PresenceState? lastEmitState;

  /// Last successful active emit. Drives the 30 s throttle.
  int? lastActiveSuccessMs;

  /// Last successful painting emit. Drives the 30 s throttle.
  int? lastPaintingSuccessMs;

  /// True once any wire emit succeeded this session. Gates the
  /// `leaving` frame on detach (CANVAS_PRESENCE_V0_1.md §3.1).
  bool everEmittedSuccessfully = false;

  /// Successful-emit timestamps in the trailing 60 s. Capped by the
  /// hard ceiling; pruned on each emit attempt.
  final List<int> recentSuccessMs = <int>[];

  _ViewerSession({
    required this.canvasLocalId,
    required this.channelIndex,
    required this.canvasId,
    required this.localNodeNum,
  });
}

/// Outbound presence emitter. One instance per app process; the
/// provider layer (post-P3) holds the singleton and drives `tick`
/// from a `Timer.periodic`. The coordinator owns no timers itself.
class PresenceEmitCoordinator {
  final PresenceCache _cache;
  final CanvasOutboundGovernor _governor;
  final CanvasOutboundChannel _outbound;
  final int? Function() _localNodeNumProvider;
  final HasPendingPaintsPredicate _hasPendingPaints;
  final int Function() _nowMs;

  final Map<int, _ViewerSession> _sessions = <int, _ViewerSession>{};

  bool _disposed = false;

  PresenceEmitCoordinator({
    required PresenceCache cache,
    required CanvasOutboundGovernor governor,
    required CanvasOutboundChannel outbound,
    required int? Function() localNodeNumProvider,
    required HasPendingPaintsPredicate hasPendingPaints,
    int Function()? nowMs,
  }) : _cache = cache,
       _governor = governor,
       _outbound = outbound,
       _localNodeNumProvider = localNodeNumProvider,
       _hasPendingPaints = hasPendingPaints,
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Number of currently attached viewer sessions. Test introspection.
  int get debugSessionCount => _sessions.length;

  /// Whether a session for [canvasLocalId] is currently attached.
  /// Test introspection.
  bool debugHasSession(int canvasLocalId) =>
      _sessions.containsKey(canvasLocalId);

  // ---------------------------------------------------------------------------
  // Viewer lifecycle
  // ---------------------------------------------------------------------------

  /// Attach a viewer on a mesh canvas.
  ///
  /// Validates the canvas is broadcast-capable (mesh scope), then
  /// SYNCHRONOUSLY seeds the local "self" entry in the cache before
  /// returning (caller may observe the cache state before awaiting).
  /// The viewing wire emit is attempted asynchronously after the
  /// synchronous seed; the returned Future completes once that
  /// attempt resolves (whether or not it actually shipped).
  ///
  /// Re-attaching for the same [canvasLocalId] replaces any existing
  /// session and refreshes the cache entry.
  ///
  /// Hard pre-flight rejections (return without seeding or emitting):
  ///   - coordinator already disposed.
  ///   - local node num is unknown (link not up yet).
  ///   - [canvasId] == 0 (Local Device Canvas sentinel).
  ///   - [channelIndex] outside `[0, CanvasLimits.channelIndexMax]`.
  Future<void> attachViewer({
    required int canvasLocalId,
    required int channelIndex,
    required int canvasId,
  }) async {
    if (_disposed) return;
    final localNodeNum = _localNodeNumProvider();
    if (localNodeNum == null) {
      AppLogging.meshCanvas(
        'presence attachViewer skipped: local node num unknown '
        'canvas=$canvasLocalId',
      );
      return;
    }
    if (canvasId == kLocalCanvasIdSentinel) {
      AppLogging.meshCanvas(
        'presence attachViewer skipped: local canvas (canvas_id=0) '
        'never broadcasts',
      );
      return;
    }
    if (channelIndex < 0 || channelIndex > CanvasLimits.channelIndexMax) {
      AppLogging.meshCanvas(
        'presence attachViewer skipped: invalid channelIndex=$channelIndex',
      );
      return;
    }

    final nowMs = _nowMs();

    // Synchronous seed: cache reflects local viewer immediately.
    // Tests assert this before awaiting.
    _cache.upsert(
      nodeNum: localNodeNum,
      canvasLocalId: canvasLocalId,
      channelIndex: channelIndex,
      state: PresenceState.viewing,
      emitTsSec: nowMs ~/ 1000,
      ttlSeconds: CanvasPresenceLimits.ttlSecondsDefault,
      source: PresenceSource.self,
      nowMs: nowMs,
    );

    final session = _ViewerSession(
      canvasLocalId: canvasLocalId,
      channelIndex: channelIndex,
      canvasId: canvasId,
      localNodeNum: localNodeNum,
    );
    _sessions[canvasLocalId] = session;
    AppLogging.meshCanvas(
      'presence attach canvas=$canvasLocalId channel=$channelIndex '
      'canvas_id=0x${canvasId.toRadixString(16)} '
      'node=0x${localNodeNum.toRadixString(16)}',
    );

    await _attemptEmit(session, PresenceState.viewing, nowMs);
  }

  /// Record a viewer interaction (pan, zoom, palette tap, long-press).
  /// Attempts an `active` emit subject to throttling and anti-
  /// starvation. Returns true if the wire emit succeeded.
  Future<bool> notifyInteraction(int canvasLocalId) async {
    if (_disposed) return false;
    final session = _sessions[canvasLocalId];
    if (session == null) return false;
    final nowMs = _nowMs();
    // Refresh local self toward `active`. The cache rejects this
    // upsert if local self is already at painting (no-downgrade),
    // which is the desired behavior.
    _cache.upsert(
      nodeNum: session.localNodeNum,
      canvasLocalId: session.canvasLocalId,
      channelIndex: session.channelIndex,
      state: PresenceState.active,
      emitTsSec: nowMs ~/ 1000,
      ttlSeconds: CanvasPresenceLimits.ttlSecondsDefault,
      source: PresenceSource.self,
      nowMs: nowMs,
    );
    return _attemptEmit(session, PresenceState.active, nowMs);
  }

  /// Record that a paint op was accepted into the pending queue.
  /// Attempts a `painting` emit subject to throttling and anti-
  /// starvation. Returns true if the wire emit succeeded.
  Future<bool> notifyPaintEnqueued(int canvasLocalId) async {
    if (_disposed) return false;
    final session = _sessions[canvasLocalId];
    if (session == null) return false;
    final nowMs = _nowMs();
    _cache.upsert(
      nodeNum: session.localNodeNum,
      canvasLocalId: session.canvasLocalId,
      channelIndex: session.channelIndex,
      state: PresenceState.painting,
      emitTsSec: nowMs ~/ 1000,
      ttlSeconds: CanvasPresenceLimits.ttlSecondsDefault,
      source: PresenceSource.self,
      nowMs: nowMs,
    );
    return _attemptEmit(session, PresenceState.painting, nowMs);
  }

  /// Pull-driven heartbeat tick. The provider layer drives this from
  /// a `Timer.periodic`. Tests call it directly with controlled time.
  /// Returns the count of frames the wire accepted on this tick.
  ///
  /// Heartbeat state is read from live local cache: if self currently
  /// reads as painting (and unexpired) we re-emit painting; same for
  /// active; otherwise viewing. Throttles and gates still apply, so a
  /// painting heartbeat that would land inside the 30 s ceiling is
  /// silently dropped. The cache is NOT refreshed by heartbeat — TTL
  /// drives natural decay back toward viewing.
  Future<int> tick({int? nowMs}) async {
    if (_disposed) return 0;
    final now = nowMs ?? _nowMs();
    var sent = 0;
    // Snapshot keys because awaits inside the loop may mutate _sessions
    // via concurrent detachViewer calls.
    final keys = _sessions.keys.toList();
    for (final id in keys) {
      final session = _sessions[id];
      if (session == null) continue;
      final last = session.lastAnyEmitMs;
      final dueForHeartbeat =
          last == null || (now - last) >= PresenceEmitTiming.heartbeatPeriodMs;
      if (!dueForHeartbeat) continue;
      final state = _heartbeatStateFor(session, now);
      final ok = await _attemptEmit(session, state, now);
      if (ok) sent++;
    }
    return sent;
  }

  /// Pick the heartbeat state from live local self cache.
  /// `painting > active > viewing`. An absent or TTL-expired entry
  /// falls back to viewing.
  PresenceState _heartbeatStateFor(_ViewerSession session, int nowMs) {
    final entry = _cache.entryFor(
      canvasLocalId: session.canvasLocalId,
      channelIndex: session.channelIndex,
      nodeNum: session.localNodeNum,
    );
    if (entry == null || entry.isExpiredAt(nowMs)) {
      return PresenceState.viewing;
    }
    switch (entry.state) {
      case PresenceState.painting:
        return PresenceState.painting;
      case PresenceState.active:
        return PresenceState.active;
      case PresenceState.viewing:
      case PresenceState.leaving:
        return PresenceState.viewing;
    }
  }

  /// Detach a viewer. Synchronously removes the session and the
  /// local self cache entry. Asynchronously emits a `leaving` frame
  /// IFF at least one prior emit succeeded this session
  /// (CANVAS_PRESENCE_V0_1.md §3.1: "Once, only if a prior
  /// viewing/active/painting was emitted").
  Future<void> detachViewer(int canvasLocalId) async {
    if (_disposed) return;
    final session = _sessions.remove(canvasLocalId);
    if (session == null) return;
    _cache.evict(
      canvasLocalId: session.canvasLocalId,
      channelIndex: session.channelIndex,
      nodeNum: session.localNodeNum,
    );
    AppLogging.meshCanvas(
      'presence detach canvas=$canvasLocalId '
      'everEmitted=${session.everEmittedSuccessfully}',
    );
    if (!session.everEmittedSuccessfully) return;
    await _emitLeaving(session, _nowMs());
  }

  /// Tear everything down. Clears every session and self entry.
  /// Does NOT emit `leaving` for any session — full app dispose is
  /// not a graceful unmount.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final session in _sessions.values) {
      _cache.evict(
        canvasLocalId: session.canvasLocalId,
        channelIndex: session.channelIndex,
        nodeNum: session.localNodeNum,
      );
    }
    _sessions.clear();
    AppLogging.meshCanvas('presence coordinator disposed');
  }

  // ---------------------------------------------------------------------------
  // Internal emit pipeline
  // ---------------------------------------------------------------------------

  /// Attempt to emit a single presence frame for [session] in [state].
  /// Returns `true` IFF the wire accepted the frame. All gates are
  /// silent drops: no queueing, no retry.
  Future<bool> _attemptEmit(
    _ViewerSession session,
    PresenceState state,
    int nowMs,
  ) async {
    // 1. Duplicate-state suppression (5 s).
    final lastAny = session.lastAnyEmitMs;
    if (lastAny != null &&
        session.lastEmitState == state &&
        (nowMs - lastAny) < PresenceEmitTiming.duplicateSuppressMs) {
      AppLogging.meshCanvas(
        'presence suppress: duplicate ${state.name} '
        'canvas=${session.canvasLocalId} within '
        '${PresenceEmitTiming.duplicateSuppressMs}ms',
      );
      return false;
    }

    // 2. Per-state throttle for active / painting (30 s).
    switch (state) {
      case PresenceState.active:
        final last = session.lastActiveSuccessMs;
        if (last != null &&
            (nowMs - last) < PresenceEmitTiming.activeThrottleMs) {
          AppLogging.meshCanvas(
            'presence throttle: active within '
            '${PresenceEmitTiming.activeThrottleMs}ms '
            'canvas=${session.canvasLocalId}',
          );
          return false;
        }
      case PresenceState.painting:
        final last = session.lastPaintingSuccessMs;
        if (last != null &&
            (nowMs - last) < PresenceEmitTiming.paintingThrottleMs) {
          AppLogging.meshCanvas(
            'presence throttle: painting within '
            '${PresenceEmitTiming.paintingThrottleMs}ms '
            'canvas=${session.canvasLocalId}',
          );
          return false;
        }
      case PresenceState.viewing:
      case PresenceState.leaving:
        // No per-state throttle. Heartbeat cadence (90 s) and
        // duplicate suppression already cover viewing; leaving is
        // routed through _emitLeaving, not this path.
        break;
    }

    // 3. Hard ceiling 4 / 60 s. Prune timestamps that aged out.
    session.recentSuccessMs.removeWhere(
      (t) => (nowMs - t) >= PresenceEmitTiming.hardCeilingWindowMs,
    );
    if (session.recentSuccessMs.length >=
        PresenceEmitTiming.hardCeilingPerWindow) {
      AppLogging.meshCanvas(
        'presence ceiling: ${session.recentSuccessMs.length}/'
        '${PresenceEmitTiming.hardCeilingPerWindow} in 60s window '
        'canvas=${session.canvasLocalId}',
      );
      return false;
    }

    // 4. Anti-starvation: paint queue must be empty.
    final paintQueueHot = await _hasPendingPaints(session.canvasLocalId);
    if (paintQueueHot) {
      AppLogging.meshCanvas(
        'presence defer: paint queue not empty '
        'canvas=${session.canvasLocalId}',
      );
      return false;
    }

    // 5. Anti-starvation: governor headroom must reserve at least
    // 96 B for paints.
    if (_governor.remainingBytes < PresenceEmitTiming.governorHeadroomBytes) {
      AppLogging.meshCanvas(
        'presence defer: governor remaining='
        '${_governor.remainingBytes}B < '
        '${PresenceEmitTiming.governorHeadroomBytes}B headroom',
      );
      return false;
    }

    // 6. Encode + send.
    final encoded = _encode(session, state, nowMs);
    if (encoded == null) {
      // CanvasCodec.encodePresence only returns null on out-of-range
      // ttl, which this layer always sets to the default. A null here
      // is a programming bug.
      AppLogging.meshCanvas(
        'presence encode failed for ${state.name} '
        'canvas=${session.canvasLocalId}',
      );
      return false;
    }
    final result = await _outbound.sendCanvasPayload(
      canvasPayload: encoded,
      channelIndex: session.channelIndex,
    );
    if (result.outcome != CanvasSendOutcome.sent) {
      AppLogging.meshCanvas(
        'presence drop: outcome=${result.outcome.name} '
        'canvas=${session.canvasLocalId}',
      );
      return false;
    }

    // 7. Success: charge governor + update session timestamps.
    _governor.recordSend(PresenceEmitTiming.presenceFrameBytes);
    session.lastAnyEmitMs = nowMs;
    session.lastEmitState = state;
    session.recentSuccessMs.add(nowMs);
    session.everEmittedSuccessfully = true;
    if (state == PresenceState.active) {
      session.lastActiveSuccessMs = nowMs;
    } else if (state == PresenceState.painting) {
      session.lastPaintingSuccessMs = nowMs;
    }
    AppLogging.meshCanvas(
      'presence emit ${state.name} canvas=${session.canvasLocalId} '
      'channel=${session.channelIndex} wire=${result.wireBytes}B',
    );
    return true;
  }

  /// Best-effort `leaving` emit on detach. Applies the governor gate
  /// only (one-shot; skips throttling and paint-queue gate so we do
  /// not silently swallow the dispose signal).
  Future<void> _emitLeaving(_ViewerSession session, int nowMs) async {
    if (_governor.remainingBytes < PresenceEmitTiming.presenceFrameBytes) {
      AppLogging.meshCanvas(
        'presence leaving dropped: governor remaining='
        '${_governor.remainingBytes}B '
        'canvas=${session.canvasLocalId}',
      );
      return;
    }
    final encoded = _encode(session, PresenceState.leaving, nowMs);
    if (encoded == null) return;
    final result = await _outbound.sendCanvasPayload(
      canvasPayload: encoded,
      channelIndex: session.channelIndex,
    );
    if (result.outcome == CanvasSendOutcome.sent) {
      _governor.recordSend(PresenceEmitTiming.presenceFrameBytes);
      AppLogging.meshCanvas(
        'presence emit leaving canvas=${session.canvasLocalId} '
        'wire=${result.wireBytes}B',
      );
    } else {
      AppLogging.meshCanvas(
        'presence leaving dropped: outcome=${result.outcome.name} '
        'canvas=${session.canvasLocalId}',
      );
    }
  }

  Uint8List? _encode(_ViewerSession session, PresenceState state, int nowMs) {
    final op = CanvasPresenceOp(
      canvasId: session.canvasId,
      authorId: session.localNodeNum,
      state: state,
      emitTs: nowMs ~/ 1000,
      ttlSeconds: CanvasPresenceLimits.ttlSecondsDefault,
    );
    return CanvasCodec.encodePresence(op);
  }
}
