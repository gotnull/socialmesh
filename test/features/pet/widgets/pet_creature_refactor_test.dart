// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/onboarding/widgets/mesh_node_brain.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/widgets/pet_sigil_painter.dart';

void main() {
  group('paletteFromDnaSeed determinism', () {
    test('same seed + branch produces identical palette', () {
      final a = paletteFromDnaSeed(0xA5F3C7, PetBranch.steady);
      final b = paletteFromDnaSeed(0xA5F3C7, PetBranch.steady);
      expect(a, equals(b));
      expect(a, hasLength(3));
    });

    test('adjacent seeds produce visibly different palettes', () {
      final a = paletteFromDnaSeed(0xA5F3C7, PetBranch.steady);
      final b = paletteFromDnaSeed(0xA5F3C8, PetBranch.steady);
      // First colour should not match — Murmur3 fmix32 scrambles bits
      // enough that a +1 seed lands on a very different hue.
      expect(a[0], isNot(equals(b[0])));
    });

    test('branch tunes saturation / lightness without shifting hue', () {
      const seed = 0x12345;
      final luminous = paletteFromDnaSeed(seed, PetBranch.luminous);
      final dimmed = paletteFromDnaSeed(seed, PetBranch.dimmed);
      final luminousHsl = HSLColor.fromColor(luminous[0]);
      final dimmedHsl = HSLColor.fromColor(dimmed[0]);
      // Hue stable across branches for the same seed.
      expect(
        (luminousHsl.hue - dimmedHsl.hue).abs() % 360,
        lessThan(1.0),
        reason: 'branch should not rotate hue',
      );
      // Luminous is brighter and more saturated than dimmed.
      expect(luminousHsl.lightness, greaterThan(dimmedHsl.lightness));
      expect(luminousHsl.saturation, greaterThan(dimmedHsl.saturation));
    });

    test('palette has 3 entries', () {
      final palette = paletteFromDnaSeed(42, PetBranch.steady);
      expect(palette, hasLength(3));
    });
  });

  group('mapPetMood precedence', () {
    test('egg always maps to dormant, regardless of flags', () {
      expect(
        mapPetMood(
          mood: PetMood.content,
          stage: PetStage.egg,
          isAsleep: false,
          isSick: false,
          isCalling: false,
        ),
        MeshBrainMood.dormant,
      );
      expect(
        mapPetMood(
          mood: PetMood.calling,
          stage: PetStage.egg,
          isAsleep: false,
          isSick: true,
          isCalling: true,
        ),
        MeshBrainMood.dormant,
      );
    });

    test('dormant stage maps to dormant', () {
      expect(
        mapPetMood(
          mood: PetMood.content,
          stage: PetStage.dormant,
          isAsleep: false,
          isSick: false,
          isCalling: false,
        ),
        MeshBrainMood.dormant,
      );
    });

    test('asleep beats PetMood but not egg/dormant', () {
      expect(
        mapPetMood(
          mood: PetMood.content,
          stage: PetStage.adult,
          isAsleep: true,
          isSick: false,
          isCalling: false,
        ),
        MeshBrainMood.dormant,
      );
    });

    test('sick maps to glitching (sci-fi corruption feel)', () {
      expect(
        mapPetMood(
          mood: PetMood.content,
          stage: PetStage.adult,
          isAsleep: false,
          isSick: true,
          isCalling: false,
        ),
        MeshBrainMood.glitching,
      );
    });

    test('calling maps to alert', () {
      expect(
        mapPetMood(
          mood: PetMood.content,
          stage: PetStage.adult,
          isAsleep: false,
          isSick: false,
          isCalling: true,
        ),
        MeshBrainMood.alert,
      );
    });

    test('PetMood.content → happy when no overriding flag', () {
      expect(
        mapPetMood(
          mood: PetMood.content,
          stage: PetStage.adult,
          isAsleep: false,
          isSick: false,
          isCalling: false,
        ),
        MeshBrainMood.happy,
      );
    });

    test('PetMood.hungry → hopeful (seeking feed)', () {
      expect(
        mapPetMood(
          mood: PetMood.hungry,
          stage: PetStage.adult,
          isAsleep: false,
          isSick: false,
          isCalling: false,
        ),
        MeshBrainMood.hopeful,
      );
    });

    test('PetMood.sad → sad', () {
      expect(
        mapPetMood(
          mood: PetMood.sad,
          stage: PetStage.adult,
          isAsleep: false,
          isSick: false,
          isCalling: false,
        ),
        MeshBrainMood.sad,
      );
    });
  });

  group('PetCreature widget', () {
    testWidgets('builds without error across full stage × branch matrix', (
      tester,
    ) async {
      for (final stage in PetStage.values) {
        for (final branch in PetBranch.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: PetCreature(
                  dnaSeed: 0xDEAD_BEEF ^ stage.index ^ branch.index,
                  stage: stage,
                  branch: branch,
                  mood: PetMood.content,
                  isAsleep: false,
                  isSick: false,
                  isCalling: false,
                  hygieneArtefactCount: 0,
                  size: 120,
                ),
              ),
            ),
          );
          expect(find.byType(PetCreature), findsOneWidget);
          expect(
            find.byType(MeshNodeBrain),
            findsOneWidget,
            reason:
                'PetCreature should delegate rendering to MeshNodeBrain '
                'for stage=$stage branch=$branch',
          );
          // Let animations settle between iterations.
          await tester.pump(const Duration(milliseconds: 50));
        }
      }
    });

    testWidgets(
      'sick pet enables sciFiGlitch on the underlying MeshNodeBrain',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Center(
              child: PetCreature(
                dnaSeed: 1,
                stage: PetStage.adult,
                branch: PetBranch.steady,
                mood: PetMood.sick,
                isAsleep: false,
                isSick: true,
                isCalling: false,
                hygieneArtefactCount: 0,
                size: 120,
              ),
            ),
          ),
        );
        final brain = tester.widget<MeshNodeBrain>(find.byType(MeshNodeBrain));
        expect(brain.sciFiGlitch, isTrue);
        expect(brain.mood, MeshBrainMood.glitching);
      },
    );

    testWidgets('egg disables expression and faces', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: PetCreature(
              dnaSeed: 1,
              stage: PetStage.egg,
              branch: PetBranch.unborn,
              mood: PetMood.content,
              isAsleep: false,
              isSick: false,
              isCalling: false,
              hygieneArtefactCount: 0,
              size: 120,
            ),
          ),
        ),
      );
      final brain = tester.widget<MeshNodeBrain>(find.byType(MeshNodeBrain));
      expect(brain.showExpression, isFalse);
      expect(brain.showFaces, isFalse);
      expect(brain.interactive, isFalse);
      expect(brain.mood, MeshBrainMood.dormant);
    });

    testWidgets('NodePet always passes preferFrontFace: true', (tester) async {
      for (final mode in PetRenderMode.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: PetCreature(
                dnaSeed: 1,
                stage: PetStage.adult,
                branch: PetBranch.steady,
                mood: PetMood.content,
                isAsleep: false,
                isSick: false,
                isCalling: false,
                hygieneArtefactCount: 0,
                size: 120,
                mode: mode,
              ),
            ),
          ),
        );
        final brain = tester.widget<MeshNodeBrain>(find.byType(MeshNodeBrain));
        expect(
          brain.preferFrontFace,
          isTrue,
          reason:
              'All NodePet modes should pin the face forward so the '
              'creature looks at the user instead of tumbling, mode=$mode',
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    });
  });
}
