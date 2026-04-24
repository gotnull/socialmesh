// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// flutter_map's Crs.checkLatLng throws when a Marker's point is non-finite,
// which crashes the entire MarkerLayer build. Filter at construction.
// See: https://github.com/fleaflet/flutter_map/issues/2178
LatLng? safeLatLng(num? lat, num? lng) {
  if (lat == null || lng == null) return null;
  final dLat = lat.toDouble();
  final dLng = lng.toDouble();
  if (!dLat.isFinite || !dLng.isFinite) return null;
  if (dLat < -90.0 || dLat > 90.0) return null;
  if (dLng < -180.0 || dLng > 180.0) return null;
  return LatLng(dLat, dLng);
}

bool isFiniteLatLng(LatLng? p) {
  if (p == null) return false;
  return p.latitude.isFinite &&
      p.longitude.isFinite &&
      p.latitude >= -90.0 &&
      p.latitude <= 90.0 &&
      p.longitude >= -180.0 &&
      p.longitude <= 180.0;
}

List<Marker> finiteMarkers(Iterable<Marker> markers) {
  return markers.where((m) => isFiniteLatLng(m.point)).toList(growable: false);
}

// Build LatLngBounds.fromPoints only from finite points. Returns null when
// nothing finite is left — callers should skip the fit in that case rather
// than feed a degenerate bounds into the camera.
LatLngBounds? safeLatLngBounds(Iterable<LatLng> points) {
  final finite = points.where(isFiniteLatLng).toList(growable: false);
  if (finite.isEmpty) return null;
  return LatLngBounds.fromPoints(finite);
}

// Guarded camera movement. flutter_map's Crs.checkLatLng throws fatally when
// a non-finite center reaches projectAtZoom via the tile layer, so every
// programmatic move must filter NaN/out-of-range coordinates at the boundary.
extension SafeMapControllerMove on MapController {
  bool safeMove(LatLng? point, double zoom) {
    if (!isFiniteLatLng(point) || !zoom.isFinite) return false;
    return move(point!, zoom);
  }

  void safeMoveAndRotate(LatLng? point, double zoom, double rotation) {
    if (!isFiniteLatLng(point) || !zoom.isFinite || !rotation.isFinite) return;
    moveAndRotate(point!, zoom, rotation);
  }
}
