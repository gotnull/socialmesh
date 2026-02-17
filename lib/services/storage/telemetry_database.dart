// SPDX-License-Identifier: GPL-3.0-or-later

// Telemetry Database — SQLite-backed telemetry history storage.
//
// Replaces the SharedPreferences StringList approach which suffered from:
// - Full read-modify-write of EVERY entry on each new telemetry packet
// - 8 metric types x N nodes x 1000 entries stored as JSON string lists
// - No indexing (linear scan for every query)
// - Growing key namespace pollution in SharedPreferences
//
// This implementation uses a single `telemetry` table with a `type` column
// discriminator, JSON `data` column for metric-specific fields, and proper
// composite indexes for efficient per-node and per-type queries.
//
// Database: telemetry.db
// Schema version: 1
//
// Tables:
//   - telemetry: all metric types in one table, discriminated by `type`

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/logging.dart';
import '../../models/telemetry_log.dart';

/// Schema version for the Telemetry SQLite database.
const int telemetrySchemaVersion = 1;

/// Metric type discriminator values stored in the `type` column.
abstract final class TelemetryType {
  static const deviceMetrics = 'device_metrics';
  static const environmentMetrics = 'environment_metrics';
  static const powerMetrics = 'power_metrics';
  static const airQualityMetrics = 'air_quality_metrics';
  static const positionLog = 'position_log';
  static const traceRouteLog = 'trace_route_log';
  static const paxCounterLog = 'pax_counter_log';
  static const detectionSensorLog = 'detection_sensor_log';
}

/// SQLite-backed telemetry history storage.
///
/// Drop-in replacement for [TelemetryStorageService]. Maintains the same
/// public API so providers and consumers require no logic changes.
class TelemetryDatabase {
  static const _dbName = 'telemetry.db';
  static const _tableName = 'telemetry';
  static const _dbVersion = 1;

  /// Maximum entries retained per node per metric type.
  static const int maxLogEntries = 1000;

  /// SharedPreferences key prefixes matching the old storage service.
  static const _legacyKeyPrefixes = {
    TelemetryType.deviceMetrics: 'device_metrics_log',
    TelemetryType.environmentMetrics: 'environment_metrics_log',
    TelemetryType.powerMetrics: 'power_metrics_log',
    TelemetryType.airQualityMetrics: 'air_quality_metrics_log',
    TelemetryType.positionLog: 'position_log',
    TelemetryType.traceRouteLog: 'trace_route_log',
    TelemetryType.paxCounterLog: 'pax_counter_log',
    TelemetryType.detectionSensorLog: 'detection_sensor_log',
  };

  Database? _db;
  final String? _testDbPath;
  bool _migrationAttempted = false;

  TelemetryDatabase({String? testDbPath}) : _testDbPath = testDbPath;

  /// Initialize the database, creating tables if needed and migrating
  /// any legacy SharedPreferences data on first run.
  Future<void> init() async {
    if (_db != null) return;

    final String dbPath;
    if (_testDbPath != null) {
      dbPath = _testDbPath;
    } else {
      final documentsDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(documentsDir.path, _dbName);
    }

    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        AppLogging.storage('Creating telemetry database v$version');
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        AppLogging.storage(
          'Upgrading telemetry database v$oldVersion -> v$newVersion',
        );
        // Future migrations go here
      },
    );

    // Migrate from SharedPreferences on first run (skip in test mode)
    if (!_migrationAttempted && _testDbPath == null) {
      _migrationAttempted = true;
      await _migrateFromSharedPreferences();
    }
  }

  Database get _database {
    if (_db == null) {
      throw StateError('TelemetryDatabase not initialized — call init() first');
    }
    return _db!;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        node_num INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        data TEXT NOT NULL
      )
    ''');

    // Primary access pattern: per-node, per-type, ordered by time
    await db.execute('''
      CREATE INDEX idx_telemetry_type_node_time
      ON $_tableName (type, node_num, timestamp DESC)
    ''');

    // Aggregate queries: all entries of a type, ordered by time
    await db.execute('''
      CREATE INDEX idx_telemetry_type_time
      ON $_tableName (type, timestamp DESC)
    ''');

    AppLogging.storage('Created telemetry table with indexes');
  }

  // ---------------------------------------------------------------------------
  // Migration from SharedPreferences
  // ---------------------------------------------------------------------------

  static const _migrationFlag = 'telemetry_db_migration_done';

  Future<void> _migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_migrationFlag) == true) return;

      var totalMigrated = 0;

      for (final entry in _legacyKeyPrefixes.entries) {
        final type = entry.key;
        final prefix = entry.value;
        final migratedForType = await _migrateType(prefs, type, prefix);
        totalMigrated += migratedForType;
      }

      await prefs.setBool(_migrationFlag, true);

      if (totalMigrated > 0) {
        AppLogging.storage(
          'Telemetry migration complete: $totalMigrated entries '
          'imported from SharedPreferences to SQLite',
        );
        // Clean up legacy keys
        await _removeLegacyKeys(prefs);
      }
    } catch (e) {
      AppLogging.storage('Telemetry migration failed (non-fatal): $e');
    }
  }

  Future<int> _migrateType(
    SharedPreferences prefs,
    String type,
    String prefix,
  ) async {
    var count = 0;
    final nodeNums = <int>{};

    for (final key in prefs.getKeys()) {
      if (key.startsWith('${prefix}_')) {
        final nodeNum = int.tryParse(key.substring('${prefix}_'.length));
        if (nodeNum != null) {
          nodeNums.add(nodeNum);
        }
      }
    }

    for (final nodeNum in nodeNums) {
      final key = '${prefix}_$nodeNum';
      final jsonList = prefs.getStringList(key);
      if (jsonList == null || jsonList.isEmpty) continue;

      final batch = _database.batch();
      for (final jsonStr in jsonList) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final id = json['id'] as String? ?? '';
          final timestamp = json['timestamp'] as int? ?? 0;

          // Strip id/nodeNum/timestamp from data — they live in columns
          final data = Map<String, dynamic>.from(json)
            ..remove('id')
            ..remove('nodeNum')
            ..remove('timestamp');

          batch.insert(_tableName, {
            'id': id,
            'type': type,
            'node_num': nodeNum,
            'timestamp': timestamp,
            'data': jsonEncode(data),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          count++;
        } catch (e) {
          // Skip malformed entries
          AppLogging.storage(
            'Skipping malformed telemetry entry during migration: $e',
          );
        }
      }
      await batch.commit(noResult: true);
    }

    return count;
  }

  Future<void> _removeLegacyKeys(SharedPreferences prefs) async {
    for (final prefix in _legacyKeyPrefixes.values) {
      final keysToRemove = prefs
          .getKeys()
          .where((key) => key.startsWith('${prefix}_'))
          .toList();
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
    }
    AppLogging.storage('Removed legacy telemetry SharedPreferences keys');
  }

  // ---------------------------------------------------------------------------
  // Generic insert + trim
  // ---------------------------------------------------------------------------

  Future<void> _addEntry(String type, TelemetryLogEntry entry) async {
    final json = entry.toJson();
    // Strip columns that live in dedicated fields
    final data = Map<String, dynamic>.from(json)
      ..remove('id')
      ..remove('nodeNum')
      ..remove('timestamp');

    await _database.insert(_tableName, {
      'id': entry.id,
      'type': type,
      'node_num': entry.nodeNum,
      'timestamp': entry.timestamp.millisecondsSinceEpoch,
      'data': jsonEncode(data),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await _trimEntries(type, entry.nodeNum);
  }

  /// Delete oldest entries beyond [maxLogEntries] for a given type + node.
  Future<void> _trimEntries(String type, int nodeNum) async {
    // Find the timestamp of the maxLogEntries-th newest entry
    final cutoff = await _database.rawQuery(
      '''
      SELECT timestamp FROM $_tableName
      WHERE type = ? AND node_num = ?
      ORDER BY timestamp DESC
      LIMIT 1 OFFSET ?
      ''',
      [type, nodeNum, maxLogEntries],
    );

    if (cutoff.isNotEmpty) {
      final cutoffTs = cutoff.first['timestamp'] as int;
      await _database.delete(
        _tableName,
        where: 'type = ? AND node_num = ? AND timestamp <= ?',
        whereArgs: [type, nodeNum, cutoffTs],
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Generic query helpers
  // ---------------------------------------------------------------------------

  Future<List<T>> _getEntries<T extends TelemetryLogEntry>(
    String type,
    int nodeNum,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    final rows = await _database.query(
      _tableName,
      where: 'type = ? AND node_num = ?',
      whereArgs: [type, nodeNum],
      orderBy: 'timestamp ASC',
    );
    return rows.map((row) => _rowToEntry(row, fromJson)).toList();
  }

  Future<List<T>> _getAllEntries<T extends TelemetryLogEntry>(
    String type,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    final rows = await _database.query(
      _tableName,
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'timestamp DESC',
    );
    return rows.map((row) => _rowToEntry(row, fromJson)).toList();
  }

  T _rowToEntry<T extends TelemetryLogEntry>(
    Map<String, dynamic> row,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
    // Reassemble the full JSON that models expect
    data['id'] = row['id'] as String;
    data['nodeNum'] = row['node_num'] as int;
    data['timestamp'] = row['timestamp'] as int;
    return fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // Device Metrics
  // ---------------------------------------------------------------------------

  Future<void> addDeviceMetrics(DeviceMetricsLog log) async {
    await _addEntry(TelemetryType.deviceMetrics, log);
  }

  Future<List<DeviceMetricsLog>> getDeviceMetrics(int nodeNum) async {
    return _getEntries(
      TelemetryType.deviceMetrics,
      nodeNum,
      DeviceMetricsLog.fromJson,
    );
  }

  Future<List<DeviceMetricsLog>> getAllDeviceMetrics() async {
    return _getAllEntries(
      TelemetryType.deviceMetrics,
      DeviceMetricsLog.fromJson,
    );
  }

  // ---------------------------------------------------------------------------
  // Environment Metrics
  // ---------------------------------------------------------------------------

  Future<void> addEnvironmentMetrics(EnvironmentMetricsLog log) async {
    await _addEntry(TelemetryType.environmentMetrics, log);
  }

  Future<List<EnvironmentMetricsLog>> getEnvironmentMetrics(int nodeNum) async {
    return _getEntries(
      TelemetryType.environmentMetrics,
      nodeNum,
      EnvironmentMetricsLog.fromJson,
    );
  }

  Future<List<EnvironmentMetricsLog>> getAllEnvironmentMetrics() async {
    return _getAllEntries(
      TelemetryType.environmentMetrics,
      EnvironmentMetricsLog.fromJson,
    );
  }

  // ---------------------------------------------------------------------------
  // Power Metrics
  // ---------------------------------------------------------------------------

  Future<void> addPowerMetrics(PowerMetricsLog log) async {
    await _addEntry(TelemetryType.powerMetrics, log);
  }

  Future<List<PowerMetricsLog>> getPowerMetrics(int nodeNum) async {
    return _getEntries(
      TelemetryType.powerMetrics,
      nodeNum,
      PowerMetricsLog.fromJson,
    );
  }

  Future<List<PowerMetricsLog>> getAllPowerMetrics() async {
    return _getAllEntries(TelemetryType.powerMetrics, PowerMetricsLog.fromJson);
  }

  // ---------------------------------------------------------------------------
  // Air Quality Metrics
  // ---------------------------------------------------------------------------

  Future<void> addAirQualityMetrics(AirQualityMetricsLog log) async {
    await _addEntry(TelemetryType.airQualityMetrics, log);
  }

  Future<List<AirQualityMetricsLog>> getAirQualityMetrics(int nodeNum) async {
    return _getEntries(
      TelemetryType.airQualityMetrics,
      nodeNum,
      AirQualityMetricsLog.fromJson,
    );
  }

  Future<List<AirQualityMetricsLog>> getAllAirQualityMetrics() async {
    return _getAllEntries(
      TelemetryType.airQualityMetrics,
      AirQualityMetricsLog.fromJson,
    );
  }

  // ---------------------------------------------------------------------------
  // Position Logs
  // ---------------------------------------------------------------------------

  Future<void> addPositionLog(PositionLog log) async {
    await _addEntry(TelemetryType.positionLog, log);
  }

  Future<List<PositionLog>> getPositionLogs(int nodeNum) async {
    return _getEntries(
      TelemetryType.positionLog,
      nodeNum,
      PositionLog.fromJson,
    );
  }

  Future<List<PositionLog>> getAllPositionLogs() async {
    return _getAllEntries(TelemetryType.positionLog, PositionLog.fromJson);
  }

  // ---------------------------------------------------------------------------
  // Traceroute Logs (legacy — new traceroutes use TracerouteDatabase)
  // ---------------------------------------------------------------------------

  Future<void> addTraceRouteLog(TraceRouteLog log) async {
    await _addEntry(TelemetryType.traceRouteLog, log);
  }

  Future<void> replaceOrAddTraceRouteLog(TraceRouteLog log) async {
    // Find and remove the most recent pending entry for the same target
    final pendingRows = await _database.query(
      _tableName,
      where: 'type = ? AND node_num = ?',
      whereArgs: [TelemetryType.traceRouteLog, log.nodeNum],
      orderBy: 'timestamp DESC',
    );

    for (final row in pendingRows) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      final targetNode = data['targetNode'] as int?;
      final response = data['response'] as bool? ?? false;
      if (targetNode == log.targetNode && !response) {
        await _database.delete(
          _tableName,
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        break;
      }
    }

    await _addEntry(TelemetryType.traceRouteLog, log);
  }

  Future<List<TraceRouteLog>> getTraceRouteLogs(int nodeNum) async {
    return _getEntries(
      TelemetryType.traceRouteLog,
      nodeNum,
      TraceRouteLog.fromJson,
    );
  }

  Future<List<TraceRouteLog>> getAllTraceRouteLogs() async {
    return _getAllEntries(TelemetryType.traceRouteLog, TraceRouteLog.fromJson);
  }

  // ---------------------------------------------------------------------------
  // PAX Counter Logs
  // ---------------------------------------------------------------------------

  Future<void> addPaxCounterLog(PaxCounterLog log) async {
    await _addEntry(TelemetryType.paxCounterLog, log);
  }

  Future<List<PaxCounterLog>> getPaxCounterLogs(int nodeNum) async {
    return _getEntries(
      TelemetryType.paxCounterLog,
      nodeNum,
      PaxCounterLog.fromJson,
    );
  }

  Future<List<PaxCounterLog>> getAllPaxCounterLogs() async {
    return _getAllEntries(TelemetryType.paxCounterLog, PaxCounterLog.fromJson);
  }

  // ---------------------------------------------------------------------------
  // Detection Sensor Logs
  // ---------------------------------------------------------------------------

  Future<void> addDetectionSensorLog(DetectionSensorLog log) async {
    await _addEntry(TelemetryType.detectionSensorLog, log);
  }

  Future<List<DetectionSensorLog>> getDetectionSensorLogs(int nodeNum) async {
    return _getEntries(
      TelemetryType.detectionSensorLog,
      nodeNum,
      DetectionSensorLog.fromJson,
    );
  }

  Future<List<DetectionSensorLog>> getAllDetectionSensorLogs() async {
    return _getAllEntries(
      TelemetryType.detectionSensorLog,
      DetectionSensorLog.fromJson,
    );
  }

  // ---------------------------------------------------------------------------
  // Clear operations
  // ---------------------------------------------------------------------------

  /// Clear all logs for a specific node across all metric types.
  Future<void> clearLogsForNode(int nodeNum) async {
    await _database.delete(
      _tableName,
      where: 'node_num = ?',
      whereArgs: [nodeNum],
    );
  }

  /// Clear all device metrics across all nodes.
  Future<void> clearDeviceMetrics() async {
    await _database.delete(
      _tableName,
      where: 'type = ?',
      whereArgs: [TelemetryType.deviceMetrics],
    );
  }

  /// Clear all environment metrics across all nodes.
  Future<void> clearEnvironmentMetrics() async {
    await _database.delete(
      _tableName,
      where: 'type = ?',
      whereArgs: [TelemetryType.environmentMetrics],
    );
  }

  /// Clear all power metrics across all nodes.
  Future<void> clearPowerMetrics() async {
    await _database.delete(
      _tableName,
      where: 'type = ?',
      whereArgs: [TelemetryType.powerMetrics],
    );
  }

  /// Clear all air quality metrics across all nodes.
  Future<void> clearAirQualityMetrics() async {
    await _database.delete(
      _tableName,
      where: 'type = ?',
      whereArgs: [TelemetryType.airQualityMetrics],
    );
  }

  /// Clear all position logs across all nodes.
  Future<void> clearPositionLogs() async {
    await _database.delete(
      _tableName,
      where: 'type = ?',
      whereArgs: [TelemetryType.positionLog],
    );
  }

  /// Clear traceroute logs for a specific node.
  Future<void> clearTraceRouteLogsForNode(int nodeNum) async {
    await _database.delete(
      _tableName,
      where: 'type = ? AND node_num = ?',
      whereArgs: [TelemetryType.traceRouteLog, nodeNum],
    );
  }

  /// Clear all traceroute logs across all nodes.
  Future<void> clearTraceRouteLogs() async {
    await _database.delete(
      _tableName,
      where: 'type = ?',
      whereArgs: [TelemetryType.traceRouteLog],
    );
  }

  /// Clear all telemetry data across all nodes and types.
  Future<void> clearAllData() async {
    await _database.delete(_tableName);
  }

  // ---------------------------------------------------------------------------
  // CSV Export
  // ---------------------------------------------------------------------------

  Future<String> exportDeviceMetricsCsv(int nodeNum) async {
    final logs = await getDeviceMetrics(nodeNum);
    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,batteryLevel,voltage,channelUtilization,airUtilTx,'
      'uptimeSeconds',
    );
    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.batteryLevel ?? ''},'
        '${log.voltage ?? ''},${log.channelUtilization ?? ''},'
        '${log.airUtilTx ?? ''},${log.uptimeSeconds ?? ''}',
      );
    }
    return buffer.toString();
  }

  Future<String> exportEnvironmentMetricsCsv(int nodeNum) async {
    final logs = await getEnvironmentMetrics(nodeNum);
    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,temperature,relativeHumidity,barometricPressure,'
      'gasResistance,iaq,lux,uvLux,whiteLux,windDirection,windSpeed,'
      'windGust,rainfall,soilMoisture,soilTemperature',
    );
    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.temperature ?? ''},'
        '${log.relativeHumidity ?? ''},${log.barometricPressure ?? ''},'
        '${log.gasResistance ?? ''},${log.iaq ?? ''},${log.lux ?? ''},'
        '${log.uvLux ?? ''},${log.whiteLux ?? ''},'
        '${log.windDirection ?? ''},${log.windSpeed ?? ''},'
        '${log.windGust ?? ''},${log.rainfall ?? ''},'
        '${log.soilMoisture ?? ''},${log.soilTemperature ?? ''}',
      );
    }
    return buffer.toString();
  }

  Future<String> exportPositionLogsCsv(int nodeNum) async {
    final logs = await getPositionLogs(nodeNum);
    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,latitude,longitude,altitude,heading,speed,satsInView',
    );
    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.latitude},'
        '${log.longitude},${log.altitude ?? ''},${log.heading ?? ''},'
        '${log.speed ?? ''},${log.satsInView ?? ''}',
      );
    }
    return buffer.toString();
  }

  /// Close the database.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
