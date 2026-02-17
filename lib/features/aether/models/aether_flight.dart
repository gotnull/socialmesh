// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

/// A Meshtastic node scheduled to be on a flight
class AetherFlight {
  final String id;
  final String nodeId; // Meshtastic node ID (hex)
  final String? nodeName; // Optional friendly name
  final String flightNumber; // e.g., "UA123"
  final String? airline;
  final String departure; // Airport code, e.g., "LAX"
  final String arrival; // Airport code, e.g., "JFK"
  final DateTime scheduledDeparture;
  final DateTime? scheduledArrival;
  final String userId; // Who posted this
  final String? userName;
  final String? notes; // Any additional info
  final bool isActive; // Server-managed active flag (may lag behind real time)
  final DateTime createdAt;
  final int receptionCount; // Number of reception reports

  const AetherFlight({
    required this.id,
    required this.nodeId,
    this.nodeName,
    required this.flightNumber,
    this.airline,
    required this.departure,
    required this.arrival,
    required this.scheduledDeparture,
    this.scheduledArrival,
    required this.userId,
    this.userName,
    this.notes,
    this.isActive = false,
    required this.createdAt,
    this.receptionCount = 0,
  });

  factory AetherFlight.fromJson(Map<String, dynamic> json, String id) {
    return AetherFlight(
      id: id,
      nodeId: json['nodeId'] as String,
      nodeName: json['nodeName'] as String?,
      flightNumber: json['flightNumber'] as String,
      airline: json['airline'] as String?,
      departure: json['departure'] as String,
      arrival: json['arrival'] as String,
      scheduledDeparture: (json['scheduledDeparture'] as Timestamp).toDate(),
      scheduledArrival: json['scheduledArrival'] != null
          ? (json['scheduledArrival'] as Timestamp).toDate()
          : null,
      userId: json['userId'] as String,
      userName: json['userName'] as String?,
      notes: json['notes'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      receptionCount: json['receptionCount'] as int? ?? 0,
    );
  }

  /// Create an [AetherFlight] from the Aether REST API response.
  ///
  /// The API uses snake_case keys and ISO 8601 date strings instead of
  /// Firestore camelCase keys and [Timestamp] objects.
  factory AetherFlight.fromApiJson(Map<String, dynamic> json) {
    return AetherFlight(
      id: json['id'] as String,
      nodeId: (json['node_id'] as String?) ?? '',
      nodeName: json['node_name'] as String?,
      flightNumber: json['flight_number'] as String,
      airline: json['airline'] as String?,
      departure: json['departure'] as String,
      arrival: json['arrival'] as String,
      scheduledDeparture: DateTime.parse(json['scheduled_departure'] as String),
      scheduledArrival: json['scheduled_arrival'] != null
          ? DateTime.parse(json['scheduled_arrival'] as String)
          : null,
      userId: '', // API flights have no userId — community-shared
      userName: json['user_name'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: DateTime.parse(json['created_at'] as String),
      receptionCount: json['reception_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'nodeName': nodeName,
      'flightNumber': flightNumber,
      'airline': airline,
      'departure': departure,
      'arrival': arrival,
      'scheduledDeparture': Timestamp.fromDate(scheduledDeparture),
      'scheduledArrival': scheduledArrival != null
          ? Timestamp.fromDate(scheduledArrival!)
          : null,
      'userId': userId,
      'userName': userName,
      'notes': notes,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'receptionCount': receptionCount,
    };
  }

  AetherFlight copyWith({
    String? id,
    String? nodeId,
    String? nodeName,
    String? flightNumber,
    String? airline,
    String? departure,
    String? arrival,
    DateTime? scheduledDeparture,
    DateTime? scheduledArrival,
    String? userId,
    String? userName,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    int? receptionCount,
  }) {
    return AetherFlight(
      id: id ?? this.id,
      nodeId: nodeId ?? this.nodeId,
      nodeName: nodeName ?? this.nodeName,
      flightNumber: flightNumber ?? this.flightNumber,
      airline: airline ?? this.airline,
      departure: departure ?? this.departure,
      arrival: arrival ?? this.arrival,
      scheduledDeparture: scheduledDeparture ?? this.scheduledDeparture,
      scheduledArrival: scheduledArrival ?? this.scheduledArrival,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      receptionCount: receptionCount ?? this.receptionCount,
    );
  }

  /// Check if flight is upcoming (within next 24 hours)
  bool get isUpcoming {
    final now = DateTime.now();
    if (now.isAfter(scheduledDeparture)) return false;
    final diff = scheduledDeparture.difference(now);
    return diff.inHours <= 24;
  }

  /// Check if flight should currently be in the air based on schedule.
  ///
  /// True when scheduled departure is in the past and scheduled arrival
  /// (or fallback 12-hour window) is in the future.
  bool get isInFlight {
    final now = DateTime.now();
    if (now.isBefore(scheduledDeparture)) return false;
    if (scheduledArrival != null) {
      return now.isBefore(scheduledArrival!);
    }
    // Assume 12 hours max flight time if no arrival
    return now.isBefore(scheduledDeparture.add(const Duration(hours: 12)));
  }

  /// Check if flight is past
  bool get isPast {
    final now = DateTime.now();
    if (scheduledArrival != null) {
      return now.isAfter(scheduledArrival!);
    }
    // Assume 12 hours max flight time if no arrival
    return now.isAfter(scheduledDeparture.add(const Duration(hours: 12)));
  }

  /// Get flight status string.
  ///
  /// Time-based checks (`isPast`, `isInFlight`, `isUpcoming`) take priority
  /// over the stored `isActive` flag because the flag may lag behind real
  /// time (e.g. the Aether API only expires flights every 5 minutes).
  String get statusText {
    if (isPast) return 'Completed';
    if (isInFlight || isActive) return 'In Flight';
    if (isUpcoming) return 'Upcoming';
    return 'Scheduled';
  }
}

/// A reception report from a ground station
class ReceptionReport {
  final String id;
  final String aetherFlightId;
  final String flightNumber;
  final String reporterId; // User who received
  final String? reporterName;
  final String? reporterNodeId; // Their Meshtastic node
  final String? reporterNodeName; // Their node's display name
  final double? latitude;
  final double? longitude;
  final double? altitude; // Ground station altitude
  final double? snr; // Signal-to-noise ratio
  final double? rssi; // Signal strength
  final double? estimatedDistance; // km
  final String? notes;
  final DateTime receivedAt;
  final DateTime createdAt;

  const ReceptionReport({
    required this.id,
    required this.aetherFlightId,
    required this.flightNumber,
    required this.reporterId,
    this.reporterName,
    this.reporterNodeId,
    this.reporterNodeName,
    this.latitude,
    this.longitude,
    this.altitude,
    this.snr,
    this.rssi,
    this.estimatedDistance,
    this.notes,
    required this.receivedAt,
    required this.createdAt,
  });

  factory ReceptionReport.fromJson(Map<String, dynamic> json, String id) {
    return ReceptionReport(
      id: id,
      aetherFlightId: json['aetherFlightId'] as String,
      flightNumber: json['flightNumber'] as String,
      reporterId: json['reporterId'] as String,
      reporterName: json['reporterName'] as String?,
      reporterNodeId: json['reporterNodeId'] as String?,
      reporterNodeName: json['reporterNodeName'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      snr: (json['snr'] as num?)?.toDouble(),
      rssi: (json['rssi'] as num?)?.toDouble(),
      estimatedDistance: (json['estimatedDistance'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      receivedAt: (json['receivedAt'] as Timestamp).toDate(),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'aetherFlightId': aetherFlightId,
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
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Live flight position from tracking API
class FlightPosition {
  final String callsign;
  final double latitude;
  final double longitude;
  final double altitude; // meters
  final double velocity; // m/s
  final double heading; // degrees
  final bool onGround;
  final DateTime lastUpdate;

  const FlightPosition({
    required this.callsign,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.velocity,
    required this.heading,
    required this.onGround,
    required this.lastUpdate,
  });

  /// Altitude in feet
  double get altitudeFeet => altitude * 3.28084;

  /// Velocity in knots
  double get velocityKnots => velocity * 1.94384;

  /// Estimated radio horizon in km (assuming 915MHz LoRa)
  /// Formula: d = 3.57 * sqrt(h) where h is in meters
  double get radioHorizonKm => 3.57 * math.sqrt(altitude > 0 ? altitude : 1);

  /// Estimated coverage radius in km (more conservative)
  double get coverageRadiusKm => radioHorizonKm * 0.8;
}
