import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/models/telemetry_log.dart';
import 'package:socialmesh/services/storage/telemetry_storage_service.dart';

void main() {
  late SharedPreferences prefs;
  late TelemetryStorageService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = TelemetryStorageService(prefs);
  });

  group('TelemetryStorageService - DeviceMetrics', () {
    test('getDeviceMetrics returns empty list initially', () async {
      final metrics = await service.getDeviceMetrics(12345);
      expect(metrics, isEmpty);
    });

    test('addDeviceMetrics saves metrics', () async {
      final log = DeviceMetricsLog(
        nodeNum: 12345,
        batteryLevel: 85,
        voltage: 4.1,
        channelUtilization: 15.5,
        uptimeSeconds: 3600,
      );

      await service.addDeviceMetrics(log);
      final metrics = await service.getDeviceMetrics(12345);

      expect(metrics.length, 1);
      expect(metrics.first.batteryLevel, 85);
      expect(metrics.first.voltage, 4.1);
    });

    test('addDeviceMetrics stores multiple entries', () async {
      await service.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 12345, batteryLevel: 85),
      );
      await service.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 12345, batteryLevel: 80),
      );
      await service.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 12345, batteryLevel: 75),
      );

      final metrics = await service.getDeviceMetrics(12345);
      expect(metrics.length, 3);
    });

    test('metrics are isolated by nodeNum', () async {
      await service.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 111, batteryLevel: 80),
      );
      await service.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 222, batteryLevel: 60),
      );

      final metrics1 = await service.getDeviceMetrics(111);
      final metrics2 = await service.getDeviceMetrics(222);

      expect(metrics1.length, 1);
      expect(metrics1.first.batteryLevel, 80);
      expect(metrics2.length, 1);
      expect(metrics2.first.batteryLevel, 60);
    });
  });

  group('TelemetryStorageService - EnvironmentMetrics', () {
    test('getEnvironmentMetrics returns empty list initially', () async {
      final metrics = await service.getEnvironmentMetrics(12345);
      expect(metrics, isEmpty);
    });

    test('addEnvironmentMetrics saves metrics', () async {
      final log = EnvironmentMetricsLog(
        nodeNum: 12345,
        temperature: 22.5,
        humidity: 45.0,
        barometricPressure: 1013.25,
      );

      await service.addEnvironmentMetrics(log);
      final metrics = await service.getEnvironmentMetrics(12345);

      expect(metrics.length, 1);
      expect(metrics.first.temperature, 22.5);
      expect(metrics.first.humidity, 45.0);
    });
  });

  group('TelemetryStorageService - PowerMetrics', () {
    test('getPowerMetrics returns empty list initially', () async {
      final metrics = await service.getPowerMetrics(12345);
      expect(metrics, isEmpty);
    });

    test('addPowerMetrics saves metrics', () async {
      final log = PowerMetricsLog(
        nodeNum: 12345,
        ch1Voltage: 12.5,
        ch1Current: 0.5,
        ch2Voltage: 5.0,
        ch2Current: 0.2,
      );

      await service.addPowerMetrics(log);
      final metrics = await service.getPowerMetrics(12345);

      expect(metrics.length, 1);
      expect(metrics.first.ch1Voltage, 12.5);
    });
  });

  group('TelemetryStorageService - AirQualityMetrics', () {
    test('getAirQualityMetrics returns empty list initially', () async {
      final metrics = await service.getAirQualityMetrics(12345);
      expect(metrics, isEmpty);
    });

    test('addAirQualityMetrics saves metrics', () async {
      final log = AirQualityMetricsLog(
        nodeNum: 12345,
        pm25Standard: 12,
        pm100Standard: 25,
        co2: 400,
      );

      await service.addAirQualityMetrics(log);
      final metrics = await service.getAirQualityMetrics(12345);

      expect(metrics.length, 1);
      expect(metrics.first.pm25Standard, 12);
      expect(metrics.first.co2, 400);
    });
  });

  group('TelemetryStorageService - PositionLog', () {
    test('getPositionLogs returns empty list initially', () async {
      final logs = await service.getPositionLogs(12345);
      expect(logs, isEmpty);
    });

    test('addPositionLog saves position', () async {
      final log = PositionLog(
        nodeNum: 12345,
        latitude: 37.7749,
        longitude: -122.4194,
        altitude: 10,
        satsInView: 8,
      );

      await service.addPositionLog(log);
      final logs = await service.getPositionLogs(12345);

      expect(logs.length, 1);
      expect(logs.first.latitude, 37.7749);
      expect(logs.first.longitude, -122.4194);
    });
  });

  group('TelemetryStorageService - TraceRouteLog', () {
    test('getTraceRouteLogs returns empty list initially', () async {
      final logs = await service.getTraceRouteLogs(12345);
      expect(logs, isEmpty);
    });

    test('addTraceRouteLog saves route', () async {
      final log = TraceRouteLog(
        nodeNum: 12345,
        targetNode: 67890,
        sent: true,
        response: true,
        hopsTowards: 2,
        hopsBack: 3,
      );

      await service.addTraceRouteLog(log);
      final logs = await service.getTraceRouteLogs(12345);

      expect(logs.length, 1);
      expect(logs.first.targetNode, 67890);
      expect(logs.first.hopsTowards, 2);
    });
  });

  group('TelemetryStorageService - PaxCounterLog', () {
    test('getPaxCounterLogs returns empty list initially', () async {
      final logs = await service.getPaxCounterLogs(12345);
      expect(logs, isEmpty);
    });

    test('addPaxCounterLog saves count', () async {
      final log = PaxCounterLog(
        nodeNum: 12345,
        wifi: 25,
        ble: 15,
        uptime: 3600,
      );

      await service.addPaxCounterLog(log);
      final logs = await service.getPaxCounterLogs(12345);

      expect(logs.length, 1);
      expect(logs.first.wifi, 25);
      expect(logs.first.ble, 15);
    });
  });

  group('TelemetryStorageService - DetectionSensorLog', () {
    test('getDetectionSensorLogs returns empty list initially', () async {
      final logs = await service.getDetectionSensorLogs(12345);
      expect(logs, isEmpty);
    });

    test('addDetectionSensorLog saves detection', () async {
      final log = DetectionSensorLog(
        nodeNum: 12345,
        detected: true,
        name: 'Motion Sensor',
        eventType: 'motion',
      );

      await service.addDetectionSensorLog(log);
      final logs = await service.getDetectionSensorLogs(12345);

      expect(logs.length, 1);
      expect(logs.first.detected, true);
      expect(logs.first.name, 'Motion Sensor');
    });
  });

  group('TelemetryStorageService - Clear operations', () {
    test('clearLogsForNode clears all logs for a node', () async {
      await service.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 12345, batteryLevel: 80),
      );
      await service.addPositionLog(
        PositionLog(nodeNum: 12345, latitude: 37.7749, longitude: -122.4194),
      );

      await service.clearLogsForNode(12345);

      expect(await service.getDeviceMetrics(12345), isEmpty);
      expect(await service.getPositionLogs(12345), isEmpty);
    });

    test('clearDeviceMetrics clears device metrics for all nodes', () async {
      await service.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 111, batteryLevel: 80),
      );
      await service.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 222, batteryLevel: 70),
      );

      await service.clearDeviceMetrics();

      expect(await service.getDeviceMetrics(111), isEmpty);
      expect(await service.getDeviceMetrics(222), isEmpty);
    });
  });

  group('TelemetryStorageService - GetAll operations', () {
    test('getAllDeviceMetrics returns metrics from all nodes', () async {
      await service.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 111, batteryLevel: 80),
      );
      await service.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 222, batteryLevel: 70),
      );

      final all = await service.getAllDeviceMetrics();

      expect(all.length, 2);
    });

    test(
      'getAllDeviceMetrics returns sorted by timestamp descending',
      () async {
        await service.addDeviceMetrics(
          DeviceMetricsLog(nodeNum: 111, batteryLevel: 80),
        );
        await Future.delayed(const Duration(milliseconds: 10));
        await service.addDeviceMetrics(
          DeviceMetricsLog(nodeNum: 222, batteryLevel: 70),
        );

        final all = await service.getAllDeviceMetrics();

        // Most recent should be first
        expect(all.first.batteryLevel, 70);
        expect(all.last.batteryLevel, 80);
      },
    );
  });

  group('TelemetryStorageService - CSV Export', () {
    test('exportDeviceMetricsCsv generates valid CSV', () async {
      await service.addDeviceMetrics(
        DeviceMetricsLog(
          nodeNum: 12345,
          batteryLevel: 85,
          voltage: 4.1,
          channelUtilization: 15.5,
          airUtilTx: 2.5,
          uptimeSeconds: 3600,
        ),
      );

      final csv = await service.exportDeviceMetricsCsv(12345);

      expect(csv, contains('timestamp,batteryLevel,voltage'));
      expect(csv, contains('85'));
      expect(csv, contains('4.1'));
      expect(csv, contains('15.5'));
    });

    test('exportEnvironmentMetricsCsv generates valid CSV', () async {
      await service.addEnvironmentMetrics(
        EnvironmentMetricsLog(
          nodeNum: 12345,
          temperature: 22.5,
          humidity: 45.0,
        ),
      );

      final csv = await service.exportEnvironmentMetricsCsv(12345);

      expect(csv, contains('timestamp,temperature'));
      expect(csv, contains('22.5'));
      expect(csv, contains('45.0'));
    });

    test('exportPositionLogsCsv generates valid CSV', () async {
      await service.addPositionLog(
        PositionLog(
          nodeNum: 12345,
          latitude: 37.7749,
          longitude: -122.4194,
          altitude: 10,
        ),
      );

      final csv = await service.exportPositionLogsCsv(12345);

      expect(csv, contains('timestamp,latitude,longitude'));
      expect(csv, contains('37.7749'));
      expect(csv, contains('-122.4194'));
    });
  });
}
