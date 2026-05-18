// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../../models/meshcore_contact.dart';

/// Row 13: opacity multiplier for a contact's map marker based on
/// the age of the last advert we heard from them.
///
/// MeshCore contact records carry `latitude` / `longitude` (advertised
/// by the contact) and `lastSeen` (last time we heard ANY advert from
/// them). Location doesn't carry its own timestamp, so `lastSeen` is
/// the best signal that the location is still meaningful.
///
/// Thresholds:
///   - fresh:       lastSeen <  24h            -> 1.0 (full opacity)
///   - stale:       24h <= lastSeen < 7d       -> 0.5
///   - very stale:  lastSeen >= 7d             -> 0.25
///
/// `now` is injected so tests can pin the clock; production callers
/// pass `DateTime.now()`.
double meshCoreContactMarkerOpacity(MeshCoreContact contact, DateTime now) {
  final age = now.difference(contact.lastSeen);
  if (age < kMeshCoreMarkerFreshThreshold) return 1.0;
  if (age < kMeshCoreMarkerVeryStaleThreshold) return 0.5;
  return 0.25;
}

/// Below this age, the marker renders at full opacity.
const Duration kMeshCoreMarkerFreshThreshold = Duration(hours: 24);

/// At or above this age, the marker renders at the most-faded opacity.
/// Between the fresh and very-stale thresholds the marker renders at
/// the mid-staleness opacity.
const Duration kMeshCoreMarkerVeryStaleThreshold = Duration(days: 7);
