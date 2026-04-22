// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests for the ceremonial double-helix trait (PetHelixSpec).
//
// Pins:
//   - Determinism: same (seed, stage, branch) → same spec.
//   - Presence rules: egg / unborn → disabled. Juvenile → hint.
//     Adolescent+ → full. dnaSeed bit 23 is the coarse presence gate.
//   - Branch style influence: volatile has brokenness, dimmed collapsed
//     radius, luminous reaches further, etc.
//   - Bounded complexity: strandCount ∈ {1, 2, 3}; segmentCount bounded.
//   - Tiny mode: helix skipped at paint time even when enabled.
//   - Paint smoke: every stage × branch × mood combination constructs
//     and paints without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/widgets/pet_render_model.dart';
import 'package:socialmesh/features/pet/widgets/pet_sigil_painter.dart';

/// Seed with presence bit 23 SET — helix enabled when branch/stage allow.
const int _seedWithHelix = 0x00800000;

/// Seed with presence bit 23 CLEAR — helix disabled even at adult.
const int _seedWithoutHelix = 0x00000000;

PetHelixSpec _specFor({
  required int seed,
  required PetStage stage,
  required PetBranch branch,
}) => PetSigilGeometry.forIdentity(
  dnaSeed: seed,
  stage: stage,
  branch: branch,
).helix;

void main() {
  group('PetHelixSpec — determinism', () {
    test('same identity produces identical spec fields', () {
      final a = _specFor(
        seed: _seedWithHelix,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      final b = _specFor(
        seed: _seedWithHelix,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      expect(a.enabled, b.enabled);
      expect(a.presence, b.presence);
      expect(a.strandCount, b.strandCount);
      expect(a.radiusFactor, b.radiusFactor);
      expect(a.verticalSpanFactor, b.verticalSpanFactor);
      expect(a.segmentCount, b.segmentCount);
      expect(a.twistCycles, b.twistCycles);
      expect(a.wobbleAmount, b.wobbleAmount);
      expect(a.baseAngle, b.baseAngle);
      expect(a.brokennessMask, b.brokennessMask);
    });

    test('different seeds may produce distinct specs', () {
      final a = _specFor(
        seed: _seedWithHelix,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      final b = _specFor(
        seed: _seedWithHelix | 0x0000FFFF,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      // At minimum one of the seed-derived fields should differ.
      final distinct =
          a.baseAngle != b.baseAngle ||
          a.radiusFactor != b.radiusFactor ||
          a.brokennessMask != b.brokennessMask ||
          a.strandCount != b.strandCount ||
          a.twistCycles != b.twistCycles;
      expect(distinct, isTrue);
    });
  });

  group('PetHelixSpec — presence gating', () {
    test('egg stage → disabled regardless of seed or branch', () {
      for (final branch in PetBranch.values) {
        final spec = _specFor(
          seed: _seedWithHelix,
          stage: PetStage.egg,
          branch: branch,
        );
        expect(spec.enabled, isFalse, reason: 'egg + ${branch.name}');
        expect(spec.presence, PetHelixPresence.none);
      }
    });

    test('unborn branch → disabled regardless of seed or stage', () {
      for (final stage in PetStage.values) {
        final spec = _specFor(
          seed: _seedWithHelix,
          stage: stage,
          branch: PetBranch.unborn,
        );
        expect(spec.enabled, isFalse, reason: 'unborn + ${stage.name}');
      }
    });

    test('presence-bit-CLEAR seed → disabled even at adult', () {
      for (final branch in PetBranch.values) {
        if (branch == PetBranch.unborn) continue;
        final spec = _specFor(
          seed: _seedWithoutHelix,
          stage: PetStage.adult,
          branch: branch,
        );
        expect(spec.enabled, isFalse, reason: 'noHelixSeed + ${branch.name}');
      }
    });

    test('juvenile (enabled) → hint presence', () {
      for (final branch in PetBranch.values) {
        if (branch == PetBranch.unborn) continue;
        final spec = _specFor(
          seed: _seedWithHelix,
          stage: PetStage.juvenile,
          branch: branch,
        );
        expect(spec.enabled, isTrue);
        expect(spec.presence, PetHelixPresence.hint);
      }
    });

    test('adolescent / adult / elder / dormant (enabled) → full presence', () {
      for (final stage in const [
        PetStage.adolescent,
        PetStage.adult,
        PetStage.elder,
        PetStage.dormant,
      ]) {
        final spec = _specFor(
          seed: _seedWithHelix,
          stage: stage,
          branch: PetBranch.steady,
        );
        expect(spec.enabled, isTrue);
        expect(spec.presence, PetHelixPresence.full);
      }
    });
  });

  group('PetHelixSpec — bounded complexity', () {
    test('strandCount ∈ {1, 2, 3} across a seed sweep', () {
      for (var i = 0; i < 256; i++) {
        final seed = _seedWithHelix | i;
        for (final branch in PetBranch.values) {
          if (branch == PetBranch.unborn) continue;
          final spec = _specFor(
            seed: seed,
            stage: PetStage.adult,
            branch: branch,
          );
          expect(
            spec.strandCount,
            inInclusiveRange(1, 3),
            reason: 'seed=$seed branch=${branch.name}',
          );
        }
      }
    });

    test('segmentCount is bounded (≤ 24 — helix is cheap)', () {
      final spec = _specFor(
        seed: _seedWithHelix,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      expect(spec.segmentCount, lessThanOrEqualTo(24));
      expect(spec.segmentCount, greaterThan(0));
    });

    test('twistCycles is integer (wrap continuity)', () {
      for (final branch in PetBranch.values) {
        if (branch == PetBranch.unborn) continue;
        final spec = _specFor(
          seed: _seedWithHelix,
          stage: PetStage.adult,
          branch: branch,
        );
        expect(spec.twistCycles, inInclusiveRange(1, 5), reason: branch.name);
        expect(spec.twistCycles, isA<int>());
      }
    });

    test('disabled spec has zero complexity', () {
      final spec = _specFor(
        seed: _seedWithoutHelix,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      expect(spec.enabled, isFalse);
      expect(spec.strandCount, 0);
      expect(spec.segmentCount, 0);
      expect(spec.twistCycles, 0);
      expect(spec.rungCount, 0);
    });

    test('rungCount: full 2-strand helix has 5–8 rungs', () {
      // Sweep seeds that vary bits 27–30 (which control strandRoll) so
      // we hit the 2-strand branch of the classifier (common case).
      // Seed 0x10000000 = strandRoll nibble 0x2 → 2-strand on steady.
      var sampled = 0;
      for (var i = 2; i < 16; i++) {
        // Skip strandRoll 0 (→ 3 strands) and 1 (→ 1 strand) on steady.
        final seed = _seedWithHelix | (i << 27);
        final spec = _specFor(
          seed: seed,
          stage: PetStage.adult,
          branch: PetBranch.steady,
        );
        if (spec.strandCount != 2) continue;
        expect(
          spec.rungCount,
          inInclusiveRange(5, 8),
          reason: 'seed=${seed.toRadixString(16)} adult steady',
        );
        sampled += 1;
      }
      expect(sampled, greaterThan(0), reason: 'must cover ≥1 2-strand seed');
    });

    test('rungCount: juvenile (hint) halves the rung density', () {
      final spec = _specFor(
        seed: _seedWithHelix,
        stage: PetStage.juvenile,
        branch: PetBranch.steady,
      );
      if (spec.strandCount == 2) {
        expect(spec.rungCount, inInclusiveRange(2, 4));
        expect(spec.rungCount, lessThan(6));
      }
    });

    test('rungCount: single-strand and 3-strand anomalies have 0 rungs', () {
      for (var i = 0; i < 256; i++) {
        final seed = _seedWithHelix | i;
        final spec = _specFor(
          seed: seed,
          stage: PetStage.adult,
          branch: PetBranch.volatile,
        );
        if (spec.strandCount != 2) {
          expect(
            spec.rungCount,
            0,
            reason: 'strandCount=${spec.strandCount} must have no rungs',
          );
        }
      }
    });
  });

  group('PetHelixSpec — branch style influence', () {
    test('volatile produces non-zero brokenness mask', () {
      // Try a sweep since the mask derives from dnaSeed — most seeds
      // should produce at least one broken segment on volatile.
      var foundBroken = false;
      for (var i = 0; i < 32; i++) {
        final seed = _seedWithHelix | (i << 3);
        final spec = _specFor(
          seed: seed,
          stage: PetStage.adult,
          branch: PetBranch.volatile,
        );
        if (spec.brokennessMask != 0) {
          foundBroken = true;
          break;
        }
      }
      expect(foundBroken, isTrue);
    });

    test('luminous and steady never produce brokenness', () {
      for (var i = 0; i < 64; i++) {
        final seed = _seedWithHelix | (i << 3);
        for (final branch in const [PetBranch.luminous, PetBranch.steady]) {
          final spec = _specFor(
            seed: seed,
            stage: PetStage.adult,
            branch: branch,
          );
          expect(
            spec.brokennessMask,
            0,
            reason: '${branch.name} must not fracture (seed=$seed)',
          );
        }
      }
    });

    test('dimmed has collapsed radius vs luminous', () {
      // Pinned for the same seed — luminous reaches further.
      final seed = _seedWithHelix | 0xA5;
      final luminous = _specFor(
        seed: seed,
        stage: PetStage.adult,
        branch: PetBranch.luminous,
      );
      final dimmed = _specFor(
        seed: seed,
        stage: PetStage.adult,
        branch: PetBranch.dimmed,
      );
      expect(luminous.radiusFactor, greaterThan(dimmed.radiusFactor));
    });

    test('elder has taller vertical span than adult', () {
      final adult = _specFor(
        seed: _seedWithHelix,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      final elder = _specFor(
        seed: _seedWithHelix,
        stage: PetStage.elder,
        branch: PetBranch.steady,
      );
      expect(elder.verticalSpanFactor, greaterThan(adult.verticalSpanFactor));
    });

    test('dormant has shortest vertical span (ghost remnant)', () {
      final dormant = _specFor(
        seed: _seedWithHelix,
        stage: PetStage.dormant,
        branch: PetBranch.steady,
      );
      final adult = _specFor(
        seed: _seedWithHelix,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      expect(dormant.verticalSpanFactor, lessThan(adult.verticalSpanFactor));
    });
  });

  group('Paint smoke — full matrix including helix', () {
    testWidgets('every stage × branch × mood paints with helix enabled', (
      tester,
    ) async {
      for (final stage in PetStage.values) {
        for (final branch in PetBranch.values) {
          for (final mood in PetMood.values) {
            final widget = MediaQuery(
              data: const MediaQueryData(),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Center(
                  child: PetCreature(
                    dnaSeed: _seedWithHelix | 0xDEAD,
                    stage: stage,
                    branch: branch,
                    mood: mood,
                    isAsleep: false,
                    isSick: false,
                    isCalling: false,
                    hygieneArtefactCount: 0,
                    size: 220,
                    mode: PetRenderMode.home,
                  ),
                ),
              ),
            );
            await tester.pumpWidget(widget);
            await tester.pump(const Duration(milliseconds: 16));
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'stage=${stage.name} branch=${branch.name} '
                  'mood=${mood.name}',
            );
          }
        }
      }
    });

    testWidgets('tiny mode with helix-enabled seed paints safely', (
      tester,
    ) async {
      // Helix must be suppressed in tiny mode (the painter skips the
      // layer regardless of spec.enabled).
      final widget = MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: PetCreature(
              dnaSeed: _seedWithHelix,
              stage: PetStage.adult,
              branch: PetBranch.luminous,
              mood: PetMood.content,
              isAsleep: false,
              isSick: false,
              isCalling: false,
              hygieneArtefactCount: 0,
              size: 32,
              mode: PetRenderMode.tiny,
            ),
          ),
        ),
      );
      await tester.pumpWidget(widget);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    });
  });
}
