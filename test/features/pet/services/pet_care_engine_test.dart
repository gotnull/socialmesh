// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/pet_config.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/models/pet_state.dart';
import 'package:socialmesh/features/pet/services/pet_care_engine.dart';

const _noonHatchHour = 12;

// Daytime base (not in sleep window).
DateTime _day(int d, [int h = _noonHatchHour, int m = 0]) =>
    DateTime(2026, 3, d, h, m);

PetState _freshJuvenile(PetConfig config, DateTime at) {
  return PetState.egg(
    ownerNodeNum: 0xA5A5A5A5,
    hatchedAt: at.subtract(config.eggDuration + const Duration(seconds: 1)),
    statMax: config.statMax,
  );
}

void main() {
  group('PetCareEngine — determinism (acceptance #1)', () {
    test('same (ownerNodeNum, hatchedAt) produces identical dnaSeed 100x', () {
      final hatchedAt = DateTime(2026, 4, 1, 12);
      final seeds = <int>{};
      for (var i = 0; i < 100; i++) {
        final s = PetState.egg(ownerNodeNum: 0xFEEDFACE, hatchedAt: hatchedAt);
        seeds.add(s.dnaSeed);
      }
      expect(seeds.length, 1);
    });

    test('different hatchedAt gives different dnaSeed', () {
      final a = PetState.egg(
        ownerNodeNum: 0xFEEDFACE,
        hatchedAt: DateTime(2026, 4, 1, 12),
      ).dnaSeed;
      final b = PetState.egg(
        ownerNodeNum: 0xFEEDFACE,
        hatchedAt: DateTime(2026, 4, 1, 12, 0, 1),
      ).dnaSeed;
      expect(a, isNot(b));
    });
  });

  group('PetCareEngine — stat decay (acceptance #2)', () {
    test('full-stat start drains energy over ~10h (production defaults)', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 12);
      // Skip past egg stage so decay kicks in.
      var s = _freshJuvenile(config, start);
      // Jump 10 hours forward.
      final later = start.add(const Duration(hours: 10));
      s = engine.advanceTo(s, later);
      // Energy decays 1/tick, 30-min ticks → 20 ticks → 10 energy → 0.
      expect(s.energy, lessThanOrEqualTo(1));
      expect(s.energy, greaterThanOrEqualTo(0));
    });

    test('advanceTo is idempotent when gap = 0', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final at = _day(1, 10);
      final s = _freshJuvenile(config, at);
      final advanced = engine.advanceTo(s, s.lastTickAt);
      expect(advanced.energy, s.energy);
      expect(advanced.mood, s.mood);
      expect(advanced.stability, s.stability);
    });

    test('advanceTo with negative gap does nothing', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final at = _day(1, 10);
      final s = _freshJuvenile(config, at);
      final advanced = engine.advanceTo(
        s,
        s.lastTickAt.subtract(const Duration(hours: 1)),
      );
      expect(advanced, s);
    });
  });

  group('PetCareEngine — attention calls + mistakes (acceptance #3)', () {
    test('ignoring a call past deadline increments mistake counter', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 10);
      var s = _freshJuvenile(config, start);

      // Drain energy enough to trigger a call (4h ≈ 8 decay ticks → energy 2).
      s = engine.advanceTo(s, start.add(const Duration(hours: 4)));
      expect(s.activeCall, isNotNull, reason: 'low energy must trigger call');

      final mistakesBefore = s.stageAccumulators.mistakes;
      final deadline = s.activeCall!.deadline;
      s = engine.advanceTo(s, deadline.add(const Duration(minutes: 1)));
      expect(s.stageAccumulators.mistakes, greaterThan(mistakesBefore));
    });

    test('Charge answers a hungry call and increments answeredCalls', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 10);
      var s = _freshJuvenile(config, start);

      s = engine.advanceTo(s, start.add(const Duration(hours: 4)));
      expect(s.activeCall, isNotNull);
      expect(s.activeCall!.reason, CallReason.hungry);

      final answeredBefore = s.stageAccumulators.answeredCalls;
      final actionAt = s.lastTickAt.add(const Duration(minutes: 5));
      s = engine.applyAction(s, CareAction.charge, actionAt);

      expect(s.activeCall, isNull);
      expect(s.stageAccumulators.answeredCalls, answeredBefore + 1);
    });
  });

  group('PetCareEngine — sleep transitions (acceptance #4)', () {
    test('entering sleep window sets isAsleep', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      // Hatch in the evening; engine should find itself in sleep window
      // after advancing to 23:00.
      final start = _day(1, 20);
      var s = _freshJuvenile(config, start);
      s = engine.advanceTo(s, _day(1, 23));
      expect(s.isAsleep, isTrue);
    });

    test('leaving sleep window clears isAsleep on next tick', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 23);
      var s = _freshJuvenile(config, start);
      s = engine.advanceTo(s, start); // settle into sleep
      expect(s.isAsleep, isTrue);

      s = engine.advanceTo(s, _day(2, 8));
      expect(s.isAsleep, isFalse);
    });

    test('Charge is a no-op while asleep', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 23);
      var s = _freshJuvenile(config, start);
      s = engine.advanceTo(s, start);
      expect(s.isAsleep, isTrue);

      final energyBefore = s.energy;
      s = engine.applyAction(s, CareAction.charge, start);
      expect(s.energy, energyBefore);
    });
  });

  group('PetCareEngine — sickness (acceptance #5)', () {
    test('multiple Surges push instability past threshold → sickness', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 10);
      var s = _freshJuvenile(config, start);

      // Enough surges to push instability ≥ sicknessInstabilityThreshold.
      final surgesNeeded =
          (config.sicknessInstabilityThreshold / config.instabilityPerSurge)
              .ceil();
      var t = start;
      for (var i = 0; i < surgesNeeded + 1; i++) {
        t = t.add(const Duration(seconds: 1));
        s = engine.applyAction(s, CareAction.surge, t);
      }
      // The next tick evaluates sickness onset.
      s = engine.advanceTo(s, t.add(config.careTickDuration));
      expect(s.isSick, isTrue);
    });

    test('Purge recovers from sickness', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 10);
      var s = _freshJuvenile(config, start);

      // Force sickness directly.
      s = s.copyWith(isSick: true, instability: 8);
      s = engine.applyAction(s, CareAction.purge, start);
      expect(s.isSick, isFalse);
    });
  });

  group('PetCareEngine — persistence round-trip (acceptance #7)', () {
    test('PetState survives JSON round-trip unchanged', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 10);
      var s = _freshJuvenile(config, start);
      // Generate some history.
      s = engine.advanceTo(s, start.add(const Duration(hours: 3)));
      s = engine.applyAction(
        s,
        CareAction.charge,
        start.add(const Duration(hours: 3, minutes: 1)),
      );

      final json = s.toJsonString();
      final restored = PetState.fromJsonString(json);

      expect(restored.ownerNodeNum, s.ownerNodeNum);
      expect(restored.dnaSeed, s.dnaSeed);
      expect(restored.stage, s.stage);
      expect(restored.branch, s.branch);
      expect(restored.energy, s.energy);
      expect(restored.mood, s.mood);
      expect(restored.stability, s.stability);
      expect(restored.instability, s.instability);
      expect(restored.isSick, s.isSick);
      expect(restored.isAsleep, s.isAsleep);
      expect(restored.hygieneArtefacts.length, s.hygieneArtefacts.length);
      expect(restored.activeCall?.reason, s.activeCall?.reason);
      expect(restored.stageAccumulators, s.stageAccumulators);
      expect(restored.recentEvents.length, s.recentEvents.length);
    });
  });

  group('PetCareEngine — long-gap catch-up invariants', () {
    test('exact mode for gap ≤ 24h', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 10);
      var s = _freshJuvenile(config, start);
      s = engine.advanceTo(s, start.add(const Duration(hours: 23)));
      // Stats should be near floor but not below 0.
      expect(s.energy, inInclusiveRange(0, config.statMax));
      expect(s.mood, inInclusiveRange(0, config.statMax));
    });

    test('gap > 24h: stats stay ≥ neglectFloorStat', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 10);
      var s = _freshJuvenile(config, start);
      // 30 days later.
      s = engine.advanceTo(s, start.add(const Duration(days: 30)));
      expect(s.energy, greaterThanOrEqualTo(config.neglectFloorStat));
      expect(s.mood, greaterThanOrEqualTo(config.neglectFloorStat));
      expect(s.stability, greaterThanOrEqualTo(config.neglectFloorStat));
    });

    test('extreme gaps leave the pet in a valid, recoverable state', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 10);
      var s = _freshJuvenile(config, start);

      // 10 years of absence.
      s = engine.advanceTo(s, start.add(const Duration(days: 3650)));

      // Stats never underflow.
      expect(s.energy, greaterThanOrEqualTo(config.neglectFloorStat));
      expect(s.mood, greaterThanOrEqualTo(config.neglectFloorStat));
      expect(s.stability, greaterThanOrEqualTo(config.neglectFloorStat));
      // Hygiene field doesn't grow unbounded.
      expect(
        s.hygieneArtefacts.length,
        lessThanOrEqualTo(config.hygieneMaxOnField),
      );
      // Stage chain walks to completion rather than stalling mid-progression.
      expect(s.stage, PetStage.dormant);
    });

    test('bounded-mode stage walk progresses through all stages', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 10);
      var s = _freshJuvenile(config, start);

      // 8 days should land us in adult; exact handles the first 24h, bounded
      // handles days 2-8.
      s = engine.advanceTo(s, start.add(const Duration(days: 8)));
      expect(s.stage, PetStage.adult);
    });
  });
}
