import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/device_config_models.dart';

void main() {
  group('DeviceRole', () {
    test('has all expected values', () {
      expect(DeviceRole.values.length, 11);
      expect(DeviceRole.values, contains(DeviceRole.client));
      expect(DeviceRole.values, contains(DeviceRole.clientMute));
      expect(DeviceRole.values, contains(DeviceRole.router));
      expect(DeviceRole.values, contains(DeviceRole.tracker));
      expect(DeviceRole.values, contains(DeviceRole.sensor));
      expect(DeviceRole.values, contains(DeviceRole.tak));
      expect(DeviceRole.values, contains(DeviceRole.clientHidden));
      expect(DeviceRole.values, contains(DeviceRole.lostAndFound));
      expect(DeviceRole.values, contains(DeviceRole.takTracker));
      expect(DeviceRole.values, contains(DeviceRole.routerLate));
      expect(DeviceRole.values, contains(DeviceRole.clientBase));
    });

    test('client has correct properties', () {
      expect(DeviceRole.client.displayName, 'Client');
      expect(DeviceRole.client.description, 'Standard messaging device');
    });

    test('router has correct properties', () {
      expect(DeviceRole.router.displayName, 'Router');
      expect(
        DeviceRole.router.description,
        'Infrastructure node for extending coverage',
      );
    });

    test('all roles have non-empty displayName', () {
      for (final role in DeviceRole.values) {
        expect(role.displayName, isNotEmpty);
      }
    });

    test('all roles have non-empty description', () {
      for (final role in DeviceRole.values) {
        expect(role.description, isNotEmpty);
      }
    });
  });

  group('RebroadcastMode', () {
    test('has all expected values', () {
      expect(RebroadcastMode.values.length, 6);
    });

    test('all has correct properties', () {
      expect(RebroadcastMode.all.displayName, 'All');
      expect(
        RebroadcastMode.all.description,
        'Rebroadcast all observed messages',
      );
    });

    test('none has correct properties', () {
      expect(RebroadcastMode.none.displayName, 'None');
      expect(RebroadcastMode.none.description, 'Do not rebroadcast');
    });
  });

  group('DeviceConfig', () {
    test('creates with default values', () {
      final config = DeviceConfig();

      expect(config.role, DeviceRole.client);
      expect(config.rebroadcastMode, RebroadcastMode.all);
      expect(config.nodeInfoBroadcastSecs, 900);
      expect(config.serialEnabled, true);
      expect(config.doubleTapAsButtonPress, false);
      expect(config.disableTripleClick, false);
      expect(config.ledHeartbeatDisabled, false);
      expect(config.tzdef, isNull);
    });

    test('creates with custom values', () {
      final config = DeviceConfig(
        role: DeviceRole.router,
        rebroadcastMode: RebroadcastMode.localOnly,
        nodeInfoBroadcastSecs: 1800,
        serialEnabled: false,
        tzdef: 'EST5EDT',
      );

      expect(config.role, DeviceRole.router);
      expect(config.rebroadcastMode, RebroadcastMode.localOnly);
      expect(config.nodeInfoBroadcastSecs, 1800);
      expect(config.serialEnabled, false);
      expect(config.tzdef, 'EST5EDT');
    });

    test('copyWith preserves unmodified values', () {
      final original = DeviceConfig(
        role: DeviceRole.router,
        nodeInfoBroadcastSecs: 1800,
      );

      final copied = original.copyWith(serialEnabled: false);

      expect(copied.role, DeviceRole.router);
      expect(copied.nodeInfoBroadcastSecs, 1800);
      expect(copied.serialEnabled, false);
    });
  });

  group('GpsMode', () {
    test('has all expected values', () {
      expect(GpsMode.values.length, 3);
    });

    test('enabled has correct properties', () {
      expect(GpsMode.enabled.displayName, 'Enabled');
      expect(GpsMode.enabled.description, 'GPS is present and enabled');
    });

    test('disabled has correct properties', () {
      expect(GpsMode.disabled.displayName, 'Disabled');
      expect(GpsMode.disabled.description, 'GPS is present but disabled');
    });

    test('notPresent has correct properties', () {
      expect(GpsMode.notPresent.displayName, 'Not Present');
      expect(GpsMode.notPresent.description, 'GPS is not present on device');
    });
  });

  group('PositionConfig', () {
    test('creates with default values', () {
      final config = PositionConfig();

      expect(config.positionBroadcastSecs, 900);
      expect(config.smartBroadcastEnabled, true);
      expect(config.fixedPosition, false);
      expect(config.gpsMode, GpsMode.enabled);
      expect(config.gpsUpdateInterval, 30);
      expect(config.smartMinimumDistance, 100);
      expect(config.smartMinimumIntervalSecs, 30);
    });

    test('copyWith preserves unmodified values', () {
      final original = PositionConfig(
        positionBroadcastSecs: 1800,
        fixedPosition: true,
      );

      final copied = original.copyWith(gpsMode: GpsMode.disabled);

      expect(copied.positionBroadcastSecs, 1800);
      expect(copied.fixedPosition, true);
      expect(copied.gpsMode, GpsMode.disabled);
    });
  });

  group('PowerConfig', () {
    test('creates with default values', () {
      final config = PowerConfig();

      expect(config.isPowerSaving, false);
      expect(config.onBatteryShutdownAfterSecs, 0);
      expect(config.waitBluetoothSecs, 60);
      expect(config.sdsSecs, 31536000);
      expect(config.lsSecs, 300);
      expect(config.minWakeSecs, 10);
    });

    test('copyWith preserves unmodified values', () {
      final original = PowerConfig(isPowerSaving: true, lsSecs: 600);

      final copied = original.copyWith(minWakeSecs: 20);

      expect(copied.isPowerSaving, true);
      expect(copied.lsSecs, 600);
      expect(copied.minWakeSecs, 20);
    });
  });

  group('DisplayUnits', () {
    test('has all expected values', () {
      expect(DisplayUnits.values.length, 2);
    });

    test('metric has correct properties', () {
      expect(DisplayUnits.metric.displayName, 'Metric');
      expect(DisplayUnits.metric.description, 'Kilometers, Celsius');
    });

    test('imperial has correct properties', () {
      expect(DisplayUnits.imperial.displayName, 'Imperial');
      expect(DisplayUnits.imperial.description, 'Miles, Fahrenheit');
    });
  });

  group('DisplayConfig', () {
    test('creates with default values', () {
      final config = DisplayConfig();

      expect(config.screenOnSecs, 60);
      expect(config.autoScreenCarouselSecs, 0);
      expect(config.flipScreen, false);
      expect(config.units, DisplayUnits.metric);
      expect(config.headingBold, false);
      expect(config.wakeOnTapOrMotion, false);
      expect(config.use12hClock, false);
    });

    test('copyWith preserves unmodified values', () {
      final original = DisplayConfig(
        screenOnSecs: 120,
        units: DisplayUnits.imperial,
      );

      final copied = original.copyWith(flipScreen: true);

      expect(copied.screenOnSecs, 120);
      expect(copied.units, DisplayUnits.imperial);
      expect(copied.flipScreen, true);
    });
  });

  group('BluetoothPairingMode', () {
    test('has all expected values', () {
      expect(BluetoothPairingMode.values.length, 3);
    });

    test('randomPin has correct properties', () {
      expect(BluetoothPairingMode.randomPin.displayName, 'Random PIN');
      expect(
        BluetoothPairingMode.randomPin.description,
        'Generate random PIN shown on screen',
      );
    });

    test('fixedPin has correct properties', () {
      expect(BluetoothPairingMode.fixedPin.displayName, 'Fixed PIN');
      expect(
        BluetoothPairingMode.fixedPin.description,
        'Use a specified fixed PIN',
      );
    });

    test('noPin has correct properties', () {
      expect(BluetoothPairingMode.noPin.displayName, 'No PIN');
      expect(
        BluetoothPairingMode.noPin.description,
        'No PIN required for pairing',
      );
    });
  });

  group('BluetoothConfig', () {
    test('creates with default values', () {
      final config = BluetoothConfig();

      expect(config.enabled, true);
      expect(config.mode, BluetoothPairingMode.randomPin);
      expect(config.fixedPin, 123456);
    });

    test('copyWith preserves unmodified values', () {
      final original = BluetoothConfig(
        enabled: false,
        mode: BluetoothPairingMode.fixedPin,
      );

      final copied = original.copyWith(fixedPin: 999999);

      expect(copied.enabled, false);
      expect(copied.mode, BluetoothPairingMode.fixedPin);
      expect(copied.fixedPin, 999999);
    });
  });

  group('ModemPreset', () {
    test('has all expected values', () {
      expect(ModemPreset.values.length, 8);
    });

    test('longFast has correct properties', () {
      expect(ModemPreset.longFast.displayName, 'Long Fast');
      expect(
        ModemPreset.longFast.description,
        '250kHz bandwidth, optimized for range',
      );
    });

    test('shortTurbo has correct properties', () {
      expect(ModemPreset.shortTurbo.displayName, 'Short Turbo');
      expect(
        ModemPreset.shortTurbo.description,
        'Fastest preset, 500kHz bandwidth',
      );
    });
  });

  group('LoRaConfig', () {
    test('creates with default values', () {
      final config = LoRaConfig();

      expect(config.usePreset, true);
      expect(config.modemPreset, ModemPreset.longFast);
      expect(config.hopLimit, 3);
      expect(config.txEnabled, true);
      expect(config.txPower, 0);
      expect(config.overrideDutyCycle, false);
      expect(config.sx126xRxBoostedGain, false);
      expect(config.ignoreMqtt, false);
    });

    test('copyWith preserves unmodified values', () {
      final original = LoRaConfig(
        modemPreset: ModemPreset.longSlow,
        hopLimit: 5,
      );

      final copied = original.copyWith(txEnabled: false);

      expect(copied.modemPreset, ModemPreset.longSlow);
      expect(copied.hopLimit, 5);
      expect(copied.txEnabled, false);
    });
  });

  group('DeviceMetadata', () {
    test('creates with default values', () {
      final metadata = DeviceMetadata();

      expect(metadata.firmwareVersion, 'Unknown');
      expect(metadata.deviceStateVersion, 0);
      expect(metadata.canShutdown, false);
      expect(metadata.hasWifi, false);
      expect(metadata.hasBluetooth, true);
      expect(metadata.hasEthernet, false);
      expect(metadata.role, isNull);
      expect(metadata.hardwareModel, isNull);
      expect(metadata.hasRemoteHardware, false);
      expect(metadata.hasPKC, false);
    });

    test('creates with all values', () {
      final metadata = DeviceMetadata(
        firmwareVersion: '2.3.0',
        deviceStateVersion: 1,
        canShutdown: true,
        hasWifi: true,
        hasBluetooth: true,
        hasEthernet: true,
        role: 'ROUTER',
        hardwareModel: 'TBEAM',
        hasRemoteHardware: true,
        hasPKC: true,
      );

      expect(metadata.firmwareVersion, '2.3.0');
      expect(metadata.canShutdown, true);
      expect(metadata.hasWifi, true);
      expect(metadata.hasEthernet, true);
      expect(metadata.role, 'ROUTER');
      expect(metadata.hardwareModel, 'TBEAM');
      expect(metadata.hasRemoteHardware, true);
      expect(metadata.hasPKC, true);
    });
  });

  group('MQTTConfig', () {
    test('creates with default values', () {
      final config = MQTTConfig();

      expect(config.enabled, false);
      expect(config.address, '');
      expect(config.username, '');
      expect(config.password, '');
      expect(config.encryptionEnabled, true);
      expect(config.jsonEnabled, false);
      expect(config.tlsEnabled, false);
      expect(config.root, 'msh');
      expect(config.proxyToClientEnabled, false);
      expect(config.mapReportingEnabled, false);
    });

    test('copyWith preserves unmodified values', () {
      final original = MQTTConfig(
        enabled: true,
        address: 'mqtt.example.com',
        username: 'user',
      );

      final copied = original.copyWith(password: 'secret');

      expect(copied.enabled, true);
      expect(copied.address, 'mqtt.example.com');
      expect(copied.username, 'user');
      expect(copied.password, 'secret');
    });
  });

  group('TelemetryConfig', () {
    test('creates with default values', () {
      final config = TelemetryConfig();

      expect(config.deviceUpdateInterval, 1800);
      expect(config.environmentUpdateInterval, 1800);
      expect(config.environmentMeasurementEnabled, false);
      expect(config.environmentScreenEnabled, false);
      expect(config.environmentDisplayFahrenheit, false);
      expect(config.airQualityEnabled, false);
      expect(config.airQualityInterval, 1800);
      expect(config.powerMeasurementEnabled, false);
      expect(config.powerUpdateInterval, 1800);
    });

    test('copyWith preserves unmodified values', () {
      final original = TelemetryConfig(
        deviceUpdateInterval: 900,
        environmentMeasurementEnabled: true,
      );

      final copied = original.copyWith(airQualityEnabled: true);

      expect(copied.deviceUpdateInterval, 900);
      expect(copied.environmentMeasurementEnabled, true);
      expect(copied.airQualityEnabled, true);
    });
  });

  group('ExternalNotificationConfig', () {
    test('creates with default values', () {
      final config = ExternalNotificationConfig();

      expect(config.enabled, false);
      expect(config.outputMs, 1000);
      expect(config.active, false);
      expect(config.alertMessage, true);
      expect(config.alertBell, true);
      expect(config.usePwm, false);
      expect(config.nagTimeout, 0);
    });

    test('copyWith preserves unmodified values', () {
      final original = ExternalNotificationConfig(enabled: true, outputMs: 500);

      final copied = original.copyWith(alertBell: false);

      expect(copied.enabled, true);
      expect(copied.outputMs, 500);
      expect(copied.alertBell, false);
    });
  });

  group('StoreForwardConfig', () {
    test('creates with default values', () {
      final config = StoreForwardConfig();

      expect(config.enabled, false);
      expect(config.heartbeat, false);
      expect(config.records, 0);
      expect(config.historyReturnMax, 0);
      expect(config.historyReturnWindow, 0);
      expect(config.isServer, false);
    });

    test('copyWith preserves unmodified values', () {
      final original = StoreForwardConfig(enabled: true, isServer: true);

      final copied = original.copyWith(records: 100);

      expect(copied.enabled, true);
      expect(copied.isServer, true);
      expect(copied.records, 100);
    });
  });

  group('RangeTestConfig', () {
    test('creates with default values', () {
      final config = RangeTestConfig();

      expect(config.enabled, false);
      expect(config.sender, 0);
      expect(config.save, false);
    });

    test('copyWith preserves unmodified values', () {
      final original = RangeTestConfig(enabled: true, sender: 60);

      final copied = original.copyWith(save: true);

      expect(copied.enabled, true);
      expect(copied.sender, 60);
      expect(copied.save, true);
    });
  });

  group('FixedPosition', () {
    test('creates with required fields', () {
      final position = FixedPosition(latitude: -33.8688, longitude: 151.2093);

      expect(position.latitude, -33.8688);
      expect(position.longitude, 151.2093);
      expect(position.altitude, 0);
    });

    test('creates with altitude', () {
      final position = FixedPosition(
        latitude: -33.8688,
        longitude: 151.2093,
        altitude: 100,
      );

      expect(position.altitude, 100);
    });
  });
}
