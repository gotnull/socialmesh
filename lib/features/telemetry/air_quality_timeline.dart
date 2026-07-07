// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../models/telemetry_log.dart';

// Gas resistance lives on EnvironmentMetricsLog because that is where
// the Meshtastic wire format carries it, but users think of the
// BME680/688 gas sensor as an air-quality reading. The Air Quality Log
// therefore merges the gas series from environment rows at render time
// instead of duplicating samples into air-quality rows - historical
// readings appear immediately and the DB stays single-source.

/// Gas readings within this window of a same-node air-quality row are
/// treated as the same broadcast. A node whose firmware computes IAQ
/// writes BOTH rows milliseconds apart from one telemetry packet; a
/// naive concat would render two cards per sample. Far above write
/// skew, far below any telemetry broadcast interval.
const kAirQualityGasPairTolerance = Duration(seconds: 30);

/// One Air Quality Log card: an air-quality row, a standalone gas
/// reading, or an air-quality row with its paired gas reading.
class AirQualityTimelineEntry {
  final int nodeNum;
  final DateTime timestamp;

  /// Null for a standalone gas reading (gas-only sensor, no IAQ/PM).
  final AirQualityMetricsLog? airQuality;

  /// Gas resistance in ohms; null when the sample carried none.
  final double? gasResistance;

  const AirQualityTimelineEntry({
    required this.nodeNum,
    required this.timestamp,
    this.airQuality,
    this.gasResistance,
  });
}

/// Merges air-quality rows with the gas-resistance series from
/// environment rows into one newest-first timeline.
///
/// Each gas reading attaches to the nearest same-node air-quality row
/// within [kAirQualityGasPairTolerance] (nearest wins when several
/// compete); unmatched gas readings become standalone entries.
List<AirQualityTimelineEntry> buildAirQualityTimeline(
  List<AirQualityMetricsLog> airLogs,
  List<EnvironmentMetricsLog> envLogs,
) {
  final gasLogs = envLogs.where((e) => e.gasResistance != null).toList();

  // Best pairing per air row: air index -> (gas log, time distance).
  final pairedGas = <int, (EnvironmentMetricsLog, Duration)>{};
  final standaloneGas = <EnvironmentMetricsLog>[];

  for (final gas in gasLogs) {
    var bestIndex = -1;
    Duration? bestDistance;
    for (var i = 0; i < airLogs.length; i++) {
      final air = airLogs[i];
      if (air.nodeNum != gas.nodeNum) continue;
      final distance = (air.timestamp.difference(gas.timestamp)).abs();
      if (distance > kAirQualityGasPairTolerance) continue;
      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    if (bestIndex == -1) {
      standaloneGas.add(gas);
      continue;
    }
    final existing = pairedGas[bestIndex];
    if (existing == null || bestDistance! < existing.$2) {
      // A displaced earlier pairing falls back to standalone rather
      // than disappearing.
      if (existing != null) standaloneGas.add(existing.$1);
      pairedGas[bestIndex] = (gas, bestDistance!);
    } else {
      standaloneGas.add(gas);
    }
  }

  final entries = <AirQualityTimelineEntry>[
    for (var i = 0; i < airLogs.length; i++)
      AirQualityTimelineEntry(
        nodeNum: airLogs[i].nodeNum,
        timestamp: airLogs[i].timestamp,
        airQuality: airLogs[i],
        gasResistance: pairedGas[i]?.$1.gasResistance,
      ),
    for (final gas in standaloneGas)
      AirQualityTimelineEntry(
        nodeNum: gas.nodeNum,
        timestamp: gas.timestamp,
        gasResistance: gas.gasResistance,
      ),
  ];

  entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return entries;
}
