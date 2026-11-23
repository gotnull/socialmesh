// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:math' as math;

/// Where a reading's receiver position came from.
enum RangeTestPositionSource { phone, radio }

/// One recorded Range Test run: every Range Test packet the connected radio
/// heard between Start and Stop.
class RangeTestSession {
  final int id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int readingCount;

  const RangeTestSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.readingCount,
  });

  bool get isOpen => endedAt == null;

  RangeTestSession copyWith({DateTime? endedAt, int? readingCount}) {
    return RangeTestSession(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      readingCount: readingCount ?? this.readingCount,
    );
  }

  factory RangeTestSession.fromMap(Map<String, Object?> map) {
    final endedMs = map['ended_at_ms'] as int?;
    return RangeTestSession(
      id: map['id']! as int,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        map['started_at_ms']! as int,
      ),
      endedAt: endedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endedMs),
      readingCount: (map['reading_count'] as int?) ?? 0,
    );
  }
}

/// One Range Test packet as recorded. A null measurement was not available:
/// no RF reading for a packet that came through MQTT, no receiver position
/// without a phone fix or a radio position, no distance without both ends.
class RangeTestReading {
  final int sessionId;
  final DateTime receivedAt;
  final int senderNodeNum;
  final String? senderName;
  final int packetId;
  final int? sequence;
  final String payload;
  final double? rxSnr;
  final int? rxRssi;
  final bool viaMqtt;
  final double? rxLatitude;
  final double? rxLongitude;
  final int? rxAltitude;
  final RangeTestPositionSource? rxPositionSource;
  final double? senderLatitude;
  final double? senderLongitude;
  final double? distanceMeters;

  const RangeTestReading({
    required this.sessionId,
    required this.receivedAt,
    required this.senderNodeNum,
    required this.senderName,
    required this.packetId,
    required this.sequence,
    required this.payload,
    required this.rxSnr,
    required this.rxRssi,
    required this.viaMqtt,
    required this.rxLatitude,
    required this.rxLongitude,
    required this.rxAltitude,
    required this.rxPositionSource,
    required this.senderLatitude,
    required this.senderLongitude,
    required this.distanceMeters,
  });

  bool get hasRxPosition => rxLatitude != null && rxLongitude != null;

  Map<String, Object?> toMap() => {
    'session_id': sessionId,
    'received_at_ms': receivedAt.millisecondsSinceEpoch,
    'sender_node_num': senderNodeNum,
    'sender_name': senderName,
    'packet_id': packetId,
    'sequence': sequence,
    'payload': payload,
    'rx_snr': rxSnr,
    'rx_rssi': rxRssi,
    'via_mqtt': viaMqtt ? 1 : 0,
    'rx_latitude': rxLatitude,
    'rx_longitude': rxLongitude,
    'rx_altitude': rxAltitude,
    'rx_position_source': rxPositionSource?.name,
    'sender_latitude': senderLatitude,
    'sender_longitude': senderLongitude,
    'distance_m': distanceMeters,
  };

  factory RangeTestReading.fromMap(Map<String, Object?> map) {
    final source = map['rx_position_source'] as String?;
    return RangeTestReading(
      sessionId: map['session_id']! as int,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        map['received_at_ms']! as int,
      ),
      senderNodeNum: map['sender_node_num']! as int,
      senderName: map['sender_name'] as String?,
      packetId: map['packet_id']! as int,
      sequence: map['sequence'] as int?,
      payload: map['payload']! as String,
      rxSnr: (map['rx_snr'] as num?)?.toDouble(),
      rxRssi: map['rx_rssi'] as int?,
      viaMqtt: map['via_mqtt'] == 1,
      rxLatitude: (map['rx_latitude'] as num?)?.toDouble(),
      rxLongitude: (map['rx_longitude'] as num?)?.toDouble(),
      rxAltitude: map['rx_altitude'] as int?,
      rxPositionSource: source == null
          ? null
          : RangeTestPositionSource.values.asNameMap()[source],
      senderLatitude: (map['sender_latitude'] as num?)?.toDouble(),
      senderLongitude: (map['sender_longitude'] as num?)?.toDouble(),
      distanceMeters: (map['distance_m'] as num?)?.toDouble(),
    );
  }
}

/// Figures for a session, computed from its readings in the order they were
/// received. Averages and the maximum cover only readings that carry the
/// value.
class RangeTestSummary {
  /// Readings that carried a sequence number.
  final int sequencedCount;

  /// Packets the senders transmitted while the session heard them, from the
  /// sequence numbers; null when no reading carried one.
  final int? expectedCount;
  final double? averageSnr;
  final double? averageRssi;
  final double? maxDistanceMeters;

  /// For each reading, how many packets from the same sender went unheard
  /// since that sender's previous reading.
  final List<int> missedBefore;

  const RangeTestSummary._({
    required this.sequencedCount,
    required this.expectedCount,
    required this.averageSnr,
    required this.averageRssi,
    required this.maxDistanceMeters,
    required this.missedBefore,
  });

  factory RangeTestSummary.of(List<RangeTestReading> readings) {
    // A sender restarts its count at 1 when it reboots, so a sequence that
    // does not go up starts a new run. Each run expects every number from
    // its first to its last.
    final runStart = <int, int>{};
    final lastSeq = <int, int>{};
    var expected = 0;
    var sequenced = 0;
    final missed = <int>[];
    for (final r in readings) {
      final seq = r.sequence;
      if (seq == null) {
        missed.add(0);
        continue;
      }
      sequenced++;
      final previous = lastSeq[r.senderNodeNum];
      if (previous == null || seq <= previous) {
        if (previous != null) {
          expected += previous - runStart[r.senderNodeNum]! + 1;
        }
        runStart[r.senderNodeNum] = seq;
        missed.add(0);
      } else {
        missed.add(seq - previous - 1);
      }
      lastSeq[r.senderNodeNum] = seq;
    }
    for (final entry in lastSeq.entries) {
      expected += entry.value - runStart[entry.key]! + 1;
    }

    double? average(Iterable<num> values) => values.isEmpty
        ? null
        : values.fold<double>(0, (sum, v) => sum + v) / values.length;
    final distances = readings.map((r) => r.distanceMeters).nonNulls;

    return RangeTestSummary._(
      sequencedCount: sequenced,
      expectedCount: sequenced == 0 ? null : expected,
      averageSnr: average(readings.map((r) => r.rxSnr).nonNulls),
      averageRssi: average(readings.map((r) => r.rxRssi).nonNulls),
      maxDistanceMeters: distances.isEmpty ? null : distances.reduce(math.max),
      missedBefore: missed,
    );
  }
}
