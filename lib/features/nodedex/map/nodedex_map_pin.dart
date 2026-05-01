// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pin model for the NodeDex Map.
//
// One pin per NodeDex entry that has at least one encounter with both
// latitude and longitude recorded. The pin's coordinates come from the
// most recent positioned encounter (`positionedAt`); the entry may
// have a newer encounter without GPS, captured separately as
// `lastEncounterAt`. Keeping the two timestamps distinct prevents the
// UI from claiming the node was at the pin's coordinates more recently
// than it actually was — see `docs/overlay/AGENT_GUIDE.md`-style
// invariants for why honest timestamps matter.
//
// Staleness is computed against an injected clock (see
// `nodedexMapNowProvider` in `nodedex_map_pins_provider.dart`) so tests
// remain deterministic and the UI does not silently drift between
// rebuilds.

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/nodedex_entry.dart';

/// Number of days after which a pin is considered stale and rendered
/// at reduced opacity. Public so tests and UI can reference the same
/// constant.
const int kNodeDexMapStaleAfterDays = 7;

@immutable
class NodeDexMapPin {
  final int nodeNum;
  final LatLng position;

  /// Timestamp of the encounter that supplied [position] — the newest
  /// encounter on the entry that had both latitude and longitude
  /// non-null.
  final DateTime positionedAt;

  /// Timestamp of the entry's most recent encounter overall, regardless
  /// of whether GPS was available at the time. Will be `>= positionedAt`.
  /// Equal to [positionedAt] when the newest encounter was the one that
  /// supplied position.
  final DateTime lastEncounterAt;

  final int encounterCount;
  final SigilData? sigil;
  final NodeSocialTag? socialTag;
  final String? displayName;

  const NodeDexMapPin({
    required this.nodeNum,
    required this.position,
    required this.positionedAt,
    required this.lastEncounterAt,
    required this.encounterCount,
    this.sigil,
    this.socialTag,
    this.displayName,
  });

  /// True when more than [kNodeDexMapStaleAfterDays] have elapsed
  /// between [now] and [positionedAt]. Caller threads in the clock —
  /// production passes wall-time via `nodedexMapNowProvider`; tests
  /// override it.
  bool isStaleAt(DateTime now) =>
      now.difference(positionedAt).inDays > kNodeDexMapStaleAfterDays;

  /// Whether the entry has been encountered again (without GPS) since
  /// the position was captured. When true, the sheet should surface
  /// both timestamps so the user understands the pin is older than the
  /// last contact.
  bool get hasNewerEncounterThanPosition =>
      lastEncounterAt.isAfter(positionedAt);
}
