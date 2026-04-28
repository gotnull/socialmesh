// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/generated/meshtastic/config.pb.dart' as config_pb;
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart'
    as config_pbenum;
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as mesh_pb;
import 'package:socialmesh/generated/meshtastic/module_config.pb.dart'
    as module_pb;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/backup/device_config_backup_service.dart';
import 'package:socialmesh/services/backup/device_config_bundle.dart';

void main() {
  group('DeviceConfigBackupService.capture', () {
    test('returns a populated bundle when every section is cached', () async {
      final gateway = _FakeGateway()..snapshotData = _fullySeededSnapshot();
      final service = DeviceConfigBackupService(gateway: gateway);

      final result = await service.capture();

      expect(result.missingSections, isEmpty);
      expect(result.bundle.owner, isNotNull);
      expect(result.bundle.lora, isNotNull);
      expect(result.bundle.device, isNotNull);
      expect(result.bundle.channels, hasLength(1));
      expect(
        result.bundle.moduleConfigBytes.containsKey(BundleModuleType.mqtt),
        isTrue,
      );
      expect(
        gateway.refreshCalls,
        isEmpty,
        reason: 'cache was full so no refresh should have fired',
      );
    });

    test(
      'fires refresh and waits when cache is empty, drops timed-out sections',
      () async {
        // Gateway returns null for lora initially. After refresh, the next
        // snapshot has lora populated. waitForSection returns true for lora,
        // false for everything else (timeout).
        final gateway = _FakeGateway();

        // Initial snapshot — empty.
        gateway.snapshotData = const DeviceConfigSnapshot(myNodeNum: 42);

        gateway.onRefresh = (section) async {
          if (section == DeviceConfigSection.lora) {
            // Lora arrives — patch the snapshot.
            gateway.snapshotData = DeviceConfigSnapshot(
              myNodeNum: 42,
              lora: config_pb.Config_LoRaConfig()
                ..region = config_pbenum.Config_LoRaConfig_RegionCode.US,
            );
          }
          // Other sections never arrive.
        };

        gateway.onWaitForSection = (section, _) async {
          return section == DeviceConfigSection.lora;
        };

        final service = DeviceConfigBackupService(
          gateway: gateway,
          refreshTimeout: const Duration(milliseconds: 1),
        );

        final result = await service.capture();

        expect(result.bundle.lora, isNotNull);
        expect(result.bundle.device, isNull);
        expect(result.missingSections, contains('device'));
        expect(result.missingSections, contains('owner'));
        expect(result.missingSections, isNot(contains('lora')));
      },
    );
  });

  group('DeviceConfigBackupService.restore', () {
    test(
      'respects RestoreSelection — sections set to false are not applied',
      () async {
        final gateway = _FakeGateway();
        final service = DeviceConfigBackupService(
          gateway: gateway,
          channelGap: Duration.zero,
        );

        final bundle = DeviceConfigBundle(
          createdAt: DateTime.utc(2026, 1, 1),
          owner: mesh_pb.User()..longName = 'X',
          lora: config_pb.Config_LoRaConfig()
            ..region = config_pbenum.Config_LoRaConfig_RegionCode.US,
          moduleConfigBytes: {
            BundleModuleType.mqtt:
                (module_pb.ModuleConfig_MQTTConfig()..enabled = true)
                    .writeToBuffer(),
          },
          channels: [
            ChannelConfig(
              index: 0,
              name: 'LongFast',
              psk: const [1],
              role: 'PRIMARY',
            ),
          ],
        );

        // Apply only channels.
        final report = await service.restore(
          bundle,
          const RestoreSelection(channels: true),
        );

        expect(gateway.appliedConfigs, isEmpty);
        expect(gateway.appliedModuleConfigs, isEmpty);
        expect(gateway.appliedOwners, isEmpty);
        expect(gateway.appliedChannels, hasLength(1));
        expect(report.applied, contains('channel:0'));
        expect(report.applied.where((s) => s.startsWith('module:')), isEmpty);
        expect(report.applied, isNot(contains('owner')));
      },
    );

    test('reports per-section apply/fail counts', () async {
      final gateway = _FakeGateway()
        ..failOn.add('Config:lora')
        ..failOn.add('Channel:1');
      final service = DeviceConfigBackupService(
        gateway: gateway,
        channelGap: Duration.zero,
      );

      final bundle = DeviceConfigBundle(
        createdAt: DateTime.utc(2026, 1, 1),
        lora: config_pb.Config_LoRaConfig()
          ..region = config_pbenum.Config_LoRaConfig_RegionCode.US,
        device: config_pb.Config_DeviceConfig()
          ..role = config_pbenum.Config_DeviceConfig_Role.CLIENT,
        channels: [
          ChannelConfig(index: 0, name: 'A', psk: const [1], role: 'PRIMARY'),
          ChannelConfig(
            index: 1,
            name: 'B',
            psk: const [2, 3, 4],
            role: 'SECONDARY',
          ),
        ],
      );

      final report = await service.restore(
        bundle,
        const RestoreSelection(channels: true, radio: true),
      );

      expect(report.failed.containsKey('lora'), isTrue);
      expect(report.failed.containsKey('channel:1'), isTrue);
      expect(report.applied, contains('device'));
      expect(report.applied, contains('channel:0'));
      expect(report.hasFailures, isTrue);
    });

    test(
      'skipped section keys are tracked when bundle is missing them',
      () async {
        final gateway = _FakeGateway();
        final service = DeviceConfigBackupService(
          gateway: gateway,
          channelGap: Duration.zero,
        );

        final bundle = DeviceConfigBundle(
          createdAt: DateTime.utc(2026, 1, 1),
          lora: config_pb.Config_LoRaConfig()
            ..region = config_pbenum.Config_LoRaConfig_RegionCode.US,
          // device, position, etc. all null.
        );

        final report = await service.restore(
          bundle,
          const RestoreSelection(radio: true, owner: true),
        );

        expect(report.applied, contains('lora'));
        expect(report.skipped, contains('owner'));
        expect(report.skipped, contains('device'));
        expect(report.skipped, contains('position'));
      },
    );
  });
}

DeviceConfigSnapshot _fullySeededSnapshot() {
  return DeviceConfigSnapshot(
    myNodeNum: 0xABCD0001,
    deviceMetadata: 'fw=2.5.18',
    owner: mesh_pb.User()..longName = 'Op',
    lora: config_pb.Config_LoRaConfig()
      ..region = config_pbenum.Config_LoRaConfig_RegionCode.EU_868,
    device: config_pb.Config_DeviceConfig()
      ..role = config_pbenum.Config_DeviceConfig_Role.CLIENT,
    position: config_pb.Config_PositionConfig()..positionBroadcastSecs = 900,
    power: config_pb.Config_PowerConfig(),
    network: config_pb.Config_NetworkConfig(),
    display: config_pb.Config_DisplayConfig(),
    bluetooth: config_pb.Config_BluetoothConfig()..enabled = true,
    security: config_pb.Config_SecurityConfig(),
    mqtt: module_pb.ModuleConfig_MQTTConfig()..enabled = false,
    serial: module_pb.ModuleConfig_SerialConfig(),
    externalNotification: module_pb.ModuleConfig_ExternalNotificationConfig(),
    storeForward: module_pb.ModuleConfig_StoreForwardConfig(),
    rangeTest: module_pb.ModuleConfig_RangeTestConfig(),
    telemetry: module_pb.ModuleConfig_TelemetryConfig()
      ..deviceUpdateInterval = 1800,
    cannedMessage: module_pb.ModuleConfig_CannedMessageConfig(),
    ambientLighting: module_pb.ModuleConfig_AmbientLightingConfig(),
    detectionSensor: module_pb.ModuleConfig_DetectionSensorConfig(),
    paxcounter: module_pb.ModuleConfig_PaxcounterConfig(),
    channels: [
      ChannelConfig(
        index: 0,
        name: 'LongFast',
        psk: const [1],
        role: 'PRIMARY',
      ),
    ],
  );
}

class _FakeGateway implements DeviceConfigBackupGateway {
  DeviceConfigSnapshot snapshotData = const DeviceConfigSnapshot();

  /// Section keys to fail on. Format: `Config:lora`, `Module:mqtt`,
  /// `Channel:0`, `Owner:long`.
  final Set<String> failOn = {};

  /// Optional hook called from refresh(); useful to mutate [snapshotData].
  Future<void> Function(DeviceConfigSection)? onRefresh;

  /// Optional hook for waitForSection; defaults to true (immediate).
  Future<bool> Function(DeviceConfigSection, Duration)? onWaitForSection;

  final List<DeviceConfigSection> refreshCalls = [];
  final List<config_pb.Config> appliedConfigs = [];
  final List<module_pb.ModuleConfig> appliedModuleConfigs = [];
  final List<ChannelConfig> appliedChannels = [];
  final List<mesh_pb.User> appliedOwners = [];

  @override
  DeviceConfigSnapshot snapshot() => snapshotData;

  @override
  Future<void> refresh(DeviceConfigSection section) async {
    refreshCalls.add(section);
    if (onRefresh != null) await onRefresh!(section);
  }

  @override
  Future<bool> waitForSection(
    DeviceConfigSection section,
    Duration timeout,
  ) async {
    if (onWaitForSection != null) {
      return onWaitForSection!(section, timeout);
    }
    return true;
  }

  @override
  Future<void> applyConfig(config_pb.Config config) async {
    final key = _configKey(config);
    if (key != null && failOn.contains('Config:$key')) {
      throw StateError('fake failure for $key');
    }
    appliedConfigs.add(config);
  }

  @override
  Future<void> applyModuleConfig(module_pb.ModuleConfig moduleConfig) async {
    final key = _moduleKey(moduleConfig);
    if (key != null && failOn.contains('Module:$key')) {
      throw StateError('fake failure for module $key');
    }
    appliedModuleConfigs.add(moduleConfig);
  }

  @override
  Future<void> applyChannel(ChannelConfig channel) async {
    if (failOn.contains('Channel:${channel.index}')) {
      throw StateError('fake failure for channel ${channel.index}');
    }
    appliedChannels.add(channel);
  }

  @override
  Future<void> applyOwner(mesh_pb.User owner) async {
    if (failOn.contains('Owner:long')) {
      throw StateError('fake failure for owner');
    }
    appliedOwners.add(owner);
  }

  String? _configKey(config_pb.Config c) {
    if (c.hasLora()) return 'lora';
    if (c.hasDevice()) return 'device';
    if (c.hasPosition()) return 'position';
    if (c.hasPower()) return 'power';
    if (c.hasNetwork()) return 'network';
    if (c.hasDisplay()) return 'display';
    if (c.hasBluetooth()) return 'bluetooth';
    if (c.hasSecurity()) return 'security';
    return null;
  }

  String? _moduleKey(module_pb.ModuleConfig m) {
    if (m.hasMqtt()) return 'mqtt';
    if (m.hasSerial()) return 'serial';
    if (m.hasTelemetry()) return 'telemetry';
    if (m.hasExternalNotification()) return 'externalNotification';
    if (m.hasStoreForward()) return 'storeForward';
    if (m.hasRangeTest()) return 'rangeTest';
    if (m.hasCannedMessage()) return 'cannedMessage';
    if (m.hasAmbientLighting()) return 'ambientLighting';
    if (m.hasDetectionSensor()) return 'detectionSensor';
    if (m.hasPaxcounter()) return 'paxcounter';
    return null;
  }
}
