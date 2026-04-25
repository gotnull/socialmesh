// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/generated/meshtastic/config.pb.dart' as config_pb;
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart'
    as config_pbenum;
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as mesh_pb;
import 'package:socialmesh/generated/meshtastic/module_config.pb.dart'
    as module_pb;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/backup/device_config_bundle.dart';

void main() {
  group('DeviceConfigBundle', () {
    test('round-trip encode/decode preserves every section byte-for-byte', () {
      final bundle = _buildFixtureBundle();
      final json = bundle.encode();
      final restored = DeviceConfigBundle.decode(json);

      expect(restored.schemaVersion, kDeviceConfigBundleSchemaVersion);
      expect(restored.nodeNum, bundle.nodeNum);
      expect(restored.deviceMetadata, bundle.deviceMetadata);

      expect(
        restored.owner!.writeToBuffer(),
        bundle.owner!.writeToBuffer(),
        reason: 'owner round-trip mismatch',
      );

      expect(restored.lora!.writeToBuffer(), bundle.lora!.writeToBuffer());
      expect(restored.device!.writeToBuffer(), bundle.device!.writeToBuffer());
      expect(
        restored.position!.writeToBuffer(),
        bundle.position!.writeToBuffer(),
      );
      expect(restored.power!.writeToBuffer(), bundle.power!.writeToBuffer());
      expect(
        restored.network!.writeToBuffer(),
        bundle.network!.writeToBuffer(),
      );
      expect(
        restored.display!.writeToBuffer(),
        bundle.display!.writeToBuffer(),
      );
      expect(
        restored.bluetooth!.writeToBuffer(),
        bundle.bluetooth!.writeToBuffer(),
      );
      expect(
        restored.security!.writeToBuffer(),
        bundle.security!.writeToBuffer(),
      );

      expect(
        restored.moduleConfigBytes[BundleModuleType.mqtt],
        bundle.moduleConfigBytes[BundleModuleType.mqtt],
      );
      expect(
        restored.moduleConfigBytes[BundleModuleType.telemetry],
        bundle.moduleConfigBytes[BundleModuleType.telemetry],
      );

      expect(restored.channels.length, bundle.channels.length);
      for (var i = 0; i < bundle.channels.length; i++) {
        final original = bundle.channels[i];
        final after = restored.channels[i];
        expect(after.index, original.index);
        expect(after.name, original.name);
        expect(after.psk, original.psk, reason: 'channel $i PSK mismatch');
        expect(after.uplink, original.uplink);
        expect(after.downlink, original.downlink);
        expect(after.role, original.role);
        expect(after.positionPrecision, original.positionPrecision);
      }
    });

    test('throws on missing schemaVersion', () {
      final json = jsonEncode({'sections': {}});
      expect(
        () => DeviceConfigBundle.decode(json),
        throwsA(isA<DeviceConfigBundleException>()),
      );
    });

    test('throws on unsupported schemaVersion', () {
      final json = jsonEncode({
        'schemaVersion': '99',
        'createdAt': '2026-01-01T00:00:00Z',
        'sections': {},
      });
      expect(
        () => DeviceConfigBundle.decode(json),
        throwsA(isA<DeviceConfigBundleException>()),
      );
    });

    test('throws on non-JSON input', () {
      expect(
        () => DeviceConfigBundle.decode('not json'),
        throwsA(isA<DeviceConfigBundleException>()),
      );
    });

    test('unknown sections are ignored (forward-compat)', () {
      final json = jsonEncode({
        'schemaVersion': '1',
        'createdAt': '2026-01-01T00:00:00Z',
        'sections': {
          'futureFeature': {'arbitrary': 'payload'},
          'configs': {
            'lora': base64Encode(
              (config_pb.Config_LoRaConfig()
                    ..region = config_pbenum.Config_LoRaConfig_RegionCode.US
                    ..hopLimit = 3)
                  .writeToBuffer(),
            ),
          },
        },
      });

      final bundle = DeviceConfigBundle.decode(json);
      expect(
        bundle.lora!.region,
        config_pbenum.Config_LoRaConfig_RegionCode.US,
      );
      expect(bundle.lora!.hopLimit, 3);
    });

    test(
      'channel PSK survives round-trip including high bytes and zero bytes',
      () {
        final psk = List<int>.generate(32, (i) => (i * 7 + 13) & 0xFF);
        final channel = ChannelConfig(
          index: 1,
          name: 'BankVault',
          psk: psk,
          uplink: true,
          downlink: false,
          role: 'SECONDARY',
          positionPrecision: 0,
        );
        final bundle = DeviceConfigBundle(
          createdAt: DateTime.utc(2026, 4, 26, 12, 0),
          nodeNum: 0xDEADBEEF,
          channels: [channel],
        );
        final restored = DeviceConfigBundle.decode(bundle.encode());

        expect(restored.channels.single.psk, psk);
      },
    );

    test('isEmpty returns true when no sections are present', () {
      final bundle = DeviceConfigBundle(createdAt: DateTime.utc(2026, 1, 1));
      expect(bundle.isEmpty, isTrue);
    });

    test('isEmpty returns false when at least one section exists', () {
      final bundle = DeviceConfigBundle(
        createdAt: DateTime.utc(2026, 1, 1),
        owner: mesh_pb.User()..longName = 'Test',
      );
      expect(bundle.isEmpty, isFalse);
    });

    test('suggestedFilename includes node id and timestamp', () {
      final bundle = DeviceConfigBundle(
        createdAt: DateTime.utc(2026, 4, 26, 9, 30),
        nodeNum: 0x12345678,
      );
      final name = bundle.suggestedFilename();
      expect(name, contains('12345678'));
      expect(name, contains('202604260930'));
      expect(name, endsWith('.smcfg.json'));
    });

    test('encoded JSON omits sections that are null', () {
      final bundle = DeviceConfigBundle(
        createdAt: DateTime.utc(2026, 1, 1),
        nodeNum: 1,
        owner: mesh_pb.User()..longName = 'Just owner',
      );
      final raw = jsonDecode(bundle.encode()) as Map<String, dynamic>;
      final sections = raw['sections'] as Map<String, dynamic>;
      expect(sections.containsKey('owner'), isTrue);
      expect(sections.containsKey('configs'), isFalse);
      expect(sections.containsKey('moduleConfigs'), isFalse);
      expect(sections.containsKey('channels'), isFalse);
    });
  });
}

DeviceConfigBundle _buildFixtureBundle() {
  final owner = mesh_pb.User()
    ..id = '!12345678'
    ..longName = 'Field Operator'
    ..shortName = 'FOPS'
    ..isLicensed = true;

  final lora = config_pb.Config_LoRaConfig()
    ..usePreset = true
    ..region = config_pbenum.Config_LoRaConfig_RegionCode.EU_868
    ..modemPreset = config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST
    ..hopLimit = 3
    ..txEnabled = true
    ..txPower = 27;

  final device = config_pb.Config_DeviceConfig()
    ..role = config_pbenum.Config_DeviceConfig_Role.CLIENT
    ..nodeInfoBroadcastSecs = 10800;

  final position = config_pb.Config_PositionConfig()
    ..positionBroadcastSecs = 900
    ..positionBroadcastSmartEnabled = true;

  final power = config_pb.Config_PowerConfig()..waitBluetoothSecs = 60;

  final network = config_pb.Config_NetworkConfig()..wifiEnabled = false;

  final display = config_pb.Config_DisplayConfig()..screenOnSecs = 60;

  final bluetooth = config_pb.Config_BluetoothConfig()..enabled = true;

  final security = config_pb.Config_SecurityConfig()
    ..isManaged = false
    ..serialEnabled = true;

  final mqtt = module_pb.ModuleConfig_MQTTConfig()
    ..enabled = true
    ..address = 'mqtt.example.com'
    ..root = 'msh/EU_868';

  final telemetry = module_pb.ModuleConfig_TelemetryConfig()
    ..deviceUpdateInterval = 1800;

  return DeviceConfigBundle(
    createdAt: DateTime.utc(2026, 4, 26, 12, 0),
    nodeNum: 0x12345678,
    deviceMetadata: 'fw=2.5.18 hw=HELTEC_V3',
    owner: owner,
    lora: lora,
    device: device,
    position: position,
    power: power,
    network: network,
    display: display,
    bluetooth: bluetooth,
    security: security,
    moduleConfigBytes: {
      BundleModuleType.mqtt: mqtt.writeToBuffer(),
      BundleModuleType.telemetry: telemetry.writeToBuffer(),
    },
    channels: [
      ChannelConfig(
        index: 0,
        name: 'LongFast',
        psk: const [1],
        role: 'PRIMARY',
      ),
      ChannelConfig(
        index: 1,
        name: 'Backchannel',
        psk: const [
          0xAA,
          0xBB,
          0xCC,
          0xDD,
          0xEE,
          0xFF,
          0x00,
          0x11,
          0x22,
          0x33,
          0x44,
          0x55,
          0x66,
          0x77,
          0x88,
          0x99,
        ],
        uplink: true,
        downlink: true,
        role: 'SECONDARY',
        positionPrecision: 14,
      ),
    ],
  );
}
