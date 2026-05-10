// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Integration coverage for OperationsNotifier — the slice of the feature
// that wires repository + engine + state into a Riverpod provider.
//
// Tests use the public ingest() API to drive events directly. NodeDex and
// traceroute stream wiring is exercised by listening to derived providers
// after each ingest.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/features/operations/application/operations_providers.dart';
import 'package:socialmesh/features/operations/data/operations_database.dart';
import 'package:socialmesh/features/operations/domain/operation_catalog.dart';
import 'package:socialmesh/features/operations/models/operation_event.dart';
import 'package:socialmesh/features/operations/models/operation_models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// Builds a container where:
  ///   - the feature flag is forced on,
  ///   - the database is in-memory,
  ///   - NodeDex and traceroute stream sources are stubbed to emit nothing
  ///     (we drive events through the public `ingest()` API instead).
  ///
  /// Returns the container plus the underlying database so the test can
  /// dispose it explicitly.
  Future<({ProviderContainer container, OperationsDatabase database})>
  makeContainer({List<OperationDefinition>? catalog}) async {
    final database = OperationsDatabase(testDbPath: inMemoryDatabasePath);
    final container = ProviderContainer(
      overrides: [
        operationsEnabledProvider.overrideWithValue(true),
        operationsDatabaseProvider.overrideWithValue(database),
        if (catalog != null)
          operationsCatalogProvider.overrideWithValue(catalog),
        // The notifier subscribes to NodeDex + traceroute; both are
        // overridden to no-op so tests can drive events deterministically
        // through the notifier's public ingest() method.
        operationsTracerouteEventProvider.overrideWith(
          (ref) => const Stream.empty(),
        ),
      ],
    );
    // Wait for AsyncNotifier.build() to complete.
    await container.read(operationsProvider.future);
    return (container: container, database: database);
  }

  Future<void> ingestNode(ProviderContainer c, int nodeNum) async {
    await c
        .read(operationsProvider.notifier)
        .ingest(
          OperationNodeEncountered(
            nodeNum: nodeNum,
            occurredAt: DateTime.utc(2026, 5, 9, 12),
          ),
        );
  }

  test('FIRST_CONTACT completes on the first unique node ingest', () async {
    final h = await makeContainer();
    addTearDown(() async {
      h.container.dispose();
      await h.database.close();
    });

    await ingestNode(h.container, 0xAABB);

    final state = h.container.read(operationsProvider).requireValue;
    final fc = state.progress[OperationIds.firstContact]!;
    expect(fc.objectiveProgress['encounter_one'], 1);
    expect(fc.completedAt, isNotNull);

    final completed = h.container.read(operationsCompletedListProvider);
    expect(
      completed.any((vm) => vm.definition.id == OperationIds.firstContact),
      isTrue,
    );
  });

  test('repeated ingest of the same node does not double count', () async {
    final h = await makeContainer();
    addTearDown(() async {
      h.container.dispose();
      await h.database.close();
    });

    await ingestNode(h.container, 1);
    await ingestNode(h.container, 1);
    await ingestNode(h.container, 1);

    final state = h.container.read(operationsProvider).requireValue;
    final sh = state.progress[OperationIds.signalHunter];
    // SignalHunter requires 10 unique encounters; only one unique was
    // delivered so progress is 1, not 3.
    expect(sh?.objectiveProgress['encounter_ten'], 1);
  });

  test('SIGNAL_HUNTER completes at exactly 10 unique nodes', () async {
    final h = await makeContainer();
    addTearDown(() async {
      h.container.dispose();
      await h.database.close();
    });

    for (var i = 1; i <= 10; i++) {
      await ingestNode(h.container, i);
    }

    final state = h.container.read(operationsProvider).requireValue;
    final sh = state.progress[OperationIds.signalHunter]!;
    expect(sh.objectiveProgress['encounter_ten'], 10);
    expect(sh.completedAt, isNotNull);
  });

  test('progress persists across notifier rebuilds', () async {
    final h = await makeContainer();
    addTearDown(() async {
      h.container.dispose();
      await h.database.close();
    });

    for (var i = 1; i <= 4; i++) {
      await ingestNode(h.container, i);
    }
    final beforeReload = h.container
        .read(operationsProvider)
        .requireValue
        .progress;
    expect(
      beforeReload[OperationIds.signalHunter]!
          .objectiveProgress['encounter_ten'],
      4,
    );

    // Force a notifier rebuild without dropping the database.
    h.container.invalidate(operationsProvider);
    await h.container.read(operationsProvider.future);
    final afterReload = h.container
        .read(operationsProvider)
        .requireValue
        .progress;

    expect(
      afterReload[OperationIds.signalHunter]!
          .objectiveProgress['encounter_ten'],
      4,
    );

    // And ingesting the same nodes again is a no-op.
    for (var i = 1; i <= 4; i++) {
      await ingestNode(h.container, i);
    }
    final afterReplay = h.container
        .read(operationsProvider)
        .requireValue
        .progress;
    expect(
      afterReplay[OperationIds.signalHunter]!
          .objectiveProgress['encounter_ten'],
      4,
    );
  });

  test('PATHFINDER completes on a successful traceroute event', () async {
    final h = await makeContainer();
    addTearDown(() async {
      h.container.dispose();
      await h.database.close();
    });

    await h.container
        .read(operationsProvider.notifier)
        .ingest(
          OperationTracerouteCompleted(
            runId: 'run_1',
            targetNodeId: 0xAA,
            hopCount: 1,
            occurredAt: DateTime.utc(2026, 5, 9, 12),
          ),
        );

    final state = h.container.read(operationsProvider).requireValue;
    final pf = state.progress[OperationIds.pathfinder]!;
    expect(pf.objectiveProgress['traceroute_one'], 1);
    expect(pf.completedAt, isNotNull);
  });

  test('a disabled feature flag yields an empty state', () async {
    final database = OperationsDatabase(testDbPath: inMemoryDatabasePath);
    final c = ProviderContainer(
      overrides: [
        operationsEnabledProvider.overrideWithValue(false),
        operationsDatabaseProvider.overrideWithValue(database),
        operationsTracerouteEventProvider.overrideWith(
          (ref) => const Stream.empty(),
        ),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await database.close();
    });

    final state = await c.read(operationsProvider.future);
    expect(state.enabled, isFalse);
    expect(state.catalog, isEmpty);
    expect(c.read(operationsActiveListProvider), isEmpty);
    expect(c.read(operationsCompletedListProvider), isEmpty);
  });

  test(
    'completion is idempotent — second completion ingest is a no-op',
    () async {
      final h = await makeContainer();
      addTearDown(() async {
        h.container.dispose();
        await h.database.close();
      });

      await ingestNode(h.container, 1);
      final firstCompletedAt = h.container
          .read(operationsProvider)
          .requireValue
          .progress[OperationIds.firstContact]!
          .completedAt;
      expect(firstCompletedAt, isNotNull);

      // Subsequent unique encounters do not re-stamp completedAt.
      await ingestNode(h.container, 2);
      final stillSame = h.container
          .read(operationsProvider)
          .requireValue
          .progress[OperationIds.firstContact]!
          .completedAt;
      expect(stillSame, firstCompletedAt);
    },
  );

  test('disabled deferred operations never accumulate progress', () async {
    final h = await makeContainer();
    addTearDown(() async {
      h.container.dispose();
      await h.database.close();
    });

    // Force a multi-hop traceroute event that the disabled multi-hop
    // observer would otherwise be eligible for.
    await h.container
        .read(operationsProvider.notifier)
        .ingest(
          OperationTracerouteCompleted(
            runId: 'multi_run',
            targetNodeId: 0xAA,
            hopCount: 5,
            occurredAt: DateTime.utc(2026, 5, 9, 12),
          ),
        );

    final state = h.container.read(operationsProvider).requireValue;
    expect(
      state.progress.containsKey(OperationIds.multiHopObserver),
      isFalse,
      reason: 'Disabled operation must not have persisted progress.',
    );

    final activeIds = h.container
        .read(operationsActiveListProvider)
        .map((vm) => vm.definition.id)
        .toSet();
    expect(activeIds, isNot(contains(OperationIds.multiHopObserver)));
  });

  test('reward acknowledgement stamps claimedAt only once', () async {
    final h = await makeContainer();
    addTearDown(() async {
      h.container.dispose();
      await h.database.close();
    });

    await ingestNode(h.container, 1);
    await h.container
        .read(operationsProvider.notifier)
        .markRewardClaimed(OperationIds.firstContact);
    final firstClaim = h.container
        .read(operationsProvider)
        .requireValue
        .progress[OperationIds.firstContact]!
        .claimedAt;
    expect(firstClaim, isNotNull);

    // Second call is a no-op — claimedAt does not move.
    await h.container
        .read(operationsProvider.notifier)
        .markRewardClaimed(OperationIds.firstContact);
    final stillSame = h.container
        .read(operationsProvider)
        .requireValue
        .progress[OperationIds.firstContact]!
        .claimedAt;
    expect(stillSame, firstClaim);
  });
}
