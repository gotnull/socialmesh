// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:socialmesh/core/logging.dart';

import '../models/sky_node.dart';

/// Service for Sky Scanner functionality
class SkyScannerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _skyNodesCollection =>
      _firestore.collection('skyNodes');

  CollectionReference<Map<String, dynamic>> get _reportsCollection =>
      _firestore.collection('receptionReports');

  // ============ Sky Nodes ============

  /// Get all upcoming and active sky nodes
  Stream<List<SkyNode>> watchSkyNodes() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 12));
    return _skyNodesCollection
        .where('scheduledDeparture', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('scheduledDeparture')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SkyNode.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Get active flights (in progress)
  Stream<List<SkyNode>> watchActiveFlights() {
    return _skyNodesCollection
        .where('isActive', isEqualTo: true)
        .orderBy('scheduledDeparture')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SkyNode.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Get sky nodes for a specific user
  Stream<List<SkyNode>> watchUserSkyNodes(String userId) {
    return _skyNodesCollection
        .where('userId', isEqualTo: userId)
        .orderBy('scheduledDeparture', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SkyNode.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Create a new sky node (schedule a flight)
  Future<SkyNode> createSkyNode({
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

    final docRef = await _skyNodesCollection.add(data);
    final doc = await docRef.get();
    return SkyNode.fromJson(doc.data()!, doc.id);
  }

  /// Update sky node active status
  Future<void> updateSkyNodeStatus(String id, {required bool isActive}) async {
    await _skyNodesCollection.doc(id).update({'isActive': isActive});
  }

  /// Delete a sky node
  Future<void> deleteSkyNode(String id) async {
    await _skyNodesCollection.doc(id).delete();
  }

  // ============ Reception Reports ============

  /// Watch reception reports for a sky node
  Stream<List<ReceptionReport>> watchReports(String skyNodeId) {
    return _reportsCollection
        .where('skyNodeId', isEqualTo: skyNodeId)
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReceptionReport.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Get recent reception reports
  Stream<List<ReceptionReport>> watchRecentReports({int limit = 50}) {
    return _reportsCollection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReceptionReport.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Get global leaderboard — all-time top distances
  ///
  /// This is the primary leaderboard query. Results are sorted by
  /// estimatedDistance descending so the longest range contacts appear first.
  /// Data is persisted in Firestore and survives app deletion.
  Stream<List<ReceptionReport>> watchLeaderboard({int limit = 100}) {
    return _reportsCollection
        .where('estimatedDistance', isGreaterThan: 0)
        .orderBy('estimatedDistance', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReceptionReport.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Get top distance record (all-time best)
  Future<ReceptionReport?> getTopDistanceRecord() async {
    final snapshot = await _reportsCollection
        .where('estimatedDistance', isGreaterThan: 0)
        .orderBy('estimatedDistance', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return ReceptionReport.fromJson(doc.data(), doc.id);
  }

  /// Get leaderboard filtered by time period
  Stream<List<ReceptionReport>> watchLeaderboardByPeriod({
    required DateTime since,
    int limit = 50,
  }) {
    return _reportsCollection
        .where('estimatedDistance', isGreaterThan: 0)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('estimatedDistance', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReceptionReport.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Get a user's personal best distance
  Future<ReceptionReport?> getUserPersonalBest(String userId) async {
    final snapshot = await _reportsCollection
        .where('reporterId', isEqualTo: userId)
        .where('estimatedDistance', isGreaterThan: 0)
        .orderBy('estimatedDistance', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return ReceptionReport.fromJson(doc.data(), doc.id);
  }

  /// Get user's rank on the leaderboard
  Future<int?> getUserLeaderboardRank(String userId) async {
    // Get all reports sorted by distance
    final snapshot = await _reportsCollection
        .where('estimatedDistance', isGreaterThan: 0)
        .orderBy('estimatedDistance', descending: true)
        .get();

    if (snapshot.docs.isEmpty) return null;

    // Find user's best report position
    int rank = 1;
    double? userBestDistance;

    for (final doc in snapshot.docs) {
      final report = ReceptionReport.fromJson(doc.data(), doc.id);
      if (report.reporterId == userId) {
        if (userBestDistance == null ||
            (report.estimatedDistance ?? 0) > userBestDistance) {
          userBestDistance = report.estimatedDistance;
          return rank;
        }
      }
      rank++;
    }

    return null; // User has no reports
  }

  /// Create a reception report
  Future<ReceptionReport> createReport({
    required String skyNodeId,
    required String flightNumber,
    required String reporterId,
    String? reporterName,
    String? reporterNodeId,
    double? latitude,
    double? longitude,
    double? altitude,
    double? snr,
    double? rssi,
    double? estimatedDistance,
    String? notes,
    required DateTime receivedAt,
  }) async {
    final data = {
      'skyNodeId': skyNodeId,
      'flightNumber': flightNumber,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reporterNodeId': reporterNodeId,
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

    final docRef = await _reportsCollection.add(data);

    // Increment reception count on sky node
    await _skyNodesCollection.doc(skyNodeId).update({
      'receptionCount': FieldValue.increment(1),
    });

    final doc = await docRef.get();
    return ReceptionReport.fromJson(doc.data()!, doc.id);
  }

  // ============ Flight Tracking (OpenSky Network) ============

  /// Get live flight position from OpenSky Network API
  /// This is a free API with rate limits - be respectful
  Future<FlightPosition?> getFlightPosition(String callsign) async {
    try {
      // Clean callsign (remove spaces, uppercase)
      final cleanCallsign = callsign.replaceAll(' ', '').toUpperCase();

      final uri = Uri.parse(
        'https://opensky-network.org/api/states/all?icao24=&callsign=$cleanCallsign',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final states = json['states'] as List<dynamic>?;

        if (states != null && states.isNotEmpty) {
          final state = states.first as List<dynamic>;
          // OpenSky state vector format:
          // [0] icao24, [1] callsign, [2] origin_country, [3] time_position,
          // [4] last_contact, [5] longitude, [6] latitude, [7] baro_altitude,
          // [8] on_ground, [9] velocity, [10] true_track, [11] vertical_rate,
          // [12] sensors, [13] geo_altitude, [14] squawk, [15] spi, [16] position_source

          return FlightPosition(
            callsign: (state[1] as String?)?.trim() ?? cleanCallsign,
            longitude: (state[5] as num?)?.toDouble() ?? 0,
            latitude: (state[6] as num?)?.toDouble() ?? 0,
            altitude: (state[7] as num?)?.toDouble() ?? 0,
            onGround: state[8] as bool? ?? false,
            velocity: (state[9] as num?)?.toDouble() ?? 0,
            heading: (state[10] as num?)?.toDouble() ?? 0,
            lastUpdate: DateTime.fromMillisecondsSinceEpoch(
              ((state[4] as num?)?.toInt() ?? 0) * 1000,
            ),
          );
        }
      }

      return null;
    } catch (e) {
      AppLogging.app('[SkyScanner] Error fetching flight position: $e');
      return null;
    }
  }

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
