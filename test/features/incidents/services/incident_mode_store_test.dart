// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/features/incidents/models/incident_mode_models.dart';
import 'package:socialmesh/features/incidents/services/incident_mode_store.dart';
import 'package:socialmesh/features/incidents/services/mesh_incident_database.dart';
import 'package:socialmesh/services/protocol/sip/spp_types.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _seq = 0;
final _testPid = pid;

String _uniqueDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'incident_mode_${_testPid}_${_seq++}.db');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  final base = DateTime.utc(2026, 6, 17, 10);
  DateTime at(int minutes) => base.add(Duration(minutes: minutes));
  const incidentId = 0x1001;
  const requester = 100;
  const responderA = 200;

  IncidentEvent create({int minute = 0, DateTime? expiresAt}) => IncidentEvent(
    incidentId: incidentId,
    workflowKind: IncidentWorkflowKind.helpRequest,
    type: IncidentEventType.create,
    senderNodeId: requester,
    seq: 0,
    timestamp: at(minute),
    receivedAt: at(minute),
    expiresAt: expiresAt,
  );

  IncidentEvent helpEvent({
    required IncidentEventType type,
    required int sender,
    required int seq,
    required int minute,
    IncidentQuickUpdate? quickUpdate,
    IncidentLocation? location,
    IncidentMessage? message,
  }) => IncidentEvent(
    incidentId: incidentId,
    workflowKind: IncidentWorkflowKind.helpRequest,
    type: type,
    senderNodeId: sender,
    seq: seq,
    timestamp: at(minute),
    receivedAt: at(minute),
    quickUpdate: quickUpdate,
    location: location,
    message: message,
  );

  Future<(MeshIncidentDatabaseImpl, IncidentModeStore)> openStore() async {
    final db = MeshIncidentDatabaseImpl(dbPathOverride: _uniqueDbPath());
    await db.open();
    return (db, IncidentModeStore(db: db));
  }

  group('schema creation + migration', () {
    test(
      'fresh DB creates incident_mode_events and round-trips an event',
      () async {
        final (db, store) = await openStore();
        addTearDown(db.close);

        expect(await store.ingestEvent(create()), isTrue);
        final timeline = await store.getTimeline(incidentId);
        expect(timeline, hasLength(1));
        expect(timeline.single.type, IncidentEventType.create);
      },
    );

    test('schema version is 2', () {
      expect(meshIncidentSchemaVersion, 2);
    });

    test('migrates a v1 DB without breaking existing hazard data', () async {
      final path = _uniqueDbPath();

      // Build a v1 database (legacy hazard reports table only) with one row.
      final legacy = await openDatabase(
        path,
        version: 1,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE mesh_incident_reports (
              id              INTEGER PRIMARY KEY AUTOINCREMENT,
              caseId          INTEGER NOT NULL,
              seqNum          INTEGER NOT NULL,
              updateType      INTEGER NOT NULL,
              confidence      INTEGER NOT NULL,
              classification  INTEGER NOT NULL,
              priority        INTEGER NOT NULL,
              status          INTEGER NOT NULL,
              reporterRole    INTEGER NOT NULL,
              timestamp       INTEGER NOT NULL,
              refSeq          INTEGER,
              latitude        REAL,
              longitude       REAL,
              body            TEXT NOT NULL,
              senderNodeId    INTEGER NOT NULL,
              isSuperseded    INTEGER NOT NULL DEFAULT 0,
              receivedAt      INTEGER,
              UNIQUE(caseId, seqNum, senderNodeId)
            )
          ''');
        },
      );
      await legacy.insert('mesh_incident_reports', {
        'caseId': 7,
        'seqNum': 0,
        'updateType': 0,
        'confidence': 0,
        'classification': 0,
        'priority': 0,
        'status': 0,
        'reporterRole': 0,
        'timestamp': at(0).millisecondsSinceEpoch,
        'refSeq': null,
        'latitude': null,
        'longitude': null,
        'body': 'legacy hazard',
        'senderNodeId': 9,
        'isSuperseded': 0,
        'receivedAt': null,
      });
      await legacy.close();

      // Open with the v2 impl -> triggers onUpgrade(1 -> 2).
      final db = MeshIncidentDatabaseImpl(dbPathOverride: path);
      await db.open();
      addTearDown(db.close);

      // Legacy hazard data survived the migration.
      final reports = await db.getReportsForCase(7);
      expect(reports, hasLength(1));
      expect(reports.single.body, 'legacy hazard');

      // New event log table is usable.
      final store = IncidentModeStore(db: db);
      expect(await store.ingestEvent(create()), isTrue);
      expect(await store.getTimeline(incidentId), hasLength(1));
    });
  });

  group('insert + dedupe', () {
    test('insert IncidentCreate then project broadcasting', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);

      await store.ingestEvent(create());
      final proj = await store.loadIncidentProjection(incidentId);
      expect(proj, isNotNull);
      expect(proj!.helpState, IncidentLifecycleState.broadcasting);
      expect(proj.originNodeId, requester);
    });

    test('duplicate IncidentCreate is idempotent', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);

      expect(await store.ingestEvent(create()), isTrue);
      expect(await store.ingestEvent(create()), isFalse); // duplicate ignored
      expect(await store.getTimeline(incidentId), hasLength(1));
    });

    test('out-of-order inserts converge through the reducer', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);

      final events = [
        helpEvent(
          type: IncidentEventType.responderStatus,
          sender: responderA,
          seq: 2,
          minute: 4,
          quickUpdate: IncidentQuickUpdate.arrived,
        ),
        helpEvent(
          type: IncidentEventType.responderAccept,
          sender: responderA,
          seq: 0,
          minute: 2,
        ),
        create(minute: 0),
        helpEvent(
          type: IncidentEventType.responderStatus,
          sender: responderA,
          seq: 1,
          minute: 3,
          quickUpdate: IncidentQuickUpdate.onMyWay,
        ),
      ];
      await store.ingestEvents(events);

      final proj = await store.loadIncidentProjection(incidentId);
      expect(proj!.helpState, IncidentLifecycleState.responderArrived);
      // Persisted timeline is chronological regardless of insert order.
      final times = (await store.getTimeline(
        incidentId,
      )).map((e) => e.timestamp).toList();
      expect(times, [...times]..sort());
    });
  });

  group('participants + quick status', () {
    test(
      'ResponderAccept persists participant and projects with responder',
      () async {
        final (db, store) = await openStore();
        addTearDown(db.close);
        await store.ingestEvents([
          create(),
          helpEvent(
            type: IncidentEventType.responderAccept,
            sender: responderA,
            seq: 0,
            minute: 2,
          ),
        ]);
        final proj = await store.loadIncidentProjection(incidentId);
        expect(proj!.helpState, IncidentLifecycleState.activeWithResponder);
        expect(proj.responderCount, 1);
        expect(proj.responders.single.nodeId, responderA);
      },
    );

    test('ResponderLeave returns to activeNoResponder', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      await store.ingestEvents([
        create(),
        helpEvent(
          type: IncidentEventType.responderAccept,
          sender: responderA,
          seq: 0,
          minute: 2,
        ),
        helpEvent(
          type: IncidentEventType.responderLeave,
          sender: responderA,
          seq: 1,
          minute: 3,
        ),
      ]);
      final proj = await store.loadIncidentProjection(incidentId);
      expect(proj!.helpState, IncidentLifecycleState.activeNoResponder);
      expect(proj.responderCount, 0);
    });

    test('RequesterStatus persists quick update', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      await store.ingestEvents([
        create(),
        helpEvent(
          type: IncidentEventType.requesterStatus,
          sender: requester,
          seq: 1,
          minute: 1,
          quickUpdate: IncidentQuickUpdate.cantMove,
        ),
      ]);
      final proj = await store.loadIncidentProjection(incidentId);
      expect(proj!.lastRequesterStatus, IncidentQuickUpdate.cantMove);
    });

    test('ResponderStatus persists quick update on the responder', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      await store.ingestEvents([
        create(),
        helpEvent(
          type: IncidentEventType.responderAccept,
          sender: responderA,
          seq: 0,
          minute: 2,
        ),
        helpEvent(
          type: IncidentEventType.responderStatus,
          sender: responderA,
          seq: 1,
          minute: 3,
          quickUpdate: IncidentQuickUpdate.onMyWay,
        ),
      ]);
      final proj = await store.loadIncidentProjection(incidentId);
      expect(proj!.helpState, IncidentLifecycleState.responderEnRoute);
      expect(proj.responders.single.lastStatus, IncidentQuickUpdate.onMyWay);
    });
  });

  group('location + message persistence', () {
    test(
      'IncidentLocation persists accuracy, fixedAt and receivedAt',
      () async {
        final (db, store) = await openStore();
        addTearDown(db.close);
        final fix = at(1);
        await store.ingestEvents([
          create(),
          helpEvent(
            type: IncidentEventType.location,
            sender: requester,
            seq: 1,
            minute: 2,
            location: IncidentLocation(
              incidentId: incidentId,
              nodeId: requester,
              latitude: -33.8688,
              longitude: 151.2093,
              accuracyMeters: 12.5,
              fixedAt: fix,
              receivedAt: at(2),
            ),
          ),
        ]);
        final timeline = await store.getTimeline(incidentId);
        final locEvent = timeline.firstWhere(
          (e) => e.type == IncidentEventType.location,
        );
        final loc = locEvent.location!;
        expect(loc.nodeId, requester);
        expect(loc.latitude, closeTo(-33.8688, 1e-9));
        expect(loc.longitude, closeTo(151.2093, 1e-9));
        expect(loc.accuracyMeters, 12.5);
        expect(loc.fixedAt, fix);
        expect(loc.receivedAt, at(2));

        final proj = await store.loadIncidentProjection(incidentId);
        expect(proj!.lastRequesterLocation?.latitude, closeTo(-33.8688, 1e-9));
      },
    );

    test('IncidentMessage persists the (already-sanitized) text', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      await store.ingestEvents([
        create(),
        helpEvent(
          type: IncidentEventType.message,
          sender: requester,
          seq: 1,
          minute: 2,
          message: IncidentMessage(
            incidentId: incidentId,
            senderNodeId: requester,
            seq: 1,
            text: 'near the north gate',
            timestamp: at(2),
          ),
        ),
      ]);
      final timeline = await store.getTimeline(incidentId);
      final msgEvent = timeline.firstWhere(
        (e) => e.type == IncidentEventType.message,
      );
      expect(msgEvent.message!.text, 'near the north gate');
      expect(msgEvent.message!.seq, 1);
      expect(msgEvent.message!.senderNodeId, requester);
    });
  });

  group('terminal projections', () {
    test('IncidentResolve projects resolvedSafe', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      await store.ingestEvents([
        create(),
        helpEvent(
          type: IncidentEventType.resolve,
          sender: requester,
          seq: 1,
          minute: 5,
        ),
      ]);
      final proj = await store.loadIncidentProjection(incidentId);
      expect(proj!.helpState, IncidentLifecycleState.resolvedSafe);
      expect(proj.isTerminal, isTrue);
    });

    test(
      'IncidentCancel projects cancelled (distinct from resolved)',
      () async {
        final (db, store) = await openStore();
        addTearDown(db.close);
        await store.ingestEvents([
          create(),
          helpEvent(
            type: IncidentEventType.cancel,
            sender: requester,
            seq: 1,
            minute: 3,
          ),
        ]);
        final proj = await store.loadIncidentProjection(incidentId);
        expect(proj!.helpState, IncidentLifecycleState.cancelled);
        expect(proj.helpState, isNot(IncidentLifecycleState.resolvedSafe));
      },
    );

    test('expiry projects expired', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      await store.ingestEvents([
        create(expiresAt: at(30)),
        helpEvent(
          type: IncidentEventType.expire,
          sender: requester,
          seq: 1,
          minute: 31,
        ),
      ]);
      final proj = await store.loadIncidentProjection(incidentId);
      expect(proj!.helpState, IncidentLifecycleState.expired);
      expect(proj.isTerminal, isTrue);
    });
  });

  group('hazard isolation in storage', () {
    test('hazard event persists but never enters help lifecycle', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      await store.ingestEvent(
        IncidentEvent(
          incidentId: 0x900,
          workflowKind: IncidentWorkflowKind.hazardReport,
          type: IncidentEventType.hazardReport,
          senderNodeId: 9,
          seq: 0,
          timestamp: at(0),
          hazardStatus: IncidentMeshStatus.active,
          hazardUpdateType: IncidentUpdateType.initial,
        ),
      );
      final proj = await store.loadIncidentProjection(0x900);
      expect(proj!.workflowKind, IncidentWorkflowKind.hazardReport);
      expect(proj.helpState, isNull);
      expect(proj.hazardStatus, IncidentMeshStatus.active);
      expect(proj.responderCount, 0);
    });
  });

  group('getActiveHelpRequests', () {
    test(
      'excludes resolved/cancelled/expired and hazard, includes active',
      () async {
        final (db, store) = await openStore();
        addTearDown(db.close);

        // Active help request (id 1).
        await store.ingestEvent(
          IncidentEvent(
            incidentId: 1,
            workflowKind: IncidentWorkflowKind.helpRequest,
            type: IncidentEventType.create,
            senderNodeId: requester,
            seq: 0,
            timestamp: at(0),
          ),
        );
        // Resolved help request (id 2).
        await store.ingestEvents([
          IncidentEvent(
            incidentId: 2,
            workflowKind: IncidentWorkflowKind.helpRequest,
            type: IncidentEventType.create,
            senderNodeId: requester,
            seq: 0,
            timestamp: at(0),
          ),
          IncidentEvent(
            incidentId: 2,
            workflowKind: IncidentWorkflowKind.helpRequest,
            type: IncidentEventType.resolve,
            senderNodeId: requester,
            seq: 1,
            timestamp: at(1),
          ),
        ]);
        // Hazard report (id 3) — must never appear in active help requests.
        await store.ingestEvent(
          IncidentEvent(
            incidentId: 3,
            workflowKind: IncidentWorkflowKind.hazardReport,
            type: IncidentEventType.hazardReport,
            senderNodeId: 9,
            seq: 0,
            timestamp: at(0),
            hazardStatus: IncidentMeshStatus.reported,
            hazardUpdateType: IncidentUpdateType.initial,
          ),
        );

        final active = await store.getActiveHelpRequests();
        expect(active.map((p) => p.incidentId), [1]);
      },
    );
  });
}
