// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression tests for the "unfavorited nodes come back on every reconnect"
// bug.
//
// Root cause: remove_favorite_node is a fire-and-forget local admin packet.
// When it is dropped (or the radio never persists its NodeDB to flash), the
// device keeps reporting is_favorite=true on reconnect, and the OR-merge in
// NodesNotifier (node.isFavorite || existing.isFavorite) resurrected the
// favourite locally with no way to ever turn it off.
//
// Fix: an explicit user unfavorite writes a tombstone
// (DeviceFavoritesService.addUnfavoriteTombstone). The merge paths AND the
// OR result with !tombstoned, so a stale device flag cannot resurrect the
// favourite. The tombstone clears when a device NodeDB replay confirms
// is_favorite=false (ProtocolService.onNodeDbFavoriteReported wired in
// protocolServiceProvider) or when the user re-favorites.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/nodes/node_identity_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

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

/// Builds a fully wired ProviderContainer with a fresh, empty
/// SharedPreferences store so tests are hermetically isolated.
///
/// When [useRealProtocolProvider] is true the real protocolServiceProvider
/// body runs (against a fake transport), which wires the production
/// onNodeDbFavoriteReported callback; otherwise a directly constructed
/// ProtocolService is injected via overrideWithValue.
Future<
  ({
    ProviderContainer container,
    ProtocolService protocol,
    NodeStorageService storage,
    DeviceFavoritesService favorites,
  })
>
_buildContainer({
  List<MeshNode> storedNodes = const [],
  Set<int> cachedFavorites = const {},
  Set<int> tombstones = const {},
  bool useRealProtocolProvider = false,
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

  final container = ProviderContainer(
    overrides: [
      if (useRealProtocolProvider) ...[
        transportProvider.overrideWithValue(_FakeTransport()),
        meshPacketDedupeStoreProvider.overrideWithValue(
          MeshPacketDedupeStore(dbPathOverride: ':memory:'),
        ),
      ] else
        protocolServiceProvider.overrideWithValue(
          ProtocolService(_FakeTransport()),
        ),
      nodeStorageProvider.overrideWith((ref) async => storage),
      deviceFavoritesProvider.overrideWith((ref) async => favService),
      nodeIdentityStoreProvider.overrideWith((ref) async => identityStore),
    ],
  );

  // Ensure all async providers are ready before touching nodesProvider.
  await container.read(nodeStorageProvider.future);
  await container.read(deviceFavoritesProvider.future);
  await container.read(nodeIdentityStoreProvider.future);

  return (
    container: container,
    protocol: container.read(protocolServiceProvider),
    storage: storage,
    favorites: favService,
  );
}

/// Injects a NodeInfo FromRadio packet into [protocol] and pumps the event
/// loop so the stream listener in NodesNotifier can process it.
Future<void> _injectNodeInfo(
  ProtocolService protocol, {
  required int nodeNum,
  required String longName,
  required String shortName,
  bool isFavorite = false,
}) async {
  final fromRadio = pb.FromRadio(
    nodeInfo: pb.NodeInfo(
      num: nodeNum,
      isFavorite: isFavorite,
      user: pb.User()
        ..longName = longName
        ..shortName = shortName,
    ),
  );
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
  // Allow NodesNotifier stream listener to process the emitted node.
  await Future<void>.delayed(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('_init merge: tombstone suppresses device-reported favourite', () {
    test('device NodeInfo isFavorite=true present at init stays unfavorited '
        'for a tombstoned node', () async {
      const nodeNum = 0xA1C1;

      final env = await _buildContainer(
        storedNodes: [MeshNode(nodeNum: nodeNum, longName: 'StaleFav')],
        tombstones: {nodeNum},
      );
      addTearDown(env.container.dispose);

      // Device NodeDB replays the stale favourite before init runs.
      await _injectNodeInfo(
        env.protocol,
        nodeNum: nodeNum,
        longName: 'StaleFav',
        shortName: 'SFV',
        isFavorite: true,
      );

      env.container.read(nodesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        env.container.read(nodesProvider)[nodeNum]?.isFavorite,
        isFalse,
        reason:
            'A tombstoned node must stay unfavorited even when the device '
            'NodeDB still reports is_favorite=true at connect time.',
      );
    });

    test('stored record already resurrected by the pre-fix bug is healed '
        'to unfavorited at init', () async {
      const nodeNum = 0xB2B2;

      final env = await _buildContainer(
        storedNodes: [
          // Legacy state: the pre-fix OR-merge re-persisted the stale
          // device favourite over the user's unfavorite.
          MeshNode(nodeNum: nodeNum, longName: 'Legacy', isFavorite: true),
        ],
        tombstones: {nodeNum},
      );
      addTearDown(env.container.dispose);

      env.container.read(nodesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        env.container.read(nodesProvider)[nodeNum]?.isFavorite,
        isFalse,
        reason:
            'A tombstone must heal a stored record that the pre-fix bug '
            'left marked as favourite.',
      );
    });

    test('device favourite for a node absent from storage is suppressed '
        'when tombstoned (new-node merge branch)', () async {
      const nodeNum = 0xC3C3;

      final env = await _buildContainer(tombstones: {nodeNum});
      addTearDown(env.container.dispose);

      await _injectNodeInfo(
        env.protocol,
        nodeNum: nodeNum,
        longName: 'NotStored',
        shortName: 'NST',
        isFavorite: true,
      );

      env.container.read(nodesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        env.container.read(nodesProvider)[nodeNum]?.isFavorite,
        isFalse,
        reason:
            'The new-node merge branch must also honour the tombstone when '
            'the device replays a favourite for a node not in storage.',
      );
    });
  });

  group('stream listener: tombstone suppresses late device favourite', () {
    test('NodeInfo isFavorite=true arriving after init stays unfavorited '
        'for a tombstoned node', () async {
      const tombstonedNum = 0xD4D4;
      const storedFavNum = 0xE5E5;

      final env = await _buildContainer(
        storedNodes: [
          MeshNode(
            nodeNum: storedFavNum,
            longName: 'RealFav',
            isFavorite: true,
          ),
        ],
        tombstones: {tombstonedNum},
      );
      addTearDown(env.container.dispose);

      env.container.read(nodesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Stale device favourite arrives late for the tombstoned node.
      await _injectNodeInfo(
        env.protocol,
        nodeNum: tombstonedNum,
        longName: 'StaleFav',
        shortName: 'SFV',
        isFavorite: true,
      );
      // OR regression guard: a placeholder-style emission with
      // isFavorite=false must not clobber the non-tombstoned stored
      // favourite.
      await _injectNodeInfo(
        env.protocol,
        nodeNum: storedFavNum,
        longName: 'RealFav',
        shortName: 'RFV',
        isFavorite: false,
      );

      final nodes = env.container.read(nodesProvider);
      expect(
        nodes[tombstonedNum]?.isFavorite,
        isFalse,
        reason:
            'A late device is_favorite=true must not resurrect a '
            'tombstoned unfavorite.',
      );
      expect(
        nodes[storedFavNum]?.isFavorite,
        isTrue,
        reason:
            'The placeholder-protection OR must keep working for '
            'non-tombstoned nodes.',
      );
    });
  });

  group('setNodeFavorite lifecycle', () {
    test(
      'unfavorite tombstones the node and updates sidecar + state',
      () async {
        const nodeNum = 0xF6F6;

        final env = await _buildContainer(
          storedNodes: [
            MeshNode(nodeNum: nodeNum, longName: 'Fav', isFavorite: true),
          ],
          cachedFavorites: {nodeNum},
        );
        addTearDown(env.container.dispose);

        env.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        await env.container
            .read(nodesProvider.notifier)
            .setNodeFavorite(nodeNum, false);

        expect(env.container.read(nodesProvider)[nodeNum]?.isFavorite, isFalse);
        expect(env.favorites.isTombstoned(nodeNum), isTrue);
        expect(env.favorites.favorites.contains(nodeNum), isFalse);
      },
    );

    test(
      're-favorite clears the tombstone and restores sidecar + state',
      () async {
        const nodeNum = 0xA7A7;

        final env = await _buildContainer(
          storedNodes: [MeshNode(nodeNum: nodeNum, longName: 'Node')],
          tombstones: {nodeNum},
        );
        addTearDown(env.container.dispose);

        env.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        await env.container
            .read(nodesProvider.notifier)
            .setNodeFavorite(nodeNum, true);

        expect(env.container.read(nodesProvider)[nodeNum]?.isFavorite, isTrue);
        expect(env.favorites.isTombstoned(nodeNum), isFalse);
        expect(env.favorites.favorites.contains(nodeNum), isTrue);
      },
    );
  });

  group('device confirmation clears the tombstone (production wiring)', () {
    test('NodeDB replay with is_favorite=false clears the tombstone, and a '
        'later is_favorite=true is honoured again', () async {
      const nodeNum = 0xB8B8;

      final env = await _buildContainer(
        storedNodes: [MeshNode(nodeNum: nodeNum, longName: 'Node')],
        tombstones: {nodeNum},
        useRealProtocolProvider: true,
      );
      addTearDown(env.container.dispose);

      env.container.read(nodesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Device confirms the unfavorite in its NodeDB replay.
      await _injectNodeInfo(
        env.protocol,
        nodeNum: nodeNum,
        longName: 'Node',
        shortName: 'NDE',
        isFavorite: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        env.favorites.isTombstoned(nodeNum),
        isFalse,
        reason:
            'A device NodeDB replay reporting is_favorite=false must '
            'clear the pending tombstone.',
      );
      expect(env.container.read(nodesProvider)[nodeNum]?.isFavorite, isFalse);

      // The node is re-favorited externally (e.g. another app). With the
      // tombstone confirmed and cleared, the favourite must be honoured.
      await _injectNodeInfo(
        env.protocol,
        nodeNum: nodeNum,
        longName: 'Node',
        shortName: 'NDE',
        isFavorite: true,
      );
      // Non-structural updates to existing nodes coalesce for 250ms
      // before committing to state; wait out the window.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(
        env.container.read(nodesProvider)[nodeNum]?.isFavorite,
        isTrue,
        reason:
            'After the device confirms the unfavorite, an external '
            're-favorite must flow through again.',
      );
    });

    test(
      'NodeDB replay with is_favorite=true does not clear the tombstone',
      () async {
        const nodeNum = 0xC9C9;

        final env = await _buildContainer(
          tombstones: {nodeNum},
          useRealProtocolProvider: true,
        );
        addTearDown(env.container.dispose);

        env.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        await _injectNodeInfo(
          env.protocol,
          nodeNum: nodeNum,
          longName: 'Stale',
          shortName: 'STL',
          isFavorite: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          env.favorites.isTombstoned(nodeNum),
          isTrue,
          reason:
              'A stale is_favorite=true replay must leave the tombstone in '
              'place so the unfavorite keeps being enforced.',
        );
        expect(env.container.read(nodesProvider)[nodeNum]?.isFavorite, isFalse);
      },
    );
  });
}
