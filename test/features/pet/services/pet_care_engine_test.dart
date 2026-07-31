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

    // Regression: the partial-sub-tick branch in _advanceExact used to
    // unconditionally bump `lastTickAt` to `now`, which pushed the next
    // care-tick boundary forward every time advanceTo was called with a
    // sub-tick gap. Result: when the UI's animation ticker called
    // advanceTo every 10s, the care tick's 30-minute cadence never
    // fired and stats stayed at the hatch value forever. Reproduce the
    // tight-cadence pattern and assert real decay.
    test('repeated sub-tick advanceTo calls still hit care tick at 30min', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 12);
      var s = _freshJuvenile(config, start);
      final initialEnergy = s.energy;
      // Simulate the UI animation ticker: call advanceTo every 10s for
      // 45 real minutes. The partial-sub-tick bug would keep
      // `lastTickAt` bumping forward and suppress every care tick.
      for (
        var elapsed = Duration.zero;
        elapsed < const Duration(minutes: 45);
        elapsed += const Duration(seconds: 10)
      ) {
        s = engine.advanceTo(s, start.add(elapsed));
      }
      // After 45 minutes, at least one 30-minute care tick must have
      // fired — stats must have decayed off the hatch value.
      expect(
        s.energy,
        lessThan(initialEnergy),
        reason: 'care tick must fire across sub-tick advanceTo calls',
      );
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

    // Regression: totalCalls used to be incremented BOTH when the call
    // started AND again when it expired, double-counting missed calls
    // and deflating attentionScore. This biases the adolescent→adult
    // branch resolution away from Luminous for pets that miss calls.
    test('missed call increments totalCalls exactly once', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 10);
      var s = _freshJuvenile(config, start);

      // Drain to trigger a call.
      s = engine.advanceTo(s, start.add(const Duration(hours: 4)));
      expect(s.activeCall, isNotNull);
      expect(s.stageAccumulators.totalCalls, 1);

      // Miss it.
      final deadline = s.activeCall!.deadline;
      s = engine.advanceTo(s, deadline.add(const Duration(minutes: 1)));

      // After miss: totalCalls must STILL be 1, not 2.
      expect(
        s.stageAccumulators.totalCalls,
        1,
        reason: 'totalCalls counted at start; expiry must not re-count',
      );
      expect(s.stageAccumulators.mistakes, greaterThan(0));
      // attentionScore is the key derived value — 0 answered / 1 total = 0.0
      // (with the bug: 0 / 2 = 0.0, same output but the semantics are wrong
      // and multi-call sequences diverge from truth).
      expect(s.stageAccumulators.attentionScore, 0.0);
    });

    // Conservation invariant: every call either gets answered or missed.
    // So totalCalls must equal answeredCalls + missed-call mistakes.
    // With the double-count bug, totalCalls would exceed that sum and
    // attentionScore would be deflated. This test runs a long session
    // with mixed answered/missed calls and asserts the invariant.
    test('totalCalls == answeredCalls + missedCalls across a long session', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 10);
      var s = _freshJuvenile(config, start);

      // First call: answer it.
      s = engine.advanceTo(s, start.add(const Duration(hours: 4)));
      expect(s.activeCall?.reason, CallReason.hungry);
      s = engine
          .applyAction(
            s,
            CareAction.charge,
            start.add(const Duration(hours: 4, minutes: 1)),
          )
          .state;

      // Long catch-up: lets more calls trigger + expire unanswered.
      s = engine.advanceTo(s, start.add(const Duration(hours: 16)));

      // Count missed calls by scanning recentEvents for callMissed.
      final missedCount = s.recentEvents
          .where((e) => e.kind == CareEventKind.callMissed)
          .length;

      // Conservation: totalCalls = answered + missed + (live call, if any)
      final live = s.activeCall == null ? 0 : 1;
      expect(
        s.stageAccumulators.totalCalls,
        s.stageAccumulators.answeredCalls + missedCount + live,
        reason:
            'totalCalls must equal answered + missed (+ live); '
            'double-counting would make this diverge',
      );

      // And attentionScore is the honest ratio.
      expect(
        s.stageAccumulators.attentionScore,
        closeTo(
          s.stageAccumulators.answeredCalls / s.stageAccumulators.totalCalls,
          1e-9,
        ),
      );
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
      s = engine.applyAction(s, CareAction.charge, actionAt).state;

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
      s = engine.applyAction(s, CareAction.charge, start).state;
      expect(s.energy, energyBefore);
    });

    test('sleep window is zone-flag independent (wall-clock semantics)', () {
      // State rehydrated from the repository carries UTC-flagged
      // DateTimes while fresh in-session timestamps are local. The
      // window must evaluate identically for the same instant under
      // either flag, or it shifts by the UTC offset after an app
      // restart. Vacuous on a UTC-zoned test host (toLocal is then
      // the identity); discriminating on any other host.
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      for (var h = 0; h < 24; h++) {
        final local = _day(1, h);
        expect(
          engine.isInSleepWindow(local.toUtc()),
          engine.isInSleepWindow(local),
          reason:
              'hour $h: UTC-flagged and local-flagged views of the '
              'same instant must agree',
        );
      }
    });
  });

  group('PetCareEngine — sickness (acceptance #5)', () {
    test('multiple Surges push instability past threshold → sickness', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 10);
      var s = _freshJuvenile(config, start);
      // Advance past the egg stage so Surge is valid, and drain energy
      // to just below max so each Surge is "applied" (not capped) and
      // the instability bump fires.
      s = engine.advanceTo(s, start.add(const Duration(hours: 2)));
      s = s.copyWith(energy: 3);

      // Enough surges to push instability ≥ sicknessInstabilityThreshold.
      final surgesNeeded =
          (config.sicknessInstabilityThreshold / config.instabilityPerSurge)
              .ceil();
      var t = s.lastTickAt;
      for (var i = 0; i < surgesNeeded + 1; i++) {
        t = t.add(const Duration(seconds: 1));
        s = engine.applyAction(s, CareAction.surge, t).state;
        // Keep draining energy so each surge is applied, not capped.
        s = s.copyWith(energy: 3);
      }
      // The next care tick evaluates sickness onset.
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
      s = engine.applyAction(s, CareAction.purge, start).state;
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
      s = engine
          .applyAction(
            s,
            CareAction.charge,
            start.add(const Duration(hours: 3, minutes: 1)),
          )
          .state;

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

    // Regression: bounded-mode used to generate synthetic hygiene
    // artefacts at `lastTickAt + (fullListIndex + 1) days`, which
    // placed high-index artefacts PAST `now` when the pet already had
    // some artefacts before the gap. Artefacts dated in the future
    // never satisfy the stale check, so sickness would never trigger
    // from them during catch-up.
    test('bounded-mode synthetic hygiene artefacts are all ≤ now', () {
      const config = PetConfig();
      final engine = PetCareEngine(config: config);
      final start = _day(1, 10);
      // Start with an existing pre-gap artefact so the synthetic
      // ones get placed at high indices.
      var s = _freshJuvenile(
        config,
        start,
      ).copyWith(hygieneArtefacts: [start.add(const Duration(hours: 1))]);

      final now = start.add(const Duration(days: 5));
      s = engine.advanceTo(s, now);

      // Every artefact must land at or before `now` — no futures.
      for (final a in s.hygieneArtefacts) {
        expect(
          a.isAfter(now),
          isFalse,
          reason: 'hygiene artefact $a landed past now=$now',
        );
      }
      // And every artefact must be >= the start so we don't go back
      // in time either.
      for (final a in s.hygieneArtefacts) {
        expect(
          a.isBefore(start),
          isFalse,
          reason: 'hygiene artefact $a landed before start=$start',
        );
      }
    });
  });
}
