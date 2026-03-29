// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression tests for the "favourited gateway node intermittently vanishes
// from the Favourites section" bug.
//
// Root cause: isFavorite was managed via a separate DeviceFavoritesService
// (SharedPreferences sidecar) rather than living directly on the persisted
// MeshNode record. During NodesNotifier._init(), replaceAllFavorites() was
// called with whatever protocol.nodes contained at that moment. Because BLE
// streams the NodeDB incrementally, this snapshot was often PARTIAL — nodes
// whose NodeInfo hadn't arrived yet were simply absent, so their favourite
// status was silently wiped from the cache. The stream listener also ignored
// the device's authoritative isFavorite flag, always deferring to the cache.
//
// Fix (iOS CoreData pattern):
//   • isFavorite now lives directly on the MeshNode record (persisted by
//     NodeStorageService). No separate favourites cache is consulted.
//   • _init: stored nodes keep their persisted isFavorite; protocol merge
//     uses OR (node.isFavorite || existing.isFavorite) to avoid losing a
//     favourite when the protocol snapshot was built from a placeholder.
//   • Stream listener: uses the same OR rule so late-arriving NodeInfo
//     with isFavorite=true is honoured, and non-NodeInfo packets (which
//     preserve isFavorite via copyWith) never clobber a stored favourite.
//   • ProtocolService: immediately updates _nodes on set/removeFavoriteNode
//     so subsequent stream emissions carry the correct flag.
//   • No replaceAllFavorites call — there is no separate cache to reconcile.

import 'dart:async';

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

// ---------------------------------------------------------------------------
// Minimal fake transport – never connected, never sends data.
// ---------------------------------------------------------------------------

class _FakeTransport implements DeviceTransport {
  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

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

/// Builds a fully wired ProviderContainer with a fresh, empty
/// SharedPreferences store so tests are hermetically isolated.
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

  final identityStore = NodeIdentityStore();
  await identityStore.init();

  final protocol = ProtocolService(_FakeTransport());

  final container = ProviderContainer(
    overrides: [
      protocolServiceProvider.overrideWithValue(protocol),
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
    protocol: protocol,
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // iOS CoreData pattern: isFavorite lives on the MeshNode record
  // -------------------------------------------------------------------------

  group('_init: stored isFavorite survives partial NodeDB at connect time', () {
    test(
      'cached favourite survives when its NodeInfo has not arrived yet',
      () async {
        // AL_C_GT (0xA1C1) was a favourite last session — persisted directly
        // on the MeshNode in NodeStorageService (iOS CoreData pattern).
        const gatewayNum = 0xA1C1;
        const otherNum = 0xB2B2;

        final env = await _buildContainer(
          storedNodes: [
            MeshNode(
              nodeNum: gatewayNum,
              longName: 'AL_C-GT',
              isFavorite: true,
            ),
            MeshNode(nodeNum: otherNum, longName: 'OtherNode'),
          ],
        );
        addTearDown(env.container.dispose);

        // Simulate a partial NodeDB: only otherNode arrived before _init ran.
        // Its NodeInfo does NOT carry isFavorite=true.
        await _injectNodeInfo(
          env.protocol,
          nodeNum: otherNum,
          longName: 'OtherNode',
          shortName: 'OTH',
          isFavorite: false,
        );

        // Boot NodesNotifier — this triggers _init. Because isFavorite now
        // lives on the stored MeshNode (not in a separate cache), the
        // gateway's favourite status is preserved even though its NodeInfo
        // has not arrived yet.
        env.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final gatewayNode = env.container.read(nodesProvider)[gatewayNum];
        expect(
          gatewayNode?.isFavorite,
          isTrue,
          reason:
              'Gateway node should remain a favourite after init even when '
              'its NodeInfo was not in the partial NodeDB snapshot.',
        );
      },
    );

    test(
      'device-reported favourite is merged with stored favourite on init',
      () async {
        const deviceFavNum = 0xD1D1; // reported by device NodeDB
        const storedFavNum = 0xC2C2; // only in stored MeshNode

        final env = await _buildContainer(
          storedNodes: [
            MeshNode(nodeNum: deviceFavNum, longName: 'DeviceFav'),
            MeshNode(
              nodeNum: storedFavNum,
              longName: 'StoredFav',
              isFavorite: true,
            ),
          ],
        );
        addTearDown(env.container.dispose);

        // Inject NodeInfo for the device-reported favourite (isFavorite=true).
        await _injectNodeInfo(
          env.protocol,
          nodeNum: deviceFavNum,
          longName: 'DeviceFav',
          shortName: 'DFV',
          isFavorite: true,
        );

        env.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final nodes = env.container.read(nodesProvider);

        expect(
          nodes[deviceFavNum]?.isFavorite,
          isTrue,
          reason: 'Device-reported favourite must be marked in state.',
        );
        expect(
          nodes[storedFavNum]?.isFavorite,
          isTrue,
          reason:
              'Stored favourite must survive alongside device-reported ones.',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Stream listener: late-arriving NodeInfo with isFavorite=true
  // -------------------------------------------------------------------------

  group('late-arriving NodeInfo favourite sync (iOS CoreData pattern)', () {
    test(
      'NodeInfo with isFavorite=true arriving after init adds node to favourites',
      () async {
        const gatewayNum = 0xA1C1;
        const earlyNum = 0xE0E0;

        final env = await _buildContainer(
          storedNodes: [MeshNode(nodeNum: earlyNum, longName: 'EarlyNode')],
        );
        addTearDown(env.container.dispose);

        // Boot NodesNotifier with no favourites at all.
        env.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Now the gateway's NodeInfo arrives late (as happens when the device
        // sends NodeDB entries after the initial snapshot was taken).
        await _injectNodeInfo(
          env.protocol,
          nodeNum: gatewayNum,
          longName: 'AL_C-GT',
          shortName: 'ALGT',
          isFavorite: true,
        );

        final gatewayNode = env.container.read(nodesProvider)[gatewayNum];
        expect(gatewayNode, isNotNull, reason: 'Node must be registered.');
        expect(
          gatewayNode?.isFavorite,
          isTrue,
          reason:
              'Node arriving late with isFavorite=true must appear in '
              'the Favourites section.',
        );
      },
    );

    test(
      'NodeInfo with isFavorite=false does not add node to favourites',
      () async {
        const nodeNum = 0xF0F0;

        final env = await _buildContainer();
        addTearDown(env.container.dispose);

        env.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await _injectNodeInfo(
          env.protocol,
          nodeNum: nodeNum,
          longName: 'NotFavorite',
          shortName: 'NF',
          isFavorite: false,
        );

        final node = env.container.read(nodesProvider)[nodeNum];
        expect(
          node?.isFavorite,
          isFalse,
          reason: 'Non-favourite NodeInfo must not create a favourite entry.',
        );
      },
    );

    test('existing stored favourite remains favourite even when stream emits '
        'isFavorite=false (non-NodeInfo packet / placeholder)', () async {
      // Scenario: user had nodeA as a favourite (persisted on MeshNode).
      // The protocol service emits nodeA (e.g., from a position packet)
      // with isFavorite=false because the placeholder was created before
      // the device's NodeInfo arrived. The stored value must win via OR.
      const nodeNum = 0xCACA;

      final env = await _buildContainer(
        storedNodes: [
          MeshNode(nodeNum: nodeNum, longName: 'StoredFav', isFavorite: true),
        ],
      );
      addTearDown(env.container.dispose);

      env.container.read(nodesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // NodeInfo arrives with isFavorite=false (device hasn't confirmed yet
      // or this is a non-NodeDB packet that doesn't carry the flag).
      await _injectNodeInfo(
        env.protocol,
        nodeNum: nodeNum,
        longName: 'StoredFav',
        shortName: 'SFV',
        isFavorite: false,
      );

      final node = env.container.read(nodesProvider)[nodeNum];
      expect(
        node?.isFavorite,
        isTrue,
        reason:
            'A node that is favourite in the persisted MeshNode must stay '
            'favourite even when an incoming packet carries isFavorite=false '
            '(OR-preservation like iOS CoreData).',
      );
    });
  });

  // -------------------------------------------------------------------------
  // ProtocolService: immediate _nodes update on set/removeFavoriteNode
  // -------------------------------------------------------------------------

  group('ProtocolService._nodes cache updated immediately on admin commands', () {
    test('removeFavoriteNode updates _nodes so subsequent stream updates carry '
        'isFavorite=false', () async {
      final connectedTransport = _ConnectedFakeTransport();
      final protocol = ProtocolService(connectedTransport);

      // Inject a NodeInfo that sets the node as favourite in _nodes.
      const nodeNum = 0x1111;
      final fromRadio = pb.FromRadio(
        nodeInfo: pb.NodeInfo(
          num: nodeNum,
          isFavorite: true,
          user: pb.User()
            ..longName = 'GatewayNode'
            ..shortName = 'GWY',
        ),
      );
      await protocol.handleIncomingPacket(fromRadio.writeToBuffer());

      // Verify node is in the protocol cache as favourite.
      expect(protocol.nodes[nodeNum]?.isFavorite, isTrue);

      // Set the fake myNodeNum so the admin guard passes.
      connectedTransport.myNodeNum = 0x9999;
      final myFromRadio = pb.FromRadio(
        myInfo: pb.MyNodeInfo(myNodeNum: 0x9999),
      );
      await protocol.handleIncomingPacket(myFromRadio.writeToBuffer());

      // Call removeFavoriteNode — the fix ensures _nodes is updated instantly.
      await protocol.removeFavoriteNode(nodeNum);

      expect(
        protocol.nodes[nodeNum]?.isFavorite,
        isFalse,
        reason:
            'removeFavoriteNode must immediately set isFavorite=false in '
            'the protocol-layer node cache to prevent stale stream updates.',
      );
    });

    test('setFavoriteNode updates _nodes so subsequent stream updates carry '
        'isFavorite=true', () async {
      final connectedTransport = _ConnectedFakeTransport();
      final protocol = ProtocolService(connectedTransport);

      // Inject a non-favourite node.
      const nodeNum = 0x2222;
      final fromRadio = pb.FromRadio(
        nodeInfo: pb.NodeInfo(
          num: nodeNum,
          isFavorite: false,
          user: pb.User()
            ..longName = 'SomeNode'
            ..shortName = 'SN',
        ),
      );
      await protocol.handleIncomingPacket(fromRadio.writeToBuffer());

      expect(protocol.nodes[nodeNum]?.isFavorite, isFalse);

      connectedTransport.myNodeNum = 0x9999;
      final myFromRadio = pb.FromRadio(
        myInfo: pb.MyNodeInfo(myNodeNum: 0x9999),
      );
      await protocol.handleIncomingPacket(myFromRadio.writeToBuffer());

      await protocol.setFavoriteNode(nodeNum);

      expect(
        protocol.nodes[nodeNum]?.isFavorite,
        isTrue,
        reason:
            'setFavoriteNode must immediately set isFavorite=true in '
            'the protocol-layer node cache.',
      );
    });
  });

  // -------------------------------------------------------------------------
  // End-to-end: full scenario matching the user-reported bug
  // -------------------------------------------------------------------------

  group('end-to-end: gateway node intermittently absent from Favourites', () {
    test('AL_C-GT appears in Favourites after late NodeInfo even when init ran '
        'with a partial NodeDB that did not include it', () async {
      // --- Session setup ---
      // The user has gateway nodes marked favourite from a previous session.
      // They are stored in NodeStorage with isFavorite=true on the MeshNode
      // itself (iOS CoreData pattern — no separate cache).

      const gatewayA = 0xA1C0; // "AL_C-GT"
      const gatewayB = 0xA1C2; // "ALC1-GW"
      const activeNode = 0xBB01; // recently-active regular node

      final env = await _buildContainer(
        storedNodes: [
          MeshNode(nodeNum: gatewayA, longName: 'AL_C-GT', isFavorite: true),
          MeshNode(nodeNum: gatewayB, longName: 'ALC1-GW', isFavorite: true),
          MeshNode(nodeNum: activeNode, longName: 'ActiveNode'),
        ],
      );
      addTearDown(env.container.dispose);

      // --- Partial NodeDB arrives first (only active node, no gateways) ---
      await _injectNodeInfo(
        env.protocol,
        nodeNum: activeNode,
        longName: 'ActiveNode',
        shortName: 'ACT',
        isFavorite: false,
      );

      // Boot NodesNotifier. With the old code _init would call
      // replaceAllFavorites({}) wiping the gateway favourites.
      // With the iOS CoreData pattern the stored MeshNode.isFavorite
      // is the source of truth — no separate cache to corrupt.
      env.container.read(nodesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // --- Gateways' NodeInfo arrives late via BLE NodeDB stream ---
      await _injectNodeInfo(
        env.protocol,
        nodeNum: gatewayA,
        longName: 'AL_C-GT',
        shortName: 'ALGT',
        isFavorite: true,
      );
      await _injectNodeInfo(
        env.protocol,
        nodeNum: gatewayB,
        longName: 'ALC1-GW',
        shortName: 'AGWB',
        isFavorite: true,
      );

      final nodes = env.container.read(nodesProvider);

      expect(
        nodes[gatewayA]?.isFavorite,
        isTrue,
        reason: 'AL_C-GT must appear in the Favourites section.',
      );
      expect(
        nodes[gatewayB]?.isFavorite,
        isTrue,
        reason: 'ALC1-GW must appear in the Favourites section.',
      );
      expect(
        nodes[activeNode]?.isFavorite,
        isFalse,
        reason: 'Non-favourite active node must not be promoted.',
      );
    });

    test('favourites survive even when gateways never appear in protocol.nodes '
        'snapshot (zero NodeInfo at init time)', () async {
      // Edge case: app connects and _init runs before ANY NodeInfo arrives.
      // protocol.nodes is completely empty. With the old replaceAllFavorites
      // approach the favourites cache would NOT be wiped (guard:
      // protocolNodes.isNotEmpty), but with the iOS pattern we don't rely
      // on that guard at all — stored MeshNode.isFavorite is the truth.

      const gatewayNum = 0xA1C0;

      final env = await _buildContainer(
        storedNodes: [
          MeshNode(nodeNum: gatewayNum, longName: 'AL_C-GT', isFavorite: true),
        ],
      );
      addTearDown(env.container.dispose);

      // Boot with zero protocol nodes.
      env.container.read(nodesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final node = env.container.read(nodesProvider)[gatewayNum];
      expect(
        node?.isFavorite,
        isTrue,
        reason:
            'Stored favourite must survive init when protocol.nodes is empty.',
      );
    });
  });

  // -------------------------------------------------------------------------
  // DeviceFavoritesService is no longer consulted for isFavorite
  // -------------------------------------------------------------------------

  group('isFavorite is independent of DeviceFavoritesService cache', () {
    test('node stored with isFavorite=true shows as favourite even when '
        'DeviceFavoritesService cache is empty', () async {
      // The cache is intentionally empty — proving that the stored
      // MeshNode.isFavorite is the sole source of truth.
      const nodeNum = 0xAAAA;

      final env = await _buildContainer(
        storedNodes: [
          MeshNode(nodeNum: nodeNum, longName: 'NoCacheFav', isFavorite: true),
        ],
        cachedFavorites: const {}, // empty cache
      );
      addTearDown(env.container.dispose);

      env.container.read(nodesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final node = env.container.read(nodesProvider)[nodeNum];
      expect(
        node?.isFavorite,
        isTrue,
        reason:
            'Stored MeshNode.isFavorite=true must be honoured regardless '
            'of DeviceFavoritesService cache state.',
      );
    });

    test('node stored with isFavorite=false stays non-favourite even when '
        'DeviceFavoritesService cache says favourite', () async {
      // The cache says favourite, but the MeshNode says not favourite.
      // MeshNode is the source of truth — cache should be ignored.
      const nodeNum = 0xBBBB;

      final env = await _buildContainer(
        storedNodes: [
          MeshNode(
            nodeNum: nodeNum,
            longName: 'CacheOnlyFav',
            isFavorite: false,
          ),
        ],
        cachedFavorites: {nodeNum}, // cache says favourite
      );
      addTearDown(env.container.dispose);

      env.container.read(nodesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final node = env.container.read(nodesProvider)[nodeNum];
      expect(
        node?.isFavorite,
        isFalse,
        reason:
            'DeviceFavoritesService cache must NOT override the persisted '
            'MeshNode.isFavorite=false (iOS CoreData pattern).',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Transport that simulates a connected device (accepts sends without throwing).
// ---------------------------------------------------------------------------

class _ConnectedFakeTransport implements DeviceTransport {
  int? myNodeNum;
  final List<List<int>> sentPackets = [];

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
    sentPackets.add(data);
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
}
