// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/features/incidents/models/incident_mode_models.dart';
import 'package:socialmesh/features/incidents/providers/mesh_incident_providers.dart';
import 'package:socialmesh/features/incidents/services/mesh_incident_database.dart';
import 'package:socialmesh/services/protocol/sip/spp_types.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _seq = 0;
final _pid = pid;
String _dbPath() =>
    p.join(Directory.systemTemp.path, 'active_help_${_pid}_${_seq++}.db');

const _flagsOn =
    'SIP_ENABLED=true\n'
    'MRRP_ENABLED=true\n'
    'MESH_INCIDENTS_ENABLED=true\n'
    'INCIDENT_HELP_REQUEST_ENABLED=true\n';

IncidentEvent _help(int incidentId, IncidentEventType type, int seq) =>
    IncidentEvent(
      incidentId: incidentId,
      workflowKind: IncidentWorkflowKind.helpRequest,
      type: type,
      senderNodeId: 100,
      seq: seq,
      timestamp: DateTime.utc(2026, 6, 17, 10).add(Duration(minutes: seq)),
    );

IncidentEvent _hazard(int incidentId) => IncidentEvent(
  incidentId: incidentId,
  workflowKind: IncidentWorkflowKind.hazardReport,
  type: IncidentEventType.hazardReport,
  senderNodeId: 9,
  seq: 0,
  timestamp: DateTime.utc(2026, 6, 17, 10),
  hazardStatus: IncidentMeshStatus.reported,
  hazardUpdateType: IncidentUpdateType.initial,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => databaseFactory = databaseFactoryFfi);

  Future<(ProviderContainer, MeshIncidentDatabaseImpl)> container() async {
    final db = MeshIncidentDatabaseImpl(dbPathOverride: _dbPath());
    await db.open();
    final c = ProviderContainer(
      overrides: [meshIncidentDatabaseProvider.overrideWithValue(db)],
    );
    return (c, db);
  }

  test('flags off -> empty (no banner) even with a stored create', () async {
    dotenv.loadFromString(envString: 'TEST_MODE=true'); // all flags false
    final (c, db) = await container();
    addTearDown(c.dispose);
    addTearDown(db.close);
    await c
        .read(incidentModeStoreProvider)
        .ingestEvent(_help(0x1, IncidentEventType.create, 0));
    expect(await c.read(activeHelpRequestsProvider.future), isEmpty);
  });

  group('flags on', () {
    setUp(() => dotenv.loadFromString(envString: _flagsOn));

    test('trusted create is present in active list', () async {
      final (c, db) = await container();
      addTearDown(c.dispose);
      addTearDown(db.close);
      await c
          .read(incidentModeStoreProvider)
          .ingestEvent(_help(0xA1, IncidentEventType.create, 0));
      c.read(incidentModeEpochProvider.notifier).bump();
      final active = await c.read(activeHelpRequestsProvider.future);
      expect(active.map((p) => p.incidentId), [0xA1]);
    });

    test('empty store -> no banner', () async {
      final (c, db) = await container();
      addTearDown(c.dispose);
      addTearDown(db.close);
      expect(await c.read(activeHelpRequestsProvider.future), isEmpty);
    });

    test('hazard_report is excluded', () async {
      final (c, db) = await container();
      addTearDown(c.dispose);
      addTearDown(db.close);
      await c.read(incidentModeStoreProvider).ingestEvent(_hazard(0xB2));
      expect(await c.read(activeHelpRequestsProvider.future), isEmpty);
    });

    test('resolved / cancelled / expired are excluded', () async {
      final (c, db) = await container();
      addTearDown(c.dispose);
      addTearDown(db.close);
      final store = c.read(incidentModeStoreProvider);
      // Active.
      await store.ingestEvent(_help(0xC1, IncidentEventType.create, 0));
      // Resolved.
      await store.ingestEvent(_help(0xC2, IncidentEventType.create, 0));
      await store.ingestEvent(_help(0xC2, IncidentEventType.resolve, 1));
      // Cancelled.
      await store.ingestEvent(_help(0xC3, IncidentEventType.create, 0));
      await store.ingestEvent(_help(0xC3, IncidentEventType.cancel, 1));
      // Expired.
      await store.ingestEvent(_help(0xC4, IncidentEventType.create, 0));
      await store.ingestEvent(_help(0xC4, IncidentEventType.expire, 1));

      c.read(incidentModeEpochProvider.notifier).bump();
      final active = await c.read(activeHelpRequestsProvider.future);
      expect(active.map((p) => p.incidentId), [0xC1]);
    });
  });
}
