// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/pet_base_allele.dart';

void main() {
  group('PetBaseAllele — codes & complement pairing', () {
    test('single-letter codes are A/T/G/C in enum order', () {
      expect(PetBaseAllele.aurora.code, 'A');
      expect(PetBaseAllele.tether.code, 'T');
      expect(PetBaseAllele.gale.code, 'G');
      expect(PetBaseAllele.calm.code, 'C');
    });

    test('complement pairing is A↔T, G↔C and self-inverse', () {
      expect(PetBaseAllele.aurora.complement, PetBaseAllele.tether);
      expect(PetBaseAllele.tether.complement, PetBaseAllele.aurora);
      expect(PetBaseAllele.gale.complement, PetBaseAllele.calm);
      expect(PetBaseAllele.calm.complement, PetBaseAllele.gale);
      for (final a in PetBaseAllele.values) {
        expect(a.complement.complement, a, reason: 'involution: ${a.name}');
      }
    });

    test('archetype colors are distinct across all four alleles', () {
      final seen = <int>{};
      for (final a in PetBaseAllele.values) {
        final color = a.archetypeColor.toARGB32();
        expect(seen.add(color), isTrue, reason: 'duplicate color on ${a.code}');
      }
    });
  });

  group('alleleFromIndex', () {
    test('maps 0..3 to aurora/tether/gale/calm', () {
      expect(alleleFromIndex(0), PetBaseAllele.aurora);
      expect(alleleFromIndex(1), PetBaseAllele.tether);
      expect(alleleFromIndex(2), PetBaseAllele.gale);
      expect(alleleFromIndex(3), PetBaseAllele.calm);
    });

    test('masks to the lowest two bits (higher bits ignored)', () {
      expect(alleleFromIndex(4), PetBaseAllele.aurora);
      expect(alleleFromIndex(0xFF), PetBaseAllele.calm);
    });
  });

  group('deriveAlleleSequence', () {
    test('is deterministic — same seed produces same sequence', () {
      final a = deriveAlleleSequence(0x8FDDC077);
      final b = deriveAlleleSequence(0x8FDDC077);
      expect(a, equals(b));
    });

    test('distinct seeds produce distinct sequences', () {
      final a = deriveAlleleSequence(0x8FDDC077);
      final b = deriveAlleleSequence(0x8FDDC078);
      expect(a, isNot(equals(b)));
    });

    test('default length is 32', () {
      expect(deriveAlleleSequence(0xDEADBEEF).length, 32);
    });

    test('respects the length parameter', () {
      expect(deriveAlleleSequence(0xDEADBEEF, length: 8).length, 8);
      expect(deriveAlleleSequence(0xDEADBEEF, length: 64).length, 64);
    });

    test('covers multiple alleles for non-degenerate seeds', () {
      // A random seed should produce at least 3 distinct alleles in a
      // 32-base sequence. This guards against a bit-packing bug that
      // would collapse the sequence to one or two alleles.
      final s = deriveAlleleSequence(0x12345678);
      final distinct = s.toSet();
      expect(distinct.length, greaterThanOrEqualTo(3));
    });
  });

  group('PetAlleleDistribution', () {
    test('counts match the sequence', () {
      final seq = [
        PetBaseAllele.aurora,
        PetBaseAllele.aurora,
        PetBaseAllele.tether,
        PetBaseAllele.gale,
      ];
      final d = PetAlleleDistribution.from(seq);
      expect(d.aurora, 2);
      expect(d.tether, 1);
      expect(d.gale, 1);
      expect(d.calm, 0);
      expect(d.total, 4);
    });

    test('ratio is count / total', () {
      final seq = [
        PetBaseAllele.aurora,
        PetBaseAllele.aurora,
        PetBaseAllele.tether,
        PetBaseAllele.gale,
      ];
      final d = PetAlleleDistribution.from(seq);
      expect(d.ratio(PetBaseAllele.aurora), closeTo(0.5, 1e-9));
      expect(d.ratio(PetBaseAllele.tether), closeTo(0.25, 1e-9));
      expect(d.ratio(PetBaseAllele.calm), 0.0);
    });

    test('empty distribution ratio is 0 (no div by zero)', () {
      const d = PetAlleleDistribution(aurora: 0, tether: 0, gale: 0, calm: 0);
      expect(d.ratio(PetBaseAllele.aurora), 0.0);
    });

    test('dominant returns the majority allele', () {
      final seq = [
        PetBaseAllele.aurora,
        PetBaseAllele.gale,
        PetBaseAllele.gale,
        PetBaseAllele.gale,
      ];
      expect(PetAlleleDistribution.from(seq).dominant, PetBaseAllele.gale);
    });

    test('dominant ties break by enum ordinal', () {
      // Aurora (0) and Tether (1) tied — aurora wins by earlier ordinal.
      final seq = [PetBaseAllele.aurora, PetBaseAllele.tether];
      expect(PetAlleleDistribution.from(seq).dominant, PetBaseAllele.aurora);
    });
  });
}
