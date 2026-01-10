import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../core/logging.dart';
import '../../models/mesh_models.dart';
import 'ar_calibration.dart';

/// Production-grade AR Engine with advanced sensor fusion,
/// Kalman filtering, and predictive tracking
class AREngine {
  // ═══════════════════════════════════════════════════════════════════════════
  // CALIBRATION & SMOOTHING
  // ═══════════════════════════════════════════════════════════════════════════
  final ARCalibrationService _calibration = ARCalibrationService();
  final HeadingStabilizer _headingStabilizer = HeadingStabilizer();
  final Map<int, MarkerSmoother> _markerSmoothers = {};

  ARCalibrationState get calibrationState => _calibration.state;

  // ═══════════════════════════════════════════════════════════════════════════
  // SENSOR SUBSCRIPTIONS
  // ═══════════════════════════════════════════════════════════════════════════
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  StreamSubscription<MagnetometerEvent>? _magnetometerSub;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSub;
  StreamSubscription<Position>? _positionSub;

  // ═══════════════════════════════════════════════════════════════════════════
  // KALMAN FILTER STATE
  // ═══════════════════════════════════════════════════════════════════════════
  final _headingKalman = _KalmanFilter1D(
    processNoise: 0.01,
    measurementNoise: 0.1,
    estimatedError: 1.0,
  );
  final _pitchKalman = _KalmanFilter1D(
    processNoise: 0.01,
    measurementNoise: 0.1,
    estimatedError: 1.0,
  );
  final _rollKalman = _KalmanFilter1D(
    processNoise: 0.01,
    measurementNoise: 0.1,
    estimatedError: 1.0,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // SENSOR DATA
  // ═══════════════════════════════════════════════════════════════════════════
  vm.Vector3 _accelerometer = vm.Vector3.zero();
  vm.Vector3 _magnetometer = vm.Vector3.zero();
  DateTime _lastGyroUpdate = DateTime.now();

  // Fused orientation (Euler angles in degrees)
  double _heading = 0;
  double _pitch = 0;
  double _roll = 0;

  // Gyroscope-integrated orientation (for smooth interpolation)
  double _gyroHeading = 0;
  double _gyroPitch = 0;
  double _gyroRoll = 0;

  // Complementary filter weight (0-1, higher = more gyro trust)
  static const double _gyroWeight = 0.98;
  static const double _accelMagWeight = 1.0 - _gyroWeight;

  // ═══════════════════════════════════════════════════════════════════════════
  // POSITION TRACKING
  // ═══════════════════════════════════════════════════════════════════════════
  Position? _userPosition;
  final List<_PositionSample> _positionHistory = [];
  static const int _maxPositionHistory = 100;

  // Velocity estimation for smooth GPS interpolation
  double _velocityNorth = 0; // m/s
  double _velocityEast = 0; // m/s
  DateTime _lastPositionUpdate = DateTime.now();

  // ═══════════════════════════════════════════════════════════════════════════
  // NODE TRACKING
  // ═══════════════════════════════════════════════════════════════════════════
  final Map<int, _TrackedNode> _trackedNodes = {};
  final List<ARNodeCluster> _clusters = [];

  // ═══════════════════════════════════════════════════════════════════════════
  // OUTPUT STREAMS
  // ═══════════════════════════════════════════════════════════════════════════
  final _orientationController = StreamController<AROrientation>.broadcast();
  final _positionController = StreamController<ARPosition>.broadcast();
  final _nodesController = StreamController<List<ARWorldNode>>.broadcast();
  final _clustersController = StreamController<List<ARNodeCluster>>.broadcast();
  final _alertsController = StreamController<List<ARAlert>>.broadcast();

  Stream<AROrientation> get orientationStream => _orientationController.stream;
  Stream<ARPosition> get positionStream => _positionController.stream;
  Stream<List<ARWorldNode>> get nodesStream => _nodesController.stream;
  Stream<List<ARNodeCluster>> get clustersStream => _clustersController.stream;
  Stream<List<ARAlert>> get alertsStream => _alertsController.stream;
  Stream<ARCalibrationState> get calibrationStream => _calibration.stateStream;

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════════════════════════
  bool _isRunning = false;
  bool _isDisposed = false;
  Timer? _updateTimer;
  Timer? _alertTimer;

  bool get isRunning => _isRunning;
  Position? get userPosition => _userPosition;

  AROrientation get currentOrientation => AROrientation(
    heading: _heading,
    pitch: _pitch,
    roll: _roll,
    accuracy: _calculateOrientationAccuracy(),
    timestamp: DateTime.now(),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> start() async {
    if (_isRunning || _isDisposed) return;

    AppLogging.app('[AREngine] Starting...');

    try {
      // Initialize calibration service
      await _calibration.initialize();
      AppLogging.app(
        '[AREngine] Calibration initialized - FOV: ${_calibration.state.horizontalFov.toStringAsFixed(1)}°×${_calibration.state.verticalFov.toStringAsFixed(1)}°',
      );

      // Start high-frequency sensor streams
      _accelerometerSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 16), // ~60Hz
      ).listen(_onAccelerometer);

      _magnetometerSub = magnetometerEventStream(
        samplingPeriod: const Duration(milliseconds: 16),
      ).listen(_onMagnetometer);

      _gyroscopeSub = gyroscopeEventStream(
        samplingPeriod: const Duration(milliseconds: 16),
      ).listen(_onGyroscope);

      // Start GPS
      await _startLocationUpdates();

      // Start update loop for smooth interpolation
      _updateTimer = Timer.periodic(
        const Duration(milliseconds: 16), // 60 FPS
        (_) => _update(),
      );

      // Start alert monitoring
      _alertTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _checkAlerts(),
      );

      _isRunning = true;
      AppLogging.app('[AREngine] Started successfully');
    } catch (e) {
      AppLogging.app('[AREngine] Failed to start: $e');
      rethrow;
    }
  }

  void stop() {
    if (!_isRunning) return;

    AppLogging.app('[AREngine] Stopping...');

    _accelerometerSub?.cancel();
    _magnetometerSub?.cancel();
    _gyroscopeSub?.cancel();
    _positionSub?.cancel();
    _updateTimer?.cancel();
    _alertTimer?.cancel();

    _accelerometerSub = null;
    _magnetometerSub = null;
    _gyroscopeSub = null;
    _positionSub = null;
    _updateTimer = null;
    _alertTimer = null;

    _isRunning = false;
    AppLogging.app('[AREngine] Stopped');
  }

  void dispose() {
    _isDisposed = true;
    stop();
    _calibration.dispose();
    _orientationController.close();
    _positionController.close();
    _nodesController.close();
    _clustersController.close();
    _alertsController.close();
  }

  /// Start compass calibration process
  void startCompassCalibration() {
    if (!_isRunning) return;
    _calibration.startCompassCalibration();
  }

  /// Cancel compass calibration
  void cancelCompassCalibration() {
    _calibration.cancelCompassCalibration();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SENSOR CALLBACKS
  // ═══════════════════════════════════════════════════════════════════════════

  void _onAccelerometer(AccelerometerEvent event) {
    if (_isDisposed || !_isRunning) return;
    _accelerometer = vm.Vector3(event.x, event.y, event.z);
  }

  void _onMagnetometer(MagnetometerEvent event) {
    if (_isDisposed || !_isRunning) return;
    _magnetometer = vm.Vector3(event.x, event.y, event.z);
  }

  void _onGyroscope(GyroscopeEvent event) {
    if (_isDisposed || !_isRunning) return;

    final now = DateTime.now();
    final dt = now.difference(_lastGyroUpdate).inMicroseconds / 1000000.0;
    _lastGyroUpdate = now;

    if (dt > 0 && dt < 0.1) {
      // Integrate gyroscope for high-frequency updates
      _gyroHeading += event.z * dt * 180 / math.pi;
      _gyroPitch += event.x * dt * 180 / math.pi;
      _gyroRoll += event.y * dt * 180 / math.pi;

      // Normalize heading
      while (_gyroHeading >= 360) {
        _gyroHeading -= 360;
      }
      while (_gyroHeading < 0) {
        _gyroHeading += 360;
      }

      // Clamp pitch and roll
      _gyroPitch = _gyroPitch.clamp(-90.0, 90.0);
      _gyroRoll = _gyroRoll.clamp(-180.0, 180.0);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UPDATE LOOP
  // ═══════════════════════════════════════════════════════════════════════════

  void _update() {
    if (_isDisposed || !_isRunning) return;

    _updateOrientation();
    _interpolatePosition();
    _emitState();
  }

  void _updateOrientation() {
    // Calculate orientation from accelerometer + magnetometer
    final accelMagOrientation = _calculateAccelMagOrientation();

    // Complementary filter: blend gyro-integrated with accel/mag
    final blendedHeading = _blendAngles(
      _gyroHeading,
      accelMagOrientation.heading,
      _gyroWeight,
    );
    final blendedPitch =
        _gyroPitch * _gyroWeight + accelMagOrientation.pitch * _accelMagWeight;
    final blendedRoll =
        _gyroRoll * _gyroWeight + accelMagOrientation.roll * _accelMagWeight;

    // Sync gyro values to prevent drift
    _gyroHeading = blendedHeading;
    _gyroPitch = blendedPitch;
    _gyroRoll = blendedRoll;

    // Apply Kalman filter for final output
    var filteredHeading = _headingKalman.update(blendedHeading);
    _pitch = _pitchKalman.update(blendedPitch);
    _roll = _rollKalman.update(blendedRoll);

    // Apply heading stabilization to prevent jitter
    _heading = _headingStabilizer.stabilize(filteredHeading);

    // Normalize heading
    while (_heading >= 360) {
      _heading -= 360;
    }
    while (_heading < 0) {
      _heading += 360;
    }
  }

  _RawOrientation _calculateAccelMagOrientation() {
    final ax = _accelerometer.x;
    final ay = _accelerometer.y;
    final az = _accelerometer.z;

    // Calculate pitch and roll from accelerometer
    final pitch = math.atan2(-ax, math.sqrt(ay * ay + az * az));
    final roll = math.atan2(ay, az);

    // Tilt-compensated heading from magnetometer
    final mx = _magnetometer.x;
    final my = _magnetometer.y;
    final mz = _magnetometer.z;

    final cosRoll = math.cos(roll);
    final sinRoll = math.sin(roll);
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);

    final xH =
        mx * cosPitch + my * sinRoll * sinPitch + mz * cosRoll * sinPitch;
    final yH = my * cosRoll - mz * sinRoll;

    var heading = math.atan2(-yH, xH) * 180 / math.pi;
    if (heading < 0) heading += 360;

    return _RawOrientation(
      heading: heading,
      pitch: pitch * 180 / math.pi,
      roll: roll * 180 / math.pi,
    );
  }

  double _blendAngles(double a, double b, double weightA) {
    // Handle wrap-around for angles
    var diff = b - a;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    var result = a + diff * (1.0 - weightA);
    while (result >= 360) {
      result -= 360;
    }
    while (result < 0) {
      result += 360;
    }

    return result;
  }

  void _interpolatePosition() {
    if (_userPosition == null) return;

    // Interpolate position between GPS updates for smoother tracking
    // Note: Position interpolation is handled implicitly through velocity tracking
    // in the node processing pipeline. This method serves as a hook for
    // future enhancements like dead reckoning with accelerometer data.
  }

  void _emitState() {
    if (_isDisposed) return;

    _orientationController.add(
      AROrientation(
        heading: _heading,
        pitch: _pitch,
        roll: _roll,
        accuracy: _calculateOrientationAccuracy(),
        timestamp: DateTime.now(),
      ),
    );

    if (_userPosition != null) {
      _positionController.add(
        ARPosition(
          latitude: _userPosition!.latitude,
          longitude: _userPosition!.longitude,
          altitude: _userPosition!.altitude,
          accuracy: _userPosition!.accuracy,
          velocityNorth: _velocityNorth,
          velocityEast: _velocityEast,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  double _calculateOrientationAccuracy() {
    // Estimate orientation accuracy based on sensor data quality
    final accelMag = _accelerometer.length;
    final magMag = _magnetometer.length;

    // Good accelerometer should read ~9.8 m/s²
    final accelQuality = 1.0 - (accelMag - 9.8).abs() / 9.8;

    // Good magnetometer should read ~25-65 µT
    final magQuality = magMag > 20 && magMag < 70 ? 1.0 : 0.5;

    return (accelQuality * 0.5 + magQuality * 0.5).clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOCATION TRACKING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _startLocationUpdates() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      AppLogging.app('[AREngine] Location permission denied');
      return;
    }

    // Get initial position
    try {
      _userPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      _lastPositionUpdate = DateTime.now();
    } catch (e) {
      AppLogging.app('[AREngine] Failed to get initial position: $e');
    }

    // High-accuracy position stream
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 1, // Update every meter
          ),
        ).listen(
          _onPosition,
          onError: (error) {
            AppLogging.app('[AREngine] Position stream error: $error');
          },
          cancelOnError: false,
        );
  }

  void _onPosition(Position position) {
    if (_isDisposed || !_isRunning) return;

    final now = DateTime.now();

    // Calculate velocity if we have previous position
    if (_userPosition != null) {
      final dt = now.difference(_lastPositionUpdate).inMilliseconds / 1000.0;
      if (dt > 0 && dt < 10) {
        // Calculate distance moved
        final dLat = position.latitude - _userPosition!.latitude;
        final dLon = position.longitude - _userPosition!.longitude;

        // Convert to meters
        final dNorth = dLat * 111320.0;
        final dEast =
            dLon * 111320.0 * math.cos(position.latitude * math.pi / 180);

        // Calculate velocity
        _velocityNorth = dNorth / dt;
        _velocityEast = dEast / dt;
      }
    }

    _userPosition = position;
    _lastPositionUpdate = now;

    // Update magnetic declination for this location
    _calibration.updateMagneticDeclination(
      position.latitude,
      position.longitude,
    );

    // Update GPS accuracy status
    _calibration.updateGpsStatus(position.accuracy);

    // Store in history
    _positionHistory.add(_PositionSample(position: position, timestamp: now));

    // Trim history
    while (_positionHistory.length > _maxPositionHistory) {
      _positionHistory.removeAt(0);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NODE PROCESSING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Process mesh nodes into AR world nodes with tracking data
  List<ARWorldNode> processNodes(
    List<MeshNode> nodes, {
    AREngineConfig? config,
  }) {
    if (_userPosition == null) return [];

    final cfg = config ?? const AREngineConfig();
    final result = <ARWorldNode>[];

    // Use calibrated FOV if available and config uses defaults
    final hFov = cfg.horizontalFov == 60
        ? _calibration.state.horizontalFov
        : cfg.horizontalFov;
    final vFov = cfg.verticalFov == 90
        ? _calibration.state.verticalFov
        : cfg.verticalFov;

    // Apply magnetic declination to heading for accurate bearing calculations
    final correctedHeading = _heading + _calibration.state.magneticDeclination;

    for (final node in nodes) {
      if (node.latitude == null ||
          node.longitude == null ||
          node.latitude == 0 ||
          node.longitude == 0) {
        continue;
      }

      // Get or create tracked node
      var tracked = _trackedNodes[node.nodeNum];
      if (tracked == null) {
        tracked = _TrackedNode(nodeNum: node.nodeNum);
        _trackedNodes[node.nodeNum] = tracked;
      }

      // Update tracking
      tracked.update(node);

      // Calculate world position relative to user
      final worldPos = _calculateWorldPosition(
        node.latitude!,
        node.longitude!,
        node.altitude?.toDouble() ?? _userPosition!.altitude,
      );

      // Apply distance filter
      if (worldPos.distance > cfg.maxDistance) continue;

      // Calculate screen position with calibrated FOV
      var screenPos = _calculateScreenPositionWithHeading(
        worldPos,
        hFov,
        vFov,
        correctedHeading,
      );

      // Apply marker smoothing to reduce jitter
      var smoother = _markerSmoothers[node.nodeNum];
      if (smoother == null) {
        smoother = MarkerSmoother();
        _markerSmoothers[node.nodeNum] = smoother;
      }
      final smoothed = smoother.smooth(
        node.nodeNum,
        screenPos.normalizedX,
        screenPos.normalizedY,
      );
      screenPos = screenPos.copyWithPosition(smoothed.x, smoothed.y);

      // Calculate threat level
      final threatLevel = _calculateThreatLevel(node, tracked);

      result.add(
        ARWorldNode(
          node: node,
          worldPosition: worldPos,
          screenPosition: screenPos,
          velocity: tracked.velocity,
          predictedPosition: tracked.predictedPosition,
          threatLevel: threatLevel,
          signalQuality: _calculateSignalQuality(node),
          isNew: tracked.isNew,
          isMoving: tracked.isMoving,
          track: tracked.positionHistory
              .map(
                (p) =>
                    ARTrackPoint(position: p.position, timestamp: p.timestamp),
              )
              .toList(),
        ),
      );
    }

    // Sort by distance
    result.sort(
      (a, b) => a.worldPosition.distance.compareTo(b.worldPosition.distance),
    );

    // Cluster nearby nodes
    _clusters.clear();
    _clusterNodes(result, cfg.clusterRadius);

    // Emit updates
    _nodesController.add(result);
    _clustersController.add(_clusters);

    return result;
  }

  ARWorldPosition _calculateWorldPosition(double lat, double lon, double alt) {
    final userLat = _userPosition!.latitude;
    final userLon = _userPosition!.longitude;
    final userAlt = _userPosition!.altitude;

    // Calculate distance using Haversine
    final distance = _haversineDistance(userLat, userLon, lat, lon);

    // Calculate bearing
    final bearing = _calculateBearing(userLat, userLon, lat, lon);

    // Calculate elevation angle
    final altDiff = alt - userAlt;
    final elevation = math.atan2(altDiff, distance) * 180 / math.pi;

    // Calculate 3D position in local coordinates (ENU - East, North, Up)
    final bearingRad = bearing * math.pi / 180;
    final east = distance * math.sin(bearingRad);
    final north = distance * math.cos(bearingRad);
    final up = altDiff;

    return ARWorldPosition(
      latitude: lat,
      longitude: lon,
      altitude: alt,
      distance: distance,
      bearing: bearing,
      elevation: elevation,
      localEast: east,
      localNorth: north,
      localUp: up,
    );
  }

  ARScreenPosition _calculateScreenPosition(
    ARWorldPosition worldPos,
    double fovH,
    double fovV,
  ) {
    // Calculate relative angle from current heading
    var relativeAngle = worldPos.bearing - _heading;
    while (relativeAngle > 180) {
      relativeAngle -= 360;
    }
    while (relativeAngle < -180) {
      relativeAngle += 360;
    }

    // Calculate relative elevation from current pitch
    final relativeElevation = worldPos.elevation - _pitch;

    // Check if in view
    final halfFovH = fovH / 2;
    final halfFovV = fovV / 2;
    final isInView =
        relativeAngle.abs() <= halfFovH && relativeElevation.abs() <= halfFovV;

    // Normalized screen position (-1 to 1)
    final normalizedX = relativeAngle / halfFovH;
    final normalizedY = -relativeElevation / halfFovV;

    // Calculate depth factor for perspective
    final depthFactor = 1.0 / (1.0 + worldPos.distance / 1000);

    // Calculate visual size
    final baseSize = 80.0;
    final size = (baseSize * depthFactor).clamp(20.0, 150.0);

    // Calculate opacity
    final opacity = (1.0 - worldPos.distance / 50000).clamp(0.3, 1.0);

    return ARScreenPosition(
      normalizedX: normalizedX,
      normalizedY: normalizedY,
      isInView: isInView,
      isOnLeft: relativeAngle < -halfFovH,
      isOnRight: relativeAngle > halfFovH,
      isAbove: relativeElevation > halfFovV,
      isBelow: relativeElevation < -halfFovV,
      relativeAngle: relativeAngle,
      relativeElevation: relativeElevation,
      depthFactor: depthFactor,
      size: size,
      opacity: opacity,
    );
  }

  /// Calculate screen position with explicit heading (for magnetic declination correction)
  ARScreenPosition _calculateScreenPositionWithHeading(
    ARWorldPosition worldPos,
    double fovH,
    double fovV,
    double heading,
  ) {
    // Calculate relative angle from corrected heading
    var relativeAngle = worldPos.bearing - heading;
    while (relativeAngle > 180) {
      relativeAngle -= 360;
    }
    while (relativeAngle < -180) {
      relativeAngle += 360;
    }

    // Calculate relative elevation from current pitch
    final relativeElevation = worldPos.elevation - _pitch;

    // Check if in view
    final halfFovH = fovH / 2;
    final halfFovV = fovV / 2;
    final isInView =
        relativeAngle.abs() <= halfFovH && relativeElevation.abs() <= halfFovV;

    // Normalized screen position (-1 to 1)
    final normalizedX = relativeAngle / halfFovH;
    final normalizedY = -relativeElevation / halfFovV;

    // Calculate depth factor for perspective
    final depthFactor = 1.0 / (1.0 + worldPos.distance / 1000);

    // Calculate visual size based on distance with better curve
    final baseSize = 80.0;
    final size = (baseSize * depthFactor).clamp(20.0, 150.0);

    // Calculate opacity based on distance
    final opacity = (1.0 - worldPos.distance / 50000).clamp(0.3, 1.0);

    return ARScreenPosition(
      normalizedX: normalizedX,
      normalizedY: normalizedY,
      isInView: isInView,
      isOnLeft: relativeAngle < -halfFovH,
      isOnRight: relativeAngle > halfFovH,
      isAbove: relativeElevation > halfFovV,
      isBelow: relativeElevation < -halfFovV,
      relativeAngle: relativeAngle,
      relativeElevation: relativeElevation,
      depthFactor: depthFactor,
      size: size,
      opacity: opacity,
    );
  }

  double _calculateSignalQuality(MeshNode node) {
    if (node.snr != null) {
      // SNR typically ranges from -20 to 10 dB
      return ((node.snr! + 20) / 30).clamp(0.0, 1.0);
    }
    if (node.rssi != null) {
      // RSSI typically ranges from -120 to -30 dBm
      return ((node.rssi! + 120) / 90).clamp(0.0, 1.0);
    }
    return 0.5;
  }

  ARThreatLevel _calculateThreatLevel(MeshNode node, _TrackedNode tracked) {
    // Check battery
    if (node.batteryLevel != null && node.batteryLevel! < 10) {
      return ARThreatLevel.critical;
    }
    if (node.batteryLevel != null && node.batteryLevel! < 25) {
      return ARThreatLevel.warning;
    }

    // Check if node went offline
    if (node.lastHeard != null) {
      final age = DateTime.now().difference(node.lastHeard!);
      if (age.inMinutes > 60) return ARThreatLevel.offline;
      if (age.inMinutes > 15) return ARThreatLevel.warning;
    }

    // Check if new node
    if (tracked.isNew) return ARThreatLevel.info;

    return ARThreatLevel.normal;
  }

  void _clusterNodes(List<ARWorldNode> nodes, double clusterRadius) {
    final clustered = <int>{};

    for (var i = 0; i < nodes.length; i++) {
      if (clustered.contains(i)) continue;

      final cluster = <ARWorldNode>[nodes[i]];
      clustered.add(i);

      for (var j = i + 1; j < nodes.length; j++) {
        if (clustered.contains(j)) continue;

        // Check if within cluster radius
        final dx =
            nodes[j].worldPosition.localEast - nodes[i].worldPosition.localEast;
        final dy =
            nodes[j].worldPosition.localNorth -
            nodes[i].worldPosition.localNorth;
        final dist = math.sqrt(dx * dx + dy * dy);

        if (dist < clusterRadius) {
          cluster.add(nodes[j]);
          clustered.add(j);
        }
      }

      if (cluster.length > 1) {
        // Calculate cluster center
        var sumLat = 0.0, sumLon = 0.0, sumAlt = 0.0;
        for (final n in cluster) {
          sumLat += n.worldPosition.latitude;
          sumLon += n.worldPosition.longitude;
          sumAlt += n.worldPosition.altitude;
        }
        final centerLat = sumLat / cluster.length;
        final centerLon = sumLon / cluster.length;
        final centerAlt = sumAlt / cluster.length;

        final centerWorld = _calculateWorldPosition(
          centerLat,
          centerLon,
          centerAlt,
        );
        final centerScreen = _calculateScreenPosition(centerWorld, 60, 90);

        _clusters.add(
          ARNodeCluster(
            nodes: cluster,
            centerPosition: centerWorld,
            screenPosition: centerScreen,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ALERT SYSTEM
  // ═══════════════════════════════════════════════════════════════════════════

  void _checkAlerts() {
    if (_isDisposed || !_isRunning) return;

    final alerts = <ARAlert>[];

    for (final tracked in _trackedNodes.values) {
      // New node discovered
      if (tracked.isNew && tracked.firstSeen != null) {
        final age = DateTime.now().difference(tracked.firstSeen!);
        if (age.inSeconds < 30) {
          alerts.add(
            ARAlert(
              type: ARAlertType.newNode,
              nodeNum: tracked.nodeNum,
              message: 'New node discovered',
              severity: ARAlertSeverity.info,
              timestamp: DateTime.now(),
            ),
          );
        }
      }

      // Node moving
      if (tracked.isMoving && tracked.velocity.length > 1.0) {
        alerts.add(
          ARAlert(
            type: ARAlertType.nodeMoving,
            nodeNum: tracked.nodeNum,
            message: 'Node in motion',
            severity: ARAlertSeverity.info,
            timestamp: DateTime.now(),
          ),
        );
      }

      // Low battery
      final lastNode = tracked.lastNode;
      if (lastNode?.batteryLevel != null && lastNode!.batteryLevel! < 20) {
        alerts.add(
          ARAlert(
            type: ARAlertType.lowBattery,
            nodeNum: tracked.nodeNum,
            message: 'Low battery: ${lastNode.batteryLevel}%',
            severity: lastNode.batteryLevel! < 10
                ? ARAlertSeverity.critical
                : ARAlertSeverity.warning,
            timestamp: DateTime.now(),
          ),
        );
      }
    }

    if (alerts.isNotEmpty) {
      _alertsController.add(alerts);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * math.pi / 180;
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2Rad);
    final x =
        math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);

    var bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SUPPORTING CLASSES
// ═══════════════════════════════════════════════════════════════════════════

/// 1D Kalman filter for smoothing sensor data
class _KalmanFilter1D {
  double _estimate = 0;
  double _errorEstimate;
  final double _processNoise;
  final double _measurementNoise;

  _KalmanFilter1D({
    required double processNoise,
    required double measurementNoise,
    required double estimatedError,
  }) : _processNoise = processNoise,
       _measurementNoise = measurementNoise,
       _errorEstimate = estimatedError;

  double update(double measurement) {
    // Prediction update
    _errorEstimate += _processNoise;

    // Measurement update
    final kalmanGain = _errorEstimate / (_errorEstimate + _measurementNoise);
    _estimate = _estimate + kalmanGain * (measurement - _estimate);
    _errorEstimate = (1 - kalmanGain) * _errorEstimate;

    return _estimate;
  }
}

class _RawOrientation {
  final double heading;
  final double pitch;
  final double roll;

  const _RawOrientation({
    required this.heading,
    required this.pitch,
    required this.roll,
  });
}

class _PositionSample {
  final Position position;
  final DateTime timestamp;

  const _PositionSample({required this.position, required this.timestamp});
}

/// Tracked node with history and prediction
class _TrackedNode {
  final int nodeNum;
  final List<_NodePositionSample> positionHistory = [];
  DateTime? firstSeen;
  MeshNode? lastNode;
  vm.Vector3 velocity = vm.Vector3.zero();
  vm.Vector3? predictedPosition;

  static const int _maxHistory = 50;
  static const Duration _newThreshold = Duration(minutes: 5);

  _TrackedNode({required this.nodeNum});

  bool get isNew =>
      firstSeen != null &&
      DateTime.now().difference(firstSeen!) < _newThreshold;

  bool get isMoving => velocity.length > 0.5; // m/s

  void update(MeshNode node) {
    final now = DateTime.now();

    // Set first seen
    firstSeen ??= now;
    lastNode = node;

    // Track position if available
    if (node.latitude != null &&
        node.longitude != null &&
        node.latitude != 0 &&
        node.longitude != 0) {
      final sample = _NodePositionSample(
        position: vm.Vector3(
          node.latitude!,
          node.longitude!,
          node.altitude?.toDouble() ?? 0,
        ),
        timestamp: now,
      );

      positionHistory.add(sample);

      // Trim history
      while (positionHistory.length > _maxHistory) {
        positionHistory.removeAt(0);
      }

      // Calculate velocity
      if (positionHistory.length >= 2) {
        final prev = positionHistory[positionHistory.length - 2];
        final dt = now.difference(prev.timestamp).inMilliseconds / 1000.0;

        if (dt > 0 && dt < 60) {
          final dLat = sample.position.x - prev.position.x;
          final dLon = sample.position.y - prev.position.y;
          final dAlt = sample.position.z - prev.position.z;

          // Convert to meters
          final dNorth = dLat * 111320.0;
          final dEast =
              dLon * 111320.0 * math.cos(sample.position.x * math.pi / 180);

          velocity = vm.Vector3(dEast / dt, dNorth / dt, dAlt / dt);

          // Predict position 30 seconds ahead
          predictedPosition = sample.position + velocity * 30.0;
        }
      }
    }
  }
}

class _NodePositionSample {
  final vm.Vector3 position;
  final DateTime timestamp;

  const _NodePositionSample({required this.position, required this.timestamp});
}

/// Track point for node movement history
class ARTrackPoint {
  final vm.Vector3 position;
  final DateTime timestamp;

  const ARTrackPoint({required this.position, required this.timestamp});
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA CLASSES
// ═══════════════════════════════════════════════════════════════════════════

class AROrientation {
  final double heading;
  final double pitch;
  final double roll;
  final double accuracy;
  final DateTime timestamp;

  const AROrientation({
    required this.heading,
    required this.pitch,
    required this.roll,
    required this.accuracy,
    required this.timestamp,
  });

  factory AROrientation.initial() => AROrientation(
    heading: 0,
    pitch: 0,
    roll: 0,
    accuracy: 0,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class ARPosition {
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
  final double velocityNorth;
  final double velocityEast;
  final DateTime timestamp;

  const ARPosition({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
    required this.velocityNorth,
    required this.velocityEast,
    required this.timestamp,
  });
}

class ARWorldPosition {
  final double latitude;
  final double longitude;
  final double altitude;
  final double distance;
  final double bearing;
  final double elevation;
  final double localEast;
  final double localNorth;
  final double localUp;

  const ARWorldPosition({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.distance,
    required this.bearing,
    required this.elevation,
    required this.localEast,
    required this.localNorth,
    required this.localUp,
  });
}

class ARScreenPosition {
  final double normalizedX; // -1 to 1
  final double normalizedY; // -1 to 1
  final bool isInView;
  final bool isOnLeft;
  final bool isOnRight;
  final bool isAbove;
  final bool isBelow;
  final double relativeAngle;
  final double relativeElevation;
  final double depthFactor;
  final double size;
  final double opacity;

  const ARScreenPosition({
    required this.normalizedX,
    required this.normalizedY,
    required this.isInView,
    required this.isOnLeft,
    required this.isOnRight,
    required this.isAbove,
    required this.isBelow,
    required this.relativeAngle,
    required this.relativeElevation,
    required this.depthFactor,
    required this.size,
    required this.opacity,
  });

  /// Create a copy with updated smoothed position
  ARScreenPosition copyWithPosition(double newX, double newY) {
    return ARScreenPosition(
      normalizedX: newX,
      normalizedY: newY,
      isInView: isInView,
      isOnLeft: isOnLeft,
      isOnRight: isOnRight,
      isAbove: isAbove,
      isBelow: isBelow,
      relativeAngle: relativeAngle,
      relativeElevation: relativeElevation,
      depthFactor: depthFactor,
      size: size,
      opacity: opacity,
    );
  }

  /// Convert to pixel coordinates
  Offset toPixels(double screenWidth, double screenHeight) {
    return Offset(
      screenWidth / 2 + normalizedX * screenWidth / 2,
      screenHeight / 2 + normalizedY * screenHeight / 2,
    );
  }
}

class ARWorldNode {
  final MeshNode node;
  final ARWorldPosition worldPosition;
  final ARScreenPosition screenPosition;
  final vm.Vector3 velocity;
  final vm.Vector3? predictedPosition;
  final ARThreatLevel threatLevel;
  final double signalQuality;
  final bool isNew;
  final bool isMoving;
  final List<ARTrackPoint> track;

  const ARWorldNode({
    required this.node,
    required this.worldPosition,
    required this.screenPosition,
    required this.velocity,
    this.predictedPosition,
    required this.threatLevel,
    required this.signalQuality,
    required this.isNew,
    required this.isMoving,
    required this.track,
  });
}

class ARNodeCluster {
  final List<ARWorldNode> nodes;
  final ARWorldPosition centerPosition;
  final ARScreenPosition screenPosition;

  const ARNodeCluster({
    required this.nodes,
    required this.centerPosition,
    required this.screenPosition,
  });

  int get count => nodes.length;
}

enum ARThreatLevel { normal, info, warning, critical, offline }

class ARAlert {
  final ARAlertType type;
  final int nodeNum;
  final String message;
  final ARAlertSeverity severity;
  final DateTime timestamp;

  const ARAlert({
    required this.type,
    required this.nodeNum,
    required this.message,
    required this.severity,
    required this.timestamp,
  });
}

enum ARAlertType {
  newNode,
  nodeMoving,
  nodeOffline,
  lowBattery,
  signalLost,
  signalRestored,
}

enum ARAlertSeverity { info, warning, critical }

class AREngineConfig {
  final double maxDistance;
  final double horizontalFov;
  final double verticalFov;
  final double clusterRadius;
  final bool enablePrediction;
  final bool enableTracking;

  const AREngineConfig({
    this.maxDistance = 50000, // 50km
    this.horizontalFov = 60,
    this.verticalFov = 90,
    this.clusterRadius = 100, // meters
    this.enablePrediction = true,
    this.enableTracking = true,
  });
}
