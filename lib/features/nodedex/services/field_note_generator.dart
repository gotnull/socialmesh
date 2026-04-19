// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Field Note Generator — deterministic single-line observations.
//
// Generates a short, evocative field-journal-style note for a node
// based on its identity seed (nodeNum), primary trait, and history.
// The note is fully deterministic: the same inputs always produce
// the same note. No randomness, no network, no side effects.
//
// Notes read like entries in a naturalist's field journal:
//   "First logged at dusk. Signal steady, bearing north."
//   "Intermittent presence. Appears without pattern."
//   "Fixed installation. Consistent signal for 14 days."
//
// The generator uses the node number hash to select from template
// families, then fills in concrete values from the entry data.
// This ensures visual variety across nodes while maintaining
// determinism within each node's identity.

import 'package:socialmesh/l10n/app_localizations.dart';

import '../models/nodedex_entry.dart';
import 'sigil_generator.dart';

/// Deterministic field note generator for NodeDex entries.
///
/// All methods are static, pure, and side-effect-free.
/// The same inputs always produce the same output.
class FieldNoteGenerator {
  FieldNoteGenerator._();

  /// Number of templates available per trait.
  static const int _templatesPerTrait = 8;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generate a deterministic field note for a node.
  ///
  /// The note is a single line of text suitable for display in the
  /// NodeDex detail header. It reads like a field journal observation.
  ///
  /// [entry] — the NodeDex entry with encounter history.
  /// [trait] — the primary inferred trait for template selection.
  /// [l10n] — localization strings for the current locale.
  ///
  /// Returns a non-empty string. Always deterministic.
  static String generate({
    required NodeDexEntry entry,
    required NodeTrait trait,
    required AppLocalizations l10n,
  }) {
    // Use the sigil hash to deterministically pick a template index.
    // This ensures the same node always gets the same template.
    final hash = SigilGenerator.mix(entry.nodeNum);
    final templateIndex = _extractBits(hash, 0, 16) % _templatesPerTrait;

    return _noteForTrait(trait, templateIndex, l10n, entry);
  }

  // ---------------------------------------------------------------------------
  // Per-trait localized note selection
  // ---------------------------------------------------------------------------

  static String _noteForTrait(
    NodeTrait trait,
    int index,
    AppLocalizations l10n,
    NodeDexEntry entry,
  ) {
    return switch (trait) {
      NodeTrait.wanderer => _wandererNote(index, l10n, entry),
      NodeTrait.beacon => _beaconNote(index, l10n, entry),
      NodeTrait.ghost => _ghostNote(index, l10n, entry),
      NodeTrait.sentinel => _sentinelNote(index, l10n, entry),
      NodeTrait.relay => _relayNote(index, l10n, entry),
      NodeTrait.courier => _courierNote(index, l10n, entry),
      NodeTrait.anchor => _anchorNote(index, l10n, entry),
      NodeTrait.drifter => _drifterNote(index, l10n, entry),
      NodeTrait.unknown => _unknownNote(index, l10n, entry),
    };
  }

  static String _wandererNote(
    int index,
    AppLocalizations l10n,
    NodeDexEntry entry,
  ) {
    return switch (index) {
      0 => l10n.nodedexFieldNoteWanderer0(entry.regionCount),
      1 => l10n.nodedexFieldNoteWanderer1(entry.distinctPositionCount),
      2 => l10n.nodedexFieldNoteWanderer2(entry.regionCount),
      3 => l10n.nodedexFieldNoteWanderer3(
        _formatDistance(entry.maxDistanceSeen, l10n),
      ),
      4 => l10n.nodedexFieldNoteWanderer4,
      5 => l10n.nodedexFieldNoteWanderer5(entry.regionCount),
      6 => l10n.nodedexFieldNoteWanderer6(entry.distinctPositionCount),
      7 => l10n.nodedexFieldNoteWanderer7,
      _ => l10n.nodedexFieldNoteWanderer0(entry.regionCount),
    };
  }

  static String _beaconNote(
    int index,
    AppLocalizations l10n,
    NodeDexEntry entry,
  ) {
    final rate = _computeRate(entry);
    return switch (index) {
      0 => l10n.nodedexFieldNoteBeacon0(rate),
      1 => l10n.nodedexFieldNoteBeacon1,
      2 => l10n.nodedexFieldNoteBeacon2(
        _formatRelativeTime(entry.timeSinceLastSeen, l10n),
      ),
      3 => l10n.nodedexFieldNoteBeacon3(entry.encounterCount),
      4 => l10n.nodedexFieldNoteBeacon4,
      5 => l10n.nodedexFieldNoteBeacon5,
      6 => l10n.nodedexFieldNoteBeacon6(rate),
      7 => l10n.nodedexFieldNoteBeacon7,
      _ => l10n.nodedexFieldNoteBeacon0(rate),
    };
  }

  static String _ghostNote(
    int index,
    AppLocalizations l10n,
    NodeDexEntry entry,
  ) {
    return switch (index) {
      0 => l10n.nodedexFieldNoteGhost0(
        _formatRelativeTime(entry.timeSinceLastSeen, l10n),
      ),
      1 => l10n.nodedexFieldNoteGhost1(entry.encounterCount, entry.age.inDays),
      2 => l10n.nodedexFieldNoteGhost2,
      3 => l10n.nodedexFieldNoteGhost3,
      4 => l10n.nodedexFieldNoteGhost4,
      5 => l10n.nodedexFieldNoteGhost5,
      6 => l10n.nodedexFieldNoteGhost6,
      7 => l10n.nodedexFieldNoteGhost7,
      _ => l10n.nodedexFieldNoteGhost0(
        _formatRelativeTime(entry.timeSinceLastSeen, l10n),
      ),
    };
  }

  static String _sentinelNote(
    int index,
    AppLocalizations l10n,
    NodeDexEntry entry,
  ) {
    return switch (index) {
      0 => l10n.nodedexFieldNoteSentinel0(entry.age.inDays),
      1 => l10n.nodedexFieldNoteSentinel1,
      2 => l10n.nodedexFieldNoteSentinel2(entry.encounterCount),
      3 => l10n.nodedexFieldNoteSentinel3(_formatDate(entry.firstSeen)),
      4 => l10n.nodedexFieldNoteSentinel4,
      5 => l10n.nodedexFieldNoteSentinel5,
      6 => l10n.nodedexFieldNoteSentinel6(entry.bestSnr?.round() ?? 0),
      7 => l10n.nodedexFieldNoteSentinel7(entry.age.inDays),
      _ => l10n.nodedexFieldNoteSentinel0(entry.age.inDays),
    };
  }

  static String _relayNote(
    int index,
    AppLocalizations l10n,
    NodeDexEntry entry,
  ) {
    return switch (index) {
      0 => l10n.nodedexFieldNoteRelay0,
      1 => l10n.nodedexFieldNoteRelay1,
      2 => l10n.nodedexFieldNoteRelay2,
      3 => l10n.nodedexFieldNoteRelay3,
      4 => l10n.nodedexFieldNoteRelay4,
      5 => l10n.nodedexFieldNoteRelay5(entry.encounterCount),
      6 => l10n.nodedexFieldNoteRelay6,
      7 => l10n.nodedexFieldNoteRelay7,
      _ => l10n.nodedexFieldNoteRelay0,
    };
  }

  static String _courierNote(
    int index,
    AppLocalizations l10n,
    NodeDexEntry entry,
  ) {
    return switch (index) {
      0 => l10n.nodedexFieldNoteCourier0(
        entry.messageCount,
        entry.encounterCount,
      ),
      1 => l10n.nodedexFieldNoteCourier1,
      2 => l10n.nodedexFieldNoteCourier2,
      3 => l10n.nodedexFieldNoteCourier3(entry.messageCount),
      4 => l10n.nodedexFieldNoteCourier4,
      5 => l10n.nodedexFieldNoteCourier5(entry.messageCount),
      6 => l10n.nodedexFieldNoteCourier6,
      7 => l10n.nodedexFieldNoteCourier7,
      _ => l10n.nodedexFieldNoteCourier0(
        entry.messageCount,
        entry.encounterCount,
      ),
    };
  }

  static String _anchorNote(
    int index,
    AppLocalizations l10n,
    NodeDexEntry entry,
  ) {
    return switch (index) {
      0 => l10n.nodedexFieldNoteAnchor0(entry.historicalCoSeenCount),
      1 => l10n.nodedexFieldNoteAnchor1,
      2 => l10n.nodedexFieldNoteAnchor2(entry.historicalCoSeenCount),
      3 => l10n.nodedexFieldNoteAnchor3,
      4 => l10n.nodedexFieldNoteAnchor4,
      5 => l10n.nodedexFieldNoteAnchor5,
      6 => l10n.nodedexFieldNoteAnchor6(entry.historicalCoSeenCount),
      7 => l10n.nodedexFieldNoteAnchor7,
      _ => l10n.nodedexFieldNoteAnchor0(entry.historicalCoSeenCount),
    };
  }

  static String _drifterNote(
    int index,
    AppLocalizations l10n,
    NodeDexEntry entry,
  ) {
    return switch (index) {
      0 => l10n.nodedexFieldNoteDrifter0,
      1 => l10n.nodedexFieldNoteDrifter1,
      2 => l10n.nodedexFieldNoteDrifter2,
      3 => l10n.nodedexFieldNoteDrifter3,
      4 => l10n.nodedexFieldNoteDrifter4,
      5 => l10n.nodedexFieldNoteDrifter5,
      6 => l10n.nodedexFieldNoteDrifter6,
      7 => l10n.nodedexFieldNoteDrifter7,
      _ => l10n.nodedexFieldNoteDrifter0,
    };
  }

  static String _unknownNote(
    int index,
    AppLocalizations l10n,
    NodeDexEntry entry,
  ) {
    return switch (index) {
      0 => l10n.nodedexFieldNoteUnknown0,
      1 => l10n.nodedexFieldNoteUnknown1,
      2 => l10n.nodedexFieldNoteUnknown2(_formatDate(entry.firstSeen)),
      3 => l10n.nodedexFieldNoteUnknown3,
      4 => l10n.nodedexFieldNoteUnknown4,
      5 => l10n.nodedexFieldNoteUnknown5,
      6 => l10n.nodedexFieldNoteUnknown6,
      7 => l10n.nodedexFieldNoteUnknown7,
      _ => l10n.nodedexFieldNoteUnknown0,
    };
  }

  // ---------------------------------------------------------------------------
  // Value computation helpers
  // ---------------------------------------------------------------------------

  static String _computeRate(NodeDexEntry entry) {
    final ageDays = entry.age.inHours / 24.0;
    return ageDays > 0.01
        ? (entry.encounterCount / ageDays).toStringAsFixed(1)
        : entry.encounterCount.toString();
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  static String _formatDistance(double? meters, AppLocalizations l10n) {
    if (meters == null) return l10n.nodedexDistanceUnknown;
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '${meters.round()}m';
  }

  static String _formatRelativeTime(Duration duration, AppLocalizations l10n) {
    if (duration.inMinutes < 1) return l10n.nodedexRelativeTimeMomentsAgo;
    if (duration.inMinutes < 60) {
      return l10n.nodedexRelativeTimeMinutesAgo(duration.inMinutes);
    }
    if (duration.inHours < 24) {
      return l10n.nodedexRelativeTimeHoursAgo(duration.inHours);
    }
    if (duration.inDays == 1) return l10n.nodedexRelativeTimeYesterday;
    if (duration.inDays < 30) {
      return l10n.nodedexRelativeTimeDaysAgo(duration.inDays);
    }
    final months = duration.inDays ~/ 30;
    if (months == 1) return l10n.nodedexRelativeTimeOneMonthAgo;
    return l10n.nodedexRelativeTimeMonthsAgo(months);
  }

  static String _formatDate(DateTime date) {
    // Produce a compact date like "12 Mar" or "5 Jan 2024"
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final now = DateTime.now();
    final month = months[date.month - 1];
    if (date.year == now.year) {
      return '${date.day} $month';
    }
    return '${date.day} $month ${date.year}';
  }

  // ---------------------------------------------------------------------------
  // Hash utilities (mirrors SigilGenerator for consistency)
  // ---------------------------------------------------------------------------

  static int _extractBits(int hash, int offset, int count) {
    return (hash >> offset) & ((1 << count) - 1);
  }
}
