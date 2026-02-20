// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

/// MIL-STD-2525 affiliation derived from the second atom of a CoT type string.
///
/// Example: `a-f-G-U-C` → second atom is `f` → [friendly].
enum CotAffiliation {
  /// Friendly force (blue).
  friendly,

  /// Hostile force (red).
  hostile,

  /// Neutral force (green).
  neutral,

  /// Unknown affiliation (yellow).
  unknown,

  /// Assumed friend (lighter blue).
  assumedFriend,

  /// Suspect (lighter red).
  suspect,

  /// Pending / unrecognized (yellow).
  pending,
}

/// Named color constants for each affiliation.
///
/// Colors follow MIL-STD-2525 conventions adapted for dark-themed maps.
abstract final class CotAffiliationColors {
  static const Color friendly = Color(0xFF4A90D9);
  static const Color hostile = Color(0xFFD94A4A);
  static const Color neutral = Color(0xFF4AD94A);
  static const Color unknown = Color(0xFFD9D94A);
  static const Color assumedFriend = Color(0xFF7AB3E8);
  static const Color suspect = Color(0xFFE87A7A);
  static const Color pending = Color(0xFFD9D94A);
}

/// Extension to resolve display properties from a [CotAffiliation].
extension CotAffiliationX on CotAffiliation {
  /// Primary color for markers, borders, and trails.
  Color get color {
    switch (this) {
      case CotAffiliation.friendly:
        return CotAffiliationColors.friendly;
      case CotAffiliation.hostile:
        return CotAffiliationColors.hostile;
      case CotAffiliation.neutral:
        return CotAffiliationColors.neutral;
      case CotAffiliation.unknown:
        return CotAffiliationColors.unknown;
      case CotAffiliation.assumedFriend:
        return CotAffiliationColors.assumedFriend;
      case CotAffiliation.suspect:
        return CotAffiliationColors.suspect;
      case CotAffiliation.pending:
        return CotAffiliationColors.pending;
    }
  }

  /// Human-readable label.
  String get label {
    switch (this) {
      case CotAffiliation.friendly:
        return 'Friendly';
      case CotAffiliation.hostile:
        return 'Hostile';
      case CotAffiliation.neutral:
        return 'Neutral';
      case CotAffiliation.unknown:
        return 'Unknown';
      case CotAffiliation.assumedFriend:
        return 'Assumed Friend';
      case CotAffiliation.suspect:
        return 'Suspect';
      case CotAffiliation.pending:
        return 'Pending';
    }
  }
}

/// Parse the second atom of a CoT type string into a [CotAffiliation].
///
/// The CoT type format is `a-X-...` where `X` is the affiliation atom:
/// - `f` → friendly
/// - `h` → hostile
/// - `n` → neutral
/// - `u` → unknown
/// - `a` → assumed friend
/// - `s` → suspect
/// - anything else → pending
///
/// Returns [CotAffiliation.pending] for malformed or unrecognized types.
CotAffiliation parseAffiliation(String cotType) {
  final atoms = cotType.split('-');
  if (atoms.length < 2) return CotAffiliation.pending;

  final affiliationAtom = atoms[1].toLowerCase();
  switch (affiliationAtom) {
    case 'f':
      return CotAffiliation.friendly;
    case 'h':
      return CotAffiliation.hostile;
    case 'n':
      return CotAffiliation.neutral;
    case 'u':
      return CotAffiliation.unknown;
    case 'a':
      return CotAffiliation.assumedFriend;
    case 's':
      return CotAffiliation.suspect;
    default:
      return CotAffiliation.pending;
  }
}

// ---------------------------------------------------------------------------
// CoT dimension / function icon mapping
// ---------------------------------------------------------------------------

/// Resolve an [IconData] from a CoT type string based on its dimension and
/// function atoms.
///
/// The CoT type format is `a-X-D-F-...`:
///   - Atom 0: `a` (atom category)
///   - Atom 1: affiliation (f/h/n/u/a/s)
///   - Atom 2: dimension — G (Ground), A (Air), S (Sea Surface),
///             U (Subsurface), P (Space), F (SOF), E (Electronic Warfare)
///   - Atom 3+: function codes refining the entity type
///
/// Returns [Icons.gps_fixed] for unrecognized or malformed types.
IconData cotTypeIcon(String cotType) {
  final atoms = cotType.split('-');
  if (atoms.length < 3) return Icons.gps_fixed;

  final dimension = atoms[2].toUpperCase();
  switch (dimension) {
    case 'G': // Ground
      if (atoms.length >= 4) {
        switch (atoms[3].toUpperCase()) {
          case 'U': // Unit
            return Icons.groups;
          case 'E': // Equipment / vehicle
            return Icons.local_shipping;
          case 'I': // Installation
            return Icons.business;
          case 'C': // Civilian
            return Icons.person;
          case 'N': // Non-combatant
            return Icons.person_outline;
          case 'S': // Signals intelligence
            return Icons.cell_tower;
        }
      }
      return Icons.terrain;
    case 'A': // Air
      if (atoms.length >= 4) {
        switch (atoms[3].toUpperCase()) {
          case 'M': // Military fixed-wing
            return Icons.flight;
          case 'H': // Rotary-wing
            return Icons.airplanemode_on;
          case 'W': // Weapon / missile
            return Icons.rocket_launch;
          case 'U': // UAV
            return Icons.flight_takeoff;
        }
      }
      return Icons.flight;
    case 'S': // Sea Surface
      return Icons.sailing;
    case 'U': // Subsurface
      return Icons.scuba_diving;
    case 'P': // Space
      return Icons.satellite_alt;
    case 'F': // SOF
      return Icons.shield;
    case 'E': // Electronic Warfare
      return Icons.cell_tower;
    default:
      return Icons.gps_fixed;
  }
}
