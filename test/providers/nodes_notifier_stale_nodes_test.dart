// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodesNotifier.removeNodes and the Clear Stale Nodes setting: removed
// nodes leave state and persistent storage (a fresh storage read stands in
// for an app restart), and on each transition into ready the nodes not
// heard for the chosen number of days are cleared from the app.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/nodes/node_identity_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

const int _myNodeNum = 0x9999;

class _ConnectedTransport implements DeviceTransport {
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
  Future<void> send(List<int> data) async {}

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

MeshNode _node(int nodeNum, {int? daysAgo, bool favourite = false}) => MeshNode(
  nodeNum: nodeNum,
  longName: 'Node$nodeNum',
  lastHeard: daysAgo == null
      ? null
      : DateTime.now().subtract(Duration(days: daysAgo)),
  isFavorite: favourite,
);

Future<
  ({
    ProviderContainer container,
    ProtocolService protocol,
    NodeStorageService storage,
  })
>
_buildContainer({
  required List<MeshNode> storedNodes,
  int purgeStaleNodeDays = 0,
}) async {
  SharedPreferences.setMockInitialValues({});

  final storage = NodeStorageService();
  await storage.init();
  await storage.saveNodes(storedNodes);

  final settings = SettingsService();
  await settings.init();
  await settings.setPurgeStaleNodeDays(purgeStaleNodeDays);

  final favService = DeviceFavoritesService();
  await favService.init();

  final identityStore = NodeIdentityStore();
  await identityStore.init();

  final protocol = ProtocolService(_ConnectedTransport());

  final container = ProviderContainer(
    overrides: [
      protocolServiceProvider.overrideWithValue(protocol),
      nodeStorageProvider.overrideWith((ref) async => storage),
      deviceFavoritesProvider.overrideWith((ref) async => favService),
      nodeIdentityStoreProvider.overrideWith((ref) async => identityStore),
      settingsServiceProvider.overrideWith((ref) async => settings),
    ],
  );

  await container.read(nodeStorageProvider.future);
  await container.read(deviceFavoritesProvider.future);
  await container.read(nodeIdentityStoreProvider.future);
  await container.read(settingsServiceProvider.future);

  final fromRadio = pb.FromRadio(myInfo: pb.MyNodeInfo(myNodeNum: _myNodeNum));
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());

  return (container: container, protocol: protocol, storage: storage);
}

/// Starts NodesNotifier with a live listener so its readiness listener
/// runs, and waits for the stored nodes to load.
Future<void> _activate(ProviderContainer container) async {
  final sub = container.listen(nodesProvider, (_, _) {});
  addTearDown(sub.close);
  await Future<void>.delayed(const Duration(milliseconds: 100));
}

Future<Set<int>> _storedNodeNums(NodeStorageService storage) async =>
    (await storage.loadNodes()).map((n) => n.nodeNum).toSet();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('removeNodes drops the nodes from state and from storage', () async {
    final env = await _buildContainer(
      storedNodes: [
        _node(1, daysAgo: 1),
        _node(2, daysAgo: 1),
        _node(3, daysAgo: 1),
      ],
    );
    addTearDown(env.container.dispose);
    await _activate(env.container);
    expect(env.container.read(nodesProvider).keys.toSet(), {1, 2, 3});

    env.container.read(nodesProvider.notifier).removeNodes({1, 3});
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(env.container.read(nodesProvider).keys.toSet(), {2});
    expect(await _storedNodeNums(env.storage), {2});

    // A fresh storage instance reads what the next launch would load.
    final relaunched = NodeStorageService();
    await relaunched.init();
    expect(await _storedNodeNums(relaunched), {2});
  });

  test('a removed node with a pending debounced save is not written back '
      'to storage', () async {
    final env = await _buildContainer(storedNodes: [_node(1, daysAgo: 1)]);
    addTearDown(env.container.dispose);
    await _activate(env.container);

    final notifier = env.container.read(nodesProvider.notifier);
    notifier.addOrUpdateNode(_node(5, daysAgo: 0));
    notifier.removeNodes({5});
    // Past the 2 s save debounce.
    await Future<void>.delayed(const Duration(milliseconds: 2300));

    expect(await _storedNodeNums(env.storage), {1});
  });

  test('ready clears nodes not heard for the chosen days and keeps the '
      'rest', () async {
    final env = await _buildContainer(
      storedNodes: [
        _node(1, daysAgo: 30),
        _node(2, daysAgo: 2),
        _node(3, daysAgo: 30, favourite: true),
        _node(4),
        _node(_myNodeNum, daysAgo: 30),
      ],
      purgeStaleNodeDays: 7,
    );
    addTearDown(env.container.dispose);
    await _activate(env.container);

    env.protocol.debugForceReadinessForTesting(OperationalReadiness.ready);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final kept = {2, 3, 4, _myNodeNum};
    expect(env.container.read(nodesProvider).keys.toSet(), kept);
    expect(await _storedNodeNums(env.storage), kept);
  });

  test('ready clears nothing while Clear Stale Nodes is off', () async {
    final env = await _buildContainer(
      storedNodes: [_node(1, daysAgo: 300), _node(2, daysAgo: 2)],
    );
    addTearDown(env.container.dispose);
    await _activate(env.container);

    env.protocol.debugForceReadinessForTesting(OperationalReadiness.ready);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(env.container.read(nodesProvider).keys.toSet(), {1, 2});
    expect(await _storedNodeNums(env.storage), {1, 2});
  });
}
