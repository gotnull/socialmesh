// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetBaseAllele — four DNA bases that also serve as NodePet "resonance
// alleles", tying each pet's helix sequence to the existing branch
// archetypes.
//
// Mapping:
//   Aurora  (A) ↔ Luminous branch (radiant, outward-reaching)
//   Tether  (T) ↔ Steady branch   (grounded, reliable)
//   Gale    (G) ↔ Volatile branch (sudden, energetic)
//   Calm    (C) ↔ Dimmed branch   (reserved, withdrawing)
//
// Complementary pairing (preserved from biological DNA):
//   A↔T  (Aurora ↔ Tether)   — extroverted-opposite pair
//   G↔C  (Gale ↔ Calm)       — activity-opposite pair
//
// Colors intentionally cross-branch: each allele wears its archetype's
// palette-primary hue regardless of the pet's own branch, so the helix
// always shows the full 4-color spectrum of NodePet resonances. This is
// the "DNA is universal, pets are specific" framing.

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// One of the four NodePet resonance alleles. Enum ordinal is the
/// persistent base index (0..3) used by seed-derived sequences — do
/// NOT reorder.
enum PetBaseAllele {
  aurora, // 0 — pairs with tether
  tether, // 1 — pairs with aurora
  gale, // 2 — pairs with calm
  calm, // 3 — pairs with gale
}

extension PetBaseAlleleX on PetBaseAllele {
  /// Single-letter code for ultra-compact displays. NOT a localizable
  /// string — it's a fixed DNA-notation symbol.
  String get code {
    switch (this) {
      case PetBaseAllele.aurora:
        return 'A';
      case PetBaseAllele.tether:
        return 'T';
      case PetBaseAllele.gale:
        return 'G';
      case PetBaseAllele.calm:
        return 'C';
    }
  }

  /// Archetype color for this allele — the dominant hue of the branch
  /// it corresponds to. Cross-branch by design: every pet's helix
  /// shows all 4 allele colors regardless of the pet's own branch.
  Color get archetypeColor {
    switch (this) {
      case PetBaseAllele.aurora:
        return AccentColors.yellow; // luminous
      case PetBaseAllele.tether:
        return AccentColors.emerald; // steady
      case PetBaseAllele.gale:
        return AccentColors.orange; // volatile
      case PetBaseAllele.calm:
        return AccentColors.lavender; // dimmed
    }
  }

  /// Complementary allele under the A↔T / G↔C pairing rule. Useful for
  /// per-sample rendering: a rung at sample i pairs strand0's allele
  /// with strand1's complement.
  PetBaseAllele get complement {
    switch (this) {
      case PetBaseAllele.aurora:
        return PetBaseAllele.tether;
      case PetBaseAllele.tether:
        return PetBaseAllele.aurora;
      case PetBaseAllele.gale:
        return PetBaseAllele.calm;
      case PetBaseAllele.calm:
        return PetBaseAllele.gale;
    }
  }
}

/// Resolve allele from a 2-bit seed window (ordinal 0..3).
PetBaseAllele alleleFromIndex(int index) => PetBaseAllele.values[index & 0x03];

/// Derive a [length]-step allele sequence deterministically from
/// [dnaSeed]. Stable across app launches, identical for the same seed.
/// Uses a rolling 2-bit window with a 7-bit stride to de-correlate the
/// sequence from local bit patterns — otherwise a low-entropy seed
/// would repeat every 16 samples.
List<PetBaseAllele> deriveAlleleSequence(int dnaSeed, {int length = 32}) {
  final out = List<PetBaseAllele>.filled(length, PetBaseAllele.aurora);
  var bits = dnaSeed;
  for (var i = 0; i < length; i++) {
    final shift = (i * 7) & 0x1F; // 0..31, coprime-ish with 32
    final idx = (bits >> shift) & 0x03;
    out[i] = alleleFromIndex(idx);
    // Lightly perturb bits so periodicity doesn't re-emerge at long
    // sequences. xorshift-like mix.
    bits ^= bits << 13;
    bits ^= (bits >> 17) & 0x7FFFFFFF;
    bits ^= bits << 5;
  }
  return out;
}

/// Distribution of alleles across a sequence. Each value is the count,
/// not the fraction — convert to `count/length` at the call site.
@immutable
class PetAlleleDistribution {
  final int aurora;
  final int tether;
  final int gale;
  final int calm;

  const PetAlleleDistribution({
    required this.aurora,
    required this.tether,
    required this.gale,
    required this.calm,
  });

  int get total => aurora + tether + gale + calm;

  int count(PetBaseAllele allele) {
    switch (allele) {
      case PetBaseAllele.aurora:
        return aurora;
      case PetBaseAllele.tether:
        return tether;
      case PetBaseAllele.gale:
        return gale;
      case PetBaseAllele.calm:
        return calm;
    }
  }

  double ratio(PetBaseAllele allele) {
    final t = total;
    return t == 0 ? 0.0 : count(allele) / t;
  }

  /// The most-represented allele. Ties broken by enum ordinal
  /// (aurora > tether > gale > calm) — deterministic given the same
  /// sequence, which matters for the "dominant allele" surfaced to
  /// the UI.
  PetBaseAllele get dominant {
    var best = PetBaseAllele.aurora;
    var bestCount = aurora;
    for (final a in [
      PetBaseAllele.tether,
      PetBaseAllele.gale,
      PetBaseAllele.calm,
    ]) {
      if (count(a) > bestCount) {
        best = a;
        bestCount = count(a);
      }
    }
    return best;
  }

  factory PetAlleleDistribution.from(List<PetBaseAllele> sequence) {
    var a = 0, t = 0, g = 0, c = 0;
    for (final base in sequence) {
      switch (base) {
        case PetBaseAllele.aurora:
          a++;
        case PetBaseAllele.tether:
          t++;
        case PetBaseAllele.gale:
          g++;
        case PetBaseAllele.calm:
          c++;
      }
    }
    return PetAlleleDistribution(aurora: a, tether: t, gale: g, calm: c);
  }
}
