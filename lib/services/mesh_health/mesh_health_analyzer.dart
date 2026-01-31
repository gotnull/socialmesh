// SPDX-License-Identifier: GPL-3.0-or-later
// Mesh Network Health Analyzer Service
//
// Pure Dart service for analyzing mesh network telemetry.
// Performs windowed calculations without unbounded memory growth.
// Detects saturation, spam, flooding, and reliability issues.

import 'dart:async';
import 'dart:math' as math;

import 'mesh_health_models.dart';

/// Configuration for the mesh health analyzer
class MeshHealthConfig {
  /// Duration of the sliding analysis window (milliseconds)
  final int windowDurationMs;

  /// Maximum telemetry packets to retain
  final int maxPacketHistory;

  /// Maximum time-series data points for graphs
  final int maxGraphPoints;

  /// Channel utilization threshold for saturation warning (percent)
  final double saturationWarningThreshold;

  /// Channel utilization threshold for saturation critical (percent)
  final double saturationCriticalThreshold;

  /// Minimum TX interval to flag as spam (seconds)
  final int spamIntervalThresholdSec;

  /// Minimum hop count to flag as flooding
  final int floodHopThreshold;

  /// Reliability drop threshold (percent below average)
  final double reliabilityDropThreshold;

  /// RSSI threshold for signal degradation
  final int rssiDegradationThreshold;

  /// How often to emit snapshots (milliseconds)
  final int snapshotIntervalMs;

  const MeshHealthConfig({
    this.windowDurationMs = 60000, // 60 second window
    this.maxPacketHistory = 1000,
    this.maxGraphPoints = 120,
    this.saturationWarningThreshold = 50.0,
    this.saturationCriticalThreshold = 75.0,
    this.spamIntervalThresholdSec = 20,
    this.floodHopThreshold = 4,
    this.reliabilityDropThreshold = 0.3,
    this.rssiDegradationThreshold = -100,
    this.snapshotIntervalMs = 1000,
  });
}

/// Mesh health analyzer service
///
/// Thread-safe service for ingesting telemetry and computing health metrics.
/// Uses windowed calculations to prevent unbounded memory growth.
class MeshHealthAnalyzer {
  final MeshHealthConfig config;

  // Bounded packet history
  late final CircularBuffer<MeshTelemetry> _packetHistory;

  // Time-series for graphs
  late final CircularBuffer<UtilizationDataPoint> _utilizationHistory;

  // Per-node statistics (windowed)
  final Map<String, _NodeAccumulator> _nodeAccumulators = {};

  // Current detected issues
  final List<HealthIssue> _activeIssues = [];

  // Stream controller for health snapshots
  final _snapshotController = StreamController<MeshHealthSnapshot>.broadcast();

  // Snapshot timer
  Timer? _snapshotTimer;

  // Baseline metrics for comparison
  double? _baselineReliability;
  double? _baselineRssi;

  MeshHealthAnalyzer({this.config = const MeshHealthConfig()}) {
    _packetHistory = CircularBuffer(config.maxPacketHistory);
    _utilizationHistory = CircularBuffer(config.maxGraphPoints);
  }

  /// Stream of health snapshots for UI updates
  Stream<MeshHealthSnapshot> get snapshots => _snapshotController.stream;

  /// Start periodic snapshot emission
  void start() {
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer.periodic(
      Duration(milliseconds: config.snapshotIntervalMs),
      (_) => _emitSnapshot(),
    );
  }

  /// Stop periodic snapshots
  void stop() {
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
  }

  /// Dispose resources
  void dispose() {
    stop();
    _snapshotController.close();
  }

  /// Ingest a single telemetry packet
  void ingestTelemetry(MeshTelemetry telemetry) {
    _packetHistory.add(telemetry);
    _updateNodeAccumulator(telemetry);
    _pruneStaleData(telemetry.timestamp);
  }

  /// Ingest telemetry from JSON
  void ingestJson(Map<String, dynamic> json) {
    ingestTelemetry(MeshTelemetry.fromJson(json));
  }

  /// Ingest multiple telemetry packets (batch)
  void ingestBatch(List<MeshTelemetry> packets) {
    for (final packet in packets) {
      ingestTelemetry(packet);
    }
  }

  /// Get current health snapshot synchronously
  MeshHealthSnapshot getSnapshot() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return _computeSnapshot(now);
  }

  /// Get utilization time-series for graphs
  List<UtilizationDataPoint> getUtilizationHistory() {
    return _utilizationHistory.toList();
  }

  /// Get per-node statistics
  List<NodeStats> getNodeStats() {
    return _nodeAccumulators.values.map((a) => a.toStats()).toList()
      ..sort((a, b) => b.totalAirtimeMs.compareTo(a.totalAirtimeMs));
  }

  /// Get top N contributors to channel utilization
  List<NodeStats> getTopContributors({int limit = 5}) {
    final stats = getNodeStats();
    return stats.take(limit).toList();
  }

  /// Compute channel utilization percentage
  double computeUtilization() {
    if (_packetHistory.isEmpty) return 0;

    final packets = _getWindowedPackets();
    if (packets.isEmpty) return 0;

    final totalAirtimeMs = packets.fold<int>(0, (sum, p) => sum + p.airtimeMs);
    return (totalAirtimeMs / config.windowDurationMs) * 100;
  }

  /// Compute average reliability in window
  double computeAverageReliability() {
    final packets = _getWindowedPackets();
    if (packets.isEmpty) return 1.0;

    final sum = packets.fold<double>(0, (sum, p) => sum + p.reliability);
    return sum / packets.length;
  }

  /// Compute average RSSI in window
  double computeAverageRssi() {
    final packets = _getWindowedPackets();
    if (packets.isEmpty) return -80;

    final sum = packets.fold<int>(0, (sum, p) => sum + p.rssi);
    return sum / packets.length;
  }

  /// Compute average SNR in window
  double computeAverageSnr() {
    final packets = _getWindowedPackets();
    if (packets.isEmpty) return 10;

    final sum = packets.fold<double>(0, (sum, p) => sum + p.snr);
    return sum / packets.length;
  }

  /// Detect nodes transmitting under configured interval threshold
  List<NodeStats> detectIntervalSpammers() {
    return getNodeStats().where((n) => n.isSpamming).toList();
  }

  /// Detect nodes using max hop propagation
  List<NodeStats> detectHopFlooders() {
    return getNodeStats().where((n) => n.isHopFlooding).toList();
  }

  /// Detect unknown nodes contributing significant traffic
  List<NodeStats> detectUnknownNodeFlood() {
    final unknowns = getNodeStats().where((n) => !n.isKnownNode).toList();
    final totalAirtime = _packetHistory.items.fold<int>(
      0,
      (sum, p) => sum + p.airtimeMs,
    );

    if (totalAirtime == 0) return [];

    // Flag unknown nodes contributing >10% of traffic
    return unknowns
        .where((n) => (n.totalAirtimeMs / totalAirtime) > 0.1)
        .toList();
  }

  /// Attribute root cause for reliability drops
  List<HealthIssue> attributeReliabilityDrop() {
    final issues = <HealthIssue>[];
    final currentReliability = computeAverageReliability();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Set baseline if not set
    _baselineReliability ??= currentReliability;

    // Check if reliability dropped significantly
    if (_baselineReliability! - currentReliability >
        config.reliabilityDropThreshold) {
      // Analyze possible causes
      final utilization = computeUtilization();
      final spammers = detectIntervalSpammers();
      final flooders = detectHopFlooders();
      final avgRssi = computeAverageRssi();

      if (utilization >= config.saturationWarningThreshold) {
        issues.add(
          HealthIssue(
            type: HealthIssueType.reliabilityDrop,
            severity: IssueSeverity.warning,
            message:
                'Reliability drop likely caused by channel saturation (${utilization.toStringAsFixed(1)}%)',
            metric: currentReliability,
            timestamp: now,
          ),
        );
      } else if (spammers.isNotEmpty) {
        final topSpammer = spammers.first;
        issues.add(
          HealthIssue(
            type: HealthIssueType.reliabilityDrop,
            severity: IssueSeverity.warning,
            message:
                'Reliability drop correlated with spam from ${topSpammer.nodeId}',
            nodeId: topSpammer.nodeId,
            metric: currentReliability,
            timestamp: now,
          ),
        );
      } else if (flooders.isNotEmpty) {
        final topFlooder = flooders.first;
        issues.add(
          HealthIssue(
            type: HealthIssueType.reliabilityDrop,
            severity: IssueSeverity.warning,
            message:
                'Reliability drop correlated with hop flooding from ${topFlooder.nodeId}',
            nodeId: topFlooder.nodeId,
            metric: currentReliability,
            timestamp: now,
          ),
        );
      } else if (avgRssi < config.rssiDegradationThreshold) {
        issues.add(
          HealthIssue(
            type: HealthIssueType.reliabilityDrop,
            severity: IssueSeverity.warning,
            message:
                'Reliability drop likely caused by signal degradation (RSSI: ${avgRssi.toStringAsFixed(0)} dBm)',
            metric: currentReliability,
            timestamp: now,
          ),
        );
      } else {
        issues.add(
          HealthIssue(
            type: HealthIssueType.reliabilityDrop,
            severity: IssueSeverity.info,
            message:
                'Reliability dropped to ${(currentReliability * 100).toStringAsFixed(1)}% - cause unknown',
            metric: currentReliability,
            timestamp: now,
          ),
        );
      }
    }

    // Slowly adjust baseline
    _baselineReliability =
        _baselineReliability! * 0.95 + currentReliability * 0.05;

    return issues;
  }

  /// Run all detection algorithms and return issues
  List<HealthIssue> detectAllIssues() {
    final issues = <HealthIssue>[];
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 1. Channel saturation
    final utilization = computeUtilization();
    if (utilization >= config.saturationCriticalThreshold) {
      issues.add(
        HealthIssue(
          type: HealthIssueType.channelSaturation,
          severity: IssueSeverity.critical,
          message:
              'Channel critically saturated at ${utilization.toStringAsFixed(1)}%',
          metric: utilization,
          timestamp: now,
        ),
      );
    } else if (utilization >= config.saturationWarningThreshold) {
      issues.add(
        HealthIssue(
          type: HealthIssueType.channelSaturation,
          severity: IssueSeverity.warning,
          message:
              'Channel utilization high at ${utilization.toStringAsFixed(1)}%',
          metric: utilization,
          timestamp: now,
        ),
      );
    }

    // 2. Interval spam
    final spammers = detectIntervalSpammers();
    for (final spammer in spammers) {
      issues.add(
        HealthIssue(
          type: HealthIssueType.intervalSpam,
          severity: IssueSeverity.warning,
          message:
              'Node ${spammer.nodeId} transmitting every ${spammer.actualIntervalSec.toStringAsFixed(1)}s (configured: ${spammer.avgTxIntervalSec}s)',
          nodeId: spammer.nodeId,
          metric: spammer.actualIntervalSec,
          timestamp: now,
        ),
      );
    }

    // 3. Hop flooding
    final flooders = detectHopFlooders();
    for (final flooder in flooders) {
      issues.add(
        HealthIssue(
          type: HealthIssueType.hopFlooding,
          severity: IssueSeverity.warning,
          message:
              'Node ${flooder.nodeId} using max hops (${flooder.maxHopCount}) excessively',
          nodeId: flooder.nodeId,
          metric: flooder.maxHopCount.toDouble(),
          timestamp: now,
        ),
      );
    }

    // 4. Unknown node flood
    final unknowns = detectUnknownNodeFlood();
    if (unknowns.isNotEmpty) {
      final totalUnknownAirtime = unknowns.fold<int>(
        0,
        (sum, n) => sum + n.totalAirtimeMs,
      );
      final totalAirtime = _packetHistory.items.fold<int>(
        0,
        (sum, p) => sum + p.airtimeMs,
      );
      final percent = totalAirtime > 0
          ? (totalUnknownAirtime / totalAirtime) * 100
          : 0.0;

      issues.add(
        HealthIssue(
          type: HealthIssueType.unknownNodeFlood,
          severity: percent > 30
              ? IssueSeverity.critical
              : IssueSeverity.warning,
          message:
              '${unknowns.length} unknown nodes contributing ${percent.toStringAsFixed(1)}% of traffic',
          metric: percent,
          timestamp: now,
        ),
      );
    }

    // 5. Signal degradation
    final avgRssi = computeAverageRssi();
    _baselineRssi ??= avgRssi;

    if (avgRssi < config.rssiDegradationThreshold) {
      issues.add(
        HealthIssue(
          type: HealthIssueType.signalDegradation,
          severity: avgRssi < -110
              ? IssueSeverity.critical
              : IssueSeverity.warning,
          message: 'Average RSSI degraded to ${avgRssi.toStringAsFixed(0)} dBm',
          metric: avgRssi,
          timestamp: now,
        ),
      );
    }

    // 6. Reliability attribution
    issues.addAll(attributeReliabilityDrop());

    return issues;
  }

  /// Clear all data and reset
  void reset() {
    _packetHistory.clear();
    _utilizationHistory.clear();
    _nodeAccumulators.clear();
    _activeIssues.clear();
    _baselineReliability = null;
    _baselineRssi = null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  void _updateNodeAccumulator(MeshTelemetry telemetry) {
    final accumulator = _nodeAccumulators.putIfAbsent(
      telemetry.nodeId,
      () => _NodeAccumulator(
        nodeId: telemetry.nodeId,
        isKnownNode: telemetry.isKnownNode,
      ),
    );
    accumulator.add(telemetry);
  }

  void _pruneStaleData(int currentTimestamp) {
    final cutoff = currentTimestamp - (config.windowDurationMs ~/ 1000);

    // Prune packet history
    _packetHistory.removeWhere((p) => p.timestamp < cutoff);

    // Prune node accumulators
    _nodeAccumulators.removeWhere((_, acc) => acc.lastSeen < cutoff);

    // Also prune packets within accumulators
    for (final acc in _nodeAccumulators.values) {
      acc.pruneOlderThan(cutoff);
    }
  }

  List<MeshTelemetry> _getWindowedPackets() {
    if (_packetHistory.isEmpty) return [];

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final cutoff = now - (config.windowDurationMs ~/ 1000);

    return _packetHistory.items.where((p) => p.timestamp >= cutoff).toList();
  }

  MeshHealthSnapshot _computeSnapshot(int timestamp) {
    final utilization = computeUtilization();
    final reliability = computeAverageReliability();
    final rssi = computeAverageRssi();
    final snr = computeAverageSnr();
    final packets = _getWindowedPackets();
    final nodeStats = getNodeStats();
    final issues = detectAllIssues();

    final knownCount = nodeStats.where((n) => n.isKnownNode).length;
    final unknownCount = nodeStats.where((n) => !n.isKnownNode).length;
    final totalAirtime = packets.fold<int>(0, (sum, p) => sum + p.airtimeMs);

    return MeshHealthSnapshot(
      timestamp: timestamp,
      channelUtilizationPercent: utilization,
      avgReliability: reliability,
      avgRssi: rssi,
      avgSnr: snr,
      totalPackets: packets.length,
      totalAirtimeMs: totalAirtime,
      activeNodeCount: nodeStats.length,
      knownNodeCount: knownCount,
      unknownNodeCount: unknownCount,
      activeIssues: issues,
      topContributors: getTopContributors(),
    );
  }

  void _emitSnapshot() {
    if (_snapshotController.isClosed) return;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final snapshot = _computeSnapshot(now);

    // Record utilization point for graph
    _utilizationHistory.add(
      UtilizationDataPoint(
        timestamp: now,
        utilizationPercent: snapshot.channelUtilizationPercent,
        reliability: snapshot.avgReliability,
        packetCount: snapshot.totalPackets,
      ),
    );

    _snapshotController.add(snapshot);
  }
}

/// Internal accumulator for per-node statistics
class _NodeAccumulator {
  final String nodeId;
  final bool isKnownNode;
  final List<MeshTelemetry> _packets = [];

  _NodeAccumulator({required this.nodeId, required this.isKnownNode});

  void add(MeshTelemetry packet) {
    _packets.add(packet);
  }

  void pruneOlderThan(int cutoffTimestamp) {
    _packets.removeWhere((p) => p.timestamp < cutoffTimestamp);
  }

  int get lastSeen => _packets.isNotEmpty ? _packets.last.timestamp : 0;
  int get firstSeen => _packets.isNotEmpty ? _packets.first.timestamp : 0;

  NodeStats toStats() {
    if (_packets.isEmpty) {
      return NodeStats(
        nodeId: nodeId,
        isKnownNode: isKnownNode,
        packetCount: 0,
        totalAirtimeMs: 0,
        totalPayloadBytes: 0,
        avgRssi: -80,
        avgSnr: 10,
        avgReliability: 1.0,
        avgTxIntervalSec: 900,
        maxHopCount: 3,
        avgHopCount: 0,
        firstSeen: 0,
        lastSeen: 0,
      );
    }

    final count = _packets.length;
    final totalAirtime = _packets.fold<int>(0, (s, p) => s + p.airtimeMs);
    final totalPayload = _packets.fold<int>(0, (s, p) => s + p.payloadBytes);
    final avgRssi = _packets.fold<int>(0, (s, p) => s + p.rssi) / count;
    final avgSnr = _packets.fold<double>(0, (s, p) => s + p.snr) / count;
    final avgRel =
        _packets.fold<double>(0, (s, p) => s + p.reliability) / count;
    final avgInterval =
        _packets.fold<int>(0, (s, p) => s + p.txIntervalSec) ~/ count;
    final maxHop = _packets.fold<int>(
      0,
      (max, p) => math.max(max, p.maxHopCount),
    );
    final avgHop = _packets.fold<int>(0, (s, p) => s + p.hopCount) ~/ count;

    return NodeStats(
      nodeId: nodeId,
      isKnownNode: isKnownNode,
      packetCount: count,
      totalAirtimeMs: totalAirtime,
      totalPayloadBytes: totalPayload,
      avgRssi: avgRssi,
      avgSnr: avgSnr,
      avgReliability: avgRel,
      avgTxIntervalSec: avgInterval,
      maxHopCount: maxHop,
      avgHopCount: avgHop,
      firstSeen: firstSeen,
      lastSeen: lastSeen,
    );
  }
}
