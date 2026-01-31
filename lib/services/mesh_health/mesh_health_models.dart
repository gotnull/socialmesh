// SPDX-License-Identifier: GPL-3.0-or-later
// Mesh Network Health Diagnostic Models
//
// Pure Dart models for telemetry data, node statistics, and health issues.
// No platform-specific dependencies.

import 'dart:collection';

/// Raw telemetry packet from mesh network
class MeshTelemetry {
  final int timestamp;
  final String nodeId;
  final bool isKnownNode;
  final int hopCount;
  final int maxHopCount;
  final int payloadBytes;
  final int rssi;
  final double snr;
  final int txIntervalSec;
  final double reliability;
  final int airtimeMs;

  const MeshTelemetry({
    required this.timestamp,
    required this.nodeId,
    required this.isKnownNode,
    required this.hopCount,
    required this.maxHopCount,
    required this.payloadBytes,
    required this.rssi,
    required this.snr,
    required this.txIntervalSec,
    required this.reliability,
    required this.airtimeMs,
  });

  factory MeshTelemetry.fromJson(Map<String, dynamic> json) {
    return MeshTelemetry(
      timestamp: json['timestamp'] as int,
      nodeId: json['node_id'] as String,
      isKnownNode: json['is_known_node'] as bool? ?? false,
      hopCount: json['hop_count'] as int? ?? 0,
      maxHopCount: json['max_hop_count'] as int? ?? 3,
      payloadBytes: json['payload_bytes'] as int? ?? 0,
      rssi: json['rssi'] as int? ?? -120,
      snr: (json['snr'] as num?)?.toDouble() ?? 0.0,
      txIntervalSec: json['tx_interval_sec'] as int? ?? 900,
      reliability: (json['reliability'] as num?)?.toDouble() ?? 1.0,
      airtimeMs: json['airtime_ms'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'node_id': nodeId,
    'is_known_node': isKnownNode,
    'hop_count': hopCount,
    'max_hop_count': maxHopCount,
    'payload_bytes': payloadBytes,
    'rssi': rssi,
    'snr': snr,
    'tx_interval_sec': txIntervalSec,
    'reliability': reliability,
    'airtime_ms': airtimeMs,
  };
}

/// Per-node aggregated statistics
class NodeStats {
  final String nodeId;
  final bool isKnownNode;
  final int packetCount;
  final int totalAirtimeMs;
  final int totalPayloadBytes;
  final double avgRssi;
  final double avgSnr;
  final double avgReliability;
  final int avgTxIntervalSec;
  final int maxHopCount;
  final int avgHopCount;
  final int firstSeen;
  final int lastSeen;

  const NodeStats({
    required this.nodeId,
    required this.isKnownNode,
    required this.packetCount,
    required this.totalAirtimeMs,
    required this.totalPayloadBytes,
    required this.avgRssi,
    required this.avgSnr,
    required this.avgReliability,
    required this.avgTxIntervalSec,
    required this.maxHopCount,
    required this.avgHopCount,
    required this.firstSeen,
    required this.lastSeen,
  });

  /// Average interval between packets (seconds)
  double get actualIntervalSec {
    if (packetCount < 2) return avgTxIntervalSec.toDouble();
    return (lastSeen - firstSeen) / (packetCount - 1);
  }

  /// Is this node transmitting faster than configured?
  bool get isSpamming => actualIntervalSec < 20 && packetCount > 2;

  /// Is this node using max hops excessively?
  bool get isHopFlooding => maxHopCount >= 4 && packetCount > 3;

  /// Node contribution to channel utilization (percentage)
  double utilizationPercent(int windowDurationMs) {
    if (windowDurationMs <= 0) return 0;
    return (totalAirtimeMs / windowDurationMs) * 100;
  }
}

/// Types of mesh health issues
enum HealthIssueType {
  channelSaturation,
  intervalSpam,
  hopFlooding,
  reliabilityDrop,
  signalDegradation,
  unknownNodeFlood,
}

/// Severity levels for health issues
enum IssueSeverity { info, warning, critical }

/// A detected health issue with attribution
class HealthIssue {
  final HealthIssueType type;
  final IssueSeverity severity;
  final String message;
  final String? nodeId;
  final double? metric;
  final int timestamp;

  const HealthIssue({
    required this.type,
    required this.severity,
    required this.message,
    this.nodeId,
    this.metric,
    required this.timestamp,
  });

  String get severityLabel {
    switch (severity) {
      case IssueSeverity.info:
        return 'INFO';
      case IssueSeverity.warning:
        return 'WARNING';
      case IssueSeverity.critical:
        return 'CRITICAL';
    }
  }

  String get typeLabel {
    switch (type) {
      case HealthIssueType.channelSaturation:
        return 'Channel Saturation';
      case HealthIssueType.intervalSpam:
        return 'Interval Spam';
      case HealthIssueType.hopFlooding:
        return 'Hop Flooding';
      case HealthIssueType.reliabilityDrop:
        return 'Reliability Drop';
      case HealthIssueType.signalDegradation:
        return 'Signal Degradation';
      case HealthIssueType.unknownNodeFlood:
        return 'Unknown Node Flood';
    }
  }
}

/// Overall mesh health snapshot
class MeshHealthSnapshot {
  final int timestamp;
  final double channelUtilizationPercent;
  final double avgReliability;
  final double avgRssi;
  final double avgSnr;
  final int totalPackets;
  final int totalAirtimeMs;
  final int activeNodeCount;
  final int knownNodeCount;
  final int unknownNodeCount;
  final List<HealthIssue> activeIssues;
  final List<NodeStats> topContributors;

  const MeshHealthSnapshot({
    required this.timestamp,
    required this.channelUtilizationPercent,
    required this.avgReliability,
    required this.avgRssi,
    required this.avgSnr,
    required this.totalPackets,
    required this.totalAirtimeMs,
    required this.activeNodeCount,
    required this.knownNodeCount,
    required this.unknownNodeCount,
    required this.activeIssues,
    required this.topContributors,
  });

  bool get isSaturated => channelUtilizationPercent >= 50;
  bool get isHealthy => activeIssues.isEmpty;
  bool get hasCriticalIssues =>
      activeIssues.any((i) => i.severity == IssueSeverity.critical);

  int get issueCount => activeIssues.length;
  int get criticalCount =>
      activeIssues.where((i) => i.severity == IssueSeverity.critical).length;
  int get warningCount =>
      activeIssues.where((i) => i.severity == IssueSeverity.warning).length;
}

/// Time-series data point for graphing
class UtilizationDataPoint {
  final int timestamp;
  final double utilizationPercent;
  final double reliability;
  final int packetCount;

  const UtilizationDataPoint({
    required this.timestamp,
    required this.utilizationPercent,
    required this.reliability,
    required this.packetCount,
  });
}

/// Bounded circular buffer for windowed calculations
class CircularBuffer<T> {
  final int capacity;
  final Queue<T> _buffer = Queue<T>();

  CircularBuffer(this.capacity);

  void add(T item) {
    if (_buffer.length >= capacity) {
      _buffer.removeFirst();
    }
    _buffer.add(item);
  }

  void clear() => _buffer.clear();

  int get length => _buffer.length;
  bool get isEmpty => _buffer.isEmpty;
  bool get isNotEmpty => _buffer.isNotEmpty;

  Iterable<T> get items => _buffer;
  T? get first => _buffer.isNotEmpty ? _buffer.first : null;
  T? get last => _buffer.isNotEmpty ? _buffer.last : null;

  List<T> toList() => _buffer.toList();

  /// Remove items that don't match predicate
  void removeWhere(bool Function(T) test) {
    _buffer.removeWhere(test);
  }
}
