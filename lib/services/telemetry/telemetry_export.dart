// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

// PR-4: "App telemetry store export v1" — a pure (IO-free) formatter that
// turns the on-device telemetry samples into a stable, business-ingestible
// contract: per-metric CSV (typed, snake_case columns), NDJSON, and a
// structured JSON document.
//
// Scope honesty: this exports ONLY what the app's `telemetry` table holds
// (per-type model `toJson` + node_num + timestamp). It is NOT the gateway /
// decoded-MQTT ingest schema (gateway_id, packet_id, channel, portnum,
// from/to node, raw/decoded payload) — that is PR-5. No `protocol` column:
// the store does not record protocol per row.
//
// The input to every method is the per-type model `toJson()` maps (camelCase
// keys), grouped by metric_type string. The formatter never touches the
// database or the filesystem, so it is fully unit-testable.

/// One CSV/flat column: its stable snake_case [name] and how to pull its
/// value out of a model `toJson()` map.
class _Col {
  const _Col(this.name, this.extract);
  final String name;
  final Object? Function(Map<String, dynamic> json) extract;
}

abstract final class TelemetryExport {
  /// Bumped only on a breaking change to the column/record contract.
  static const int schemaVersion = 1;

  /// Provenance marker — this export is the app store, not the gateway ingest.
  static const String source = 'app_telemetry_db';

  /// The on-device store carries no decoded packet metadata.
  static const bool packetMetadataAvailable = false;

  /// Canonical, deterministic metric-type order for NDJSON/JSON/bundle.
  /// Values mirror `TelemetryType.*` in telemetry_database.dart (pinned by a
  /// test so they cannot drift).
  static const List<String> metricTypeOrder = [
    'device_metrics',
    'environment_metrics',
    'power_metrics',
    'air_quality_metrics',
    'position_log',
    'trace_route_log',
    'pax_counter_log',
    'detection_sensor_log',
  ];

  /// Common columns prefixing every CSV row / flat record, in order.
  static const List<String> commonColumns = [
    'schema_version',
    'metric_type',
    'node_num',
    'node_hex',
    'timestamp_utc',
    'timestamp_ms',
  ];

  /// Meshtastic-style node id, e.g. `!0000007b`.
  static String nodeHex(int nodeNum) =>
      '!${(nodeNum & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';

  static String _isoUtc(int epochMs) => DateTime.fromMillisecondsSinceEpoch(
    epochMs,
    isUtc: true,
  ).toIso8601String();

  /// Type-specific columns (after [commonColumns]), in deterministic order.
  static List<_Col> _typeColumns(String metricType) {
    switch (metricType) {
      case 'device_metrics':
        return [
          _Col('battery_level', (j) => j['batteryLevel']),
          _Col('voltage', (j) => j['voltage']),
          _Col('channel_utilization', (j) => j['channelUtilization']),
          _Col('air_util_tx', (j) => j['airUtilTx']),
          _Col('uptime_seconds', (j) => j['uptimeSeconds']),
        ];
      case 'environment_metrics':
        return [
          _Col('temperature', (j) => j['temperature']),
          _Col(
            'relative_humidity',
            (j) => j['relativeHumidity'] ?? j['humidity'],
          ),
          _Col('barometric_pressure', (j) => j['barometricPressure']),
          _Col('gas_resistance', (j) => j['gasResistance']),
          _Col('iaq', (j) => j['iaq']),
          _Col('lux', (j) => j['lux']),
          _Col('white_lux', (j) => j['whiteLux']),
          _Col('uv_lux', (j) => j['uvLux']),
          _Col('wind_direction', (j) => j['windDirection']),
          _Col('wind_speed', (j) => j['windSpeed']),
          _Col('wind_gust', (j) => j['windGust']),
          _Col('rainfall_1h', (j) => j['rainfall1h']),
          _Col('rainfall_24h', (j) => j['rainfall24h']),
          _Col('soil_moisture', (j) => j['soilMoisture']),
          _Col('soil_temperature', (j) => j['soilTemperature']),
        ];
      case 'power_metrics':
        return [
          _Col('ch1_voltage', (j) => j['ch1Voltage']),
          _Col('ch1_current', (j) => j['ch1Current']),
          _Col('ch2_voltage', (j) => j['ch2Voltage']),
          _Col('ch2_current', (j) => j['ch2Current']),
          _Col('ch3_voltage', (j) => j['ch3Voltage']),
          _Col('ch3_current', (j) => j['ch3Current']),
        ];
      case 'air_quality_metrics':
        return [
          _Col('pm10_standard', (j) => j['pm10Standard']),
          _Col('pm25_standard', (j) => j['pm25Standard']),
          _Col('pm100_standard', (j) => j['pm100Standard']),
          _Col('pm10_environmental', (j) => j['pm10Environmental']),
          _Col('pm25_environmental', (j) => j['pm25Environmental']),
          _Col('pm100_environmental', (j) => j['pm100Environmental']),
          _Col('particles_03um', (j) => j['particles03um']),
          _Col('particles_05um', (j) => j['particles05um']),
          _Col('particles_10um', (j) => j['particles10um']),
          _Col('particles_25um', (j) => j['particles25um']),
          _Col('particles_50um', (j) => j['particles50um']),
          _Col('particles_100um', (j) => j['particles100um']),
          _Col('co2', (j) => j['co2']),
        ];
      case 'position_log':
        return [
          _Col('latitude', (j) => j['latitude']),
          _Col('longitude', (j) => j['longitude']),
          _Col('altitude', (j) => j['altitude']),
          _Col('sats_in_view', (j) => j['satsInView']),
          _Col('speed', (j) => j['speed']),
          _Col('heading', (j) => j['heading']),
          _Col('precision_bits', (j) => j['precisionBits']),
        ];
      case 'trace_route_log':
        return [
          _Col('target_node', (j) => j['targetNode']),
          _Col('sent', (j) => j['sent']),
          _Col('response', (j) => j['response']),
          _Col('hops_towards', (j) => j['hopsTowards']),
          _Col('hops_back', (j) => j['hopsBack']),
          // CSV exposes only the count; the full nested hop list is preserved
          // in NDJSON/JSON `data`.
          _Col('hop_count', (j) => (j['hops'] as List?)?.length ?? 0),
          _Col('snr', (j) => j['snr']),
          _Col('via_mqtt', (j) => j['viaMqtt']),
        ];
      case 'pax_counter_log':
        return [
          _Col('wifi', (j) => j['wifi']),
          _Col('ble', (j) => j['ble']),
          _Col('uptime', (j) => j['uptime']),
          // Computed convenience; mirrors PaxCounterLog.total.
          _Col(
            'total',
            (j) => ((j['wifi'] as int?) ?? 0) + ((j['ble'] as int?) ?? 0),
          ),
        ];
      case 'detection_sensor_log':
        return [
          _Col('name', (j) => j['name']),
          _Col('detected', (j) => j['detected']),
          _Col('event_type', (j) => j['eventType']),
        ];
      default:
        return const [];
    }
  }

  /// Ordered CSV column names for [metricType] (common + type-specific).
  static List<String> csvColumns(String metricType) => [
    ...commonColumns,
    ..._typeColumns(metricType).map((c) => c.name),
  ];

  /// Flat, CSV-aligned view of one sample (common columns + typed columns).
  /// The returned map is insertion-ordered (Dart map literals are
  /// `LinkedHashMap`), so column order is stable.
  static Map<String, Object?> flatten(
    String metricType,
    Map<String, dynamic> json,
  ) {
    final ms = json['timestamp'] as int;
    final nodeNum = json['nodeNum'] as int;
    final m = <String, Object?>{};
    m['schema_version'] = schemaVersion;
    m['metric_type'] = metricType;
    m['node_num'] = nodeNum;
    m['node_hex'] = nodeHex(nodeNum);
    m['timestamp_utc'] = _isoUtc(ms);
    m['timestamp_ms'] = ms;
    for (final c in _typeColumns(metricType)) {
      m[c.name] = c.extract(json);
    }
    return m;
  }

  /// Rich NDJSON/JSON record: normalized metadata + the full model payload
  /// (`data`), so nested structures like trace-route hops survive.
  static Map<String, Object?> richRecord(
    String metricType,
    Map<String, dynamic> json,
  ) {
    final ms = json['timestamp'] as int;
    final nodeNum = json['nodeNum'] as int;
    return {
      'schema_version': schemaVersion,
      'metric_type': metricType,
      'node_num': nodeNum,
      'node_hex': nodeHex(nodeNum),
      'timestamp_utc': _isoUtc(ms),
      'timestamp_ms': ms,
      'data': json,
    };
  }

  /// Deterministic ordering within a metric type: node_num, then timestamp,
  /// then id. Never relies on database return order.
  static int _cmpWithinType(Map<String, dynamic> a, Map<String, dynamic> b) {
    final n = (a['nodeNum'] as int).compareTo(b['nodeNum'] as int);
    if (n != 0) return n;
    final t = (a['timestamp'] as int).compareTo(b['timestamp'] as int);
    if (t != 0) return t;
    return ((a['id'] as String?) ?? '').compareTo((b['id'] as String?) ?? '');
  }

  static List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> rows) =>
      [...rows]..sort(_cmpWithinType);

  /// Per-type CSV: header row + deterministically-sorted data rows.
  static String toCsv(String metricType, List<Map<String, dynamic>> entries) {
    final cols = csvColumns(metricType);
    final sb = StringBuffer()..writeln(cols.map(_csvCell).join(','));
    for (final json in _sorted(entries)) {
      final flat = flatten(metricType, json);
      sb.writeln(cols.map((c) => _csvCell(flat[c])).join(','));
    }
    return sb.toString();
  }

  /// One rich JSON record per line, across all types in canonical order.
  static String toNdjson(Map<String, List<Map<String, dynamic>>> byType) {
    final sb = StringBuffer();
    for (final type in metricTypeOrder) {
      final entries = byType[type];
      if (entries == null) continue;
      for (final json in _sorted(entries)) {
        sb.writeln(jsonEncode(richRecord(type, json)));
      }
    }
    return sb.toString();
  }

  /// Structured JSON document: provenance + honesty flags + per-type records.
  static String toStructuredJson(
    Map<String, List<Map<String, dynamic>>> byType, {
    required DateTime exportedAtUtc,
    String? appVersion,
  }) {
    final types = <String, Object?>{};
    for (final type in metricTypeOrder) {
      final entries = byType[type];
      if (entries == null) continue;
      types[type] = _sorted(entries).map((j) => richRecord(type, j)).toList();
    }
    return const JsonEncoder.withIndent('  ').convert({
      'schema_version': schemaVersion,
      'source': source,
      'packet_metadata_available': packetMetadataAvailable,
      'exported_at_utc': exportedAtUtc.toUtc().toIso8601String(),
      if (appVersion != null) 'app_version': appVersion,
      'types': types,
    });
  }

  /// Format a single CSV cell: invariant (no locale), with RFC-4180 escaping.
  /// Null → empty. Numbers use Dart's invariant `toString()` (always `.`).
  static String _csvCell(Object? value) {
    if (value == null) return '';
    final s = value is String ? value : value.toString();
    if (s.contains(',') ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
