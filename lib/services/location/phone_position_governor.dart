// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:math' as math;

import '../../core/logging.dart';
import '../protocol/protocol_service.dart';

/// Reason why a phone GPS position publish was requested.
///
/// Used for per-reason rate limiting and diagnostic logging.
enum PositionPublishReason {
  /// Periodic 30-second timer tick from LocationService.
  timerTick,

  /// App lifecycle resumed (foreground return).
  lifecycleResume,

  /// BLE reconnect completed successfully.
  reconnect,

  /// User tapped "Share Location" on dashboard quick actions.
  manualAction,

  /// Widget builder "Share Location" action.
  widgetAction,

  /// SharePositionCommand from the command system.
  command,
}

/// Result of a governor publish decision.
enum PublishDecision {
  /// Position was published to the mesh.
  allowed,

  /// Blocked because providePhoneLocation is disabled.
  blockedDisabled,

  /// Blocked by time-based rate limit (too soon since last publish).
  blockedInterval,

  /// Blocked by distance threshold (hasn't moved enough).
  blockedDistance,

  /// Blocked because no GPS position was available.
  blockedNoPosition,
}

/// Centralized governor for phone GPS position publishing.
///
/// All phone-GPS-to-mesh emission paths MUST route through this governor.
/// It enforces:
/// 1. `providePhoneLocation` opt-in gate (hard block when disabled)
/// 2. Minimum time interval between publishes (time gate)
/// 3. Minimum distance moved since last publish (distance gate)
///
/// Manual user actions (dashboard share, widget share, command) use a
/// shorter minimum interval but still enforce a floor to prevent spam.
///
/// The ProtocolService 20-second rate limiter remains as a secondary
/// safety net but is NOT relied upon as the primary gate.
class PhonePositionGovernor {
  final ProtocolService _protocolService;

  /// Callback returning whether `providePhoneLocation` is enabled.
  /// Evaluated on every publish request. When `null`, defaults to `false`.
  final bool Function()? isLocationSharingEnabled;

  // -----------------------------------------------------------------------
  // Configuration constants
  // -----------------------------------------------------------------------

  /// Minimum interval between automatic (timer/lifecycle/reconnect) publishes.
  /// Aligned with common Meshtastic SmartPosition defaults.
  static const Duration autoMinInterval = Duration(seconds: 300);

  /// Minimum interval between manual (user-triggered) publishes.
  /// Shorter than auto to allow intentional shares, but still prevents spam.
  static const Duration manualMinInterval = Duration(seconds: 60);

  /// Minimum distance in meters the phone must have moved since the last
  /// published position before an automatic publish is allowed.
  /// Aligned with common Meshtastic SmartPosition defaults (100-200m).
  /// Manual actions bypass this gate.
  static const double minDistanceMeters = 150.0;

  // -----------------------------------------------------------------------
  // State
  // -----------------------------------------------------------------------

  /// Timestamp of last successful publish (any reason).
  DateTime? _lastPublishedAt;

  /// Latitude of last successfully published position.
  double? _lastPublishedLat;

  /// Longitude of last successfully published position.
  double? _lastPublishedLon;

  /// Total number of publishes allowed during this governor's lifetime.
  int _publishCount = 0;

  /// Total number of requests denied during this governor's lifetime.
  int _denyCount = 0;

  PhonePositionGovernor(this._protocolService, {this.isLocationSharingEnabled});

  // -----------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------

  /// Timestamp of last successful publish. Exposed for testing/diagnostics.
  DateTime? get lastPublishedAt => _lastPublishedAt;

  /// Last published latitude. Exposed for testing/diagnostics.
  double? get lastPublishedLat => _lastPublishedLat;

  /// Last published longitude. Exposed for testing/diagnostics.
  double? get lastPublishedLon => _lastPublishedLon;

  /// Number of publishes allowed.
  int get publishCount => _publishCount;

  /// Number of requests denied.
  int get denyCount => _denyCount;

  /// Request permission to publish a phone GPS position to the mesh.
  ///
  /// Returns the [PublishDecision]. If [PublishDecision.allowed], the
  /// position has already been sent to the mesh via ProtocolService.
  ///
  /// All callers should use this instead of calling
  /// `ProtocolService.sendPosition()` directly for phone GPS.
  Future<PublishDecision> requestPublish({
    required double latitude,
    required double longitude,
    int? altitude,
    required PositionPublishReason reason,
  }) async {
    // Gate 1: providePhoneLocation must be enabled.
    if (!(isLocationSharingEnabled?.call() ?? false)) {
      _logDecision(
        reason: reason,
        decision: PublishDecision.blockedDisabled,
        lat: latitude,
        lon: longitude,
      );
      _denyCount++;
      return PublishDecision.blockedDisabled;
    }

    // Gate 2: time-based rate limit.
    final minInterval = _isManualReason(reason)
        ? manualMinInterval
        : autoMinInterval;

    if (_lastPublishedAt != null) {
      final elapsed = DateTime.now().difference(_lastPublishedAt!);
      if (elapsed < minInterval) {
        _logDecision(
          reason: reason,
          decision: PublishDecision.blockedInterval,
          lat: latitude,
          lon: longitude,
          elapsed: elapsed,
          minInterval: minInterval,
        );
        _denyCount++;
        return PublishDecision.blockedInterval;
      }
    }

    // Gate 3: distance threshold (automatic reasons only).
    // Manual actions bypass distance gate - the user explicitly wants to share.
    if (!_isManualReason(reason) &&
        _lastPublishedLat != null &&
        _lastPublishedLon != null) {
      final distance = _haversineMeters(
        _lastPublishedLat!,
        _lastPublishedLon!,
        latitude,
        longitude,
      );
      if (distance < minDistanceMeters) {
        _logDecision(
          reason: reason,
          decision: PublishDecision.blockedDistance,
          lat: latitude,
          lon: longitude,
          distance: distance,
        );
        _denyCount++;
        return PublishDecision.blockedDistance;
      }
    }

    // All gates passed - publish.
    await _protocolService.sendPosition(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
    );

    _lastPublishedAt = DateTime.now();
    _lastPublishedLat = latitude;
    _lastPublishedLon = longitude;
    _publishCount++;

    _logDecision(
      reason: reason,
      decision: PublishDecision.allowed,
      lat: latitude,
      lon: longitude,
    );

    return PublishDecision.allowed;
  }

  /// Reset governor state. Used when the user disconnects from a device
  /// or disables phone location sharing, so that the next connection
  /// starts fresh.
  void reset() {
    _lastPublishedAt = null;
    _lastPublishedLat = null;
    _lastPublishedLon = null;
    _publishCount = 0;
    _denyCount = 0;
    AppLogging.nodes('PhonePositionGovernor: state reset');
  }

  // -----------------------------------------------------------------------
  // Testing support
  // -----------------------------------------------------------------------

  /// Override the last-published timestamp for testing.
  /// Only visible within tests via the public setter.
  set lastPublishedAtOverride(DateTime? value) {
    _lastPublishedAt = value;
  }

  /// Override the last-published position for testing.
  void setLastPublishedPosition(double? lat, double? lon) {
    _lastPublishedLat = lat;
    _lastPublishedLon = lon;
  }

  // -----------------------------------------------------------------------
  // Private
  // -----------------------------------------------------------------------

  /// Returns `true` for user-initiated reasons that should use the shorter
  /// manual interval and bypass the distance gate.
  bool _isManualReason(PositionPublishReason reason) {
    switch (reason) {
      case PositionPublishReason.manualAction:
      case PositionPublishReason.widgetAction:
      case PositionPublishReason.command:
        return true;
      case PositionPublishReason.timerTick:
      case PositionPublishReason.lifecycleResume:
      case PositionPublishReason.reconnect:
        return false;
    }
  }

  /// Haversine distance in meters between two lat/lon pairs.
  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  /// Log a single-line governor decision for diagnostics.
  void _logDecision({
    required PositionPublishReason reason,
    required PublishDecision decision,
    required double lat,
    required double lon,
    Duration? elapsed,
    Duration? minInterval,
    double? distance,
  }) {
    final buffer = StringBuffer()
      ..write('PhonePositionGovernor: ')
      ..write(decision == PublishDecision.allowed ? 'ALLOW' : 'DENY')
      ..write(' reason=${reason.name}')
      ..write(' pos=(${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})');

    if (elapsed != null) {
      buffer.write(' elapsed=${elapsed.inSeconds}s');
    }
    if (minInterval != null) {
      buffer.write(' minInterval=${minInterval.inSeconds}s');
    }
    if (distance != null) {
      buffer.write(' distance=${distance.toStringAsFixed(0)}m');
    }

    if (decision == PublishDecision.allowed) {
      buffer.write(' [publish #$_publishCount]');
    } else {
      buffer.write(' [deny #$_denyCount]');
    }

    AppLogging.nodes(buffer.toString());
  }
}
