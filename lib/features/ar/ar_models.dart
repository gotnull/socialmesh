import 'dart:math' as math;

import '../../models/mesh_models.dart';

/// Represents a node's position in AR space
class ARNode {
  final MeshNode node;
  final double distance; // meters
  final double bearing; // degrees from north (0-360)
  final double elevation; // degrees (-90 to 90)
  final double signalQuality; // 0-1

  const ARNode({
    required this.node,
    required this.distance,
    required this.bearing,
    required this.elevation,
    required this.signalQuality,
  });

  /// Calculate screen position based on device orientation
  /// Returns null if node is behind the camera
  ARScreenPosition? toScreenPosition({
    required double deviceHeading, // compass heading
    required double devicePitch, // tilt up/down
    required double deviceRoll, // tilt left/right
    required double fovHorizontal, // camera field of view
    required double fovVertical,
    required double screenWidth,
    required double screenHeight,
  }) {
    // Calculate horizontal angle relative to where camera is pointing
    double relativeAngle = bearing - deviceHeading;

    // Normalize to -180 to 180
    while (relativeAngle > 180) {
      relativeAngle -= 360;
    }
    while (relativeAngle < -180) {
      relativeAngle += 360;
    }

    // Check if within horizontal field of view
    final halfFovH = fovHorizontal / 2;
    if (relativeAngle.abs() > halfFovH + 20) {
      // +20 for edge indicators
      return null;
    }

    // Calculate vertical angle relative to camera pitch
    final relativeElevation = elevation - devicePitch;

    // Check if within vertical field of view
    final halfFovV = fovVertical / 2;
    final isInView =
        relativeAngle.abs() <= halfFovH && relativeElevation.abs() <= halfFovV;

    // Map to screen coordinates
    // Center of screen = camera direction
    final x = screenWidth / 2 + (relativeAngle / halfFovH) * (screenWidth / 2);
    final y =
        screenHeight / 2 - (relativeElevation / halfFovV) * (screenHeight / 2);

    // Calculate visual size based on distance (closer = bigger)
    final baseSize = 60.0;
    final size = (baseSize * 100 / (distance + 50)).clamp(30.0, 120.0);

    // Calculate opacity based on distance
    final opacity = (1.0 - (distance / 50000)).clamp(0.3, 1.0);

    return ARScreenPosition(
      x: x,
      y: y,
      size: size,
      opacity: opacity,
      isInView: isInView,
      isOnLeft: relativeAngle < -halfFovH,
      isOnRight: relativeAngle > halfFovH,
      relativeAngle: relativeAngle,
    );
  }

  /// Format distance for display
  String get formattedDistance {
    if (distance < 1000) {
      return '${distance.round()}m';
    } else if (distance < 10000) {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    } else {
      return '${(distance / 1000).round()}km';
    }
  }

  /// Get compass direction string
  String get compassDirection {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) / 45).floor() % 8;
    return directions[index];
  }
}

/// Screen position for an AR element
class ARScreenPosition {
  final double x;
  final double y;
  final double size;
  final double opacity;
  final bool isInView;
  final bool isOnLeft;
  final bool isOnRight;
  final double relativeAngle;

  const ARScreenPosition({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.isInView,
    required this.isOnLeft,
    required this.isOnRight,
    required this.relativeAngle,
  });
}

/// Device orientation data for AR
/// Named ARDeviceOrientation to avoid conflict with Flutter's DeviceOrientation
class ARDeviceOrientation {
  final double heading; // compass heading (0-360, 0=north)
  final double pitch; // tilt forward/back (-90 to 90)
  final double roll; // tilt left/right (-180 to 180)

  const ARDeviceOrientation({
    required this.heading,
    required this.pitch,
    required this.roll,
  });

  static const zero = ARDeviceOrientation(heading: 0, pitch: 0, roll: 0);
}

/// AR View configuration
class ARConfig {
  final double horizontalFov;
  final double verticalFov;
  final double maxDisplayDistance; // meters
  final bool showOffscreenIndicators;
  final bool showDistanceLabels;
  final bool showSignalStrength;
  final ARSortMode sortMode;

  const ARConfig({
    this.horizontalFov = 60.0,
    this.verticalFov = 90.0,
    this.maxDisplayDistance = 50000, // 50km
    this.showOffscreenIndicators = true,
    this.showDistanceLabels = true,
    this.showSignalStrength = true,
    this.sortMode = ARSortMode.distance,
  });
}

enum ARSortMode { distance, signalStrength, name, lastHeard }

/// Calculate bearing between two GPS coordinates
double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
  final dLon = _toRadians(lon2 - lon1);
  final lat1Rad = _toRadians(lat1);
  final lat2Rad = _toRadians(lat2);

  final y = math.sin(dLon) * math.cos(lat2Rad);
  final x =
      math.cos(lat1Rad) * math.sin(lat2Rad) -
      math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);

  var bearing = math.atan2(y, x);
  bearing = _toDegrees(bearing);
  bearing = (bearing + 360) % 360;

  return bearing;
}

/// Calculate distance between two GPS coordinates (Haversine formula)
double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0; // meters

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

/// Calculate elevation angle to a point
double calculateElevation(double distance, double altitudeDifference) {
  if (distance == 0) return 0;
  return _toDegrees(math.atan2(altitudeDifference, distance));
}

double _toRadians(double degrees) => degrees * math.pi / 180;
double _toDegrees(double radians) => radians * 180 / math.pi;
