// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_providers.dart';
import '../models/tak_event.dart';
import 'tak_providers.dart';

/// State for the navigate-to-entity (Bloodhound) screen.
class TakNavigationState {
  const TakNavigationState({
    required this.target,
    this.bearingDegrees,
    this.distanceKm,
    this.hasUserPosition = false,
    this.userLat,
    this.userLon,
  });

  final TakEvent target;
  final double? bearingDegrees;
  final double? distanceKm;
  final bool hasUserPosition;
  final double? userLat;
  final double? userLon;

  /// Estimated time of arrival if the user (or target) is closing distance.
  ///
  /// Computed only when the target has a non-zero speed *and* is moving
  /// generally toward the user (bearing difference < 90°). Returns `null`
  /// when ETA cannot be meaningfully estimated.
  String? get formattedEta {
    if (distanceKm == null || distanceKm == 0) return null;
    final speed = target.speed; // m/s
    if (speed == null || speed <= 0) return null;
    final course = target.course;
    if (course == null || bearingDegrees == null) return null;

    // Reverse bearing: direction from target back to user.
    final reverseBearing = (bearingDegrees! + 180) % 360;
    // Angular difference between target's course and the approach bearing.
    var diff = (course - reverseBearing).abs();
    if (diff > 180) diff = 360 - diff;
    // Only show ETA when target is broadly approaching (< 90° off).
    if (diff >= 90) return null;

    // Closing speed = speed * cos(diff).
    final closingSpeedKmh = speed * 3.6 * math.cos(diff * math.pi / 180);
    if (closingSpeedKmh <= 0) return null;

    final hoursToArrival = distanceKm! / closingSpeedKmh;
    final minutes = (hoursToArrival * 60).round();
    if (minutes < 1) return '< 1 min';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }

  /// The target's speed text, or "Stationary" if none.
  String get targetSpeedText {
    if (target.speed == null || target.speed == 0.0) {
      return 'Target stationary';
    }
    final kmh = target.speed! * 3.6;
    final dir = target.formattedCourse;
    if (dir != null) {
      return 'Target moving $dir at ${kmh.toStringAsFixed(1)} km/h';
    }
    return 'Target moving at ${kmh.toStringAsFixed(1)} km/h';
  }

  /// Bearing formatted as "045\u00B0 NE".
  String? get formattedBearing {
    if (bearingDegrees == null) return null;
    final deg = bearingDegrees!.round();
    return '${deg.toString().padLeft(3, '0')}\u00B0 ${_compassDirection(bearingDegrees!)}';
  }

  /// Distance formatted for display.
  String? get formattedDistance {
    if (distanceKm == null) return null;
    if (distanceKm! < 1.0) return '${(distanceKm! * 1000).round()} m';
    return '${distanceKm!.toStringAsFixed(1)} km';
  }
}

/// Compute forward azimuth (bearing) from point A to point B in degrees.
double _forwardBearing(double lat1, double lon1, double lat2, double lon2) {
  final dLon = _toRadians(lon2 - lon1);
  final y = math.sin(dLon) * math.cos(_toRadians(lat2));
  final x =
      math.cos(_toRadians(lat1)) * math.sin(_toRadians(lat2)) -
      math.sin(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * math.cos(dLon);
  final bearing = math.atan2(y, x);
  return (bearing * 180 / math.pi + 360) % 360;
}

/// Haversine great-circle distance in km.
double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180;

String _compassDirection(double degrees) {
  final d = degrees % 360;
  if (d >= 337.5 || d < 22.5) return 'N';
  if (d < 67.5) return 'NE';
  if (d < 112.5) return 'E';
  if (d < 157.5) return 'SE';
  if (d < 202.5) return 'S';
  if (d < 247.5) return 'SW';
  if (d < 292.5) return 'W';
  return 'NW';
}

/// Provider that computes navigation data (bearing, distance) from the
/// user's current position to a target TAK entity.
///
/// Recomputes whenever the user's node position or the target entity updates.
final takNavigationProvider = Provider.family<TakNavigationState, String>((
  ref,
  targetUid,
) {
  final events = ref.watch(takActiveEventsProvider);
  final myNodeNum = ref.watch(myNodeNumProvider);
  final nodes = ref.watch(nodesProvider);

  // Find the target event by UID.
  final target = events.where((e) => e.uid == targetUid).firstOrNull;

  if (target == null) {
    // Entity no longer active — return a placeholder.
    return TakNavigationState(
      target: TakEvent(
        uid: targetUid,
        type: 'a-u',
        lat: 0,
        lon: 0,
        timeUtcMs: 0,
        staleUtcMs: 0,
        receivedUtcMs: 0,
      ),
    );
  }

  // User position from connected Meshtastic node.
  double? userLat;
  double? userLon;
  if (myNodeNum != null) {
    userLat = nodes[myNodeNum]?.latitude;
    userLon = nodes[myNodeNum]?.longitude;
  }

  final hasPos =
      userLat != null && userLon != null && (userLat != 0 || userLon != 0);

  if (!hasPos) {
    return TakNavigationState(target: target);
  }

  final bearing = _forwardBearing(userLat, userLon, target.lat, target.lon);
  final distance = _haversineKm(userLat, userLon, target.lat, target.lon);

  return TakNavigationState(
    target: target,
    bearingDegrees: bearing,
    distanceKm: distance,
    hasUserPosition: true,
    userLat: userLat,
    userLon: userLon,
  );
});
