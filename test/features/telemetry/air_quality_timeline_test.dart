// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/telemetry/air_quality_timeline.dart';
import 'package:socialmesh/models/telemetry_log.dart';

// Air Quality timeline merge.
//
// Gas resistance lives in environment rows (Meshtastic wire format);
// the Air Quality Log merges the gas series at render time. A BME680
// node whose firmware also computes IAQ writes BOTH an air-quality row
// and an environment row from the same broadcast within milliseconds,
// so gas readings pair with the nearest same-node air row inside
// kAirQualityGasPairTolerance instead of producing duplicate cards.
void main() {
  final t0 = DateTime.utc(2026, 7, 1, 12);

  AirQualityMetricsLog air({
    required int nodeNum,
    required DateTime timestamp,
    int? iaq,
  }) => AirQualityMetricsLog(nodeNum: nodeNum, timestamp: timestamp, iaq: iaq);

  EnvironmentMetricsLog env({
    required int nodeNum,
    required DateTime timestamp,
    double? gasResistance,
    double? temperature,
  }) => EnvironmentMetricsLog(
    nodeNum: nodeNum,
    timestamp: timestamp,
    gasResistance: gasResistance,
    temperature: temperature,
  );

  test('gas-only environment reading becomes a standalone entry', () {
    final entries = buildAirQualityTimeline(const [], [
      env(nodeNum: 1, timestamp: t0, gasResistance: 3141),
    ]);

    expect(entries, hasLength(1));
    expect(entries.single.airQuality, isNull);
    expect(entries.single.gasResistance, 3141);
    expect(entries.single.nodeNum, 1);
  });

  test('environment readings without gas are ignored entirely', () {
    final entries = buildAirQualityTimeline(const [], [
      env(nodeNum: 1, timestamp: t0, temperature: 21.5),
    ]);

    expect(entries, isEmpty);
  });

  test('gas within tolerance attaches to the same-node air row', () {
    final entries = buildAirQualityTimeline(
      [air(nodeNum: 1, timestamp: t0, iaq: 60)],
      [
        env(
          nodeNum: 1,
          timestamp: t0.add(const Duration(seconds: 5)),
          gasResistance: 3141,
        ),
      ],
    );

    expect(entries, hasLength(1), reason: 'one broadcast, one card');
    expect(entries.single.airQuality?.iaq, 60);
    expect(entries.single.gasResistance, 3141);
  });

  test('gas beyond tolerance stays standalone', () {
    final entries = buildAirQualityTimeline(
      [air(nodeNum: 1, timestamp: t0, iaq: 60)],
      [
        env(
          nodeNum: 1,
          timestamp: t0.add(const Duration(minutes: 5)),
          gasResistance: 3141,
        ),
      ],
    );

    expect(entries, hasLength(2));
    expect(entries.first.airQuality, isNull, reason: 'newest first');
    expect(entries.first.gasResistance, 3141);
    expect(entries.last.airQuality?.iaq, 60);
    expect(entries.last.gasResistance, isNull);
  });

  test('nearest same-node air row wins when several are in range', () {
    final near = air(
      nodeNum: 1,
      timestamp: t0.add(const Duration(seconds: 2)),
      iaq: 61,
    );
    final far = air(
      nodeNum: 1,
      timestamp: t0.add(const Duration(seconds: 20)),
      iaq: 62,
    );
    final entries = buildAirQualityTimeline(
      [far, near],
      [env(nodeNum: 1, timestamp: t0, gasResistance: 3141)],
    );

    final nearEntry = entries.singleWhere((e) => e.airQuality?.iaq == 61);
    final farEntry = entries.singleWhere((e) => e.airQuality?.iaq == 62);
    expect(nearEntry.gasResistance, 3141);
    expect(farEntry.gasResistance, isNull);
  });

  test('cross-node readings never pair, even at identical timestamps', () {
    final entries = buildAirQualityTimeline(
      [air(nodeNum: 1, timestamp: t0, iaq: 60)],
      [env(nodeNum: 2, timestamp: t0, gasResistance: 3141)],
    );

    expect(entries, hasLength(2));
    final airEntry = entries.singleWhere((e) => e.airQuality != null);
    expect(airEntry.gasResistance, isNull);
    final gasEntry = entries.singleWhere((e) => e.airQuality == null);
    expect(gasEntry.nodeNum, 2);
  });

  test('a displaced pairing falls back to standalone, never disappears', () {
    // Two gas readings compete for one air row; the nearer wins and
    // the loser must still render as its own card.
    final entries = buildAirQualityTimeline(
      [air(nodeNum: 1, timestamp: t0, iaq: 60)],
      [
        env(
          nodeNum: 1,
          timestamp: t0.add(const Duration(seconds: 20)),
          gasResistance: 1000,
        ),
        env(
          nodeNum: 1,
          timestamp: t0.add(const Duration(seconds: 2)),
          gasResistance: 2000,
        ),
      ],
    );

    expect(entries, hasLength(2));
    final airEntry = entries.singleWhere((e) => e.airQuality != null);
    expect(airEntry.gasResistance, 2000, reason: 'nearest wins');
    final standalone = entries.singleWhere((e) => e.airQuality == null);
    expect(standalone.gasResistance, 1000);
  });

  test('output is newest-first regardless of input order', () {
    final entries = buildAirQualityTimeline(
      [
        air(nodeNum: 1, timestamp: t0, iaq: 60),
        air(nodeNum: 1, timestamp: t0.add(const Duration(hours: 2)), iaq: 62),
      ],
      [
        env(
          nodeNum: 2,
          timestamp: t0.add(const Duration(hours: 1)),
          gasResistance: 3141,
        ),
      ],
    );

    expect(entries.map((e) => e.timestamp).toList(), [
      t0.add(const Duration(hours: 2)),
      t0.add(const Duration(hours: 1)),
      t0,
    ]);
  });

  test('empty inputs produce an empty timeline', () {
    expect(buildAirQualityTimeline(const [], const []), isEmpty);
  });
}
