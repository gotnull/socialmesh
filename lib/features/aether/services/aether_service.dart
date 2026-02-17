// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:socialmesh/core/logging.dart';

import '../models/aether_flight.dart';

/// Service for Aether flight tracking functionality
class AetherService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _flightsCollection =>
      _firestore.collection('aetherFlights');

  CollectionReference<Map<String, dynamic>> get _reportsCollection =>
      _firestore.collection('receptionReports');

  // ============ Aether Flights ============

  /// Get all upcoming and active flights
  Stream<List<AetherFlight>> watchFlights() {
    AppLogging.aether('watchFlights() — subscribing to flights since 12h ago');
    final cutoff = DateTime.now().subtract(const Duration(hours: 12));
    return _flightsCollection
        .where('scheduledDeparture', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('scheduledDeparture')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AetherFlight.fromJson(doc.data(), doc.id))
              .toList(),
        )
        .handleError((Object e) {
          AppLogging.aether('Flights stream error: $e');
        });
  }

  /// Get active flights (in progress)
  Stream<List<AetherFlight>> watchActiveFlights() {
    AppLogging.aether('watchActiveFlights() — subscribing to active flights');
    return _flightsCollection
        .where('isActive', isEqualTo: true)
        .orderBy('scheduledDeparture')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AetherFlight.fromJson(doc.data(), doc.id))
              .toList(),
        )
        .handleError((Object e) {
          AppLogging.aether('Active flights stream error: $e');
        });
  }

  /// Create a new flight schedule
  Future<AetherFlight> createFlight({
    required String nodeId,
    String? nodeName,
    required String flightNumber,
    String? airline,
    required String departure,
    required String arrival,
    required DateTime scheduledDeparture,
    DateTime? scheduledArrival,
    required String userId,
    String? userName,
    String? notes,
  }) async {
    AppLogging.aether(
      'createFlight() — $flightNumber $departure -> $arrival '
      'departing ${scheduledDeparture.toIso8601String()}',
    );

    final data = {
      'nodeId': nodeId,
      'nodeName': nodeName,
      'flightNumber': flightNumber.toUpperCase(),
      'airline': airline,
      'departure': departure.toUpperCase(),
      'arrival': arrival.toUpperCase(),
      'scheduledDeparture': Timestamp.fromDate(scheduledDeparture),
      'scheduledArrival': scheduledArrival != null
          ? Timestamp.fromDate(scheduledArrival)
          : null,
      'userId': userId,
      'userName': userName,
      'notes': notes,
      'isActive': false,
      'createdAt': FieldValue.serverTimestamp(),
      'receptionCount': 0,
    };

    final docRef = await _flightsCollection.add(data);
    AppLogging.aether('Flight created: ${docRef.id}');
    final doc = await docRef.get();
    return AetherFlight.fromJson(doc.data()!, doc.id);
  }

  /// Update flight active status
  Future<void> updateFlightStatus(String id, {required bool isActive}) async {
    AppLogging.aether('updateFlightStatus() — id=$id isActive=$isActive');
    await _flightsCollection.doc(id).update({'isActive': isActive});
  }

  /// Delete a flight
  Future<void> deleteFlight(String id) async {
    AppLogging.aether('deleteFlight() — id=$id');
    await _flightsCollection.doc(id).delete();
    AppLogging.aether('Flight deleted: $id');
  }

  // ============ Reception Reports ============

  /// Watch reception reports for a flight
  Stream<List<ReceptionReport>> watchReports(String flightId) {
    AppLogging.aether('watchReports() — flightId=$flightId');
    return _reportsCollection
        .where('aetherFlightId', isEqualTo: flightId)
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReceptionReport.fromJson(doc.data(), doc.id))
              .toList(),
        )
        .handleError((Object e) {
          AppLogging.aether('Reports stream error: $e');
        });
  }

  /// Get global leaderboard — all-time top distances
  ///
  /// This is the primary leaderboard query. Results are sorted by
  /// estimatedDistance descending so the longest range contacts appear first.
  /// Data is persisted in Firestore and survives app deletion.
  Stream<List<ReceptionReport>> watchLeaderboard({int limit = 100}) {
    AppLogging.aether('watchLeaderboard() — limit=$limit');
    return _reportsCollection
        .where('estimatedDistance', isGreaterThan: 0)
        .orderBy('estimatedDistance', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReceptionReport.fromJson(doc.data(), doc.id))
              .toList(),
        )
        .handleError((Object e) {
          AppLogging.aether('Leaderboard stream error: $e');
        });
  }

  /// Create a reception report
  Future<ReceptionReport> createReport({
    required String flightId,
    required String flightNumber,
    required String reporterId,
    String? reporterName,
    String? reporterNodeId,
    String? reporterNodeName,
    double? latitude,
    double? longitude,
    double? altitude,
    double? snr,
    double? rssi,
    double? estimatedDistance,
    String? notes,
    required DateTime receivedAt,
  }) async {
    AppLogging.aether('=' * 60);
    AppLogging.aether('Creating reception report');
    AppLogging.aether('  flightId: $flightId');
    AppLogging.aether('  flightNumber: $flightNumber');
    AppLogging.aether('  reporterId: $reporterId');
    AppLogging.aether('  reporterName: $reporterName');
    AppLogging.aether('  reporterNodeId: $reporterNodeId');
    AppLogging.aether('  reporterNodeName: $reporterNodeName');
    AppLogging.aether('  lat/lon: $latitude, $longitude');
    AppLogging.aether('  rssi: $rssi, snr: $snr');
    AppLogging.aether('  estimatedDistance: $estimatedDistance km');
    AppLogging.aether('  notes: ${notes != null ? '"$notes"' : 'none'}');
    AppLogging.aether('  receivedAt: $receivedAt');

    final data = {
      'aetherFlightId': flightId,
      'flightNumber': flightNumber,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reporterNodeId': reporterNodeId,
      'reporterNodeName': reporterNodeName,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'snr': snr,
      'rssi': rssi,
      'estimatedDistance': estimatedDistance,
      'notes': notes,
      'receivedAt': Timestamp.fromDate(receivedAt),
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      AppLogging.aether('Writing report to Firestore...');
      final docRef = await _reportsCollection.add(data);
      AppLogging.aether('Report created: ${docRef.id}');

      // Increment reception count on flight
      AppLogging.aether('Incrementing reception count on flight $flightId...');
      await _flightsCollection.doc(flightId).update({
        'receptionCount': FieldValue.increment(1),
      });
      AppLogging.aether('Reception count incremented');

      final doc = await docRef.get();
      final report = ReceptionReport.fromJson(doc.data()!, doc.id);
      AppLogging.aether('Report confirmed: ${report.id}');
      AppLogging.aether('=' * 60);
      return report;
    } catch (e, st) {
      AppLogging.aether('Report creation FAILED: $e');
      AppLogging.aether('Stack trace: $st');
      AppLogging.aether('=' * 60);
      rethrow;
    }
  }

  // ============ Distance Calculations ============

  /// Calculate distance between two coordinates in km
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371.0; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Calculate distance including altitude difference (slant range)
  static double calculateSlantRange(
    double lat1,
    double lon1,
    double alt1,
    double lat2,
    double lon2,
    double alt2,
  ) {
    final groundDistance = calculateDistance(lat1, lon1, lat2, lon2);
    final altDiff = (alt2 - alt1) / 1000; // Convert to km
    return math.sqrt(groundDistance * groundDistance + altDiff * altDiff);
  }
}
