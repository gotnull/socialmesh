// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression tests for time-exact stage transitions.
//
// Stage duration boundaries are honoured precisely — they do NOT snap to
// care-tick boundaries. The care-tick cadence continues to drive
// decay/hygiene/sickness/call lifecycle, independent of stage progression.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/pet_config.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/models/pet_state.dart';
import 'package:socialmesh/features/pet/services/pet_care_engine.dart';

const _ownerNodeNum = 0xF00DBABE;
final _hatch = DateTime(2026, 5, 1, 12);

PetState _fromEgg(PetConfig config) {
  return PetState.egg(
    ownerNodeNum: _ownerNodeNum,
    hatchedAt: _hatch,
    statMax: config.statMax,
  );
}

void main() {
  group('egg hatches at exactly eggDuration', () {
    test('1 second before eggDuration → still egg', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final s = _fromEgg(config);
      final justBefore = _hatch
          .add(config.eggDuration)
          .subtract(const Duration(seconds: 1));
      final advanced = engine.advanceTo(s, justBefore);
      expect(advanced.stage, PetStage.egg);
    });

    test(
      'exactly at eggDuration → juvenile (transition fires on the edge)',
      () {
        const config = PetConfig();
        final engine = PetCareEngine(config: config);
        final s = _fromEgg(config);
        final onBoundary = _hatch.add(config.eggDuration);
        final advanced = engine.advanceTo(s, onBoundary);
        expect(advanced.stage, PetStage.juvenile);
        expect(advanced.stageStartedAt, onBoundary);
      },
    );

    test('1 second after eggDuration → juvenile, transition timestamp '
        'matches eggDuration boundary (NOT the next 30-min care tick)', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final s = _fromEgg(config);
      final justAfter = _hatch
          .add(config.eggDuration)
          .add(const Duration(seconds: 1));
      final advanced = engine.advanceTo(s, justAfter);
      expect(advanced.stage, PetStage.juvenile);
      // The transition fires exactly at the eggDuration boundary — its
      // stageStartedAt is _hatch + eggDuration, not at _hatch + 30min.
      expect(advanced.stageStartedAt, _hatch.add(config.eggDuration));
    });
  });

  group('stage transitions are not quantized to careTickDuration', () {
    test(
      'juvenile → adolescent fires exactly at juvenileDuration boundary',
      () {
        const config = PetConfig();
        final engine = PetCareEngine(config: config);
        final s = _fromEgg(config);
        // Advance to just past juvenile end:
        // egg (10m) + juvenile (2d) + 1s
        final at = _hatch
            .add(config.eggDuration + config.juvenileDuration)
            .add(const Duration(seconds: 1));
        final advanced = engine.advanceTo(s, at);
        expect(advanced.stage, PetStage.adolescent);
        // adolescent's stageStartedAt should be at the juvenile boundary,
        // NOT at the nearest 30-min tick past it.
        expect(
          advanced.stageStartedAt,
          _hatch.add(config.eggDuration + config.juvenileDuration),
        );
      },
    );

    test('adolescent → adult fires exactly at adolescentDuration boundary '
        'and resolves the branch at that instant', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final s = _fromEgg(config);
      final at = _hatch
          .add(
            config.eggDuration +
                config.juvenileDuration +
                config.adolescentDuration,
          )
          .add(const Duration(seconds: 1));
      final advanced = engine.advanceTo(s, at);
      expect(advanced.stage, PetStage.adult);
      expect(
        advanced.stageStartedAt,
        _hatch.add(
          config.eggDuration +
              config.juvenileDuration +
              config.adolescentDuration,
        ),
      );
      // Accumulators reset at the transition.
      expect(advanced.stageAccumulators.mistakes, 0);
      expect(advanced.stageAccumulators.surges, 0);
    });
  });

  group('multiple stage boundaries crossed in a single advance call', () {
    test('egg → juvenile → adolescent all fire in one advance, '
        'each at its exact boundary', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final s = _fromEgg(config);
      final at = _hatch.add(
        config.eggDuration + config.juvenileDuration + const Duration(hours: 3),
      );
      final advanced = engine.advanceTo(s, at);
      expect(advanced.stage, PetStage.adolescent);
      expect(
        advanced.stageStartedAt,
        _hatch.add(config.eggDuration + config.juvenileDuration),
      );
    });

    test('long catch-up across all stages is deterministic', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      // Advance well past elder end — should land in dormant with stable
      // timestamps regardless of run order.
      final at = _hatch
          .add(config.productiveLifespan)
          .add(const Duration(days: 30));
      final first = engine.advanceTo(_fromEgg(config), at);
      final second = engine.advanceTo(_fromEgg(config), at);
      expect(first.stage, PetStage.dormant);
      expect(second.stage, PetStage.dormant);
      expect(first.stageStartedAt, second.stageStartedAt);
      expect(first.branch, second.branch);
    });

    test(
      'bounded catch-up (>24h gap) also lands at exact stage boundaries',
      () {
        const config = PetConfig();
        final engine = PetCareEngine(config: config);
        final s = _fromEgg(config);
        // 8 days forward — exact handles the first 24h, bounded handles
        // the remainder. Should land in adult with stageStartedAt at the
        // exact adolescent-end boundary.
        final at = _hatch.add(const Duration(days: 8));
        final advanced = engine.advanceTo(s, at);
        expect(advanced.stage, PetStage.adult);
        expect(
          advanced.stageStartedAt,
          _hatch.add(
            config.eggDuration +
                config.juvenileDuration +
                config.adolescentDuration,
          ),
        );
      },
    );
  });

  group('care-tick behaviour is unchanged by the refactor', () {
    test('decay still fires at 30-min care-tick cadence', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      // Push pet past egg and juvenile so we're in adolescent (stable
      // stage for a long decay window).
      final adolescentStart = _hatch.add(
        config.eggDuration + config.juvenileDuration,
      );
      var s = engine.advanceTo(_fromEgg(config), adolescentStart);
      expect(s.stage, PetStage.adolescent);
      final startEnergy = s.energy;
      // Advance exactly one care tick.
      s = engine.advanceTo(s, s.lastTickAt.add(config.careTickDuration));
      expect(s.energy, startEnergy - config.energyDecayPerTick);
    });

    test('partial advance between care ticks does NOT apply decay', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final adolescentStart = _hatch.add(
        config.eggDuration + config.juvenileDuration,
      );
      var s = engine.advanceTo(_fromEgg(config), adolescentStart);
      final startEnergy = s.energy;
      // Advance 5 minutes — well below careTickDuration (30 min).
      s = engine.advanceTo(s, s.lastTickAt.add(const Duration(minutes: 5)));
      expect(s.energy, startEnergy);
    });

    test('advancing through a stage boundary + a care tick applies both in '
        'chronological order', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final s = _fromEgg(config);
      // Advance 45 minutes: crosses egg→juvenile at T+10min. The stage
      // transition bumps lastTickAt to T+10min, so the first juvenile
      // care tick fires at T+10min + careTickDuration = T+40min. At
      // T+45min we should be juvenile with one care tick of decay.
      final at = _hatch.add(const Duration(minutes: 45));
      final advanced = engine.advanceTo(s, at);
      expect(advanced.stage, PetStage.juvenile);
      expect(advanced.stageStartedAt, _hatch.add(config.eggDuration));
      expect(advanced.energy, config.statMax - config.energyDecayPerTick);
    });

    test('care-tick cadence realigns to the stage-transition instant — '
        'first care tick in a new stage fires stageStartedAt + careTickDuration, '
        'NOT at the nearest absolute-time tick', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final s = _fromEgg(config);
      // T+39min: egg→juvenile at T+10min, first juvenile care tick at
      // T+40min. At T+39min nothing has decayed yet.
      final at = _hatch.add(const Duration(minutes: 39));
      final advanced = engine.advanceTo(s, at);
      expect(advanced.stage, PetStage.juvenile);
      expect(advanced.energy, config.statMax);
    });
  });
}
