import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/telemetry_log.dart';

void main() {
  group('DeviceMetricsLog', () {
    test('creates with required fields', () {
      final log = DeviceMetricsLog(nodeNum: 123);

      expect(log.id, isNotEmpty);
      expect(log.nodeNum, 123);
      expect(log.timestamp, isNotNull);
      expect(log.batteryLevel, isNull);
      expect(log.voltage, isNull);
      expect(log.channelUtilization, isNull);
      expect(log.airUtilTx, isNull);
      expect(log.uptimeSeconds, isNull);
    });

    test('creates with all fields', () {
      final timestamp = DateTime(2024, 1, 1);
      final log = DeviceMetricsLog(
        id: 'device-log-1',
        nodeNum: 456,
        timestamp: timestamp,
        batteryLevel: 75,
        voltage: 4.2,
        channelUtilization: 15.5,
        airUtilTx: 2.3,
        uptimeSeconds: 3600,
      );

      expect(log.id, 'device-log-1');
      expect(log.nodeNum, 456);
      expect(log.timestamp, timestamp);
      expect(log.batteryLevel, 75);
      expect(log.voltage, 4.2);
      expect(log.channelUtilization, 15.5);
      expect(log.airUtilTx, 2.3);
      expect(log.uptimeSeconds, 3600);
    });

    test('serializes to JSON', () {
      final log = DeviceMetricsLog(
        id: 'device-log-1',
        nodeNum: 123,
        batteryLevel: 80,
        voltage: 4.1,
      );

      final json = log.toJson();

      expect(json['id'], 'device-log-1');
      expect(json['nodeNum'], 123);
      expect(json['batteryLevel'], 80);
      expect(json['voltage'], 4.1);
      expect(json['timestamp'], isA<int>());
    });

    test('deserializes from JSON', () {
      final json = {
        'id': 'device-log-2',
        'nodeNum': 789,
        'timestamp': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'batteryLevel': 50,
        'voltage': 3.8,
        'channelUtilization': 20.0,
        'airUtilTx': 5.0,
        'uptimeSeconds': 7200,
      };

      final log = DeviceMetricsLog.fromJson(json);

      expect(log.id, 'device-log-2');
      expect(log.nodeNum, 789);
      expect(log.batteryLevel, 50);
      expect(log.voltage, 3.8);
      expect(log.channelUtilization, 20.0);
      expect(log.airUtilTx, 5.0);
      expect(log.uptimeSeconds, 7200);
    });
  });

  group('EnvironmentMetricsLog', () {
    test('creates with required fields', () {
      final log = EnvironmentMetricsLog(nodeNum: 123);

      expect(log.nodeNum, 123);
      expect(log.temperature, isNull);
      expect(log.humidity, isNull);
      expect(log.barometricPressure, isNull);
    });

    test('creates with all environment metrics', () {
      final log = EnvironmentMetricsLog(
        nodeNum: 123,
        temperature: 25.5,
        humidity: 60.0,
        barometricPressure: 1013.25,
        gasResistance: 50000.0,
        iaq: 50,
        lux: 500.0,
        whiteLux: 400.0,
        uvLux: 2.0,
        windDirection: 180,
        windSpeed: 5.5,
        windGust: 8.0,
        rainfall1h: 2.5,
        rainfall24h: 15.0,
        soilMoisture: 45,
        soilTemperature: 18.0,
      );

      expect(log.temperature, 25.5);
      expect(log.humidity, 60.0);
      expect(log.barometricPressure, 1013.25);
      expect(log.gasResistance, 50000.0);
      expect(log.iaq, 50);
      expect(log.lux, 500.0);
      expect(log.windDirection, 180);
      expect(log.windSpeed, 5.5);
      expect(log.soilMoisture, 45);
    });

    test('humidity and relativeHumidity are aliased', () {
      final log1 = EnvironmentMetricsLog(nodeNum: 1, humidity: 50.0);
      expect(log1.humidity, 50.0);
      expect(log1.relativeHumidity, 50.0);

      final log2 = EnvironmentMetricsLog(nodeNum: 2, relativeHumidity: 60.0);
      expect(log2.humidity, 60.0);
      expect(log2.relativeHumidity, 60.0);
    });

    test('serializes to JSON', () {
      final log = EnvironmentMetricsLog(
        nodeNum: 123,
        temperature: 25.0,
        humidity: 50.0,
      );

      final json = log.toJson();

      expect(json['nodeNum'], 123);
      expect(json['temperature'], 25.0);
      expect(json['humidity'], 50.0);
    });

    test('deserializes from JSON', () {
      final json = {
        'nodeNum': 456,
        'timestamp': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'temperature': 22.5,
        'humidity': 55.0,
        'barometricPressure': 1015.0,
        'iaq': 25,
      };

      final log = EnvironmentMetricsLog.fromJson(json);

      expect(log.nodeNum, 456);
      expect(log.temperature, 22.5);
      expect(log.humidity, 55.0);
      expect(log.barometricPressure, 1015.0);
      expect(log.iaq, 25);
    });
  });

  group('PowerMetricsLog', () {
    test('creates with required fields', () {
      final log = PowerMetricsLog(nodeNum: 123);

      expect(log.nodeNum, 123);
      expect(log.ch1Voltage, isNull);
      expect(log.ch1Current, isNull);
    });

    test('creates with all power metrics', () {
      final log = PowerMetricsLog(
        nodeNum: 123,
        ch1Voltage: 5.0,
        ch1Current: 0.5,
        ch2Voltage: 3.3,
        ch2Current: 0.2,
        ch3Voltage: 12.0,
        ch3Current: 1.0,
      );

      expect(log.ch1Voltage, 5.0);
      expect(log.ch1Current, 0.5);
      expect(log.ch2Voltage, 3.3);
      expect(log.ch2Current, 0.2);
      expect(log.ch3Voltage, 12.0);
      expect(log.ch3Current, 1.0);
    });

    test('serializes to JSON', () {
      final log = PowerMetricsLog(
        nodeNum: 123,
        ch1Voltage: 5.0,
        ch1Current: 0.5,
      );

      final json = log.toJson();

      expect(json['nodeNum'], 123);
      expect(json['ch1Voltage'], 5.0);
      expect(json['ch1Current'], 0.5);
    });

    test('deserializes from JSON', () {
      final json = {
        'nodeNum': 789,
        'timestamp': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'ch1Voltage': 4.5,
        'ch1Current': 0.3,
        'ch2Voltage': 3.0,
        'ch2Current': 0.1,
      };

      final log = PowerMetricsLog.fromJson(json);

      expect(log.nodeNum, 789);
      expect(log.ch1Voltage, 4.5);
      expect(log.ch1Current, 0.3);
      expect(log.ch2Voltage, 3.0);
      expect(log.ch2Current, 0.1);
    });
  });

  group('AirQualityMetricsLog', () {
    test('creates with required fields', () {
      final log = AirQualityMetricsLog(nodeNum: 123);

      expect(log.nodeNum, 123);
      expect(log.pm25Standard, isNull);
      expect(log.co2, isNull);
    });

    test('creates with all air quality metrics', () {
      final log = AirQualityMetricsLog(
        nodeNum: 123,
        pm10Standard: 10,
        pm25Standard: 25,
        pm100Standard: 100,
        pm10Environmental: 12,
        pm25Environmental: 28,
        pm100Environmental: 105,
        particles03um: 1000,
        particles05um: 500,
        particles10um: 200,
        particles25um: 50,
        particles50um: 10,
        particles100um: 2,
        co2: 450,
      );

      expect(log.pm10Standard, 10);
      expect(log.pm25Standard, 25);
      expect(log.pm100Standard, 100);
      expect(log.co2, 450);
      expect(log.particles03um, 1000);
    });

    test('serializes to JSON', () {
      final log = AirQualityMetricsLog(
        nodeNum: 123,
        pm25Standard: 25,
        co2: 400,
      );

      final json = log.toJson();

      expect(json['nodeNum'], 123);
      expect(json['pm25Standard'], 25);
      expect(json['co2'], 400);
    });

    test('deserializes from JSON', () {
      final json = {
        'nodeNum': 456,
        'timestamp': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'pm25Standard': 30,
        'pm100Standard': 80,
        'co2': 500,
      };

      final log = AirQualityMetricsLog.fromJson(json);

      expect(log.nodeNum, 456);
      expect(log.pm25Standard, 30);
      expect(log.pm100Standard, 80);
      expect(log.co2, 500);
    });
  });

  group('PositionLog', () {
    test('creates with required fields', () {
      final log = PositionLog(
        nodeNum: 123,
        latitude: -33.8688,
        longitude: 151.2093,
      );

      expect(log.nodeNum, 123);
      expect(log.latitude, -33.8688);
      expect(log.longitude, 151.2093);
      expect(log.altitude, isNull);
      expect(log.satsInView, isNull);
    });

    test('creates with all position fields', () {
      final log = PositionLog(
        nodeNum: 123,
        latitude: -33.8688,
        longitude: 151.2093,
        altitude: 50,
        satsInView: 12,
        speed: 5,
        heading: 180,
        precisionBits: 32,
      );

      expect(log.latitude, -33.8688);
      expect(log.longitude, 151.2093);
      expect(log.altitude, 50);
      expect(log.satsInView, 12);
      expect(log.speed, 5);
      expect(log.heading, 180);
      expect(log.precisionBits, 32);
    });

    test('serializes to JSON', () {
      final log = PositionLog(
        nodeNum: 123,
        latitude: -33.8688,
        longitude: 151.2093,
        altitude: 100,
      );

      final json = log.toJson();

      expect(json['nodeNum'], 123);
      expect(json['latitude'], -33.8688);
      expect(json['longitude'], 151.2093);
      expect(json['altitude'], 100);
    });

    test('deserializes from JSON', () {
      final json = {
        'nodeNum': 789,
        'timestamp': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'latitude': -33.5,
        'longitude': 151.5,
        'altitude': 200,
        'satsInView': 8,
        'speed': 10,
        'heading': 90,
      };

      final log = PositionLog.fromJson(json);

      expect(log.nodeNum, 789);
      expect(log.latitude, -33.5);
      expect(log.longitude, 151.5);
      expect(log.altitude, 200);
      expect(log.satsInView, 8);
      expect(log.speed, 10);
      expect(log.heading, 90);
    });
  });

  group('TraceRouteLog', () {
    test('creates with required fields', () {
      final log = TraceRouteLog(nodeNum: 123, targetNode: 456);

      expect(log.nodeNum, 123);
      expect(log.targetNode, 456);
      expect(log.sent, true);
      expect(log.response, false);
      expect(log.hopsTowards, 0);
      expect(log.hopsBack, 0);
      expect(log.hops, isEmpty);
    });

    test('creates with hops', () {
      final log = TraceRouteLog(
        nodeNum: 123,
        targetNode: 456,
        sent: true,
        response: true,
        hopsTowards: 2,
        hopsBack: 2,
        hops: [
          TraceRouteHop(nodeNum: 111, name: 'Relay1', snr: 5.0),
          TraceRouteHop(nodeNum: 222, name: 'Relay2', snr: 3.0, back: true),
        ],
        snr: 4.0,
      );

      expect(log.hops.length, 2);
      expect(log.hops.first.nodeNum, 111);
      expect(log.hops.first.name, 'Relay1');
      expect(log.hops.last.back, true);
      expect(log.snr, 4.0);
    });

    test('serializes to JSON', () {
      final log = TraceRouteLog(
        nodeNum: 123,
        targetNode: 456,
        hops: [TraceRouteHop(nodeNum: 111, name: 'Relay1')],
      );

      final json = log.toJson();

      expect(json['nodeNum'], 123);
      expect(json['targetNode'], 456);
      expect(json['hops'], isA<List>());
      expect((json['hops'] as List).length, 1);
    });

    test('deserializes from JSON', () {
      final json = {
        'nodeNum': 789,
        'targetNode': 321,
        'timestamp': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'sent': true,
        'response': true,
        'hopsTowards': 1,
        'hopsBack': 1,
        'hops': [
          {'nodeNum': 111, 'name': 'Hop1', 'snr': 5.0, 'back': false},
        ],
        'snr': 6.0,
      };

      final log = TraceRouteLog.fromJson(json);

      expect(log.nodeNum, 789);
      expect(log.targetNode, 321);
      expect(log.response, true);
      expect(log.hops.length, 1);
      expect(log.hops.first.name, 'Hop1');
      expect(log.snr, 6.0);
    });
  });

  group('TraceRouteHop', () {
    test('creates with required fields', () {
      final hop = TraceRouteHop(nodeNum: 123);

      expect(hop.nodeNum, 123);
      expect(hop.name, isNull);
      expect(hop.snr, isNull);
      expect(hop.back, false);
    });

    test('creates with all fields', () {
      final hop = TraceRouteHop(
        nodeNum: 123,
        name: 'TestHop',
        snr: 5.5,
        back: true,
        latitude: -33.8688,
        longitude: 151.2093,
      );

      expect(hop.nodeNum, 123);
      expect(hop.name, 'TestHop');
      expect(hop.snr, 5.5);
      expect(hop.back, true);
      expect(hop.latitude, -33.8688);
      expect(hop.longitude, 151.2093);
    });

    test('serializes to JSON', () {
      final hop = TraceRouteHop(nodeNum: 123, name: 'Hop', snr: 3.0);
      final json = hop.toJson();

      expect(json['nodeNum'], 123);
      expect(json['name'], 'Hop');
      expect(json['snr'], 3.0);
    });

    test('deserializes from JSON', () {
      final json = {
        'nodeNum': 456,
        'name': 'TestHop',
        'snr': 4.0,
        'back': true,
        'latitude': -33.5,
        'longitude': 151.5,
      };

      final hop = TraceRouteHop.fromJson(json);

      expect(hop.nodeNum, 456);
      expect(hop.name, 'TestHop');
      expect(hop.snr, 4.0);
      expect(hop.back, true);
      expect(hop.latitude, -33.5);
    });
  });

  group('PaxCounterLog', () {
    test('creates with required fields', () {
      final log = PaxCounterLog(nodeNum: 123, wifi: 10, ble: 5);

      expect(log.nodeNum, 123);
      expect(log.wifi, 10);
      expect(log.ble, 5);
      expect(log.uptime, 0);
    });

    test('calculates total', () {
      final log = PaxCounterLog(nodeNum: 123, wifi: 10, ble: 5);
      expect(log.total, 15);
    });

    test('serializes to JSON', () {
      final log = PaxCounterLog(nodeNum: 123, wifi: 20, ble: 10, uptime: 3600);
      final json = log.toJson();

      expect(json['nodeNum'], 123);
      expect(json['wifi'], 20);
      expect(json['ble'], 10);
      expect(json['uptime'], 3600);
    });

    test('deserializes from JSON', () {
      final json = {
        'nodeNum': 456,
        'timestamp': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'wifi': 15,
        'ble': 8,
        'uptime': 7200,
      };

      final log = PaxCounterLog.fromJson(json);

      expect(log.nodeNum, 456);
      expect(log.wifi, 15);
      expect(log.ble, 8);
      expect(log.uptime, 7200);
    });
  });

  group('DetectionSensorLog', () {
    test('creates with default values', () {
      final log = DetectionSensorLog(nodeNum: 123);

      expect(log.nodeNum, 123);
      expect(log.name, '');
      expect(log.detected, false);
      expect(log.eventType, isNull);
    });

    test('creates with all fields', () {
      final log = DetectionSensorLog(
        nodeNum: 123,
        name: 'Motion Sensor',
        detected: true,
        eventType: 'motion',
      );

      expect(log.name, 'Motion Sensor');
      expect(log.detected, true);
      expect(log.eventType, 'motion');
    });

    test('serializes to JSON', () {
      final log = DetectionSensorLog(
        nodeNum: 123,
        name: 'Door Sensor',
        detected: true,
        eventType: 'open',
      );
      final json = log.toJson();

      expect(json['nodeNum'], 123);
      expect(json['name'], 'Door Sensor');
      expect(json['detected'], true);
      expect(json['eventType'], 'open');
    });

    test('deserializes from JSON', () {
      final json = {
        'nodeNum': 789,
        'timestamp': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'name': 'PIR',
        'detected': true,
        'eventType': 'motion_detected',
      };

      final log = DetectionSensorLog.fromJson(json);

      expect(log.nodeNum, 789);
      expect(log.name, 'PIR');
      expect(log.detected, true);
      expect(log.eventType, 'motion_detected');
    });

    test('deserializes from JSON with sensorName alias', () {
      final json = {
        'nodeNum': 123,
        'sensorName': 'Legacy Sensor',
        'detected': false,
      };

      final log = DetectionSensorLog.fromJson(json);

      expect(log.name, 'Legacy Sensor');
    });
  });
}
