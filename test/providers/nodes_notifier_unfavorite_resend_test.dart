// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Coverage for NodesNotifier._enforceFavoriteIntents: on each transition
// into OperationalReadiness.ready (device NodeDB replay complete), the app
// re-sends the favourite admin messages the device missed. The favourite
// admin messages are fire-and-forget local admin packets, so a dropped
// packet (or a NodeDB not persisted to flash before a reboot) leaves the
// device out of sync with the user's last in-app action.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/admin.pb.dart' as admin;
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/nodes/node_identity_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

const int _myNodeNum = 0x9999;

class _RecordingConnectedTransport implements DeviceTransport {
  final List<List<int>> sent = <List<int>>[];

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
  Future<void> send(List<int> data) async {
    sent.add(List<int>.of(data));
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
  Future<void> dispose() async {}
}

Future<
  ({
    ProviderContainer container,
    ProtocolService protocol,
    _RecordingConnectedTransport transport,
    DeviceFavoritesService favorites,
  })
>
_buildContainer({
  List<MeshNode> storedNodes = const [],
  Set<int> cachedFavorites = const {},
  Set<int> tombstones = const {},
}) async {
  SharedPreferences.setMockInitialValues({});

  final storage = NodeStorageService();
  await storage.init();
  for (final node in storedNodes) {
    await storage.saveNode(node);
  }

  final favService = DeviceFavoritesService();
  await favService.init();
  for (final num in cachedFavorites) {
    await favService.addFavorite(num);
  }
  for (final num in tombstones) {
    await favService.addUnfavoriteTombstone(num);
  }

  final identityStore = NodeIdentityStore();
  await identityStore.init();

  final transport = _RecordingConnectedTransport();
  final protocol = ProtocolService(transport);

  final container = ProviderContainer(
    overrides: [
      protocolServiceProvider.overrideWithValue(protocol),
      nodeStorageProvider.overrideWith((ref) async => storage),
      deviceFavoritesProvider.overrideWith((ref) async => favService),
      nodeIdentityStoreProvider.overrideWith((ref) async => identityStore),
    ],
  );

  await container.read(nodeStorageProvider.future);
  await container.read(deviceFavoritesProvider.future);
  await container.read(nodeIdentityStoreProvider.future);

  return (
    container: container,
    protocol: protocol,
    transport: transport,
    favorites: favService,
  );
}

Future<void> _injectMyInfo(ProtocolService protocol) async {
  final fromRadio = pb.FromRadio(myInfo: pb.MyNodeInfo(myNodeNum: _myNodeNum));
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
}

Future<void> _injectNodeInfo(
  ProtocolService protocol, {
  required int nodeNum,
  required bool isFavorite,
}) async {
  final fromRadio = pb.FromRadio(
    nodeInfo: pb.NodeInfo(
      num: nodeNum,
      isFavorite: isFavorite,
      user: pb.User()
        ..longName = 'Node$nodeNum'
        ..shortName = 'N',
    ),
  );
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
  await Future<void>.delayed(const Duration(milliseconds: 50));
}

/// Decodes every recorded ToRadio admin frame into (packet, AdminMessage).
List<({pb.MeshPacket packet, admin.AdminMessage message})> _sentAdminFrames(
  _RecordingConnectedTransport transport,
) {
  final frames = <({pb.MeshPacket packet, admin.AdminMessage message})>[];
  for (final bytes in transport.sent) {
    try {
      final toRadio = pb.ToRadio.fromBuffer(bytes);
      if (!toRadio.hasPacket()) continue;
      final packet = toRadio.packet;
      if (packet.decoded.portnum != pn.PortNum.ADMIN_APP) continue;
      frames.add((
        packet: packet,
        message: admin.AdminMessage.fromBuffer(packet.decoded.payload),
      ));
    } catch (_) {
      // Not a ToRadio frame.
    }
  }
  return frames;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ready transition re-sends remove_favorite_node for tombstoned nodes '
      'the device still reports as favourite, exactly once, as a local '
      'admin packet', () async {
    const staleFavNum = 0x1111; // tombstoned, device says favourite
    const confirmedNum = 0x2222; // tombstoned, device says not favourite

    final env = await _buildContainer(
      storedNodes: [
        MeshNode(nodeNum: staleFavNum, longName: 'StaleFav'),
        MeshNode(nodeNum: confirmedNum, longName: 'Confirmed'),
      ],
      tombstones: {staleFavNum, confirmedNum},
    );
    addTearDown(env.container.dispose);

    await _injectMyInfo(env.protocol);
    await _injectNodeInfo(env.protocol, nodeNum: staleFavNum, isFavorite: true);
    await _injectNodeInfo(
      env.protocol,
      nodeNum: confirmedNum,
      isFavorite: false,
    );

    // Activate NodesNotifier with a real listener (mirrors the always-on
    // UI watchers in production). Riverpod 3 pauses a provider's ref.listen
    // subscriptions while the provider itself has no active listeners, so a
    // bare read would leave the readiness listener paused.
    final sub = env.container.listen(nodesProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    env.transport.sent.clear();
    env.protocol.debugForceReadinessForTesting(OperationalReadiness.ready);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final adminFrames = _sentAdminFrames(env.transport);
    final removals = adminFrames
        .where((f) => f.message.hasRemoveFavoriteNode())
        .toList();

    expect(
      removals.length,
      1,
      reason:
          'Exactly one remove_favorite_node re-send is expected: only the '
          'node the device still reports as favourite.',
    );
    expect(removals.single.message.removeFavoriteNode, staleFavNum);
    expect(
      removals.single.packet.from,
      removals.single.packet.to,
      reason:
          'Favourite admin re-sends must be local admin packets '
          '(from == to == myNodeNum), never mesh traffic.',
    );
    expect(removals.single.packet.wantAck, isFalse);

    // Second ready transition: removeFavoriteNode already patched the
    // protocol cache to isFavorite=false, so nothing is re-sent.
    env.transport.sent.clear();
    env.protocol.debugForceReadinessForTesting(OperationalReadiness.degraded);
    env.protocol.debugForceReadinessForTesting(OperationalReadiness.ready);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      _sentAdminFrames(
        env.transport,
      ).where((f) => f.message.hasRemoveFavoriteNode()),
      isEmpty,
      reason:
          'A second ready transition must not re-send once the protocol '
          'cache already reflects the unfavorite (idempotence).',
    );
  });

  test('ready transition re-sends set_favorite_node when the device lost a '
      'favourite the app still holds', () async {
    const lostFavNum = 0x3333;

    final env = await _buildContainer(
      storedNodes: [
        MeshNode(nodeNum: lostFavNum, longName: 'LostFav', isFavorite: true),
      ],
      cachedFavorites: {lostFavNum},
    );
    addTearDown(env.container.dispose);

    await _injectMyInfo(env.protocol);
    // Device lost the favourite (e.g. NodeDB never persisted to flash).
    await _injectNodeInfo(env.protocol, nodeNum: lostFavNum, isFavorite: false);

    final sub = env.container.listen(nodesProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    env.transport.sent.clear();
    env.protocol.debugForceReadinessForTesting(OperationalReadiness.ready);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final adds = _sentAdminFrames(
      env.transport,
    ).where((f) => f.message.hasSetFavoriteNode()).toList();

    expect(
      adds.length,
      1,
      reason:
          'The device-side lost favourite must be re-asserted with one '
          'set_favorite_node send.',
    );
    expect(adds.single.message.setFavoriteNode, lostFavNum);
  });

  test('ready transition sends nothing when device and app agree', () async {
    const inSyncFav = 0x4444;

    final env = await _buildContainer(
      storedNodes: [
        MeshNode(nodeNum: inSyncFav, longName: 'InSync', isFavorite: true),
      ],
      cachedFavorites: {inSyncFav},
    );
    addTearDown(env.container.dispose);

    await _injectMyInfo(env.protocol);
    await _injectNodeInfo(env.protocol, nodeNum: inSyncFav, isFavorite: true);

    final sub = env.container.listen(nodesProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    env.transport.sent.clear();
    env.protocol.debugForceReadinessForTesting(OperationalReadiness.ready);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      _sentAdminFrames(env.transport),
      isEmpty,
      reason: 'No admin traffic when device state matches app intent.',
    );
  });
}
