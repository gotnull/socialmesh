// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_providers.dart';
import '../models/tak_event.dart';
import '../services/tak_gateway_client.dart';
import '../utils/cot_affiliation.dart';
import 'tak_providers.dart';
import 'tak_settings_provider.dart';
import 'tak_tracking_provider.dart';

/// Immutable snapshot of the Situational Awareness Dashboard state.
class TakDashboardState {
  const TakDashboardState({
    required this.friendlyCount,
    required this.hostileCount,
    required this.neutralCount,
    required this.unknownCount,
    this.nearestHostile,
    this.nearestHostileDistanceKm,
    this.nearestUnknown,
    this.nearestUnknownDistanceKm,
    required this.trackedCount,
    required this.trackedCallsigns,
    required this.staleCount,
    required this.isConnected,
    this.lastEventTime,
    required this.isPublishing,
    required this.publishIntervalSeconds,
  });

  final int friendlyCount;
  final int hostileCount;
  final int neutralCount;
  final int unknownCount;
  final TakEvent? nearestHostile;
  final double? nearestHostileDistanceKm;
  final TakEvent? nearestUnknown;
  final double? nearestUnknownDistanceKm;
  final int trackedCount;
  final List<String> trackedCallsigns;
  final int staleCount;
  final bool isConnected;
  final DateTime? lastEventTime;
  final bool isPublishing;
  final int publishIntervalSeconds;

  /// Total entity count across all affiliations.
  int get totalCount =>
      friendlyCount + hostileCount + neutralCount + unknownCount;
}

/// Computes the Haversine great-circle distance between two points in km.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
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

/// Format a distance value for display.
///
/// Returns meters for distances < 1 km, otherwise km with 1 decimal.
String formatDistance(double km) {
  if (km < 1.0) {
    return '${(km * 1000).round()} m';
  }
  return '${km.toStringAsFixed(1)} km';
}

/// Provider that computes the SA dashboard state from active events,
/// connection state, tracking state, and user position.
final takDashboardProvider = Provider<TakDashboardState>((ref) {
  final events = ref.watch(takActiveEventsProvider);
  final connectionState =
      ref.watch(takConnectionStateProvider).whenOrNull(data: (s) => s) ??
      TakConnectionState.disconnected;
  final trackedUids = ref.watch(takTrackedUidsProvider);
  final settings = ref.watch(takSettingsProvider).value;
  final myNodeNum = ref.watch(myNodeNumProvider);
  final nodes = ref.watch(nodesProvider);

  // User position from connected Meshtastic node.
  double? userLat;
  double? userLon;
  if (myNodeNum != null) {
    userLat = nodes[myNodeNum]?.latitude;
    userLon = nodes[myNodeNum]?.longitude;
  }

  // Has a valid user position (non-zero).
  final hasUserPosition =
      userLat != null && userLon != null && (userLat != 0 || userLon != 0);

  // Count by affiliation.
  var friendlyCount = 0;
  var hostileCount = 0;
  var neutralCount = 0;
  var unknownCount = 0;
  var staleCount = 0;

  TakEvent? nearestHostile;
  double? nearestHostileKm;
  TakEvent? nearestUnknown;
  double? nearestUnknownKm;

  for (final event in events) {
    final affiliation = parseAffiliation(event.type);
    switch (affiliation) {
      case CotAffiliation.friendly:
      case CotAffiliation.assumedFriend:
        friendlyCount++;
      case CotAffiliation.hostile:
      case CotAffiliation.suspect:
        hostileCount++;
      case CotAffiliation.neutral:
        neutralCount++;
      case CotAffiliation.unknown:
      case CotAffiliation.pending:
        unknownCount++;
    }

    if (event.isStale) staleCount++;

    // Compute nearest hostile/unknown distances.
    if (hasUserPosition) {
      final distKm = haversineKm(userLat, userLon, event.lat, event.lon);

      if (affiliation == CotAffiliation.hostile ||
          affiliation == CotAffiliation.suspect) {
        if (nearestHostileKm == null || distKm < nearestHostileKm) {
          nearestHostile = event;
          nearestHostileKm = distKm;
        }
      }

      if (affiliation == CotAffiliation.unknown ||
          affiliation == CotAffiliation.pending) {
        if (nearestUnknownKm == null || distKm < nearestUnknownKm) {
          nearestUnknown = event;
          nearestUnknownKm = distKm;
        }
      }
    }
  }

  // Tracked entity callsigns.
  final trackedCallsigns = <String>[];
  for (final event in events) {
    if (trackedUids.contains(event.uid)) {
      trackedCallsigns.add(event.callsign ?? event.uid);
    }
  }

  // Last event time: most recent receivedUtcMs.
  DateTime? lastEventTime;
  if (events.isNotEmpty) {
    final maxReceived = events.map((e) => e.receivedUtcMs).reduce(math.max);
    lastEventTime = DateTime.fromMillisecondsSinceEpoch(maxReceived);
  }

  return TakDashboardState(
    friendlyCount: friendlyCount,
    hostileCount: hostileCount,
    neutralCount: neutralCount,
    unknownCount: unknownCount,
    nearestHostile: nearestHostile,
    nearestHostileDistanceKm: nearestHostileKm,
    nearestUnknown: nearestUnknown,
    nearestUnknownDistanceKm: nearestUnknownKm,
    trackedCount: trackedCallsigns.length,
    trackedCallsigns: trackedCallsigns,
    staleCount: staleCount,
    isConnected: connectionState == TakConnectionState.connected,
    lastEventTime: lastEventTime,
    isPublishing: settings?.publishEnabled ?? false,
    publishIntervalSeconds: settings?.publishInterval ?? 60,
  );
});
