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
