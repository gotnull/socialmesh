// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PR-4: contract tests for the pure "app telemetry store export v1" formatter.
// Pins the stable column contract (order, escaping, nulls), deterministic row
// ordering, NDJSON/JSON round-trip + nested-hop preservation, empty/large
// datasets, the honesty flags, and that no fabricated (gateway/protocol)
// columns leak in.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/telemetry_log.dart';
import 'package:socialmesh/services/storage/telemetry_database.dart';
import 'package:socialmesh/services/telemetry/telemetry_export.dart';

DateTime _ts(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

void main() {
  group('metric type order pins TelemetryType (no drift)', () {
    test('order matches the database discriminators', () {
      expect(TelemetryExport.metricTypeOrder, [
        TelemetryType.deviceMetrics,
        TelemetryType.environmentMetrics,
        TelemetryType.powerMetrics,
        TelemetryType.airQualityMetrics,
        TelemetryType.positionLog,
        TelemetryType.traceRouteLog,
        TelemetryType.paxCounterLog,
        TelemetryType.detectionSensorLog,
      ]);
    });
  });

  group('honesty flags + provenance', () {
    test('schema_version / source / packet_metadata_available', () {
      expect(TelemetryExport.schemaVersion, 1);
      expect(TelemetryExport.source, 'app_telemetry_db');
      expect(TelemetryExport.packetMetadataAvailable, isFalse);
    });

    test('node_hex renders Meshtastic-style id', () {
      expect(TelemetryExport.nodeHex(123), '!0000007b');
    });
  });

  group('csvColumns — stable, documented headers in order', () {
    test('device_metrics header', () {
      expect(TelemetryExport.csvColumns(TelemetryType.deviceMetrics), [
        'schema_version',
        'metric_type',
        'node_num',
        'node_hex',
        'timestamp_utc',
        'timestamp_ms',
        'battery_level',
        'voltage',
        'channel_utilization',
        'air_util_tx',
        'uptime_seconds',
      ]);
    });

    test('trace_route_log exposes hop_count, never the nested hops list', () {
      final cols = TelemetryExport.csvColumns(TelemetryType.traceRouteLog);
      expect(cols, contains('hop_count'));
      expect(cols, isNot(contains('hops')));
    });

    test('pax_counter_log includes computed total', () {
      expect(
        TelemetryExport.csvColumns(TelemetryType.paxCounterLog),
        contains('total'),
      );
    });

    test('no fabricated columns leak in (no protocol / packet metadata)', () {
      for (final type in TelemetryExport.metricTypeOrder) {
        final cols = TelemetryExport.csvColumns(type);
        for (final banned in const [
          'protocol',
          'gateway_id',
          'packet_id',
          'channel_name',
          'channel_index',
          'portnum',
          'from_node_id',
          'to_node_id',
        ]) {
          expect(cols, isNot(contains(banned)), reason: '$type leaked $banned');
        }
      }
    });
  });

  group('toCsv', () {
    test('header-only output for an empty dataset', () {
      final csv = TelemetryExport.toCsv(TelemetryType.deviceMetrics, const []);
      final lines = const LineSplitter().convert(csv);
      expect(lines, hasLength(1));
      expect(
        lines.first,
        TelemetryExport.csvColumns(TelemetryType.deviceMetrics).join(','),
      );
    });

    test('rows are sorted by node_num, then timestamp, then id', () {
      final rows = [
        DeviceMetricsLog(
          id: 'b',
          nodeNum: 2,
          timestamp: _ts(1000),
          batteryLevel: 1,
        ).toJson(),
        DeviceMetricsLog(
          id: 'a',
          nodeNum: 1,
          timestamp: _ts(3000),
          batteryLevel: 2,
        ).toJson(),
        DeviceMetricsLog(
          id: 'a',
          nodeNum: 1,
          timestamp: _ts(1000),
          batteryLevel: 3,
        ).toJson(),
      ];
      final csv = TelemetryExport.toCsv(TelemetryType.deviceMetrics, rows);
      final lines = const LineSplitter().convert(csv);
      // node 1 @1000, node 1 @3000, node 2 @1000 → battery 3,2,1.
      expect(lines[1], startsWith('1,device_metrics,1,!00000001,'));
      expect(lines[1], endsWith(',3,,,,'));
      expect(lines[2], contains(',!00000001,'));
      expect(lines[3], startsWith('1,device_metrics,2,!00000002,'));
    });

    test('null fields render as empty cells', () {
      final csv = TelemetryExport.toCsv(TelemetryType.deviceMetrics, [
        DeviceMetricsLog(
          id: 'x',
          nodeNum: 7,
          timestamp: _ts(0),
          voltage: 3.7,
        ).toJson(),
      ]);
      final dataLine = const LineSplitter().convert(csv)[1];
      // battery_level empty, voltage 3.7, rest empty.
      expect(dataLine, endsWith(',,3.7,,,'));
    });

    test('values with comma / quote / newline are RFC-4180 escaped', () {
      final csv = TelemetryExport.toCsv(TelemetryType.detectionSensorLog, [
        DetectionSensorLog(
          id: 'x',
          nodeNum: 1,
          timestamp: _ts(0),
          name: 'a,b"c\nd',
          detected: true,
        ).toJson(),
      ]);
      expect(csv, contains('"a,b""c\nd"'));
    });

    test('numbers use invariant formatting (dot decimal, no grouping)', () {
      final csv = TelemetryExport.toCsv(TelemetryType.positionLog, [
        PositionLog(
          id: 'x',
          nodeNum: 1,
          timestamp: _ts(0),
          latitude: -37.77495,
          longitude: 144.93942,
          altitude: 1500,
        ).toJson(),
      ]);
      final dataLine = const LineSplitter().convert(csv)[1];
      expect(dataLine, contains('-37.77495,144.93942,1500,'));
    });
  });

  group('toNdjson', () {
    test('empty input → empty string', () {
      expect(TelemetryExport.toNdjson(const {}), isEmpty);
    });

    test('each line is a rich record with metadata + data', () {
      final ndjson = TelemetryExport.toNdjson({
        TelemetryType.deviceMetrics: [
          DeviceMetricsLog(
            id: 'x',
            nodeNum: 9,
            timestamp: _ts(1700000000000),
            batteryLevel: 80,
          ).toJson(),
        ],
      });
      final rec = jsonDecode(ndjson.trim()) as Map<String, dynamic>;
      expect(rec['schema_version'], 1);
      expect(rec['metric_type'], 'device_metrics');
      expect(rec['node_num'], 9);
      expect(rec['node_hex'], '!00000009');
      expect(rec['timestamp_ms'], 1700000000000);
      expect(rec['timestamp_utc'], endsWith('Z'));
      expect((rec['data'] as Map)['batteryLevel'], 80);
    });

    test('trace_route_log preserves nested hops in data', () {
      final ndjson = TelemetryExport.toNdjson({
        TelemetryType.traceRouteLog: [
          TraceRouteLog(
            id: 'x',
            nodeNum: 1,
            timestamp: _ts(0),
            targetNode: 2,
            hops: [
              TraceRouteHop(nodeNum: 5, snr: 4.5),
              TraceRouteHop(nodeNum: 6),
            ],
          ).toJson(),
        ],
      });
      final rec = jsonDecode(ndjson.trim()) as Map<String, dynamic>;
      final hops = (rec['data'] as Map)['hops'] as List;
      expect(hops, hasLength(2));
      expect((hops.first as Map)['nodeNum'], 5);
    });

    test('records are emitted in canonical metric-type order', () {
      final ndjson = TelemetryExport.toNdjson({
        TelemetryType.paxCounterLog: [
          PaxCounterLog(
            id: 'p',
            nodeNum: 1,
            timestamp: _ts(0),
            wifi: 1,
            ble: 2,
          ).toJson(),
        ],
        TelemetryType.deviceMetrics: [
          DeviceMetricsLog(
            id: 'd',
            nodeNum: 1,
            timestamp: _ts(0),
            batteryLevel: 50,
          ).toJson(),
        ],
      });
      final types = const LineSplitter()
          .convert(ndjson)
          .map((l) => (jsonDecode(l) as Map)['metric_type'])
          .toList();
      expect(types, ['device_metrics', 'pax_counter_log']);
    });
  });

  group('toStructuredJson', () {
    test('document carries provenance + honesty flags + per-type records', () {
      final json = TelemetryExport.toStructuredJson(
        {
          TelemetryType.deviceMetrics: [
            DeviceMetricsLog(
              id: 'x',
              nodeNum: 1,
              timestamp: _ts(0),
              batteryLevel: 10,
            ).toJson(),
          ],
        },
        exportedAtUtc: _ts(1700000000000),
        appVersion: '1.2.3+45',
      );
      final doc = jsonDecode(json) as Map<String, dynamic>;
      expect(doc['schema_version'], 1);
      expect(doc['source'], 'app_telemetry_db');
      expect(doc['packet_metadata_available'], isFalse);
      expect(doc['exported_at_utc'], endsWith('Z'));
      expect(doc['app_version'], '1.2.3+45');
      final device = (doc['types'] as Map)['device_metrics'] as List;
      expect(device, hasLength(1));
      expect((device.first as Map)['data']['batteryLevel'], 10);
    });

    test('large dataset (5000 rows) exports in full', () {
      final rows = List.generate(
        5000,
        (i) => DeviceMetricsLog(
          id: 'id$i',
          nodeNum: i % 7,
          timestamp: _ts(i * 1000),
          batteryLevel: i % 100,
        ).toJson(),
      );
      final json = TelemetryExport.toStructuredJson({
        TelemetryType.deviceMetrics: rows,
      }, exportedAtUtc: _ts(0));
      final doc = jsonDecode(json) as Map<String, dynamic>;
      expect((doc['types'] as Map)['device_metrics'], hasLength(5000));
    });
  });
}
