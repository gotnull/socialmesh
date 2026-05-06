// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

import '../../generated/meshtastic/channel.pb.dart' as channel_pb;
import '../../generated/meshtastic/channel.pbenum.dart' as channel_pbenum;
import '../../generated/meshtastic/config.pb.dart' as config_pb;
import '../../generated/meshtastic/mesh.pb.dart' as mesh_pb;
import '../../models/mesh_models.dart';

/// Schema version of the device-config backup file.
///
/// Bumped only on incompatible changes. Forward-compat additions go into the
/// envelope as new optional sections; consumers ignore unknown keys.
const String kDeviceConfigBundleSchemaVersion = '1';

/// Filename extension for backup files.
const String kDeviceConfigBundleExtension = 'smcfg.json';

/// Module-config types covered by the backup envelope.
///
/// Mirrors the `oneof payload_variant` slots on `ModuleConfig` that have a
/// matching get/set admin path in [ProtocolService]. `audio`,
/// `remoteHardware`, and `neighborInfo` are intentionally not yet wired into
/// the protocol service set/cache flow — they are preserved on the wire when
/// present in the file but skipped on capture if their cache is null.
enum BundleModuleType {
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
  neighborInfo,
}

extension BundleModuleTypeKey on BundleModuleType {
  String get jsonKey {
    switch (this) {
      case BundleModuleType.mqtt:
        return 'mqtt';
      case BundleModuleType.serial:
        return 'serial';
      case BundleModuleType.externalNotification:
        return 'externalNotification';
      case BundleModuleType.storeForward:
        return 'storeForward';
      case BundleModuleType.rangeTest:
        return 'rangeTest';
      case BundleModuleType.telemetry:
        return 'telemetry';
      case BundleModuleType.cannedMessage:
        return 'cannedMessage';
      case BundleModuleType.ambientLighting:
        return 'ambientLighting';
      case BundleModuleType.detectionSensor:
        return 'detectionSensor';
      case BundleModuleType.paxcounter:
        return 'paxcounter';
      case BundleModuleType.neighborInfo:
        return 'neighborInfo';
    }
  }
}

BundleModuleType? _moduleTypeFromKey(String key) {
  for (final t in BundleModuleType.values) {
    if (t.jsonKey == key) return t;
  }
  return null;
}

/// Snapshot of a Meshtastic device's user-configurable state, suitable for
/// export to a single backup file and re-application via admin messages on a
/// fresh device.
///
/// All protobuf fields are stored as the live message instances. The JSON
/// envelope produced by [encode] base64-encodes each field's wire bytes
/// (`writeToBuffer`) so the round-trip is byte-identical to what the device
/// emits — no proto3-JSON intermediate, no risk of unknown-field loss.
///
/// The DM private key is **not** part of this bundle. It is owned by the
/// existing FlutterSecureStorage / iCloud-Keychain backup flow in
/// `security_config_screen.dart` so the file is not a single point of
/// failure for identity.
class DeviceConfigBundle {
  final String schemaVersion;
  final DateTime createdAt;
  final int? nodeNum;
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
  final Map<BundleModuleType, List<int>> moduleConfigBytes;
  final List<ChannelConfig> channels;

  DeviceConfigBundle({
    this.schemaVersion = kDeviceConfigBundleSchemaVersion,
    required this.createdAt,
    this.nodeNum,
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
    Map<BundleModuleType, List<int>>? moduleConfigBytes,
    List<ChannelConfig>? channels,
  }) : moduleConfigBytes = moduleConfigBytes ?? const {},
       channels = channels ?? const [];

  /// Convenience: returns the parsed module config for [type], or null if
  /// the bundle does not contain that module's config.
  ///
  /// The bundle stores module configs as raw wire bytes so that round-tripping
  /// preserves unknown fields. This helper decodes on demand.
  T? moduleConfigAs<T>(BundleModuleType type, T Function(List<int>) parser) {
    final bytes = moduleConfigBytes[type];
    if (bytes == null) return null;
    return parser(bytes);
  }

  /// JSON-envelope encoding. The result is a UTF-8 string suitable for
  /// writing to a `.smcfg.json` file.
  String encode({bool pretty = true}) {
    final Map<String, dynamic> sections = {};

    if (owner != null) {
      sections['owner'] = base64Encode(owner!.writeToBuffer());
    }

    final Map<String, String> configs = {};
    if (lora != null) configs['lora'] = base64Encode(lora!.writeToBuffer());
    if (device != null) {
      configs['device'] = base64Encode(device!.writeToBuffer());
    }
    if (position != null) {
      configs['position'] = base64Encode(position!.writeToBuffer());
    }
    if (power != null) configs['power'] = base64Encode(power!.writeToBuffer());
    if (network != null) {
      configs['network'] = base64Encode(network!.writeToBuffer());
    }
    if (display != null) {
      configs['display'] = base64Encode(display!.writeToBuffer());
    }
    if (bluetooth != null) {
      configs['bluetooth'] = base64Encode(bluetooth!.writeToBuffer());
    }
    if (security != null) {
      configs['security'] = base64Encode(security!.writeToBuffer());
    }
    if (configs.isNotEmpty) sections['configs'] = configs;

    if (moduleConfigBytes.isNotEmpty) {
      final Map<String, String> modules = {};
      for (final entry in moduleConfigBytes.entries) {
        modules[entry.key.jsonKey] = base64Encode(entry.value);
      }
      sections['moduleConfigs'] = modules;
    }

    if (channels.isNotEmpty) {
      sections['channels'] = channels
          .map(_channelToWire)
          .map(base64Encode)
          .toList();
    }

    final envelope = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      if (nodeNum != null) 'nodeNum': nodeNum,
      if (deviceMetadata != null) 'deviceMetadata': deviceMetadata,
      'sections': sections,
    };

    return pretty
        ? const JsonEncoder.withIndent('  ').convert(envelope)
        : jsonEncode(envelope);
  }

  /// Decodes a JSON envelope back into a [DeviceConfigBundle]. Unknown
  /// section keys are ignored (forward-compat). Throws
  /// [DeviceConfigBundleException] on malformed input or schema mismatch.
  static DeviceConfigBundle decode(String json) {
    final Object? raw;
    try {
      raw = jsonDecode(json);
    } catch (e) {
      throw DeviceConfigBundleException('Not valid JSON: $e');
    }
    if (raw is! Map<String, dynamic>) {
      throw const DeviceConfigBundleException(
        'Top-level JSON must be an object',
      );
    }

    final schemaVersion = raw['schemaVersion'];
    if (schemaVersion is! String) {
      throw const DeviceConfigBundleException('Missing schemaVersion');
    }
    if (schemaVersion != kDeviceConfigBundleSchemaVersion) {
      throw DeviceConfigBundleException(
        'Unsupported schemaVersion "$schemaVersion" '
        '(expected "$kDeviceConfigBundleSchemaVersion")',
      );
    }

    DateTime createdAt;
    final createdRaw = raw['createdAt'];
    if (createdRaw is String) {
      createdAt =
          DateTime.tryParse(createdRaw)?.toUtc() ?? DateTime.now().toUtc();
    } else {
      createdAt = DateTime.now().toUtc();
    }

    final nodeNum = raw['nodeNum'] is int ? raw['nodeNum'] as int : null;
    final deviceMetadata = raw['deviceMetadata'] is String
        ? raw['deviceMetadata'] as String
        : null;

    final sections = raw['sections'];
    if (sections is! Map<String, dynamic>) {
      return DeviceConfigBundle(
        schemaVersion: schemaVersion,
        createdAt: createdAt,
        nodeNum: nodeNum,
        deviceMetadata: deviceMetadata,
      );
    }

    mesh_pb.User? owner;
    if (sections['owner'] is String) {
      owner = mesh_pb.User.fromBuffer(
        base64Decode(sections['owner'] as String),
      );
    }

    config_pb.Config_LoRaConfig? lora;
    config_pb.Config_DeviceConfig? device;
    config_pb.Config_PositionConfig? position;
    config_pb.Config_PowerConfig? power;
    config_pb.Config_NetworkConfig? network;
    config_pb.Config_DisplayConfig? display;
    config_pb.Config_BluetoothConfig? bluetooth;
    config_pb.Config_SecurityConfig? security;

    final configs = sections['configs'];
    if (configs is Map<String, dynamic>) {
      lora = _decode(
        configs['lora'],
        (b) => config_pb.Config_LoRaConfig.fromBuffer(b),
      );
      device = _decode(
        configs['device'],
        (b) => config_pb.Config_DeviceConfig.fromBuffer(b),
      );
      position = _decode(
        configs['position'],
        (b) => config_pb.Config_PositionConfig.fromBuffer(b),
      );
      power = _decode(
        configs['power'],
        (b) => config_pb.Config_PowerConfig.fromBuffer(b),
      );
      network = _decode(
        configs['network'],
        (b) => config_pb.Config_NetworkConfig.fromBuffer(b),
      );
      display = _decode(
        configs['display'],
        (b) => config_pb.Config_DisplayConfig.fromBuffer(b),
      );
      bluetooth = _decode(
        configs['bluetooth'],
        (b) => config_pb.Config_BluetoothConfig.fromBuffer(b),
      );
      security = _decode(
        configs['security'],
        (b) => config_pb.Config_SecurityConfig.fromBuffer(b),
      );
    }

    final Map<BundleModuleType, List<int>> moduleConfigBytes = {};
    final modules = sections['moduleConfigs'];
    if (modules is Map<String, dynamic>) {
      for (final entry in modules.entries) {
        final type = _moduleTypeFromKey(entry.key);
        if (type == null) continue;
        if (entry.value is! String) continue;
        moduleConfigBytes[type] = base64Decode(entry.value as String);
      }
    }

    final List<ChannelConfig> channels = [];
    final channelsRaw = sections['channels'];
    if (channelsRaw is List) {
      for (final encoded in channelsRaw) {
        if (encoded is! String) continue;
        try {
          final wire = channel_pb.Channel.fromBuffer(base64Decode(encoded));
          channels.add(_channelFromWire(wire));
        } catch (_) {
          // Skip malformed entries — partial bundles still restore what they can.
        }
      }
    }

    return DeviceConfigBundle(
      schemaVersion: schemaVersion,
      createdAt: createdAt,
      nodeNum: nodeNum,
      deviceMetadata: deviceMetadata,
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
      channels: channels,
    );
  }

  /// Suggested filename for export. The short node ID is the lower 32 bits of
  /// [nodeNum] in hex, mirroring how Meshtastic nodes identify themselves.
  String suggestedFilename() {
    final shortId = nodeNum != null
        ? nodeNum!.toRadixString(16).padLeft(8, '0')
        : 'unknown';
    final ts = createdAt.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${ts.year}${two(ts.month)}${two(ts.day)}${two(ts.hour)}${two(ts.minute)}';
    return 'socialmesh-device-config-$shortId-$stamp.$kDeviceConfigBundleExtension';
  }

  /// Whether the bundle contains anything worth restoring.
  bool get isEmpty =>
      owner == null &&
      lora == null &&
      device == null &&
      position == null &&
      power == null &&
      network == null &&
      display == null &&
      bluetooth == null &&
      security == null &&
      moduleConfigBytes.isEmpty &&
      channels.isEmpty;
}

T? _decode<T>(Object? value, T Function(List<int>) parser) {
  if (value is! String) return null;
  try {
    return parser(base64Decode(value));
  } catch (_) {
    return null;
  }
}

/// Serialize a [ChannelConfig] (SocialMesh's flat model) to the wire-format
/// `Channel` proto. Mirrors the approach used by the channel QR sharing flow
/// in `channel_options_sheet.dart`.
List<int> _channelToWire(ChannelConfig c) {
  final settings = channel_pb.ChannelSettings()
    ..name = c.name
    ..psk = c.psk
    ..uplinkEnabled = c.uplink
    ..downlinkEnabled = c.downlink
    ..moduleSettings = (channel_pb.ModuleSettings()
      ..positionPrecision = c.positionPrecision);

  channel_pbenum.Channel_Role role;
  switch (c.role.toUpperCase()) {
    case 'PRIMARY':
      role = channel_pbenum.Channel_Role.PRIMARY;
      break;
    case 'SECONDARY':
      role = channel_pbenum.Channel_Role.SECONDARY;
      break;
    case 'DISABLED':
    default:
      role = channel_pbenum.Channel_Role.DISABLED;
      break;
  }

  final channel = channel_pb.Channel()
    ..index = c.index
    ..settings = settings
    ..role = role;
  return channel.writeToBuffer();
}

ChannelConfig _channelFromWire(channel_pb.Channel ch) {
  return ChannelConfig(
    index: ch.index,
    name: ch.settings.name,
    psk: List<int>.from(ch.settings.psk),
    uplink: ch.settings.uplinkEnabled,
    downlink: ch.settings.downlinkEnabled,
    role: ch.role.name,
    positionPrecision: ch.settings.moduleSettings.positionPrecision,
  );
}

class DeviceConfigBundleException implements Exception {
  final String message;
  const DeviceConfigBundleException(this.message);

  @override
  String toString() => 'DeviceConfigBundleException: $message';
}
