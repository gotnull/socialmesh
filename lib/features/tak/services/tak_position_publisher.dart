// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import '../../../core/logging.dart';
import '../models/tak_publish_config.dart';
import '../services/tak_gateway_client.dart';

/// Timer-based publisher that POSTs the local node's CoT SA position to the
/// TAK Gateway at a configurable interval.
///
/// Deduplicates by lat/lon with a 0.0001-degree threshold. Skips if the
/// gateway is disconnected, no position is available, or the position is
/// unchanged since the last publish.
class TakPositionPublisher {
  final TakGatewayClient _client;

  /// Returns the current node number (hex uppercase), or null if unavailable.
  final String? Function() _getNodeHex;

  /// Returns the current node latitude, or null.
  final double? Function() _getLat;

  /// Returns the current node longitude, or null.
  final double? Function() _getLon;

  /// Returns the node's long name for use as default callsign.
  final String Function() _getNodeName;

  Timer? _timer;
  TakPublishConfig _config;

  double? _lastLat;
  double? _lastLon;

  TakPositionPublisher({
    required TakGatewayClient client,
    required String? Function() getNodeHex,
    required double? Function() getLat,
    required double? Function() getLon,
    required String Function() getNodeName,
    TakPublishConfig config = const TakPublishConfig(),
  }) : _client = client,
       _getNodeHex = getNodeHex,
       _getLat = getLat,
       _getLon = getLon,
       _getNodeName = getNodeName,
       _config = config;

  /// Current configuration.
  TakPublishConfig get config => _config;

  /// Whether the publisher is actively running.
  bool get isRunning => _timer != null && _timer!.isActive;

  /// Update configuration. Restarts the timer if the interval changed and
  /// the publisher was already running.
  void updateConfig(TakPublishConfig newConfig) {
    final wasRunning = isRunning;
    final intervalChanged =
        newConfig.intervalSeconds != _config.intervalSeconds;
    _config = newConfig;

    if (!newConfig.enabled) {
      stop();
      return;
    }

    if (wasRunning && intervalChanged) {
      stop();
      start();
    } else if (!wasRunning && newConfig.enabled) {
      start();
    }
  }

  /// Start the periodic publish timer.
  void start() {
    if (isRunning) return;
    if (!_config.enabled) {
      AppLogging.tak('PositionPublisher: not starting — disabled');
      return;
    }

    final callsign = _config.effectiveCallsign(_getNodeName());
    AppLogging.tak(
      'PositionPublisher started: interval=${_config.intervalSeconds}s, '
      'callsign=$callsign',
    );

    // Publish immediately, then periodically.
    _publish();
    _timer = Timer.periodic(
      Duration(seconds: _config.intervalSeconds),
      (_) => _publish(),
    );
  }

  /// Stop the publisher.
  void stop() {
    if (!isRunning) return;
    _timer?.cancel();
    _timer = null;
    _lastLat = null;
    _lastLon = null;
    AppLogging.tak('PositionPublisher stopped');
  }

  /// Clean up.
  void dispose() {
    stop();
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<void> _publish() async {
    if (_client.state != TakConnectionState.connected) {
      AppLogging.tak(
        'PositionPublisher: gateway not connected, skipping publish',
      );
      return;
    }

    final nodeHex = _getNodeHex();
    if (nodeHex == null) {
      AppLogging.tak(
        'PositionPublisher: no node number available, skipping publish',
      );
      return;
    }

    final lat = _getLat();
    final lon = _getLon();
    if (lat == null || lon == null) {
      AppLogging.tak(
        'PositionPublisher: no GPS position available, skipping publish',
      );
      return;
    }

    // Skip (0,0) positions.
    if (lat == 0.0 && lon == 0.0) {
      AppLogging.tak('PositionPublisher: position is 0,0 — skipping publish');
      return;
    }

    // Dedup: skip if position unchanged within threshold.
    if (_lastLat != null && _lastLon != null) {
      final latDelta = (lat - _lastLat!).abs();
      final lonDelta = (lon - _lastLon!).abs();
      if (latDelta < 0.0001 && lonDelta < 0.0001) {
        AppLogging.tak(
          'PositionPublisher: position unchanged, skipping publish',
        );
        return;
      }
    }

    final callsign = _config.effectiveCallsign(_getNodeName());
    final uid = 'SOCIALMESH-$nodeHex';

    AppLogging.tak(
      'PositionPublisher: publishing position '
      'lat=${lat.toStringAsFixed(4)}, lon=${lon.toStringAsFixed(4)}',
    );

    final success = await _client.publishPosition(
      uid: uid,
      type: 'a-f-G-U-C',
      callsign: callsign,
      lat: lat,
      lon: lon,
    );

    if (success) {
      _lastLat = lat;
      _lastLon = lon;
    }
  }
}
