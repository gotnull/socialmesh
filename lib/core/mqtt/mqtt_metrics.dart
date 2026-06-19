// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Health metrics model for the Global Layer (MQTT) feature.
///
/// [GlobalLayerMetrics] tracks connection health, message throughput,
/// and error history for the status panel and diagnostics screens.
/// All metrics are computed from timestamped samples and are designed
/// to be lightweight enough for periodic refresh without impacting
/// battery life.
library;

import 'dart:collection';
import 'dart:convert';

import 'mqtt_constants.dart';

/// Direction of message flow for throughput tracking.
enum MessageDirection {
  /// Messages received from the broker (remote → local).
  inbound,

  /// Messages published to the broker (local → remote).
  outbound;

  String get displayLabel => switch (this) {
    inbound => 'Inbound',
    outbound => 'Outbound',
  };
}

/// A single timestamped throughput sample.
class ThroughputSample {
  /// When this sample was recorded.
  final DateTime timestamp;

  /// Direction of the message that triggered this sample.
  final MessageDirection direction;

  /// Size of the message payload in bytes, if available.
  final int? payloadBytes;

  /// The MQTT topic the message was on, if available.
  final String? topic;

  const ThroughputSample({
    required this.timestamp,
    required this.direction,
    this.payloadBytes,
    this.topic,
  });

  /// Whether this sample is within the metrics rolling window.
  bool get isWithinWindow {
    final cutoff = DateTime.now().subtract(GlobalLayerConstants.metricsWindow);
    return timestamp.isAfter(cutoff);
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'direction': direction.name,
    if (payloadBytes != null) 'payloadBytes': payloadBytes,
    if (topic != null) 'topic': topic,
  };
}

/// A recorded error event for the diagnostics history.
class ConnectionErrorRecord {
  /// When the error occurred.
  final DateTime timestamp;

  /// Human-readable error message (sanitized — no secrets).
  final String message;

  /// Error classification for grouping in diagnostics.
  final ConnectionErrorType type;

  /// Whether this error was automatically recovered from.
  final bool recovered;

  const ConnectionErrorRecord({
    required this.timestamp,
    required this.message,
    required this.type,
    this.recovered = false,
  });

  /// Duration since this error occurred.
  Duration get age => DateTime.now().difference(timestamp);

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'message': message,
    'type': type.name,
    'recovered': recovered,
  };

  ConnectionErrorRecord copyWith({bool? recovered}) {
    return ConnectionErrorRecord(
      timestamp: timestamp,
      message: message,
      type: type,
      recovered: recovered ?? this.recovered,
    );
  }

  @override
  String toString() =>
      'ConnectionErrorRecord(${type.name}: $message, '
      '${timestamp.toIso8601String()}, '
      'recovered: $recovered)'; // lint-allow: hardcoded-string
}

/// Classification of connection errors for diagnostics grouping.
enum ConnectionErrorType {
  /// DNS resolution failed — host not found.
  dnsFailure,

  /// TCP connection could not be established.
  tcpFailure,

  /// TLS handshake failed (certificate error, protocol mismatch).
  tlsFailure,

  /// Authentication rejected by the broker.
  authFailure,

  /// Subscribe operation failed or was rejected.
  subscribeFailure,

  /// Publish operation failed.
  publishFailure,

  /// Connection was unexpectedly dropped by the broker.
  brokerDisconnect,

  /// Network connectivity lost (device went offline).
  networkLoss,

  /// Connection or operation timed out.
  timeout,

  /// Ping/keep-alive response not received.
  pingTimeout,

  /// An unclassified error.
  unknown;

  /// Human-readable label for the diagnostics UI.
  String get displayLabel => switch (this) {
    dnsFailure => 'DNS Resolution Failed', // lint-allow: hardcoded-string
    tcpFailure => 'Connection Refused', // lint-allow: hardcoded-string
    tlsFailure => 'TLS Handshake Failed', // lint-allow: hardcoded-string
    authFailure => 'Authentication Failed', // lint-allow: hardcoded-string
    subscribeFailure => 'Subscribe Rejected', // lint-allow: hardcoded-string
    publishFailure => 'Publish Failed', // lint-allow: hardcoded-string
    brokerDisconnect => 'Broker Disconnected', // lint-allow: hardcoded-string
    networkLoss => 'Network Offline', // lint-allow: hardcoded-string
    timeout => 'Connection Timeout', // lint-allow: hardcoded-string
    pingTimeout => 'Keep-Alive Timeout', // lint-allow: hardcoded-string
    unknown => 'Unknown Error', // lint-allow: hardcoded-string
  };

  /// Suggested user action for each error type.
  String get suggestedAction => switch (this) {
    dnsFailure =>
      'Check the broker hostname for typos. Verify your device ' // lint-allow: hardcoded-string
          'has internet access.', // lint-allow: hardcoded-string
    tcpFailure =>
      'The broker may be offline or the port may be incorrect. ' // lint-allow: hardcoded-string
          'Verify the host and port, and check if a firewall is ' // lint-allow: hardcoded-string
          'blocking the connection.', // lint-allow: hardcoded-string
    tlsFailure =>
      'The broker may not support TLS on this port, or its ' // lint-allow: hardcoded-string
          'certificate may be invalid. Try toggling TLS off, or ' // lint-allow: hardcoded-string
          'use port ${GlobalLayerConstants.defaultPort} for unencrypted ' // lint-allow: hardcoded-string
          'connections.',
    authFailure =>
      'Check your username and password. Some brokers require ' // lint-allow: hardcoded-string
          'specific credentials or do not allow anonymous access.', // lint-allow: hardcoded-string
    subscribeFailure =>
      'The broker rejected the subscription. Check that the topic ' // lint-allow: hardcoded-string
          'is valid and that your account has permission to subscribe.', // lint-allow: hardcoded-string
    publishFailure =>
      'The broker rejected the publish. Check that the topic is ' // lint-allow: hardcoded-string
          'valid and that your account has permission to publish.', // lint-allow: hardcoded-string
    brokerDisconnect =>
      'The broker closed the connection. This may be due to ' // lint-allow: hardcoded-string
          'idle timeout, duplicate client ID, or broker maintenance.', // lint-allow: hardcoded-string
    networkLoss =>
      'Your device appears to be offline. Check your Wi-Fi or ' // lint-allow: hardcoded-string
          'cellular connection.', // lint-allow: hardcoded-string
    timeout =>
      'The connection attempt timed out. The broker may be ' // lint-allow: hardcoded-string
          'unreachable or overloaded.', // lint-allow: hardcoded-string
    pingTimeout =>
      'The broker stopped responding to keep-alive pings. ' // lint-allow: hardcoded-string
          'The connection may have been silently dropped.', // lint-allow: hardcoded-string
    unknown =>
      'An unexpected error occurred. Check the diagnostics log ' // lint-allow: hardcoded-string
          'for details.', // lint-allow: hardcoded-string
  };

  /// Whether this error type is likely caused by misconfiguration
  /// (as opposed to transient network issues).
  bool get isConfigurationError => switch (this) {
    dnsFailure || tcpFailure || tlsFailure || authFailure => true,
    _ => false,
  };
}

/// Aggregated health metrics for the Global Layer connection.
///
/// This is an immutable snapshot of the current connection health.
/// A new instance is created on each metrics refresh cycle.
class GlobalLayerMetrics {
  /// Timestamp of the last successful ping/keep-alive response.
  final DateTime? lastPingAt;

  /// Round-trip time of the last ping in milliseconds.
  final int? lastPingMs;

  /// Number of reconnection attempts since the last clean connect.
  final int reconnectCount;

  /// Rolling throughput samples within the metrics window.
  final List<ThroughputSample> _samples;

  /// Recent error history (bounded by [GlobalLayerConstants.maxRecentErrors]).
  final List<ConnectionErrorRecord> _recentErrors;

  /// Timestamp when the current connection session started.
  final DateTime? sessionStartedAt;

  /// Total number of messages received since session start.
  final int totalInbound;

  /// Total number of messages published since session start.
  final int totalOutbound;

  /// Total bytes received since session start.
  final int totalBytesInbound;

  /// Total bytes published since session start.
  final int totalBytesOutbound;

  const GlobalLayerMetrics({
    this.lastPingAt,
    this.lastPingMs,
    this.reconnectCount = 0,
    this._samples = const [],
    this._recentErrors = const [],
    this.sessionStartedAt,
    this.totalInbound = 0,
    this.totalOutbound = 0,
    this.totalBytesInbound = 0,
    this.totalBytesOutbound = 0,
  });

  /// Empty metrics representing a fresh or disabled state.
  static const GlobalLayerMetrics empty = GlobalLayerMetrics();

  // ---------------------------------------------------------------------------
  // Derived metrics
  // ---------------------------------------------------------------------------

  /// Unmodifiable view of throughput samples.
  List<ThroughputSample> get samples => UnmodifiableListView(_samples);

  /// Unmodifiable view of recent errors.
  List<ConnectionErrorRecord> get recentErrors =>
      UnmodifiableListView(_recentErrors);

  /// Duration of the current connection session.
  Duration? get sessionDuration {
    if (sessionStartedAt == null) return null;
    return DateTime.now().difference(sessionStartedAt!);
  }

  /// Human-readable session duration string.
  String get sessionDurationDisplay {
    final duration = sessionDuration;
    if (duration == null) return 'N/A'; // lint-allow: hardcoded-string

    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    }
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    }
    return '${duration.inSeconds}s';
  }

  /// Time elapsed since the last ping response.
  Duration? get timeSinceLastPing {
    if (lastPingAt == null) return null;
    return DateTime.now().difference(lastPingAt!);
  }

  /// Inbound message rate (messages per minute) within the rolling window.
  double get inboundRate {
    final windowSamples = _samplesInWindow(MessageDirection.inbound);
    if (windowSamples.isEmpty) return 0;
    final windowMinutes = GlobalLayerConstants.metricsWindow.inSeconds / 60;
    return windowSamples.length / windowMinutes;
  }

  /// Outbound message rate (messages per minute) within the rolling window.
  double get outboundRate {
    final windowSamples = _samplesInWindow(MessageDirection.outbound);
    if (windowSamples.isEmpty) return 0;
    final windowMinutes = GlobalLayerConstants.metricsWindow.inSeconds / 60;
    return windowSamples.length / windowMinutes;
  }

  /// Combined message rate (messages per minute) within the rolling window.
  double get combinedRate => inboundRate + outboundRate;

  /// Human-readable throughput display string.
  String get throughputDisplay {
    final rate = combinedRate;
    if (rate < 0.1) return 'Idle';
    if (rate < 1) return '< 1 msg/min'; // lint-allow: hardcoded-string
    return '${rate.toStringAsFixed(1)} msg/min';
  }

  /// Total messages (inbound + outbound) since session start.
  int get totalMessages => totalInbound + totalOutbound;

  /// Total bytes (inbound + outbound) since session start.
  int get totalBytes => totalBytesInbound + totalBytesOutbound;

  /// Number of unrecovered errors.
  int get activeErrorCount => _recentErrors.where((e) => !e.recovered).length;

  /// The most recent error, if any.
  ConnectionErrorRecord? get lastError =>
      _recentErrors.isNotEmpty ? _recentErrors.last : null;

  /// Whether the connection appears healthy based on available signals.
  bool get isHealthy {
    if (activeErrorCount > 0) return false;
    if (lastPingAt != null) {
      final sincePing = timeSinceLastPing!;
      // Consider unhealthy if no ping response in 3x the keep-alive interval
      if (sincePing.inSeconds > GlobalLayerConstants.keepAliveSeconds * 3) {
        return false;
      }
    }
    return true;
  }

  /// Per-topic message counts within the rolling window.
  Map<String, int> get messageCountsByTopic {
    final counts = <String, int>{};
    final cutoff = DateTime.now().subtract(GlobalLayerConstants.metricsWindow);
    for (final sample in _samples) {
      if (sample.timestamp.isAfter(cutoff) && sample.topic != null) {
        counts[sample.topic!] = (counts[sample.topic!] ?? 0) + 1;
      }
    }
    return counts;
  }

  // ---------------------------------------------------------------------------
  // Mutation (returns new instance)
  // ---------------------------------------------------------------------------

  /// Records a new throughput sample.
  ///
  /// Automatically prunes samples outside the rolling window and
  /// caps the total at [GlobalLayerConstants.maxThroughputSamples].
  GlobalLayerMetrics recordSample(ThroughputSample sample) {
    final cutoff = DateTime.now().subtract(GlobalLayerConstants.metricsWindow);
    final pruned = _samples.where((s) => s.timestamp.isAfter(cutoff)).toList();
    pruned.add(sample);

    // Cap total samples
    while (pruned.length > GlobalLayerConstants.maxThroughputSamples) {
      pruned.removeAt(0);
    }

    final isInbound = sample.direction == MessageDirection.inbound;
    return GlobalLayerMetrics(
      lastPingAt: lastPingAt,
      lastPingMs: lastPingMs,
      reconnectCount: reconnectCount,
      samples: pruned,
      recentErrors: _recentErrors,
      sessionStartedAt: sessionStartedAt,
      totalInbound: totalInbound + (isInbound ? 1 : 0),
      totalOutbound: totalOutbound + (isInbound ? 0 : 1),
      totalBytesInbound:
          totalBytesInbound + (isInbound ? (sample.payloadBytes ?? 0) : 0),
      totalBytesOutbound:
          totalBytesOutbound + (isInbound ? 0 : (sample.payloadBytes ?? 0)),
    );
  }

  /// Records a ping response.
  GlobalLayerMetrics recordPing(int roundTripMs) {
    return GlobalLayerMetrics(
      lastPingAt: DateTime.now(),
      lastPingMs: roundTripMs,
      reconnectCount: reconnectCount,
      samples: _samples,
      recentErrors: _recentErrors,
      sessionStartedAt: sessionStartedAt,
      totalInbound: totalInbound,
      totalOutbound: totalOutbound,
      totalBytesInbound: totalBytesInbound,
      totalBytesOutbound: totalBytesOutbound,
    );
  }

  /// Records a connection error.
  ///
  /// Automatically caps the error history at
  /// [GlobalLayerConstants.maxRecentErrors].
  GlobalLayerMetrics recordError(ConnectionErrorRecord error) {
    final updated = List<ConnectionErrorRecord>.of(_recentErrors);
    updated.add(error);

    while (updated.length > GlobalLayerConstants.maxRecentErrors) {
      updated.removeAt(0);
    }

    return GlobalLayerMetrics(
      lastPingAt: lastPingAt,
      lastPingMs: lastPingMs,
      reconnectCount: reconnectCount,
      samples: _samples,
      recentErrors: updated,
      sessionStartedAt: sessionStartedAt,
      totalInbound: totalInbound,
      totalOutbound: totalOutbound,
      totalBytesInbound: totalBytesInbound,
      totalBytesOutbound: totalBytesOutbound,
    );
  }

  /// Increments the reconnect counter.
  GlobalLayerMetrics incrementReconnectCount() {
    return GlobalLayerMetrics(
      lastPingAt: lastPingAt,
      lastPingMs: lastPingMs,
      reconnectCount: reconnectCount + 1,
      samples: _samples,
      recentErrors: _recentErrors,
      sessionStartedAt: sessionStartedAt,
      totalInbound: totalInbound,
      totalOutbound: totalOutbound,
      totalBytesInbound: totalBytesInbound,
      totalBytesOutbound: totalBytesOutbound,
    );
  }

  /// Starts a new session, resetting counters but preserving error history.
  GlobalLayerMetrics startSession() {
    return GlobalLayerMetrics(
      lastPingAt: null,
      lastPingMs: null,
      reconnectCount: 0,
      samples: const [],
      recentErrors: _recentErrors,
      sessionStartedAt: DateTime.now(),
      totalInbound: 0,
      totalOutbound: 0,
      totalBytesInbound: 0,
      totalBytesOutbound: 0,
    );
  }

  /// Ends the current session, preserving metrics for review.
  GlobalLayerMetrics endSession() {
    return GlobalLayerMetrics(
      lastPingAt: lastPingAt,
      lastPingMs: lastPingMs,
      reconnectCount: reconnectCount,
      samples: _samples,
      recentErrors: _recentErrors,
      sessionStartedAt: null,
      totalInbound: totalInbound,
      totalOutbound: totalOutbound,
      totalBytesInbound: totalBytesInbound,
      totalBytesOutbound: totalBytesOutbound,
    );
  }

  /// Clears all error history.
  GlobalLayerMetrics clearErrors() {
    return GlobalLayerMetrics(
      lastPingAt: lastPingAt,
      lastPingMs: lastPingMs,
      reconnectCount: reconnectCount,
      samples: _samples,
      recentErrors: const [],
      sessionStartedAt: sessionStartedAt,
      totalInbound: totalInbound,
      totalOutbound: totalOutbound,
      totalBytesInbound: totalBytesInbound,
      totalBytesOutbound: totalBytesOutbound,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  /// Produces a redacted JSON summary safe for diagnostics export.
  ///
  /// No secrets are present in metrics, but this follows the same
  /// pattern as other redactable models for consistency.
  Map<String, dynamic> toRedactedJson() => {
    'lastPingAt': lastPingAt?.toIso8601String(),
    'lastPingMs': lastPingMs,
    'reconnectCount': reconnectCount,
    'sessionDuration': sessionDurationDisplay,
    'totalInbound': totalInbound,
    'totalOutbound': totalOutbound,
    'totalBytesInbound': totalBytesInbound,
    'totalBytesOutbound': totalBytesOutbound,
    'inboundRate': '${inboundRate.toStringAsFixed(2)} msg/min',
    'outboundRate': '${outboundRate.toStringAsFixed(2)} msg/min',
    'activeErrors': activeErrorCount,
    'recentErrors': _recentErrors
        .take(10)
        .map((e) => e.toJson())
        .toList(growable: false),
    'isHealthy': isHealthy,
  };

  /// Redacted JSON as a formatted string for copy-to-clipboard.
  String toRedactedString() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toRedactedJson());
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Returns samples within the rolling window filtered by direction.
  List<ThroughputSample> _samplesInWindow(MessageDirection direction) {
    final cutoff = DateTime.now().subtract(GlobalLayerConstants.metricsWindow);
    return _samples
        .where((s) => s.direction == direction && s.timestamp.isAfter(cutoff))
        .toList(growable: false);
  }

  @override
  String toString() =>
      'GlobalLayerMetrics('
      'session: $sessionDurationDisplay, ' // lint-allow: hardcoded-string
      'in: $totalInbound, out: $totalOutbound, ' // lint-allow: hardcoded-string
      'rate: $throughputDisplay, ' // lint-allow: hardcoded-string
      'reconnects: $reconnectCount, ' // lint-allow: hardcoded-string
      'errors: $activeErrorCount, ' // lint-allow: hardcoded-string
      'healthy: $isHealthy)'; // lint-allow: hardcoded-string
}
