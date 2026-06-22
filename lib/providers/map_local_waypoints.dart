// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

// User-dropped local waypoints ("yellow pins"). Shared from lib/providers so
// any feature (the map screen, the route detail map) can render them without
// a cross-feature import. Session-scoped: a plain (non-autoDispose) provider is
// retained by the container for the app lifetime, so the pins survive the
// MapScreen being disposed and rebuilt on every bottom-nav tab switch.

/// A user-dropped local waypoint (the yellow pin). Distinct from shared mesh
/// waypoints, which already persist via `waypointsNotifierProvider`.
class MapLocalWaypoint {
  final int id;
  final LatLng position;
  final String label;

  const MapLocalWaypoint({
    required this.id,
    required this.position,
    required this.label,
  });
}

final mapLocalWaypointsProvider =
    NotifierProvider<MapLocalWaypointsNotifier, List<MapLocalWaypoint>>(
      MapLocalWaypointsNotifier.new,
    );

class MapLocalWaypointsNotifier extends Notifier<List<MapLocalWaypoint>> {
  @override
  List<MapLocalWaypoint> build() => const [];

  void add(MapLocalWaypoint waypoint) {
    state = [...state, waypoint];
  }

  void remove(int id) {
    state = state.where((w) => w.id != id).toList(growable: false);
  }

  void clear() {
    state = const [];
  }
}
