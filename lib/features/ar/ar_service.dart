import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../models/mesh_models.dart';
import 'ar_models.dart';

/// Service that handles AR calculations and sensor fusion
class ARService {
  // Sensor subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  StreamSubscription<MagnetometerEvent>? _magnetometerSub;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSub;

  // Sensor data
  List<double> _accelerometer = [0, 0, 0];
  List<double> _magnetometer = [0, 0, 0];

  // Smoothed orientation
  double _heading = 0;
  double _pitch = 0;
  double _roll = 0;

  // Low-pass filter coefficient (0-1, higher = more smoothing)
  static const double _smoothingFactor = 0.15;

  // User's current position
  Position? _userPosition;
  StreamSubscription<Position>? _positionSub;

  // Orientation stream
  final _orientationController =
      StreamController<ARDeviceOrientation>.broadcast();
  Stream<ARDeviceOrientation> get orientationStream =>
      _orientationController.stream;

  // Position stream
  final _positionController = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  // Current state
  bool _isRunning = false;
  bool _isDisposed = false;
  bool get isRunning => _isRunning;
  Position? get userPosition => _userPosition;
  ARDeviceOrientation get currentOrientation =>
      ARDeviceOrientation(heading: _heading, pitch: _pitch, roll: _roll);

  /// Start AR sensors
  Future<void> start() async {
    if (_isRunning) return;

    debugPrint('[AR] Starting AR sensors...');

    try {
      // Start accelerometer
      _accelerometerSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 20),
      ).listen(_onAccelerometer);

      // Start magnetometer (compass)
      _magnetometerSub = magnetometerEventStream(
        samplingPeriod: const Duration(milliseconds: 20),
      ).listen(_onMagnetometer);

      // Start gyroscope for smooth rotation
      _gyroscopeSub = gyroscopeEventStream(
        samplingPeriod: const Duration(milliseconds: 20),
      ).listen(_onGyroscope);

      // Start GPS
      await _startLocationUpdates();

      _isRunning = true;
      debugPrint('[AR] AR sensors started');
    } catch (e) {
      debugPrint('[AR] Failed to start sensors: $e');
      rethrow;
    }
  }

  /// Stop AR sensors
  void stop() {
    debugPrint('[AR] Stopping AR sensors...');

    _accelerometerSub?.cancel();
    _magnetometerSub?.cancel();
    _gyroscopeSub?.cancel();
    _positionSub?.cancel();

    _accelerometerSub = null;
    _magnetometerSub = null;
    _gyroscopeSub = null;
    _positionSub = null;

    _isRunning = false;
    debugPrint('[AR] AR sensors stopped');
  }

  /// Dispose of resources
  void dispose() {
    _isDisposed = true;
    stop();
    _orientationController.close();
    _positionController.close();
  }

  Future<void> _startLocationUpdates() async {
    // Check permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('[AR] Location permission denied');
      return;
    }

    // Get initial position
    try {
      _userPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _positionController.add(_userPosition!);
    } catch (e) {
      debugPrint('[AR] Failed to get initial position: $e');
    }

    // Listen for updates
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5, // Update every 5 meters
          ),
        ).listen((position) {
          if (_isDisposed || !_isRunning) return;
          _userPosition = position;
          _positionController.add(position);
        });
  }

  void _onAccelerometer(AccelerometerEvent event) {
    if (_isDisposed || !_isRunning) return;
    _accelerometer = [event.x, event.y, event.z];
    _updateOrientation();
  }

  void _onMagnetometer(MagnetometerEvent event) {
    if (_isDisposed || !_isRunning) return;
    _magnetometer = [event.x, event.y, event.z];
    _updateOrientation();
  }

  void _onGyroscope(GyroscopeEvent event) {
    // Gyroscope data reserved for future enhanced sensor fusion
    // Currently unused but subscription kept active for smooth transition
    // to more sophisticated orientation algorithms
  }

  void _updateOrientation() {
    // Calculate pitch and roll from accelerometer
    final ax = _accelerometer[0];
    final ay = _accelerometer[1];
    final az = _accelerometer[2];

    // Pitch: rotation around X axis (tilt forward/back)
    final rawPitch = math.atan2(-ax, math.sqrt(ay * ay + az * az));

    // Roll: rotation around Y axis (tilt left/right)
    final rawRoll = math.atan2(ay, az);

    // Calculate heading from magnetometer (compensated for tilt)
    final mx = _magnetometer[0];
    final my = _magnetometer[1];
    final mz = _magnetometer[2];

    // Tilt compensation
    final cosRoll = math.cos(rawRoll);
    final sinRoll = math.sin(rawRoll);
    final cosPitch = math.cos(rawPitch);
    final sinPitch = math.sin(rawPitch);

    final xH =
        mx * cosPitch + my * sinRoll * sinPitch + mz * cosRoll * sinPitch;
    final yH = my * cosRoll - mz * sinRoll;

    var rawHeading = math.atan2(-yH, xH);
    rawHeading = rawHeading * 180 / math.pi;
    if (rawHeading < 0) rawHeading += 360;

    // Convert pitch and roll to degrees
    final pitchDeg = rawPitch * 180 / math.pi;
    final rollDeg = rawRoll * 180 / math.pi;

    // Apply low-pass filter for smooth animation
    _heading = _lowPassFilter(
      _heading,
      rawHeading,
      _smoothingFactor,
      wrap: 360,
    );
    _pitch = _lowPassFilter(_pitch, pitchDeg, _smoothingFactor);
    _roll = _lowPassFilter(_roll, rollDeg, _smoothingFactor);

    // Emit updated orientation
    _orientationController.add(
      ARDeviceOrientation(heading: _heading, pitch: _pitch, roll: _roll),
    );
  }

  /// Low-pass filter with optional wrap-around for angles
  double _lowPassFilter(
    double current,
    double target,
    double factor, {
    double? wrap,
  }) {
    if (wrap != null) {
      // Handle wrap-around (e.g., 359° to 1°)
      var diff = target - current;
      if (diff > wrap / 2) diff -= wrap;
      if (diff < -wrap / 2) diff += wrap;
      var result = current + diff * factor;
      if (result < 0) result += wrap;
      if (result >= wrap) result -= wrap;
      return result;
    }
    return current + (target - current) * factor;
  }

  /// Convert mesh nodes to AR nodes relative to user position
  List<ARNode> calculateARNodes(List<MeshNode> nodes, {double? userAltitude}) {
    if (_userPosition == null) return [];

    final userLat = _userPosition!.latitude;
    final userLon = _userPosition!.longitude;
    final userAlt = userAltitude ?? _userPosition!.altitude;

    final arNodes = <ARNode>[];

    for (final node in nodes) {
      // Skip nodes without position
      if (node.latitude == null ||
          node.longitude == null ||
          node.latitude == 0 ||
          node.longitude == 0) {
        continue;
      }

      final nodeLat = node.latitude!;
      final nodeLon = node.longitude!;
      final nodeAlt = node.altitude?.toDouble() ?? userAlt;

      // Calculate distance
      final distance = calculateDistance(userLat, userLon, nodeLat, nodeLon);

      // Calculate bearing
      final bearing = calculateBearing(userLat, userLon, nodeLat, nodeLon);

      // Calculate elevation angle
      final altDiff = nodeAlt - userAlt;
      final elevation = calculateElevation(distance, altDiff);

      // Calculate signal quality (0-1)
      // Based on SNR if available, otherwise use distance
      double signalQuality = 0.5;
      if (node.snr != null) {
        // SNR typically ranges from -20 to 10 dB
        signalQuality = ((node.snr! + 20) / 30).clamp(0.0, 1.0);
      } else {
        // Estimate based on distance (closer = better)
        signalQuality = (1.0 - distance / 50000).clamp(0.1, 1.0);
      }

      arNodes.add(
        ARNode(
          node: node,
          distance: distance,
          bearing: bearing,
          elevation: elevation,
          signalQuality: signalQuality,
        ),
      );
    }

    // Sort by distance (closest first)
    arNodes.sort((a, b) => a.distance.compareTo(b.distance));

    return arNodes;
  }

  /// Get permission status for AR features
  static Future<ARPermissionStatus> checkPermissions() async {
    // Check location permission
    final locationPermission = await Geolocator.checkPermission();
    final hasLocation =
        locationPermission == LocationPermission.always ||
        locationPermission == LocationPermission.whileInUse;

    // Check if location services are enabled
    final locationEnabled = await Geolocator.isLocationServiceEnabled();

    return ARPermissionStatus(
      hasLocationPermission: hasLocation,
      locationServicesEnabled: locationEnabled,
    );
  }

  /// Request necessary permissions
  static Future<bool> requestPermissions() async {
    // Request location
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    // Check if location services are enabled
    final locationEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationEnabled) {
      // Could prompt user to enable location services
      return false;
    }

    return true;
  }
}

class ARPermissionStatus {
  final bool hasLocationPermission;
  final bool locationServicesEnabled;

  const ARPermissionStatus({
    required this.hasLocationPermission,
    required this.locationServicesEnabled,
  });

  bool get isFullyGranted => hasLocationPermission && locationServicesEnabled;
}
