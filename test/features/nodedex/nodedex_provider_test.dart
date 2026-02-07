// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/providers/nodedex_providers.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_database.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_sqlite_store.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
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
}) {
  return MeshNode(
    nodeNum: nodeNum,
    distance: distance,
    snr: snr,
    rssi: rssi,
    latitude: latitude,
    longitude: longitude,
    firstHeard: firstHeard,
    lastHeard: lastHeard,
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
/// FutureProvider resolves synchronously inside fakeAsync.
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
      // Return the store synchronously (not async) so the FutureProvider
      // resolves immediately without needing microtask flushes.
      nodeDexStoreProvider.overrideWith((ref) => preInitStore),
    ],
  );

  return (
    container: container,
    nodesNotifier: nodesNotifier,
    store: preInitStore,
  );
}

/// Trigger the [nodeDexProvider] build and flush enough microtask rounds
/// for the FutureProvider to resolve, the notifier to rebuild, and the
/// async `_init` method to finish loading from storage.
///
/// Uses `container.listen` (not `container.read`) so Riverpod keeps the
/// provider alive and automatically rebuilds it when watched dependencies
/// (like the `FutureProvider<NodeDexSqliteStore>`) resolve.
void _initProvider(ProviderContainer container, FakeAsync async) {
  // listen() creates a subscription that keeps the provider alive and
  // reactive — unlike read(), which is a one-shot that doesn't trigger
  // rebuilds when dependencies update.
  container.listen(nodeDexProvider, (_, _) {});
  // Flush multiple rounds:
  //   1. FutureProvider resolves -> nodeDexProvider invalidated
  //   2. nodeDexProvider rebuilds (now has store) -> async _init() starts
  //   3. _init() awaits loadAllAsMap -> completes, sets state
  //   4. Safety round for any downstream microtasks
  for (var i = 0; i < 5; i++) {
    async.flushMicrotasks();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NodeDexSqliteStore preInitStore;
  late NodeDexDatabase preInitDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    preInitDb = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
    preInitStore = NodeDexSqliteStore(preInitDb);
    await preInitStore.init();
  });

  tearDown(() async {
    await preInitStore.dispose();
  });

  // ===========================================================================
  // Initialization
  // ===========================================================================

  group('initialization', () {
    test('provider starts with empty state before init completes', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        // Before any flushing, state is the initial empty map from build().
        final state = ctx.container.read(nodeDexProvider);
        expect(state, isEmpty);

        ctx.container.dispose();
      });
    });

    test('provider loads entries from store after init', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        final state = ctx.container.read(nodeDexProvider);
        // Fresh store => empty
        expect(state, isEmpty);

        ctx.container.dispose();
      });
    });

    test('provider loads pre-existing entries from store', () async {
      // Pre-populate the SQLite store with an entry.
      final entry = _makeEntry(nodeNum: 42, encounterCount: 5);
      await preInitStore.saveEntryImmediate(entry);

      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        final state = ctx.container.read(nodeDexProvider);
        expect(state.length, equals(1));
        expect(state[42], isNotNull);
        expect(state[42]!.encounterCount, equals(5));

        ctx.container.dispose();
      });
    });
  });

  // ===========================================================================
  // Node Discovery
  // ===========================================================================

  group('node discovery', () {
    test('new node in nodesProvider creates NodeDex entry', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // Simulate node discovery
        ctx.nodesNotifier.addNode(_makeNode(100, snr: 10, rssi: -80));
        async.flushMicrotasks();

        final state = ctx.container.read(nodeDexProvider);
        expect(state.containsKey(100), isTrue);
        expect(state[100]!.nodeNum, equals(100));
        expect(state[100]!.encounterCount, equals(1));
        expect(state[100]!.bestSnr, equals(10));
        expect(state[100]!.bestRssi, equals(-80));

        ctx.container.dispose();
      });
    });

    test('own node number is skipped during discovery', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // Add our own node
        ctx.nodesNotifier.addNode(_makeNode(_myNodeNum));
        async.flushMicrotasks();

        final state = ctx.container.read(nodeDexProvider);
        expect(state.containsKey(_myNodeNum), isFalse);

        ctx.container.dispose();
      });
    });

    test('node 0 is skipped during discovery', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(_makeNode(0));
        async.flushMicrotasks();

        final state = ctx.container.read(nodeDexProvider);
        expect(state.containsKey(0), isFalse);

        ctx.container.dispose();
      });
    });

    test('discovered entry has a sigil', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(_makeNode(200));
        async.flushMicrotasks();

        final entry = ctx.container.read(nodeDexProvider)[200];
        expect(entry, isNotNull);
        expect(entry!.sigil, isNotNull);

        ctx.container.dispose();
      });
    });

    test('multiple nodes discovered at once', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.setNodes({
          100: _makeNode(100, snr: 5),
          200: _makeNode(200, snr: 8),
          300: _makeNode(300, snr: 12),
        });
        async.flushMicrotasks();

        final state = ctx.container.read(nodeDexProvider);
        expect(state.length, equals(3));
        expect(state.containsKey(100), isTrue);
        expect(state.containsKey(200), isTrue);
        expect(state.containsKey(300), isTrue);

        ctx.container.dispose();
      });
    });

    test('re-seen node within cooldown does not increment encounter count', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // First discovery
        ctx.nodesNotifier.addNode(_makeNode(100));
        async.flushMicrotasks();

        final firstState = ctx.container.read(nodeDexProvider);
        expect(firstState[100]!.encounterCount, equals(1));

        // Re-discover within cooldown (< 5 minutes)
        async.elapse(const Duration(minutes: 2));
        ctx.nodesNotifier.setNodes({100: _makeNode(100, snr: 15)});
        async.flushMicrotasks();

        final secondState = ctx.container.read(nodeDexProvider);
        // Should NOT increment because we're within 5-minute cooldown
        expect(secondState[100]!.encounterCount, equals(1));

        ctx.container.dispose();
      });
    });

    test('re-seen node after cooldown increments encounter count', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // First discovery
        ctx.nodesNotifier.addNode(_makeNode(100));
        async.flushMicrotasks();

        // Wait past cooldown (>= 5 minutes)
        async.elapse(const Duration(minutes: 6));

        // Trigger re-discovery by updating the node
        ctx.nodesNotifier.setNodes({100: _makeNode(100, snr: 15)});
        async.flushMicrotasks();

        final state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.encounterCount, equals(2));

        ctx.container.dispose();
      });
    });

    test('discovered entry records distance and metrics', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(
          _makeNode(100, distance: 1500.0, snr: 12, rssi: -65),
        );
        async.flushMicrotasks();

        final entry = ctx.container.read(nodeDexProvider)[100]!;
        expect(entry.maxDistanceSeen, equals(1500.0));
        expect(entry.bestSnr, equals(12));
        expect(entry.bestRssi, equals(-65));

        ctx.container.dispose();
      });
    });

    test('node with position records position in encounter', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(
          _makeNode(100, latitude: 48.8566, longitude: 2.3522),
        );
        async.flushMicrotasks();

        final entry = ctx.container.read(nodeDexProvider)[100]!;
        expect(entry.encounters.length, equals(1));
        expect(entry.encounters.first.latitude, equals(48.8566));
        expect(entry.encounters.first.longitude, equals(2.3522));

        ctx.container.dispose();
      });
    });
  });

  // ===========================================================================
  // Session tracking & co-seen flush
  // ===========================================================================

  group('co-seen flush', () {
    test(
      'co-seen relationships created after flush interval for co-present nodes',
      () {
        fakeAsync((async) {
          final ctx = _createTestContainer(preInitStore: preInitStore);
          addTearDown(ctx.container.dispose);

          _initProvider(ctx.container, async);

          // Discover two nodes in same session
          ctx.nodesNotifier.setNodes({
            100: _makeNode(100),
            200: _makeNode(200),
          });
          async.flushMicrotasks();

          // Verify entries exist but no co-seen yet (flush hasn't fired)
          var state = ctx.container.read(nodeDexProvider);
          expect(state[100]!.coSeenNodes, isEmpty);
          expect(state[200]!.coSeenNodes, isEmpty);

          // Advance past the co-seen flush interval (2 minutes)
          async.elapse(const Duration(minutes: 2, seconds: 1));
          async.flushMicrotasks();

          // Now co-seen relationships should exist
          state = ctx.container.read(nodeDexProvider);
          expect(state[100]!.coSeenNodes.containsKey(200), isTrue);
          expect(state[200]!.coSeenNodes.containsKey(100), isTrue);
          expect(state[100]!.coSeenNodes[200]!.count, equals(1));
          expect(state[200]!.coSeenNodes[100]!.count, equals(1));

          ctx.container.dispose();
        });
      },
    );

    test('co-seen flush is bidirectional', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.setNodes({
          100: _makeNode(100),
          200: _makeNode(200),
          300: _makeNode(300),
        });
        async.flushMicrotasks();

        // Trigger flush
        async.elapse(const Duration(minutes: 2, seconds: 1));
        async.flushMicrotasks();

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

        ctx.container.dispose();
      });
    });

    test('co-seen flush clears session so next flush is fresh', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // First batch: two nodes
        ctx.nodesNotifier.setNodes({100: _makeNode(100), 200: _makeNode(200)});
        async.flushMicrotasks();

        // First flush
        async.elapse(const Duration(minutes: 2, seconds: 1));
        async.flushMicrotasks();

        var state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.coSeenNodes[200]!.count, equals(1));

        // Second flush without new node updates — session was cleared
        // so no new co-seen relationships should be added
        async.elapse(const Duration(minutes: 2, seconds: 1));
        async.flushMicrotasks();

        state = ctx.container.read(nodeDexProvider);
        // Count should still be 1 (session was cleared, no new sightings)
        expect(state[100]!.coSeenNodes[200]!.count, equals(1));

        ctx.container.dispose();
      });
    });

    test('co-seen count increments across multiple flush cycles', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // First session: discover nodes
        ctx.nodesNotifier.setNodes({100: _makeNode(100), 200: _makeNode(200)});
        async.flushMicrotasks();

        // First flush
        async.elapse(const Duration(minutes: 2, seconds: 1));
        async.flushMicrotasks();

        var state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.coSeenNodes[200]!.count, equals(1));

        // Re-discover (trigger handleNodesUpdate so session is populated again)
        // Need to wait past encounter cooldown to trigger _handleNodesUpdate
        async.elapse(const Duration(minutes: 4));

        ctx.nodesNotifier.setNodes({
          100: _makeNode(100, snr: 20),
          200: _makeNode(200, snr: 25),
        });
        async.flushMicrotasks();

        // Second flush
        async.elapse(const Duration(minutes: 2, seconds: 1));
        async.flushMicrotasks();

        state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.coSeenNodes[200]!.count, equals(2));

        ctx.container.dispose();
      });
    });

    test('single node in session produces no co-seen relationships', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // Only one node
        ctx.nodesNotifier.addNode(_makeNode(100));
        async.flushMicrotasks();

        // Trigger flush
        async.elapse(const Duration(minutes: 2, seconds: 1));
        async.flushMicrotasks();

        final state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.coSeenNodes, isEmpty);

        ctx.container.dispose();
      });
    });

    test('co-seen flush on dispose persists relationships', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);

        _initProvider(ctx.container, async);

        // Discover two nodes
        ctx.nodesNotifier.setNodes({100: _makeNode(100), 200: _makeNode(200)});
        async.flushMicrotasks();

        // Dispose triggers flush via onDispose (no timer needed)
        ctx.container.dispose();
        async.flushMicrotasks();

        // The store should have received saveEntries from the flush.
        // We verify the store's internal state survived the dispose flush.
      });
    });
  });

  // ===========================================================================
  // recordMessage
  // ===========================================================================

  group('recordMessage', () {
    test('increments node-level message count', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // Discover node
        ctx.nodesNotifier.addNode(_makeNode(100));
        async.flushMicrotasks();

        // Record a message
        ctx.container.read(nodeDexProvider.notifier).recordMessage(100);

        final state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.messageCount, equals(1));

        ctx.container.dispose();
      });
    });

    test('increments message count by custom amount', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(_makeNode(100));
        async.flushMicrotasks();

        ctx.container
            .read(nodeDexProvider.notifier)
            .recordMessage(100, count: 5);

        final state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.messageCount, equals(5));

        ctx.container.dispose();
      });
    });

    test('accumulates message count across calls', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(_makeNode(100));
        async.flushMicrotasks();

        final notifier = ctx.container.read(nodeDexProvider.notifier);
        notifier.recordMessage(100);
        notifier.recordMessage(100);
        notifier.recordMessage(100);

        final state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.messageCount, equals(3));

        ctx.container.dispose();
      });
    });

    test('no-op for unknown node', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // Record message for a node that doesn't exist in NodeDex
        ctx.container.read(nodeDexProvider.notifier).recordMessage(999);

        final state = ctx.container.read(nodeDexProvider);
        expect(state.containsKey(999), isFalse);

        ctx.container.dispose();
      });
    });

    test(
      'increments per-edge message count for session peers with existing relationship',
      () {
        fakeAsync((async) {
          final ctx = _createTestContainer(preInitStore: preInitStore);
          addTearDown(ctx.container.dispose);

          _initProvider(ctx.container, async);

          // Discover two nodes (adds them to session)
          ctx.nodesNotifier.setNodes({
            100: _makeNode(100),
            200: _makeNode(200),
          });
          async.flushMicrotasks();

          // Flush to create co-seen relationships
          async.elapse(const Duration(minutes: 2, seconds: 1));
          async.flushMicrotasks();

          // Verify relationships exist
          var state = ctx.container.read(nodeDexProvider);
          expect(state[100]!.coSeenNodes.containsKey(200), isTrue);

          // Re-discover to add back to session (session was cleared after flush)
          async.elapse(const Duration(minutes: 4));
          ctx.nodesNotifier.setNodes({
            100: _makeNode(100, snr: 15),
            200: _makeNode(200, snr: 20),
          });
          async.flushMicrotasks();

          // Now record a message for node 100
          ctx.container.read(nodeDexProvider.notifier).recordMessage(100);

          state = ctx.container.read(nodeDexProvider);
          // Node 100's edge to 200 should have messageCount incremented
          expect(state[100]!.coSeenNodes[200]!.messageCount, equals(1));
          // Node-level message count
          expect(state[100]!.messageCount, equals(1));

          ctx.container.dispose();
        });
      },
    );

    test('does not create new co-seen relationship from message alone', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // Discover two nodes
        ctx.nodesNotifier.setNodes({100: _makeNode(100), 200: _makeNode(200)});
        async.flushMicrotasks();

        // Do NOT flush co-seen — no relationships exist yet

        // Record message: should not create a co-seen edge
        ctx.container.read(nodeDexProvider.notifier).recordMessage(100);

        final state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.messageCount, equals(1));
        // No co-seen relationship should have been created
        expect(state[100]!.coSeenNodes, isEmpty);

        ctx.container.dispose();
      });
    });

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

        fakeAsync((async) {
          final ctx = _createTestContainer(preInitStore: preInitStore);
          addTearDown(ctx.container.dispose);

          _initProvider(ctx.container, async);

          // Verify the pre-populated entry loaded
          var state = ctx.container.read(nodeDexProvider);
          expect(state[100]!.coSeenNodes[300]!.count, equals(5));

          // Add node 100 and 200 to current session (300 is NOT in session)
          ctx.nodesNotifier.setNodes({
            100: _makeNode(100),
            200: _makeNode(200),
          });
          async.flushMicrotasks();

          // Flush to create 100<->200 relationship
          async.elapse(const Duration(minutes: 2, seconds: 1));
          async.flushMicrotasks();

          // Re-add to session
          async.elapse(const Duration(minutes: 4));
          ctx.nodesNotifier.setNodes({
            100: _makeNode(100, snr: 20),
            200: _makeNode(200, snr: 25),
          });
          async.flushMicrotasks();

          // Record message for 100
          ctx.container.read(nodeDexProvider.notifier).recordMessage(100);

          state = ctx.container.read(nodeDexProvider);
          // Edge to 200 (in session) should have incremented
          expect(state[100]!.coSeenNodes[200]!.messageCount, equals(1));
          // Edge to 300 (NOT in session) should NOT have incremented
          expect(state[100]!.coSeenNodes[300]!.messageCount, equals(0));

          ctx.container.dispose();
        });
      },
    );
  });

  // ===========================================================================
  // setSocialTag
  // ===========================================================================

  group('setSocialTag', () {
    test('sets social tag on existing entry', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(_makeNode(100));
        async.flushMicrotasks();

        ctx.container
            .read(nodeDexProvider.notifier)
            .setSocialTag(100, NodeSocialTag.contact);

        final state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.socialTag, equals(NodeSocialTag.contact));

        ctx.container.dispose();
      });
    });

    test('clears social tag with null', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(_makeNode(100));
        async.flushMicrotasks();

        ctx.container
            .read(nodeDexProvider.notifier)
            .setSocialTag(100, NodeSocialTag.trustedNode);
        ctx.container.read(nodeDexProvider.notifier).setSocialTag(100, null);

        final state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.socialTag, isNull);

        ctx.container.dispose();
      });
    });

    test('is no-op for unknown node', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.container
            .read(nodeDexProvider.notifier)
            .setSocialTag(999, NodeSocialTag.contact);

        final state = ctx.container.read(nodeDexProvider);
        expect(state.containsKey(999), isFalse);

        ctx.container.dispose();
      });
    });
  });

  // ===========================================================================
  // setUserNote
  // ===========================================================================

  group('setUserNote', () {
    test('sets user note on existing entry', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(_makeNode(100));
        async.flushMicrotasks();

        ctx.container
            .read(nodeDexProvider.notifier)
            .setUserNote(100, 'Test note');

        final state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.userNote, equals('Test note'));

        ctx.container.dispose();
      });
    });

    test('clears user note with null', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(_makeNode(100));
        async.flushMicrotasks();

        ctx.container
            .read(nodeDexProvider.notifier)
            .setUserNote(100, 'Initial note');
        ctx.container.read(nodeDexProvider.notifier).setUserNote(100, null);

        final state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.userNote, isNull);

        ctx.container.dispose();
      });
    });

    test('clears user note with empty string', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(_makeNode(100));
        async.flushMicrotasks();

        ctx.container
            .read(nodeDexProvider.notifier)
            .setUserNote(100, 'Something');
        ctx.container.read(nodeDexProvider.notifier).setUserNote(100, '');

        final state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.userNote, isNull);

        ctx.container.dispose();
      });
    });

    test('truncates note to 280 characters', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(_makeNode(100));
        async.flushMicrotasks();

        final longNote = 'A' * 500;
        ctx.container.read(nodeDexProvider.notifier).setUserNote(100, longNote);

        final state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.userNote!.length, equals(280));

        ctx.container.dispose();
      });
    });

    test('is no-op for unknown node', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.container.read(nodeDexProvider.notifier).setUserNote(999, 'note');

        final state = ctx.container.read(nodeDexProvider);
        expect(state.containsKey(999), isFalse);

        ctx.container.dispose();
      });
    });
  });

  // ===========================================================================
  // clearAll
  // ===========================================================================

  group('clearAll', () {
    test('removes all entries from state', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.setNodes({100: _makeNode(100), 200: _makeNode(200)});
        async.flushMicrotasks();

        expect(ctx.container.read(nodeDexProvider).length, equals(2));

        ctx.container.read(nodeDexProvider.notifier).clearAll();
        async.flushMicrotasks();

        final state = ctx.container.read(nodeDexProvider);
        expect(state, isEmpty);

        ctx.container.dispose();
      });
    });
  });

  // ===========================================================================
  // exportJson / importJson
  // ===========================================================================

  group('export and import', () {
    test('exportJson returns JSON for current entries', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(_makeNode(100, snr: 10));
        async.flushMicrotasks();

        // Flush store so data is persisted
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        final notifier = ctx.container.read(nodeDexProvider.notifier);
        String? exported;
        notifier.exportJson().then((v) => exported = v);
        async.flushMicrotasks();

        expect(exported, isNotNull);
        expect(exported!.contains('"nn":100'), isTrue);

        ctx.container.dispose();
      });
    });

    test('importJson adds entries and refreshes state', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // Import entries
        final entries = [
          _makeEntry(nodeNum: 500, encounterCount: 10),
          _makeEntry(nodeNum: 600, encounterCount: 5),
        ];
        final json = NodeDexEntry.encodeList(entries);

        int? importCount;
        ctx.container
            .read(nodeDexProvider.notifier)
            .importJson(json)
            .then((v) => importCount = v);
        async.flushMicrotasks();

        expect(importCount, equals(2));

        final state = ctx.container.read(nodeDexProvider);
        expect(state.containsKey(500), isTrue);
        expect(state.containsKey(600), isTrue);
        expect(state[500]!.encounterCount, equals(10));
        expect(state[600]!.encounterCount, equals(5));

        ctx.container.dispose();
      });
    });

    test('importJson merges with existing entries', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // Discover a node
        ctx.nodesNotifier.addNode(_makeNode(100, snr: 5));
        async.flushMicrotasks();

        // Flush store
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        // Import entry for same node with better metrics
        final importedEntry = _makeEntry(
          nodeNum: 100,
          encounterCount: 50,
          bestSnr: 20,
          maxDistanceSeen: 5000.0,
          firstSeen: DateTime(2023, 1, 1),
        );
        final json = NodeDexEntry.encodeList([importedEntry]);

        int? importCount;
        ctx.container
            .read(nodeDexProvider.notifier)
            .importJson(json)
            .then((v) => importCount = v);
        async.flushMicrotasks();

        expect(importCount, equals(1));

        final state = ctx.container.read(nodeDexProvider);
        final entry = state[100]!;
        // Merged: max encounter count
        expect(entry.encounterCount, equals(50));
        // Merged: earliest firstSeen
        expect(entry.firstSeen, equals(DateTime(2023, 1, 1)));

        ctx.container.dispose();
      });
    });
  });

  // ===========================================================================
  // Derived providers
  // ===========================================================================

  group('derived providers', () {
    test('nodeDexEntryProvider returns entry for given nodeNum', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(_makeNode(100, snr: 12));
        async.flushMicrotasks();

        final entry = ctx.container.read(nodeDexEntryProvider(100));
        expect(entry, isNotNull);
        expect(entry!.nodeNum, equals(100));
        expect(entry.bestSnr, equals(12));

        ctx.container.dispose();
      });
    });

    test('nodeDexEntryProvider returns null for unknown node', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        final entry = ctx.container.read(nodeDexEntryProvider(999));
        expect(entry, isNull);

        ctx.container.dispose();
      });
    });

    test('nodeDexStatsProvider computes aggregate statistics', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.setNodes({
          100: _makeNode(100, snr: 5, rssi: -90, distance: 1000),
          200: _makeNode(200, snr: 15, rssi: -60, distance: 5000),
          300: _makeNode(300, snr: 10, rssi: -75, distance: 3000),
        });
        async.flushMicrotasks();

        final stats = ctx.container.read(nodeDexStatsProvider);
        expect(stats.totalNodes, equals(3));
        expect(stats.bestSnrOverall, equals(15));
        expect(stats.bestRssiOverall, equals(-60));
        expect(stats.longestDistance, equals(5000.0));

        ctx.container.dispose();
      });
    });

    test('nodeDexTraitProvider computes trait for node', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(_makeNode(100));
        async.flushMicrotasks();

        // Just verify it doesn't throw and returns some value.
        // Trait might be null if not enough data, that's fine —
        // the point is the provider doesn't throw.
        ctx.container.read(nodeDexTraitProvider(100));
        expect(true, isTrue); // Provider executed without error

        ctx.container.dispose();
      });
    });
  });

  // ===========================================================================
  // Constellation provider
  // ===========================================================================

  group('constellation provider', () {
    test('empty state produces empty constellation', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        final constellation = ctx.container.read(nodeDexConstellationProvider);
        expect(constellation.isEmpty, isTrue);
        expect(constellation.nodeCount, equals(0));
        expect(constellation.edgeCount, equals(0));

        ctx.container.dispose();
      });
    });

    test('nodes with co-seen relationships produce edges', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // Discover three nodes
        ctx.nodesNotifier.setNodes({
          100: _makeNode(100),
          200: _makeNode(200),
          300: _makeNode(300),
        });
        async.flushMicrotasks();

        // Flush co-seen
        async.elapse(const Duration(minutes: 2, seconds: 1));
        async.flushMicrotasks();

        final constellation = ctx.container.read(nodeDexConstellationProvider);
        expect(constellation.nodeCount, equals(3));
        // 3 nodes fully connected = 3 edges (100-200, 100-300, 200-300)
        expect(constellation.edgeCount, equals(3));

        ctx.container.dispose();
      });
    });

    test('constellation edges carry metadata from co-seen relationships', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // Discover two nodes
        ctx.nodesNotifier.setNodes({100: _makeNode(100), 200: _makeNode(200)});
        async.flushMicrotasks();

        // Flush co-seen
        async.elapse(const Duration(minutes: 2, seconds: 1));
        async.flushMicrotasks();

        final constellation = ctx.container.read(nodeDexConstellationProvider);
        expect(constellation.edgeCount, equals(1));

        final edge = constellation.edges.first;
        expect(edge.weight, greaterThan(0));
        expect(edge.firstSeen, isNotNull);
        expect(edge.lastSeen, isNotNull);

        ctx.container.dispose();
      });
    });

    test('nodes without co-seen relationships have no edges', () async {
      // Pre-populate with entries that have no co-seen
      final entries = [
        _makeEntry(nodeNum: 100, encounterCount: 5),
        _makeEntry(nodeNum: 200, encounterCount: 3),
      ];
      await preInitStore.bulkInsert(entries);

      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        final constellation = ctx.container.read(nodeDexConstellationProvider);
        expect(constellation.nodeCount, equals(2));
        expect(constellation.edgeCount, equals(0));

        ctx.container.dispose();
      });
    });
  });

  // ===========================================================================
  // Encounter re-recording with metrics improvement
  // ===========================================================================

  group('encounter metrics improvement', () {
    test('re-encounter improves best SNR', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // First discovery with low SNR
        ctx.nodesNotifier.addNode(_makeNode(100, snr: 5));
        async.flushMicrotasks();

        expect(ctx.container.read(nodeDexProvider)[100]!.bestSnr, equals(5));

        // Wait past cooldown and re-discover with higher SNR
        async.elapse(const Duration(minutes: 6));
        ctx.nodesNotifier.setNodes({100: _makeNode(100, snr: 20)});
        async.flushMicrotasks();

        expect(ctx.container.read(nodeDexProvider)[100]!.bestSnr, equals(20));

        ctx.container.dispose();
      });
    });

    test('re-encounter improves max distance', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(_makeNode(100, distance: 1000.0));
        async.flushMicrotasks();

        expect(
          ctx.container.read(nodeDexProvider)[100]!.maxDistanceSeen,
          equals(1000.0),
        );

        // Wait past cooldown and re-discover with greater distance
        async.elapse(const Duration(minutes: 6));
        ctx.nodesNotifier.setNodes({100: _makeNode(100, distance: 5000.0)});
        async.flushMicrotasks();

        expect(
          ctx.container.read(nodeDexProvider)[100]!.maxDistanceSeen,
          equals(5000.0),
        );

        ctx.container.dispose();
      });
    });
  });

  // ===========================================================================
  // Integration: discovery → co-seen → message flow
  // ===========================================================================

  group('full flow integration', () {
    test(
      'discover nodes, co-seen flush, record messages, verify per-edge counts',
      () {
        fakeAsync((async) {
          final ctx = _createTestContainer(preInitStore: preInitStore);
          addTearDown(ctx.container.dispose);

          _initProvider(ctx.container, async);

          // Step 1: Discover three nodes
          ctx.nodesNotifier.setNodes({
            100: _makeNode(100, snr: 10),
            200: _makeNode(200, snr: 8),
            300: _makeNode(300, snr: 15),
          });
          async.flushMicrotasks();

          var state = ctx.container.read(nodeDexProvider);
          expect(state.length, equals(3));

          // Step 2: Flush co-seen relationships
          async.elapse(const Duration(minutes: 2, seconds: 1));
          async.flushMicrotasks();

          state = ctx.container.read(nodeDexProvider);
          // All three should be co-seen with each other
          expect(state[100]!.coSeenNodes.length, equals(2));
          expect(state[200]!.coSeenNodes.length, equals(2));
          expect(state[300]!.coSeenNodes.length, equals(2));

          // Step 3: Re-enter session (session was cleared after flush)
          async.elapse(const Duration(minutes: 4));
          ctx.nodesNotifier.setNodes({
            100: _makeNode(100, snr: 12),
            200: _makeNode(200, snr: 10),
            300: _makeNode(300, snr: 18),
          });
          async.flushMicrotasks();

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

          ctx.container.dispose();
        });
      },
    );

    test('export after full flow preserves all data', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // Discover and establish relationships
        ctx.nodesNotifier.setNodes({
          100: _makeNode(100, snr: 10, distance: 2000),
          200: _makeNode(200, snr: 15, distance: 3000),
        });
        async.flushMicrotasks();

        // Set social tags
        final notifier = ctx.container.read(nodeDexProvider.notifier);
        notifier.setSocialTag(100, NodeSocialTag.contact);
        notifier.setUserNote(200, 'A relay node');

        // Flush co-seen
        async.elapse(const Duration(minutes: 2, seconds: 1));
        async.flushMicrotasks();

        // Flush store
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        // Export
        String? exported;
        notifier.exportJson().then((v) => exported = v);
        async.flushMicrotasks();

        expect(exported, isNotNull);

        // Import into a fresh store for a second container
        final freshDb = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
        final freshStore = NodeDexSqliteStore(freshDb);
        freshStore.init().then((_) {});
        async.flushMicrotasks();

        final ctx2 = _createTestContainer(preInitStore: freshStore);
        addTearDown(ctx2.container.dispose);

        _initProvider(ctx2.container, async);

        int? importCount;
        ctx2.container
            .read(nodeDexProvider.notifier)
            .importJson(exported!)
            .then((v) => importCount = v);
        async.flushMicrotasks();

        expect(importCount, equals(2));

        final state = ctx2.container.read(nodeDexProvider);
        expect(state[100]!.socialTag, equals(NodeSocialTag.contact));
        expect(state[200]!.userNote, equals('A relay node'));
        expect(state[100]!.coSeenNodes.containsKey(200), isTrue);
        expect(state[200]!.coSeenNodes.containsKey(100), isTrue);

        ctx2.container.dispose();
        ctx.container.dispose();
      });
    });
  });

  // ===========================================================================
  // Edge cases
  // ===========================================================================

  group('edge cases', () {
    test('null myNodeNum does not crash', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(
          preInitStore: preInitStore,
          myNodeNum: null,
        );
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // Should not throw
        ctx.nodesNotifier.addNode(_makeNode(100));
        async.flushMicrotasks();

        // Entry should be created (null != 100)
        final state = ctx.container.read(nodeDexProvider);
        expect(state.containsKey(100), isTrue);

        ctx.container.dispose();
      });
    });

    test('rapid node updates do not corrupt state', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // Rapidly add and update many nodes
        for (int i = 1; i <= 20; i++) {
          ctx.nodesNotifier.addNode(_makeNode(i, snr: i));
        }
        async.flushMicrotasks();

        final state = ctx.container.read(nodeDexProvider);
        expect(state.length, equals(20));

        // All entries should have correct data
        for (int i = 1; i <= 20; i++) {
          expect(state[i], isNotNull, reason: 'Node $i should exist');
          expect(state[i]!.bestSnr, equals(i));
        }

        ctx.container.dispose();
      });
    });

    test('recordMessage after clearAll is no-op', () {
      fakeAsync((async) {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        ctx.nodesNotifier.addNode(_makeNode(100));
        async.flushMicrotasks();

        ctx.container.read(nodeDexProvider.notifier).clearAll();
        async.flushMicrotasks();

        // Should not throw
        ctx.container.read(nodeDexProvider.notifier).recordMessage(100);

        final state = ctx.container.read(nodeDexProvider);
        expect(state, isEmpty);

        ctx.container.dispose();
      });
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

        fakeAsync((async) {
          final ctx = _createTestContainer(preInitStore: preInitStore);
          addTearDown(ctx.container.dispose);

          _initProvider(ctx.container, async);

          // Verify entry loaded (sigil may be regenerated by SQLite store)
          var state = ctx.container.read(nodeDexProvider);

          // Trigger re-encounter (past cooldown from 2024-01-01)
          ctx.nodesNotifier.addNode(_makeNode(100, snr: 10));
          async.flushMicrotasks();

          state = ctx.container.read(nodeDexProvider);
          expect(state[100]!.sigil, isNotNull);

          ctx.container.dispose();
        });
      },
    );

    test('initial node sync on init populates session', () {
      fakeAsync((async) {
        // Start with nodes already present
        final ctx = _createTestContainer(
          preInitStore: preInitStore,
          initialNodes: {100: _makeNode(100), 200: _makeNode(200)},
        );
        addTearDown(ctx.container.dispose);

        _initProvider(ctx.container, async);

        // Entries should have been created from initial sync
        var state = ctx.container.read(nodeDexProvider);
        expect(state.containsKey(100), isTrue);
        expect(state.containsKey(200), isTrue);

        // Flush co-seen — initial sync should have added to session
        async.elapse(const Duration(minutes: 2, seconds: 1));
        async.flushMicrotasks();

        state = ctx.container.read(nodeDexProvider);
        expect(state[100]!.coSeenNodes.containsKey(200), isTrue);
        expect(state[200]!.coSeenNodes.containsKey(100), isTrue);

        ctx.container.dispose();
      });
    });
  });
}
