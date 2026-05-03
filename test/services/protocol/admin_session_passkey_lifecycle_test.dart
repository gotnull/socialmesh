// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for the admin session passkey lifecycle inside ProtocolService.
///
/// Pins behaviours that exist in production today but were not previously
/// covered by `remote_admin_integrity_test.dart`'s `session passkey handling`
/// group:
///
/// 1. Empty passkey on a remote admin response does not get stored.
/// 2. A passkey carried on a local-origin admin response does not get stored.
/// 3. A remote admin write with no stored passkey sends without one and
///    still carries the remote routing flags (wantAck + RELIABLE).
/// 4. A subsequent valid remote admin response replaces the previously
///    stored passkey for that node.
///
/// Parity reference: `meshtastic-ios/Meshtastic/Accessory/Accessory Manager/`
/// `AccessoryManager+ToRadio.swift::saveDeviceConfig` and
/// `MeshPackets.swift` (sessionExpiration / sessionPasskey upsert).
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
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/services/protocol/admin_target.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

// =============================================================================
// Test doubles
// =============================================================================

class _TestTransport implements DeviceTransport {
  final List<List<int>> sentBytes = [];
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

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
  Future<void> refreshNotifications() async {}

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

  pb.MeshPacket get lastPacket {
    final toRadio = pb.ToRadio.fromBuffer(sentBytes.last);
    return toRadio.packet;
  }

  admin.AdminMessage get lastAdminMessage {
    final packet = lastPacket;
    return admin.AdminMessage.fromBuffer(packet.decoded.payload);
  }

  void clear() => sentBytes.clear();
}

const _myNodeNum = 0xAABBCCDD;
const _remoteNodeNum = 0x12345678;

Future<void> _primeNodeNum(ProtocolService protocol) async {
  final myInfo = pb.MyNodeInfo()..myNodeNum = _myNodeNum;
  final fromRadio = pb.FromRadio()..myInfo = myInfo;
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
  await Future<void>.delayed(Duration.zero);
}

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

/// Inject an admin response carrying a `getDeviceMetadataResponse` and an
/// arbitrary [sessionPasskey] (which may be empty), originating from
/// [fromNodeNum]. Mirrors the way the firmware embeds the passkey in any
/// admin response after the device-metadata exchange.
Future<void> _injectAdminResponseWithPasskey(
  ProtocolService protocol, {
  required int fromNodeNum,
  required List<int> sessionPasskey,
  int packetId = 55555,
}) async {
  final metadata = pb.DeviceMetadata()
    ..firmwareVersion = '2.5.0'
    ..hwModel = pb.HardwareModel.HELTEC_V3
    ..hasBluetooth = true;

  final adminMsg = admin.AdminMessage()
    ..getDeviceMetadataResponse = metadata
    ..sessionPasskey = sessionPasskey;

  final data = pb.Data()
    ..portnum = pn.PortNum.ADMIN_APP
    ..payload = adminMsg.writeToBuffer();

  final packet = pb.MeshPacket()
    ..from = fromNodeNum
    ..to = _myNodeNum
    ..decoded = data
    ..id = packetId;

  final fromRadio = pb.FromRadio()..packet = packet;
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
  await Future<void>.delayed(Duration.zero);
}

config_pb.Config _clientDeviceConfig() {
  return config_pb.Config()
    ..device = (config_pb.Config_DeviceConfig()
      ..role = config_pbenum.Config_DeviceConfig_Role.CLIENT);
}

void main() {
  late _TestTransport transport;
  late ProtocolService protocol;

  setUp(() async {
    transport = _TestTransport();
    protocol = ProtocolService(transport);
    await _primeNodeNum(protocol);
    await _injectNodeInfo(
      protocol,
      _remoteNodeNum,
      longName: 'Remote',
      shortName: 'RM',
    );
  });

  tearDown(() async {
    await transport.dispose();
    protocol.dispose();
  });

  group('admin session passkey lifecycle', () {
    test('empty passkey on a remote admin response is not stored '
        'and does not attach to subsequent remote writes', () async {
      await _injectAdminResponseWithPasskey(
        protocol,
        fromNodeNum: _remoteNodeNum,
        sessionPasskey: const <int>[],
      );

      transport.clear();
      await protocol.setConfig(
        _clientDeviceConfig(),
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final sentAdmin = transport.lastAdminMessage;
      expect(
        sentAdmin.hasSessionPasskey(),
        isFalse,
        reason:
            'An empty passkey from the radio must not be cached and must '
            'not appear on the next remote admin write.',
      );
      expect(sentAdmin.sessionPasskey, isEmpty);
    });

    test(
      'passkey carried on a local-origin admin response is not stored '
      '(only remote responses can update the remote-session cache)',
      () async {
        await _injectAdminResponseWithPasskey(
          protocol,
          fromNodeNum: _myNodeNum,
          sessionPasskey: const <int>[42, 42, 42, 42, 42],
        );

        transport.clear();
        await protocol.setConfig(
          _clientDeviceConfig(),
          target: const AdminTarget.remote(_remoteNodeNum),
        );

        final sentAdmin = transport.lastAdminMessage;
        expect(
          sentAdmin.hasSessionPasskey(),
          isFalse,
          reason:
              'Local-origin admin responses must not seed the remote-session '
              'cache for any node, including unrelated remote node numbers.',
        );
      },
    );

    test(
      'remote target with no stored passkey sends without passkey '
      'and still carries remote routing flags (wantAck + RELIABLE)',
      () async {
        transport.clear();
        await protocol.setConfig(
          _clientDeviceConfig(),
          target: const AdminTarget.remote(_remoteNodeNum),
        );

        final sentAdmin = transport.lastAdminMessage;
        final sentPacket = transport.lastPacket;

        expect(sentAdmin.hasSessionPasskey(), isFalse);
        expect(sentAdmin.sessionPasskey, isEmpty);

        expect(sentPacket.from, equals(_myNodeNum));
        expect(sentPacket.to, equals(_remoteNodeNum));
        expect(sentPacket.wantAck, isTrue);
        expect(
          sentPacket.priority,
          equals(pbenum.MeshPacket_Priority.RELIABLE),
        );
        expect(sentPacket.decoded.portnum, equals(pn.PortNum.ADMIN_APP));
        expect(sentAdmin.hasSetConfig(), isTrue);
        expect(sentAdmin.setConfig.hasDevice(), isTrue);
      },
    );

    test('a subsequent valid remote admin response replaces the previously '
        'stored passkey for that node', () async {
      const passkeyA = <int>[1, 2, 3, 4, 5];
      const passkeyB = <int>[9, 8, 7, 6, 5];

      await _injectAdminResponseWithPasskey(
        protocol,
        fromNodeNum: _remoteNodeNum,
        sessionPasskey: passkeyA,
        packetId: 11111,
      );

      transport.clear();
      await protocol.setConfig(
        _clientDeviceConfig(),
        target: const AdminTarget.remote(_remoteNodeNum),
      );
      expect(transport.lastAdminMessage.sessionPasskey, equals(passkeyA));

      await _injectAdminResponseWithPasskey(
        protocol,
        fromNodeNum: _remoteNodeNum,
        sessionPasskey: passkeyB,
        packetId: 22222,
      );

      transport.clear();
      await protocol.setConfig(
        _clientDeviceConfig(),
        target: const AdminTarget.remote(_remoteNodeNum),
      );
      expect(
        transport.lastAdminMessage.sessionPasskey,
        equals(passkeyB),
        reason:
            'The most recent remote admin response must overwrite the '
            'cached passkey; stale values must not survive a refresh.',
      );
    });
  });
}
