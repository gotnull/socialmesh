// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression tests for raw-stat (vitality) modulation of the pet
// renderer. The primary animation contract is PetMood + flags; raw
// stats only supply bounded secondary modulation WITHIN a mood bucket.
// These tests pin the invariant that modulation never crosses mood
// boundaries — a "sick" pet at max stats is still visibly sicker than
// a "hungry" pet at min stats, etc.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/widgets/pet_render_model.dart';
import 'package:socialmesh/features/pet/widgets/pet_sigil_painter.dart';

void main() {
  group('petBreathAmplitude — monotonic in vitality', () {
    test('every mood gets slightly more breath as vitality rises', () {
      for (final mood in PetMood.values) {
        final low = petBreathAmplitude(mood, PetStage.adult, 0.0);
        final mid = petBreathAmplitude(mood, PetStage.adult, 0.5);
        final high = petBreathAmplitude(mood, PetStage.adult, 1.0);
        expect(low, lessThan(mid), reason: '${mood.name}: low < mid');
        expect(mid, lessThan(high), reason: '${mood.name}: mid < high');
      }
    });

    test('modulation band is tight (±10% around midpoint vitality)', () {
      // The band is capped at ±10% because that's the widest the
      // closest adjacent baselines (hungry/sad 0.03 → sleeping 0.04)
      // will tolerate without boundary collision. See §distinct-bucket
      // boundary matrix below.
      for (final mood in PetMood.values) {
        final mid = petBreathAmplitude(mood, PetStage.adult, 0.5);
        final low = petBreathAmplitude(mood, PetStage.adult, 0.0);
        final high = petBreathAmplitude(mood, PetStage.adult, 1.0);
        expect(
          low / mid,
          closeTo(0.90, 0.001),
          reason: '${mood.name}: min is 0.90× of midpoint',
        );
        expect(
          high / mid,
          closeTo(1.10, 0.001),
          reason: '${mood.name}: max is 1.10× of midpoint',
        );
      }
    });

    test('vitality is clamped — values outside [0,1] do not extend band', () {
      final base = petBreathAmplitude(PetMood.content, PetStage.adult, 1.0);
      final over = petBreathAmplitude(PetMood.content, PetStage.adult, 5.0);
      final under = petBreathAmplitude(PetMood.content, PetStage.adult, -2.0);
      expect(over, equals(base));
      expect(
        under,
        equals(petBreathAmplitude(PetMood.content, PetStage.adult, 0.0)),
      );
    });
  });

  group('petBreathAmplitude — mood bucket boundaries preserved', () {
    // Invariant: a pet's mood class must be recognisable regardless of
    // stats. Adjacent mood amplitudes never overlap after modulation.

    test('sick (max stats) stays quieter than sleeping (min stats)', () {
      final sickHigh = petBreathAmplitude(PetMood.sick, PetStage.adult, 1.0);
      final sleepingLow = petBreathAmplitude(
        PetMood.sleeping,
        PetStage.adult,
        0.0,
      );
      expect(sickHigh, lessThan(sleepingLow));
    });

    test('hungry (max stats) stays quieter than content (min stats)', () {
      final hungryHigh = petBreathAmplitude(
        PetMood.hungry,
        PetStage.adult,
        1.0,
      );
      final contentLow = petBreathAmplitude(
        PetMood.content,
        PetStage.adult,
        0.0,
      );
      expect(hungryHigh, lessThan(contentLow));
    });

    test('sad (max stats) stays quieter than content (min stats)', () {
      final sadHigh = petBreathAmplitude(PetMood.sad, PetStage.adult, 1.0);
      final contentLow = petBreathAmplitude(
        PetMood.content,
        PetStage.adult,
        0.0,
      );
      expect(sadHigh, lessThan(contentLow));
    });

    test('content (max stats) stays quieter than calling (min stats)', () {
      final contentHigh = petBreathAmplitude(
        PetMood.content,
        PetStage.adult,
        1.0,
      );
      final callingLow = petBreathAmplitude(
        PetMood.calling,
        PetStage.adult,
        0.0,
      );
      expect(contentHigh, lessThan(callingLow));
    });

    test('sleeping (max stats) stays quieter than content (min stats)', () {
      final sleepingHigh = petBreathAmplitude(
        PetMood.sleeping,
        PetStage.adult,
        1.0,
      );
      final contentLow = petBreathAmplitude(
        PetMood.content,
        PetStage.adult,
        0.0,
      );
      expect(sleepingHigh, lessThan(contentLow));
    });
  });

  group('petBreathAmplitude — egg override', () {
    test('egg stage uses its own baseline regardless of mood', () {
      // All moods at egg stage must return the same baseline (0.10 × vitality band).
      final amps = <double>[];
      for (final mood in PetMood.values) {
        amps.add(petBreathAmplitude(mood, PetStage.egg, 0.75));
      }
      final first = amps.first;
      for (final a in amps) {
        expect(a, equals(first));
      }
    });

    test('egg baseline differs from any adult mood baseline', () {
      final egg = petBreathAmplitude(PetMood.content, PetStage.egg, 0.5);
      for (final mood in PetMood.values) {
        final adult = petBreathAmplitude(mood, PetStage.adult, 0.5);
        expect(egg, isNot(equals(adult)));
      }
    });
  });

  group('petBuoyancyScale — monotonic and tight', () {
    test('bounds are 0.80 (vitality=0) and 1.15 (vitality=1)', () {
      expect(petBuoyancyScale(0.0), 0.80);
      expect(petBuoyancyScale(1.0), closeTo(1.15, 0.001));
    });
    test('midpoint vitality lands near 1.0 (very slight boost)', () {
      expect(petBuoyancyScale(0.5), closeTo(0.975, 0.001));
    });
    test('out-of-range values clamp', () {
      expect(petBuoyancyScale(-1.0), 0.80);
      expect(petBuoyancyScale(2.0), closeTo(1.15, 0.001));
    });
  });

  group('petAuraIntensityScale — stability-only band', () {
    test('bounds are 0.75 (stability=0) and 1.10 (stability=1)', () {
      expect(petAuraIntensityScale(0.0), 0.75);
      expect(petAuraIntensityScale(1.0), closeTo(1.10, 0.001));
    });
    test('clamped outside [0,1]', () {
      expect(petAuraIntensityScale(-0.5), 0.75);
      expect(petAuraIntensityScale(3.0), closeTo(1.10, 0.001));
    });
  });

  group('petWobbleAmplitudeScale — deliberately very narrow', () {
    test('bounds are 0.85 (vitality=0) and 1.05 (vitality=1)', () {
      expect(petWobbleAmplitudeScale(0.0), 0.85);
      expect(petWobbleAmplitudeScale(1.0), closeTo(1.05, 0.001));
    });
    test('peak amplitude never moves more than ±10% around midpoint', () {
      final mid = petWobbleAmplitudeScale(0.5);
      expect(petWobbleAmplitudeScale(0.0) / mid, closeTo(0.895, 0.01));
      expect(petWobbleAmplitudeScale(1.0) / mid, closeTo(1.105, 0.01));
    });
  });

  group('PetRenderContext — vitality aggregation', () {
    PetRenderContext ctx({
      double energy = 1.0,
      double moodStat = 1.0,
      double stability = 1.0,
    }) {
      return PetRenderContext(
        mode: PetRenderMode.home,
        stage: PetStage.adult,
        branch: PetBranch.steady,
        mood: PetMood.content,
        isAsleep: false,
        isSick: false,
        isCalling: false,
        hygieneArtefactCount: 0,
        phase: 0,
        energyNorm: energy,
        moodStatNorm: moodStat,
        stabilityNorm: stability,
      );
    }

    test('defaults to full-health vitality when norms unspecified', () {
      final c = PetRenderContext(
        mode: PetRenderMode.home,
        stage: PetStage.adult,
        branch: PetBranch.steady,
        mood: PetMood.content,
        isAsleep: false,
        isSick: false,
        isCalling: false,
        hygieneArtefactCount: 0,
        phase: 0,
      );
      expect(c.vitality, 1.0);
    });

    test('vitality is the mean of the three stat norms', () {
      expect(
        ctx(energy: 0.5, moodStat: 0.3, stability: 0.7).vitality,
        closeTo(0.5, 1e-9),
      );
      expect(ctx(energy: 0.0, moodStat: 0.0, stability: 0.0).vitality, 0.0);
      expect(ctx(energy: 1.0, moodStat: 1.0, stability: 1.0).vitality, 1.0);
    });

    test('vitality clamps when norms exceed [0,1]', () {
      expect(ctx(energy: 2.0, moodStat: 2.0, stability: 2.0).vitality, 1.0);
      expect(ctx(energy: -1.0, moodStat: -1.0, stability: -1.0).vitality, 0.0);
    });
  });

  group('PetCreature widget — vitality flows through without regression', () {
    // Smoke + construction tests. We can't verify pixel output, but we
    // can verify that (a) the widget accepts the new optional params,
    // (b) same-mood widgets with wildly different stats both paint
    // successfully, and (c) omitting the params is still valid.

    testWidgets('same mood, min-vs-max stats, both paint', (tester) async {
      for (final stats in [(1, 1, 1), (10, 10, 10)]) {
        final (energy, moodStat, stability) = stats;
        final widget = MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: PetCreature(
                dnaSeed: 0xCAFEBABE,
                stage: PetStage.adult,
                branch: PetBranch.steady,
                mood: PetMood.content,
                isAsleep: false,
                isSick: false,
                isCalling: false,
                hygieneArtefactCount: 0,
                size: 220,
                mode: PetRenderMode.home,
                energy: energy,
                moodStat: moodStat,
                stability: stability,
                statMax: 10,
              ),
            ),
          ),
        );
        await tester.pumpWidget(widget);
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester.takeException(),
          isNull,
          reason: 'stats=$stats painted without error',
        );
      }
    });

    testWidgets('omitting raw-stat params still paints (default baseline)', (
      tester,
    ) async {
      final widget = MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: PetCreature(
              dnaSeed: 0x1234ABCD,
              stage: PetStage.adult,
              branch: PetBranch.luminous,
              mood: PetMood.content,
              isAsleep: false,
              isSick: false,
              isCalling: false,
              hygieneArtefactCount: 0,
              size: 220,
              mode: PetRenderMode.home,
              // energy / moodStat / stability omitted — should default
              // to full-health baseline.
            ),
          ),
        ),
      );
      await tester.pumpWidget(widget);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    });

    testWidgets('statMax scales raw-int params correctly', (tester) async {
      // Same normalized stats via different (raw, statMax) pairs must
      // produce identical visual output. We verify by constructing both
      // and confirming both paint — the vitality value is internal.
      for (final cfg in [(5, 10), (50, 100), (1, 2)]) {
        final (raw, max) = cfg;
        final widget = MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: PetCreature(
                dnaSeed: 0xDEADBEEF,
                stage: PetStage.adult,
                branch: PetBranch.steady,
                mood: PetMood.content,
                isAsleep: false,
                isSick: false,
                isCalling: false,
                hygieneArtefactCount: 0,
                size: 220,
                mode: PetRenderMode.home,
                energy: raw,
                moodStat: raw,
                stability: raw,
                statMax: max,
              ),
            ),
          ),
        );
        await tester.pumpWidget(widget);
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull, reason: 'cfg=$cfg');
      }
    });
  });

  group('Regression: modulation never overwhelms the mood contract', () {
    // Holistic assertion — the full matrix of distinct-bucket adjacent
    // pairs at extremal vitality must stay strictly ordered. Moods that
    // share a base amplitude (hungry ≈ sad) occupy the same bucket, so
    // the matrix groups them together.
    //
    // Canonical ordering (low → high):
    //   sick < {hungry, sad} < sleeping < content < calling
    test('distinct-bucket boundary matrix holds at extremes', () {
      final tiers = <List<PetMood>>[
        [PetMood.sick],
        [PetMood.hungry, PetMood.sad],
        [PetMood.sleeping],
        [PetMood.content],
        [PetMood.calling],
      ];
      for (var i = 0; i < tiers.length - 1; i++) {
        for (final lowerMood in tiers[i]) {
          for (final higherMood in tiers[i + 1]) {
            final lowerMax = petBreathAmplitude(lowerMood, PetStage.adult, 1.0);
            final higherMin = petBreathAmplitude(
              higherMood,
              PetStage.adult,
              0.0,
            );
            expect(
              lowerMax < higherMin,
              isTrue,
              reason:
                  '${lowerMood.name}@max ($lowerMax) must stay '
                  'below ${higherMood.name}@min ($higherMin)',
            );
          }
        }
      }
    });

    test('within a shared-base bucket (hungry == sad), amplitudes tie', () {
      for (final v in const [0.0, 0.5, 1.0]) {
        expect(
          petBreathAmplitude(PetMood.hungry, PetStage.adult, v),
          equals(petBreathAmplitude(PetMood.sad, PetStage.adult, v)),
        );
      }
    });
  });
}
