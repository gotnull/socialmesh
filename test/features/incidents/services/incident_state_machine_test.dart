// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/auth/permission_service.dart';
import 'package:socialmesh/core/auth/role.dart';
import 'package:socialmesh/features/incidents/models/incident.dart';
import 'package:socialmesh/features/incidents/models/incident_transition.dart';
import 'package:socialmesh/features/incidents/services/incident_database.dart';
import 'package:socialmesh/features/incidents/services/incident_state_machine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PermissionService _service(Role role) =>
    PermissionService(role: role, orgId: 'org-1');

Incident _draft({
  String id = 'inc-1',
  String ownerId = 'uid-owner',
  String? assigneeId,
}) => Incident(
  id: id,
  orgId: 'org-1',
  title: 'Test incident',
  state: IncidentState.draft,
  priority: IncidentPriority.immediate,
  classification: IncidentClassification.operational,
  ownerId: ownerId,
  assigneeId: assigneeId,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

/// Insert a bare incident row into the database so the state machine
/// has something to update.
Future<void> _insertIncident(IncidentDatabase db, Incident incident) async {
  await db.database.insert('incidents', incident.toMap());
}

/// Read the current state projection from the incidents table.
Future<String> _readState(IncidentDatabase db, String incidentId) async {
  final rows = await db.database.query(
    'incidents',
    columns: ['state'],
    where: 'id = ?',
    whereArgs: [incidentId],
  );
  return rows.first['state'] as String;
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late IncidentDatabase db;

  setUp(() async {
    db = IncidentDatabase(dbPathOverride: inMemoryDatabasePath);
    await db.open();
  });

  tearDown(() async {
    await db.close();
  });

  // =========================================================================
  // 1) Valid transitions (11)
  // =========================================================================

  group('valid transitions', () {
    Future<IncidentTransition> apply(
      IncidentStateMachine sm,
      Incident incident,
      IncidentState target, {
      String actorId = 'uid-actor',
      String? assigneeId,
      String? note,
    }) async {
      return sm.transition(
        incident: incident,
        target: target,
        actorId: actorId,
        assigneeId: assigneeId,
        note: note,
      );
    }

    test('draft -> open (submit)', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.operator),
      );
      final incident = _draft();
      await _insertIncident(db, incident);

      final t = await apply(sm, incident, IncidentState.open);
      expect(t.fromState, IncidentState.draft);
      expect(t.toState, IncidentState.open);
      expect(await _readState(db, incident.id), 'open');
    });

    test('draft -> cancelled (cancel)', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.supervisor),
      );
      final incident = _draft();
      await _insertIncident(db, incident);

      final t = await apply(sm, incident, IncidentState.cancelled);
      expect(t.toState, IncidentState.cancelled);
      expect(await _readState(db, incident.id), 'cancelled');
    });

    test('open -> assigned (assign)', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.supervisor),
      );
      final incident = _draft().copyWith(state: IncidentState.open);
      await _insertIncident(db, incident);

      final t = await apply(
        sm,
        incident,
        IncidentState.assigned,
        assigneeId: 'uid-assignee',
      );
      expect(t.toState, IncidentState.assigned);
      expect(await _readState(db, incident.id), 'assigned');
    });

    test('open -> escalated (escalate)', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.operator),
      );
      final incident = _draft().copyWith(state: IncidentState.open);
      await _insertIncident(db, incident);

      final t = await apply(sm, incident, IncidentState.escalated);
      expect(t.toState, IncidentState.escalated);
      expect(await _readState(db, incident.id), 'escalated');
    });

    test('open -> resolved (resolve by supervisor)', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.supervisor),
      );
      final incident = _draft().copyWith(state: IncidentState.open);
      await _insertIncident(db, incident);

      final t = await apply(sm, incident, IncidentState.resolved);
      expect(t.toState, IncidentState.resolved);
      expect(await _readState(db, incident.id), 'resolved');
    });

    test('open -> cancelled (cancel)', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.admin),
      );
      final incident = _draft().copyWith(state: IncidentState.open);
      await _insertIncident(db, incident);

      final t = await apply(sm, incident, IncidentState.cancelled);
      expect(t.toState, IncidentState.cancelled);
    });

    test('escalated -> assigned (assign after escalation)', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.admin),
      );
      final incident = _draft().copyWith(state: IncidentState.escalated);
      await _insertIncident(db, incident);

      final t = await apply(
        sm,
        incident,
        IncidentState.assigned,
        assigneeId: 'uid-responder',
      );
      expect(t.toState, IncidentState.assigned);
    });

    test('escalated -> cancelled (cancel)', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.supervisor),
      );
      final incident = _draft().copyWith(state: IncidentState.escalated);
      await _insertIncident(db, incident);

      final t = await apply(sm, incident, IncidentState.cancelled);
      expect(t.toState, IncidentState.cancelled);
    });

    test('assigned -> resolved (resolve)', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.supervisor),
      );
      final incident = _draft().copyWith(
        state: IncidentState.assigned,
        assigneeId: 'uid-assignee',
      );
      await _insertIncident(db, incident);

      final t = await apply(sm, incident, IncidentState.resolved);
      expect(t.toState, IncidentState.resolved);
    });

    test('assigned -> cancelled (cancel)', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.admin),
      );
      final incident = _draft().copyWith(state: IncidentState.assigned);
      await _insertIncident(db, incident);

      final t = await apply(sm, incident, IncidentState.cancelled);
      expect(t.toState, IncidentState.cancelled);
    });

    test('resolved -> closed (close)', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.supervisor),
      );
      final incident = _draft().copyWith(state: IncidentState.resolved);
      await _insertIncident(db, incident);

      final t = await apply(sm, incident, IncidentState.closed);
      expect(t.toState, IncidentState.closed);
      expect(await _readState(db, incident.id), 'closed');
    });
  });

  // =========================================================================
  // 2) Invalid transitions (12)
  // =========================================================================

  group('invalid transitions', () {
    IncidentStateMachine sm() =>
        IncidentStateMachine(db: db, permissions: _service(Role.admin));

    Future<void> expectInvalid(Incident incident, IncidentState target) async {
      await _insertIncident(db, incident);
      expect(
        () => sm().transition(
          incident: incident,
          target: target,
          actorId: 'uid-admin',
          assigneeId: target == IncidentState.assigned ? 'uid-assignee' : null,
        ),
        throwsA(isA<InvalidTransitionException>()),
      );
    }

    test('closed -> any (terminal state)', () async {
      await expectInvalid(
        _draft(id: 'inv-1').copyWith(state: IncidentState.closed),
        IncidentState.open,
      );
    });

    test('cancelled -> any (terminal state)', () async {
      await expectInvalid(
        _draft(id: 'inv-2').copyWith(state: IncidentState.cancelled),
        IncidentState.open,
      );
    });

    test('resolved -> open (cannot reopen)', () async {
      await expectInvalid(
        _draft(id: 'inv-3').copyWith(state: IncidentState.resolved),
        IncidentState.open,
      );
    });

    test('resolved -> assigned (cannot reassign)', () async {
      await expectInvalid(
        _draft(id: 'inv-4').copyWith(state: IncidentState.resolved),
        IncidentState.assigned,
      );
    });

    test('resolved -> escalated (cannot escalate)', () async {
      await expectInvalid(
        _draft(id: 'inv-5').copyWith(state: IncidentState.resolved),
        IncidentState.escalated,
      );
    });

    test('assigned -> open (cannot unassign)', () async {
      await expectInvalid(
        _draft(id: 'inv-6').copyWith(state: IncidentState.assigned),
        IncidentState.open,
      );
    });

    test('assigned -> escalated (only from open)', () async {
      await expectInvalid(
        _draft(id: 'inv-7').copyWith(state: IncidentState.assigned),
        IncidentState.escalated,
      );
    });

    test('draft -> assigned (must submit first)', () async {
      await expectInvalid(_draft(id: 'inv-8'), IncidentState.assigned);
    });

    test('draft -> resolved (must submit first)', () async {
      await expectInvalid(_draft(id: 'inv-9'), IncidentState.resolved);
    });

    test('draft -> escalated (must submit first)', () async {
      await expectInvalid(_draft(id: 'inv-10'), IncidentState.escalated);
    });

    test('draft -> closed (must submit/resolve/close)', () async {
      await expectInvalid(_draft(id: 'inv-11'), IncidentState.closed);
    });

    test('open -> closed (must resolve first)', () async {
      await expectInvalid(
        _draft(id: 'inv-12').copyWith(state: IncidentState.open),
        IncidentState.closed,
      );
    });
  });

  // =========================================================================
  // 3) Terminal state rejection
  // =========================================================================

  group('terminal state rejection', () {
    test('no transition from closed', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.admin),
      );
      final incident = _draft(
        id: 'term-1',
      ).copyWith(state: IncidentState.closed);
      await _insertIncident(db, incident);

      for (final target in IncidentState.values) {
        if (target == IncidentState.closed) continue;
        expect(
          () => sm.transition(
            incident: incident,
            target: target,
            actorId: 'uid-admin',
            assigneeId: target == IncidentState.assigned
                ? 'uid-assignee'
                : null,
          ),
          throwsA(isA<InvalidTransitionException>()),
          reason: 'closed -> ${target.name} should be rejected',
        );
      }
    });

    test('no transition from cancelled', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.admin),
      );
      final incident = _draft(
        id: 'term-2',
      ).copyWith(state: IncidentState.cancelled);
      await _insertIncident(db, incident);

      for (final target in IncidentState.values) {
        if (target == IncidentState.cancelled) continue;
        expect(
          () => sm.transition(
            incident: incident,
            target: target,
            actorId: 'uid-admin',
            assigneeId: target == IncidentState.assigned
                ? 'uid-assignee'
                : null,
          ),
          throwsA(isA<InvalidTransitionException>()),
          reason: 'cancelled -> ${target.name} should be rejected',
        );
      }
    });
  });

  // =========================================================================
  // 4) Projection rebuild
  // =========================================================================

  group('projection rebuild', () {
    test('rebuilds state from transitions after projection deleted', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.admin),
      );
      final incident = _draft(id: 'rebuild-1');
      await _insertIncident(db, incident);

      // Apply: draft -> open -> assigned -> resolved -> closed
      var current = incident;
      current = current.copyWith(state: IncidentState.open);
      await sm.transition(
        incident: incident,
        target: IncidentState.open,
        actorId: 'uid-actor',
      );

      await sm.transition(
        incident: current,
        target: IncidentState.assigned,
        actorId: 'uid-actor',
        assigneeId: 'uid-responder',
      );
      current = current.copyWith(state: IncidentState.assigned);

      await sm.transition(
        incident: current,
        target: IncidentState.resolved,
        actorId: 'uid-actor',
      );
      current = current.copyWith(state: IncidentState.resolved);

      await sm.transition(
        incident: current,
        target: IncidentState.closed,
        actorId: 'uid-actor',
      );

      // Verify current state = closed.
      expect(await _readState(db, 'rebuild-1'), 'closed');

      // Corrupt: reset state to draft in projection.
      await db.database.update(
        'incidents',
        {'state': 'draft'},
        where: 'id = ?',
        whereArgs: ['rebuild-1'],
      );
      expect(await _readState(db, 'rebuild-1'), 'draft');

      // Rebuild from transitions.
      final rebuilt = await sm.rebuildProjection('rebuild-1');
      expect(rebuilt, IncidentState.closed);
      expect(await _readState(db, 'rebuild-1'), 'closed');
    });

    test('rebuilds intermediate state correctly', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.supervisor),
      );
      final incident = _draft(id: 'rebuild-2');
      await _insertIncident(db, incident);

      // Apply: draft -> open -> escalated
      await sm.transition(
        incident: incident,
        target: IncidentState.open,
        actorId: 'uid-actor',
      );
      final open = incident.copyWith(state: IncidentState.open);

      await sm.transition(
        incident: open,
        target: IncidentState.escalated,
        actorId: 'uid-actor',
      );

      // Corrupt: reset state to draft.
      await db.database.update(
        'incidents',
        {'state': 'draft'},
        where: 'id = ?',
        whereArgs: ['rebuild-2'],
      );

      final rebuilt = await sm.rebuildProjection('rebuild-2');
      expect(rebuilt, IncidentState.escalated);
    });
  });

  // =========================================================================
  // 5) Role enforcement
  // =========================================================================

  group('role enforcement', () {
    test('operator resolving own assigned incident (allowed)', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.operator),
      );

      // Operator is the assignee.
      final incident = _draft(
        id: 'role-1',
      ).copyWith(state: IncidentState.assigned, assigneeId: 'uid-operator');
      await _insertIncident(db, incident);

      // The actor is the assignee — Y* cell should pass.
      final t = await sm.transition(
        incident: incident,
        target: IncidentState.resolved,
        actorId: 'uid-operator',
      );
      expect(t.toState, IncidentState.resolved);
    });

    test('operator resolving non-own incident (denied)', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.operator),
      );

      // Operator is NOT the assignee.
      final incident = _draft(
        id: 'role-2',
      ).copyWith(state: IncidentState.assigned, assigneeId: 'uid-someone-else');
      await _insertIncident(db, incident);

      expect(
        () => sm.transition(
          incident: incident,
          target: IncidentState.resolved,
          actorId: 'uid-operator',
        ),
        throwsA(isA<InsufficientPermissionException>()),
      );
    });

    test('observer attempting write (denied)', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.observer),
      );
      final incident = _draft(id: 'role-3');
      await _insertIncident(db, incident);

      expect(
        () => sm.transition(
          incident: incident,
          target: IncidentState.open,
          actorId: 'uid-observer',
        ),
        throwsA(isA<InsufficientPermissionException>()),
      );
    });

    test('operator cannot assign (denied)', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.operator),
      );
      final incident = _draft(id: 'role-4').copyWith(state: IncidentState.open);
      await _insertIncident(db, incident);

      expect(
        () => sm.transition(
          incident: incident,
          target: IncidentState.assigned,
          actorId: 'uid-operator',
          assigneeId: 'uid-target',
        ),
        throwsA(isA<InsufficientPermissionException>()),
      );
    });

    test('observer cannot cancel (denied)', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.observer),
      );
      final incident = _draft(id: 'role-5');
      await _insertIncident(db, incident);

      expect(
        () => sm.transition(
          incident: incident,
          target: IncidentState.cancelled,
          actorId: 'uid-observer',
        ),
        throwsA(isA<InsufficientPermissionException>()),
      );
    });
  });

  // =========================================================================
  // 6) Append-only invariant
  // =========================================================================

  group('append-only invariant', () {
    test('transition records accumulate in order', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.admin),
      );
      final incident = _draft(id: 'append-1');
      await _insertIncident(db, incident);

      // draft -> open
      await sm.transition(
        incident: incident,
        target: IncidentState.open,
        actorId: 'uid-a',
      );
      final open = incident.copyWith(state: IncidentState.open);

      // open -> assigned
      await sm.transition(
        incident: open,
        target: IncidentState.assigned,
        actorId: 'uid-a',
        assigneeId: 'uid-b',
      );

      // Check transition count.
      final rows = await db.database.query(
        'incident_transitions',
        where: 'incidentId = ?',
        whereArgs: ['append-1'],
        orderBy: 'timestamp ASC, id ASC',
      );

      expect(rows.length, 2);
      expect(rows[0]['fromState'], 'draft');
      expect(rows[0]['toState'], 'open');
      expect(rows[1]['fromState'], 'open');
      expect(rows[1]['toState'], 'assigned');
    });

    test('transition IDs are unique UUIDs', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.admin),
      );
      final incident = _draft(id: 'append-2');
      await _insertIncident(db, incident);

      final t1 = await sm.transition(
        incident: incident,
        target: IncidentState.open,
        actorId: 'uid-a',
      );
      final open = incident.copyWith(state: IncidentState.open);

      final t2 = await sm.transition(
        incident: open,
        target: IncidentState.escalated,
        actorId: 'uid-a',
      );

      expect(t1.id, isNot(equals(t2.id)));
      expect(t1.id.length, 36); // UUID v4 format
      expect(t2.id.length, 36);
    });

    test(
      'same-timestamp transitions ordered by transitionId tie-break',
      () async {
        // Manually insert two transitions with identical timestamps but
        // different UUIDs. rebuildProjection must return the state from
        // the transition whose id sorts lexicographically last.
        final incident = _draft(
          id: 'tiebreak-1',
        ).copyWith(state: IncidentState.open);
        await _insertIncident(db, incident);

        final sameEpoch = DateTime.now().millisecondsSinceEpoch;

        // Insert two transitions with the same timestamp.
        // UUID "aaa..." sorts before "zzz...", so the second row wins.
        await db.database.insert('incident_transitions', {
          'id': 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',
          'incidentId': 'tiebreak-1',
          'fromState': 'draft',
          'toState': 'open',
          'actorId': 'uid-a',
          'note': null,
          'timestamp': sameEpoch,
        });

        await db.database.insert('incident_transitions', {
          'id': 'zzzzzzzz-zzzz-4zzz-zzzz-zzzzzzzzzzzz',
          'incidentId': 'tiebreak-1',
          'fromState': 'open',
          'toState': 'escalated',
          'actorId': 'uid-a',
          'note': null,
          'timestamp': sameEpoch,
        });

        final sm = IncidentStateMachine(
          db: db,
          permissions: _service(Role.admin),
        );

        // rebuildProjection replays ORDER BY timestamp ASC, id ASC
        // so "aaa..." transition is first, "zzz..." is second → escalated.
        final result = await sm.rebuildProjection('tiebreak-1');
        expect(result, IncidentState.escalated);
      },
    );
  });

  // =========================================================================
  // 7) Misc edge cases
  // =========================================================================

  group('edge cases', () {
    test('assigneeId required for assigned target', () async {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.admin),
      );
      final incident = _draft(id: 'edge-1').copyWith(state: IncidentState.open);
      await _insertIncident(db, incident);

      expect(
        () => sm.transition(
          incident: incident,
          target: IncidentState.assigned,
          actorId: 'uid-admin',
          // assigneeId intentionally omitted
        ),
        throwsA(isA<InvalidTransitionException>()),
      );
    });

    test('canTransition returns correct booleans', () {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.admin),
      );

      expect(sm.canTransition(IncidentState.draft, IncidentState.open), true);
      expect(
        sm.canTransition(IncidentState.draft, IncidentState.assigned),
        false,
      );
      expect(sm.canTransition(IncidentState.closed, IncidentState.open), false);
    });

    test('validTargets returns correct set', () {
      final sm = IncidentStateMachine(
        db: db,
        permissions: _service(Role.admin),
      );

      expect(sm.validTargets(IncidentState.open), {
        IncidentState.assigned,
        IncidentState.escalated,
        IncidentState.resolved,
        IncidentState.cancelled,
      });
      expect(sm.validTargets(IncidentState.closed), <IncidentState>{});
    });
  });
}
