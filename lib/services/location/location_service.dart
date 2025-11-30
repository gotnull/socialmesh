import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../protocol/protocol_service.dart';

/// Service that provides phone GPS location and can send it to the mesh.
/// This mimics the iOS Meshtastic app behavior where the phone provides
/// GPS coordinates for the connected device when the device doesn't have GPS.
class LocationService {
  final ProtocolService _protocolService;
  Timer? _locationTimer;
  Position? _lastPosition;
  bool _isRunning = false;

  /// How often to send position updates (in seconds)
  static const int positionUpdateIntervalSeconds = 30;

  LocationService(this._protocolService);

  /// Current position
  Position? get lastPosition => _lastPosition;

  /// Check if location services are enabled and we have permission
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('📍 Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('📍 Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('📍 Location permission permanently denied');
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
        desiredAccuracy: LocationAccuracy.high,
      );

      _lastPosition = position;
      debugPrint(
        '📍 Got phone GPS position: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e) {
      debugPrint('📍 Error getting location: $e');
      return null;
    }
  }

  /// Start periodic location updates to the mesh
  Future<void> startLocationUpdates() async {
    if (_isRunning) return;

    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      debugPrint('📍 Cannot start location updates - no permission');
      return;
    }

    _isRunning = true;
    debugPrint('📍 Starting periodic location updates');

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
    debugPrint('📍 Stopped location updates');
  }

  /// Send current phone GPS position to the mesh
  Future<void> _sendCurrentPosition() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) {
        debugPrint('📍 No position to send');
        return;
      }

      // Send position to mesh (broadcast)
      await _protocolService.sendPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude.toInt(),
      );

      debugPrint(
        '📍 Sent phone GPS to mesh: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      debugPrint('📍 Error sending position: $e');
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
