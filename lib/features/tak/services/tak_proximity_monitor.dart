// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math' as math;

import '../../../core/logging.dart';
import '../../../services/notifications/notification_service.dart';
import '../models/tak_event.dart';
import '../utils/cot_affiliation.dart';

/// Background monitor that fires local notifications when hostile/unknown
/// TAK entities enter a configurable radius around the user's position.
///
/// Check cycle runs every [checkIntervalSeconds] seconds. Per-entity dedup
/// prevents duplicate alerts: an entity must exit the radius before it can
/// re-alert on re-entry.
class TakProximityMonitor {
  TakProximityMonitor({
    required NotificationService notificationService,
    required this.getEvents,
    required this.getUserLat,
    required this.getUserLon,
    required this.getRadiusKm,
    required this.getAffiliations,
  }) : _notificationService = notificationService;

  final NotificationService _notificationService;
  final List<TakEvent> Function() getEvents;
  final double? Function() getUserLat;
  final double? Function() getUserLon;
  final double Function() getRadiusKm;
  final Set<String> Function() getAffiliations;

  static const checkIntervalSeconds = 15;

  Timer? _timer;
  final _insideRadius = <String>{};

  /// Start the periodic check timer.
  void start() {
    if (_timer != null) return;
    AppLogging.tak('ProximityMonitor: started');
    _timer = Timer.periodic(
      const Duration(seconds: checkIntervalSeconds),
      (_) => _check(),
    );
    // Run an immediate check.
    _check();
  }

  /// Stop the periodic check timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _insideRadius.clear();
    AppLogging.tak('ProximityMonitor: stopped');
  }

  /// Clean up resources.
  void dispose() {
    stop();
  }

  void _check() {
    final userLat = getUserLat();
    final userLon = getUserLon();

    if (userLat == null || userLon == null || (userLat == 0 && userLon == 0)) {
      AppLogging.tak(
        'ProximityMonitor: user position unavailable, skipping cycle',
      );
      return;
    }

    final radiusKm = getRadiusKm();
    final affiliations = getAffiliations();
    final events = getEvents();

    // Filter to non-stale entities matching configured affiliations.
    final candidates = events.where((e) {
      if (e.isStale) return false;
      final aff = parseAffiliation(e.type);
      return affiliations.contains(aff.name);
    }).toList();

    AppLogging.tak(
      'ProximityMonitor: checking ${candidates.length} entities '
      'against radius $radiusKm km',
    );

    // Track which UIDs are still active to clean up stale entries.
    final activeUids = <String>{};

    for (final event in candidates) {
      activeUids.add(event.uid);
      final distKm = _haversineKm(userLat, userLon, event.lat, event.lon);
      final wasInside = _insideRadius.contains(event.uid);

      if (distKm < radiusKm) {
        if (!wasInside) {
          // Entity just entered the radius — fire alert.
          _insideRadius.add(event.uid);
          AppLogging.tak(
            'ProximityMonitor: ${event.callsign ?? event.uid} at '
            '${distKm.toStringAsFixed(1)} km -- inside radius (was outside)',
          );
          AppLogging.tak(
            'ProximityMonitor: firing proximity alert for '
            '${event.callsign ?? event.uid}',
          );
          _fireAlert(event, distKm);
        } else {
          AppLogging.tak(
            'ProximityMonitor: ${event.callsign ?? event.uid} at '
            '${distKm.toStringAsFixed(1)} km -- already inside radius, skipping',
          );
        }
      } else {
        if (wasInside) {
          // Entity exited the radius — reset dedup.
          _insideRadius.remove(event.uid);
          AppLogging.tak(
            'ProximityMonitor: ${event.callsign ?? event.uid} at '
            '${distKm.toStringAsFixed(1)} km -- exited radius, resetting dedup',
          );
        }
      }
    }

    // Clean up stale entities from the inside set.
    _insideRadius.removeWhere((uid) => !activeUids.contains(uid));
  }

  void _fireAlert(TakEvent event, double distKm) {
    final affiliation = parseAffiliation(event.type);
    final callsign = event.callsign ?? event.uid;
    final distance = distKm < 1.0
        ? '${(distKm * 1000).round()} m'
        : '${distKm.toStringAsFixed(1)} km';

    String body;
    if (event.speed != null && event.speed! > 0) {
      final kmh = event.speed! * 3.6;
      final heading = event.formattedCourse ?? '';
      body =
          '${affiliation.label} entity at $distance -- '
          'heading $heading at ${kmh.toStringAsFixed(0)} km/h';
    } else {
      body = '${affiliation.label} entity at $distance -- stationary';
    }

    _notificationService.showTakProximityNotification(
      uid: event.uid,
      callsign: callsign,
      body: body,
    );
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
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

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}
