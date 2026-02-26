// SPDX-License-Identifier: GPL-3.0-or-later

/// Tests for remote administration data integrity.
///
/// These tests verify that:
/// - Config responses from remote nodes do not pollute local cached state
/// - setDeviceConfig does not clone local cache as base for remote targets
/// - Device metadata responses are routed to the correct node entry
/// - Config stream listeners do not overwrite remote-sourced values
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/admin.pb.dart' as admin;
import 'package:socialmesh/generated/meshtastic/config.pb.dart' as config_pb;
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart'
    as config_pbenum;
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/mesh.pbenum.dart' as pbenum;
import 'package:socialmesh/generated/meshtastic/module_config.pb.dart'
    as module_pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/services/protocol/admin_target.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

// =============================================================================
// Test doubles
// =============================================================================

/// Transport that captures sent bytes and allows injecting incoming packets.
class _TestTransport implements DeviceTransport {
  final List<List<int>> sentBytes = [];
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  DeviceConnectionState get state => DeviceConnectionState.connected;

  @override
  bool get isConnected => true;

  @override
  Stream<DeviceConnectionState> get stateStream => const Stream.empty();

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();

  @override
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(List<int> data) async {
    sentBytes.add(data);
  }

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  String? get bleModelNumber => null;

  @override
  String? get bleManufacturerName => null;

  @override
  Future<void> dispose() async {
    await _dataController.close();
  }

  /// Decode the last sent bytes as a ToRadio and extract the MeshPacket.
  pb.MeshPacket get lastPacket {
    final toRadio = pb.ToRadio.fromBuffer(sentBytes.last);
    return toRadio.packet;
  }

  /// Decode the admin message from the last sent packet.
  admin.AdminMessage get lastAdminMessage {
    final packet = lastPacket;
    return admin.AdminMessage.fromBuffer(packet.decoded.payload);
  }

  void clear() => sentBytes.clear();
}

const _myNodeNum = 0xAABBCCDD;
const _remoteNodeNum = 0x12345678;

/// Prime the protocol service with a myNodeNum.
Future<void> _primeNodeNum(ProtocolService protocol) async {
  final myInfo = pb.MyNodeInfo()..myNodeNum = _myNodeNum;
  final fromRadio = pb.FromRadio()..myInfo = myInfo;
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
  await Future<void>.delayed(Duration.zero);
}

/// Inject a config response into the protocol service as if it came from
/// [fromNodeNum].
Future<void> _injectConfigResponse(
  ProtocolService protocol,
  int fromNodeNum,
  config_pb.Config config,
) async {
  final adminMsg = admin.AdminMessage()..getConfigResponse = config;

  final data = pb.Data()
    ..portnum = pn.PortNum.ADMIN_APP
    ..payload = adminMsg.writeToBuffer();

  final packet = pb.MeshPacket()
    ..from = fromNodeNum
    ..to = _myNodeNum
    ..decoded = data
    ..id = 12345;

  final fromRadio = pb.FromRadio()..packet = packet;
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
  await Future<void>.delayed(Duration.zero);
}

/// Inject a device metadata response as if it came from [fromNodeNum].
Future<void> _injectMetadataResponse(
  ProtocolService protocol,
  int fromNodeNum, {
  required String firmwareVersion,
  pb.HardwareModel hwModel = pb.HardwareModel.HELTEC_V3,
  bool hasWifi = false,
  bool hasBluetooth = true,
}) async {
  final metadata = pb.DeviceMetadata()
    ..firmwareVersion = firmwareVersion
    ..hwModel = hwModel
    ..hasWifi = hasWifi
    ..hasBluetooth = hasBluetooth;

  final adminMsg = admin.AdminMessage()..getDeviceMetadataResponse = metadata;

  final data = pb.Data()
    ..portnum = pn.PortNum.ADMIN_APP
    ..payload = adminMsg.writeToBuffer();

  final packet = pb.MeshPacket()
    ..from = fromNodeNum
    ..to = _myNodeNum
    ..decoded = data
    ..id = 99999;

  final fromRadio = pb.FromRadio()..packet = packet;
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
  await Future<void>.delayed(Duration.zero);
}

/// Inject a NodeInfo so that the protocol service knows about a node.
Future<void> _injectNodeInfo(
  ProtocolService protocol,
  int nodeNum, {
  required String longName,
  required String shortName,
}) async {
  final user = pb.User()
    ..id = '!${nodeNum.toRadixString(16)}'
    ..longName = longName
    ..shortName = shortName;

  final nodeInfo = pb.NodeInfo()
    ..num = nodeNum
    ..user = user;

  final fromRadio = pb.FromRadio()..nodeInfo = nodeInfo;
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late _TestTransport transport;
  late ProtocolService protocol;

  setUp(() async {
    transport = _TestTransport();
    protocol = ProtocolService(transport);
    await _primeNodeNum(protocol);
  });

  tearDown(() async {
    await transport.dispose();
    protocol.dispose();
  });

  // ===========================================================================
  // setDeviceConfig: local cache isolation for remote targets
  // ===========================================================================

  group('setDeviceConfig: local cache isolation', () {
    test('remote target does not clone local cached config as base', () async {
      // 1. Inject a local device config response to populate the cache.
      //    Set serialEnabled=true as a marker field.
      final localDeviceConfig = config_pb.Config_DeviceConfig()
        ..role = config_pbenum.Config_DeviceConfig_Role.ROUTER
        ..serialEnabled = true
        ..nodeInfoBroadcastSecs = 1800
        ..ledHeartbeatDisabled = true;

      final localConfig = config_pb.Config()..device = localDeviceConfig;
      await _injectConfigResponse(protocol, _myNodeNum, localConfig);

      // Verify local cache is populated
      expect(protocol.currentDeviceConfig, isNotNull);
      expect(protocol.currentDeviceConfig!.serialEnabled, isTrue);
      expect(
        protocol.currentDeviceConfig!.role,
        config_pbenum.Config_DeviceConfig_Role.ROUTER,
      );

      // 2. Send setDeviceConfig to REMOTE target with serialEnabled=false
      transport.clear();
      await protocol.setDeviceConfig(
        role: config_pbenum.Config_DeviceConfig_Role.CLIENT,
        rebroadcastMode: config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
        serialEnabled: false,
        nodeInfoBroadcastSecs: 900,
        ledHeartbeatDisabled: false,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      // 3. Decode the sent packet and verify it was built from scratch
      //    (not cloned from local cache).
      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.hasSetConfig(), isTrue);
      final sentDeviceConfig = adminMsg.setConfig.device;

      // The explicitly set fields should be correct
      expect(
        sentDeviceConfig.role,
        config_pbenum.Config_DeviceConfig_Role.CLIENT,
      );
      expect(sentDeviceConfig.serialEnabled, isFalse);
      expect(sentDeviceConfig.nodeInfoBroadcastSecs, 900);
      expect(sentDeviceConfig.ledHeartbeatDisabled, isFalse);

      // 4. Verify local cache was NOT modified
      expect(protocol.currentDeviceConfig!.serialEnabled, isTrue);
      expect(
        protocol.currentDeviceConfig!.role,
        config_pbenum.Config_DeviceConfig_Role.ROUTER,
      );
    });

    test(
      'local target clones cached config to preserve unknown fields',
      () async {
        // 1. Inject local device config with a known state
        final localDeviceConfig = config_pb.Config_DeviceConfig()
          ..role = config_pbenum.Config_DeviceConfig_Role.ROUTER
          ..serialEnabled = true
          ..nodeInfoBroadcastSecs = 1800;

        final localConfig = config_pb.Config()..device = localDeviceConfig;
        await _injectConfigResponse(protocol, _myNodeNum, localConfig);

        // 2. Send setDeviceConfig locally, changing only the role
        transport.clear();
        await protocol.setDeviceConfig(
          role: config_pbenum.Config_DeviceConfig_Role.CLIENT,
          rebroadcastMode:
              config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
          serialEnabled: true,
          nodeInfoBroadcastSecs: 1800,
          ledHeartbeatDisabled: false,
          target: const AdminTarget.local(),
        );

        // 3. Verify the packet was sent correctly
        final adminMsg = transport.lastAdminMessage;
        final sentConfig = adminMsg.setConfig.device;
        expect(sentConfig.role, config_pbenum.Config_DeviceConfig_Role.CLIENT);
        // serialEnabled should be preserved from clone
        expect(sentConfig.serialEnabled, isTrue);
      },
    );

    test('local target with no cached config builds from scratch', () async {
      // No config injected — cache is empty
      expect(protocol.currentDeviceConfig, isNull);

      transport.clear();
      await protocol.setDeviceConfig(
        role: config_pbenum.Config_DeviceConfig_Role.CLIENT,
        rebroadcastMode: config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
        serialEnabled: false,
        nodeInfoBroadcastSecs: 900,
        ledHeartbeatDisabled: false,
      );

      final adminMsg = transport.lastAdminMessage;
      final sentConfig = adminMsg.setConfig.device;
      expect(sentConfig.role, config_pbenum.Config_DeviceConfig_Role.CLIENT);
      expect(sentConfig.serialEnabled, isFalse);
    });

    test('null target uses local path and clones cache', () async {
      // Inject local config
      final localDeviceConfig = config_pb.Config_DeviceConfig()
        ..role = config_pbenum.Config_DeviceConfig_Role.REPEATER
        ..serialEnabled = true;

      final localConfig = config_pb.Config()..device = localDeviceConfig;
      await _injectConfigResponse(protocol, _myNodeNum, localConfig);

      transport.clear();
      await protocol.setDeviceConfig(
        role: config_pbenum.Config_DeviceConfig_Role.CLIENT,
        rebroadcastMode: config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
        serialEnabled: true,
        nodeInfoBroadcastSecs: 900,
        ledHeartbeatDisabled: false,
        // target: null (default) => local
      );

      // Packet should be self-addressed (local)
      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  // ===========================================================================
  // setConfig: local cache protection
  // ===========================================================================

  group('setConfig: local cache protection', () {
    test('remote target does not update local cache', () async {
      // Inject initial local config
      final initialConfig = config_pb.Config_DeviceConfig()
        ..role = config_pbenum.Config_DeviceConfig_Role.CLIENT;
      final initial = config_pb.Config()..device = initialConfig;
      await _injectConfigResponse(protocol, _myNodeNum, initial);
      expect(
        protocol.currentDeviceConfig!.role,
        config_pbenum.Config_DeviceConfig_Role.CLIENT,
      );

      // Send config to remote target with different role
      transport.clear();
      final remoteConfig = config_pb.Config_DeviceConfig()
        ..role = config_pbenum.Config_DeviceConfig_Role.ROUTER;
      await protocol.setConfig(
        config_pb.Config()..device = remoteConfig,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      // Local cache should still have CLIENT, not ROUTER
      expect(
        protocol.currentDeviceConfig!.role,
        config_pbenum.Config_DeviceConfig_Role.CLIENT,
      );
    });

    test('local target updates local cache immediately', () async {
      final newConfig = config_pb.Config_DeviceConfig()
        ..role = config_pbenum.Config_DeviceConfig_Role.ROUTER;
      await protocol.setConfig(
        config_pb.Config()..device = newConfig,
        target: const AdminTarget.local(),
      );

      expect(
        protocol.currentDeviceConfig!.role,
        config_pbenum.Config_DeviceConfig_Role.ROUTER,
      );
    });
  });

  // ===========================================================================
  // _handleAdminMessage: config response source isolation
  // ===========================================================================

  group('Config response source isolation', () {
    test('local config response updates local cache', () async {
      final deviceConfig = config_pb.Config_DeviceConfig()
        ..role = config_pbenum.Config_DeviceConfig_Role.ROUTER
        ..serialEnabled = true;

      final config = config_pb.Config()..device = deviceConfig;
      await _injectConfigResponse(protocol, _myNodeNum, config);

      expect(protocol.currentDeviceConfig, isNotNull);
      expect(
        protocol.currentDeviceConfig!.role,
        config_pbenum.Config_DeviceConfig_Role.ROUTER,
      );
      expect(protocol.currentDeviceConfig!.serialEnabled, isTrue);
    });

    test('remote config response does NOT update local cache', () async {
      // First, set a known local config
      final localConfig = config_pb.Config_DeviceConfig()
        ..role = config_pbenum.Config_DeviceConfig_Role.CLIENT;
      await _injectConfigResponse(
        protocol,
        _myNodeNum,
        config_pb.Config()..device = localConfig,
      );
      expect(
        protocol.currentDeviceConfig!.role,
        config_pbenum.Config_DeviceConfig_Role.CLIENT,
      );

      // Now inject a remote config response with a different role
      final remoteConfig = config_pb.Config_DeviceConfig()
        ..role = config_pbenum.Config_DeviceConfig_Role.ROUTER;
      await _injectConfigResponse(
        protocol,
        _remoteNodeNum,
        config_pb.Config()..device = remoteConfig,
      );

      // Local cache should still be CLIENT
      expect(
        protocol.currentDeviceConfig!.role,
        config_pbenum.Config_DeviceConfig_Role.CLIENT,
      );
    });

    test('remote LoRa config response does NOT update local cache', () async {
      // Set initial local LoRa config
      final localLora = config_pb.Config_LoRaConfig()
        ..region = config_pbenum.Config_LoRaConfig_RegionCode.US
        ..hopLimit = 3;
      await _injectConfigResponse(
        protocol,
        _myNodeNum,
        config_pb.Config()..lora = localLora,
      );
      expect(protocol.currentLoraConfig, isNotNull);
      expect(
        protocol.currentLoraConfig!.region,
        config_pbenum.Config_LoRaConfig_RegionCode.US,
      );

      // Inject remote LoRa config with different region
      final remoteLora = config_pb.Config_LoRaConfig()
        ..region = config_pbenum.Config_LoRaConfig_RegionCode.EU_868
        ..hopLimit = 5;
      await _injectConfigResponse(
        protocol,
        _remoteNodeNum,
        config_pb.Config()..lora = remoteLora,
      );

      // Local cache should still be US
      expect(
        protocol.currentLoraConfig!.region,
        config_pbenum.Config_LoRaConfig_RegionCode.US,
      );
    });

    test('config response stream emits for ALL sources', () async {
      final receivedConfigs = <config_pb.Config_DeviceConfig>[];
      final sub = protocol.deviceConfigStream.listen(receivedConfigs.add);

      // Inject local config
      final localConfig = config_pb.Config_DeviceConfig()
        ..role = config_pbenum.Config_DeviceConfig_Role.CLIENT;
      await _injectConfigResponse(
        protocol,
        _myNodeNum,
        config_pb.Config()..device = localConfig,
      );

      // Inject remote config
      final remoteConfig = config_pb.Config_DeviceConfig()
        ..role = config_pbenum.Config_DeviceConfig_Role.ROUTER;
      await _injectConfigResponse(
        protocol,
        _remoteNodeNum,
        config_pb.Config()..device = remoteConfig,
      );

      // Small delay for stream delivery
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Both should have been emitted to the stream
      expect(receivedConfigs.length, 2);
      expect(
        receivedConfigs[0].role,
        config_pbenum.Config_DeviceConfig_Role.CLIENT,
      );
      expect(
        receivedConfigs[1].role,
        config_pbenum.Config_DeviceConfig_Role.ROUTER,
      );

      await sub.cancel();
    });
  });

  // ===========================================================================
  // Device metadata response source isolation
  // ===========================================================================

  group('Device metadata response isolation', () {
    test('local metadata response updates local node', () async {
      // Inject local node info first so there's a node entry to update
      await _injectNodeInfo(
        protocol,
        _myNodeNum,
        longName: 'MyDevice',
        shortName: 'MD',
      );

      // Verify the node exists
      expect(protocol.nodes[_myNodeNum], isNotNull);
      expect(protocol.nodes[_myNodeNum]!.firmwareVersion, isNull);

      // Inject local metadata response
      await _injectMetadataResponse(
        protocol,
        _myNodeNum,
        firmwareVersion: '2.5.6',
      );

      // Local node should have the firmware version
      expect(protocol.nodes[_myNodeNum]!.firmwareVersion, '2.5.6');
    });

    test('remote metadata response does NOT overwrite local node', () async {
      // Inject both local and remote node entries
      await _injectNodeInfo(
        protocol,
        _myNodeNum,
        longName: 'MyDevice',
        shortName: 'MD',
      );

      // Set local firmware version via local metadata
      await _injectMetadataResponse(
        protocol,
        _myNodeNum,
        firmwareVersion: '2.5.6',
      );
      expect(protocol.nodes[_myNodeNum]!.firmwareVersion, '2.5.6');

      // Inject REMOTE metadata response with different firmware version
      await _injectMetadataResponse(
        protocol,
        _remoteNodeNum,
        firmwareVersion: '2.4.0',
      );

      // Local node should still have 2.5.6, NOT 2.4.0
      expect(protocol.nodes[_myNodeNum]!.firmwareVersion, '2.5.6');
    });
  });

  // ===========================================================================
  // setOwnerConfig: local node cache protection
  // ===========================================================================

  group('setOwnerConfig: local node cache protection', () {
    test('remote target does not update local node cache', () async {
      // Inject local node
      await _injectNodeInfo(
        protocol,
        _myNodeNum,
        longName: 'OriginalName',
        shortName: 'ON',
      );
      expect(protocol.nodes[_myNodeNum]!.longName, 'OriginalName');

      // Send owner config to remote target
      await protocol.setOwnerConfig(
        longName: 'RemoteName',
        shortName: 'RN',
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      // Local node should not have changed
      expect(protocol.nodes[_myNodeNum]!.longName, 'OriginalName');
    });

    test('local target updates local node cache', () async {
      await _injectNodeInfo(
        protocol,
        _myNodeNum,
        longName: 'OriginalName',
        shortName: 'ON',
      );

      await protocol.setOwnerConfig(
        longName: 'NewName',
        shortName: 'NN',
        target: const AdminTarget.local(),
      );

      expect(protocol.nodes[_myNodeNum]!.longName, 'NewName');
    });
  });

  // ===========================================================================
  // setDeviceConfig: local node role cache protection
  // ===========================================================================

  group('setDeviceConfig: local node role cache protection', () {
    test('remote target does not update local node role', () async {
      await _injectNodeInfo(
        protocol,
        _myNodeNum,
        longName: 'MyDevice',
        shortName: 'MD',
      );

      // Inject initial device config to set up cache
      final localConfig = config_pb.Config_DeviceConfig()
        ..role = config_pbenum.Config_DeviceConfig_Role.CLIENT;
      await _injectConfigResponse(
        protocol,
        _myNodeNum,
        config_pb.Config()..device = localConfig,
      );

      // Save device config targeting remote node with ROUTER role
      await protocol.setDeviceConfig(
        role: config_pbenum.Config_DeviceConfig_Role.ROUTER,
        rebroadcastMode: config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
        serialEnabled: false,
        nodeInfoBroadcastSecs: 900,
        ledHeartbeatDisabled: false,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      // Local node role should NOT have changed to ROUTER
      // (The role is set as a string on the MeshNode model)
      final localNode = protocol.nodes[_myNodeNum];
      if (localNode?.role != null) {
        expect(localNode!.role, isNot('ROUTER'));
      }
    });
  });

  // ===========================================================================
  // Packet routing invariants
  // ===========================================================================

  group('Packet routing invariants', () {
    test('remote admin packet has RELIABLE priority and wantAck', () async {
      await protocol.setDeviceConfig(
        role: config_pbenum.Config_DeviceConfig_Role.CLIENT,
        rebroadcastMode: config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
        serialEnabled: false,
        nodeInfoBroadcastSecs: 900,
        ledHeartbeatDisabled: false,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.from, _myNodeNum);
      expect(packet.wantAck, isTrue);
      expect(packet.priority, pbenum.MeshPacket_Priority.RELIABLE);
    });

    test('local admin packet has NO routing flags', () async {
      await protocol.setDeviceConfig(
        role: config_pbenum.Config_DeviceConfig_Role.CLIENT,
        rebroadcastMode: config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
        serialEnabled: false,
        nodeInfoBroadcastSecs: 900,
        ledHeartbeatDisabled: false,
        target: const AdminTarget.local(),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _myNodeNum);
      expect(packet.from, _myNodeNum);
      expect(packet.wantAck, isFalse);
      // Default priority should NOT be RELIABLE
      expect(packet.priority, isNot(pbenum.MeshPacket_Priority.RELIABLE));
    });

    test('AdminTarget.fromNullable(null) routes to local device', () async {
      final target = AdminTarget.fromNullable(null);
      expect(target.isLocal, isTrue);

      await protocol.setConfig(
        config_pb.Config()
          ..device = (config_pb.Config_DeviceConfig()
            ..role = config_pbenum.Config_DeviceConfig_Role.CLIENT),
        target: target,
      );

      final packet = transport.lastPacket;
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });

    test('AdminTarget.fromNullable(remoteNum) routes to remote', () async {
      final target = AdminTarget.fromNullable(_remoteNodeNum);
      expect(target.isRemote, isTrue);

      await protocol.setConfig(
        config_pb.Config()
          ..device = (config_pb.Config_DeviceConfig()
            ..role = config_pbenum.Config_DeviceConfig_Role.CLIENT),
        target: target,
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
    });
  });

  // ===========================================================================
  // setModuleConfig: local cache protection
  // ===========================================================================

  group('setModuleConfig: local cache protection', () {
    test('remote target does not pollute local module cache', () async {
      // Inject local MQTT config
      final localMqtt = admin.AdminMessage()
        ..getModuleConfigResponse = (module_pb.ModuleConfig()
          ..mqtt = (module_pb.ModuleConfig_MQTTConfig()..enabled = false));

      final localData = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = localMqtt.writeToBuffer();

      final localPacket = pb.MeshPacket()
        ..from = _myNodeNum
        ..to = _myNodeNum
        ..decoded = localData
        ..id = 11111;

      final localFromRadio = pb.FromRadio()..packet = localPacket;
      await protocol.handleIncomingPacket(localFromRadio.writeToBuffer());
      await Future<void>.delayed(Duration.zero);

      // Verify local cache
      expect(protocol.currentMqttConfig, isNotNull);
      expect(protocol.currentMqttConfig!.enabled, isFalse);

      // Inject remote MQTT config response
      final remoteMqtt = admin.AdminMessage()
        ..getModuleConfigResponse = (module_pb.ModuleConfig()
          ..mqtt = (module_pb.ModuleConfig_MQTTConfig()..enabled = true));

      final remoteData = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = remoteMqtt.writeToBuffer();

      final remotePacket = pb.MeshPacket()
        ..from = _remoteNodeNum
        ..to = _myNodeNum
        ..decoded = remoteData
        ..id = 22222;

      final remoteFromRadio = pb.FromRadio()..packet = remotePacket;
      await protocol.handleIncomingPacket(remoteFromRadio.writeToBuffer());
      await Future<void>.delayed(Duration.zero);

      // Local cache should still be disabled
      expect(protocol.currentMqttConfig!.enabled, isFalse);
    });
  });

  // ===========================================================================
  // Multiple config operations: sequential independence
  // ===========================================================================

  group('Sequential remote/local operations', () {
    test('local save after remote save does not carry remote values', () async {
      // 1. Set up local config cache
      final localDeviceConfig = config_pb.Config_DeviceConfig()
        ..role = config_pbenum.Config_DeviceConfig_Role.CLIENT
        ..serialEnabled = false;
      await _injectConfigResponse(
        protocol,
        _myNodeNum,
        config_pb.Config()..device = localDeviceConfig,
      );

      // 2. Do a remote save (ROUTER role)
      transport.clear();
      await protocol.setDeviceConfig(
        role: config_pbenum.Config_DeviceConfig_Role.ROUTER,
        rebroadcastMode: config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
        serialEnabled: true,
        nodeInfoBroadcastSecs: 900,
        ledHeartbeatDisabled: false,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      // Remote save should NOT have touched local cache
      expect(
        protocol.currentDeviceConfig!.role,
        config_pbenum.Config_DeviceConfig_Role.CLIENT,
      );

      // 3. Do a local save (change role to REPEATER)
      transport.clear();
      await protocol.setDeviceConfig(
        role: config_pbenum.Config_DeviceConfig_Role.REPEATER,
        rebroadcastMode: config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
        serialEnabled: false,
        nodeInfoBroadcastSecs: 900,
        ledHeartbeatDisabled: false,
        target: const AdminTarget.local(),
      );

      // The local packet should be sent to self
      final packet = transport.lastPacket;
      expect(packet.to, _myNodeNum);

      // The sent config should have REPEATER role and serialEnabled=false
      // (NOT the ROUTER/true from the remote save)
      final adminMsg = transport.lastAdminMessage;
      final sentConfig = adminMsg.setConfig.device;
      expect(sentConfig.role, config_pbenum.Config_DeviceConfig_Role.REPEATER);

      // Local cache should now have the new role
      expect(
        protocol.currentDeviceConfig!.role,
        config_pbenum.Config_DeviceConfig_Role.REPEATER,
      );
    });
  });

  // ===========================================================================
  // LoRa config response stream
  // ===========================================================================

  group('LoRa config stream isolation', () {
    test('both local and remote responses emit on stream', () async {
      final receivedRegions = <config_pbenum.Config_LoRaConfig_RegionCode>[];
      final sub = protocol.loraConfigStream.listen((config) {
        receivedRegions.add(config.region);
      });

      // Inject local LoRa config
      await _injectConfigResponse(
        protocol,
        _myNodeNum,
        config_pb.Config()
          ..lora = (config_pb.Config_LoRaConfig()
            ..region = config_pbenum.Config_LoRaConfig_RegionCode.US),
      );

      // Inject remote LoRa config
      await _injectConfigResponse(
        protocol,
        _remoteNodeNum,
        config_pb.Config()
          ..lora = (config_pb.Config_LoRaConfig()
            ..region = config_pbenum.Config_LoRaConfig_RegionCode.EU_868),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(receivedRegions.length, 2);
      expect(receivedRegions[0], config_pbenum.Config_LoRaConfig_RegionCode.US);
      expect(
        receivedRegions[1],
        config_pbenum.Config_LoRaConfig_RegionCode.EU_868,
      );

      await sub.cancel();
    });
  });
}
