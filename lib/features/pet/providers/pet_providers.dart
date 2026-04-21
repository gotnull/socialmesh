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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../../../providers/app_lifecycle_provider.dart';
import '../../../providers/app_providers.dart' show myNodeNumProvider;
import '../models/pet_config.dart';
import '../models/pet_enums.dart';
import '../models/pet_public_state.dart';
import '../models/pet_state.dart';
import '../services/pet_care_engine.dart';
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

  Future<void> charge() => _apply(CareAction.charge);
  Future<void> surge() => _apply(CareAction.surge);
  Future<void> resonate() => _apply(CareAction.resonate);
  Future<void> stabilise() => _apply(CareAction.stabilise);
  Future<void> sync() => _apply(CareAction.sync);
  Future<void> purge() => _apply(CareAction.purge);
  Future<void> dim() => _apply(CareAction.dim);
  Future<void> inspect() => _apply(CareAction.inspect);

  /// Replace a dormant pet with a fresh egg. Also available while the pet
  /// is dormant — the UI guards other cases.
  Future<void> reSigil() async {
    final current = state.value;
    if (current == null) return;
    if (current.stage != PetStage.dormant) {
      AppLogging.pet(
        'OwnPetController: reSigil refused — stage=${current.stage.name}',
      );
      return;
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
  }

  Future<void> _apply(CareAction action) async {
    final current = state.value;
    if (current == null) return;
    final engine = ref.read(petCareEngineProvider);
    final next = engine.applyAction(current, action, DateTime.now());
    if (identical(next, current)) return;
    await _persist(next);
    state = AsyncValue.data(next);
    AppLogging.pet(
      'OwnPetController: ${action.name} -> energy=${next.energy} '
      'mood=${next.mood} stability=${next.stability} '
      'stage=${next.stage.name}',
    );
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
