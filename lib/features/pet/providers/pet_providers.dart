// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pet providers — owner-side state and actions.
//
// The ownPetProvider is an AsyncNotifier that:
//   1. Reads myNodeNumProvider to discover the current device's node id.
//   2. Loads persisted state from pet.db on build, or hatches a fresh egg
//      keyed to the ownerNodeNum.
//   3. Catches up state via PetCareEngine on first load and on every app
//      foreground resume (no background timers).
//   4. Exposes action methods (charge/surge/resonate/.../reSigil) that
//      advance state, apply the action, persist, and refresh.
//   5. Drives a foreground animation ticker that refreshes the UI without
//      advancing stats beyond what the care engine does on its own cadence.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../../../providers/app_lifecycle_provider.dart';
import '../../../providers/app_providers.dart'
    show myNodeNumProvider, peerLastSeenProvider;
import '../../../providers/mrrp_providers.dart';
import '../models/peer_pet_live_state.dart';
import '../models/pet_action_result.dart';
import '../models/pet_config.dart';
import '../models/pet_enums.dart';
import '../models/pet_public_state.dart';
import '../models/pet_state.dart';
import '../services/peer_pet_live_state_mapper.dart';
import '../services/pet_animation_tracker.dart';
import '../services/pet_care_engine.dart';
import '../services/pet_notification_dispatcher.dart';
import '../services/pet_remote_client.dart';
import '../services/pet_repository.dart';
import '../storage/pet_database.dart';

/// Binary gate for all pet UI entry points.
final petFeatureGateProvider = Provider<bool>((ref) {
  return AppFeatureFlags.isPetEnabled;
});

/// Tuning profile for the care engine. Swap via override for tests and
/// dogfood builds.
final petConfigProvider = Provider<PetConfig>((ref) {
  return const PetConfig();
});

/// The pure care engine, derived from [petConfigProvider].
final petCareEngineProvider = Provider<PetCareEngine>((ref) {
  return PetCareEngine(config: ref.watch(petConfigProvider));
});

/// The SQLite-backed repository. Held alive for the app's lifetime.
final petRepositoryProvider = Provider<PetRepository>((ref) {
  final db = PetDatabase();
  final repo = PetRepository(db);
  ref.onDispose(() => repo.close());
  return repo;
});

/// Owner-side pet state. `null` when no device has ever paired (no node
/// identity yet) — consumers should treat this as the pre-feature empty
/// state rather than an error.
class OwnPetController extends AsyncNotifier<PetState?> {
  Timer? _animationTicker;

  @override
  Future<PetState?> build() async {
    ref.onDispose(() {
      _animationTicker?.cancel();
      _animationTicker = null;
    });

    // Rebuild the controller whenever the paired node identity changes.
    final ownerNodeNum = ref.watch(myNodeNumProvider);

    // React to foreground/background transitions with a catch-up advance.
    ref.listen<bool>(appLifecycleProvider, (previous, isForeground) {
      if (isForeground && previous == false) {
        _onResume();
      }
      if (isForeground) {
        _startAnimationTicker();
      } else {
        _stopAnimationTicker();
      }
    });
    _startAnimationTicker();

    if (ownerNodeNum == null) {
      AppLogging.pet(
        'OwnPetController: no paired ownerNodeNum yet — empty state',
      );
      return null;
    }

    final repo = ref.read(petRepositoryProvider);
    await repo.init();

    final existing = await repo.loadOwnPet(ownerNodeNum);
    if (existing != null) {
      final caughtUp = ref
          .read(petCareEngineProvider)
          .advanceTo(existing, DateTime.now());
      if (!identical(caughtUp, existing)) {
        await repo.saveOwnPet(caughtUp);
      }
      AppLogging.pet(
        'OwnPetController: loaded pet stage=${caughtUp.stage.name} '
        'branch=${caughtUp.branch.name}',
      );
      return caughtUp;
    }

    final fresh = PetState.egg(
      ownerNodeNum: ownerNodeNum,
      hatchedAt: DateTime.now(),
    );
    await repo.saveOwnPet(fresh);
    AppLogging.pet(
      'OwnPetController: hatched fresh egg for node=$ownerNodeNum '
      'seed=0x${fresh.dnaSeed.toRadixString(16)}',
    );
    return fresh;
  }

  Future<void> _onResume() async {
    final current = state.value;
    if (current == null) return;
    final engine = ref.read(petCareEngineProvider);
    final next = engine.advanceTo(current, DateTime.now());
    if (identical(next, current)) return;
    await _persist(next);
    state = AsyncValue.data(next);
    AppLogging.pet('OwnPetController: catch-up advance on resume');
  }

  void _startAnimationTicker() {
    if (_animationTicker != null && _animationTicker!.isActive) return;
    final period = ref.read(petConfigProvider).foregroundAnimationTick;
    _animationTicker = Timer.periodic(period, (_) => _animationTick());
  }

  void _stopAnimationTicker() {
    _animationTicker?.cancel();
    _animationTicker = null;
  }

  /// Foreground refresh: advance to now and re-emit. The care engine is
  /// idempotent for sub-tick advances, so this is a cheap UI refresh that
  /// also lets short wait times feel live without ever touching the DB.
  Future<void> _animationTick() async {
    final current = state.value;
    if (current == null) return;
    final engine = ref.read(petCareEngineProvider);
    final next = engine.advanceTo(current, DateTime.now());
    if (identical(next, current)) return;
    state = AsyncValue.data(next);
    // Persist only when something meaningful changed beyond lastTickAt.
    if (next.stage != current.stage ||
        next.branch != current.branch ||
        next.isSick != current.isSick ||
        next.isAsleep != current.isAsleep ||
        next.energy != current.energy ||
        next.mood != current.mood ||
        next.stability != current.stability ||
        next.activeCall != current.activeCall ||
        next.hygieneArtefacts.length != current.hygieneArtefacts.length) {
      await _persist(next);
    }
  }

  // ---- Public action API -----------------------------------------------
  //
  // Every action method returns a structured PetActionResult so the UI
  // can respond to capped / not-needed / invalid outcomes with the
  // appropriate feedback (toast + no-op creature bounce) even when the
  // state didn't change. Persistence runs only when the outcome is
  // `applied` AND the returned state differs from the current one.

  Future<PetActionResult> charge() => _apply(CareAction.charge);
  Future<PetActionResult> surge() => _apply(CareAction.surge);
  Future<PetActionResult> resonate() => _apply(CareAction.resonate);
  Future<PetActionResult> stabilise() => _apply(CareAction.stabilise);
  Future<PetActionResult> sync() => _apply(CareAction.sync);
  Future<PetActionResult> purge() => _apply(CareAction.purge);
  Future<PetActionResult> dim() => _apply(CareAction.dim);
  Future<PetActionResult> inspect() => _apply(CareAction.inspect);

  /// Replace a dormant pet with a fresh egg. Returns invalidInState
  /// when the pet isn't dormant — the UI gates the button, but the
  /// engine still refuses safely.
  Future<PetActionResult> reSigil() async {
    final current = state.value;
    if (current == null) {
      // Unreachable in practice — the button only mounts when a pet
      // exists. Refuse safely with a throwaway placeholder state.
      return PetActionResult.invalidInState(
        state: _placeholderState(),
        action: CareAction.reSigil,
        reason: PetActionReason.notDormant,
      );
    }
    if (current.stage != PetStage.dormant) {
      AppLogging.pet(
        'OwnPetController: reSigil refused — stage=${current.stage.name}',
      );
      return PetActionResult.invalidInState(
        state: current,
        action: CareAction.reSigil,
        reason: PetActionReason.notDormant,
      );
    }
    final fresh = PetState.egg(
      ownerNodeNum: current.ownerNodeNum,
      hatchedAt: DateTime.now(),
    );
    await _persist(fresh);
    state = AsyncValue.data(fresh);
    AppLogging.pet(
      'OwnPetController: re-sigilled to seed=0x${fresh.dnaSeed.toRadixString(16)}',
    );
    return PetActionResult.applied(state: fresh, action: CareAction.reSigil);
  }

  Future<PetActionResult> _apply(CareAction action) async {
    final current = state.value;
    if (current == null) {
      // Unreachable in practice — the action bar only mounts when a pet
      // exists. Refuse safely with a throwaway placeholder state.
      return PetActionResult.invalidInState(
        state: _placeholderState(),
        action: action,
        reason: PetActionReason.dormant,
      );
    }
    final engine = ref.read(petCareEngineProvider);
    final result = engine.applyAction(current, action, DateTime.now());
    if (result.isApplied && !identical(result.state, current)) {
      await _persist(result.state);
      state = AsyncValue.data(result.state);
    }
    AppLogging.pet(
      'OwnPetController: ${action.name} -> ${result.outcome.name}'
      '${result.reason != null ? " (${result.reason!.name})" : ""} '
      'energy=${result.state.energy} mood=${result.state.mood} '
      'stability=${result.state.stability} stage=${result.state.stage.name}',
    );
    return result;
  }

  /// Throwaway PetState used only as a carrier for invalid-state
  /// results when no owner is bound. Never persisted.
  PetState _placeholderState() {
    return PetState.egg(ownerNodeNum: 0, hatchedAt: DateTime.now());
  }

  Future<void> _persist(PetState next) async {
    try {
      await ref.read(petRepositoryProvider).saveOwnPet(next);
    } catch (e, st) {
      AppLogging.pet('OwnPetController: persist failed: $e\n$st');
    }
  }
}

final ownPetProvider = AsyncNotifierProvider<OwnPetController, PetState?>(
  OwnPetController.new,
);

/// Compact mesh-visible summary derived from the owner state. Recomputes
/// only when the compact fields actually change — the .select keeps it
/// stable under UI-only animation ticks.
final petPublicStateProvider = Provider<PetPublicState?>((ref) {
  final async = ref.watch(ownPetProvider);
  final state = async.value;
  if (state == null) return null;

  final engine = ref.watch(petCareEngineProvider);
  final mood = engine.deriveMood(state);
  final ageDays = state.ageInDaysAt(DateTime.now()).clamp(0, 255);
  final isEvolving = state.stage == PetStage.egg;
  return PetPublicState(
    dnaSeed: state.dnaSeed,
    stage: state.stage,
    branch: state.branch,
    mood: mood,
    ageInDays: ageDays,
    isAsleep: state.isAsleep,
    isSick: state.isSick,
    isCalling: state.activeCall != null,
    isEvolving: isEvolving,
  );
});

/// Convenience: mood class for UI consumption without importing the engine.
final petMoodProvider = Provider<PetMood>((ref) {
  final async = ref.watch(ownPetProvider);
  final state = async.value;
  if (state == null) return PetMood.content;
  return ref.watch(petCareEngineProvider).deriveMood(state);
});

/// Cached remote observation of another node's pet. Reads from pet.db.
/// Ingestion (write-side) goes through [petIngestControllerProvider],
/// which invalidates the family entry after persisting.
final remotePetProvider = FutureProvider.family<RemotePetObservation?, int>((
  ref,
  nodeNum,
) async {
  final repo = ref.watch(petRepositoryProvider);
  await repo.init();
  return repo.loadRemotePet(nodeNum);
});

/// Recent peers we have pet-cache entries for, within the given TTL.
/// Used by NodeDex list widgets to decide when to show a preview.
final recentRemotePetsProvider =
    FutureProvider.family<List<RemotePetObservation>, Duration>((
      ref,
      maxAge,
    ) async {
      final repo = ref.watch(petRepositoryProvider);
      await repo.init();
      return repo.recentRemotePets(maxAge: maxAge);
    });

/// Write-side controller for the remote pet cache. Other layers (mesh
/// inbound hook, fetch-on-expand) call into this to persist new
/// observations; [remotePetProvider] is invalidated afterwards so any
/// watchers refresh from disk.
class PetIngestController {
  final Ref _ref;
  PetIngestController(this._ref);

  Future<void> ingestRemotePet(
    int nodeNum,
    PetPublicState observed, {
    DateTime? at,
  }) async {
    final observedAt = at ?? DateTime.now();
    final repo = _ref.read(petRepositoryProvider);
    await repo.init();
    await repo.saveRemotePet(
      nodeNum: nodeNum,
      state: observed,
      observedAt: observedAt,
    );
    _ref.invalidate(remotePetProvider(nodeNum));
    AppLogging.pet(
      'PetIngestController: ingested node=$nodeNum '
      'stage=${observed.stage.name} branch=${observed.branch.name}',
    );
  }

  Future<void> clearRemotePet(int nodeNum) async {
    final repo = _ref.read(petRepositoryProvider);
    await repo.clearRemotePet(nodeNum);
    _ref.invalidate(remotePetProvider(nodeNum));
  }
}

final petIngestControllerProvider = Provider<PetIngestController>((ref) {
  return PetIngestController(ref);
});

/// Client that broadcasts pet.v1/get_summary REQUESTs over the active
/// MRRP dispatcher. Returns null until MRRP + SIP are both enabled — see
/// [pet_remote_client.dart] for peer-targeting semantics.
final petRemoteClientProvider = Provider<PetRemoteClient?>((ref) {
  final dispatcher = ref.watch(mrrpDispatcherProvider);
  if (dispatcher == null) return null;
  return PetRemoteClient(dispatcher);
});

/// Durable watermark for one-shot hatch / evolution effects. Backed by
/// SharedPreferences so the hatch animation never replays on rebuild or
/// resume. `null` while shared prefs is still loading — consumers should
/// skip one-shots until the future resolves.
final petAnimationTrackerProvider = FutureProvider<PetAnimationTracker>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  return PetAnimationTracker(prefs);
});

/// Durable dedupe ledger for pet notifications. Keyed by ownerNodeNum so
/// each paired device starts clean. `null` while SharedPreferences is
/// still loading.
final petNotificationLedgerProvider = FutureProvider<PetNotificationLedger>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  return PetNotificationLedger(prefs);
});

/// SharedPreferences key for the one-time pet onboarding flow. Bumped
/// (v2, v3…) if the onboarding copy changes enough to warrant
/// re-showing it to existing users.
const _petOnboardingPrefKey = 'pet_onboarding_completed_v1';

/// True once the user has seen the pet onboarding. Starts as `null`
/// while SharedPreferences loads; consumers should treat `null` as
/// "don't show anything yet" to avoid a flash.
final petOnboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_petOnboardingPrefKey) ?? false;
});

/// Marks the onboarding as completed. Call this from the sheet's
/// "Got it" button handler. Invalidates the read-side provider so
/// the host screen sees the new value.
Future<void> markPetOnboardingCompleted(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_petOnboardingPrefKey, true);
  ref.invalidate(petOnboardingCompletedProvider);
}

/// The dispatcher that turns ownPetProvider state transitions into
/// at-most-one-per-event local notifications. Returns null until the
/// ledger future resolves.
final petNotificationDispatcherProvider = Provider<PetNotificationDispatcher?>((
  ref,
) {
  final ledgerAsync = ref.watch(petNotificationLedgerProvider);
  final ledger = ledgerAsync.asData?.value;
  if (ledger == null) return null;
  return PetNotificationDispatcher(
    ledger: ledger,
    sink: const DefaultPetNotificationSink(),
    // The dispatcher is only ever activated via the notification bridge,
    // which is only `ref.watch`ed from PetHomeScreen. If the bridge is
    // firing AT ALL, NodePet is mounted — but the user may have
    // backgrounded the app with it still mounted, in which case they
    // want the OS banner. Gate on the real lifecycle instead.
    isAppInForeground: () {
      final state = WidgetsBinding.instance.lifecycleState;
      return state == AppLifecycleState.resumed;
    },
  );
});

/// Bridge provider that watches [ownPetProvider] for state transitions
/// and forwards them to [petNotificationDispatcherProvider]. Owns no
/// state of its own — it exists so the notification pipeline is wired
/// exactly where the pet state machine lives, not from UI lifecycle.
///
/// Consumers of the notification feature (currently just the Pet home
/// screen) need to `ref.watch(petNotificationBridgeProvider)` once to
/// activate it. The bridge itself returns a constant.
final petNotificationBridgeProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<PetState?>>(ownPetProvider, (prev, next) {
    final nextState = next.value;
    if (nextState == null) return;
    final dispatcher = ref.read(petNotificationDispatcherProvider);
    if (dispatcher == null) return;
    // Fire-and-forget; the dispatcher logs outcomes.
    dispatcher.onStateTransition(
      previous: prev?.value,
      current: nextState,
      now: DateTime.now(),
    );
  });
});

// ---------------------------------------------------------------------------
// Peer pet live-state layer — smoothed display band derived from remote cache
// + peer presence freshness. No persistence; the Notifier rebuilds from its
// two inputs whenever either changes.
// ---------------------------------------------------------------------------

/// Injected mapper. Swap via override in tests to shorten the cooldown.
final peerPetLiveStateMapperProvider = Provider<PeerPetLiveStateMapper>((ref) {
  return const PeerPetLiveStateMapper();
});

/// Injectable clock — tests override to a fake.
final peerPetClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

/// Sync-derived view of the per-peer remote pet observation — the
/// AsyncValue unwrapped to `T?` so consumers don't have to branch on
/// loading/error every frame. Exists as a separate provider so tests
/// can override a plain value without wrestling with FutureProvider
/// override semantics, and so [PeerPetLiveStateController] can depend
/// on a pure synchronous input.
final peerPetObservationProvider = Provider.family<RemotePetObservation?, int>((
  ref,
  nodeNum,
) {
  return ref.watch(remotePetProvider(nodeNum)).value;
});

/// Smoothed live band for a peer, derived from:
///   * `remotePetProvider(nodeNum)` — decoded public state + observedAt
///   * `peerLastSeenProvider(nodeNum)` — presence freshness from nodes map
///
/// Asymmetric transition rules (see [PeerPetLiveStateMapper] docs):
/// upgrades and wire-authoritative low-energy entries are immediate;
/// downgrades, lateral-to-unknown, and sleepy/dormant exits go through
/// a 15s cooldown. Timers are strictly single-shot — scheduling a new
/// one always cancels the previous one, so rapid-fire signal updates
/// cannot accumulate pending transitions.
class PeerPetLiveStateController extends Notifier<PeerPetLiveState> {
  PeerPetLiveStateController(this.nodeNum);

  final int nodeNum;

  Timer? _cooldownTimer;
  PeerPetLiveBand? _pendingBand;
  DateTime? _pendingSince;

  /// The last value this Notifier returned from [build]. Tracks the
  /// "current band" across rebuilds triggered by `ref.watch` — the
  /// framework-visible `state` is refreshed only when we emit, so we
  /// also need a local cache of our own returned value to detect
  /// true band transitions (vs. meaningless rebuilds).
  PeerPetLiveState? _lastReturned;

  @override
  PeerPetLiveState build() {
    ref.onDispose(_cancelTimer);

    // ref.watch drives rebuilds whenever either input changes. The
    // Notifier instance is preserved, so `_cooldownTimer`, `_pendingBand`,
    // and `_pendingSince` all survive rebuilds. We read the observation
    // through [peerPetObservationProvider] (sync-derived) rather than
    // the FutureProvider directly — this removes an AsyncValue branch
    // per frame and makes the input cleanly overridable in tests.
    final observation = ref.watch(peerPetObservationProvider(nodeNum));
    final lastSeen = ref.watch(peerLastSeenProvider(nodeNum));

    final now = ref.read(peerPetClockProvider)();
    final mapper = ref.read(peerPetLiveStateMapperProvider);

    final signal = PeerPresenceSignal(
      sinceLastSeen: lastSeen == null ? null : now.difference(lastSeen),
      sinceObserved: observation == null
          ? null
          : now.difference(observation.observedAt),
      isAsleepOnWire: observation?.state.isAsleep ?? false,
      isDormantOnWire: observation?.state.stage == PetStage.dormant,
    );
    final raw = mapper.resolveRaw(signal);

    final prior = _lastReturned;
    final currentBand = prior?.band ?? PeerPetLiveBand.unknown;

    final decision = mapper.smooth(
      current: currentBand,
      incoming: raw,
      pendingBand: _pendingBand,
      pendingSince: _pendingSince,
      signal: signal,
      now: now,
    );

    final next = _applyDecision(decision, now, prior: prior);
    _lastReturned = next;
    return next;
  }

  /// Called when the cooldown timer fires. Runs outside of `build()`,
  /// so we drive state via direct assignment. If a newer input has
  /// arrived since scheduling, the rebuild path will already have
  /// handled it — we only commit when the pending band still matches
  /// what the latest signal says.
  void _onCooldownFire() {
    final now = ref.read(peerPetClockProvider)();
    final observation = ref.read(peerPetObservationProvider(nodeNum));
    final lastSeen = ref.read(peerLastSeenProvider(nodeNum));
    final mapper = ref.read(peerPetLiveStateMapperProvider);

    final signal = PeerPresenceSignal(
      sinceLastSeen: lastSeen == null ? null : now.difference(lastSeen),
      sinceObserved: observation == null
          ? null
          : now.difference(observation.observedAt),
      isAsleepOnWire: observation?.state.isAsleep ?? false,
      isDormantOnWire: observation?.state.stage == PetStage.dormant,
    );
    final raw = mapper.resolveRaw(signal);

    if (_pendingBand == null || raw != _pendingBand) {
      _pendingBand = null;
      _pendingSince = null;
      _cooldownTimer = null;
      return;
    }

    final decision = mapper.smooth(
      current: state.band,
      incoming: raw,
      pendingBand: _pendingBand,
      pendingSince: _pendingSince,
      signal: signal,
      now: now,
    );

    final next = _applyDecision(decision, now, prior: state);
    if (!identical(next, state)) {
      _lastReturned = next;
      state = next;
    }
  }

  /// Apply [decision] to pending/timer bookkeeping and return the
  /// Notifier's next state value. Returns [prior] unchanged (same
  /// reference) when the decision would not change the band — callers
  /// compare with `identical` to decide whether to emit.
  PeerPetLiveState _applyDecision(
    PeerPetSmoothingDecision decision,
    DateTime now, {
    required PeerPetLiveState? prior,
  }) {
    // Pending-band bookkeeping — only reset the clock when the band
    // actually changes; otherwise repeated builds with the same pending
    // band would reset the cooldown and it would never expire.
    if (decision.pendingBand == null) {
      _pendingBand = null;
      _pendingSince = null;
    } else if (_pendingBand != decision.pendingBand) {
      _pendingBand = decision.pendingBand;
      _pendingSince = now;
    }

    // Timer discipline: always cancel before scheduling.
    _cancelTimer();
    final fireAt = decision.fireAt;
    if (fireAt != null && decision.pendingBand != null) {
      final remaining = fireAt.difference(now);
      final delay = remaining.isNegative ? Duration.zero : remaining;
      _cooldownTimer = Timer(delay, _onCooldownFire);
    }

    final emit = decision.emit;
    if (emit == null) {
      // No change — preserve reference so Riverpod's equality check
      // suppresses the rebuild.
      return prior ?? PeerPetLiveState.initial(now);
    }
    if (prior != null && emit == prior.band) {
      // Band unchanged — same reference, no emission.
      return prior;
    }
    if (prior != null) {
      AppLogging.pet(
        'PeerPetLiveState: node=$nodeNum '
        '${prior.band.name} -> ${emit.name}',
      );
    }
    return PeerPetLiveState(band: emit, emittedAt: now);
  }

  void _cancelTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
  }
}

final peerPetLiveStateProvider =
    NotifierProvider.family<PeerPetLiveStateController, PeerPetLiveState, int>(
      PeerPetLiveStateController.new,
    );
