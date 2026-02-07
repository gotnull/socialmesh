// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import '../../core/logging.dart';
import 'package:geolocator/geolocator.dart';
import '../protocol/protocol_service.dart';

/// Service that provides phone GPS location and can send it to the mesh.
/// Phone GPS sharing is opt-in only and disabled by default for privacy.
class LocationService {
  final ProtocolService _protocolService;
  Timer? _locationTimer;
  Position? _lastPosition;
  bool _isRunning = false;

  /// Guards against concurrent permission requests which cause
  /// "A request for location permissions is already running" crashes.
  Completer<bool>? _permissionCompleter;

  /// How often to send position updates (in seconds)
  static const int positionUpdateIntervalSeconds = 30;

  LocationService(this._protocolService);

  /// Current position
  Position? get lastPosition => _lastPosition;

  /// Check if location services are enabled and we have permission.
  ///
  /// Serializes permission requests so that only one
  /// [Geolocator.requestPermission] call is in flight at a time.
  Future<bool> checkPermissions() async {
    // If a permission request is already running, wait for it.
    if (_permissionCompleter != null) {
      AppLogging.nodes(
        'Permission request already in progress, waiting for result',
      );
      return _permissionCompleter!.future;
    }

    _permissionCompleter = Completer<bool>();

    try {
      final result = await _checkPermissionsInternal();
      _permissionCompleter!.complete(result);
      return result;
    } catch (e) {
      _permissionCompleter!.completeError(e);
      rethrow;
    } finally {
      _permissionCompleter = null;
    }
  }

  Future<bool> _checkPermissionsInternal() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      AppLogging.nodes('Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        AppLogging.nodes('Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      AppLogging.nodes('Location permission permanently denied');
      return false;
    }

    return true;
  }

  /// Get current position once
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _lastPosition = position;
      AppLogging.debug(
        '📍 Got phone GPS position: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e) {
      AppLogging.nodes('Error getting location: $e');
      return null;
    }
  }

  /// Start periodic location updates to the mesh
  Future<void> startLocationUpdates() async {
    if (_isRunning) return;

    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      AppLogging.nodes('Cannot start location updates - no permission');
      return;
    }

    _isRunning = true;
    AppLogging.nodes('Starting periodic location updates');

    // Send initial position immediately
    await _sendCurrentPosition();

    // Then send every N seconds
    _locationTimer = Timer.periodic(
      Duration(seconds: positionUpdateIntervalSeconds),
      (_) => _sendCurrentPosition(),
    );
  }

  /// Stop periodic location updates
  void stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _isRunning = false;
    AppLogging.nodes('Stopped location updates');
  }

  /// Send current phone GPS position to the mesh
  Future<void> _sendCurrentPosition() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) {
        AppLogging.nodes('No position to send');
        return;
      }

      // Send position to mesh (broadcast)
      await _protocolService.sendPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude.toInt(),
      );

      AppLogging.debug(
        '📍 Sent phone GPS to mesh: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      AppLogging.nodes('Error sending position: $e');
    }
  }

  /// Send position once (for manual requests or initial sync)
  Future<void> sendPositionOnce() async {
    await _sendCurrentPosition();
  }

  /// Dispose resources
  void dispose() {
    stopLocationUpdates();
  }
}
