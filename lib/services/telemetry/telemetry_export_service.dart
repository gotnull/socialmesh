// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/logging.dart';
import '../../models/telemetry_log.dart';
import '../../providers/telemetry_providers.dart';
import '../../utils/share_utils.dart';
import '../storage/telemetry_database.dart';
import 'telemetry_export.dart';

/// PR-4: builds the "app telemetry store export v1" bundle (zip) and shares it.
///
/// Pulls the on-device telemetry store, runs the pure [TelemetryExport]
/// formatter, and packages per-type CSVs + NDJSON + structured JSON + a
/// manifest + README. Honest scope: this is the app store, not the gateway /
/// decoded-MQTT ingest contract (PR-5).
class TelemetryExportService {
  TelemetryExportService(this._db);

  final TelemetryDatabase _db;

  /// Collects every stored sample as per-type `toJson` maps, omitting empty
  /// types. Order is canonical; row sorting happens in the formatter.
  Future<Map<String, List<Map<String, dynamic>>>> _collect() async {
    final byType = <String, List<Map<String, dynamic>>>{};
    void put(String type, List<TelemetryLogEntry> entries) {
      if (entries.isNotEmpty) {
        byType[type] = entries.map((e) => e.toJson()).toList();
      }
    }

    put(TelemetryType.deviceMetrics, await _db.getAllDeviceMetrics());
    put(TelemetryType.environmentMetrics, await _db.getAllEnvironmentMetrics());
    put(TelemetryType.powerMetrics, await _db.getAllPowerMetrics());
    put(TelemetryType.airQualityMetrics, await _db.getAllAirQualityMetrics());
    put(TelemetryType.positionLog, await _db.getAllPositionLogs());
    put(TelemetryType.traceRouteLog, await _db.getAllTraceRouteLogs());
    put(TelemetryType.paxCounterLog, await _db.getAllPaxCounterLogs());
    put(
      TelemetryType.detectionSensorLog,
      await _db.getAllDetectionSensorLogs(),
    );
    return byType;
  }

  /// Builds the export zip and returns its path, or `null` when the store
  /// holds no samples (the caller should show an empty-state message rather
  /// than share a confusing empty bundle).
  Future<String?> buildBundle({
    required DateTime exportedAtUtc,
    String? appVersion,
  }) async {
    final byType = await _collect();
    if (byType.isEmpty) return null;

    final archive = Archive();
    void add(String name, String contents) {
      final bytes = utf8.encode(contents);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    // Per-type CSVs (only non-empty types).
    final counts = <String, int>{};
    for (final type in TelemetryExport.metricTypeOrder) {
      final entries = byType[type];
      if (entries == null) continue;
      counts[type] = entries.length;
      add('$type.csv', TelemetryExport.toCsv(type, entries));
    }

    add('telemetry.ndjson', TelemetryExport.toNdjson(byType));
    add(
      'telemetry.json',
      TelemetryExport.toStructuredJson(
        byType,
        exportedAtUtc: exportedAtUtc,
        appVersion: appVersion,
      ),
    );
    add('manifest.json', _manifestJson(counts, exportedAtUtc, appVersion));
    add('README.txt', _readme());

    final zipData = ZipEncoder().encode(archive);
    final tempDir = await getTemporaryDirectory();
    final stamp = exportedAtUtc.toUtc().millisecondsSinceEpoch;
    final filePath = '${tempDir.path}/socialmesh_telemetry_$stamp.zip';
    await File(filePath).writeAsBytes(zipData);

    final total = counts.values.fold<int>(0, (a, b) => a + b);
    AppLogging.app('Telemetry export bundle saved: $filePath ($total samples)');
    return filePath;
  }

  /// Shares a built bundle via the platform share sheet.
  Future<void> shareBundle(String zipPath, {Rect? sharePosition}) async {
    await shareFiles(
      [XFile(zipPath)],
      subject:
          'SocialMesh telemetry export', // lint-allow: hardcoded-string — share-sheet subject, not in-app UI
      sharePositionOrigin: sharePosition,
    );
  }

  String _manifestJson(
    Map<String, int> counts,
    DateTime exportedAtUtc,
    String? appVersion,
  ) {
    final columnContract = <String, List<String>>{
      for (final type in counts.keys) type: TelemetryExport.csvColumns(type),
    };
    return const JsonEncoder.withIndent('  ').convert({
      'schema_version': TelemetryExport.schemaVersion,
      'source': TelemetryExport.source,
      'packet_metadata_available': TelemetryExport.packetMetadataAvailable,
      'exported_at_utc': exportedAtUtc.toUtc().toIso8601String(),
      if (appVersion != null) 'app_version': appVersion,
      'counts': counts,
      'total_samples': counts.values.fold<int>(0, (a, b) => a + b),
      'files': [
        for (final t in counts.keys) '$t.csv',
        'telemetry.ndjson',
        'telemetry.json',
        'manifest.json',
        'README.txt',
      ],
      'column_contract': columnContract,
    });
  }

  String _readme() => '''SocialMesh — App Telemetry Store Export (v1)
=============================================

This export contains telemetry samples stored by the SocialMesh app. It does
not yet represent the full decoded MQTT ingest schema planned for the SiteOps
gateway.

Contents:
  <metric_type>.csv  - one file per metric type, typed snake_case columns
  telemetry.ndjson   - one rich JSON record per line (preserves nested data,
                       e.g. trace-route hops); ideal for SQL/BigQuery ingest
  telemetry.json     - structured document: provenance + per-type records
  manifest.json      - schema_version, source, counts, and the column contract
  README.txt         - this file

Schema (schema_version 1):
  Every row/record carries common columns first, then type-specific columns:
    schema_version, metric_type, node_num, node_hex, timestamp_utc, timestamp_ms

Units (where known; otherwise unspecified):
  timestamp_utc   = UTC ISO-8601
  timestamp_ms    = Unix epoch milliseconds
  latitude/longitude = decimal degrees
  altitude        = metres
  voltage/current = volts / amperes (where the source makes this clear)
  temperature     = degrees Celsius (where the source makes this clear)
  Other units (lux, iaq, particle counts, etc.) are stored as the device
  reported them and are otherwise unspecified.

Conventions:
  - Numbers use invariant formatting (dot decimal separator, no grouping).
  - Empty/unknown values are empty CSV cells / JSON null.
  - There is no per-row protocol column: the store does not record protocol.
  - CSV exposes trace-route hop_count only; the full nested hop list is in the
    NDJSON/JSON `data` object.

Privacy:
  This export may contain telemetry and LOCATION data (node positions, fixed
  positions, and position history). Handle and share it accordingly.
''';
}

/// Provider wiring the export service to the live telemetry database.
final telemetryExportServiceProvider = FutureProvider<TelemetryExportService>((
  ref,
) async {
  final db = await ref.watch(telemetryStorageProvider.future);
  return TelemetryExportService(db);
});
