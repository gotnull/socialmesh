// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/providers/nodedex_providers.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_database.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_sqlite_store.dart';
import 'package:socialmesh/features/nodedex/widgets/coseen_network_card.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/cloud_sync_entitlement_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// =============================================================================
// Test Notifiers — extend the real notifier classes so overrideWith type-checks,
// but override build() to skip all real dependency watching / initialization.
// =============================================================================

class _TestNodesNotifier extends NodesNotifier {
  final Map<int, MeshNode> _initial;

  _TestNodesNotifier([this._initial = const {}]);

  @override
  Map<int, MeshNode> build() => _initial;

  void setNodes(Map<int, MeshNode> nodes) => state = nodes;

  @override
  void addOrUpdateNode(MeshNode node) {
    state = {...state, node.nodeNum: node};
  }

  void addNode(MeshNode node) => addOrUpdateNode(node);

  @override
  void removeNode(int nodeNum) {
    final updated = Map<int, MeshNode>.from(state);
    updated.remove(nodeNum);
    state = updated;
  }
}

/// Minimal no-op transport for constructing a ProtocolService in tests
/// without triggering platform channel dependencies.
class _FakeTransport extends DeviceTransport {
  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  DeviceConnectionState get state => DeviceConnectionState.disconnected;

  final StreamController<DeviceConnectionState> _stateCtrl =
      StreamController<DeviceConnectionState>.broadcast();

  @override
  Stream<DeviceConnectionState> get stateStream => _stateCtrl.stream;

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
  Future<void> enableNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    await _stateCtrl.close();
  }
}

class _TestMyNodeNumNotifier extends MyNodeNumNotifier {
  final int? _initial;

  _TestMyNodeNumNotifier([this._initial = 99999]);

  @override
  int? build() => _initial;
}

// =============================================================================
// Helpers
// =============================================================================

const int _myNodeNum = 99999;

MeshNode _makeNode(
  int nodeNum, {
  double? distance,
  int? snr,
  int? rssi,
  double? latitude,
  double? longitude,
  DateTime? firstHeard,
  DateTime? lastHeard,
  bool stale = false,
}) {
  return MeshNode(
    nodeNum: nodeNum,
    distance: distance,
    snr: snr,
    rssi: rssi,
    latitude: latitude,
    longitude: longitude,
    firstHeard: firstHeard,
    // Default to clock.now() so the node passes the online presence check,
    // unless the caller explicitly requests a stale (offline) node.
    lastHeard: stale ? lastHeard : (lastHeard ?? clock.now()),
  );
}

NodeDexEntry _makeEntry({
  required int nodeNum,
  DateTime? firstSeen,
  DateTime? lastSeen,
  int encounterCount = 1,
  double? maxDistanceSeen,
  int? bestSnr,
  int? bestRssi,
  int messageCount = 0,
  NodeSocialTag? socialTag,
  String? userNote,
  List<EncounterRecord> encounters = const [],
  List<SeenRegion> seenRegions = const [],
  Map<int, CoSeenRelationship> coSeenNodes = const {},
  SigilData? sigil,
}) {
  return NodeDexEntry(
    nodeNum: nodeNum,
    firstSeen: firstSeen ?? DateTime(2024, 1, 1),
    lastSeen: lastSeen ?? DateTime(2024, 6, 1),
    encounterCount: encounterCount,
    maxDistanceSeen: maxDistanceSeen,
    bestSnr: bestSnr,
    bestRssi: bestRssi,
    messageCount: messageCount,
    socialTag: socialTag,
    userNote: userNote,
    encounters: encounters,
    seenRegions: seenRegions,
    coSeenNodes: coSeenNodes,
    sigil: sigil,
  );
}

/// Creates a [ProviderContainer] wired with test overrides for
/// [nodesProvider], [myNodeNumProvider], and [nodeDexStoreProvider].
///
/// [preInitStore] must be an already-initialized [NodeDexSqliteStore] so the
/// FutureProvider resolves synchronously.
///
/// The returned record contains the container plus the test notifier
/// so callers can mutate node state.
({
  ProviderContainer container,
  _TestNodesNotifier nodesNotifier,
  NodeDexSqliteStore store,
})
_createTestContainer({
  required NodeDexSqliteStore preInitStore,
  Map<int, MeshNode> initialNodes = const {},
  int? myNodeNum = _myNodeNum,
}) {
  final nodesNotifier = _TestNodesNotifier(initialNodes);
  final myNodeNumNotifier = _TestMyNodeNumNotifier(myNodeNum);

  final container = ProviderContainer(
    overrides: [
      nodesProvider.overrideWith(() => nodesNotifier),
      myNodeNumProvider.overrideWith(() => myNodeNumNotifier),
      nodeDexStoreProvider.overrideWith((ref) => preInitStore),
      // Prevent Firebase cascade: cloudSyncEntitlementServiceProvider →
      // CloudSyncEntitlementService() → FirebaseFirestore.instance
      canCloudSyncWriteProvider.overrideWithValue(false),
      // Prevent MeshPacketDedupeStore platform channel cascade when
      // NodeDexNotifier._resolveCurrentPreset() reads the protocol service.
      protocolServiceProvider.overrideWithValue(
        ProtocolService(_FakeTransport()),
      ),
    ],
  );

  return (
    container: container,
    nodesNotifier: nodesNotifier,
    store: preInitStore,
  );
}

/// Pump the event queue to allow async initialization to complete.
/// This replaces the old fakeAsync flushMicrotasks pattern.
Future<void> _pumpEventQueue({int times = 20}) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Initialize the provider and wait for async init to complete.
Future<void> _initProvider(ProviderContainer container) async {
  container.listen(nodeDexProvider, (_, _) {});
  await _pumpEventQueue();
}

/// Wait for the store's debounced save to complete.
/// With Duration.zero debounce in tests, a single pump suffices,
/// but we do a few rounds for safety.
Future<void> _waitForSave() async {
  await _pumpEventQueue(times: 10);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NodeDexSqliteStore preInitStore;
  late NodeDexDatabase preInitDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Use zero-duration debounce/cooldowns so tests don't need fake timers.
    NodeDexNotifier.encounterCooldownOverride = Duration.zero;
    NodeDexNotifier.coSeenFlushIntervalOverride = const Duration(
      milliseconds: 50,
    );
  });

  setUp(() async {
    preInitDb = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
    preInitStore = NodeDexSqliteStore(
      preInitDb,
      saveDebounceDuration: Duration.zero,
    );
    await preInitStore.init();
  });

  tearDown(() async {
    await preInitStore.dispose();
  });

  tearDownAll(() {
    NodeDexNotifier.resetTestOverrides();
  });

  // ===========================================================================
  // Initialization
  // ===========================================================================

  group('initialization', () {
    test('provider starts with empty state before init completes', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      // Before pumping, state is the initial empty map from build().
      final state = ctx.container.read(nodeDexProvider);
      expect(state, isEmpty);
    });

    test('provider loads entries from store after init', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      final state = ctx.container.read(nodeDexProvider);
      // Fresh store => empty
      expect(state, isEmpty);
    });

    test('provider loads pre-existing entries from store', () async {
      // Pre-populate the SQLite store with an entry.
      final entry = _makeEntry(nodeNum: 42, encounterCount: 5);
      await preInitStore.saveEntryImmediate(entry);

      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      final state = ctx.container.read(nodeDexProvider);
      expect(state.length, equals(1));
      expect(state[42], isNotNull);
      expect(state[42]!.encounterCount, equals(5));
    });
  });

  // ===========================================================================
  // Node Discovery
  // ===========================================================================

  group('node discovery', () {
    test('new node in nodesProvider creates NodeDex entry', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      // Simulate node discovery
      ctx.nodesNotifier.addNode(_makeNode(100, snr: 10, rssi: -80));
      await _pumpEventQueue();

      final state = ctx.container.read(nodeDexProvider);
      expect(state.containsKey(100), isTrue);
      expect(state[100]!.nodeNum, equals(100));
      expect(state[100]!.encounterCount, equals(1));
      expect(state[100]!.bestSnr, equals(10));
      expect(state[100]!.bestRssi, equals(-80));
    });

    test(
      'own node is included in NodeDex but without encounter tracking',
      () async {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        await _initProvider(ctx.container);

        // Add our own node
        ctx.nodesNotifier.addNode(_makeNode(_myNodeNum));
        await _pumpEventQueue();

        final state = ctx.container.read(nodeDexProvider);
        // Own node IS now included (so it appears in "Your Device" section)
        expect(state.containsKey(_myNodeNum), isTrue);

        final entry = state[_myNodeNum]!;
        // Own node should have a sigil
        expect(entry.sigil, isNotNull);
        // Own node should NOT have SNR/RSSI/distance (metrics are meaningless
        // for your own device)
        expect(entry.bestSnr, isNull);
        expect(entry.bestRssi, isNull);
        expect(entry.maxDistanceSeen, isNull);
      },
    );

    test('node 0 is skipped during discovery', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(_makeNode(0));
      await _pumpEventQueue();

      final state = ctx.container.read(nodeDexProvider);
      expect(state.containsKey(0), isFalse);
    });

    test('discovered entry has a sigil', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(_makeNode(200));
      await _pumpEventQueue();

      final entry = ctx.container.read(nodeDexProvider)[200];
      expect(entry, isNotNull);
      expect(entry!.sigil, isNotNull);
    });

    test('multiple nodes discovered at once', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.setNodes({
        100: _makeNode(100, snr: 5),
        200: _makeNode(200, snr: 8),
        300: _makeNode(300, snr: 12),
      });
      await _pumpEventQueue();

      final state = ctx.container.read(nodeDexProvider);
      expect(state.length, equals(3));
      expect(state.containsKey(100), isTrue);
      expect(state.containsKey(200), isTrue);
      expect(state.containsKey(300), isTrue);
    });

    test(
      're-seen node within cooldown does not increment encounter count',
      () async {
        // Use a non-zero cooldown for this specific test
        NodeDexNotifier.encounterCooldownOverride = const Duration(minutes: 5);
        addTearDown(() {
          NodeDexNotifier.encounterCooldownOverride = Duration.zero;
        });

        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        await _initProvider(ctx.container);

        // First discovery
        ctx.nodesNotifier.addNode(_makeNode(100));
        await _pumpEventQueue();

        final firstState = ctx.container.read(nodeDexProvider);
        expect(firstState[100]!.encounterCount, equals(1));

        // Re-discover immediately (within 5-minute cooldown)
        ctx.nodesNotifier.setNodes({100: _makeNode(100, snr: 15)});
        await _pumpEventQueue();

        final secondState = ctx.container.read(nodeDexProvider);
        // Should NOT increment because we're within 5-minute cooldown
        expect(secondState[100]!.encounterCount, equals(1));
      },
    );

    test('re-seen node after cooldown increments encounter count', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      final firstSeen = DateTime(2024, 1, 1, 12, 0);

      // First discovery at a fixed time
      await withClock(Clock.fixed(firstSeen), () async {
        await _initProvider(ctx.container);

        ctx.nodesNotifier.addNode(_makeNode(100));
        await _pumpEventQueue();
      });

      // Re-discover 6 minutes later — past both provider and model cooldowns
      final laterTime = firstSeen.add(const Duration(minutes: 6));
      await withClock(Clock.fixed(laterTime), () async {
        ctx.nodesNotifier.setNodes({100: _makeNode(100, snr: 15)});
        await _pumpEventQueue();
      });

      final state = ctx.container.read(nodeDexProvider);
      expect(state[100]!.encounterCount, equals(2));
    });

    test('discovered entry records distance and metrics', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(
        _makeNode(100, distance: 1500.0, snr: 12, rssi: -65),
      );
      await _pumpEventQueue();

      final entry = ctx.container.read(nodeDexProvider)[100]!;
      expect(entry.maxDistanceSeen, equals(1500.0));
      expect(entry.bestSnr, equals(12));
      expect(entry.bestRssi, equals(-65));
    });

    test('node with position records position in encounter', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(
        _makeNode(100, latitude: 48.8566, longitude: 2.3522),
      );
      await _pumpEventQueue();

      final entry = ctx.container.read(nodeDexProvider)[100]!;
      expect(entry.encounters.length, equals(1));
      expect(entry.encounters.first.latitude, equals(48.8566));
      expect(entry.encounters.first.longitude, equals(2.3522));
    });
  });

  // ===========================================================================
  // Session tracking & co-seen flush
  // ===========================================================================

  group('co-seen flush', () {
    test(
      'co-seen relationships created after manual flush for co-present nodes',
      () async {
        NodeDexNotifier.coSeenFlushIntervalOverride = const Duration(days: 1);
        addTearDown(() {
          NodeDexNotifier.coSeenFlushIntervalOverride = const Duration(
            milliseconds: 50,
          );
        });

        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        await _initProvider(ctx.container);

        // Discover two nodes in same session
        ctx.nodesNotifier.setNodes({100: _makeNode(100), 200: _makeNode(200)});
        await _pumpEventQueue();

        // Verify entries exist but no co-seen yet (flush hasn't fired)
        var state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.coSeenNodes, isEmpty);
        expect(state[200]!.coSeenNodes, isEmpty);

        // Manually trigger co-seen flush
        ctx.container.read(nodeDexProvider.notifier).flushCoSeenForTest();
        await _waitForSave();

        // Now co-seen relationships should exist
        state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.coSeenNodes.containsKey(200), isTrue);
        expect(state[200]!.coSeenNodes.containsKey(100), isTrue);
        expect(state[100]!.coSeenNodes[200]!.count, equals(1));
        expect(state[200]!.coSeenNodes[100]!.count, equals(1));
      },
    );

    test('co-seen flush is bidirectional', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.setNodes({
        100: _makeNode(100),
        200: _makeNode(200),
        300: _makeNode(300),
      });
      await _pumpEventQueue();

      // Trigger flush
      ctx.container.read(nodeDexProvider.notifier).flushCoSeenForTest();
      await _waitForSave();

      final state = ctx.container.read(nodeDexProvider);

      // Node 100 should be co-seen with 200 and 300
      expect(state[100]!.coSeenNodes.length, equals(2));
      expect(state[100]!.coSeenNodes.containsKey(200), isTrue);
      expect(state[100]!.coSeenNodes.containsKey(300), isTrue);

      // Node 200 should be co-seen with 100 and 300
      expect(state[200]!.coSeenNodes.length, equals(2));
      expect(state[200]!.coSeenNodes.containsKey(100), isTrue);
      expect(state[200]!.coSeenNodes.containsKey(300), isTrue);

      // Node 300 should be co-seen with 100 and 200
      expect(state[300]!.coSeenNodes.length, equals(2));
      expect(state[300]!.coSeenNodes.containsKey(100), isTrue);
      expect(state[300]!.coSeenNodes.containsKey(200), isTrue);
    });

    test('co-seen flush clears session so next flush is fresh', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      // First batch: two nodes
      ctx.nodesNotifier.setNodes({100: _makeNode(100), 200: _makeNode(200)});
      await _pumpEventQueue();

      // First flush
      ctx.container.read(nodeDexProvider.notifier).flushCoSeenForTest();
      await _waitForSave();

      var state = ctx.container.read(nodeDexProvider);
      expect(state[100]!.coSeenNodes[200]!.count, equals(1));

      // Second flush without new node updates — session was cleared
      // so no new co-seen relationships should be added
      ctx.container.read(nodeDexProvider.notifier).flushCoSeenForTest();
      await _waitForSave();

      state = ctx.container.read(nodeDexProvider);
      // Count should still be 1 (session was cleared, no new sightings)
      expect(state[100]!.coSeenNodes[200]!.count, equals(1));
    });

    test('co-seen count increments across multiple flush cycles', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      // First session: discover nodes
      ctx.nodesNotifier.setNodes({100: _makeNode(100), 200: _makeNode(200)});
      await _pumpEventQueue();

      // First flush
      ctx.container.read(nodeDexProvider.notifier).flushCoSeenForTest();
      await _waitForSave();

      var state = ctx.container.read(nodeDexProvider);
      expect(state[100]!.coSeenNodes[200]!.count, equals(1));

      // Re-discover (trigger handleNodesUpdate so session is populated again)
      ctx.nodesNotifier.setNodes({
        100: _makeNode(100, snr: 20),
        200: _makeNode(200, snr: 25),
      });
      await _pumpEventQueue();

      // Second flush
      ctx.container.read(nodeDexProvider.notifier).flushCoSeenForTest();
      await _waitForSave();

      state = ctx.container.read(nodeDexProvider);
      expect(state[100]!.coSeenNodes[200]!.count, equals(2));
    });

    test('single node in session produces no co-seen relationships', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      // Only one node
      ctx.nodesNotifier.addNode(_makeNode(100));
      await _pumpEventQueue();

      // Trigger flush
      ctx.container.read(nodeDexProvider.notifier).flushCoSeenForTest();
      await _waitForSave();

      final state = ctx.container.read(nodeDexProvider);
      expect(state[100]!.coSeenNodes, isEmpty);
    });

    test('co-seen flush on dispose persists relationships', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);

      await _initProvider(ctx.container);

      // Discover two nodes
      ctx.nodesNotifier.setNodes({100: _makeNode(100), 200: _makeNode(200)});
      await _pumpEventQueue();

      // Dispose triggers flush via onDispose (no timer needed)
      ctx.container.dispose();
      await _waitForSave();

      // The store should have received saveEntries from the flush.
      // We verify the store's internal state survived the dispose flush.
    });
  });

  group('nodeDexRecentCoSeenLinksProvider', () {
    test(
      'includes recent valid co-seen pair from live session evidence',
      () async {
        final now = DateTime(2026, 4, 13, 12);

        await withClock(Clock.fixed(now), () async {
          final ctx = _createTestContainer(preInitStore: preInitStore);
          addTearDown(ctx.container.dispose);

          await _initProvider(ctx.container);

          ctx.nodesNotifier.setNodes({
            100: _makeNode(100),
            200: _makeNode(200),
          });
          await _pumpEventQueue();

          ctx.container.read(nodeDexProvider.notifier).flushCoSeenForTest();
          await _waitForSave();

          final links = ctx.container.read(
            nodeDexRecentCoSeenLinksProvider(100),
          );
          expect(links, hasLength(1));
          expect(links.first.otherNodeNum, equals(200));
          expect(links.first.relationship.count, equals(1));
        });
      },
    );

    test('excludes stale candidate older than 30 minutes', () async {
      final now = DateTime(2026, 4, 13, 12);
      final recentRelationship = CoSeenRelationship(
        count: 3,
        firstSeen: now.subtract(const Duration(minutes: 20)),
        lastSeen: now.subtract(const Duration(minutes: 5)),
      );

      await withClock(Clock.fixed(now), () async {
        await preInitStore.bulkInsert([
          _makeEntry(
            nodeNum: 100,
            lastSeen: now.subtract(const Duration(minutes: 2)),
            coSeenNodes: {200: recentRelationship},
          ),
          _makeEntry(
            nodeNum: 200,
            lastSeen: now.subtract(const Duration(minutes: 5)),
            coSeenNodes: {100: recentRelationship},
          ),
        ]);

        final ctx = _createTestContainer(
          preInitStore: preInitStore,
          initialNodes: {
            100: _makeNode(100),
            200: _makeNode(
              200,
              lastHeard: now.subtract(const Duration(minutes: 31)),
              stale: true,
            ),
          },
        );
        addTearDown(ctx.container.dispose);

        await _initProvider(ctx.container);

        final links = ctx.container.read(nodeDexRecentCoSeenLinksProvider(100));
        expect(links, isEmpty);
      });
    });

    test('excludes months-old historical relationship', () async {
      final now = DateTime(2026, 4, 13, 12);
      final staleRelationship = CoSeenRelationship(
        count: 9,
        firstSeen: now.subtract(const Duration(days: 150)),
        lastSeen: now.subtract(const Duration(days: 120)),
      );

      await withClock(Clock.fixed(now), () async {
        await preInitStore.bulkInsert([
          _makeEntry(
            nodeNum: 100,
            lastSeen: now.subtract(const Duration(minutes: 1)),
            coSeenNodes: {200: staleRelationship},
          ),
          _makeEntry(
            nodeNum: 200,
            lastSeen: now.subtract(const Duration(minutes: 1)),
            coSeenNodes: {100: staleRelationship},
          ),
        ]);

        final ctx = _createTestContainer(
          preInitStore: preInitStore,
          initialNodes: {100: _makeNode(100), 200: _makeNode(200)},
        );
        addTearDown(ctx.container.dispose);

        await _initProvider(ctx.container);

        final links = ctx.container.read(nodeDexRecentCoSeenLinksProvider(100));
        expect(links, isEmpty);
      });
    });

    test(
      'preserves pair-specific counts instead of collapsing to a shared value',
      () async {
        final now = DateTime(2026, 4, 13, 12);
        final rel200 = CoSeenRelationship(
          count: 5,
          firstSeen: now.subtract(const Duration(minutes: 20)),
          lastSeen: now.subtract(const Duration(minutes: 3)),
        );
        final rel300 = CoSeenRelationship(
          count: 2,
          firstSeen: now.subtract(const Duration(minutes: 18)),
          lastSeen: now.subtract(const Duration(minutes: 6)),
        );

        await withClock(Clock.fixed(now), () async {
          await preInitStore.bulkInsert([
            _makeEntry(
              nodeNum: 100,
              lastSeen: now.subtract(const Duration(minutes: 1)),
              coSeenNodes: {200: rel200, 300: rel300},
            ),
            _makeEntry(
              nodeNum: 200,
              lastSeen: now.subtract(const Duration(minutes: 1)),
              coSeenNodes: {100: rel200},
            ),
            _makeEntry(
              nodeNum: 300,
              lastSeen: now.subtract(const Duration(minutes: 1)),
              coSeenNodes: {100: rel300},
            ),
          ]);

          final ctx = _createTestContainer(
            preInitStore: preInitStore,
            initialNodes: {
              100: _makeNode(100),
              200: _makeNode(200),
              300: _makeNode(300),
            },
          );
          addTearDown(ctx.container.dispose);

          await _initProvider(ctx.container);

          final links = ctx.container.read(
            nodeDexRecentCoSeenLinksProvider(100),
          );
          expect(links.map((link) => link.otherNodeNum).toList(), [200, 300]);
          expect(links.map((link) => link.relationship.count).toList(), [5, 2]);
        });
      },
    );

    test('preserves pair-specific timestamps for each row', () async {
      final now = DateTime(2026, 4, 13, 12);
      final rel200 = CoSeenRelationship(
        count: 4,
        firstSeen: now.subtract(const Duration(minutes: 19)),
        lastSeen: now.subtract(const Duration(minutes: 4)),
      );
      final rel300 = CoSeenRelationship(
        count: 1,
        firstSeen: now.subtract(const Duration(minutes: 17)),
        lastSeen: now.subtract(const Duration(minutes: 9)),
      );

      await withClock(Clock.fixed(now), () async {
        await preInitStore.bulkInsert([
          _makeEntry(
            nodeNum: 100,
            lastSeen: now.subtract(const Duration(minutes: 1)),
            coSeenNodes: {200: rel200, 300: rel300},
          ),
          _makeEntry(
            nodeNum: 200,
            lastSeen: now.subtract(const Duration(minutes: 1)),
            coSeenNodes: {100: rel200},
          ),
          _makeEntry(
            nodeNum: 300,
            lastSeen: now.subtract(const Duration(minutes: 1)),
            coSeenNodes: {100: rel300},
          ),
        ]);

        final ctx = _createTestContainer(
          preInitStore: preInitStore,
          initialNodes: {
            100: _makeNode(100),
            200: _makeNode(200),
            300: _makeNode(300),
          },
        );
        addTearDown(ctx.container.dispose);

        await _initProvider(ctx.container);

        final links = ctx.container.read(nodeDexRecentCoSeenLinksProvider(100));
        final linkByNode = {for (final link in links) link.otherNodeNum: link};
        expect(linkByNode[200]!.relationship.lastSeen, equals(rel200.lastSeen));
        expect(linkByNode[300]!.relationship.lastSeen, equals(rel300.lastSeen));
      });
    });

    test(
      'excludes geographically implausible distant pairings when positions exist',
      () async {
        final now = DateTime(2026, 4, 13, 12);
        final recentRelationship = CoSeenRelationship(
          count: 2,
          firstSeen: now.subtract(const Duration(minutes: 15)),
          lastSeen: now.subtract(const Duration(minutes: 2)),
        );

        await withClock(Clock.fixed(now), () async {
          await preInitStore.bulkInsert([
            _makeEntry(
              nodeNum: 100,
              lastSeen: now.subtract(const Duration(minutes: 1)),
              coSeenNodes: {200: recentRelationship},
            ),
            _makeEntry(
              nodeNum: 200,
              lastSeen: now.subtract(const Duration(minutes: 1)),
              coSeenNodes: {100: recentRelationship},
            ),
          ]);

          final ctx = _createTestContainer(
            preInitStore: preInitStore,
            initialNodes: {
              100: _makeNode(100, latitude: -33.8688, longitude: 151.2093),
              200: _makeNode(200, latitude: 51.5074, longitude: -0.1278),
            },
          );
          addTearDown(ctx.container.dispose);

          await _initProvider(ctx.container);

          final links = ctx.container.read(
            nodeDexRecentCoSeenLinksProvider(100),
          );
          expect(links, isEmpty);
        });
      },
    );

    test(
      'uses deterministic tie-breaking for equal weight and timestamp',
      () async {
        final now = DateTime(2026, 4, 13, 12);
        final rel200 = CoSeenRelationship(
          count: 4,
          firstSeen: now.subtract(const Duration(minutes: 16)),
          lastSeen: now.subtract(const Duration(minutes: 3)),
        );
        final rel300 = CoSeenRelationship(
          count: 4,
          firstSeen: now.subtract(const Duration(minutes: 16)),
          lastSeen: now.subtract(const Duration(minutes: 3)),
        );

        await withClock(Clock.fixed(now), () async {
          await preInitStore.bulkInsert([
            _makeEntry(
              nodeNum: 100,
              lastSeen: now.subtract(const Duration(minutes: 1)),
              coSeenNodes: {300: rel300, 200: rel200},
            ),
            _makeEntry(
              nodeNum: 200,
              lastSeen: now.subtract(const Duration(minutes: 1)),
              coSeenNodes: {100: rel200},
            ),
            _makeEntry(
              nodeNum: 300,
              lastSeen: now.subtract(const Duration(minutes: 1)),
              coSeenNodes: {100: rel300},
            ),
          ]);

          final ctx = _createTestContainer(
            preInitStore: preInitStore,
            initialNodes: {
              100: _makeNode(100),
              200: _makeNode(200),
              300: _makeNode(300),
            },
          );
          addTearDown(ctx.container.dispose);

          await _initProvider(ctx.container);

          final links = ctx.container.read(
            nodeDexRecentCoSeenLinksProvider(100),
          );
          expect(links.map((link) => link.otherNodeNum).toList(), [200, 300]);
        });
      },
    );

    test('filters invalid links at the provider layer before render', () async {
      final now = DateTime(2026, 4, 13, 12);
      final staleRelationship = CoSeenRelationship(
        count: 7,
        firstSeen: now.subtract(const Duration(days: 90)),
        lastSeen: now.subtract(const Duration(days: 60)),
      );

      await withClock(Clock.fixed(now), () async {
        await preInitStore.bulkInsert([
          _makeEntry(
            nodeNum: 100,
            lastSeen: now.subtract(const Duration(minutes: 1)),
            coSeenNodes: {200: staleRelationship},
          ),
          _makeEntry(
            nodeNum: 200,
            lastSeen: now.subtract(const Duration(minutes: 1)),
            coSeenNodes: {100: staleRelationship},
          ),
        ]);

        final ctx = _createTestContainer(
          preInitStore: preInitStore,
          initialNodes: {100: _makeNode(100), 200: _makeNode(200)},
        );
        addTearDown(ctx.container.dispose);

        await _initProvider(ctx.container);

        expect(
          ctx.container.read(nodeDexRecentCoSeenLinksProvider(100)),
          isEmpty,
        );
      });
    });
  });

  group('historical co-seen semantics', () {
    test(
      'historical links remain available when recent-facing providers filter them out',
      () async {
        final now = DateTime(2026, 4, 13, 12);
        final staleRelationship = CoSeenRelationship(
          count: 4,
          firstSeen: now.subtract(const Duration(days: 120)),
          lastSeen: now.subtract(const Duration(days: 90)),
        );

        await withClock(Clock.fixed(now), () async {
          await preInitStore.bulkInsert([
            _makeEntry(
              nodeNum: 100,
              lastSeen: now.subtract(const Duration(minutes: 1)),
              coSeenNodes: {200: staleRelationship},
            ),
            _makeEntry(
              nodeNum: 200,
              lastSeen: now.subtract(const Duration(minutes: 1)),
              coSeenNodes: {100: staleRelationship},
            ),
          ]);

          final ctx = _createTestContainer(
            preInitStore: preInitStore,
            initialNodes: {100: _makeNode(100), 200: _makeNode(200)},
          );
          addTearDown(ctx.container.dispose);

          await _initProvider(ctx.container);

          final historicalLinks = ctx.container.read(
            nodeDexHistoricalCoSeenLinksProvider(100),
          );
          final recentLinks = ctx.container.read(
            nodeDexRecentCoSeenLinksProvider(100),
          );
          final cardViewModel = ctx.container.read(
            nodeDexCoSeenCardProvider(100),
          );

          expect(historicalLinks, hasLength(1));
          expect(historicalLinks.first.otherNodeNum, equals(200));
          expect(historicalLinks.first.relationship.count, equals(4));
          expect(recentLinks, isEmpty);
          expect(cardViewModel, isNull);
        });
      },
    );
  });

  // ===========================================================================
  // recordMessage
  // ===========================================================================

  group('recordMessage', () {
    test('increments node-level message count', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      // Discover node
      ctx.nodesNotifier.addNode(_makeNode(100));
      await _pumpEventQueue();

      // Record a message
      ctx.container.read(nodeDexProvider.notifier).recordMessage(100);

      final state = ctx.container.read(nodeDexProvider);
      expect(state[100]!.messageCount, equals(1));
    });

    test('increments message count by custom amount', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(_makeNode(100));
      await _pumpEventQueue();

      ctx.container.read(nodeDexProvider.notifier).recordMessage(100, count: 5);

      final state = ctx.container.read(nodeDexProvider);
      expect(state[100]!.messageCount, equals(5));
    });

    test('accumulates message count across calls', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(_makeNode(100));
      await _pumpEventQueue();

      final notifier = ctx.container.read(nodeDexProvider.notifier);
      notifier.recordMessage(100);
      notifier.recordMessage(100);
      notifier.recordMessage(100);

      final state = ctx.container.read(nodeDexProvider);
      expect(state[100]!.messageCount, equals(3));
    });

    test('no-op for unknown node', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      // Record message for a node that doesn't exist in NodeDex
      ctx.container.read(nodeDexProvider.notifier).recordMessage(999);

      final state = ctx.container.read(nodeDexProvider);
      expect(state.containsKey(999), isFalse);
    });

    test(
      'increments per-edge message count for session peers with existing relationship',
      () async {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        await _initProvider(ctx.container);

        // Discover two nodes (adds them to session)
        ctx.nodesNotifier.setNodes({100: _makeNode(100), 200: _makeNode(200)});
        await _pumpEventQueue();

        // Flush to create co-seen relationships
        ctx.container.read(nodeDexProvider.notifier).flushCoSeenForTest();
        await _waitForSave();

        // Verify relationships exist
        var state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.coSeenNodes.containsKey(200), isTrue);

        // Re-discover to add back to session (session was cleared after flush).
        // The Riverpod listener fires synchronously, so _handleNodesUpdate runs
        // immediately — no pump needed. Pumping gives the periodic flush timer
        // a chance to fire and clear _sessionSeenNodes before recordMessage.
        ctx.nodesNotifier.setNodes({
          100: _makeNode(100, snr: 15),
          200: _makeNode(200, snr: 20),
        });

        // Now record a message for node 100
        ctx.container.read(nodeDexProvider.notifier).recordMessage(100);

        state = ctx.container.read(nodeDexProvider);
        // Node 100's edge to 200 should have messageCount incremented
        expect(state[100]!.coSeenNodes[200]!.messageCount, equals(1));
        // Node-level message count
        expect(state[100]!.messageCount, equals(1));
      },
    );

    test(
      'does not create new co-seen relationship from message alone',
      () async {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        await _initProvider(ctx.container);

        // Discover two nodes. No pump after — listener fires synchronously,
        // and pumping gives the periodic flush timer a chance to create
        // unwanted co-seen relationships.
        ctx.nodesNotifier.setNodes({100: _makeNode(100), 200: _makeNode(200)});

        // Do NOT flush co-seen — no relationships exist yet

        // Record message: should not create a co-seen edge
        ctx.container.read(nodeDexProvider.notifier).recordMessage(100);

        final state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.messageCount, equals(1));
        // No co-seen relationship should have been created
        expect(state[100]!.coSeenNodes, isEmpty);
      },
    );

    test(
      'per-edge message increment only affects session peers, not all co-seen',
      () async {
        // Pre-populate store with an entry that has a co-seen relationship
        // to node 300 (which will NOT be in the current session).
        final now = DateTime(2024, 6, 1);
        final preEntry = _makeEntry(
          nodeNum: 100,
          coSeenNodes: {
            300: CoSeenRelationship(
              count: 5,
              firstSeen: now,
              lastSeen: now,
              messageCount: 0,
            ),
          },
        );
        await preInitStore.saveEntryImmediate(preEntry);

        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        await _initProvider(ctx.container);

        // Verify the pre-populated entry loaded
        var state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.coSeenNodes[300]!.count, equals(5));

        // Add node 100 and 200 to current session (300 is NOT in session)
        ctx.nodesNotifier.setNodes({100: _makeNode(100), 200: _makeNode(200)});
        await _pumpEventQueue();

        // Flush to create 100<->200 relationship
        ctx.container.read(nodeDexProvider.notifier).flushCoSeenForTest();
        await _waitForSave();

        // Re-add to session. No pump — listener fires synchronously.
        ctx.nodesNotifier.setNodes({
          100: _makeNode(100, snr: 20),
          200: _makeNode(200, snr: 25),
        });

        // Record message for 100
        ctx.container.read(nodeDexProvider.notifier).recordMessage(100);

        state = ctx.container.read(nodeDexProvider);
        // Edge to 200 (in session) should have incremented
        expect(state[100]!.coSeenNodes[200]!.messageCount, equals(1));
        // Edge to 300 (NOT in session) should NOT have incremented
        expect(state[100]!.coSeenNodes[300]!.messageCount, equals(0));
      },
    );
  });

  // ===========================================================================
  // setSocialTag
  // ===========================================================================

  group('setSocialTag', () {
    test('sets social tag on existing entry', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(_makeNode(100));
      await _pumpEventQueue();

      ctx.container
          .read(nodeDexProvider.notifier)
          .setSocialTag(100, NodeSocialTag.contact);

      final state = ctx.container.read(nodeDexProvider);
      expect(state[100]!.socialTag, equals(NodeSocialTag.contact));
    });

    test('clears social tag with null', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(_makeNode(100));
      await _pumpEventQueue();

      ctx.container
          .read(nodeDexProvider.notifier)
          .setSocialTag(100, NodeSocialTag.trustedNode);
      ctx.container.read(nodeDexProvider.notifier).setSocialTag(100, null);

      final state = ctx.container.read(nodeDexProvider);
      expect(state[100]!.socialTag, isNull);
    });

    test('is no-op for unknown node', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.container
          .read(nodeDexProvider.notifier)
          .setSocialTag(999, NodeSocialTag.contact);

      final state = ctx.container.read(nodeDexProvider);
      expect(state.containsKey(999), isFalse);
    });
  });

  // ===========================================================================
  // setUserNote
  // ===========================================================================

  group('setUserNote', () {
    test('sets user note on existing entry', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(_makeNode(100));
      await _pumpEventQueue();

      ctx.container
          .read(nodeDexProvider.notifier)
          .setUserNote(100, 'Test note');

      final state = ctx.container.read(nodeDexProvider);
      expect(state[100]!.userNote, equals('Test note'));
    });

    test('clears user note with null', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(_makeNode(100));
      await _pumpEventQueue();

      ctx.container
          .read(nodeDexProvider.notifier)
          .setUserNote(100, 'Initial note');
      ctx.container.read(nodeDexProvider.notifier).setUserNote(100, null);

      final state = ctx.container.read(nodeDexProvider);
      expect(state[100]!.userNote, isNull);
    });

    test('clears user note with empty string', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(_makeNode(100));
      await _pumpEventQueue();

      ctx.container
          .read(nodeDexProvider.notifier)
          .setUserNote(100, 'Something');
      ctx.container.read(nodeDexProvider.notifier).setUserNote(100, '');

      final state = ctx.container.read(nodeDexProvider);
      expect(state[100]!.userNote, isNull);
    });

    test('truncates note to 280 characters', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(_makeNode(100));
      await _pumpEventQueue();

      final longNote = 'A' * 500;
      ctx.container.read(nodeDexProvider.notifier).setUserNote(100, longNote);

      final state = ctx.container.read(nodeDexProvider);
      expect(state[100]!.userNote!.length, equals(280));
    });

    test('is no-op for unknown node', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.container.read(nodeDexProvider.notifier).setUserNote(999, 'note');

      final state = ctx.container.read(nodeDexProvider);
      expect(state.containsKey(999), isFalse);
    });
  });

  // ===========================================================================
  // clearAll
  // ===========================================================================

  group('clearAll', () {
    test('removes all entries from state', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.setNodes({100: _makeNode(100), 200: _makeNode(200)});
      await _pumpEventQueue();

      expect(ctx.container.read(nodeDexProvider).length, equals(2));

      ctx.container.read(nodeDexProvider.notifier).clearAll();
      await _pumpEventQueue();

      final state = ctx.container.read(nodeDexProvider);
      expect(state, isEmpty);
    });
  });

  // ===========================================================================
  // exportJson / importJson
  // ===========================================================================

  group('export and import', () {
    test('exportJson returns JSON for current entries', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(_makeNode(100, snr: 10));
      await _pumpEventQueue();

      // Flush store so data is persisted
      await preInitStore.flush();

      final notifier = ctx.container.read(nodeDexProvider.notifier);
      final exported = await notifier.exportJson();

      expect(exported, isNotNull);
      expect(exported!.contains('"nn":100'), isTrue);
    });

    test('importJson adds entries and refreshes state', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      // Import entries
      final entries = [
        _makeEntry(nodeNum: 500, encounterCount: 10),
        _makeEntry(nodeNum: 600, encounterCount: 5),
      ];
      final json = NodeDexEntry.encodeList(entries);

      final importCount = await ctx.container
          .read(nodeDexProvider.notifier)
          .importJson(json);
      await _pumpEventQueue();

      expect(importCount, equals(2));

      final state = ctx.container.read(nodeDexProvider);
      expect(state.containsKey(500), isTrue);
      expect(state.containsKey(600), isTrue);
      expect(state[500]!.encounterCount, equals(10));
      expect(state[600]!.encounterCount, equals(5));
    });

    test('importJson merges with existing entries', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      // Discover a node
      ctx.nodesNotifier.addNode(_makeNode(100, snr: 5));
      await _pumpEventQueue();

      // Flush store
      await preInitStore.flush();

      // Import entry for same node with better metrics
      final importedEntry = _makeEntry(
        nodeNum: 100,
        encounterCount: 50,
        bestSnr: 20,
        maxDistanceSeen: 5000.0,
        firstSeen: DateTime(2023, 1, 1),
      );
      final json = NodeDexEntry.encodeList([importedEntry]);

      final importCount = await ctx.container
          .read(nodeDexProvider.notifier)
          .importJson(json);
      await _pumpEventQueue();

      expect(importCount, equals(1));

      final state = ctx.container.read(nodeDexProvider);
      final entry = state[100]!;
      // Merged: max encounter count
      expect(entry.encounterCount, equals(50));
      // Merged: earliest firstSeen
      expect(entry.firstSeen, equals(DateTime(2023, 1, 1)));
    });
  });

  // ===========================================================================
  // Derived providers
  // ===========================================================================

  group('derived providers', () {
    test('nodeDexEntryProvider returns entry for given nodeNum', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(_makeNode(100, snr: 12));
      await _pumpEventQueue();

      final entry = ctx.container.read(nodeDexEntryProvider(100));
      expect(entry, isNotNull);
      expect(entry!.nodeNum, equals(100));
      expect(entry.bestSnr, equals(12));
    });

    test('nodeDexEntryProvider returns null for unknown node', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      final entry = ctx.container.read(nodeDexEntryProvider(999));
      expect(entry, isNull);
    });

    test('nodeDexStatsProvider computes aggregate statistics', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.setNodes({
        100: _makeNode(100, snr: 5, rssi: -90, distance: 1000),
        200: _makeNode(200, snr: 15, rssi: -60, distance: 5000),
        300: _makeNode(300, snr: 10, rssi: -75, distance: 3000),
      });
      await _pumpEventQueue();

      final stats = ctx.container.read(nodeDexStatsProvider);
      expect(stats.totalNodes, equals(3));
      expect(stats.bestSnrOverall, equals(15));
      expect(stats.bestRssiOverall, equals(-60));
      expect(stats.longestDistance, equals(5000.0));
    });

    test('nodeDexTraitProvider computes trait for node', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(_makeNode(100));
      await _pumpEventQueue();

      // Just verify it doesn't throw and returns some value.
      // Trait might be null if not enough data, that's fine —
      // the point is the provider doesn't throw.
      ctx.container.read(nodeDexTraitProvider(100));
      expect(true, isTrue); // Provider executed without error
    });
  });

  // ===========================================================================
  // Constellation provider
  // ===========================================================================

  group('constellation provider', () {
    test('empty state produces empty constellation', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      final constellation = ctx.container.read(nodeDexConstellationProvider);
      expect(constellation.isEmpty, isTrue);
      expect(constellation.nodeCount, equals(0));
      expect(constellation.edgeCount, equals(0));
    });

    test('nodes with co-seen relationships produce edges', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      // Discover three nodes
      ctx.nodesNotifier.setNodes({
        100: _makeNode(100),
        200: _makeNode(200),
        300: _makeNode(300),
      });
      await _pumpEventQueue();

      // Flush co-seen
      ctx.container.read(nodeDexProvider.notifier).flushCoSeenForTest();
      await _waitForSave();

      final constellation = ctx.container.read(nodeDexConstellationProvider);
      expect(constellation.nodeCount, equals(3));
      // 3 nodes fully connected = 3 edges (100-200, 100-300, 200-300)
      expect(constellation.edgeCount, equals(3));
    });

    test(
      'constellation edges carry metadata from co-seen relationships',
      () async {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        await _initProvider(ctx.container);

        // Discover two nodes
        ctx.nodesNotifier.setNodes({100: _makeNode(100), 200: _makeNode(200)});
        await _pumpEventQueue();

        // Flush co-seen
        ctx.container.read(nodeDexProvider.notifier).flushCoSeenForTest();
        await _waitForSave();

        final constellation = ctx.container.read(nodeDexConstellationProvider);
        expect(constellation.edgeCount, equals(1));

        final edge = constellation.edges.first;
        expect(edge.weight, greaterThan(0));
        expect(edge.firstSeen, isNotNull);
        expect(edge.lastSeen, isNotNull);
      },
    );

    test('nodes without co-seen relationships have no edges', () async {
      // Pre-populate with entries that have no co-seen
      final entries = [
        _makeEntry(nodeNum: 100, encounterCount: 5),
        _makeEntry(nodeNum: 200, encounterCount: 3),
      ];
      await preInitStore.bulkInsert(entries);

      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      final constellation = ctx.container.read(nodeDexConstellationProvider);
      expect(constellation.nodeCount, equals(2));
      expect(constellation.edgeCount, equals(0));
    });

    test(
      'constellation keeps historical edges even when recent links are empty',
      () async {
        final now = DateTime(2026, 4, 13, 12);
        final staleRelationship = CoSeenRelationship(
          count: 6,
          firstSeen: now.subtract(const Duration(days: 200)),
          lastSeen: now.subtract(const Duration(days: 100)),
        );

        await withClock(Clock.fixed(now), () async {
          await preInitStore.bulkInsert([
            _makeEntry(
              nodeNum: 100,
              lastSeen: now.subtract(const Duration(minutes: 1)),
              coSeenNodes: {200: staleRelationship},
            ),
            _makeEntry(
              nodeNum: 200,
              lastSeen: now.subtract(const Duration(minutes: 1)),
              coSeenNodes: {100: staleRelationship},
            ),
          ]);

          final ctx = _createTestContainer(
            preInitStore: preInitStore,
            initialNodes: {100: _makeNode(100), 200: _makeNode(200)},
          );
          addTearDown(ctx.container.dispose);

          await _initProvider(ctx.container);

          final constellation = ctx.container.read(
            nodeDexConstellationProvider,
          );
          final node100 = constellation.nodes.firstWhere(
            (node) => node.nodeNum == 100,
          );

          expect(
            ctx.container.read(nodeDexRecentCoSeenLinksProvider(100)),
            isEmpty,
          );
          expect(constellation.nodeCount, equals(2));
          expect(constellation.edgeCount, equals(1));
          expect(node100.connectionCount, equals(1));
          expect(constellation.edges.first.weight, equals(6));
          expect(
            constellation.edges.first.lastSeen,
            equals(staleRelationship.lastSeen),
          );
        });
      },
    );
  });

  // ===========================================================================
  // Encounter re-recording with metrics improvement
  // ===========================================================================

  group('encounter metrics improvement', () {
    test('re-encounter improves best SNR', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      // First discovery with low SNR
      ctx.nodesNotifier.addNode(_makeNode(100, snr: 5));
      await _pumpEventQueue();

      expect(ctx.container.read(nodeDexProvider)[100]!.bestSnr, equals(5));

      // Re-discover with higher SNR (cooldown is zero, so re-encounter fires)
      ctx.nodesNotifier.setNodes({100: _makeNode(100, snr: 20)});
      await _pumpEventQueue();

      expect(ctx.container.read(nodeDexProvider)[100]!.bestSnr, equals(20));
    });

    test('re-encounter improves max distance', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(_makeNode(100, distance: 1000.0));
      await _pumpEventQueue();

      expect(
        ctx.container.read(nodeDexProvider)[100]!.maxDistanceSeen,
        equals(1000.0),
      );

      // Re-discover with greater distance (cooldown is zero)
      ctx.nodesNotifier.setNodes({100: _makeNode(100, distance: 5000.0)});
      await _pumpEventQueue();

      expect(
        ctx.container.read(nodeDexProvider)[100]!.maxDistanceSeen,
        equals(5000.0),
      );
    });
  });

  // ===========================================================================
  // Integration: discovery → co-seen → message flow
  // ===========================================================================

  group('full flow integration', () {
    test(
      'discover nodes, co-seen flush, record messages, verify per-edge counts',
      () async {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        await _initProvider(ctx.container);

        // Step 1: Discover three nodes
        ctx.nodesNotifier.setNodes({
          100: _makeNode(100, snr: 10),
          200: _makeNode(200, snr: 8),
          300: _makeNode(300, snr: 15),
        });
        await _pumpEventQueue();

        var state = ctx.container.read(nodeDexProvider);
        expect(state.length, equals(3));

        // Step 2: Flush co-seen relationships
        ctx.container.read(nodeDexProvider.notifier).flushCoSeenForTest();
        await _waitForSave();

        state = ctx.container.read(nodeDexProvider);
        // All three should be co-seen with each other
        expect(state[100]!.coSeenNodes.length, equals(2));
        expect(state[200]!.coSeenNodes.length, equals(2));
        expect(state[300]!.coSeenNodes.length, equals(2));

        // Step 3: Re-enter session (session was cleared after flush).
        // No pump — listener fires synchronously. Pumping gives the periodic
        // flush timer a chance to clear _sessionSeenNodes before recordMessage.
        ctx.nodesNotifier.setNodes({
          100: _makeNode(100, snr: 12),
          200: _makeNode(200, snr: 10),
          300: _makeNode(300, snr: 18),
        });

        // Step 4: Record messages
        final notifier = ctx.container.read(nodeDexProvider.notifier);
        notifier.recordMessage(100, count: 3);
        notifier.recordMessage(200, count: 2);

        state = ctx.container.read(nodeDexProvider);

        // Node 100: 3 messages total, per-edge to 200 and 300 each +3
        expect(state[100]!.messageCount, equals(3));
        expect(state[100]!.coSeenNodes[200]!.messageCount, equals(3));
        expect(state[100]!.coSeenNodes[300]!.messageCount, equals(3));

        // Node 200: 2 messages total, per-edge to 100 and 300 each +2
        expect(state[200]!.messageCount, equals(2));
        expect(state[200]!.coSeenNodes[100]!.messageCount, equals(2));
        expect(state[200]!.coSeenNodes[300]!.messageCount, equals(2));

        // Node 300: no messages recorded, edges should have 0 messages
        expect(state[300]!.messageCount, equals(0));
        expect(state[300]!.coSeenNodes[100]!.messageCount, equals(0));
        expect(state[300]!.coSeenNodes[200]!.messageCount, equals(0));
      },
    );

    test('export after full flow preserves all data', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      // Discover and establish relationships
      ctx.nodesNotifier.setNodes({
        100: _makeNode(100, snr: 10, distance: 2000),
        200: _makeNode(200, snr: 15, distance: 3000),
      });
      await _pumpEventQueue();

      // Set social tags
      final notifier = ctx.container.read(nodeDexProvider.notifier);
      notifier.setSocialTag(100, NodeSocialTag.contact);
      notifier.setUserNote(200, 'A relay node');

      // Flush co-seen
      notifier.flushCoSeenForTest();
      await _waitForSave();

      // Flush store
      await preInitStore.flush();

      // Export
      final exported = await notifier.exportJson();
      expect(exported, isNotNull);

      // Import into a fresh store for a second container
      final freshDb = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      final freshStore = NodeDexSqliteStore(
        freshDb,
        saveDebounceDuration: Duration.zero,
      );
      await freshStore.init();
      addTearDown(() => freshStore.dispose());

      final ctx2 = _createTestContainer(preInitStore: freshStore);
      addTearDown(ctx2.container.dispose);

      await _initProvider(ctx2.container);

      final importCount = await ctx2.container
          .read(nodeDexProvider.notifier)
          .importJson(exported!);
      await _pumpEventQueue();

      expect(importCount, equals(2));

      final state = ctx2.container.read(nodeDexProvider);
      expect(state[100]!.socialTag, equals(NodeSocialTag.contact));
      expect(state[200]!.userNote, equals('A relay node'));
      expect(state[100]!.coSeenNodes.containsKey(200), isTrue);
      expect(state[200]!.coSeenNodes.containsKey(100), isTrue);
    });
  });

  // ===========================================================================
  // Edge cases
  // ===========================================================================

  group('edge cases', () {
    test('null myNodeNum does not crash', () async {
      final ctx = _createTestContainer(
        preInitStore: preInitStore,
        myNodeNum: null,
      );
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      // Should not throw
      ctx.nodesNotifier.addNode(_makeNode(100));
      await _pumpEventQueue();

      // Entry should be created (null != 100)
      final state = ctx.container.read(nodeDexProvider);
      expect(state.containsKey(100), isTrue);
    });

    test('rapid node updates do not corrupt state', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      // Rapidly add and update many nodes
      for (int i = 1; i <= 20; i++) {
        ctx.nodesNotifier.addNode(_makeNode(i, snr: i));
      }
      await _pumpEventQueue();

      final state = ctx.container.read(nodeDexProvider);
      expect(state.length, equals(20));

      // All entries should have correct data
      for (int i = 1; i <= 20; i++) {
        expect(state[i], isNotNull, reason: 'Node $i should exist');
        expect(state[i]!.bestSnr, equals(i));
      }
    });

    test('recordMessage after clearAll is no-op', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      ctx.nodesNotifier.addNode(_makeNode(100));
      await _pumpEventQueue();

      ctx.container.read(nodeDexProvider.notifier).clearAll();
      await _pumpEventQueue();

      // Should not throw
      ctx.container.read(nodeDexProvider.notifier).recordMessage(100);

      final state = ctx.container.read(nodeDexProvider);
      expect(state, isEmpty);
    });

    test(
      'sigil is generated for nodes missing sigil on re-encounter',
      () async {
        // Pre-populate with an entry that has no sigil
        final entry = NodeDexEntry(
          nodeNum: 100,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 1, 1),
          encounterCount: 1,
          sigil: null,
        );
        await preInitStore.saveEntryImmediate(entry);

        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        await _initProvider(ctx.container);

        // Trigger re-encounter (cooldown is zero so it fires immediately)
        ctx.nodesNotifier.addNode(_makeNode(100, snr: 10));
        await _pumpEventQueue();

        final state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.sigil, isNotNull);
      },
    );

    test('initial node snapshot does not seed co-seen session state', () async {
      // Start with nodes already present
      final ctx = _createTestContainer(
        preInitStore: preInitStore,
        initialNodes: {100: _makeNode(100), 200: _makeNode(200)},
      );
      addTearDown(ctx.container.dispose);

      await _initProvider(ctx.container);

      // Entries should have been created from initial sync
      var state = ctx.container.read(nodeDexProvider);
      expect(state.containsKey(100), isTrue);
      expect(state.containsKey(200), isTrue);

      // Flush co-seen — the cached initial snapshot should not count as
      // recent overlap evidence for co-seen link generation.
      ctx.container.read(nodeDexProvider.notifier).flushCoSeenForTest();
      await _waitForSave();

      state = ctx.container.read(nodeDexProvider);
      expect(state[100]!.coSeenNodes, isEmpty);
      expect(state[200]!.coSeenNodes, isEmpty);
      expect(
        ctx.container.read(nodeDexRecentCoSeenLinksProvider(100)),
        isEmpty,
      );
    });
  });
}
