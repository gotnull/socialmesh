// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import '../../generated/meshtastic/admin.pbenum.dart' as admin_enum;
import '../../generated/meshtastic/config.pb.dart' as config_pb;
import '../../generated/meshtastic/mesh.pb.dart' as mesh_pb;
import '../../generated/meshtastic/module_config.pb.dart' as module_pb;
import '../../models/mesh_models.dart';
import '../protocol/protocol_service.dart';
import 'device_config_bundle.dart';

/// User-selected sections to apply during a restore.
///
/// All sections default to false so callers must opt in explicitly. The
/// confirmation sheet preselects sensible defaults (channels + radio
/// settings) and reflects whatever toggles the user touches.
class RestoreSelection {
  final bool channels;
  final bool owner;
  final bool radio;
  final bool modules;

  const RestoreSelection({
    this.channels = false,
    this.owner = false,
    this.radio = false,
    this.modules = false,
  });

  bool get any => channels || owner || radio || modules;

  RestoreSelection copyWith({
    bool? channels,
    bool? owner,
    bool? radio,
    bool? modules,
  }) {
    return RestoreSelection(
      channels: channels ?? this.channels,
      owner: owner ?? this.owner,
      radio: radio ?? this.radio,
      modules: modules ?? this.modules,
    );
  }
}

/// Result of a restore operation. [applied] holds section keys that the
/// gateway accepted (transport.send returned without throwing). [failed]
/// maps section keys to the error message. [skipped] holds keys the user
/// opted out of, or that were absent from the bundle.
///
/// Section keys: `owner`, `lora`, `device`, `position`, `power`, `network`,
/// `display`, `bluetooth`, `security`, `module:<name>`, `channel:<index>`.
class RestoreReport {
  final List<String> applied = [];
  final Map<String, String> failed = {};
  final List<String> skipped = [];

  bool get hasFailures => failed.isNotEmpty;
  int get appliedCount => applied.length;
}

/// Result of a capture operation.
class DeviceConfigCapture {
  final DeviceConfigBundle bundle;

  /// Section keys that were null in the cache and did not arrive within the
  /// refresh timeout. Surfaced to the UI so the user knows the bundle is
  /// partial — usually means the device hasn't sent that config since boot.
  final List<String> missingSections;

  const DeviceConfigCapture({
    required this.bundle,
    this.missingSections = const [],
  });
}

/// Logical config sections used for refresh-on-null lookups.
enum DeviceConfigSection {
  owner,
  lora,
  device,
  position,
  power,
  network,
  display,
  bluetooth,
  security,
  mqtt,
  serial,
  externalNotification,
  storeForward,
  rangeTest,
  telemetry,
  cannedMessage,
  ambientLighting,
  detectionSensor,
  paxcounter,
}

/// Plain-data snapshot of every currently-cached config field on the
/// connected device. Built by the gateway in a single read so capture stays
/// consistent.
class DeviceConfigSnapshot {
  final int? myNodeNum;
  final String? deviceMetadata;
  final mesh_pb.User? owner;
  final config_pb.Config_LoRaConfig? lora;
  final config_pb.Config_DeviceConfig? device;
  final config_pb.Config_PositionConfig? position;
  final config_pb.Config_PowerConfig? power;
  final config_pb.Config_NetworkConfig? network;
  final config_pb.Config_DisplayConfig? display;
  final config_pb.Config_BluetoothConfig? bluetooth;
  final config_pb.Config_SecurityConfig? security;
  final module_pb.ModuleConfig_MQTTConfig? mqtt;
  final module_pb.ModuleConfig_SerialConfig? serial;
  final module_pb.ModuleConfig_ExternalNotificationConfig? externalNotification;
  final module_pb.ModuleConfig_StoreForwardConfig? storeForward;
  final module_pb.ModuleConfig_RangeTestConfig? rangeTest;
  final module_pb.ModuleConfig_TelemetryConfig? telemetry;
  final module_pb.ModuleConfig_CannedMessageConfig? cannedMessage;
  final module_pb.ModuleConfig_AmbientLightingConfig? ambientLighting;
  final module_pb.ModuleConfig_DetectionSensorConfig? detectionSensor;
  final module_pb.ModuleConfig_PaxcounterConfig? paxcounter;
  final List<ChannelConfig> channels;

  const DeviceConfigSnapshot({
    this.myNodeNum,
    this.deviceMetadata,
    this.owner,
    this.lora,
    this.device,
    this.position,
    this.power,
    this.network,
    this.display,
    this.bluetooth,
    this.security,
    this.mqtt,
    this.serial,
    this.externalNotification,
    this.storeForward,
    this.rangeTest,
    this.telemetry,
    this.cannedMessage,
    this.ambientLighting,
    this.detectionSensor,
    this.paxcounter,
    this.channels = const [],
  });
}

/// Gateway interface for [DeviceConfigBackupService]. Production code uses
/// [ProtocolServiceBackupGateway]; tests use an in-memory fake.
///
/// All methods that talk to the wire are async — they complete when the
/// transport has accepted the bytes, not when the device has applied the
/// change. [waitForSection] is the way to confirm a section actually came
/// back from the device.
abstract class DeviceConfigBackupGateway {
  DeviceConfigSnapshot snapshot();
  Future<void> refresh(DeviceConfigSection section);
  Future<bool> waitForSection(DeviceConfigSection section, Duration timeout);
  Future<void> applyConfig(config_pb.Config config);
  Future<void> applyModuleConfig(module_pb.ModuleConfig moduleConfig);
  Future<void> applyChannel(ChannelConfig channel);
  Future<void> applyOwner(mesh_pb.User owner);
}

/// Production gateway backed by [ProtocolService].
class ProtocolServiceBackupGateway implements DeviceConfigBackupGateway {
  final ProtocolService protocol;

  /// Live channel list from `channelsProvider`. The protocol service has
  /// `protocol.channels` as well, but the provider's view filters out
  /// DISABLED slots (except index 0) which is what backups should reflect.
  final List<ChannelConfig> Function() channelsRead;

  ProtocolServiceBackupGateway(this.protocol, this.channelsRead);

  @override
  DeviceConfigSnapshot snapshot() {
    return DeviceConfigSnapshot(
      myNodeNum: protocol.myNodeNum,
      owner: protocol.currentUserConfig,
      lora: protocol.currentLoraConfig,
      device: protocol.currentDeviceConfig,
      position: protocol.currentPositionConfig,
      power: protocol.currentPowerConfig,
      network: protocol.currentNetworkConfig,
      display: protocol.currentDisplayConfig,
      bluetooth: protocol.currentBluetoothConfig,
      security: protocol.currentSecurityConfig,
      mqtt: protocol.currentMqttConfig,
      serial: protocol.currentSerialConfig,
      externalNotification: protocol.currentExternalNotificationConfig,
      storeForward: protocol.currentStoreForwardConfig,
      rangeTest: protocol.currentRangeTestConfig,
      telemetry: protocol.currentTelemetryConfig,
      cannedMessage: protocol.currentCannedMessageConfig,
      ambientLighting: protocol.currentAmbientLightingConfig,
      detectionSensor: protocol.currentDetectionSensorConfig,
      paxcounter: protocol.currentPaxCounterConfig,
      channels: channelsRead(),
    );
  }

  @override
  Future<void> refresh(DeviceConfigSection section) async {
    switch (section) {
      case DeviceConfigSection.owner:
        // No dedicated getOwnerRequest in ProtocolService; owner arrives in
        // the boot config flow. Fall through.
        return;
      case DeviceConfigSection.lora:
        return protocol.getConfig(
          admin_enum.AdminMessage_ConfigType.LORA_CONFIG,
        );
      case DeviceConfigSection.device:
        return protocol.getConfig(
          admin_enum.AdminMessage_ConfigType.DEVICE_CONFIG,
        );
      case DeviceConfigSection.position:
        return protocol.getConfig(
          admin_enum.AdminMessage_ConfigType.POSITION_CONFIG,
        );
      case DeviceConfigSection.power:
        return protocol.getConfig(
          admin_enum.AdminMessage_ConfigType.POWER_CONFIG,
        );
      case DeviceConfigSection.network:
        return protocol.getConfig(
          admin_enum.AdminMessage_ConfigType.NETWORK_CONFIG,
        );
      case DeviceConfigSection.display:
        return protocol.getConfig(
          admin_enum.AdminMessage_ConfigType.DISPLAY_CONFIG,
        );
      case DeviceConfigSection.bluetooth:
        return protocol.getConfig(
          admin_enum.AdminMessage_ConfigType.BLUETOOTH_CONFIG,
        );
      case DeviceConfigSection.security:
        return protocol.getConfig(
          admin_enum.AdminMessage_ConfigType.SECURITY_CONFIG,
        );
      case DeviceConfigSection.mqtt:
        return protocol.getModuleConfig(
          admin_enum.AdminMessage_ModuleConfigType.MQTT_CONFIG,
        );
      case DeviceConfigSection.serial:
        return protocol.getModuleConfig(
          admin_enum.AdminMessage_ModuleConfigType.SERIAL_CONFIG,
        );
      case DeviceConfigSection.externalNotification:
        return protocol.getModuleConfig(
          admin_enum.AdminMessage_ModuleConfigType.EXTNOTIF_CONFIG,
        );
      case DeviceConfigSection.storeForward:
        return protocol.getModuleConfig(
          admin_enum.AdminMessage_ModuleConfigType.STOREFORWARD_CONFIG,
        );
      case DeviceConfigSection.rangeTest:
        return protocol.getModuleConfig(
          admin_enum.AdminMessage_ModuleConfigType.RANGETEST_CONFIG,
        );
      case DeviceConfigSection.telemetry:
        return protocol.getModuleConfig(
          admin_enum.AdminMessage_ModuleConfigType.TELEMETRY_CONFIG,
        );
      case DeviceConfigSection.cannedMessage:
        return protocol.getModuleConfig(
          admin_enum.AdminMessage_ModuleConfigType.CANNEDMSG_CONFIG,
        );
      case DeviceConfigSection.ambientLighting:
        return protocol.getModuleConfig(
          admin_enum.AdminMessage_ModuleConfigType.AMBIENTLIGHTING_CONFIG,
        );
      case DeviceConfigSection.detectionSensor:
        return protocol.getModuleConfig(
          admin_enum.AdminMessage_ModuleConfigType.DETECTIONSENSOR_CONFIG,
        );
      case DeviceConfigSection.paxcounter:
        return protocol.getModuleConfig(
          admin_enum.AdminMessage_ModuleConfigType.PAXCOUNTER_CONFIG,
        );
    }
  }

  @override
  Future<bool> waitForSection(
    DeviceConfigSection section,
    Duration timeout,
  ) async {
    final stream = _streamFor(section);
    if (stream == null) return false;
    try {
      await stream.first.timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Stream? _streamFor(DeviceConfigSection s) {
    switch (s) {
      case DeviceConfigSection.owner:
        return protocol.userConfigStream;
      case DeviceConfigSection.lora:
        return protocol.loraConfigStream;
      case DeviceConfigSection.device:
        return protocol.deviceConfigStream;
      case DeviceConfigSection.position:
        return protocol.positionConfigStream;
      case DeviceConfigSection.power:
        return protocol.powerConfigStream;
      case DeviceConfigSection.network:
        return protocol.networkConfigStream;
      case DeviceConfigSection.display:
        return protocol.displayConfigStream;
      case DeviceConfigSection.bluetooth:
        return protocol.bluetoothConfigStream;
      case DeviceConfigSection.security:
        return protocol.securityConfigStream;
      case DeviceConfigSection.mqtt:
        return protocol.mqttConfigStream;
      case DeviceConfigSection.serial:
        return protocol.serialConfigStream;
      case DeviceConfigSection.externalNotification:
        return protocol.externalNotificationConfigStream;
      case DeviceConfigSection.storeForward:
        return protocol.storeForwardConfigStream;
      case DeviceConfigSection.rangeTest:
        return protocol.rangeTestConfigStream;
      case DeviceConfigSection.telemetry:
        return protocol.telemetryConfigStream;
      case DeviceConfigSection.cannedMessage:
        return protocol.cannedMessageConfigStream;
      case DeviceConfigSection.ambientLighting:
        return protocol.ambientLightingConfigStream;
      case DeviceConfigSection.detectionSensor:
        return protocol.detectionSensorConfigStream;
      case DeviceConfigSection.paxcounter:
        return protocol.paxCounterConfigStream;
    }
  }

  @override
  Future<void> applyConfig(config_pb.Config config) =>
      protocol.setConfig(config);

  @override
  Future<void> applyModuleConfig(module_pb.ModuleConfig moduleConfig) =>
      protocol.setModuleConfig(moduleConfig);

  @override
  Future<void> applyChannel(ChannelConfig channel) =>
      protocol.setChannel(channel);

  @override
  Future<void> applyOwner(mesh_pb.User owner) async {
    await protocol.setOwnerConfig(
      longName: owner.longName,
      shortName: owner.shortName,
      isUnmessagable: owner.hasIsUnmessagable() ? owner.isUnmessagable : null,
      isLicensed: owner.isLicensed,
    );
  }
}

/// Orchestrates capturing and restoring a [DeviceConfigBundle] against a
/// connected Meshtastic device.
///
/// Capture reads from the protocol service's cached config snapshot; for any
/// section that's null it fires the matching `get*` admin request and waits
/// up to [refreshTimeout] for the corresponding stream to emit. Sections
/// that don't respond within the timeout are reported in
/// [DeviceConfigCapture.missingSections] but the bundle is still returned —
/// partial backups are better than no backup.
///
/// Restore applies sections sequentially via the gateway. Each section is
/// independent: a failure on one (e.g. `setConfig` for `lora`) does not
/// stop the rest. Channels are written one at a time with a short pacing
/// gap because the firmware admin queue is shallow.
///
/// Restore note: each `setConfig` admin write triggers a device reboot.
/// Sending several in close succession typically lets the firmware queue
/// them and reboot once at the end, but the BLE link will drop and the
/// reconnect flow will take over. The report reflects what the transport
/// accepted, not what the device finished applying.
class DeviceConfigBackupService {
  final DeviceConfigBackupGateway gateway;
  final Duration refreshTimeout;
  final Duration channelGap;

  DeviceConfigBackupService({
    required this.gateway,
    this.refreshTimeout = const Duration(seconds: 8),
    this.channelGap = const Duration(milliseconds: 300),
  });

  /// Capture a [DeviceConfigBundle] from the gateway's current cache, with
  /// per-section refresh-and-await for any null entries.
  Future<DeviceConfigCapture> capture() async {
    final missing = <String>[];
    final initial = gateway.snapshot();

    Future<T?> resolve<T>(
      DeviceConfigSection section,
      T? cached,
      T? Function(DeviceConfigSnapshot) reader,
    ) async {
      if (cached != null) return cached;
      try {
        await gateway.refresh(section);
      } catch (_) {
        missing.add(section.name);
        return null;
      }
      final ok = await gateway.waitForSection(section, refreshTimeout);
      if (!ok) {
        missing.add(section.name);
        return null;
      }
      return reader(gateway.snapshot());
    }

    // Start every section resolution up front so unanswered sections time
    // out concurrently rather than in sequence. A radio that answers none
    // of the admin gets (seen in the field on 2.8.0 alpha firmware) used to
    // hold the spinner for sections-times-timeout - minutes - which reads
    // as a hang; concurrent resolution bounds the whole capture at roughly
    // one refresh timeout. The get requests themselves are fire-and-forget
    // one-packet admin sends, serialised by the transport, so starting them
    // together does not change what reaches the radio.
    final ownerF = resolve(
      DeviceConfigSection.owner,
      initial.owner,
      (s) => s.owner,
    );
    final loraF = resolve(
      DeviceConfigSection.lora,
      initial.lora,
      (s) => s.lora,
    );
    final deviceF = resolve(
      DeviceConfigSection.device,
      initial.device,
      (s) => s.device,
    );
    final positionF = resolve(
      DeviceConfigSection.position,
      initial.position,
      (s) => s.position,
    );
    final powerF = resolve(
      DeviceConfigSection.power,
      initial.power,
      (s) => s.power,
    );
    final networkF = resolve(
      DeviceConfigSection.network,
      initial.network,
      (s) => s.network,
    );
    final displayF = resolve(
      DeviceConfigSection.display,
      initial.display,
      (s) => s.display,
    );
    final bluetoothF = resolve(
      DeviceConfigSection.bluetooth,
      initial.bluetooth,
      (s) => s.bluetooth,
    );
    final securityF = resolve(
      DeviceConfigSection.security,
      initial.security,
      (s) => s.security,
    );
    final mqttF = resolve(
      DeviceConfigSection.mqtt,
      initial.mqtt,
      (s) => s.mqtt,
    );
    final serialF = resolve(
      DeviceConfigSection.serial,
      initial.serial,
      (s) => s.serial,
    );
    final extNotifF = resolve(
      DeviceConfigSection.externalNotification,
      initial.externalNotification,
      (s) => s.externalNotification,
    );
    final storeForwardF = resolve(
      DeviceConfigSection.storeForward,
      initial.storeForward,
      (s) => s.storeForward,
    );
    final rangeTestF = resolve(
      DeviceConfigSection.rangeTest,
      initial.rangeTest,
      (s) => s.rangeTest,
    );
    final telemetryF = resolve(
      DeviceConfigSection.telemetry,
      initial.telemetry,
      (s) => s.telemetry,
    );
    final cannedMsgF = resolve(
      DeviceConfigSection.cannedMessage,
      initial.cannedMessage,
      (s) => s.cannedMessage,
    );
    final ambientLightingF = resolve(
      DeviceConfigSection.ambientLighting,
      initial.ambientLighting,
      (s) => s.ambientLighting,
    );
    final detectionSensorF = resolve(
      DeviceConfigSection.detectionSensor,
      initial.detectionSensor,
      (s) => s.detectionSensor,
    );
    final paxcounterF = resolve(
      DeviceConfigSection.paxcounter,
      initial.paxcounter,
      (s) => s.paxcounter,
    );

    final owner = await ownerF;
    final lora = await loraF;
    final device = await deviceF;
    final position = await positionF;
    final power = await powerF;
    final network = await networkF;
    final display = await displayF;
    final bluetooth = await bluetoothF;
    final security = await securityF;
    final mqtt = await mqttF;
    final serial = await serialF;
    final extNotif = await extNotifF;
    final storeForward = await storeForwardF;
    final rangeTest = await rangeTestF;
    final telemetry = await telemetryF;
    final cannedMsg = await cannedMsgF;
    final ambientLighting = await ambientLightingF;
    final detectionSensor = await detectionSensorF;
    final paxcounter = await paxcounterF;

    final moduleConfigBytes = <BundleModuleType, List<int>>{};
    void addModule<T>(
      BundleModuleType key,
      T? value,
      List<int> Function(T) ser,
    ) {
      if (value != null) moduleConfigBytes[key] = ser(value);
    }

    addModule(BundleModuleType.mqtt, mqtt, (v) => v.writeToBuffer());
    addModule(BundleModuleType.serial, serial, (v) => v.writeToBuffer());
    addModule(
      BundleModuleType.externalNotification,
      extNotif,
      (v) => v.writeToBuffer(),
    );
    addModule(
      BundleModuleType.storeForward,
      storeForward,
      (v) => v.writeToBuffer(),
    );
    addModule(BundleModuleType.rangeTest, rangeTest, (v) => v.writeToBuffer());
    addModule(BundleModuleType.telemetry, telemetry, (v) => v.writeToBuffer());
    addModule(
      BundleModuleType.cannedMessage,
      cannedMsg,
      (v) => v.writeToBuffer(),
    );
    addModule(
      BundleModuleType.ambientLighting,
      ambientLighting,
      (v) => v.writeToBuffer(),
    );
    addModule(
      BundleModuleType.detectionSensor,
      detectionSensor,
      (v) => v.writeToBuffer(),
    );
    addModule(
      BundleModuleType.paxcounter,
      paxcounter,
      (v) => v.writeToBuffer(),
    );

    final bundle = DeviceConfigBundle(
      createdAt: DateTime.now().toUtc(),
      nodeNum: initial.myNodeNum,
      deviceMetadata: initial.deviceMetadata,
      owner: owner,
      lora: lora,
      device: device,
      position: position,
      power: power,
      network: network,
      display: display,
      bluetooth: bluetooth,
      security: security,
      moduleConfigBytes: moduleConfigBytes,
      channels: List<ChannelConfig>.from(initial.channels),
    );

    return DeviceConfigCapture(bundle: bundle, missingSections: missing);
  }

  /// Apply a [DeviceConfigBundle] back to the connected device, scoped by
  /// [selection]. Returns a [RestoreReport] summarising what the transport
  /// accepted and what failed.
  Future<RestoreReport> restore(
    DeviceConfigBundle bundle,
    RestoreSelection selection,
  ) async {
    final report = RestoreReport();

    Future<void> trySection(String key, Future<void> Function() body) async {
      try {
        await body();
        report.applied.add(key);
      } catch (e) {
        report.failed[key] = e.toString();
      }
    }

    // Owner first — minimally invasive (no reboot required for setOwner).
    if (selection.owner) {
      if (bundle.owner != null) {
        await trySection('owner', () => gateway.applyOwner(bundle.owner!));
      } else {
        report.skipped.add('owner');
      }
    }

    // Radio: lora + the rest of the device-level configs.
    if (selection.radio) {
      if (bundle.lora != null) {
        await trySection(
          'lora',
          () => gateway.applyConfig(config_pb.Config()..lora = bundle.lora!),
        );
      } else {
        report.skipped.add('lora');
      }
      if (bundle.device != null) {
        await trySection(
          'device',
          () =>
              gateway.applyConfig(config_pb.Config()..device = bundle.device!),
        );
      } else {
        report.skipped.add('device');
      }
      if (bundle.position != null) {
        await trySection(
          'position',
          () => gateway.applyConfig(
            config_pb.Config()..position = bundle.position!,
          ),
        );
      } else {
        report.skipped.add('position');
      }
      if (bundle.power != null) {
        await trySection(
          'power',
          () => gateway.applyConfig(config_pb.Config()..power = bundle.power!),
        );
      } else {
        report.skipped.add('power');
      }
      if (bundle.network != null) {
        await trySection(
          'network',
          () => gateway.applyConfig(
            config_pb.Config()..network = bundle.network!,
          ),
        );
      } else {
        report.skipped.add('network');
      }
      if (bundle.display != null) {
        await trySection(
          'display',
          () => gateway.applyConfig(
            config_pb.Config()..display = bundle.display!,
          ),
        );
      } else {
        report.skipped.add('display');
      }
      if (bundle.bluetooth != null) {
        await trySection(
          'bluetooth',
          () => gateway.applyConfig(
            config_pb.Config()..bluetooth = bundle.bluetooth!,
          ),
        );
      } else {
        report.skipped.add('bluetooth');
      }
      // Note: SecurityConfig is the device's *security* config (admin keys,
      // managed mode, etc.) — distinct from the DM private key. We don't
      // restore it by default because applying admin-key changes against an
      // un-paired device can lock the user out. Always skipped for now;
      // surface in a future "advanced" toggle if requested.
      if (bundle.security != null) {
        report.skipped.add('security');
      }
    }

    // Module configs.
    if (selection.modules) {
      for (final entry in bundle.moduleConfigBytes.entries) {
        final key = 'module:${entry.key.jsonKey}';
        try {
          final mc = _moduleConfigFromBytes(entry.key, entry.value);
          if (mc == null) {
            report.failed[key] = 'unsupported module type';
            continue;
          }
          await gateway.applyModuleConfig(mc);
          report.applied.add(key);
        } catch (e) {
          report.failed[key] = e.toString();
        }
      }
    }

    // Channels last — each is its own admin send + 300ms gap so the
    // firmware admin queue isn't overrun. setChannel internally also does
    // a getChannel verify, so the gap is conservative.
    if (selection.channels) {
      for (final channel in bundle.channels) {
        final key = 'channel:${channel.index}';
        try {
          await gateway.applyChannel(channel);
          report.applied.add(key);
        } catch (e) {
          report.failed[key] = e.toString();
        }
        await Future<void>.delayed(channelGap);
      }
    }

    return report;
  }

  module_pb.ModuleConfig? _moduleConfigFromBytes(
    BundleModuleType type,
    List<int> bytes,
  ) {
    final mc = module_pb.ModuleConfig();
    switch (type) {
      case BundleModuleType.mqtt:
        mc.mqtt = module_pb.ModuleConfig_MQTTConfig.fromBuffer(bytes);
        return mc;
      case BundleModuleType.serial:
        mc.serial = module_pb.ModuleConfig_SerialConfig.fromBuffer(bytes);
        return mc;
      case BundleModuleType.externalNotification:
        mc.externalNotification =
            module_pb.ModuleConfig_ExternalNotificationConfig.fromBuffer(bytes);
        return mc;
      case BundleModuleType.storeForward:
        mc.storeForward = module_pb.ModuleConfig_StoreForwardConfig.fromBuffer(
          bytes,
        );
        return mc;
      case BundleModuleType.rangeTest:
        mc.rangeTest = module_pb.ModuleConfig_RangeTestConfig.fromBuffer(bytes);
        return mc;
      case BundleModuleType.telemetry:
        mc.telemetry = module_pb.ModuleConfig_TelemetryConfig.fromBuffer(bytes);
        return mc;
      case BundleModuleType.cannedMessage:
        mc.cannedMessage =
            module_pb.ModuleConfig_CannedMessageConfig.fromBuffer(bytes);
        return mc;
      case BundleModuleType.ambientLighting:
        mc.ambientLighting =
            module_pb.ModuleConfig_AmbientLightingConfig.fromBuffer(bytes);
        return mc;
      case BundleModuleType.detectionSensor:
        mc.detectionSensor =
            module_pb.ModuleConfig_DetectionSensorConfig.fromBuffer(bytes);
        return mc;
      case BundleModuleType.paxcounter:
        mc.paxcounter = module_pb.ModuleConfig_PaxcounterConfig.fromBuffer(
          bytes,
        );
        return mc;
      case BundleModuleType.neighborInfo:
        mc.neighborInfo = module_pb.ModuleConfig_NeighborInfoConfig.fromBuffer(
          bytes,
        );
        return mc;
    }
  }
}
