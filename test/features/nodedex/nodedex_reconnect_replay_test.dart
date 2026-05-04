// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Regression tests for NodeDex reconnect-replay statistics bug.
//
// Symptom: reconnecting to a Meshtastic device (e.g. T114) replayed the
// device's NodeDB and any buffered MeshPackets through the nodes stream.
// The protocol layer was stamping `lastHeard = DateTime.now()` for those
// replays, so 30-minute-old nodes appeared "online now" and NodeDex
// recorded fresh encounters for nodes the user wasn't currently near.
//
// Fix:
//   - Protocol layer now uses `packet.rxTime` / `nodeInfo.lastHeard` as
//     the authoritative timestamp.
//   - NodeDex classifies each ingest via [NodeIngestSource]: only
//     [NodeIngestSource.livePacket] (lastHeard within ~2 minutes of now)
//     records an encounter / activity bucket / co-seen tick. Sync-replay
//     entries refresh metadata only.
//
// These tests assert the NodeDex side: stale node updates must not
// inflate encounter counts, activity history, or session-seen tracking.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/providers/nodedex_providers.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_database.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_sqlite_store.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/cloud_sync_entitlement_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// =============================================================================
// Test Notifiers
// =============================================================================

class _TestNodesNotifier extends NodesNotifier {
  final Map<int, MeshNode> _initial;

  _TestNodesNotifier([this._initial = const {}]);

  @override
  Map<int, MeshNode> build() => _initial;

  void setNodes(Map<int, MeshNode> nodes) => state = nodes;
}

class _TestMyNodeNumNotifier extends MyNodeNumNotifier {
  final int? _initial;

  _TestMyNodeNumNotifier([this._initial = 99999]);

  @override
  int? build() => _initial;
}

class _FakeTransport extends DeviceTransport {
  final StreamController<DeviceConnectionState> _stateCtrl =
      StreamController<DeviceConnectionState>.broadcast();

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

const int _myNodeNum = 99999;

MeshNode _makeNode(
  int nodeNum, {
  DateTime? firstHeard,
  required DateTime lastHeard,
  int? snr,
  int? rssi,
  double? distance,
}) {
  return MeshNode(
    nodeNum: nodeNum,
    snr: snr,
    rssi: rssi,
    distance: distance,
    firstHeard: firstHeard,
    lastHeard: lastHeard,
  );
}

({
  ProviderContainer container,
  _TestNodesNotifier nodesNotifier,
  NodeDexSqliteStore store,
})
_createTestContainer({
  required NodeDexSqliteStore preInitStore,
  Map<int, MeshNode> initialNodes = const {},
}) {
  final nodesNotifier = _TestNodesNotifier(initialNodes);
  final myNodeNumNotifier = _TestMyNodeNumNotifier(_myNodeNum);

  final container = ProviderContainer(
    overrides: [
      nodesProvider.overrideWith(() => nodesNotifier),
      myNodeNumProvider.overrideWith(() => myNodeNumNotifier),
      nodeDexStoreProvider.overrideWith((ref) => preInitStore),
      canCloudSyncWriteProvider.overrideWithValue(false),
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

Future<void> _pumpEventQueue({int times = 20}) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _initProvider(ProviderContainer container) async {
  container.listen(nodeDexProvider, (_, _) {});
  await _pumpEventQueue();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NodeDexSqliteStore preInitStore;
  late NodeDexDatabase preInitDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

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
  // Stale device-DB sync replay must NOT inflate encounter statistics
  // ===========================================================================

  group('reconnect replay — stale node updates do not inflate stats', () {
    test('stale node DB sync record (>2 min old) does not increment '
        'encounter count on first discovery', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);
      await _initProvider(ctx.container);

      // Simulate a NodeInfo replay during reconnect: the device says
      // "I last heard this node 30 minutes ago" — the protocol layer
      // surfaces that as `node.lastHeard = now - 30min`.
      final now = clock.now();
      final staleNode = _makeNode(
        1001,
        lastHeard: now.subtract(const Duration(minutes: 30)),
        firstHeard: now.subtract(const Duration(hours: 6)),
        snr: 5,
        distance: 1500,
      );
      ctx.nodesNotifier.setNodes({1001: staleNode});
      await _pumpEventQueue();

      final state = ctx.container.read(nodeDexProvider);
      expect(state[1001], isNotNull, reason: 'Entry should be created');
      // Discovery creates the entry with the historical timestamp. The
      // critical assertions are:
      //   1. encounterCount stays at the discovery default (1) — no
      //      live-encounter bump on top of the seed.
      //   2. lastSeen reflects the firmware's lastHeard (30 min ago),
      //      not DateTime.now() — that was the field-bug symptom.
      //   3. The single discovery EncounterRecord is timestamped at the
      //      historical receive time, so the activity histogram does
      //      not get a fresh bucket "at the reconnect moment".
      final entry = state[1001]!;
      expect(
        entry.encounterCount,
        equals(1),
        reason:
            'Stale node-DB sync must not bump encounterCount beyond discovery default',
      );
      final lastSeenAge = now.difference(entry.lastSeen);
      expect(
        lastSeenAge.inMinutes,
        greaterThanOrEqualTo(29),
        reason:
            'lastSeen must mirror the firmware lastHeard (~30 min ago), not now',
      );
      expect(
        entry.encounters.length,
        equals(1),
        reason:
            'Discovery seeds exactly one historical encounter — sync replay must not pile on more',
      );
      final activityBucketAge = now.difference(
        entry.encounters.first.timestamp,
      );
      expect(
        activityBucketAge.inMinutes,
        greaterThanOrEqualTo(29),
        reason:
            'Activity bucket must reflect the historical receive time, not the reconnect moment',
      );
    });

    test('stale node DB sync record on a known node does not increment '
        'encounter count or add activity bucket', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);
      await _initProvider(ctx.container);

      // Step 1: pre-existing node entry.
      final initialEntry = NodeDexEntry.discovered(
        nodeNum: 2002,
        timestamp: clock.now().subtract(const Duration(days: 1)),
      );
      await preInitStore.saveEntryImmediate(initialEntry);

      // Re-init container so the provider picks up the pre-existing entry.
      ctx.container.dispose();
      final ctx2 = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx2.container.dispose);
      await _initProvider(ctx2.container);

      final beforeEntry = ctx2.container.read(nodeDexProvider)[2002];
      expect(beforeEntry, isNotNull);
      final encountersBefore = beforeEntry!.encounterCount;
      final encounterRecordsBefore = beforeEntry.encounters.length;

      // Step 2: simulate reconnect replay — the device delivers the same
      // node, but `lastHeard` is 30 minutes ago (sync replay, not live).
      final now = clock.now();
      ctx2.nodesNotifier.setNodes({
        2002: _makeNode(
          2002,
          lastHeard: now.subtract(const Duration(minutes: 30)),
          firstHeard: beforeEntry.firstSeen,
          snr: 7,
        ),
      });
      await _pumpEventQueue();

      final afterEntry = ctx2.container.read(nodeDexProvider)[2002];
      expect(afterEntry, isNotNull);
      expect(
        afterEntry!.encounterCount,
        equals(encountersBefore),
        reason: 'Reconnect with stale lastHeard must not bump encounterCount',
      );
      expect(
        afterEntry.encounters.length,
        equals(encounterRecordsBefore),
        reason:
            'Reconnect with stale lastHeard must not append a new encounter record (activity histogram bucket)',
      );
    });

    test('reconnect sequence: existing node lastSeen 30 min ago stays '
        'unchanged — encounter statistics not inflated by sync replay', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);
      await _initProvider(ctx.container);

      // Step 1: live sighting establishes the baseline.
      final t0 = clock.now();
      ctx.nodesNotifier.setNodes({
        3003: _makeNode(3003, lastHeard: t0, snr: 10),
      });
      await _pumpEventQueue();

      final baseline = ctx.container.read(nodeDexProvider)[3003];
      expect(baseline, isNotNull);
      final encountersBaseline = baseline!.encounterCount;
      final encounterRecordsBaseline = baseline.encounters.length;

      // Step 2: reconnect — node update arrives with lastHeard 30 min
      // ago. This is the firmware's authoritative receive time, not now,
      // so it must classify as deviceDbSync, not livePacket.
      ctx.nodesNotifier.setNodes({
        3003: _makeNode(
          3003,
          lastHeard: t0.subtract(const Duration(minutes: 30)),
          firstHeard: baseline.firstSeen,
          snr: 8,
        ),
      });
      await _pumpEventQueue();

      final afterReconnect = ctx.container.read(nodeDexProvider)[3003];
      expect(afterReconnect, isNotNull);
      expect(
        afterReconnect!.encounterCount,
        equals(encountersBaseline),
        reason:
            'Reconnect replay must leave encounterCount untouched (no fake encounter)',
      );
      expect(
        afterReconnect.encounters.length,
        equals(encounterRecordsBaseline),
        reason: 'Reconnect replay must leave the activity histogram unchanged',
      );
    });
  });

  // ===========================================================================
  // Live packets DO record encounters
  // ===========================================================================

  group('reconnect replay — live packets still record encounters', () {
    test(
      'live inbound packet (lastHeard within 2 min of now) records an encounter',
      () async {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);
        await _initProvider(ctx.container);

        final initialEntry = NodeDexEntry.discovered(
          nodeNum: 4004,
          timestamp: clock.now().subtract(const Duration(days: 1)),
        );
        await preInitStore.saveEntryImmediate(initialEntry);

        ctx.container.dispose();
        final ctx2 = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx2.container.dispose);
        await _initProvider(ctx2.container);

        final beforeEntry = ctx2.container.read(nodeDexProvider)[4004];
        expect(beforeEntry, isNotNull);

        final now = clock.now();
        ctx2.nodesNotifier.setNodes({
          4004: _makeNode(
            4004,
            lastHeard: now.subtract(const Duration(seconds: 5)),
            firstHeard: beforeEntry!.firstSeen,
            snr: 12,
            rssi: -80,
          ),
        });
        await _pumpEventQueue();

        final afterEntry = ctx2.container.read(nodeDexProvider)[4004];
        expect(afterEntry, isNotNull);
        expect(
          afterEntry!.encounterCount,
          greaterThan(beforeEntry.encounterCount),
          reason: 'Live inbound packet must increment encounterCount',
        );
        expect(
          afterEntry.encounters.length,
          greaterThan(beforeEntry.encounters.length),
          reason: 'Live inbound packet must append an activity bucket',
        );
      },
    );

    test(
      'live encounter timestamp tracks node.lastHeard, not DateTime.now()',
      () async {
        final ctx = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx.container.dispose);
        await _initProvider(ctx.container);

        final initialEntry = NodeDexEntry.discovered(
          nodeNum: 5005,
          timestamp: clock.now().subtract(const Duration(days: 1)),
        );
        await preInitStore.saveEntryImmediate(initialEntry);

        ctx.container.dispose();
        final ctx2 = _createTestContainer(preInitStore: preInitStore);
        addTearDown(ctx2.container.dispose);
        await _initProvider(ctx2.container);

        // Live sighting where node.lastHeard is 30 seconds ago — within
        // the live window, so it counts as a fresh encounter, but the
        // encounter timestamp must reflect the actual heard time, not now.
        final now = clock.now();
        final actualHeardAt = now.subtract(const Duration(seconds: 30));
        ctx2.nodesNotifier.setNodes({
          5005: _makeNode(5005, lastHeard: actualHeardAt, snr: 8),
        });
        await _pumpEventQueue();

        final entry = ctx2.container.read(nodeDexProvider)[5005];
        expect(entry, isNotNull);
        expect(
          entry!.encounters,
          isNotEmpty,
          reason: 'Live packet must record an encounter',
        );
        final lastEncounter = entry.encounters.last;
        // Allow ±1s of tolerance for clock granularity.
        final delta = lastEncounter.timestamp
            .difference(actualHeardAt)
            .inMilliseconds
            .abs();
        expect(
          delta,
          lessThanOrEqualTo(1000),
          reason:
              'Encounter timestamp must reflect node.lastHeard (the actual receive time), not DateTime.now()',
        );
      },
    );
  });

  // ===========================================================================
  // Init seed pass must never count as a live encounter
  // ===========================================================================

  group('initSeed pass is metadata-only', () {
    test('init seed (seedOnly: true) with fresh lastHeard does not '
        'record an encounter on first discovery', () async {
      // Seed the store with an existing entry so init has data to load.
      final initialEntry = NodeDexEntry.discovered(
        nodeNum: 6006,
        timestamp: clock.now().subtract(const Duration(days: 1)),
      );
      await preInitStore.saveEntryImmediate(initialEntry);

      // Pre-populate nodesProvider with a node whose lastHeard is RIGHT
      // NOW. _init() runs `_handleNodesUpdate(..., seedOnly: true)`
      // against this snapshot, and it MUST NOT inflate stats just
      // because the data happened to be fresh at app start.
      final ctx = _createTestContainer(
        preInitStore: preInitStore,
        initialNodes: {6006: _makeNode(6006, lastHeard: clock.now(), snr: 12)},
      );
      addTearDown(ctx.container.dispose);
      await _initProvider(ctx.container);

      final entry = ctx.container.read(nodeDexProvider)[6006];
      expect(entry, isNotNull);
      // Init seed must not bump encounter count above what the store had,
      // and it must not append activity buckets even when the live-node
      // snapshot looks fresh at app start.
      expect(
        entry!.encounterCount,
        equals(initialEntry.encounterCount),
        reason: 'Init seed pass must not inflate encounterCount',
      );
      expect(
        entry.encounters.length,
        equals(initialEntry.encounters.length),
        reason:
            'Init seed pass must not append activity buckets — encounter count and activity history come from storage, not the seed walk',
      );
    });
  });

  // ===========================================================================
  // Source classification edge cases
  // ===========================================================================

  group('NodeIngestSource classification', () {
    test('node with null lastHeard does not record an encounter', () async {
      final ctx = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx.container.dispose);
      await _initProvider(ctx.container);

      // Pre-existing entry, then update arrives with NULL lastHeard
      // (source: unknown). Must not count as live.
      final initialEntry = NodeDexEntry.discovered(
        nodeNum: 7007,
        timestamp: clock.now().subtract(const Duration(days: 1)),
      );
      await preInitStore.saveEntryImmediate(initialEntry);

      ctx.container.dispose();
      final ctx2 = _createTestContainer(preInitStore: preInitStore);
      addTearDown(ctx2.container.dispose);
      await _initProvider(ctx2.container);

      final beforeEntry = ctx2.container.read(nodeDexProvider)[7007];
      expect(beforeEntry, isNotNull);

      ctx2.nodesNotifier.setNodes({
        7007: MeshNode(nodeNum: 7007, lastHeard: null),
      });
      await _pumpEventQueue();

      final afterEntry = ctx2.container.read(nodeDexProvider)[7007];
      expect(afterEntry, isNotNull);
      expect(
        afterEntry!.encounterCount,
        equals(beforeEntry!.encounterCount),
        reason: 'Unknown source (null lastHeard) must not bump stats',
      );
      expect(
        afterEntry.encounters.length,
        equals(beforeEntry.encounters.length),
        reason: 'Unknown source must not append activity buckets',
      );
    });
  });
}
