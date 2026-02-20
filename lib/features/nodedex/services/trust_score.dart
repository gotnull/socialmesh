// SPDX-License-Identifier: GPL-3.0-or-later

// Trust Score — computed trust indicator from observable node behavior.
//
// Trust is NOT user-assigned (that is socialTag). Trust is always
// derived from real metrics: encounter frequency, node age, direct
// messaging, relay usefulness, and network recency. The score
// places every node on a five-level scale from Unknown to Established.
//
// The engine runs pure functions with no side effects. The same
// NodeDexEntry (and optional role) always produces the same result.
//
// Signals and weights:
//   1. Frequently Seen (25%) — encounter count (logarithmic)
//   2. Long-lived      (25%) — age since first seen (asymptotic)
//   3. Direct Contact  (20%) — message count (logarithmic)
//   4. Relay Usefulness(15%) — router role + encounter threshold
//   5. Network Presence(15%) — recency of last seen (decay curve)
//
// Trust levels:
//   Unknown     — score < 0.15 (almost no data)
//   Observed    — 0.15 to < 0.35
//   Familiar    — 0.35 to < 0.55
//   Trusted     — 0.55 to < 0.75
//   Established — 0.75+

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/nodedex_entry.dart';

/// Discrete trust classification derived from computed score.
enum TrustLevel {
  /// Almost no data — recently discovered or insufficient history.
  unknown,

  /// Some encounters, beginning to accumulate history.
  observed,

  /// Regular presence, moderate encounter history.
  familiar,

  /// Frequent, long-lived, with direct contact evidence.
  trusted,

  /// Deeply documented, high across all trust dimensions.
  established;

  /// Human-readable label for UI display.
  String get displayLabel {
    return switch (this) {
      TrustLevel.unknown => 'Unknown',
      TrustLevel.observed => 'Observed',
      TrustLevel.familiar => 'Familiar',
      TrustLevel.trusted => 'Trusted',
      TrustLevel.established => 'Established',
    };
  }

  /// Short description explaining this trust level.
  String get description {
    return switch (this) {
      TrustLevel.unknown => 'Not enough data to assess',
      TrustLevel.observed => 'Seen a few times on the mesh',
      TrustLevel.familiar => 'Regular presence with some history',
      TrustLevel.trusted => 'Frequent, long-lived, communicative',
      TrustLevel.established => 'Deep history across all dimensions',
    };
  }

  /// Accent color for the trust indicator dot.
  Color get color {
    return switch (this) {
      TrustLevel.unknown => const Color(0xFF6B7280), // gray-500
      TrustLevel.observed => const Color(0xFF94A3B8), // slate-400
      TrustLevel.familiar => const Color(0xFF38BDF8), // sky-400
      TrustLevel.trusted => const Color(0xFF4ADE80), // green-400
      TrustLevel.established => const Color(0xFFFBBF24), // amber-400
    };
  }

  /// Icon associated with this trust level.
  IconData get icon {
    return switch (this) {
      TrustLevel.unknown => Icons.help_outline_rounded,
      TrustLevel.observed => Icons.visibility_outlined,
      TrustLevel.familiar => Icons.handshake_outlined,
      TrustLevel.trusted => Icons.verified_outlined,
      TrustLevel.established => Icons.workspace_premium_outlined,
    };
  }
}

/// Result of a trust score computation.
///
/// Contains the overall score, the derived trust level, and
/// per-signal breakdowns for optional display.
class TrustResult {
  /// Overall trust score, 0.0 to 1.0.
  final double score;

  /// Derived trust level from the score.
  final TrustLevel level;

  /// Per-signal scores, each 0.0 to 1.0.
  final double frequentlySeen;
  final double longLived;
  final double directContact;
  final double relayUsefulness;
  final double networkPresence;

  const TrustResult({
    required this.score,
    required this.level,
    required this.frequentlySeen,
    required this.longLived,
    required this.directContact,
    required this.relayUsefulness,
    required this.networkPresence,
  });

  @override
  String toString() =>
      'TrustResult(${level.displayLabel}: '
      '${(score * 100).toStringAsFixed(0)}%)';
}

/// Pure-function engine that computes a trust score from node history.
///
/// All methods are static. No state, no side effects, no async.
/// The same inputs always produce the same [TrustResult].
class TrustScore {
  TrustScore._();

  // ---------------------------------------------------------------------------
  // Signal weights — must sum to 1.0
  // ---------------------------------------------------------------------------

  static const double _wFrequentlySeen = 0.25;
  static const double _wLongLived = 0.25;
  static const double _wDirectContact = 0.20;
  static const double _wRelayUsefulness = 0.15;
  static const double _wNetworkPresence = 0.15;

  // ---------------------------------------------------------------------------
  // Level thresholds
  // ---------------------------------------------------------------------------

  static const double _thresholdObserved = 0.15;
  static const double _thresholdFamiliar = 0.35;
  static const double _thresholdTrusted = 0.55;
  static const double _thresholdEstablished = 0.75;

  // ---------------------------------------------------------------------------
  // Curve constants — tuned for real-world mesh node behavior
  // ---------------------------------------------------------------------------

  /// Encounter count at which the frequently-seen signal saturates (~90%).
  /// Using logarithmic curve: ln(1 + count) / ln(1 + 60).
  static const int _encounterSaturation = 60;

  /// Age in days at which the long-lived signal saturates (~95%).
  /// Using asymptotic curve: 1 - e^(-3 * days / 90).
  static const int _ageSaturationDays = 90;

  /// Message count at which the direct-contact signal saturates (~90%).
  /// Using logarithmic curve: ln(1 + count) / ln(1 + 30).
  static const int _messageSaturation = 30;

  /// Hours since last seen at which network-presence drops to near zero.
  /// Using decay curve: e^(-hours / 168) (one-week half-life).
  static const int _presenceDecayHours = 168;

  /// Relay roles that contribute to the relay usefulness signal.
  static const Set<String> _relayRoles = {
    'ROUTER',
    'ROUTER_CLIENT',
    'REPEATER',
    'ROUTER_LATE',
  };

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Compute the trust score for a node.
  ///
  /// The result is deterministic: the same [entry] and [role] always
  /// produce the same [TrustResult] given the same wall-clock time.
  /// For testing, use [computeAt] to pin the reference time.
  ///
  /// [role] is the live mesh role string (e.g., 'ROUTER'). If not
  /// available, falls back to [NodeDexEntry.lastKnownRole].
  static TrustResult compute(NodeDexEntry entry, {String? role}) {
    return computeAt(entry, DateTime.now(), role: role);
  }

  /// Compute trust score at a specific reference time.
  ///
  /// Useful for deterministic testing. In production, use [compute].
  ///
  /// Nodes with zero encounters always return [TrustLevel.unknown] —
  /// trust requires at least one observation event.
  static TrustResult computeAt(
    NodeDexEntry entry,
    DateTime now, {
    String? role,
  }) {
    // No encounters means no trust data at all.
    if (entry.encounterCount <= 0) {
      return const TrustResult(
        score: 0,
        level: TrustLevel.unknown,
        frequentlySeen: 0,
        longLived: 0,
        directContact: 0,
        relayUsefulness: 0,
        networkPresence: 0,
      );
    }

    final frequentlySeen = _scoreFrequentlySeen(entry.encounterCount);
    final longLived = _scoreLongLived(entry.firstSeen, now);
    final directContact = _scoreDirectContact(entry.messageCount);
    final relayUsefulness = _scoreRelayUsefulness(
      role ?? entry.lastKnownRole,
      entry.encounterCount,
    );
    final networkPresence = _scoreNetworkPresence(entry.lastSeen, now);

    final score =
        frequentlySeen * _wFrequentlySeen +
        longLived * _wLongLived +
        directContact * _wDirectContact +
        relayUsefulness * _wRelayUsefulness +
        networkPresence * _wNetworkPresence;

    final level = _levelFromScore(score);

    return TrustResult(
      score: score,
      level: level,
      frequentlySeen: frequentlySeen,
      longLived: longLived,
      directContact: directContact,
      relayUsefulness: relayUsefulness,
      networkPresence: networkPresence,
    );
  }

  // ---------------------------------------------------------------------------
  // Signal scoring functions — each returns 0.0 to 1.0
  // ---------------------------------------------------------------------------

  /// Logarithmic curve: rapid early gains, diminishing returns.
  /// ln(1 + count) / ln(1 + saturation).
  static double _scoreFrequentlySeen(int encounterCount) {
    if (encounterCount <= 0) return 0.0;
    return (math.log(1 + encounterCount) / math.log(1 + _encounterSaturation))
        .clamp(0.0, 1.0);
  }

  /// Asymptotic curve: 1 - e^(-3 * days / saturation).
  /// Reaches ~95% at saturation days.
  static double _scoreLongLived(DateTime firstSeen, DateTime now) {
    final days = now.difference(firstSeen).inHours / 24.0;
    if (days <= 0) return 0.0;
    return (1.0 - math.exp(-3.0 * days / _ageSaturationDays)).clamp(0.0, 1.0);
  }

  /// Logarithmic curve for message count.
  /// ln(1 + count) / ln(1 + saturation).
  static double _scoreDirectContact(int messageCount) {
    if (messageCount <= 0) return 0.0;
    return (math.log(1 + messageCount) / math.log(1 + _messageSaturation))
        .clamp(0.0, 1.0);
  }

  /// Binary relay role check + encounter volume bonus.
  ///
  /// A relay role alone gives 0.7. High encounter count adds up to 0.3.
  /// Without a relay role, returns 0.0 — this signal only fires for
  /// nodes that actually route traffic.
  static double _scoreRelayUsefulness(String? role, int encounterCount) {
    if (role == null || !_relayRoles.contains(role.toUpperCase())) {
      return 0.0;
    }
    // Base score for having a relay role.
    double score = 0.7;
    // Bonus for high encounter count (indicates active relay).
    if (encounterCount > 20) {
      score += 0.3 * ((encounterCount - 20) / 40.0).clamp(0.0, 1.0);
    }
    return score.clamp(0.0, 1.0);
  }

  /// Exponential decay based on hours since last seen.
  /// e^(-hours / decayConstant). Fresh = 1.0, one week = ~0.37.
  static double _scoreNetworkPresence(DateTime lastSeen, DateTime now) {
    final hours = now.difference(lastSeen).inMinutes / 60.0;
    if (hours <= 0) return 1.0;
    return math.exp(-hours / _presenceDecayHours).clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // Level derivation
  // ---------------------------------------------------------------------------

  static TrustLevel _levelFromScore(double score) {
    if (score >= _thresholdEstablished) return TrustLevel.established;
    if (score >= _thresholdTrusted) return TrustLevel.trusted;
    if (score >= _thresholdFamiliar) return TrustLevel.familiar;
    if (score >= _thresholdObserved) return TrustLevel.observed;
    return TrustLevel.unknown;
  }
}
