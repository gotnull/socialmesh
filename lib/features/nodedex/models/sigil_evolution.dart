// SPDX-License-Identifier: GPL-3.0-or-later

// Sigil Evolution — deterministic visual maturity derived from patina score.
//
// The sigil evolution system adds subtle visual depth to a node's sigil
// based on how much observable history it has accumulated. It does NOT
// create a second scoring system — it derives everything from the
// existing patinaScore (0–100).
//
// Stages:
//   seed       (0–19)   — freshly discovered, minimal detail
//   marked     (20–39)  — starting to accumulate history
//   inscribed  (40–59)  — moderate history, recognizable presence
//   heraldic   (60–79)  — rich history, distinctive character
//   legacy     (80–100) — deeply documented, maximum detail
//
// Visual effects are intentionally subtle:
//   - lineWeightScale: 1.00 → 1.20 (barely perceptible thickening)
//   - toneScale: 1.00 → 1.12 (slight color deepening)
//   - detailTier: 0–4 (controls micro-etch density inside the sigil)
//   - augments: tiny optional marks derived from existing trait data
//
// All methods are pure functions. No state, no side effects, no async.

import 'nodedex_entry.dart';

/// The five maturity stages of a sigil's visual evolution.
///
/// Each stage maps to a patina score range and controls how much
/// visual detail the sigil renderer adds to the base geometry.
enum SigilStage {
  /// 0–19: Just discovered, base sigil only.
  seed,

  /// 20–39: Starting to show history.
  marked,

  /// 40–59: Moderate history, inner detail emerges.
  inscribed,

  /// 60–79: Rich history, full inner detail.
  heraldic,

  /// 80–100: Deeply documented, maximum visual maturity.
  legacy;

  /// Human-readable label for display purposes.
  String get displayLabel {
    return switch (this) {
      SigilStage.seed => 'Seed',
      SigilStage.marked => 'Marked',
      SigilStage.inscribed => 'Inscribed',
      SigilStage.heraldic => 'Heraldic',
      SigilStage.legacy => 'Legacy',
    };
  }
}

/// Tiny optional augment marks that can appear on evolved sigils.
///
/// Augments are derived from existing trait data — no new data
/// collection is performed. They appear as very small marks near
/// the sigil's outer ring and are only visible at higher stages.
enum SigilAugment {
  /// Small directional tick — node has relay/router behavior.
  relayMark,

  /// Tiny arc segment — node is a wanderer across regions.
  wandererMark,

  /// Faint hollow dot — node is a ghost (rarely seen).
  ghostMark,
}

/// Immutable snapshot of a sigil's visual evolution state.
///
/// Created via [SigilEvolution.fromPatina], which is a pure function
/// that deterministically maps a patina score to visual parameters.
/// The renderer uses these values to add subtle depth to the base
/// sigil geometry without changing its identity.
class SigilEvolution {
  /// The current maturity stage.
  final SigilStage stage;

  /// The patina score this evolution was derived from (0–100).
  final int patinaScore;

  /// Detail tier (0–4), mirrors stage index.
  /// Controls micro-etch density inside the sigil.
  final int detailTier;

  /// Stroke width multiplier (1.00–1.20).
  /// Applied to all sigil edge widths.
  final double lineWeightScale;

  /// Color intensity multiplier (1.00–1.12).
  /// Applied to sigil color alpha channels.
  final double toneScale;

  /// Optional tiny augment marks derived from trait data.
  /// Empty list means no augments are rendered.
  final List<SigilAugment> augments;

  const SigilEvolution({
    required this.stage,
    required this.patinaScore,
    required this.detailTier,
    required this.lineWeightScale,
    required this.toneScale,
    this.augments = const [],
  });

  // ---------------------------------------------------------------------------
  // Factory
  // ---------------------------------------------------------------------------

  /// Create a SigilEvolution from a patina score and optional trait.
  ///
  /// This is a pure function: the same inputs always produce the same
  /// output. The [patinaScore] must be 0–100 (clamped if out of range).
  /// The optional [trait] is used only to derive augment marks — it
  /// does not affect the stage, detail tier, or scaling values.
  ///
  /// ```dart
  /// final evo = SigilEvolution.fromPatina(62, trait: NodeTrait.wanderer);
  /// // evo.stage == SigilStage.heraldic
  /// // evo.detailTier == 3
  /// // evo.lineWeightScale == 1.15
  /// // evo.toneScale ~= 1.09
  /// // evo.augments == [SigilAugment.wandererMark]
  /// ```
  static SigilEvolution fromPatina(int patinaScore, {NodeTrait? trait}) {
    final clamped = patinaScore.clamp(0, 100);
    final stage = _stageFor(clamped);
    final tier = stage.index; // 0..4

    return SigilEvolution(
      stage: stage,
      patinaScore: clamped,
      detailTier: tier,
      lineWeightScale: _lineWeightScales[tier],
      toneScale: _toneScales[tier],
      augments: _augmentsFor(trait, stage),
    );
  }

  // ---------------------------------------------------------------------------
  // Stage thresholds
  // ---------------------------------------------------------------------------

  /// Map a patina score to its corresponding stage.
  static SigilStage _stageFor(int score) {
    if (score >= 80) return SigilStage.legacy;
    if (score >= 60) return SigilStage.heraldic;
    if (score >= 40) return SigilStage.inscribed;
    if (score >= 20) return SigilStage.marked;
    return SigilStage.seed;
  }

  // ---------------------------------------------------------------------------
  // Per-tier visual parameters
  // ---------------------------------------------------------------------------

  /// Line weight scale per detail tier (index 0–4).
  /// Very subtle progression: 1.00 → 1.05 → 1.10 → 1.15 → 1.20.
  static const List<double> _lineWeightScales = [
    1.00, // seed
    1.05, // marked
    1.10, // inscribed
    1.15, // heraldic
    1.20, // legacy
  ];

  /// Tone (color intensity) scale per detail tier (index 0–4).
  /// Very subtle progression: 1.00 → 1.03 → 1.06 → 1.09 → 1.12.
  static const List<double> _toneScales = [
    1.00, // seed
    1.03, // marked
    1.06, // inscribed
    1.09, // heraldic
    1.12, // legacy
  ];

  // ---------------------------------------------------------------------------
  // Augments
  // ---------------------------------------------------------------------------

  /// Derive augment marks from trait data.
  ///
  /// Augments are only added at inscribed stage or higher (tier >= 2)
  /// to keep early-stage sigils clean. Only one augment per sigil.
  static List<SigilAugment> _augmentsFor(NodeTrait? trait, SigilStage stage) {
    // No augments below inscribed stage.
    if (stage.index < SigilStage.inscribed.index) return const [];
    if (trait == null) return const [];

    return switch (trait) {
      NodeTrait.relay => const [SigilAugment.relayMark],
      NodeTrait.wanderer => const [SigilAugment.wandererMark],
      NodeTrait.ghost => const [SigilAugment.ghostMark],
      // Other traits do not have augment marks.
      _ => const [],
    };
  }

  // ---------------------------------------------------------------------------
  // Equality and debug
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SigilEvolution) return false;
    return stage == other.stage &&
        patinaScore == other.patinaScore &&
        detailTier == other.detailTier &&
        lineWeightScale == other.lineWeightScale &&
        toneScale == other.toneScale &&
        _listEquals(augments, other.augments);
  }

  @override
  int get hashCode => Object.hash(
    stage,
    patinaScore,
    detailTier,
    lineWeightScale,
    toneScale,
    Object.hashAll(augments),
  );

  @override
  String toString() =>
      'SigilEvolution(${stage.displayLabel}, patina: $patinaScore, '
      'tier: $detailTier, weight: $lineWeightScale, tone: $toneScale'
      '${augments.isNotEmpty ? ', augments: $augments' : ''})';

  /// Shallow list equality without importing foundation.
  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
