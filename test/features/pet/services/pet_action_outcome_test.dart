// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Exhaustive outcome matrix for every owner action × every state path
// the UI relies on. Protects the invariant that every tap resolves to
// exactly one of applied / capped / notNeeded / invalidInState, with the
// correct reason attached so the UI can show the right toast.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/attention_call.dart';
import 'package:socialmesh/features/pet/models/pet_action_result.dart';
import 'package:socialmesh/features/pet/models/pet_config.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/models/pet_state.dart';
import 'package:socialmesh/features/pet/services/pet_care_engine.dart';

const _ownerNodeNum = 0xABC12345;
final _hatch = DateTime(2026, 6, 1, 12);

const _config = PetConfig();
final _engine = PetCareEngine(config: _config);

/// Build a state at a specific stage with stats we can control exactly.
///
/// [now] pins `lastTickAt` so `applyAction`'s internal
/// `advanceTo(state, now)` is a no-op when tests call the engine at the
/// same instant. Otherwise care ticks between `lastTickAt` and `now`
/// would drift the very stats we're trying to assert against.
PetState _stateAt(
  PetStage stage, {
  int energy = 5,
  int mood = 5,
  int stability = 5,
  DateTime? now,
}) {
  final base = PetState.egg(ownerNodeNum: _ownerNodeNum, hatchedAt: _hatch);
  return base.copyWith(
    stage: stage,
    stageStartedAt: _hatch,
    lastTickAt: now ?? _hatch.add(const Duration(hours: 2)),
    energy: energy,
    mood: mood,
    stability: stability,
  );
}

void main() {
  final t = _hatch.add(const Duration(hours: 2));

  group('Charge outcomes', () {
    test('applied when energy < max and awake', () {
      final s = _stateAt(PetStage.juvenile, energy: 3);
      final r = _engine.applyAction(s, CareAction.charge, t);
      expect(r.outcome, PetActionOutcome.applied);
      expect(r.state.energy, greaterThan(3));
    });

    test('capped with fullyCharged reason when energy at max', () {
      final s = _stateAt(PetStage.juvenile, energy: _config.statMax);
      final r = _engine.applyAction(s, CareAction.charge, t);
      expect(r.outcome, PetActionOutcome.capped);
      expect(r.reason, PetActionReason.fullyCharged);
    });

    test(
      'applies (answering call) even at max energy if hungry call active',
      () {
        var s = _stateAt(PetStage.juvenile, energy: _config.statMax);
        s = s.copyWith(
          activeCall: AttentionCall(
            startedAt: t,
            deadline: t.add(const Duration(hours: 2)),
            reason: CallReason.hungry,
          ),
        );
        final r = _engine.applyAction(s, CareAction.charge, t);
        expect(r.outcome, PetActionOutcome.applied);
        expect(r.state.activeCall, isNull);
      },
    );

    test('invalidInState(asleep) when asleep', () {
      final s = _stateAt(PetStage.juvenile).copyWith(isAsleep: true);
      final r = _engine.applyAction(s, CareAction.charge, t);
      expect(r.outcome, PetActionOutcome.invalidInState);
      expect(r.reason, PetActionReason.asleep);
    });

    test('invalidInState(egg) during egg stage', () {
      final s = _stateAt(PetStage.egg);
      final r = _engine.applyAction(s, CareAction.charge, t);
      expect(r.outcome, PetActionOutcome.invalidInState);
      expect(r.reason, PetActionReason.egg);
    });

    test('invalidInState(dormant) when dormant', () {
      final s = _stateAt(PetStage.dormant);
      final r = _engine.applyAction(s, CareAction.charge, t);
      expect(r.outcome, PetActionOutcome.invalidInState);
      expect(r.reason, PetActionReason.dormant);
    });
  });

  group('Surge outcomes', () {
    test('applied when energy < max', () {
      final s = _stateAt(PetStage.juvenile, energy: 3);
      final r = _engine.applyAction(s, CareAction.surge, t);
      expect(r.outcome, PetActionOutcome.applied);
      expect(r.state.instability, greaterThan(0));
    });

    test('capped at max energy with no hungry call', () {
      final s = _stateAt(PetStage.juvenile, energy: _config.statMax);
      final r = _engine.applyAction(s, CareAction.surge, t);
      expect(r.outcome, PetActionOutcome.capped);
      expect(r.reason, PetActionReason.fullyCharged);
    });

    test('invalidInState(asleep) when asleep', () {
      final s = _stateAt(PetStage.juvenile).copyWith(isAsleep: true);
      final r = _engine.applyAction(s, CareAction.surge, t);
      expect(r.outcome, PetActionOutcome.invalidInState);
    });
  });

  group('Resonate outcomes', () {
    test('applied when mood < max', () {
      final s = _stateAt(PetStage.juvenile, mood: 3);
      final r = _engine.applyAction(s, CareAction.resonate, t);
      expect(r.outcome, PetActionOutcome.applied);
    });

    test('notNeeded(moodAlreadyFull) at max mood and no lonely call', () {
      final s = _stateAt(PetStage.juvenile, mood: _config.statMax);
      final r = _engine.applyAction(s, CareAction.resonate, t);
      expect(r.outcome, PetActionOutcome.notNeeded);
      expect(r.reason, PetActionReason.moodAlreadyFull);
    });

    test('applied at max mood when lonely call is active', () {
      var s = _stateAt(PetStage.juvenile, mood: _config.statMax);
      s = s.copyWith(
        activeCall: AttentionCall(
          startedAt: t,
          deadline: t.add(const Duration(hours: 2)),
          reason: CallReason.lonely,
        ),
      );
      final r = _engine.applyAction(s, CareAction.resonate, t);
      expect(r.outcome, PetActionOutcome.applied);
    });

    test('invalidInState(asleep) when asleep', () {
      final s = _stateAt(PetStage.juvenile).copyWith(isAsleep: true);
      final r = _engine.applyAction(s, CareAction.resonate, t);
      expect(r.outcome, PetActionOutcome.invalidInState);
      expect(r.reason, PetActionReason.asleep);
    });
  });

  group('Stabilise outcomes', () {
    test('notNeeded(nothingToClean) when no artefacts', () {
      final s = _stateAt(PetStage.juvenile);
      final r = _engine.applyAction(s, CareAction.stabilise, t);
      expect(r.outcome, PetActionOutcome.notNeeded);
      expect(r.reason, PetActionReason.nothingToClean);
    });

    test('applied when an artefact is on the field', () {
      final s = _stateAt(
        PetStage.juvenile,
      ).copyWith(hygieneArtefacts: [t.subtract(const Duration(hours: 3))]);
      final r = _engine.applyAction(s, CareAction.stabilise, t);
      expect(r.outcome, PetActionOutcome.applied);
      expect(r.state.hygieneArtefacts, isEmpty);
    });
  });

  group('Sync outcomes', () {
    test('notNeeded(nothingToSync) when no active call', () {
      final s = _stateAt(PetStage.juvenile, stability: 5);
      final r = _engine.applyAction(s, CareAction.sync, t);
      expect(r.outcome, PetActionOutcome.notNeeded);
      expect(r.reason, PetActionReason.nothingToSync);
    });

    test('applied when call is active — answers it without changing stats', () {
      var s = _stateAt(PetStage.juvenile, stability: 5);
      s = s.copyWith(
        activeCall: AttentionCall(
          startedAt: t,
          deadline: t.add(const Duration(hours: 2)),
          reason: CallReason.lonely,
        ),
      );
      final r = _engine.applyAction(s, CareAction.sync, t);
      expect(r.outcome, PetActionOutcome.applied);
      expect(r.state.activeCall, isNull);
      expect(
        r.state.stability,
        s.stability,
        reason: 'Sync is pure call-answer; stability is untouched',
      );
    });
  });

  group('Purge outcomes', () {
    test('invalidInState(notSick) when not sick', () {
      final s = _stateAt(PetStage.juvenile);
      final r = _engine.applyAction(s, CareAction.purge, t);
      expect(r.outcome, PetActionOutcome.invalidInState);
      expect(r.reason, PetActionReason.notSick);
    });

    test('applied when sick', () {
      final s = _stateAt(
        PetStage.juvenile,
      ).copyWith(isSick: true, instability: 8);
      final r = _engine.applyAction(s, CareAction.purge, t);
      expect(r.outcome, PetActionOutcome.applied);
      expect(r.state.isSick, isFalse);
    });
  });

  group('Dim outcomes', () {
    test('invalidInState(notBedtime) outside sleep window', () {
      final daytime = _hatch.copyWith(hour: 12);
      final s = _stateAt(PetStage.juvenile, now: daytime);
      final r = _engine.applyAction(s, CareAction.dim, daytime);
      expect(r.outcome, PetActionOutcome.invalidInState);
      expect(r.reason, PetActionReason.notBedtime);
    });

    test('applied inside sleep window', () {
      final bedtime = _hatch.copyWith(hour: 23);
      final s = _stateAt(PetStage.juvenile, now: bedtime);
      final r = _engine.applyAction(s, CareAction.dim, bedtime);
      expect(r.outcome, PetActionOutcome.applied);
      expect(r.state.isAsleep, isTrue);
    });

    test('notNeeded(alreadyAsleep) when already asleep', () {
      final bedtime = _hatch.copyWith(hour: 23);
      final s = _stateAt(
        PetStage.juvenile,
        now: bedtime,
      ).copyWith(isAsleep: true);
      final r = _engine.applyAction(s, CareAction.dim, bedtime);
      expect(r.outcome, PetActionOutcome.notNeeded);
      expect(r.reason, PetActionReason.alreadyAsleep);
    });
  });

  group('Inspect and ReSigil outcomes', () {
    test('Inspect always applied', () {
      for (final stage in PetStage.values) {
        final s = _stateAt(stage);
        final r = _engine.applyAction(s, CareAction.inspect, t);
        expect(r.outcome, PetActionOutcome.applied, reason: stage.name);
      }
    });

    test('ReSigil invalidInState(notDormant) when pet is alive', () {
      for (final stage in [
        PetStage.egg,
        PetStage.juvenile,
        PetStage.adolescent,
        PetStage.adult,
        PetStage.elder,
      ]) {
        final s = _stateAt(stage);
        final r = _engine.applyAction(s, CareAction.reSigil, t);
        expect(r.outcome, PetActionOutcome.invalidInState, reason: stage.name);
        expect(r.reason, PetActionReason.notDormant, reason: stage.name);
      }
    });

    test('ReSigil applied when dormant', () {
      final s = _stateAt(PetStage.dormant);
      final r = _engine.applyAction(s, CareAction.reSigil, t);
      expect(r.outcome, PetActionOutcome.applied);
    });
  });

  group('Outcome classification helpers', () {
    test('isApplied vs isNoOp', () {
      final applied = PetActionResult.applied(
        state: _stateAt(PetStage.juvenile),
        action: CareAction.charge,
      );
      final capped = PetActionResult.capped(
        state: _stateAt(PetStage.juvenile, energy: 10),
        action: CareAction.charge,
        reason: PetActionReason.fullyCharged,
      );
      expect(applied.isApplied, isTrue);
      expect(applied.isNoOp, isFalse);
      expect(capped.isApplied, isFalse);
      expect(capped.isNoOp, isTrue);
    });
  });
}
