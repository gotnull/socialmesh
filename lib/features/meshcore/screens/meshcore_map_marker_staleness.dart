// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../../models/meshcore_contact.dart';

/// Whether a contact's map marker shows the stale badge: no advert heard
/// from it for [kMeshCoreMarkerFreshThreshold].
///
/// MeshCore contact records carry `latitude` / `longitude` (advertised by
/// the contact) and `lastSeen` (last time we heard any advert from them).
/// Location has no timestamp of its own, so `lastSeen` is the best signal
/// that the position is still meaningful. A stale marker keeps its colour
/// and gains a "?" badge, as on the Meshtastic map, rather than fading.
///
/// `now` is injected so tests can pin the clock; production callers pass
/// `DateTime.now()`.
bool meshCoreContactMarkerIsStale(MeshCoreContact contact, DateTime now) =>
    now.difference(contact.lastSeen) >= kMeshCoreMarkerFreshThreshold;

/// Below this age a contact counts as fresh; at or above it the map marker
/// shows the stale badge.
const Duration kMeshCoreMarkerFreshThreshold = Duration(hours: 24);

/// At or above this age a contact counts as very stale in the contact lists.
const Duration kMeshCoreMarkerVeryStaleThreshold = Duration(days: 7);
