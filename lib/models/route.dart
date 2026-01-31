// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'package:uuid/uuid.dart';

/// Route for tracking GPS paths
class Route {
  final String id;
  final String name;
  final String? notes;
  final DateTime createdAt;
  final DateTime? endedAt;
  final int color;
  final bool enabled;
  final List<RouteLocation> locations;

  Route({
    String? id,
    required this.name,
    this.notes,
    DateTime? createdAt,
    this.endedAt,
    this.color = 0xFF33C758,
    this.enabled = true,
    this.locations = const [],
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  /// Total distance in meters
  double get totalDistance {
    if (locations.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < locations.length; i++) {
      total += _haversineDistance(
        locations[i - 1].latitude,
        locations[i - 1].longitude,
        locations[i].latitude,
        locations[i].longitude,
      );
    }
    return total;
  }

  /// Duration of the route
  Duration? get duration {
    if (endedAt == null) return null;
    return endedAt!.difference(createdAt);
  }

  /// Total elevation gain in meters
  double get elevationGain {
    if (locations.length < 2) return 0;
    double gain = 0;
    for (int i = 1; i < locations.length; i++) {
      final prev = locations[i - 1].altitude ?? 0;
      final curr = locations[i].altitude ?? 0;
      if (curr > prev) {
        gain += curr - prev;
      }
    }
    return gain;
  }

  /// Get the center point of the route (for map centering)
  ({double lat, double lon})? get center {
    if (locations.isEmpty) return null;
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLon = double.infinity;
    double maxLon = -double.infinity;
    for (final loc in locations) {
      if (loc.latitude < minLat) minLat = loc.latitude;
      if (loc.latitude > maxLat) maxLat = loc.latitude;
      if (loc.longitude < minLon) minLon = loc.longitude;
      if (loc.longitude > maxLon) maxLon = loc.longitude;
    }
    return (lat: (minLat + maxLat) / 2, lon: (minLon + maxLon) / 2);
  }

  Route copyWith({
    String? id,
    String? name,
    String? notes,
    DateTime? createdAt,
    DateTime? endedAt,
    int? color,
    bool? enabled,
    List<RouteLocation>? locations,
  }) {
    return Route(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      endedAt: endedAt ?? this.endedAt,
      color: color ?? this.color,
      enabled: enabled ?? this.enabled,
      locations: locations ?? this.locations,
    );
  }

  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      id: json['id'] as String?,
      name: json['name'] as String,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['endedAt'] as int)
          : null,
      color: json['color'] as int? ?? 0xFF33C758,
      enabled: json['enabled'] as bool? ?? true,
      locations:
          (json['locations'] as List?)
              ?.map((l) => RouteLocation.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'notes': notes,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'endedAt': endedAt?.millisecondsSinceEpoch,
    'color': color,
    'enabled': enabled,
    'locations': locations.map((l) => l.toJson()).toList(),
  };

  /// Haversine formula for accurate distance calculation
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0; // Earth's radius in meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}

/// Location point in a route
class RouteLocation {
  final String id;
  final double latitude;
  final double longitude;
  final int? altitude;
  final int? heading;
  final int? speed;
  final DateTime timestamp;

  RouteLocation({
    String? id,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.heading,
    this.speed,
    DateTime? timestamp,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  factory RouteLocation.fromJson(Map<String, dynamic> json) {
    return RouteLocation(
      id: json['id'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: json['altitude'] as int?,
      heading: json['heading'] as int?,
      speed: json['speed'] as int?,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    'heading': heading,
    'speed': speed,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };
}
