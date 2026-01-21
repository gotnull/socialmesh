import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';

/// Provides a normalized heading stream along with availability info.
class HeadingService {
  HeadingService() {
    _init();
  }

  final _headingController = StreamController<double?>.broadcast();
  final _availabilityController = StreamController<bool>.broadcast();
  StreamSubscription<CompassEvent>? _subscription;
  bool _initialized = false;
  bool _disposed = false;

  late final Permission _locationPermission = _resolvePlatformPermission();

  /// Emits normalized heading values (0..360) or null when unavailable.
  Stream<double?> get headingDegrees => _headingController.stream.distinct();

  /// Emits true when the heading stream is active/permission granted.
  Stream<bool> get isAvailable => _availabilityController.stream.distinct();

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    _headingController.add(null);
    _publishAvailability(false);

    if (kIsWeb || !_supportsPlatform()) {
      return;
    }

    final granted = await _requestPermission();
    _publishAvailability(granted);
    if (!granted) {
      return;
    }

    final events = FlutterCompass.events;
    if (events == null) {
      _publishAvailability(false);
      return;
    }

    _subscription = events.listen(
      _handleCompassEvent,
      onError: (_) => _publishAvailability(false),
      cancelOnError: false,
    );
  }

  Permission _resolvePlatformPermission() {
    if (kIsWeb) {
      return Permission.location;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return Permission.locationWhenInUse;
      case TargetPlatform.android:
        return Permission.location;
      default:
        return Permission.locationWhenInUse;
    }
  }

  bool _supportsPlatform() {
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  Future<bool> _requestPermission() async {
    final status = await _locationPermission.status;
    if (_hasPermission(status)) {
      return true;
    }
    final requested = await _locationPermission.request();
    return _hasPermission(requested);
  }

  bool _hasPermission(PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  void _handleCompassEvent(CompassEvent event) {
    if (_disposed) return;
    final heading = event.heading;
    if (heading == null) {
      _headingController.add(null);
      return;
    }

    final normalized = (heading % 360 + 360) % 360;
    _headingController.add(normalized);
  }

  void _publishAvailability(bool available) {
    if (_disposed) return;
    _availabilityController.add(available);
  }

  /// Cancel the subscription and close streams.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _subscription?.cancel();
    _headingController.close();
    _availabilityController.close();
  }
}
