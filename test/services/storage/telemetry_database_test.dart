// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/telemetry_log.dart';
import 'package:socialmesh/services/storage/telemetry_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late TelemetryDatabase db;

  setUp(() async {
    db = TelemetryDatabase(testDbPath: inMemoryDatabasePath);
    await db.init();
  });

  tearDown(() async {
    await db.close();
  });

  group('TelemetryDatabase — DeviceMetrics', () {
    test('getDeviceMetrics returns empty list initially', () async {
      final metrics = await db.getDeviceMetrics(12345);
      expect(metrics, isEmpty);
    });

    test('addDeviceMetrics saves and retrieves metrics', () async {
      final log = DeviceMetricsLog(
        nodeNum: 12345,
        batteryLevel: 85,
        voltage: 4.1,
        channelUtilization: 15.5,
        uptimeSeconds: 3600,
      );

      await db.addDeviceMetrics(log);
      final metrics = await db.getDeviceMetrics(12345);

      expect(metrics.length, 1);
      expect(metrics.first.batteryLevel, 85);
      expect(metrics.first.voltage, 4.1);
      expect(metrics.first.channelUtilization, 15.5);
      expect(metrics.first.uptimeSeconds, 3600);
    });

    test('addDeviceMetrics stores multiple entries', () async {
      await db.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 12345, batteryLevel: 85),
      );
      await db.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 12345, batteryLevel: 80),
      );
      await db.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 12345, batteryLevel: 75),
      );

      final metrics = await db.getDeviceMetrics(12345);
      expect(metrics.length, 3);
    });

    test('metrics are isolated by nodeNum', () async {
      await db.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 111, batteryLevel: 80),
      );
      await db.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 222, batteryLevel: 60),
      );

      final metrics111 = await db.getDeviceMetrics(111);
      final metrics222 = await db.getDeviceMetrics(222);

      expect(metrics111.length, 1);
      expect(metrics111.first.batteryLevel, 80);
      expect(metrics222.length, 1);
      expect(metrics222.first.batteryLevel, 60);
    });

    test('getAllDeviceMetrics returns entries across nodes', () async {
      await db.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 111, batteryLevel: 80),
      );
      await db.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 222, batteryLevel: 60),
      );

      final all = await db.getAllDeviceMetrics();
      expect(all.length, 2);
    });

    test('clearDeviceMetrics removes all device metrics', () async {
      await db.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 111, batteryLevel: 80),
      );
      await db.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 222, batteryLevel: 60),
      );

      await db.clearDeviceMetrics();

      final all = await db.getAllDeviceMetrics();
      expect(all, isEmpty);
    });
  });

  group('TelemetryDatabase — EnvironmentMetrics', () {
    test('stores and retrieves environment metrics', () async {
      await db.addEnvironmentMetrics(
        EnvironmentMetricsLog(
          nodeNum: 12345,
          temperature: 22.5,
          humidity: 45.0,
          barometricPressure: 1013.25,
        ),
      );

      final metrics = await db.getEnvironmentMetrics(12345);
      expect(metrics.length, 1);
      expect(metrics.first.temperature, 22.5);
      expect(metrics.first.humidity, 45.0);
      expect(metrics.first.barometricPressure, 1013.25);
    });

    test('clearEnvironmentMetrics removes all entries', () async {
      await db.addEnvironmentMetrics(
        EnvironmentMetricsLog(nodeNum: 111, temperature: 22.5),
      );
      await db.clearEnvironmentMetrics();

      final all = await db.getAllEnvironmentMetrics();
      expect(all, isEmpty);
    });
  });

  group('TelemetryDatabase — PowerMetrics', () {
    test('stores and retrieves power metrics', () async {
      await db.addPowerMetrics(
        PowerMetricsLog(
          nodeNum: 12345,
          ch1Voltage: 3.3,
          ch1Current: 0.5,
          ch2Voltage: 5.0,
        ),
      );

      final metrics = await db.getPowerMetrics(12345);
      expect(metrics.length, 1);
      expect(metrics.first.ch1Voltage, 3.3);
      expect(metrics.first.ch1Current, 0.5);
      expect(metrics.first.ch2Voltage, 5.0);
    });
  });

  group('TelemetryDatabase — AirQualityMetrics', () {
    test('stores and retrieves air quality metrics', () async {
      await db.addAirQualityMetrics(
        AirQualityMetricsLog(nodeNum: 12345, pm25Standard: 12, co2: 400),
      );

      final metrics = await db.getAirQualityMetrics(12345);
      expect(metrics.length, 1);
      expect(metrics.first.pm25Standard, 12);
      expect(metrics.first.co2, 400);
    });
  });

  group('TelemetryDatabase — PositionLog', () {
    test('stores and retrieves position logs', () async {
      await db.addPositionLog(
        PositionLog(
          nodeNum: 12345,
          latitude: -37.8136,
          longitude: 144.9631,
          altitude: 31,
          satsInView: 8,
        ),
      );

      final logs = await db.getPositionLogs(12345);
      expect(logs.length, 1);
      expect(logs.first.latitude, -37.8136);
      expect(logs.first.longitude, 144.9631);
      expect(logs.first.altitude, 31);
      expect(logs.first.satsInView, 8);
    });
  });

  group('TelemetryDatabase — PaxCounter', () {
    test('stores and retrieves pax counter logs', () async {
      await db.addPaxCounterLog(
        PaxCounterLog(nodeNum: 12345, wifi: 10, ble: 5, uptime: 3600),
      );

      final logs = await db.getPaxCounterLogs(12345);
      expect(logs.length, 1);
      expect(logs.first.wifi, 10);
      expect(logs.first.ble, 5);
      expect(logs.first.total, 15);
    });
  });

  group('TelemetryDatabase — DetectionSensor', () {
    test('stores and retrieves detection sensor logs', () async {
      await db.addDetectionSensorLog(
        DetectionSensorLog(
          nodeNum: 12345,
          name: 'motion',
          detected: true,
          eventType: 'pir',
        ),
      );

      final logs = await db.getDetectionSensorLogs(12345);
      expect(logs.length, 1);
      expect(logs.first.name, 'motion');
      expect(logs.first.detected, true);
      expect(logs.first.eventType, 'pir');
    });
  });

  group('TelemetryDatabase — Traceroute', () {
    test('stores traceroute with hops', () async {
      await db.addTraceRouteLog(
        TraceRouteLog(
          nodeNum: 0xAABBCCDD,
          targetNode: 0xAABBCCDD,
          sent: true,
          response: true,
          hopsTowards: 2,
          hopsBack: 1,
          hops: [
            TraceRouteHop(nodeNum: 0x11111111, snr: 10.0),
            TraceRouteHop(nodeNum: 0x22222222, snr: -2.0),
            TraceRouteHop(nodeNum: 0x33333333, snr: 6.0, back: true),
          ],
          snr: 7.5,
        ),
      );

      final logs = await db.getTraceRouteLogs(0xAABBCCDD);
      expect(logs.length, 1);
      expect(logs.first.targetNode, 0xAABBCCDD);
      expect(logs.first.response, true);
      expect(logs.first.hops.length, 3);
    });

    test('replaceOrAddTraceRouteLog replaces pending entry', () async {
      await db.addTraceRouteLog(
        TraceRouteLog(
          nodeNum: 0xAABBCCDD,
          targetNode: 0xAABBCCDD,
          sent: true,
          response: false,
        ),
      );

      await db.replaceOrAddTraceRouteLog(
        TraceRouteLog(
          nodeNum: 0xAABBCCDD,
          targetNode: 0xAABBCCDD,
          sent: true,
          response: true,
          hopsTowards: 1,
          hops: [TraceRouteHop(nodeNum: 0x11111111, snr: 5.0)],
        ),
      );

      final logs = await db.getTraceRouteLogs(0xAABBCCDD);
      expect(logs.length, 1);
      expect(logs.first.response, true);
    });
  });

  group('TelemetryDatabase — clearLogsForNode', () {
    test('clears all metric types for a node', () async {
      await db.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 12345, batteryLevel: 85),
      );
      await db.addEnvironmentMetrics(
        EnvironmentMetricsLog(nodeNum: 12345, temperature: 22.5),
      );
      await db.addPositionLog(
        PositionLog(nodeNum: 12345, latitude: 0, longitude: 0),
      );

      // Different node should be preserved
      await db.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 99999, batteryLevel: 50),
      );

      await db.clearLogsForNode(12345);

      expect(await db.getDeviceMetrics(12345), isEmpty);
      expect(await db.getEnvironmentMetrics(12345), isEmpty);
      expect(await db.getPositionLogs(12345), isEmpty);

      // Other node should be unaffected
      expect((await db.getDeviceMetrics(99999)).length, 1);
    });
  });

  group('TelemetryDatabase — clearAllData', () {
    test('clears everything', () async {
      await db.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 111, batteryLevel: 85),
      );
      await db.addEnvironmentMetrics(
        EnvironmentMetricsLog(nodeNum: 222, temperature: 22.5),
      );
      await db.addPowerMetrics(PowerMetricsLog(nodeNum: 333, ch1Voltage: 3.3));

      await db.clearAllData();

      expect(await db.getAllDeviceMetrics(), isEmpty);
      expect(await db.getAllEnvironmentMetrics(), isEmpty);
      expect(await db.getAllPowerMetrics(), isEmpty);
    });
  });

  group('TelemetryDatabase — trimming', () {
    test('trims entries beyond maxLogEntries per node per type', () async {
      // Insert more than maxLogEntries
      for (var i = 0; i < TelemetryDatabase.maxLogEntries + 50; i++) {
        await db.addDeviceMetrics(
          DeviceMetricsLog(
            nodeNum: 12345,
            batteryLevel: i % 100,
            timestamp: DateTime.fromMillisecondsSinceEpoch(i * 1000),
          ),
        );
      }

      final metrics = await db.getDeviceMetrics(12345);
      expect(
        metrics.length,
        lessThanOrEqualTo(TelemetryDatabase.maxLogEntries),
      );
    });
  });

  group('TelemetryDatabase — CSV export', () {
    test('exportDeviceMetricsCsv generates valid CSV', () async {
      await db.addDeviceMetrics(
        DeviceMetricsLog(
          nodeNum: 12345,
          batteryLevel: 85,
          voltage: 4.1,
          channelUtilization: 15.5,
          airUtilTx: 2.3,
          uptimeSeconds: 3600,
        ),
      );

      final csv = await db.exportDeviceMetricsCsv(12345);
      expect(csv, contains('batteryLevel'));
      expect(csv, contains('85'));
      expect(csv, contains('4.1'));
    });

    test('exportEnvironmentMetricsCsv generates valid CSV', () async {
      await db.addEnvironmentMetrics(
        EnvironmentMetricsLog(
          nodeNum: 12345,
          temperature: 22.5,
          humidity: 45.0,
        ),
      );

      final csv = await db.exportEnvironmentMetricsCsv(12345);
      expect(csv, contains('temperature'));
      expect(csv, contains('22.5'));
    });

    test('exportPositionLogsCsv generates valid CSV', () async {
      await db.addPositionLog(
        PositionLog(
          nodeNum: 12345,
          latitude: -37.8136,
          longitude: 144.9631,
          altitude: 31,
        ),
      );

      final csv = await db.exportPositionLogsCsv(12345);
      expect(csv, contains('latitude'));
      expect(csv, contains('-37.8136'));
      expect(csv, contains('144.9631'));
    });
  });

  group('TelemetryDatabase — NaN/Infinity handling', () {
    test('NaN voltage is stored as null and retrieved cleanly', () async {
      await db.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 12345, voltage: double.nan, batteryLevel: 50),
      );

      final metrics = await db.getDeviceMetrics(12345);
      expect(metrics.length, 1);
      expect(metrics.first.voltage, isNull);
      expect(metrics.first.batteryLevel, 50);
    });
  });
}
