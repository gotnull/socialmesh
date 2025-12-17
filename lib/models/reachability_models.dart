// Mesh Reachability Models
//
// Data structures for probabilistic node reachability assessment.
// This system provides likelihood estimates, NOT delivery guarantees.
//
// Key constraints:
// - No routing tables exist in Meshtastic
// - No end-to-end acknowledgements beyond first hop
// - Forwarding is opportunistic and probabilistic
// - All data comes from passive observation only

/// Reach likelihood levels for display.
/// These map from the continuous 0.0-1.0 score to discrete categories.
///
/// Thresholds:
/// - High (≥0.7): Strong recent RF observations, low hop count, good signal metrics
/// - Medium (0.4-0.69): Moderate confidence based on available data
/// - Low (<0.4): Stale data, high hop count, poor signal, or insufficient observations
enum ReachLikelihood {
  /// Score ≥ 0.7
  /// Strong indicators: recent direct RF contact, low hop count, good RSSI/SNR
  high,

  /// Score 0.4 - 0.69
  /// Moderate confidence based on mixed or aging indicators
  medium,

  /// Score < 0.4
  /// Weak indicators: stale data, high hop count, poor signal, or expired observations
  low,
}

/// Per-node reachability metadata collected through passive observation.
///
/// This data is gathered WITHOUT sending any probe traffic.
/// All values come from packets naturally observed on the mesh.
class NodeReachabilityData {
  /// The node number this data pertains to
  final int nodeNum;

  /// Minimum hop count ever observed for this node.
  /// - 0 = Direct RF contact (best case)
  /// - 1+ = Packet was relayed through N intermediate nodes
  /// - null = Never observed hop count (no packets received with hop info)
  ///
  /// Note: Meshtastic packets include hopLimit which decreases as packets are relayed.
  /// We can infer hop count from (originalHopLimit - remainingHopLimit).
  /// However, this is approximate since originalHopLimit varies by sender config.
  final int? minimumObservedHopCount;

  /// Rolling average RSSI (Received Signal Strength Indicator) in dBm.
  /// Typical range: -120 (weak) to -40 (strong).
  /// null if no RSSI data available.
  ///
  /// Note: RSSI only meaningful for packets received directly via RF.
  /// Packets via MQTT or other paths may have no meaningful RSSI.
  final double? averageRssi;

  /// Rolling average SNR (Signal-to-Noise Ratio) in dB.
  /// Higher is better. Typical range: -20 to +15.
  /// null if no SNR data available.
  final double? averageSnr;

  /// Timestamp when we last heard ANY packet from this node.
  /// Used for freshness decay calculation.
  final DateTime? lastHeardAt;

  /// Count of packets observed directly via RF from this node.
  /// Direct RF = hop count of 0 at time of reception.
  final int directPacketCount;

  /// Count of packets observed indirectly (relayed) from this node.
  /// Indirect = hop count > 0 at time of reception.
  final int indirectPacketCount;

  /// Count of first-hop DM acknowledgements received from this node.
  /// Only counts acks for direct messages we sent.
  ///
  /// Note: Meshtastic only guarantees first-hop ack, not end-to-end delivery.
  /// A positive ack rate only indicates the first relay received our message.
  final int dmAckSuccessCount;

  /// Count of first-hop DM failures for messages sent to this node.
  /// Failures include: timeout, NAK, no route on first hop.
  final int dmAckFailureCount;

  /// Total number of observation samples used for RSSI averaging.
  /// Used for weighted averaging when new samples arrive.
  final int rssiSampleCount;

  /// Total number of observation samples used for SNR averaging.
  final int snrSampleCount;

  const NodeReachabilityData({
    required this.nodeNum,
    this.minimumObservedHopCount,
    this.averageRssi,
    this.averageSnr,
    this.lastHeardAt,
    this.directPacketCount = 0,
    this.indirectPacketCount = 0,
    this.dmAckSuccessCount = 0,
    this.dmAckFailureCount = 0,
    this.rssiSampleCount = 0,
    this.snrSampleCount = 0,
  });

  /// Create empty reachability data for a node.
  factory NodeReachabilityData.empty(int nodeNum) {
    return NodeReachabilityData(nodeNum: nodeNum);
  }

  /// Seconds since last heard from this node.
  /// Returns null if never heard.
  int? get lastHeardSeconds {
    if (lastHeardAt == null) return null;
    return DateTime.now().difference(lastHeardAt!).inSeconds;
  }

  /// Ratio of direct to indirect packet observations.
  /// Returns null if no packets observed.
  /// 1.0 = all direct, 0.0 = all indirect
  double? get directVsIndirectRatio {
    final total = directPacketCount + indirectPacketCount;
    if (total == 0) return null;
    return directPacketCount / total;
  }

  /// First-hop DM ack success ratio.
  /// Returns null if no DM attempts tracked.
  /// 1.0 = all succeeded, 0.0 = all failed
  ///
  /// IMPORTANT: This only indicates first-hop reliability, NOT end-to-end delivery.
  double? get dmAckSuccessRatio {
    final total = dmAckSuccessCount + dmAckFailureCount;
    if (total == 0) return null;
    return dmAckSuccessCount / total;
  }

  /// Whether we have any observational data for this node.
  bool get hasAnyData {
    return lastHeardAt != null ||
        minimumObservedHopCount != null ||
        averageRssi != null ||
        averageSnr != null ||
        directPacketCount > 0 ||
        indirectPacketCount > 0 ||
        dmAckSuccessCount > 0 ||
        dmAckFailureCount > 0;
  }

  /// Whether this node was observed via direct RF (hop count 0).
  bool get hasDirectRfObservation => directPacketCount > 0;

  /// Copy with updated fields
  NodeReachabilityData copyWith({
    int? nodeNum,
    int? minimumObservedHopCount,
    double? averageRssi,
    double? averageSnr,
    DateTime? lastHeardAt,
    int? directPacketCount,
    int? indirectPacketCount,
    int? dmAckSuccessCount,
    int? dmAckFailureCount,
    int? rssiSampleCount,
    int? snrSampleCount,
  }) {
    return NodeReachabilityData(
      nodeNum: nodeNum ?? this.nodeNum,
      minimumObservedHopCount:
          minimumObservedHopCount ?? this.minimumObservedHopCount,
      averageRssi: averageRssi ?? this.averageRssi,
      averageSnr: averageSnr ?? this.averageSnr,
      lastHeardAt: lastHeardAt ?? this.lastHeardAt,
      directPacketCount: directPacketCount ?? this.directPacketCount,
      indirectPacketCount: indirectPacketCount ?? this.indirectPacketCount,
      dmAckSuccessCount: dmAckSuccessCount ?? this.dmAckSuccessCount,
      dmAckFailureCount: dmAckFailureCount ?? this.dmAckFailureCount,
      rssiSampleCount: rssiSampleCount ?? this.rssiSampleCount,
      snrSampleCount: snrSampleCount ?? this.snrSampleCount,
    );
  }

  /// Update RSSI with a new sample using exponential moving average.
  NodeReachabilityData updateRssi(double newRssi) {
    final count = rssiSampleCount + 1;
    final alpha = 0.3; // Weight for new sample (higher = more responsive)

    final newAverage = averageRssi == null
        ? newRssi
        : (alpha * newRssi) + ((1 - alpha) * averageRssi!);

    return copyWith(averageRssi: newAverage, rssiSampleCount: count);
  }

  /// Update SNR with a new sample using exponential moving average.
  NodeReachabilityData updateSnr(double newSnr) {
    final count = snrSampleCount + 1;
    final alpha = 0.3;

    final newAverage = averageSnr == null
        ? newSnr
        : (alpha * newSnr) + ((1 - alpha) * averageSnr!);

    return copyWith(averageSnr: newAverage, snrSampleCount: count);
  }

  /// Update minimum hop count if the new observation is lower.
  NodeReachabilityData updateMinHopCount(int observedHopCount) {
    if (minimumObservedHopCount == null ||
        observedHopCount < minimumObservedHopCount!) {
      return copyWith(minimumObservedHopCount: observedHopCount);
    }
    return this;
  }

  /// Record a direct RF packet observation (hop count = 0).
  NodeReachabilityData recordDirectPacket() {
    return copyWith(
      directPacketCount: directPacketCount + 1,
      lastHeardAt: DateTime.now(),
    ).updateMinHopCount(0);
  }

  /// Record an indirect (relayed) packet observation.
  NodeReachabilityData recordIndirectPacket(int hopCount) {
    return copyWith(
      indirectPacketCount: indirectPacketCount + 1,
      lastHeardAt: DateTime.now(),
    ).updateMinHopCount(hopCount);
  }

  /// Record a DM first-hop ack result.
  NodeReachabilityData recordDmAck({required bool success}) {
    if (success) {
      return copyWith(dmAckSuccessCount: dmAckSuccessCount + 1);
    } else {
      return copyWith(dmAckFailureCount: dmAckFailureCount + 1);
    }
  }

  @override
  String toString() =>
      'NodeReachabilityData(nodeNum: $nodeNum, lastHeard: ${lastHeardSeconds}s ago, '
      'minHops: $minimumObservedHopCount, rssi: ${averageRssi?.toStringAsFixed(1)}, '
      'snr: ${averageSnr?.toStringAsFixed(1)}, direct: $directPacketCount, '
      'indirect: $indirectPacketCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeReachabilityData &&
          runtimeType == other.runtimeType &&
          nodeNum == other.nodeNum;

  @override
  int get hashCode => nodeNum.hashCode;
}

/// Result of reachability scoring for display purposes.
class ReachabilityResult {
  /// The raw score from 0.0 to 1.0 (exclusive of both endpoints).
  /// Higher = better likelihood of message delivery.
  final double score;

  /// The discrete likelihood category for display.
  final ReachLikelihood likelihood;

  /// Human-readable path depth description.
  /// Examples: "Direct RF", "Seen via 1 hop", "Seen via 3 hops", "Unknown"
  final String pathDepthLabel;

  /// Human-readable freshness description.
  /// Examples: "12s ago", "5m ago", "2h ago", "Never"
  final String freshnessLabel;

  /// Whether this result is based on actual observations.
  /// If false, it's a default/fallback result.
  final bool hasObservations;

  const ReachabilityResult({
    required this.score,
    required this.likelihood,
    required this.pathDepthLabel,
    required this.freshnessLabel,
    required this.hasObservations,
  });

  /// Create a result indicating no data available.
  factory ReachabilityResult.noData() {
    return const ReachabilityResult(
      score: 0.1, // Never 0.0 unless fully expired
      likelihood: ReachLikelihood.low,
      pathDepthLabel: 'Unknown',
      freshnessLabel: 'Never',
      hasObservations: false,
    );
  }
}
