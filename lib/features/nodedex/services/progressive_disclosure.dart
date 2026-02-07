// SPDX-License-Identifier: GPL-3.0-or-later

// Progressive Disclosure — threshold-based visibility for field journal elements.
//
// Controls what information is revealed about a node based on how
// much observable history has accumulated. New nodes start sparse:
// only a sigil and basic metadata. As encounters, time, and data
// accumulate, additional layers are progressively unlocked.
//
// This creates a sense of "earned knowledge" — patina is not
// decoration, it is the visible result of genuine observation.
//
// Disclosure tiers:
//   Tier 0 (Trace)    — Sigil + name + hex ID only
//   Tier 1 (Noted)    — Primary trait badge visible
//   Tier 2 (Logged)   — Trait evidence + field note visible
//   Tier 3 (Inked)    — Full trait list + patina stamp visible
//   Tier 4 (Etched)   — Identity overlay at full density
//
// All methods are pure functions. No state, no side effects.
// The same inputs always produce the same disclosure level.

import '../models/nodedex_entry.dart';

/// Disclosure tier controlling which field journal elements are visible.
///
/// Each tier gates a set of UI elements. Higher tiers include all
/// elements from lower tiers plus additional detail.
enum DisclosureTier {
  /// Minimal: sigil, name, hex ID. No traits, no field note.
  trace,

  /// Primary trait badge appears. No evidence or field note yet.
  noted,

  /// Trait evidence bullets and field note become visible.
  logged,

  /// Full trait list, patina stamp, and observation timeline visible.
  inked,

  /// Maximum detail. Identity overlay renders at full density.
  etched;

  /// Whether this tier is at least [other].
  bool isAtLeast(DisclosureTier other) => index >= other.index;
}

/// What is visible at a given disclosure tier.
///
/// Each boolean field controls a specific UI element in the NodeDex
/// detail screen and list tile. The UI reads these flags to decide
/// what to render, keeping disclosure logic out of widget code.
class DisclosureState {
  /// Always true — the sigil is always visible.
  final bool showSigil;

  /// Whether the primary trait badge is visible.
  final bool showPrimaryTrait;

  /// Whether trait evidence bullet points are visible.
  final bool showTraitEvidence;

  /// Whether the deterministic field note is visible.
  final bool showFieldNote;

  /// Whether the full ranked trait list is visible.
  final bool showAllTraits;

  /// Whether the patina stamp (score) is visible.
  final bool showPatinaStamp;

  /// Whether the observation timeline strip is visible.
  final bool showTimeline;

  /// Whether the identity overlay renders behind the header.
  final bool showOverlay;

  /// Overlay opacity multiplier (0.0 to 1.0).
  ///
  /// Even when [showOverlay] is true, the overlay starts faint
  /// and increases in density as the node accumulates more history.
  final double overlayDensity;

  /// The current disclosure tier.
  final DisclosureTier tier;

  const DisclosureState({
    required this.showSigil,
    required this.showPrimaryTrait,
    required this.showTraitEvidence,
    required this.showFieldNote,
    required this.showAllTraits,
    required this.showPatinaStamp,
    required this.showTimeline,
    required this.showOverlay,
    required this.overlayDensity,
    required this.tier,
  });

  @override
  String toString() =>
      'DisclosureState(${tier.name}, '
      'overlay: ${showOverlay ? '${(overlayDensity * 100).toStringAsFixed(0)}%' : 'off'})';
}

/// Pure-function engine that computes disclosure state from node data.
///
/// All methods are static. No state, no side effects, no async.
/// The same NodeDexEntry always produces the same DisclosureState.
class ProgressiveDisclosure {
  ProgressiveDisclosure._();

  // ---------------------------------------------------------------------------
  // Tier thresholds
  // ---------------------------------------------------------------------------

  /// Minimum encounters to unlock Tier 1 (trait badge).
  static const int _tier1MinEncounters = 2;

  /// Minimum age in hours to unlock Tier 1.
  static const int _tier1MinAgeHours = 1;

  /// Minimum encounters to unlock Tier 2 (evidence + field note).
  static const int _tier2MinEncounters = 5;

  /// Minimum age in days to unlock Tier 2.
  static const int _tier2MinAgeDays = 1;

  /// Minimum encounters to unlock Tier 3 (full traits + patina).
  static const int _tier3MinEncounters = 10;

  /// Minimum age in days to unlock Tier 3.
  static const int _tier3MinAgeDays = 3;

  /// Minimum encounters to unlock Tier 4 (full overlay density).
  static const int _tier4MinEncounters = 20;

  /// Minimum age in days to unlock Tier 4.
  static const int _tier4MinAgeDays = 7;

  // ---------------------------------------------------------------------------
  // Overlay density bounds
  // ---------------------------------------------------------------------------

  /// Minimum overlay opacity when overlay is first enabled (Tier 3).
  static const double _overlayMinDensity = 0.15;

  /// Maximum overlay opacity at Tier 4 with fully saturated history.
  static const double _overlayMaxDensity = 0.40;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Compute the disclosure state for a node.
  ///
  /// The result is deterministic: the same [entry] always produces
  /// the same state given the same wall-clock time. For testing,
  /// use [computeAt] to pin the reference time.
  static DisclosureState compute(NodeDexEntry entry) {
    return computeAt(entry, DateTime.now());
  }

  /// Compute disclosure state at a specific reference time.
  ///
  /// Useful for deterministic testing. In production, use [compute].
  static DisclosureState computeAt(NodeDexEntry entry, DateTime now) {
    final tier = _computeTier(entry, now);
    final density = _computeOverlayDensity(entry, now, tier);

    return DisclosureState(
      showSigil: true,
      showPrimaryTrait: tier.isAtLeast(DisclosureTier.noted),
      showTraitEvidence: tier.isAtLeast(DisclosureTier.logged),
      showFieldNote: tier.isAtLeast(DisclosureTier.logged),
      showAllTraits: tier.isAtLeast(DisclosureTier.inked),
      showPatinaStamp: tier.isAtLeast(DisclosureTier.inked),
      showTimeline: tier.isAtLeast(DisclosureTier.inked),
      showOverlay: tier.isAtLeast(DisclosureTier.inked),
      overlayDensity: density,
      tier: tier,
    );
  }

  /// Compute just the tier without the full state.
  ///
  /// Lightweight alternative when only the tier level is needed
  /// (e.g., for filtering or sorting).
  static DisclosureTier computeTier(NodeDexEntry entry) {
    return _computeTier(entry, DateTime.now());
  }

  // ---------------------------------------------------------------------------
  // Tier computation
  // ---------------------------------------------------------------------------

  static DisclosureTier _computeTier(NodeDexEntry entry, DateTime now) {
    final ageHours = now.difference(entry.firstSeen).inHours;
    final ageDays = ageHours ~/ 24;
    final encounters = entry.encounterCount;

    // Tier 4: Etched — deep history
    if (encounters >= _tier4MinEncounters && ageDays >= _tier4MinAgeDays) {
      return DisclosureTier.etched;
    }

    // Tier 3: Inked — substantial history
    if (encounters >= _tier3MinEncounters && ageDays >= _tier3MinAgeDays) {
      return DisclosureTier.inked;
    }

    // Tier 2: Logged — moderate history
    if (encounters >= _tier2MinEncounters && ageDays >= _tier2MinAgeDays) {
      return DisclosureTier.logged;
    }

    // Tier 1: Noted — minimal viable history
    if (encounters >= _tier1MinEncounters && ageHours >= _tier1MinAgeHours) {
      return DisclosureTier.noted;
    }

    // Tier 0: Trace — just discovered
    return DisclosureTier.trace;
  }

  // ---------------------------------------------------------------------------
  // Overlay density
  // ---------------------------------------------------------------------------

  /// Compute overlay density based on tier and data richness.
  ///
  /// The density ramps up smoothly from [_overlayMinDensity] at Tier 3
  /// to [_overlayMaxDensity] at Tier 4 with rich data. Density is
  /// influenced by encounter count, age, region count, and co-seen
  /// relationships.
  static double _computeOverlayDensity(
    NodeDexEntry entry,
    DateTime now,
    DisclosureTier tier,
  ) {
    if (!tier.isAtLeast(DisclosureTier.inked)) return 0.0;

    // Base density from tier
    final baseDensity = tier == DisclosureTier.etched
        ? _overlayMinDensity + (_overlayMaxDensity - _overlayMinDensity) * 0.5
        : _overlayMinDensity;

    // Bonus density from data richness (0.0 to remaining headroom)
    final headroom = _overlayMaxDensity - baseDensity;

    double richness = 0.0;

    // Encounter richness (log scale, saturates at ~60)
    if (entry.encounterCount > 0) {
      richness += 0.3 * _logScale(entry.encounterCount.toDouble(), 60.0);
    }

    // Age richness (saturates at ~90 days)
    final ageDays = now.difference(entry.firstSeen).inHours / 24.0;
    if (ageDays > 0) {
      richness += 0.25 * _logScale(ageDays, 90.0);
    }

    // Region richness
    if (entry.regionCount > 0) {
      richness += 0.2 * _logScale(entry.regionCount.toDouble(), 6.0);
    }

    // Co-seen richness
    if (entry.coSeenCount > 0) {
      richness += 0.25 * _logScale(entry.coSeenCount.toDouble(), 20.0);
    }

    final bonus = headroom * richness.clamp(0.0, 1.0);
    return (baseDensity + bonus).clamp(0.0, _overlayMaxDensity);
  }

  /// Logarithmic scaling: ln(1 + value) / ln(1 + saturation).
  ///
  /// Returns 0.0 to 1.0. Fast early growth, diminishing returns.
  static double _logScale(double value, double saturation) {
    if (value <= 0 || saturation <= 0) return 0.0;
    // Inline natural log approximation to avoid dart:math dependency.
    // Using the identity: ln(x) ≈ series expansion.
    // For the ratio, we can use the change-of-base approach.
    final numerator = _ln(1.0 + value);
    final denominator = _ln(1.0 + saturation);
    if (denominator <= 0) return 0.0;
    return (numerator / denominator).clamp(0.0, 1.0);
  }

  /// Natural logarithm approximation.
  ///
  /// Uses the identity ln(x) = 2 * atanh((x-1)/(x+1)) with
  /// a Taylor series for atanh. Accurate to ~0.1% for x > 0.5.
  static double _ln(double x) {
    if (x <= 0) return -1e10;
    if (x == 1.0) return 0.0;

    // Reduce to [0.5, 2.0] range using ln(a*2^n) = ln(a) + n*ln(2)
    int exponent = 0;
    double reduced = x;
    while (reduced > 2.0) {
      reduced /= 2.0;
      exponent++;
    }
    while (reduced < 0.5) {
      reduced *= 2.0;
      exponent--;
    }

    // atanh series: ln(x) = 2 * sum_{k=0}^{inf} (1/(2k+1)) * ((x-1)/(x+1))^(2k+1)
    final ratio = (reduced - 1.0) / (reduced + 1.0);
    final r2 = ratio * ratio;
    double term = ratio;
    double sum = term;
    for (int k = 1; k <= 10; k++) {
      term *= r2;
      sum += term / (2 * k + 1);
    }

    const ln2 = 0.6931471805599453;
    return 2.0 * sum + exponent * ln2;
  }
}
