// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:latlong2/latlong.dart';

// latlong2's `Distance()` rounds every result to a whole unit unless told
// otherwise, so `Distance().as(LengthUnit.Kilometer, a, b)` reports 0 km for
// anything under 500 m and then steps in whole kilometres. Any distance a
// person will read must keep metre resolution, so every geographic distance
// in the app routes through these helpers instead of constructing a
// `Distance` at the call site.
const Distance _preciseDistance = Distance(roundResult: false);

/// Great-circle distance between two points in metres, unrounded. Returns 0
/// when the calculation cannot produce a finite value (near-antipodal points
/// make Vincenty fail to converge).
double distanceMetersBetween(LatLng a, LatLng b) {
  try {
    final meters = _preciseDistance.as(LengthUnit.Meter, a, b);
    return meters.isFinite ? meters : 0;
  } catch (_) {
    return 0;
  }
}

/// Great-circle distance between two points in kilometres, unrounded.
double distanceKmBetween(LatLng a, LatLng b) =>
    distanceMetersBetween(a, b) / 1000;
