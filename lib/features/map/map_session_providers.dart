// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

// MapScreen is disposed and rebuilt from scratch on every bottom-nav tab
// switch (the shell swaps the active screen by key). Anything held only in
// MapScreen's State is therefore lost on return: the camera snaps back to the
// computed fallback (the LatLng(0,0) blank-ocean default before node positions
// resolve). This session-scoped provider keeps the camera pose alive for the
// app lifetime so a tab switch restores it. Plain (non-autoDispose) providers
// are retained by the container, which is exactly the lifetime we want here.
// The local "dropped pin" waypoints live in lib/providers/map_local_waypoints
// so non-map features (the route detail map) can render them too.

/// Last camera pose for the Map tab. `null` until the user has moved the map
/// at least once this session.
class MapCameraState {
  final LatLng center;
  final double zoom;

  const MapCameraState({required this.center, required this.zoom});
}

final mapCameraStateProvider =
    NotifierProvider<MapCameraNotifier, MapCameraState?>(MapCameraNotifier.new);

class MapCameraNotifier extends Notifier<MapCameraState?> {
  @override
  MapCameraState? build() => null;

  void save(LatLng center, double zoom) {
    state = MapCameraState(center: center, zoom: zoom);
  }
}
