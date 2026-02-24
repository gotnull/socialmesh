// SPDX-License-Identifier: GPL-3.0-or-later

/// Regression tests for remote admin routing.
///
/// These tests verify that protocol service methods correctly route admin
/// packets to the specified target node (local or remote) when an
/// [AdminTarget] is provided. This was the root cause of the remote admin
/// bug: all config changes were sent to the local device even when a
/// remote target was selected in the UI.
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
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/protocol/admin_target.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

/// A transport that captures sent bytes so tests can decode and inspect them.
class _CapturingTransport implements DeviceTransport {
  final List<List<int>> sentBytes = [];

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
  Stream<List<int>> get dataStream => const Stream.empty();

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
  Future<void> dispose() async {}

  /// Decode the last sent bytes as a ToRadio message, then extract the
  /// MeshPacket from it.
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

/// Primes the protocol service with a myNodeNum by feeding a MyNodeInfo
/// FromRadio message through the incoming packet handler.
Future<void> _primeNodeNum(ProtocolService protocol) async {
  final myInfo = pb.MyNodeInfo()..myNodeNum = _myNodeNum;
  final fromRadio = pb.FromRadio()..myInfo = myInfo;
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
  // Allow microtasks to process
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late _CapturingTransport transport;
  late ProtocolService protocol;

  setUp(() async {
    transport = _CapturingTransport();
    protocol = ProtocolService(transport);
    await _primeNodeNum(protocol);
  });

  group('Remote admin routing: setDeviceConfig', () {
    test('sends to remote node when remote target is provided', () async {
      await protocol.setDeviceConfig(
        role: config_pbenum.Config_DeviceConfig_Role.CLIENT,
        rebroadcastMode: config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
        serialEnabled: false,
        nodeInfoBroadcastSecs: 900,
        ledHeartbeatDisabled: false,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
      expect(packet.priority, pbenum.MeshPacket_Priority.RELIABLE);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.hasSetConfig(), isTrue);
    });

    test('sends to self when local target is provided', () async {
      await protocol.setDeviceConfig(
        role: config_pbenum.Config_DeviceConfig_Role.CLIENT,
        rebroadcastMode: config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
        serialEnabled: false,
        nodeInfoBroadcastSecs: 900,
        ledHeartbeatDisabled: false,
        target: const AdminTarget.local(),
      );

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });

    test('sends to self when no target is provided', () async {
      await protocol.setDeviceConfig(
        role: config_pbenum.Config_DeviceConfig_Role.CLIENT,
        rebroadcastMode: config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
        serialEnabled: false,
        nodeInfoBroadcastSecs: 900,
        ledHeartbeatDisabled: false,
      );

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Remote admin routing: setOwnerConfig', () {
    test('sends to remote node when remote target is provided', () async {
      await protocol.setOwnerConfig(
        longName: 'RemoteNode',
        shortName: 'RN',
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
      expect(packet.priority, pbenum.MeshPacket_Priority.RELIABLE);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.hasSetOwner(), isTrue);
      expect(adminMsg.setOwner.longName, 'RemoteNode');
    });

    test('sends to self when no target is provided', () async {
      await protocol.setOwnerConfig(longName: 'LocalNode', shortName: 'LN');

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Remote admin routing: setDisplayConfig', () {
    test('routes to remote target', () async {
      await protocol.setDisplayConfig(
        screenOnSecs: 300,
        autoScreenCarouselSecs: 0,
        flipScreen: false,
        units: config_pb.Config_DisplayConfig_DisplayUnits.METRIC,
        displayMode: config_pb.Config_DisplayConfig_DisplayMode.DEFAULT,
        headingBold: false,
        wakeOnTapOrMotion: false,
        use12hClock: false,
        compassNorthTop: false,
        useLongNodeName: false,
        enableMessageBubbles: false,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
      expect(packet.priority, pbenum.MeshPacket_Priority.RELIABLE);
    });
  });

  group('Remote admin routing: setBluetoothConfig', () {
    test('routes to remote target', () async {
      await protocol.setBluetoothConfig(
        enabled: true,
        mode: config_pb.Config_BluetoothConfig_PairingMode.RANDOM_PIN,
        fixedPin: 123456,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
    });
  });

  group('Remote admin routing: setPowerConfig', () {
    test('routes to remote target', () async {
      await protocol.setPowerConfig(
        isPowerSaving: false,
        waitBluetoothSecs: 0,
        sdsSecs: 0,
        lsSecs: 0,
        minWakeSecs: 0,
        onBatteryShutdownAfterSecs: 0,
        adcMultiplierOverride: 0.0,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
    });
  });

  group('Remote admin routing: setNetworkConfig', () {
    test('routes to remote target', () async {
      await protocol.setNetworkConfig(
        wifiEnabled: false,
        wifiSsid: '',
        wifiPsk: '',
        ethEnabled: false,
        ntpServer: 'pool.ntp.org',
        rsyslogServer: '',
        enabledProtocols: 0,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
    });
  });

  group('Remote admin routing: setSecurityConfig', () {
    test('routes to remote target', () async {
      await protocol.setSecurityConfig(
        isManaged: false,
        serialEnabled: true,
        debugLogEnabled: false,
        adminChannelEnabled: false,
        privateKey: [],
        adminKeys: [],
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
    });
  });

  group('Remote admin routing: setMQTTConfig', () {
    test('routes to remote target', () async {
      await protocol.setMQTTConfig(
        enabled: false,
        address: '',
        username: '',
        password: '',
        encryptionEnabled: false,
        jsonEnabled: false,
        tlsEnabled: false,
        root: 'msh',
        proxyToClientEnabled: false,
        mapReportingEnabled: false,
        mapPublishIntervalSecs: 0,
        mapPositionPrecision: 0,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
    });
  });

  group('Remote admin routing: setModuleConfig', () {
    test('routes to remote target', () async {
      final moduleConfig = module_pb.ModuleConfig();
      await protocol.setModuleConfig(
        moduleConfig,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
    });

    test('routes to self when no target is provided', () async {
      final moduleConfig = module_pb.ModuleConfig();
      await protocol.setModuleConfig(moduleConfig);

      final packet = transport.lastPacket;
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Remote admin routing: reboot', () {
    test('routes to remote target', () async {
      await protocol.reboot(target: const AdminTarget.remote(_remoteNodeNum));

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
    });
  });

  group('Remote admin routing: shutdown', () {
    test('routes to remote target', () async {
      await protocol.shutdown(target: const AdminTarget.remote(_remoteNodeNum));

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
    });
  });

  group('Remote admin routing: getConfig', () {
    test('routes to remote target', () async {
      await protocol.getConfig(
        admin.AdminMessage_ConfigType.DEVICE_CONFIG,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
    });

    test('routes to self when local target is provided', () async {
      await protocol.getConfig(
        admin.AdminMessage_ConfigType.DEVICE_CONFIG,
        target: const AdminTarget.local(),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Remote admin routing: getModuleConfig', () {
    test('routes to remote target', () async {
      await protocol.getModuleConfig(
        admin.AdminMessage_ModuleConfigType.MQTT_CONFIG,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
    });
  });

  group('Remote admin routing: admin packet portnum', () {
    test('all admin packets use ADMIN_APP portnum', () async {
      // Test a representative set of methods
      await protocol.setDeviceConfig(
        role: config_pbenum.Config_DeviceConfig_Role.CLIENT,
        rebroadcastMode: config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
        serialEnabled: false,
        nodeInfoBroadcastSecs: 900,
        ledHeartbeatDisabled: false,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.decoded.portnum, pn.PortNum.ADMIN_APP);
    });
  });

  group('Golden invariant: remote target never self-addresses', () {
    test('from != to when remote target is provided', () async {
      await protocol.setOwnerConfig(
        longName: 'Test',
        shortName: 'T',
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(
        packet.from,
        isNot(equals(packet.to)),
        reason:
            'Remote admin packet must have from != to. '
            'from=${packet.from}, to=${packet.to}',
      );
    });
  });

  group('Golden invariant: local target always self-addresses', () {
    test('from == to when local target is provided', () async {
      await protocol.setOwnerConfig(
        longName: 'Test',
        shortName: 'T',
        target: const AdminTarget.local(),
      );

      final packet = transport.lastPacket;
      expect(
        packet.from,
        equals(packet.to),
        reason:
            'Local admin packet must have from == to. '
            'from=${packet.from}, to=${packet.to}',
      );
    });
  });

  // =========================================================================
  // Regression tests for audit round 2 — methods that were missed in the
  // initial remote admin routing fix.
  // =========================================================================

  group('Remote admin routing: setRangeTestConfig', () {
    test('routes to remote target', () async {
      await protocol.setRangeTestConfig(
        enabled: true,
        sender: 30,
        save: false,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
      expect(packet.priority, pbenum.MeshPacket_Priority.RELIABLE);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.hasSetModuleConfig(), isTrue);
    });

    test('routes to self when no target is provided', () async {
      await protocol.setRangeTestConfig(enabled: true, sender: 30, save: false);

      final packet = transport.lastPacket;
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Remote admin routing: setRingtone', () {
    test('routes to remote target', () async {
      await protocol.setRingtone(
        'TestTone:d=4,o=5,b=120:c,e,g',
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
      expect(packet.priority, pbenum.MeshPacket_Priority.RELIABLE);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.hasSetRingtoneMessage(), isTrue);
    });

    test('routes to self when no target is provided', () async {
      await protocol.setRingtone('TestTone:d=4,o=5,b=120:c,e,g');

      final packet = transport.lastPacket;
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Remote admin routing: factoryResetConfig', () {
    test('routes to remote target', () async {
      await protocol.factoryResetConfig(
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
      expect(packet.priority, pbenum.MeshPacket_Priority.RELIABLE);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.factoryResetConfig, 5);
    });
  });

  group('Remote admin routing: factoryResetDevice', () {
    test('routes to remote target', () async {
      await protocol.factoryResetDevice(
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
      expect(packet.priority, pbenum.MeshPacket_Priority.RELIABLE);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.factoryResetDevice, 5);
    });
  });

  group('Remote admin routing: nodeDbReset', () {
    test('routes to remote target', () async {
      await protocol.nodeDbReset(
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
      expect(packet.priority, pbenum.MeshPacket_Priority.RELIABLE);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.nodedbReset, isTrue);
    });
  });

  group('Remote admin routing: enterDfuMode', () {
    test('routes to remote target', () async {
      await protocol.enterDfuMode(
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);
      expect(packet.priority, pbenum.MeshPacket_Priority.RELIABLE);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.enterDfuModeRequest, isTrue);
    });
  });

  // ==========================================================================
  // Local-only method guards
  //
  // These methods intentionally use MeshPacketBuilder.localAdmin() and have
  // no AdminTarget parameter. Every packet MUST be self-addressed
  // (from == to == myNodeNum) and MUST NOT set wantAck (local ops).
  // ==========================================================================

  group('Local-only guard: setChannel', () {
    test('always sends to local device', () async {
      await protocol.setChannel(
        ChannelConfig(index: 0, name: 'Test', psk: [1]),
      );

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Local-only guard: getChannel', () {
    test('always sends to local device', () async {
      await protocol.getChannel(0);

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Local-only guard: setRegion', () {
    test('always sends to local device', () async {
      await protocol.setRegion(config_pbenum.Config_LoRaConfig_RegionCode.US);

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Local-only guard: removeNode', () {
    test('always sends to local device', () async {
      await protocol.removeNode(0x11111111);

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Local-only guard: setFavoriteNode', () {
    test('always sends to local device', () async {
      await protocol.setFavoriteNode(0x11111111);

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Local-only guard: removeFavoriteNode', () {
    test('always sends to local device', () async {
      await protocol.removeFavoriteNode(0x11111111);

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Local-only guard: setFixedPosition', () {
    test('always sends to local device', () async {
      await protocol.setFixedPosition(latitude: 37.7749, longitude: -122.4194);

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Local-only guard: removeFixedPosition', () {
    test('always sends to local device', () async {
      await protocol.removeFixedPosition();

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Local-only guard: setIgnoredNode', () {
    test('always sends to local device', () async {
      await protocol.setIgnoredNode(0x11111111);

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Local-only guard: removeIgnoredNode', () {
    test('always sends to local device', () async {
      await protocol.removeIgnoredNode(0x11111111);

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Local-only guard: setTimeOnly', () {
    test('always sends to local device', () async {
      await protocol.setTimeOnly(1700000000);

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });

  group('Local-only guard: syncTime', () {
    test('always sends to local device', () async {
      await protocol.syncTime();

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);
    });
  });
}
