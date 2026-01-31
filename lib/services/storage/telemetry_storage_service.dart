// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/telemetry_log.dart';

/// Storage service for telemetry history logs
class TelemetryStorageService {
  static const _deviceMetricsKey = 'device_metrics_log';
  static const _environmentMetricsKey = 'environment_metrics_log';
  static const _powerMetricsKey = 'power_metrics_log';
  static const _airQualityMetricsKey = 'air_quality_metrics_log';
  static const _positionLogKey = 'position_log';
  static const _traceRouteLogKey = 'trace_route_log';
  static const _paxCounterLogKey = 'pax_counter_log';
  static const _detectionSensorLogKey = 'detection_sensor_log';

  static const _maxLogEntries = 1000;

  final SharedPreferences _prefs;

  TelemetryStorageService(this._prefs);

  // Device Metrics
  Future<void> addDeviceMetrics(DeviceMetricsLog log) async {
    final logs = await getDeviceMetrics(log.nodeNum);
    logs.add(log);
    if (logs.length > _maxLogEntries) {
      logs.removeRange(0, logs.length - _maxLogEntries);
    }
    await _saveDeviceMetrics(log.nodeNum, logs);
  }

  Future<List<DeviceMetricsLog>> getDeviceMetrics(int nodeNum) async {
    final key = '${_deviceMetricsKey}_$nodeNum';
    final jsonList = _prefs.getStringList(key) ?? [];
    return jsonList
        .map((json) => DeviceMetricsLog.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> _saveDeviceMetrics(
    int nodeNum,
    List<DeviceMetricsLog> logs,
  ) async {
    final key = '${_deviceMetricsKey}_$nodeNum';
    await _prefs.setStringList(
      key,
      logs.map((l) => jsonEncode(l.toJson())).toList(),
    );
  }

  // Environment Metrics
  Future<void> addEnvironmentMetrics(EnvironmentMetricsLog log) async {
    final logs = await getEnvironmentMetrics(log.nodeNum);
    logs.add(log);
    if (logs.length > _maxLogEntries) {
      logs.removeRange(0, logs.length - _maxLogEntries);
    }
    await _saveEnvironmentMetrics(log.nodeNum, logs);
  }

  Future<List<EnvironmentMetricsLog>> getEnvironmentMetrics(int nodeNum) async {
    final key = '${_environmentMetricsKey}_$nodeNum';
    final jsonList = _prefs.getStringList(key) ?? [];
    return jsonList
        .map((json) => EnvironmentMetricsLog.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> _saveEnvironmentMetrics(
    int nodeNum,
    List<EnvironmentMetricsLog> logs,
  ) async {
    final key = '${_environmentMetricsKey}_$nodeNum';
    await _prefs.setStringList(
      key,
      logs.map((l) => jsonEncode(l.toJson())).toList(),
    );
  }

  // Power Metrics
  Future<void> addPowerMetrics(PowerMetricsLog log) async {
    final logs = await getPowerMetrics(log.nodeNum);
    logs.add(log);
    if (logs.length > _maxLogEntries) {
      logs.removeRange(0, logs.length - _maxLogEntries);
    }
    await _savePowerMetrics(log.nodeNum, logs);
  }

  Future<List<PowerMetricsLog>> getPowerMetrics(int nodeNum) async {
    final key = '${_powerMetricsKey}_$nodeNum';
    final jsonList = _prefs.getStringList(key) ?? [];
    return jsonList
        .map((json) => PowerMetricsLog.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> _savePowerMetrics(
    int nodeNum,
    List<PowerMetricsLog> logs,
  ) async {
    final key = '${_powerMetricsKey}_$nodeNum';
    await _prefs.setStringList(
      key,
      logs.map((l) => jsonEncode(l.toJson())).toList(),
    );
  }

  // Air Quality Metrics
  Future<void> addAirQualityMetrics(AirQualityMetricsLog log) async {
    final logs = await getAirQualityMetrics(log.nodeNum);
    logs.add(log);
    if (logs.length > _maxLogEntries) {
      logs.removeRange(0, logs.length - _maxLogEntries);
    }
    await _saveAirQualityMetrics(log.nodeNum, logs);
  }

  Future<List<AirQualityMetricsLog>> getAirQualityMetrics(int nodeNum) async {
    final key = '${_airQualityMetricsKey}_$nodeNum';
    final jsonList = _prefs.getStringList(key) ?? [];
    return jsonList
        .map((json) => AirQualityMetricsLog.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> _saveAirQualityMetrics(
    int nodeNum,
    List<AirQualityMetricsLog> logs,
  ) async {
    final key = '${_airQualityMetricsKey}_$nodeNum';
    await _prefs.setStringList(
      key,
      logs.map((l) => jsonEncode(l.toJson())).toList(),
    );
  }

  // Position Log
  Future<void> addPositionLog(PositionLog log) async {
    final logs = await getPositionLogs(log.nodeNum);
    logs.add(log);
    if (logs.length > _maxLogEntries) {
      logs.removeRange(0, logs.length - _maxLogEntries);
    }
    await _savePositionLogs(log.nodeNum, logs);
  }

  Future<List<PositionLog>> getPositionLogs(int nodeNum) async {
    final key = '${_positionLogKey}_$nodeNum';
    final jsonList = _prefs.getStringList(key) ?? [];
    return jsonList
        .map((json) => PositionLog.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> _savePositionLogs(int nodeNum, List<PositionLog> logs) async {
    final key = '${_positionLogKey}_$nodeNum';
    await _prefs.setStringList(
      key,
      logs.map((l) => jsonEncode(l.toJson())).toList(),
    );
  }

  // TraceRoute Log
  Future<void> addTraceRouteLog(TraceRouteLog log) async {
    final logs = await getTraceRouteLogs(log.nodeNum);
    logs.add(log);
    if (logs.length > _maxLogEntries) {
      logs.removeRange(0, logs.length - _maxLogEntries);
    }
    await _saveTraceRouteLogs(log.nodeNum, logs);
  }

  Future<List<TraceRouteLog>> getTraceRouteLogs(int nodeNum) async {
    final key = '${_traceRouteLogKey}_$nodeNum';
    final jsonList = _prefs.getStringList(key) ?? [];
    return jsonList
        .map((json) => TraceRouteLog.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> _saveTraceRouteLogs(
    int nodeNum,
    List<TraceRouteLog> logs,
  ) async {
    final key = '${_traceRouteLogKey}_$nodeNum';
    await _prefs.setStringList(
      key,
      logs.map((l) => jsonEncode(l.toJson())).toList(),
    );
  }

  // PAX Counter Log
  Future<void> addPaxCounterLog(PaxCounterLog log) async {
    final logs = await getPaxCounterLogs(log.nodeNum);
    logs.add(log);
    if (logs.length > _maxLogEntries) {
      logs.removeRange(0, logs.length - _maxLogEntries);
    }
    await _savePaxCounterLogs(log.nodeNum, logs);
  }

  Future<List<PaxCounterLog>> getPaxCounterLogs(int nodeNum) async {
    final key = '${_paxCounterLogKey}_$nodeNum';
    final jsonList = _prefs.getStringList(key) ?? [];
    return jsonList
        .map((json) => PaxCounterLog.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> _savePaxCounterLogs(
    int nodeNum,
    List<PaxCounterLog> logs,
  ) async {
    final key = '${_paxCounterLogKey}_$nodeNum';
    await _prefs.setStringList(
      key,
      logs.map((l) => jsonEncode(l.toJson())).toList(),
    );
  }

  // Detection Sensor Log
  Future<void> addDetectionSensorLog(DetectionSensorLog log) async {
    final logs = await getDetectionSensorLogs(log.nodeNum);
    logs.add(log);
    if (logs.length > _maxLogEntries) {
      logs.removeRange(0, logs.length - _maxLogEntries);
    }
    await _saveDetectionSensorLogs(log.nodeNum, logs);
  }

  Future<List<DetectionSensorLog>> getDetectionSensorLogs(int nodeNum) async {
    final key = '${_detectionSensorLogKey}_$nodeNum';
    final jsonList = _prefs.getStringList(key) ?? [];
    return jsonList
        .map((json) => DetectionSensorLog.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> _saveDetectionSensorLogs(
    int nodeNum,
    List<DetectionSensorLog> logs,
  ) async {
    final key = '${_detectionSensorLogKey}_$nodeNum';
    await _prefs.setStringList(
      key,
      logs.map((l) => jsonEncode(l.toJson())).toList(),
    );
  }

  // Clear all logs for a node
  Future<void> clearLogsForNode(int nodeNum) async {
    await _prefs.remove('${_deviceMetricsKey}_$nodeNum');
    await _prefs.remove('${_environmentMetricsKey}_$nodeNum');
    await _prefs.remove('${_powerMetricsKey}_$nodeNum');
    await _prefs.remove('${_airQualityMetricsKey}_$nodeNum');
    await _prefs.remove('${_positionLogKey}_$nodeNum');
    await _prefs.remove('${_traceRouteLogKey}_$nodeNum');
    await _prefs.remove('${_paxCounterLogKey}_$nodeNum');
    await _prefs.remove('${_detectionSensorLogKey}_$nodeNum');
  }

  // Clear device metrics for all nodes
  Future<void> clearDeviceMetrics() async {
    for (final nodeNum in _getNodeNumbersForKey(_deviceMetricsKey)) {
      await _prefs.remove('${_deviceMetricsKey}_$nodeNum');
    }
  }

  // Clear environment metrics for all nodes
  Future<void> clearEnvironmentMetrics() async {
    for (final nodeNum in _getNodeNumbersForKey(_environmentMetricsKey)) {
      await _prefs.remove('${_environmentMetricsKey}_$nodeNum');
    }
  }

  // Clear power metrics for all nodes
  Future<void> clearPowerMetrics() async {
    for (final nodeNum in _getNodeNumbersForKey(_powerMetricsKey)) {
      await _prefs.remove('${_powerMetricsKey}_$nodeNum');
    }
  }

  // Clear air quality metrics for all nodes
  Future<void> clearAirQualityMetrics() async {
    for (final nodeNum in _getNodeNumbersForKey(_airQualityMetricsKey)) {
      await _prefs.remove('${_airQualityMetricsKey}_$nodeNum');
    }
  }

  // Clear position logs for all nodes
  Future<void> clearPositionLogs() async {
    for (final nodeNum in _getNodeNumbersForKey(_positionLogKey)) {
      await _prefs.remove('${_positionLogKey}_$nodeNum');
    }
  }

  // Clear traceroute logs for all nodes
  Future<void> clearTraceRouteLogs() async {
    for (final nodeNum in _getNodeNumbersForKey(_traceRouteLogKey)) {
      await _prefs.remove('${_traceRouteLogKey}_$nodeNum');
    }
  }

  // Clear all telemetry data
  Future<void> clearAllData() async {
    await clearDeviceMetrics();
    await clearEnvironmentMetrics();
    await clearPowerMetrics();
    await clearAirQualityMetrics();
    await clearPositionLogs();
    await clearTraceRouteLogs();
    // Also clear pax counter and detection sensor logs
    for (final nodeNum in _getNodeNumbersForKey(_paxCounterLogKey)) {
      await _prefs.remove('${_paxCounterLogKey}_$nodeNum');
    }
    for (final nodeNum in _getNodeNumbersForKey(_detectionSensorLogKey)) {
      await _prefs.remove('${_detectionSensorLogKey}_$nodeNum');
    }
  }

  // Get all node numbers that have telemetry data
  Set<int> _getNodeNumbersForKey(String keyPrefix) {
    final nodeNums = <int>{};
    for (final key in _prefs.getKeys()) {
      if (key.startsWith('${keyPrefix}_')) {
        final nodeNum = int.tryParse(key.substring('${keyPrefix}_'.length));
        if (nodeNum != null) {
          nodeNums.add(nodeNum);
        }
      }
    }
    return nodeNums;
  }

  // Get All methods for aggregate views
  Future<List<DeviceMetricsLog>> getAllDeviceMetrics() async {
    final allLogs = <DeviceMetricsLog>[];
    for (final nodeNum in _getNodeNumbersForKey(_deviceMetricsKey)) {
      final logs = await getDeviceMetrics(nodeNum);
      allLogs.addAll(logs);
    }
    allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allLogs;
  }

  Future<List<EnvironmentMetricsLog>> getAllEnvironmentMetrics() async {
    final allLogs = <EnvironmentMetricsLog>[];
    for (final nodeNum in _getNodeNumbersForKey(_environmentMetricsKey)) {
      final logs = await getEnvironmentMetrics(nodeNum);
      allLogs.addAll(logs);
    }
    allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allLogs;
  }

  Future<List<PowerMetricsLog>> getAllPowerMetrics() async {
    final allLogs = <PowerMetricsLog>[];
    for (final nodeNum in _getNodeNumbersForKey(_powerMetricsKey)) {
      final logs = await getPowerMetrics(nodeNum);
      allLogs.addAll(logs);
    }
    allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allLogs;
  }

  Future<List<AirQualityMetricsLog>> getAllAirQualityMetrics() async {
    final allLogs = <AirQualityMetricsLog>[];
    for (final nodeNum in _getNodeNumbersForKey(_airQualityMetricsKey)) {
      final logs = await getAirQualityMetrics(nodeNum);
      allLogs.addAll(logs);
    }
    allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allLogs;
  }

  Future<List<PositionLog>> getAllPositionLogs() async {
    final allLogs = <PositionLog>[];
    for (final nodeNum in _getNodeNumbersForKey(_positionLogKey)) {
      final logs = await getPositionLogs(nodeNum);
      allLogs.addAll(logs);
    }
    allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allLogs;
  }

  Future<List<TraceRouteLog>> getAllTraceRouteLogs() async {
    final allLogs = <TraceRouteLog>[];
    for (final nodeNum in _getNodeNumbersForKey(_traceRouteLogKey)) {
      final logs = await getTraceRouteLogs(nodeNum);
      allLogs.addAll(logs);
    }
    allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allLogs;
  }

  Future<List<PaxCounterLog>> getAllPaxCounterLogs() async {
    final allLogs = <PaxCounterLog>[];
    for (final nodeNum in _getNodeNumbersForKey(_paxCounterLogKey)) {
      final logs = await getPaxCounterLogs(nodeNum);
      allLogs.addAll(logs);
    }
    allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allLogs;
  }

  Future<List<DetectionSensorLog>> getAllDetectionSensorLogs() async {
    final allLogs = <DetectionSensorLog>[];
    for (final nodeNum in _getNodeNumbersForKey(_detectionSensorLogKey)) {
      final logs = await getDetectionSensorLogs(nodeNum);
      allLogs.addAll(logs);
    }
    allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allLogs;
  }

  // Export all telemetry as CSV
  Future<String> exportDeviceMetricsCsv(int nodeNum) async {
    final logs = await getDeviceMetrics(nodeNum);
    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,batteryLevel,voltage,channelUtilization,airUtilTx,uptimeSeconds',
    );
    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.batteryLevel ?? ''},${log.voltage ?? ''},${log.channelUtilization ?? ''},${log.airUtilTx ?? ''},${log.uptimeSeconds ?? ''}',
      );
    }
    return buffer.toString();
  }

  Future<String> exportEnvironmentMetricsCsv(int nodeNum) async {
    final logs = await getEnvironmentMetrics(nodeNum);
    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,temperature,relativeHumidity,barometricPressure,gasResistance,iaq,lux,uvLux,whiteLux,windDirection,windSpeed,windGust,rainfall,soilMoisture,soilTemperature',
    );
    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.temperature ?? ''},${log.relativeHumidity ?? ''},${log.barometricPressure ?? ''},${log.gasResistance ?? ''},${log.iaq ?? ''},${log.lux ?? ''},${log.uvLux ?? ''},${log.whiteLux ?? ''},${log.windDirection ?? ''},${log.windSpeed ?? ''},${log.windGust ?? ''},${log.rainfall ?? ''},${log.soilMoisture ?? ''},${log.soilTemperature ?? ''}',
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
        '${log.timestamp.toIso8601String()},${log.latitude},${log.longitude},${log.altitude ?? ''},${log.heading ?? ''},${log.speed ?? ''},${log.satsInView ?? ''}',
      );
    }
    return buffer.toString();
  }
}
