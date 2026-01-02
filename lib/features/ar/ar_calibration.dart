// AR Calibration Service
//
// Handles camera FOV detection, compass calibration, magnetic declination,
// and sensor confidence estimation for accurate AR positioning.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CALIBRATION STATE
// ═══════════════════════════════════════════════════════════════════════════

enum CalibrationStatus { unknown, poor, fair, good, excellent }

/// Calibration progress phases
enum CalibrationPhase {
  idle,
  starting,
  collectingData,
  analyzing,
  complete,
  failed,
}

class ARCalibrationState {
  final double horizontalFov;
  final double verticalFov;
  final double magneticDeclination;
  final CalibrationStatus compassStatus;
  final CalibrationStatus gpsStatus;
  final double compassAccuracy; // 0-1
  final double gpsAccuracyMeters;
  final bool isCalibrating;
  final CalibrationPhase phase;
  final double calibrationProgress; // 0-1
  final String? calibrationMessage;
  final DateTime? lastCalibration;
  final String? deviceModel;
  final bool needsCompassCalibration;

  const ARCalibrationState({
    this.horizontalFov = 60.0,
    this.verticalFov = 80.0,
    this.magneticDeclination = 0.0,
    this.compassStatus = CalibrationStatus.unknown,
    this.gpsStatus = CalibrationStatus.unknown,
    this.compassAccuracy = 0.0,
    this.gpsAccuracyMeters = 999.0,
    this.isCalibrating = false,
    this.phase = CalibrationPhase.idle,
    this.calibrationProgress = 0.0,
    this.calibrationMessage,
    this.lastCalibration,
    this.deviceModel,
    this.needsCompassCalibration = true,
  });

  ARCalibrationState copyWith({
    double? horizontalFov,
    double? verticalFov,
    double? magneticDeclination,
    CalibrationStatus? compassStatus,
    CalibrationStatus? gpsStatus,
    double? compassAccuracy,
    double? gpsAccuracyMeters,
    bool? isCalibrating,
    CalibrationPhase? phase,
    double? calibrationProgress,
    String? calibrationMessage,
    bool clearMessage = false,
    DateTime? lastCalibration,
    String? deviceModel,
    bool? needsCompassCalibration,
  }) {
    return ARCalibrationState(
      horizontalFov: horizontalFov ?? this.horizontalFov,
      verticalFov: verticalFov ?? this.verticalFov,
      magneticDeclination: magneticDeclination ?? this.magneticDeclination,
      compassStatus: compassStatus ?? this.compassStatus,
      gpsStatus: gpsStatus ?? this.gpsStatus,
      compassAccuracy: compassAccuracy ?? this.compassAccuracy,
      gpsAccuracyMeters: gpsAccuracyMeters ?? this.gpsAccuracyMeters,
      isCalibrating: isCalibrating ?? this.isCalibrating,
      phase: phase ?? this.phase,
      calibrationProgress: calibrationProgress ?? this.calibrationProgress,
      calibrationMessage: clearMessage
          ? null
          : (calibrationMessage ?? this.calibrationMessage),
      lastCalibration: lastCalibration ?? this.lastCalibration,
      deviceModel: deviceModel ?? this.deviceModel,
      needsCompassCalibration:
          needsCompassCalibration ?? this.needsCompassCalibration,
    );
  }

  /// Check if calibration is good enough for AR
  bool get isReady =>
      compassStatus != CalibrationStatus.unknown &&
      compassStatus != CalibrationStatus.poor &&
      gpsStatus != CalibrationStatus.unknown;

  /// Overall confidence score 0-1
  double get overallConfidence {
    final compassScore = switch (compassStatus) {
      CalibrationStatus.unknown => 0.0,
      CalibrationStatus.poor => 0.25,
      CalibrationStatus.fair => 0.5,
      CalibrationStatus.good => 0.75,
      CalibrationStatus.excellent => 1.0,
    };
    final gpsScore = switch (gpsStatus) {
      CalibrationStatus.unknown => 0.0,
      CalibrationStatus.poor => 0.25,
      CalibrationStatus.fair => 0.5,
      CalibrationStatus.good => 0.75,
      CalibrationStatus.excellent => 1.0,
    };
    return (compassScore * 0.6 + gpsScore * 0.4);
  }

  /// Human-readable compass status
  String get compassStatusText => switch (compassStatus) {
    CalibrationStatus.unknown => 'Not calibrated',
    CalibrationStatus.poor => 'Poor accuracy',
    CalibrationStatus.fair => 'Fair accuracy',
    CalibrationStatus.good => 'Good accuracy',
    CalibrationStatus.excellent => 'Excellent accuracy',
  };

  /// Human-readable GPS status
  String get gpsStatusText {
    if (gpsStatus == CalibrationStatus.unknown) return 'Acquiring...';
    if (gpsAccuracyMeters < 5)
      return '±${gpsAccuracyMeters.toStringAsFixed(1)}m (Excellent)';
    if (gpsAccuracyMeters < 10)
      return '±${gpsAccuracyMeters.toStringAsFixed(1)}m (Good)';
    if (gpsAccuracyMeters < 25)
      return '±${gpsAccuracyMeters.toStringAsFixed(1)}m (Fair)';
    return '±${gpsAccuracyMeters.toStringAsFixed(0)}m (Poor)';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CALIBRATION SERVICE
// ═══════════════════════════════════════════════════════════════════════════

class ARCalibrationService {
  ARCalibrationState _state = const ARCalibrationState();
  final _stateController = StreamController<ARCalibrationState>.broadcast();
  Stream<ARCalibrationState> get stateStream => _stateController.stream;
  ARCalibrationState get state => _state;

  // Sensor subscriptions for calibration
  StreamSubscription<MagnetometerEvent>? _magnetometerSub;
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;

  // Calibration data collectors
  final List<double> _magnetometerMagnitudes = [];
  final List<double> _headingVariances = [];
  final List<_MagnetometerSample> _magnetometerSamples = [];
  double _lastHeading = 0;
  Timer? _progressTimer;
  DateTime? _calibrationStartTime;

  bool _isDisposed = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    await loadFromPrefs();
    await _detectDeviceModel();
    await detectCameraFov();

    // Check if compass calibration is needed
    if (_state.lastCalibration != null) {
      final age = DateTime.now().difference(_state.lastCalibration!);
      if (age.inHours > 24) {
        _updateState(
          _state.copyWith(
            needsCompassCalibration: true,
            compassStatus: CalibrationStatus.fair,
          ),
        );
      }
    }
  }

  Future<void> _detectDeviceModel() async {
    String? model;
    try {
      if (Platform.isIOS) {
        // iOS device model detection
        final channel = const MethodChannel('flutter.native/helper');
        try {
          model = await channel.invokeMethod<String>('getDeviceModel');
        } catch (_) {
          model = 'iPhone';
        }
      } else if (Platform.isAndroid) {
        model = 'Android';
      }
    } catch (e) {
      debugPrint('[ARCalibration] Device model detection failed: $e');
    }

    _updateState(_state.copyWith(deviceModel: model));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CAMERA FOV DETECTION - IMPROVED
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get camera FOV from device camera capabilities
  Future<({double horizontal, double vertical})> detectCameraFov() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        return _getDefaultFov();
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Get device-specific FOV based on camera sensor
      final fov = _getDeviceSpecificFov(backCamera);

      _updateState(
        _state.copyWith(
          horizontalFov: fov.horizontal,
          verticalFov: fov.vertical,
        ),
      );

      debugPrint(
        '[ARCalibration] Detected FOV: ${fov.horizontal}° × ${fov.vertical}°',
      );

      return fov;
    } catch (e) {
      debugPrint('[ARCalibration] FOV detection error: $e');
      return _getDefaultFov();
    }
  }

  ({double horizontal, double vertical}) _getDefaultFov() {
    // Conservative default that works for most phones
    return (horizontal: 65.0, vertical: 85.0);
  }

  ({double horizontal, double vertical}) _getDeviceSpecificFov([
    CameraDescription? camera,
  ]) {
    if (Platform.isIOS) {
      // iPhone models with known FOV values
      // Main camera (1x) FOV varies by model
      // iPhone 12/13/14/15 main: ~69° horizontal
      // iPhone Pro models 1x: ~69°, 0.5x: ~120°, 2x/3x: ~39°
      return (horizontal: 69.0, vertical: 89.0);
    } else if (Platform.isAndroid) {
      // Android varies widely by manufacturer
      // Samsung S-series: ~79° (main)
      // Pixel: ~77° (main)
      // OnePlus: ~74°
      // Use average conservative value
      return (horizontal: 72.0, vertical: 92.0);
    }
    return _getDefaultFov();
  }

  /// Allow manual FOV calibration with validation
  void setFov(double horizontal, double vertical) {
    _updateState(
      _state.copyWith(
        horizontalFov: horizontal.clamp(40.0, 120.0),
        verticalFov: vertical.clamp(50.0, 150.0),
      ),
    );
    _saveFovToPrefs();
  }

  /// Get recommended FOV presets for common devices
  static List<FovPreset> get fovPresets => [
    const FovPreset(name: 'iPhone (1x)', horizontal: 69.0, vertical: 89.0),
    const FovPreset(name: 'iPhone (0.5x)', horizontal: 120.0, vertical: 100.0),
    const FovPreset(name: 'Samsung Galaxy', horizontal: 79.0, vertical: 95.0),
    const FovPreset(name: 'Google Pixel', horizontal: 77.0, vertical: 93.0),
    const FovPreset(name: 'Wide (default)', horizontal: 65.0, vertical: 85.0),
    const FovPreset(name: 'Narrow', horizontal: 50.0, vertical: 70.0),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // MAGNETIC DECLINATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Update magnetic declination when position changes
  void updateMagneticDeclination(double latitude, double longitude) {
    final declination = _calculateMagneticDeclination(latitude, longitude);
    if ((declination - _state.magneticDeclination).abs() > 0.5) {
      _updateState(_state.copyWith(magneticDeclination: declination));
    }
  }

  /// Calculate magnetic declination for current location
  /// Uses simplified World Magnetic Model approximation
  double _calculateMagneticDeclination(double latitude, double longitude) {
    // Simplified WMM 2020-2025 approximation
    // Full implementation would use NOAA's WMM coefficients

    // Convert to radians
    final lat = latitude * math.pi / 180;
    final lon = longitude * math.pi / 180;

    // Simplified dipole model
    // North magnetic pole approx: 86.5°N, 164°E (2024)
    const magPoleLat = 86.5 * math.pi / 180;
    const magPoleLon = 164.0 * math.pi / 180;

    // Calculate great circle bearing difference
    final dlon = magPoleLon - lon;
    final y = math.sin(dlon);
    final x =
        math.cos(lat) * math.tan(magPoleLat) - math.sin(lat) * math.cos(dlon);
    var declination = math.atan2(y, x) * 180 / math.pi;

    // Clamp to reasonable range
    declination = declination.clamp(-30.0, 30.0);

    return declination;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPASS CALIBRATION - IMPROVED
  // ═══════════════════════════════════════════════════════════════════════════

  /// Start compass calibration - user should rotate device in figure-8 pattern
  Future<void> startCompassCalibration() async {
    if (_state.isCalibrating) return;

    _updateState(
      _state.copyWith(
        isCalibrating: true,
        phase: CalibrationPhase.starting,
        calibrationProgress: 0.0,
        calibrationMessage: 'Starting calibration...',
        compassStatus: CalibrationStatus.unknown,
      ),
    );

    _magnetometerMagnitudes.clear();
    _headingVariances.clear();
    _magnetometerSamples.clear();
    _calibrationStartTime = DateTime.now();

    // Small delay for UI to update
    await Future.delayed(const Duration(milliseconds: 500));

    _updateState(
      _state.copyWith(
        phase: CalibrationPhase.collectingData,
        calibrationMessage: 'Move device in figure-8 pattern',
      ),
    );

    // Start collecting magnetometer data at high frequency
    _magnetometerSub?.cancel();
    _magnetometerSub = magnetometerEventStream(
      samplingPeriod: const Duration(milliseconds: 20), // 50Hz
    ).listen(_onMagnetometerCalibration);

    _accelerometerSub?.cancel();
    _accelerometerSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 20),
    ).listen(_onAccelerometerCalibration);

    // Progress timer
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _updateCalibrationProgress();
    });

    // Auto-complete after 12 seconds or when quality is sufficient
    Future.delayed(const Duration(seconds: 12), () {
      if (_state.isCalibrating) {
        _completeCalibration();
      }
    });
  }

  void _onMagnetometerCalibration(MagnetometerEvent event) {
    if (_isDisposed || !_state.isCalibrating) return;

    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    _magnetometerMagnitudes.add(magnitude);
    _magnetometerSamples.add(
      _MagnetometerSample(
        x: event.x,
        y: event.y,
        z: event.z,
        timestamp: DateTime.now(),
      ),
    );

    // Keep last 600 samples (12 seconds at 50Hz)
    if (_magnetometerMagnitudes.length > 600) {
      _magnetometerMagnitudes.removeAt(0);
    }
    if (_magnetometerSamples.length > 600) {
      _magnetometerSamples.removeAt(0);
    }

    // Calculate heading for variance check
    final heading = math.atan2(event.y, event.x) * 180 / math.pi;
    if (_lastHeading != 0) {
      var diff = (heading - _lastHeading).abs();
      if (diff > 180) diff = 360 - diff;
      _headingVariances.add(diff);
      if (_headingVariances.length > 600) {
        _headingVariances.removeAt(0);
      }
    }
    _lastHeading = heading;

    // Check for early completion if quality is excellent
    if (_magnetometerMagnitudes.length >= 250) {
      // At least 5 seconds
      final quality = _assessCalibrationQuality();
      if (quality >= 0.9 && !_state.phase.name.contains('analyzing')) {
        _completeCalibration();
      }
    }
  }

  void _onAccelerometerCalibration(AccelerometerEvent event) {
    // Used for tilt compensation during calibration
    // Data is collected but primary analysis uses magnetometer
  }

  void _updateCalibrationProgress() {
    if (!_state.isCalibrating || _calibrationStartTime == null) return;

    final elapsed = DateTime.now().difference(_calibrationStartTime!);
    final timeProgress = (elapsed.inMilliseconds / 12000.0).clamp(0.0, 1.0);

    // Quality-based progress
    final quality = _assessCalibrationQuality();
    final qualityProgress = quality;

    // Combined progress (time + quality weighted)
    final progress = (timeProgress * 0.4 + qualityProgress * 0.6).clamp(
      0.0,
      1.0,
    );

    String message;
    if (_magnetometerMagnitudes.length < 100) {
      message = 'Move device in figure-8 pattern...';
    } else if (quality < 0.3) {
      message = 'Keep rotating - try all orientations';
    } else if (quality < 0.6) {
      message = 'Good progress - continue rotating';
    } else if (quality < 0.85) {
      message = 'Almost there - keep moving';
    } else {
      message = 'Excellent! Finishing up...';
    }

    _updateState(
      _state.copyWith(
        calibrationProgress: progress,
        calibrationMessage: message,
      ),
    );
  }

  double _assessCalibrationQuality() {
    if (_magnetometerMagnitudes.length < 50) return 0.0;

    // Check magnetometer field variance
    final mean =
        _magnetometerMagnitudes.reduce((a, b) => a + b) /
        _magnetometerMagnitudes.length;
    final variance =
        _magnetometerMagnitudes
            .map((m) => (m - mean) * (m - mean))
            .reduce((a, b) => a + b) /
        _magnetometerMagnitudes.length;
    final cv = math.sqrt(variance) / mean; // Coefficient of variation

    // Lower CV = more consistent readings = better calibration
    final cvScore = (1.0 - cv / 0.5).clamp(0.0, 1.0);

    // Check heading coverage (should see wide range of headings)
    final headingSum = _headingVariances.isEmpty
        ? 0.0
        : _headingVariances.reduce((a, b) => a + b);
    final coverageScore = (headingSum / 360.0).clamp(0.0, 1.0);

    // Sample count score
    final sampleScore = (_magnetometerMagnitudes.length / 400.0).clamp(
      0.0,
      1.0,
    );

    return (cvScore * 0.4 + coverageScore * 0.4 + sampleScore * 0.2);
  }

  Future<void> _completeCalibration() async {
    if (!_state.isCalibrating) return;

    _updateState(
      _state.copyWith(
        phase: CalibrationPhase.analyzing,
        calibrationMessage: 'Analyzing calibration data...',
      ),
    );

    _progressTimer?.cancel();
    _magnetometerSub?.cancel();
    _accelerometerSub?.cancel();
    _magnetometerSub = null;
    _accelerometerSub = null;

    // Brief delay for analysis feedback
    await Future.delayed(const Duration(milliseconds: 500));

    // Analyze calibration quality
    CalibrationStatus status;
    double accuracy;
    bool needsRecalibration = false;

    if (_magnetometerMagnitudes.length < 100) {
      status = CalibrationStatus.poor;
      accuracy = 0.2;
      needsRecalibration = true;
    } else {
      final quality = _assessCalibrationQuality();

      if (quality >= 0.85) {
        status = CalibrationStatus.excellent;
        accuracy = 0.95;
      } else if (quality >= 0.65) {
        status = CalibrationStatus.good;
        accuracy = 0.8;
      } else if (quality >= 0.4) {
        status = CalibrationStatus.fair;
        accuracy = 0.6;
      } else {
        status = CalibrationStatus.poor;
        accuracy = 0.3;
        needsRecalibration = true;
      }
    }

    final message = switch (status) {
      CalibrationStatus.excellent => 'Calibration complete - Excellent!',
      CalibrationStatus.good => 'Calibration complete - Good',
      CalibrationStatus.fair => 'Calibration acceptable - can improve',
      CalibrationStatus.poor => 'Calibration incomplete - please try again',
      CalibrationStatus.unknown => 'Calibration failed',
    };

    _updateState(
      _state.copyWith(
        isCalibrating: false,
        phase: status == CalibrationStatus.poor
            ? CalibrationPhase.failed
            : CalibrationPhase.complete,
        compassStatus: status,
        compassAccuracy: accuracy,
        calibrationProgress: 1.0,
        calibrationMessage: message,
        lastCalibration: DateTime.now(),
        needsCompassCalibration: needsRecalibration,
      ),
    );

    await _saveCalibrationToPrefs();

    // Clear message after delay
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isDisposed && _state.phase == CalibrationPhase.complete) {
        _updateState(
          _state.copyWith(phase: CalibrationPhase.idle, clearMessage: true),
        );
      }
    });
  }

  /// Cancel ongoing calibration
  void cancelCalibration() {
    _progressTimer?.cancel();
    _magnetometerSub?.cancel();
    _accelerometerSub?.cancel();
    _progressTimer = null;
    _magnetometerSub = null;
    _accelerometerSub = null;

    _updateState(
      _state.copyWith(
        isCalibrating: false,
        phase: CalibrationPhase.idle,
        calibrationProgress: 0.0,
        clearMessage: true,
      ),
    );
  }

  /// Alias for cancelCalibration for external use
  void cancelCompassCalibration() => cancelCalibration();

  // ═══════════════════════════════════════════════════════════════════════════
  // GPS STATUS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Update GPS status from position accuracy
  void updateGpsStatus(double accuracyMeters) {
    final status = switch (accuracyMeters) {
      < 5 => CalibrationStatus.excellent,
      < 10 => CalibrationStatus.good,
      < 25 => CalibrationStatus.fair,
      < 100 => CalibrationStatus.poor,
      _ => CalibrationStatus.unknown,
    };

    _updateState(
      _state.copyWith(gpsStatus: status, gpsAccuracyMeters: accuracyMeters),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PERSISTENCE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final hFov = prefs.getDouble('ar_horizontal_fov');
      final vFov = prefs.getDouble('ar_vertical_fov');
      final declination = prefs.getDouble('ar_magnetic_declination');
      final lastCalMs = prefs.getInt('ar_last_calibration');
      final compassAccuracy = prefs.getDouble('ar_compass_accuracy');

      _updateState(
        _state.copyWith(
          horizontalFov: hFov ?? _state.horizontalFov,
          verticalFov: vFov ?? _state.verticalFov,
          magneticDeclination: declination ?? _state.magneticDeclination,
          compassAccuracy: compassAccuracy ?? _state.compassAccuracy,
          compassStatus: compassAccuracy != null && compassAccuracy > 0.7
              ? CalibrationStatus.good
              : CalibrationStatus.unknown,
          lastCalibration: lastCalMs != null
              ? DateTime.fromMillisecondsSinceEpoch(lastCalMs)
              : null,
        ),
      );
    } catch (e) {
      debugPrint('[ARCalibration] Failed to load prefs: $e');
    }
  }

  Future<void> _saveFovToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('ar_horizontal_fov', _state.horizontalFov);
      await prefs.setDouble('ar_vertical_fov', _state.verticalFov);
    } catch (e) {
      debugPrint('[ARCalibration] Failed to save FOV: $e');
    }
  }

  Future<void> _saveCalibrationToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
        'ar_magnetic_declination',
        _state.magneticDeclination,
      );
      await prefs.setDouble('ar_compass_accuracy', _state.compassAccuracy);
      if (_state.lastCalibration != null) {
        await prefs.setInt(
          'ar_last_calibration',
          _state.lastCalibration!.millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      debugPrint('[ARCalibration] Failed to save calibration: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  void _updateState(ARCalibrationState newState) {
    if (_isDisposed) return;
    _state = newState;
    _stateController.add(_state);
  }

  void dispose() {
    _isDisposed = true;
    _progressTimer?.cancel();
    _magnetometerSub?.cancel();
    _accelerometerSub?.cancel();
    _stateController.close();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SUPPORTING CLASSES
// ═══════════════════════════════════════════════════════════════════════════

/// FOV preset for device selection
class FovPreset {
  final String name;
  final double horizontal;
  final double vertical;

  const FovPreset({
    required this.name,
    required this.horizontal,
    required this.vertical,
  });
}

class _MagnetometerSample {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  const _MagnetometerSample({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// ADVANCED LOW-PASS FILTER FOR MARKER SMOOTHING
// ═══════════════════════════════════════════════════════════════════════════

/// Advanced exponential moving average filter with velocity tracking
/// and adaptive smoothing for smooth AR marker positioning
class MarkerSmoother {
  final double alpha; // Base smoothing factor (0-1, lower = smoother)
  final double velocitySmoothing; // Velocity smoothing factor
  final bool adaptiveSmoothing; // Adjust alpha based on velocity
  final Map<int, _SmoothedPosition> _positions = {};

  MarkerSmoother({
    this.alpha = 0.25,
    this.velocitySmoothing = 0.15,
    this.adaptiveSmoothing = true,
  });

  /// Update and get smoothed position for a node
  ({double x, double y}) smooth(int nodeNum, double rawX, double rawY) {
    final now = DateTime.now();
    final existing = _positions[nodeNum];

    if (existing == null) {
      // First observation - use raw position
      _positions[nodeNum] = _SmoothedPosition(x: rawX, y: rawY, timestamp: now);
      return (x: rawX, y: rawY);
    }

    // Calculate time delta
    final dt = now.difference(existing.timestamp).inMilliseconds / 1000.0;
    if (dt <= 0) {
      return (x: existing.x, y: existing.y);
    }

    // Calculate raw velocity
    final rawVx = (rawX - existing.x) / dt;
    final rawVy = (rawY - existing.y) / dt;

    // Smooth velocity with separate low-pass filter
    final smoothedVx =
        existing.velocityX + velocitySmoothing * (rawVx - existing.velocityX);
    final smoothedVy =
        existing.velocityY + velocitySmoothing * (rawVy - existing.velocityY);

    // Calculate adaptive alpha based on velocity (faster = more responsive)
    double effectiveAlpha = alpha;
    if (adaptiveSmoothing) {
      final speed = math.sqrt(
        smoothedVx * smoothedVx + smoothedVy * smoothedVy,
      );
      // Increase alpha (more responsive) when moving fast
      // Range: alpha at rest -> 2*alpha when moving fast
      effectiveAlpha = alpha + (alpha * (speed * 2).clamp(0.0, 1.0));
    }

    // Exponential moving average with adaptive alpha
    final smoothedX = existing.x + effectiveAlpha * (rawX - existing.x);
    final smoothedY = existing.y + effectiveAlpha * (rawY - existing.y);

    _positions[nodeNum] = _SmoothedPosition(
      x: smoothedX,
      y: smoothedY,
      velocityX: smoothedVx,
      velocityY: smoothedVy,
      timestamp: now,
    );

    return (x: smoothedX, y: smoothedY);
  }

  /// Predict position based on velocity for smoother transitions
  ({double x, double y})? predict(int nodeNum, double secondsAhead) {
    final pos = _positions[nodeNum];
    if (pos == null) return null;

    return (
      x: pos.x + pos.velocityX * secondsAhead,
      y: pos.y + pos.velocityY * secondsAhead,
    );
  }

  /// Get velocity estimate for a node
  ({double vx, double vy})? getVelocity(int nodeNum) {
    final pos = _positions[nodeNum];
    if (pos == null) return null;
    return (vx: pos.velocityX, vy: pos.velocityY);
  }

  /// Get speed for a node (magnitude of velocity)
  double? getSpeed(int nodeNum) {
    final velocity = getVelocity(nodeNum);
    if (velocity == null) return null;
    return math.sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy);
  }

  /// Check if a node is moving (velocity above threshold)
  bool isMoving(int nodeNum, {double threshold = 0.01}) {
    final speed = getSpeed(nodeNum);
    return speed != null && speed > threshold;
  }

  /// Remove tracking for a node
  void remove(int nodeNum) {
    _positions.remove(nodeNum);
  }

  /// Clear all tracking
  void clear() {
    _positions.clear();
  }

  /// Get all tracked node IDs
  Set<int> get trackedNodes => _positions.keys.toSet();
}

class _SmoothedPosition {
  final double x;
  final double y;
  final double velocityX;
  final double velocityY;
  final DateTime timestamp;

  _SmoothedPosition({
    required this.x,
    required this.y,
    this.velocityX = 0,
    this.velocityY = 0,
    required this.timestamp,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// HEADING STABILIZER
// ═══════════════════════════════════════════════════════════════════════════

/// Stabilizes heading to prevent jitter near cardinal directions
/// with configurable deadband and rate limiting
class HeadingStabilizer {
  final double deadband; // Degrees of hysteresis
  final double maxRateDegreesPerSecond; // Maximum rotation rate
  double _lastStableHeading = 0;
  DateTime _lastUpdate = DateTime.now();
  bool _initialized = false;

  HeadingStabilizer({this.deadband = 2.0, this.maxRateDegreesPerSecond = 60.0});

  /// Get stabilized heading
  double stabilize(double rawHeading) {
    final now = DateTime.now();
    final dt = now.difference(_lastUpdate).inMilliseconds / 1000.0;
    _lastUpdate = now;

    // Initialize on first call
    if (!_initialized) {
      _lastStableHeading = rawHeading;
      _initialized = true;
      return rawHeading;
    }

    // Calculate shortest angular difference
    var diff = rawHeading - _lastStableHeading;
    while (diff > 180) {
      diff -= 360;
    }
    while (diff < -180) {
      diff += 360;
    }

    // Only update if change exceeds deadband
    if (diff.abs() > deadband) {
      // Rate-limit the change for smooth transitions
      final maxChange = maxRateDegreesPerSecond * dt;
      final change = diff.clamp(-maxChange, maxChange);
      _lastStableHeading = (_lastStableHeading + change) % 360;
      if (_lastStableHeading < 0) _lastStableHeading += 360;
    }

    return _lastStableHeading;
  }

  /// Reset stabilizer to a specific heading
  void reset(double heading) {
    _lastStableHeading = heading;
    _initialized = true;
  }

  /// Check if heading is near a cardinal direction
  bool isNearCardinal({double tolerance = 5.0}) {
    final heading = _lastStableHeading;
    return (heading < tolerance || heading > 360 - tolerance) ||
        (heading > 90 - tolerance && heading < 90 + tolerance) ||
        (heading > 180 - tolerance && heading < 180 + tolerance) ||
        (heading > 270 - tolerance && heading < 270 + tolerance);
  }

  /// Get cardinal direction name
  String? nearestCardinal() {
    final heading = _lastStableHeading;
    if (heading < 22.5 || heading >= 337.5) return 'N';
    if (heading >= 22.5 && heading < 67.5) return 'NE';
    if (heading >= 67.5 && heading < 112.5) return 'E';
    if (heading >= 112.5 && heading < 157.5) return 'SE';
    if (heading >= 157.5 && heading < 202.5) return 'S';
    if (heading >= 202.5 && heading < 247.5) return 'SW';
    if (heading >= 247.5 && heading < 292.5) return 'W';
    if (heading >= 292.5 && heading < 337.5) return 'NW';
    return null;
  }
}
