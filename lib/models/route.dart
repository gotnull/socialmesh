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
        _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) *
            _cos(_toRadians(lat2)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return r * c;
  }

  static double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;
  static double _sin(double x) => _taylorSin(x);
  static double _cos(double x) => _taylorSin(x + 1.5707963267948966);
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 1.5707963267948966;
    if (x == 0 && y < 0) return -1.5707963267948966;
    return 0;
  }

  static double _atan(double x) {
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * 1.5707963267948966 - _atan(1 / x);
    }
    double result = 0;
    double term = x;
    for (int n = 0; n < 20; n++) {
      result += term / (2 * n + 1);
      term *= -x * x;
    }
    return result;
  }

  static double _taylorSin(double x) {
    // Normalize to -pi to pi
    while (x > 3.141592653589793) {
      x -= 2 * 3.141592653589793;
    }
    while (x < -3.141592653589793) {
      x += 2 * 3.141592653589793;
    }
    double result = 0;
    double term = x;
    for (int n = 0; n < 10; n++) {
      result += term;
      term *= -x * x / ((2 * n + 2) * (2 * n + 3));
    }
    return result;
  }
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
