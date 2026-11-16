// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/admin.pb.dart' as admin;
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/module_config.pb.dart'
    as module_pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/services/protocol/admin_target.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _CapturingTransport implements DeviceTransport {
  final List<List<int>> sentBytes = [];

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
  Stream<List<int>> get dataStream => const Stream.empty();
  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();
  @override
  Future<void> connect(DeviceInfo device) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> send(List<int> data) async => sentBytes.add(data);
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
  Future<void> dispose() async {}

  pb.MeshPacket get lastPacket => pb.ToRadio.fromBuffer(sentBytes.last).packet;
  admin.AdminMessage get lastAdminMessage =>
      admin.AdminMessage.fromBuffer(lastPacket.decoded.payload);
}

const _myNodeNum = 0xAABBCCDD;

Future<void> _feed(ProtocolService protocol, pb.FromRadio fromRadio) async {
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late _CapturingTransport transport;
  late ProtocolService protocol;

  setUp(() async {
    transport = _CapturingTransport();
    protocol = ProtocolService(transport);
    await _feed(
      protocol,
      pb.FromRadio()..myInfo = (pb.MyNodeInfo()..myNodeNum = _myNodeNum),
    );
    await _feed(
      protocol,
      pb.FromRadio()
        ..nodeInfo = (pb.NodeInfo()
          ..num = _myNodeNum
          ..user = (pb.User()
            ..id = '!aabbccdd'
            ..longName = 'Bench'
            ..shortName = 'BN')),
    );
    protocol.debugForceReadinessForTesting(OperationalReadiness.ready);
  });

  test(
    'the initial config download caches the status message config',
    () async {
      await _feed(
        protocol,
        pb.FromRadio()
          ..moduleConfig = (module_pb.ModuleConfig()
            ..statusmessage = (module_pb.ModuleConfig_StatusMessageConfig()
              ..nodeStatus = 'On air')),
      );
      expect(protocol.currentStatusMessageConfig?.nodeStatus, 'On air');
    },
  );

  test('saving sends set_module_config to this radio without a reboot '
      'signal, and updates its node at once', () async {
    final rebootSignals = <void>[];
    final sub = protocol.localConfigWriteStream.listen(rebootSignals.add);
    addTearDown(sub.cancel);

    await protocol.setStatusMessageConfig('Out walking');
    await Future<void>.delayed(Duration.zero);

    expect(transport.lastPacket.to, _myNodeNum);
    expect(
      transport.lastAdminMessage.setModuleConfig.statusmessage.nodeStatus,
      'Out walking',
    );
    expect(protocol.currentStatusMessageConfig?.nodeStatus, 'Out walking');
    expect(protocol.nodes[_myNodeNum]?.nodeStatus, 'Out walking');
    expect(
      rebootSignals,
      isEmpty,
      reason: 'firmware saves the status message without rebooting',
    );
  });

  test('saving an empty status clears it on this radio\'s node', () async {
    await protocol.setStatusMessageConfig('Out walking');
    await protocol.setStatusMessageConfig('');

    expect(
      transport.lastAdminMessage.setModuleConfig.statusmessage.nodeStatus,
      '',
    );
    expect(protocol.nodes[_myNodeNum]?.nodeStatus, isNull);
  });

  group('remote node', () {
    const remoteNodeNum = 0x12345678;

    Future<void> remoteResponds(String status) async {
      final adm = admin.AdminMessage()
        ..getModuleConfigResponse = (module_pb.ModuleConfig()
          ..statusmessage = (module_pb.ModuleConfig_StatusMessageConfig()
            ..nodeStatus = status))
        ..sessionPasskey = [9, 8, 7];
      await _feed(
        protocol,
        pb.FromRadio()
          ..packet = (pb.MeshPacket()
            ..from = remoteNodeNum
            ..to = _myNodeNum
            ..id = 4242
            ..decoded = (pb.Data()
              ..portnum = pn.PortNum.ADMIN_APP
              ..payload = adm.writeToBuffer())),
      );
    }

    setUp(() async {
      await _feed(
        protocol,
        pb.FromRadio()
          ..nodeInfo = (pb.NodeInfo()
            ..num = remoteNodeNum
            ..user = (pb.User()
              ..id = '!12345678'
              ..longName = 'Hilltop'
              ..shortName = 'HT')),
      );
    });

    test(
      'its config response is cached for that node and opens a session',
      () async {
        expect(protocol.remoteAdminSessionReady(remoteNodeNum), isFalse);
        await remoteResponds('On the hill');

        expect(
          protocol.remoteStatusMessageConfig(remoteNodeNum)?.nodeStatus,
          'On the hill',
        );
        expect(
          protocol.currentStatusMessageConfig,
          isNull,
          reason: 'a remote node\'s config never replaces this radio\'s',
        );
        expect(protocol.remoteAdminSessionReady(remoteNodeNum), isTrue);
      },
    );

    test(
      'saving goes to that node with its session passkey and updates it',
      () async {
        await remoteResponds('On the hill');
        await protocol.setStatusMessageConfig(
          'Back at base',
          target: const AdminTarget.remote(remoteNodeNum),
        );

        expect(transport.lastPacket.to, remoteNodeNum);
        final sent = transport.lastAdminMessage;
        expect(sent.setModuleConfig.statusmessage.nodeStatus, 'Back at base');
        expect(sent.sessionPasskey, [9, 8, 7]);
        expect(protocol.nodes[remoteNodeNum]?.nodeStatus, 'Back at base');
        expect(
          protocol.remoteStatusMessageConfig(remoteNodeNum)?.nodeStatus,
          'Back at base',
        );
        expect(protocol.nodes[_myNodeNum]?.nodeStatus, isNull);
      },
    );
  });

  test('a Mesh Beacon save does not signal a reboot', () async {
    final rebootSignals = <void>[];
    final sub = protocol.localConfigWriteStream.listen(rebootSignals.add);
    addTearDown(sub.cancel);

    await protocol.setModuleConfig(
      module_pb.ModuleConfig()
        ..meshBeacon = module_pb.ModuleConfig_MeshBeaconConfig(),
    );
    await Future<void>.delayed(Duration.zero);

    expect(rebootSignals, isEmpty);
  });

  test('other module config saves still signal the expected reboot', () async {
    final rebootSignals = <void>[];
    final sub = protocol.localConfigWriteStream.listen(rebootSignals.add);
    addTearDown(sub.cancel);

    await protocol.setModuleConfig(
      module_pb.ModuleConfig()
        ..paxcounter = (module_pb.ModuleConfig_PaxcounterConfig()
          ..enabled = true),
    );
    await Future<void>.delayed(Duration.zero);

    expect(rebootSignals, hasLength(1));
  });
}
