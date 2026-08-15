// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Riverpod providers + manager for the local-only Trust + Safety
/// layer.
///
/// [PeerSafetyManager] owns:
/// - In-memory caches (`Set<int>`) for the hot-path queries
///   (`isBlocked`, `isMuted`, `hasFirstContact`). Backed by
///   [PeerSafetyStore] for durability; populated eagerly on first
///   build so frame-receive code can call `isBlocked` synchronously.
/// - A serialised write queue (mirrors `OverlayLinkStore` pattern)
///   so concurrent Block / Mute / Unblock / state-change taps can't
///   race the DB or the cache.
///
/// HARD RULES:
/// - Caches and DB are local-only. They never enter any wire frame
///   or backend payload.
/// - The hot-path getters (`isBlocked` etc.) MUST stay sync — they
///   run on every inbound SIP frame and every outbound DM call.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';
import '../services/protocol/sip/peer_rate_limiter.dart';
import '../services/protocol/sip/peer_safety_gate.dart';
import '../services/storage/peer_safety_store.dart';
import 'radio_scope_providers.dart';

/// Snapshot of the manager's hot-path caches.
class PeerSafetyManagerState {
  final Set<int> blockedNodeIds;
  final Set<int> mutedNodeIds;
  final Set<int> firstContactSeenNodeIds;

  const PeerSafetyManagerState({
    required this.blockedNodeIds,
    required this.mutedNodeIds,
    required this.firstContactSeenNodeIds,
  });

  static const empty = PeerSafetyManagerState(
    blockedNodeIds: <int>{},
    mutedNodeIds: <int>{},
    firstContactSeenNodeIds: <int>{},
  );

  PeerSafetyManagerState copyWith({
    Set<int>? blockedNodeIds,
    Set<int>? mutedNodeIds,
    Set<int>? firstContactSeenNodeIds,
  }) {
    return PeerSafetyManagerState(
      blockedNodeIds: blockedNodeIds ?? this.blockedNodeIds,
      mutedNodeIds: mutedNodeIds ?? this.mutedNodeIds,
      firstContactSeenNodeIds:
          firstContactSeenNodeIds ?? this.firstContactSeenNodeIds,
    );
  }
}

/// Lazily-opened persistence layer. Every consumer of the safety
/// store goes through this provider so the lifecycle is centralised.
final peerSafetyStoreProvider = FutureProvider<PeerSafetyStore>((ref) async {
  ref.watch(radioScopeProvider);
  final store = PeerSafetyStore();
  await store.init();
  bindStoreToRadioScope(ref, store, store.close);
  return store;
});

/// Riverpod 3.x AsyncNotifier exposing the hot-path caches as state
/// and the mutation surface as methods.
class PeerSafetyManager extends AsyncNotifier<PeerSafetyManagerState> {
  PeerSafetyStore? _store;

  /// Serialises mutating writes so two concurrent `block(x)` calls
  /// can't interleave between DB upsert and cache update.
  Future<void> _writeChain = Future<void>.value();

  /// Optional clock injection for deterministic tests. Returns
  /// wall-clock ms when unset.
  int Function() _clock = () => DateTime.now().millisecondsSinceEpoch;

  /// Override the clock used for `*_at_ms` / `last_state_change_ms`
  /// stamps. Tests only.
  void debugSetClock(int Function() clock) {
    _clock = clock;
  }

  @override
  Future<PeerSafetyManagerState> build() async {
    _store = await ref.watch(peerSafetyStoreProvider.future);
    final blocked = await _store!.getBlockedPeerNodeIds();
    final muted = await _store!.getMutedPeerNodeIds();
    final accepted = await _store!.getHandshakenPeerNodeIds();
    return PeerSafetyManagerState(
      blockedNodeIds: blocked.toSet(),
      mutedNodeIds: muted.toSet(),
      firstContactSeenNodeIds: accepted.toSet(),
    );
  }

  // ---------------------------------------------------------------
  // Hot-path sync queries
  //
  // These run on every inbound SIP frame and every outbound DM call.
  // Reading from `state.value` is O(1); during the brief
  // initial-load window (before `build()` resolves) the caches are
  // empty and these all return false / null — i.e. "treat as not
  // blocked", which is the safe default.
  // ---------------------------------------------------------------

  bool isBlocked(int peerNodeId) {
    final s = state.value;
    if (s == null) return false;
    return s.blockedNodeIds.contains(peerNodeId);
  }

  bool isMuted(int peerNodeId) {
    final s = state.value;
    if (s == null) return false;
    return s.mutedNodeIds.contains(peerNodeId);
  }

  bool hasFirstContact(int peerNodeId) {
    final s = state.value;
    if (s == null) return false;
    return s.firstContactSeenNodeIds.contains(peerNodeId);
  }

  // ---------------------------------------------------------------
  // Async mutations (serialised)
  // ---------------------------------------------------------------

  /// Mark [peerNodeId] as blocked. Idempotent. Optionally records a
  /// short [reasonCode] (local-only).
  Future<void> block(int peerNodeId, {String? reasonCode}) {
    return _enqueue(() async {
      final store = _requireStore();
      final now = _clock();
      final existing = await store.getByPeerNodeId(peerNodeId);
      final updated = (existing ?? _seed(peerNodeId)).copyWith(
        state: NodeSafetyState.blocked,
        blockedAtMs: now,
        reasonCode: reasonCode ?? existing?.reasonCode,
        lastStateChangeMs: now,
      );
      await store.upsert(updated);
      _bumpState(
        (s) => s.copyWith(
          blockedNodeIds: {...s.blockedNodeIds, peerNodeId},
          // Block trumps mute — a blocked peer is definitionally
          // "no notifications + no content surface", so leave the
          // mute set untouched but block masks it everywhere.
        ),
      );
      AppLogging.sip(
        'SIP_SAFETY: node blocked id=0x${peerNodeId.toRadixString(16)} '
        'reason=${reasonCode ?? "unspecified"}',
      );
    });
  }

  /// Remove the block on [peerNodeId]. If the row only existed to
  /// hold the block state, it's deleted; if it was carrying other
  /// state (e.g. firstHandshakeMs), the row is preserved with
  /// `state = neutral`.
  Future<void> unblock(int peerNodeId) {
    return _enqueue(() async {
      final store = _requireStore();
      final existing = await store.getByPeerNodeId(peerNodeId);
      if (existing == null) return;
      if (existing.firstHandshakeMs == null &&
          existing.notes == null &&
          existing.reasonCode == null) {
        await store.delete(peerNodeId);
      } else {
        await store.upsert(
          existing.copyWith(
            state: NodeSafetyState.neutral,
            clearBlockedAtMs: true,
            lastStateChangeMs: _clock(),
          ),
        );
      }
      _bumpState(
        (s) => s.copyWith(
          blockedNodeIds: {...s.blockedNodeIds}..remove(peerNodeId),
        ),
      );
      AppLogging.sip(
        'SIP_SAFETY: node unblocked id=0x${peerNodeId.toRadixString(16)}',
      );
    });
  }

  /// Mark [peerNodeId] as muted (notifications-only suppression).
  /// Idempotent.
  Future<void> mute(int peerNodeId) {
    return _enqueue(() async {
      final store = _requireStore();
      final now = _clock();
      final existing = await store.getByPeerNodeId(peerNodeId);
      // Don't downgrade a blocked peer to muted by accident.
      if (existing?.state == NodeSafetyState.blocked) return;
      final updated = (existing ?? _seed(peerNodeId)).copyWith(
        state: NodeSafetyState.muted,
        mutedAtMs: now,
        lastStateChangeMs: now,
      );
      await store.upsert(updated);
      _bumpState(
        (s) => s.copyWith(mutedNodeIds: {...s.mutedNodeIds, peerNodeId}),
      );
      AppLogging.sip(
        'SIP_SAFETY: node muted id=0x${peerNodeId.toRadixString(16)}',
      );
    });
  }

  /// Remove the mute on [peerNodeId].
  Future<void> unmute(int peerNodeId) {
    return _enqueue(() async {
      final store = _requireStore();
      final existing = await store.getByPeerNodeId(peerNodeId);
      if (existing == null) return;
      if (existing.state != NodeSafetyState.muted) return;
      await store.upsert(
        existing.copyWith(
          state: NodeSafetyState.neutral,
          clearMutedAtMs: true,
          lastStateChangeMs: _clock(),
        ),
      );
      _bumpState(
        (s) =>
            s.copyWith(mutedNodeIds: {...s.mutedNodeIds}..remove(peerNodeId)),
      );
      AppLogging.sip(
        'SIP_SAFETY: node unmuted id=0x${peerNodeId.toRadixString(16)}',
      );
    });
  }

  /// Mark [peerNodeId] as having completed at least one handshake
  /// Accept. Used to gate the first-contact warning UX. Idempotent —
  /// only the FIRST timestamp is preserved so the marker reads
  /// "user has consented to private comms before".
  Future<void> markFirstHandshake(int peerNodeId, int timestampMs) {
    return _enqueue(() async {
      final store = _requireStore();
      final existing = await store.getByPeerNodeId(peerNodeId);
      if (existing?.firstHandshakeMs != null) return;
      final updated = (existing ?? _seed(peerNodeId)).copyWith(
        firstHandshakeMs: timestampMs,
        lastStateChangeMs: timestampMs,
      );
      await store.upsert(updated);
      _bumpState(
        (s) => s.copyWith(
          firstContactSeenNodeIds: {...s.firstContactSeenNodeIds, peerNodeId},
        ),
      );
    });
  }

  /// Direct safety-state setter for `trusted` / `unsafe`-style
  /// transitions. The state-specific helpers (`block`, `mute`, etc.)
  /// are preferred where they apply.
  Future<void> setSafetyState(
    int peerNodeId,
    NodeSafetyState state, {
    String? reasonCode,
  }) {
    return _enqueue(() async {
      final store = _requireStore();
      final now = _clock();
      final existing = await store.getByPeerNodeId(peerNodeId);
      final updated = (existing ?? _seed(peerNodeId)).copyWith(
        state: state,
        reasonCode: reasonCode ?? existing?.reasonCode,
        blockedAtMs: state == NodeSafetyState.blocked ? now : null,
        clearBlockedAtMs:
            state != NodeSafetyState.blocked, // explicit clear on transition
        mutedAtMs: state == NodeSafetyState.muted ? now : null,
        clearMutedAtMs: state != NodeSafetyState.muted,
        lastStateChangeMs: now,
      );
      await store.upsert(updated);

      _bumpState((s) {
        var blocked = {...s.blockedNodeIds};
        var muted = {...s.mutedNodeIds};
        if (state == NodeSafetyState.blocked) {
          blocked.add(peerNodeId);
          muted.remove(peerNodeId);
        } else {
          blocked.remove(peerNodeId);
        }
        if (state == NodeSafetyState.muted) {
          muted.add(peerNodeId);
        } else if (state != NodeSafetyState.blocked) {
          muted.remove(peerNodeId);
        }
        return s.copyWith(blockedNodeIds: blocked, mutedNodeIds: muted);
      });
    });
  }

  // ---------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------

  /// Append a write to the serialised mutation chain. Concurrent
  /// callers see their work executed in submission order.
  Future<void> _enqueue(Future<void> Function() task) {
    final next = _writeChain.then((_) async {
      try {
        await task();
      } catch (e, st) {
        AppLogging.sip('SIP_SAFETY: write failed $e\n$st');
        rethrow;
      }
    });
    _writeChain = next.catchError((_) {});
    return next;
  }

  void _bumpState(
    PeerSafetyManagerState Function(PeerSafetyManagerState) mutator,
  ) {
    final current = state.value ?? PeerSafetyManagerState.empty;
    state = AsyncData(mutator(current));
  }

  PeerSafetyRecord _seed(int peerNodeId) {
    return PeerSafetyRecord(
      peerNodeId: peerNodeId,
      state: NodeSafetyState.neutral,
      lastStateChangeMs: _clock(),
    );
  }

  PeerSafetyStore _requireStore() {
    final s = _store;
    if (s == null) {
      throw StateError(
        'PeerSafetyManager mutated before initial build() completed',
      );
    }
    return s;
  }
}

/// Public Riverpod entry. Hot-path callers use
/// `ref.read(peerSafetyManagerProvider.notifier).isBlocked(id)`.
final peerSafetyManagerProvider =
    AsyncNotifierProvider<PeerSafetyManager, PeerSafetyManagerState>(
      PeerSafetyManager.new,
    );

/// Adapter that satisfies the [PeerSafetyGate] protocol-layer
/// interface by delegating to the live [PeerSafetyManager] each call.
///
/// Used by `protocolServiceProvider`, `sipDmManagerProvider`, and
/// other Ref-less protocol-layer consumers. Reads are sync and
/// default-safe (return `false` while the manager is still loading).
class PeerSafetyManagerGateAdapter implements PeerSafetyGate {
  final PeerSafetyManager Function() _readNotifier;

  const PeerSafetyManagerGateAdapter(this._readNotifier);

  @override
  bool isBlocked(int peerNodeId) {
    try {
      return _readNotifier().isBlocked(peerNodeId);
    } catch (_) {
      // Provider container disposed mid-call (e.g. test teardown)
      // — fall back to the default-safe answer rather than crashing
      // the hot path.
      return false;
    }
  }

  @override
  bool isMuted(int peerNodeId) {
    try {
      return _readNotifier().isMuted(peerNodeId);
    } catch (_) {
      return false;
    }
  }
}

/// Sync gate consumed by Ref-less protocol-layer code. Always
/// available — falls back to a no-op when the manager hasn't loaded
/// yet (cold start, tests).
final peerSafetyGateProvider = Provider<PeerSafetyGate>((ref) {
  return PeerSafetyManagerGateAdapter(
    () => ref.read(peerSafetyManagerProvider.notifier),
  );
});

/// Long-lived per-peer × per-kind token-bucket limiter. Process-wide
/// singleton (state is in-memory only and intentionally outlives any
/// one DM session). Read by `SipDmRouter` between the safety gate
/// and the global airtime limiter.
final peerRateLimiterProvider = Provider<PeerRateLimiter>((ref) {
  return PeerRateLimiter();
});

/// Stable, sorted list of currently-blocked peer node IDs.
///
/// Watches [peerSafetyManagerProvider] so the SIP Hub Blocked section
/// rebuilds the moment Block / Unblock fires anywhere in the app.
/// Returns `const <int>[]` while the manager is still loading (cold
/// start) — the SIP Hub then renders no Blocked section, which is the
/// safer default.
///
/// **Render-layer use only.** Filtering active lists against this set
/// or rendering the Blocked section MUST NOT mutate any protocol or
/// session state — list rendering is a pure read.
final blockedPeerNodeIdsProvider = Provider<List<int>>((ref) {
  final state = ref.watch(peerSafetyManagerProvider);
  final blocked = state.value?.blockedNodeIds ?? const <int>{};
  // Sort numerically so the Blocked section's row order is stable
  // across rebuilds — without this, a Set→List conversion would
  // produce hash-order which jumps around when peers are added.
  final sorted = blocked.toList()..sort();
  return sorted;
});

// ---------------------------------------------------------------------------
// First-contact banner dismissals (UI-only, persistent)
// ---------------------------------------------------------------------------

/// SharedPreferences key for the persisted set of peer node IDs whose
/// first-contact banner the user has dismissed.
const String _kFirstContactBannerDismissedPrefsKey =
    'sip_dm_first_contact_banner_dismissed_v1';

/// Local-only UI state: which peers' first-contact banners the user
/// has explicitly dismissed.
///
/// IMPORTANT: This is purely a UI affordance — dismissing the banner
/// does NOT mutate any protocol state, does NOT call
/// `markFirstHandshake`, does NOT downgrade any safety state. It only
/// hides the banner for that specific peer next time the DM screen
/// opens.
///
/// Persisted to SharedPreferences as a JSON-style list of stringified
/// node IDs (decimal). Loaded eagerly so the sync `isDismissed`
/// getter is safe to call from `build()`.
class FirstContactBannerDismissals extends AsyncNotifier<Set<int>> {
  @override
  Future<Set<int>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getStringList(_kFirstContactBannerDismissedPrefsKey) ??
        const <String>[];
    final out = <int>{};
    for (final s in raw) {
      final n = int.tryParse(s);
      if (n != null) out.add(n);
    }
    return out;
  }

  /// Sync hot-path query. Returns false until the prefs load
  /// completes — the banner stays visible during the brief async gap,
  /// which is the safer default.
  bool isDismissed(int peerNodeId) {
    final s = state.value;
    if (s == null) return false;
    return s.contains(peerNodeId);
  }

  /// Persist a dismissal. Idempotent — re-tapping after dismiss is a
  /// no-op. Local-only; never enters any wire frame.
  Future<void> dismiss(int peerNodeId) async {
    final current = state.value ?? <int>{};
    if (current.contains(peerNodeId)) return;
    final next = {...current, peerNodeId};
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kFirstContactBannerDismissedPrefsKey,
      next.map((id) => id.toString()).toList(),
    );
    AppLogging.sip(
      'PEER_SAFETY: first-contact banner dismissed for '
      'peer=0x${peerNodeId.toRadixString(16)}',
    );
  }

  /// Clear a dismissal. Used by tests; not exposed in UI.
  Future<void> reset(int peerNodeId) async {
    final current = state.value ?? <int>{};
    if (!current.contains(peerNodeId)) return;
    final next = {...current}..remove(peerNodeId);
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kFirstContactBannerDismissedPrefsKey,
      next.map((id) => id.toString()).toList(),
    );
  }
}

final firstContactBannerDismissalsProvider =
    AsyncNotifierProvider<FirstContactBannerDismissals, Set<int>>(
      FirstContactBannerDismissals.new,
    );
