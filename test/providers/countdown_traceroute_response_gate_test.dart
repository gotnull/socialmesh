// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/telemetry_log.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/countdown_providers.dart';
import 'package:socialmesh/providers/telemetry_providers.dart';
import 'package:socialmesh/services/storage/traceroute_database.dart';
import 'package:socialmesh/services/storage/traceroute_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<(TracerouteDatabase, SqliteTracerouteRepository)> createRepo() async {
    final db = TracerouteDatabase(dbPathOverride: inMemoryDatabasePath);
    await db.open();
    return (db, SqliteTracerouteRepository(db));
  }

  TraceRouteLog makeRun({required int targetNode, required bool response}) {
    return TraceRouteLog(
      nodeNum: targetNode,
      targetNode: targetNode,
      sent: true,
      response: response,
      hopsTowards: 0,
      hopsBack: 0,
      hops: const [],
    );
  }

  ProviderContainer makeContainer(SqliteTracerouteRepository repo) {
    final container = ProviderContainer(
      overrides: [
        // CountdownNotifier.build() listens to connectionStateProvider; give it
        // an inert stream so the notifier builds without a real transport.
        connectionStateProvider.overrideWith(
          (ref) => const Stream<DeviceConnectionState>.empty(),
        ),
        tracerouteRepositoryProvider.overrideWith((ref) async => repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('tracerouteAwaitingResponse (30s notification gate)', () {
    test('returns true when no run exists for the node', () async {
      final (db, repo) = await createRepo();
      addTearDown(db.close);
      final notifier = makeContainer(repo).read(countdownProvider.notifier);

      expect(await notifier.tracerouteAwaitingResponse(999), isTrue);
    });

    test(
      'returns true while the send is still pending (no response yet)',
      () async {
        final (db, repo) = await createRepo();
        addTearDown(db.close);
        // Outbound send is persisted as a pending placeholder.
        await repo.saveRun(makeRun(targetNode: 111, response: false));
        final notifier = makeContainer(repo).read(countdownProvider.notifier);

        expect(await notifier.tracerouteAwaitingResponse(111), isTrue);
      },
    );

    test(
      'returns false once a response has replaced the pending run',
      () async {
        final (db, repo) = await createRepo();
        addTearDown(db.close);
        await repo.saveRun(makeRun(targetNode: 111, response: false));
        // Inbound response replaces the placeholder.
        await repo.replaceOrAddRun(makeRun(targetNode: 111, response: true));
        final notifier = makeContainer(repo).read(countdownProvider.notifier);

        expect(await notifier.tracerouteAwaitingResponse(111), isFalse);
      },
    );
  });
}
