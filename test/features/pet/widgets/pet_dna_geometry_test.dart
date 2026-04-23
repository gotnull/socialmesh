// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests for the dedicated DNA Viewer geometry model.
//
// Invariants pinned:
//   - Determinism: same (seed, stage, branch) → identical geometry.
//   - Distinct seeds produce visibly distinct structures.
//   - Stage/branch influence presentation consistently.
//   - Geometry builds for every (stage, branch) combination without
//     throwing.
//   - Anchor list is bounded.
//   - Egg/dormant produce shorter vertical spans than adult/elder.
//   - Decoded-trait helper labels are stable.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/widgets/pet_dna_geometry.dart';

const int _seedA = 0xD9BAB777;
const int _seedB = 0x12345678;

void main() {
  group('PetDnaGeometry — determinism', () {
    test('same identity produces identical render key + structure', () {
      final a = PetDnaGeometry.forIdentity(
        dnaSeed: _seedA,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      final b = PetDnaGeometry.forIdentity(
        dnaSeed: _seedA,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      expect(a.renderKey, b.renderKey);
      expect(a.dnaSeed, b.dnaSeed);
      expect(a.radiusFactor, b.radiusFactor);
      expect(a.verticalSpanFactor, b.verticalSpanFactor);
      expect(a.twistCycles, b.twistCycles);
      expect(a.strandCount, b.strandCount);
      expect(a.anchors.length, b.anchors.length);
      for (var i = 0; i < a.anchors.length; i++) {
        expect(a.anchors[i].t, b.anchors[i].t);
        expect(a.anchors[i].angleA, b.anchors[i].angleA);
        expect(a.anchors[i].hasRung, b.anchors[i].hasRung);
        expect(a.anchors[i].hasRuneMarker, b.anchors[i].hasRuneMarker);
      }
      expect(a.coreGlyphAngles, b.coreGlyphAngles);
    });

    test('distinct seeds produce distinct render keys', () {
      final a = PetDnaGeometry.forIdentity(
        dnaSeed: _seedA,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      final b = PetDnaGeometry.forIdentity(
        dnaSeed: _seedB,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      expect(a.renderKey, isNot(b.renderKey));
    });

    test('distinct seeds typically produce visibly distinct structures', () {
      final a = PetDnaGeometry.forIdentity(
        dnaSeed: _seedA,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      final b = PetDnaGeometry.forIdentity(
        dnaSeed: _seedB,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      // At least one geometric property should differ.
      final distinct =
          a.radiusFactor != b.radiusFactor ||
          a.twistCycles != b.twistCycles ||
          a.anchors.first.angleA != b.anchors.first.angleA ||
          a.coreGlyphAngles.length != b.coreGlyphAngles.length ||
          a.decoded.symmetryVertexCount != b.decoded.symmetryVertexCount ||
          a.decoded.orbitalComplexity != b.decoded.orbitalComplexity;
      expect(distinct, isTrue);
    });
  });

  group('PetDnaGeometry — bounded complexity', () {
    test('anchors list is bounded at a small fixed count', () {
      for (var i = 0; i < 32; i++) {
        final g = PetDnaGeometry.forIdentity(
          dnaSeed: i * 0x85EBCA77,
          stage: PetStage.adult,
          branch: PetBranch.steady,
        );
        expect(g.anchors.length, lessThanOrEqualTo(32));
        expect(g.anchors.length, greaterThan(0));
      }
    });

    test('strandCount ∈ {1, 2, 3}', () {
      for (var i = 0; i < 64; i++) {
        final g = PetDnaGeometry.forIdentity(
          dnaSeed: i * 0xC2B2AE35,
          stage: PetStage.adult,
          branch: PetBranch.steady,
        );
        expect(g.strandCount, inInclusiveRange(1, 3));
      }
    });

    test('twistCycles is a small integer', () {
      final g = PetDnaGeometry.forIdentity(
        dnaSeed: _seedA,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      expect(g.twistCycles, isA<int>());
      expect(g.twistCycles, greaterThanOrEqualTo(1));
      expect(g.twistCycles, lessThanOrEqualTo(5));
    });
  });

  group('PetDnaGeometry — stage / branch influence', () {
    test('egg stage has the shortest vertical span', () {
      final egg = PetDnaGeometry.forIdentity(
        dnaSeed: _seedA,
        stage: PetStage.egg,
        branch: PetBranch.unborn,
      );
      final adult = PetDnaGeometry.forIdentity(
        dnaSeed: _seedA,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      expect(egg.verticalSpanFactor, lessThan(adult.verticalSpanFactor));
    });

    test('elder has a longer span than adult (ceremonial extension)', () {
      final elder = PetDnaGeometry.forIdentity(
        dnaSeed: _seedA,
        stage: PetStage.elder,
        branch: PetBranch.steady,
      );
      final adult = PetDnaGeometry.forIdentity(
        dnaSeed: _seedA,
        stage: PetStage.adult,
        branch: PetBranch.steady,
      );
      expect(elder.verticalSpanFactor, greaterThan(adult.verticalSpanFactor));
    });

    test('dimmed branch has a smaller helix radius than luminous', () {
      final luminous = PetDnaGeometry.forIdentity(
        dnaSeed: _seedA,
        stage: PetStage.adult,
        branch: PetBranch.luminous,
      );
      final dimmed = PetDnaGeometry.forIdentity(
        dnaSeed: _seedA,
        stage: PetStage.adult,
        branch: PetBranch.dimmed,
      );
      expect(dimmed.radiusFactor, lessThan(luminous.radiusFactor));
    });
  });

  group('PetDnaGeometry — full matrix smoke', () {
    test('builds without errors across all stage × branch pairs', () {
      for (final stage in PetStage.values) {
        for (final branch in PetBranch.values) {
          expect(
            () => PetDnaGeometry.forIdentity(
              dnaSeed: 0xABCD_1234 ^ stage.index * 7 ^ branch.index * 31,
              stage: stage,
              branch: branch,
            ),
            returnsNormally,
            reason: '${stage.name} · ${branch.name}',
          );
        }
      }
    });
  });

  group('Decoded trait labels', () {
    test('symmetry class label covers 5–8 vertex polygons', () {
      expect(petDnaSymmetryClassLabel(5), 'Pentagonal');
      expect(petDnaSymmetryClassLabel(6), 'Hexagonal');
      expect(petDnaSymmetryClassLabel(7), 'Heptagonal');
      expect(petDnaSymmetryClassLabel(8), 'Octagonal');
    });

    test('strand-config label covers 1–3 strands', () {
      expect(petDnaStrandConfigLabel(1), 'Monad');
      expect(petDnaStrandConfigLabel(2), 'Dyad');
      expect(petDnaStrandConfigLabel(3), 'Triad');
    });
  });
}
