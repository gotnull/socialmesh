// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression test for critical bug: node count collapsing after app restart.
//
// Root cause: `clearDeviceDataBeforeConnect` was wiping both in-memory and
// persistent node storage before every reconnection. The device only sends
// back its limited NodeDB (~80 nodes), so nodes discovered via mesh traffic
// during the previous session were permanently lost.
//
// Fix: `clearDeviceDataBeforeConnect` now preserves nodes by default
// (clearNodeData: false). Only explicit device-forget paths pass
// clearNodeData: true.
//
// This test verifies that nodes survive the reconnect clear cycle and that
// the device's NodeDB merges on top of persisted nodes without losing any.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/nodes/node_identity_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

// ---------------------------------------------------------------------------
// Minimal fake transport for provider wiring
// ---------------------------------------------------------------------------
class _FakeTransport implements DeviceTransport {
  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  @override
  DeviceConnectionState get state => DeviceConnectionState.disconnected;

  @override
  bool get isConnected => false;

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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Create a minimal [MeshNode] with a given [nodeNum] and optional name.
MeshNode _node(int nodeNum, {String? longName, DateTime? lastHeard}) {
  return MeshNode(
    nodeNum: nodeNum,
    longName: longName ?? 'Node_${nodeNum.toRadixString(16)}',
    lastHeard: lastHeard ?? DateTime.now(),
  );
}

/// Seed [storage] with [count] nodes numbered starting from [startNum].
/// Returns the list of saved nodes.
Future<List<MeshNode>> _seedNodes(
  NodeStorageService storage, {
  required int count,
  int startNum = 1,
}) async {
  final nodes = <MeshNode>[];
  for (var i = 0; i < count; i++) {
    nodes.add(_node(startNum + i));
  }
  await storage.saveNodes(nodes);
  return nodes;
}

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

class _Harness {
  _Harness({
    required this.storage,
    required this.identityStore,
    required this.protocol,
    required this.container,
  });

  final NodeStorageService storage;
  final NodeIdentityStore identityStore;
  final ProtocolService protocol;
  final ProviderContainer container;
}

Future<_Harness> _createHarness() async {
  SharedPreferences.setMockInitialValues({});
  final storage = NodeStorageService();
  await storage.init();
  final identityStore = NodeIdentityStore();
  await identityStore.init();
  final protocol = ProtocolService(_FakeTransport());

  final container = ProviderContainer(
    overrides: [
      protocolServiceProvider.overrideWithValue(protocol),
      nodeStorageProvider.overrideWith((ref) async => storage),
      deviceFavoritesProvider.overrideWith((ref) async {
        final service = DeviceFavoritesService();
        await service.init();
        return service;
      }),
      nodeIdentityStoreProvider.overrideWith((ref) async => identityStore),
    ],
  );

  // Wait for async providers to stabilise
  await container.read(nodeStorageProvider.future);
  await container.read(deviceFavoritesProvider.future);
  await container.read(nodeIdentityStoreProvider.future);

  return _Harness(
    storage: storage,
    identityStore: identityStore,
    protocol: protocol,
    container: container,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Node reconnect persistence (regression)', () {
    test(
      'clearDeviceDataBeforeConnect (default) preserves nodes in storage',
      () async {
        final h = await _createHarness();
        addTearDown(h.container.dispose);

        // Seed 150 nodes to simulate a long session
        await _seedNodes(h.storage, count: 150);
        final beforeClear = await h.storage.loadNodes();
        expect(beforeClear, hasLength(150));

        // Initialise NodesNotifier so it loads from storage
        h.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(
          h.container.read(nodesProvider).length,
          150,
          reason: 'All 150 nodes should be in memory after init',
        );

        // Simulate reconnect — default clearNodeData: false
        // We cannot call the WidgetRef version in a unit test, so replicate
        // the exact operations that clearDeviceDataBeforeConnectRef performs
        // when clearNodeData is false (the default for reconnect paths).

        // Channels are always cleared:
        h.container.read(channelsProvider.notifier).clearChannels();
        // New-nodes badge reset:
        h.container.read(newNodesCountProvider.notifier).reset();
        // NOTE: nodesProvider.notifier.clearNodes() is NOT called.
        // NOTE: nodeStorage.clearNodes() is NOT called.

        // Verify in-memory nodes are still present
        expect(
          h.container.read(nodesProvider).length,
          150,
          reason:
              'Reconnect with default clearNodeData should preserve in-memory nodes',
        );

        // Verify persistent storage is still intact
        final afterClear = await h.storage.loadNodes();
        expect(
          afterClear,
          hasLength(150),
          reason:
              'Reconnect with default clearNodeData should preserve stored nodes',
        );
      },
    );

    test(
      'clearDeviceDataBeforeConnect with clearNodeData: true wipes all nodes',
      () async {
        final h = await _createHarness();
        addTearDown(h.container.dispose);

        await _seedNodes(h.storage, count: 150);

        h.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(h.container.read(nodesProvider).length, 150);

        // Simulate forget-device path — clearNodeData: true
        h.container.read(nodesProvider.notifier).clearNodes();
        h.container.read(channelsProvider.notifier).clearChannels();
        h.container.read(newNodesCountProvider.notifier).reset();
        // Also clear persistent storage (as the real code does with clearNodeData: true):
        await h.storage.clearNodes();

        expect(
          h.container.read(nodesProvider).length,
          0,
          reason: 'Forget-device should wipe all in-memory nodes',
        );

        final afterWipe = await h.storage.loadNodes();
        expect(
          afterWipe,
          hasLength(0),
          reason: 'Forget-device should wipe all persisted nodes',
        );
      },
    );

    test(
      'protocol stream updates merge on top of preserved nodes without loss',
      () async {
        final h = await _createHarness();
        addTearDown(h.container.dispose);

        // Seed 150 nodes — simulates accumulated session knowledge
        final seeded = await _seedNodes(h.storage, count: 150);

        h.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(h.container.read(nodesProvider).length, 150);

        // Simulate device re-sending its NodeDB (only first 80 nodes)
        // via the protocol node stream. This mirrors what happens when
        // protocol.start() re-fetches from the connected device.
        for (var i = 0; i < 80; i++) {
          final updated = seeded[i].copyWith(
            lastHeard: DateTime.now(),
            batteryLevel: 90,
          );
          h.container.read(nodesProvider.notifier).addOrUpdateNode(updated);
        }

        await Future<void>.delayed(const Duration(milliseconds: 100));

        final nodes = h.container.read(nodesProvider);
        expect(
          nodes.length,
          150,
          reason:
              'After device sends 80-node NodeDB, all 150 nodes should still be present '
              '(80 updated + 70 untouched)',
        );

        // Verify the 80 updated nodes got fresh data
        expect(nodes[1]?.batteryLevel, 90);

        // Verify the nodes beyond the device NodeDB are still present
        expect(nodes[81], isNotNull, reason: 'Node 81 should survive');
        expect(nodes[150], isNotNull, reason: 'Node 150 should survive');
      },
    );

    test(
      'storage round-trip preserves node count across simulated restart',
      () async {
        final h = await _createHarness();
        addTearDown(h.container.dispose);

        // Session 1: accumulate 150 nodes
        await _seedNodes(h.storage, count: 150);
        h.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(h.container.read(nodesProvider).length, 150);

        // Verify storage has all 150
        final stored = await h.storage.loadNodes();
        expect(stored, hasLength(150));

        // Session 2: create a fresh container (simulates cold app restart)
        // Re-use the same storage instance (same SharedPreferences backing)
        final container2 = ProviderContainer(
          overrides: [
            protocolServiceProvider.overrideWithValue(
              ProtocolService(_FakeTransport()),
            ),
            nodeStorageProvider.overrideWith((ref) async => h.storage),
            deviceFavoritesProvider.overrideWith((ref) async {
              final service = DeviceFavoritesService();
              await service.init();
              return service;
            }),
            nodeIdentityStoreProvider.overrideWith(
              (ref) async => h.identityStore,
            ),
          ],
        );
        addTearDown(container2.dispose);

        await container2.read(nodeStorageProvider.future);
        await container2.read(deviceFavoritesProvider.future);
        await container2.read(nodeIdentityStoreProvider.future);

        // NodesNotifier._init() should load all 150 from storage
        container2.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(
          container2.read(nodesProvider).length,
          150,
          reason:
              'After cold restart, all 150 nodes should be restored from storage',
        );
      },
    );

    test(
      'new nodes discovered via mesh traffic are persisted and survive restart',
      () async {
        final h = await _createHarness();
        addTearDown(h.container.dispose);

        // Start with 80 nodes from device NodeDB
        await _seedNodes(h.storage, count: 80);
        h.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(h.container.read(nodesProvider).length, 80);

        // Simulate discovering 70 more nodes via mesh traffic
        for (var i = 81; i <= 150; i++) {
          h.container
              .read(nodesProvider.notifier)
              .addOrUpdateNode(_node(i, longName: 'MeshDiscovered_$i'));
        }

        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(h.container.read(nodesProvider).length, 150);

        // Flush any pending saves by waiting for debounce
        await Future<void>.delayed(const Duration(seconds: 3));

        // Verify all 150 are persisted
        final stored = await h.storage.loadNodes();
        expect(
          stored.length,
          150,
          reason: 'All 150 nodes (80 device + 70 mesh) should be persisted',
        );

        // Verify specific mesh-discovered nodes are in storage
        final meshNode = stored.firstWhere(
          (n) => n.nodeNum == 100,
          orElse: () => throw StateError('Node 100 not found in storage'),
        );
        expect(meshNode.longName, 'MeshDiscovered_100');
      },
    );

    test(
      'new-nodes badge does not inflate on reconnect when nodes already exist',
      () async {
        final h = await _createHarness();
        addTearDown(h.container.dispose);

        // Seed nodes
        await _seedNodes(h.storage, count: 80);
        h.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 150));

        // Reset badge (as clearDeviceDataBeforeConnect does)
        h.container.read(newNodesCountProvider.notifier).reset();
        expect(h.container.read(newNodesCountProvider), 0);

        // Re-send existing nodes (simulates device NodeDB dump after reconnect)
        for (var i = 1; i <= 80; i++) {
          h.container
              .read(nodesProvider.notifier)
              .addOrUpdateNode(_node(i).copyWith(lastHeard: DateTime.now()));
        }

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Badge should NOT have incremented — these are all known nodes
        // (addOrUpdateNode goes through the same merge path as the stream
        // listener, which only increments for genuinely new nodeNums)
        expect(
          h.container.read(newNodesCountProvider),
          0,
          reason:
              'Re-sending known nodes after reconnect should not inflate the new-nodes badge',
        );
      },
    );
  });
}
