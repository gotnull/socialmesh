// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/incidents/models/incident.dart';
import 'package:socialmesh/features/incidents/models/incident_transition.dart';
import 'package:socialmesh/features/incidents/services/incident_conflict_resolver.dart';
import 'package:socialmesh/features/incidents/services/incident_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

IncidentTransition _transition({
  required String id,
  String incidentId = 'inc-1',
  IncidentState fromState = IncidentState.open,
  IncidentState toState = IncidentState.resolved,
  String actorId = 'uid-a',
  String? actorRole = 'operator',
  int timestampMs = 1000,
}) {
  return IncidentTransition(
    id: id,
    incidentId: incidentId,
    fromState: fromState,
    toState: toState,
    actorId: actorId,
    actorRole: actorRole,
    timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
  );
}

Incident _incident({
  String id = 'inc-1',
  IncidentState state = IncidentState.open,
}) {
  return Incident(
    id: id,
    orgId: 'org-1',
    title: 'Test incident',
    state: state,
    priority: IncidentPriority.immediate,
    classification: IncidentClassification.operational,
    ownerId: 'uid-owner',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

Future<void> insertIncident(IncidentDatabase db, Incident incident) async {
  await db.database.insert('incidents', incident.toMap());
}

Future<String> readState(IncidentDatabase db, String incidentId) async {
  final rows = await db.database.query(
    'incidents',
    columns: ['state'],
    where: 'id = ?',
    whereArgs: [incidentId],
  );
  return rows.first['state'] as String;
}

Future<List<String>> supersededIds(
  IncidentDatabase db,
  String incidentId,
) async {
  final rows = await db.database.query(
    'incident_transitions',
    columns: ['id'],
    where: 'incidentId = ? AND supersededBy IS NOT NULL',
    whereArgs: [incidentId],
  );
  return rows.map((r) => r['id'] as String).toList();
}

Future<int> transitionCount(IncidentDatabase db, String incidentId) async {
  final rows = await db.database.query(
    'incident_transitions',
    where: 'incidentId = ?',
    whereArgs: [incidentId],
  );
  return rows.length;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const resolver = IncidentConflictResolver();

  // =========================================================================
  // 1) Comparator rank mappings
  // =========================================================================

  group('transitionTypeRank', () {
    test('escalated has highest rank (5)', () {
      expect(
        IncidentConflictResolver.transitionTypeRank(IncidentState.escalated),
        5,
      );
    });

    test('cancelled = 4, assigned = 3, resolved = 2, open = 1', () {
      expect(
        IncidentConflictResolver.transitionTypeRank(IncidentState.cancelled),
        4,
      );
      expect(
        IncidentConflictResolver.transitionTypeRank(IncidentState.assigned),
        3,
      );
      expect(
        IncidentConflictResolver.transitionTypeRank(IncidentState.resolved),
        2,
      );
      expect(
        IncidentConflictResolver.transitionTypeRank(IncidentState.open),
        1,
      );
    });
  });

  group('actorRoleRank', () {
    test('admin=4, supervisor=3, operator=2, observer=1, null=0', () {
      expect(IncidentConflictResolver.actorRoleRank('admin'), 4);
      expect(IncidentConflictResolver.actorRoleRank('supervisor'), 3);
      expect(IncidentConflictResolver.actorRoleRank('operator'), 2);
      expect(IncidentConflictResolver.actorRoleRank('observer'), 1);
      expect(IncidentConflictResolver.actorRoleRank(null), 0);
    });
  });

  // =========================================================================
  // 2) Unit tests for each tie-break level
  // =========================================================================

  group('compare: priorityRank decides', () {
    test('escalate wins over resolve (higher transition rank)', () {
      final escalate = _transition(
        id: 'tx-esc',
        toState: IncidentState.escalated,
        timestampMs: 998,
      );
      final resolve = _transition(
        id: 'tx-res',
        toState: IncidentState.resolved,
        timestampMs: 1000,
      );

      // escalate should win (sort first)
      final result = IncidentConflictResolver.compare(escalate, resolve);
      expect(
        result,
        lessThan(0),
        reason: 'escalate should sort before resolve',
      );
    });

    test('cancel wins over assign', () {
      final cancel = _transition(
        id: 'tx-can',
        toState: IncidentState.cancelled,
        timestampMs: 1001,
      );
      final assign = _transition(
        id: 'tx-asg',
        toState: IncidentState.assigned,
        timestampMs: 1000,
      );

      final result = IncidentConflictResolver.compare(cancel, assign);
      expect(result, lessThan(0));
    });
  });

  group('compare: timestamp decides when priorityRank ties', () {
    test('earlier timestamp wins when same transition type', () {
      final early = _transition(
        id: 'tx-1',
        toState: IncidentState.resolved,
        timestampMs: 998,
      );
      final late = _transition(
        id: 'tx-2',
        toState: IncidentState.resolved,
        timestampMs: 1002,
      );

      final result = IncidentConflictResolver.compare(early, late);
      expect(result, lessThan(0), reason: 'earlier timestamp should win');
    });
  });

  group('compare: actorRoleRank decides when priorityRank + timestamp tie', () {
    test('admin wins over supervisor', () {
      final admin = _transition(
        id: 'tx-1',
        toState: IncidentState.resolved,
        actorRole: 'admin',
        timestampMs: 1000,
      );
      final supervisor = _transition(
        id: 'tx-2',
        toState: IncidentState.resolved,
        actorRole: 'supervisor',
        timestampMs: 1000,
      );

      final result = IncidentConflictResolver.compare(admin, supervisor);
      expect(result, lessThan(0), reason: 'admin should win');
    });
  });

  group('compare: actorId decides when previous keys tie', () {
    test('lexicographically earlier actorId wins', () {
      final a = _transition(
        id: 'tx-1',
        toState: IncidentState.resolved,
        actorId: 'alice',
        actorRole: 'operator',
        timestampMs: 1000,
      );
      final b = _transition(
        id: 'tx-2',
        toState: IncidentState.resolved,
        actorId: 'bob',
        actorRole: 'operator',
        timestampMs: 1000,
      );

      final result = IncidentConflictResolver.compare(a, b);
      expect(result, lessThan(0), reason: 'alice < bob lexicographically');
    });
  });

  group('compare: transitionId decides as final tiebreaker', () {
    test('lexicographically earlier transitionId wins', () {
      final a = _transition(
        id: 'aaaa-0000',
        toState: IncidentState.resolved,
        actorId: 'same-actor',
        actorRole: 'operator',
        timestampMs: 1000,
      );
      final b = _transition(
        id: 'zzzz-9999',
        toState: IncidentState.resolved,
        actorId: 'same-actor',
        actorRole: 'operator',
        timestampMs: 1000,
      );

      final result = IncidentConflictResolver.compare(a, b);
      expect(result, lessThan(0), reason: 'aaaa < zzzz');
    });
  });

  group('compare: outside 5-second window', () {
    test('earlier timestamp wins regardless of priority rank', () {
      // escalate has higher rank but is 10 seconds later
      final escalateLate = _transition(
        id: 'tx-esc',
        toState: IncidentState.escalated,
        timestampMs: 11000,
      );
      final resolveEarly = _transition(
        id: 'tx-res',
        toState: IncidentState.resolved,
        timestampMs: 1000,
      );

      final result = IncidentConflictResolver.compare(
        resolveEarly,
        escalateLate,
      );
      expect(
        result,
        lessThan(0),
        reason: 'earlier timestamp should win outside 5s window',
      );
    });
  });

  group('compareFullChain: always uses priorityRank first', () {
    test('higher rank wins even when 10s apart', () {
      final escalate = _transition(
        id: 'tx-esc',
        toState: IncidentState.escalated,
        timestampMs: 11000,
      );
      final resolve = _transition(
        id: 'tx-res',
        toState: IncidentState.resolved,
        timestampMs: 1000,
      );

      final result = IncidentConflictResolver.compareFullChain(
        escalate,
        resolve,
      );
      expect(
        result,
        lessThan(0),
        reason: 'escalated wins by rank regardless of timestamp',
      );
    });
  });

  group('compareByTimestamp: always uses timestamp first', () {
    test('earlier timestamp wins even when lower rank', () {
      final resolveEarly = _transition(
        id: 'tx-res',
        toState: IncidentState.resolved,
        timestampMs: 1000,
      );
      final escalateLate = _transition(
        id: 'tx-esc',
        toState: IncidentState.escalated,
        timestampMs: 2000,
      );

      final result = IncidentConflictResolver.compareByTimestamp(
        resolveEarly,
        escalateLate,
      );
      expect(
        result,
        lessThan(0),
        reason: 'earlier timestamp wins regardless of rank',
      );
    });

    test('same timestamp falls through to priorityRank', () {
      final escalate = _transition(
        id: 'tx-esc',
        toState: IncidentState.escalated,
        timestampMs: 1000,
      );
      final resolve = _transition(
        id: 'tx-res',
        toState: IncidentState.resolved,
        timestampMs: 1000,
      );

      final result = IncidentConflictResolver.compareByTimestamp(
        escalate,
        resolve,
      );
      expect(result, lessThan(0), reason: 'same ts -> priorityRank tiebreaker');
    });
  });

  // =========================================================================
  // 3) resolveConflicts unit tests
  // =========================================================================

  group('resolveConflicts', () {
    test('no conflict when only one transition per fromState', () {
      final transitions = [
        _transition(
          id: 'tx-1',
          fromState: IncidentState.draft,
          toState: IncidentState.open,
          timestampMs: 100,
        ),
        _transition(
          id: 'tx-2',
          fromState: IncidentState.open,
          toState: IncidentState.resolved,
          timestampMs: 200,
        ),
      ];

      final result = resolver.resolveConflicts(
        incidentId: 'inc-1',
        transitions: transitions,
      );

      expect(result.supersededIds, isEmpty);
      expect(result.winningTransitions, hasLength(2));
    });

    test('escalate wins over resolve (same fromState, same window)', () {
      // Anchor: draft→open so that open is reachable.
      final anchor = _transition(
        id: 'tx-anchor',
        fromState: IncidentState.draft,
        toState: IncidentState.open,
        timestampMs: 500,
      );
      final resolve = _transition(
        id: 'tx-resolve',
        fromState: IncidentState.open,
        toState: IncidentState.resolved,
        timestampMs: 1000,
        actorId: 'uid-a',
      );
      final escalate = _transition(
        id: 'tx-escalate',
        fromState: IncidentState.open,
        toState: IncidentState.escalated,
        timestampMs: 998,
        actorId: 'uid-b',
      );

      final result = resolver.resolveConflicts(
        incidentId: 'inc-1',
        transitions: [anchor, resolve, escalate],
      );

      expect(result.supersededIds, {'tx-resolve'});
      expect(result.winningTransitions, hasLength(2));
      expect(result.winningTransitions.last.id, 'tx-escalate');
      expect(result.debugResolutionPath, contains('priorityRank'));
    });

    test('orphan transitions are superseded', () {
      // Chain A: draft→open, open→assigned
      // Chain B: draft→cancelled (wins over draft→open)
      // If B wins at draft, open→assigned becomes orphaned (open unreachable).
      final draftOpen = _transition(
        id: 'tx-open',
        fromState: IncidentState.draft,
        toState: IncidentState.open,
        timestampMs: 1000,
      );
      final draftCancel = _transition(
        id: 'tx-cancel',
        fromState: IncidentState.draft,
        toState: IncidentState.cancelled,
        timestampMs: 1001,
      );
      final openAssigned = _transition(
        id: 'tx-assign',
        fromState: IncidentState.open,
        toState: IncidentState.assigned,
        timestampMs: 1100,
      );

      final result = resolver.resolveConflicts(
        incidentId: 'inc-1',
        transitions: [draftOpen, draftCancel, openAssigned],
      );

      // draftCancel wins (cancel=4 > open=1)
      // draftOpen is superseded (group conflict)
      // openAssigned is orphaned (open is unreachable)
      expect(result.supersededIds, containsAll(['tx-open', 'tx-assign']));
      expect(result.winningTransitions.single.id, 'tx-cancel');
    });

    test('empty transitions returns empty resolution', () {
      final result = resolver.resolveConflicts(
        incidentId: 'inc-1',
        transitions: [],
      );

      expect(result.winningTransitions, isEmpty);
      expect(result.supersededIds, isEmpty);
    });

    test('group-level window: 3 transitions straddling boundary converge', () {
      // This is the intransitivity edge case. Pairwise window checks
      // produce a cycle: A>B (within 5s, rank), B>C (outside 5s, ts),
      // C>A (within 5s, rank). Group-level window (maxTs - minTs > 5000)
      // falls back to timestamp ordering, making B the deterministic
      // winner since it has the earliest timestamp.
      final anchor = _transition(
        id: 'tx-anchor',
        fromState: IncidentState.draft,
        toState: IncidentState.open,
        timestampMs: 0,
      );
      final b = _transition(
        id: 'tx-B',
        fromState: IncidentState.open,
        toState: IncidentState.resolved, // rank=2
        timestampMs: 0, // Same ts as anchor — chain walk must handle this.
      );
      final a = _transition(
        id: 'tx-A',
        fromState: IncidentState.open,
        toState: IncidentState.escalated, // rank=5
        timestampMs: 4999,
      );
      final c = _transition(
        id: 'tx-C',
        fromState: IncidentState.open,
        toState: IncidentState.cancelled, // rank=4
        timestampMs: 5001,
      );

      final result = resolver.resolveConflicts(
        incidentId: 'inc-1',
        transitions: [anchor, b, a, c],
      );

      // Group span = 5001 - 0 = 5001 > 5000 → timestamp-first ordering.
      // B has earliest ts (0), so B wins. Chain walk: anchor → B.
      expect(result.winningTransitions, hasLength(2));
      expect(result.winningTransitions[0].id, 'tx-anchor');
      expect(
        result.winningTransitions[1].id,
        'tx-B',
        reason: 'B wins by timestamp (group outside window)',
      );
      expect(result.supersededIds, containsAll(['tx-A', 'tx-C']));
    });

    test('group within window uses full chain (priorityRank first)', () {
      final anchor = _transition(
        id: 'tx-anchor',
        fromState: IncidentState.draft,
        toState: IncidentState.open,
        timestampMs: 0,
      );
      // 3 transitions within 5 seconds of each other.
      final b = _transition(
        id: 'tx-B',
        fromState: IncidentState.open,
        toState: IncidentState.resolved, // rank=2
        timestampMs: 1000,
      );
      final a = _transition(
        id: 'tx-A',
        fromState: IncidentState.open,
        toState: IncidentState.escalated, // rank=5
        timestampMs: 4999,
      );
      final c = _transition(
        id: 'tx-C',
        fromState: IncidentState.open,
        toState: IncidentState.cancelled, // rank=4
        timestampMs: 5000,
      );

      final result = resolver.resolveConflicts(
        incidentId: 'inc-1',
        transitions: [anchor, b, a, c],
      );

      // Group span = 5000 - 1000 = 4000 ≤ 5000 → full chain.
      // escalated (rank=5) wins by priorityRank.
      expect(
        result.winningTransitions.last.id,
        'tx-A',
        reason: 'A wins by priorityRank (group within window)',
      );
      expect(result.supersededIds, containsAll(['tx-B', 'tx-C']));
    });

    test('replayed remote packet produces stable idempotent result', () {
      final anchor = _transition(
        id: 'tx-anchor',
        fromState: IncidentState.draft,
        toState: IncidentState.open,
        timestampMs: 100,
      );
      final t1 = _transition(
        id: 'tx-1',
        fromState: IncidentState.open,
        toState: IncidentState.resolved,
        timestampMs: 1000,
      );
      final t2 = _transition(
        id: 'tx-2',
        fromState: IncidentState.open,
        toState: IncidentState.escalated,
        timestampMs: 1001,
      );

      // First resolution.
      final result1 = resolver.resolveConflicts(
        incidentId: 'inc-1',
        transitions: [anchor, t1, t2],
      );

      // Second resolution with same inputs (simulating replay).
      final result2 = resolver.resolveConflicts(
        incidentId: 'inc-1',
        transitions: [anchor, t2, t1], // different input order
      );

      expect(
        result1.winningTransitions.map((t) => t.id).toList(),
        result2.winningTransitions.map((t) => t.id).toList(),
        reason: 'Same winner regardless of input order',
      );
      expect(
        result1.supersededIds,
        result2.supersededIds,
        reason: 'Same superseded set regardless of input order',
      );
    });

    test('cascading supersession: C supersedes A, B was superseded by A', () {
      // First sync: A beats B at fromState=open.
      // Second sync: C arrives and beats A at fromState=open.
      // B's supersededBy still points to A but both B and A are excluded
      // from projection (supersededBy IS NOT NULL).
      final anchor = _transition(
        id: 'tx-anchor',
        fromState: IncidentState.draft,
        toState: IncidentState.open,
        timestampMs: 100,
      );
      final b = _transition(
        id: 'tx-B',
        fromState: IncidentState.open,
        toState: IncidentState.resolved, // rank=2
        timestampMs: 1000,
      );
      final a = _transition(
        id: 'tx-A',
        fromState: IncidentState.open,
        toState: IncidentState.cancelled, // rank=4
        timestampMs: 1001,
      );

      // First resolution: A beats B.
      final r1 = resolver.resolveConflicts(
        incidentId: 'inc-1',
        transitions: [anchor, b, a],
      );
      expect(r1.supersededIds, {'tx-B'});
      expect(r1.winningTransitions.last.id, 'tx-A');

      // Now C arrives (rank=5, beats A).
      final c = _transition(
        id: 'tx-C',
        fromState: IncidentState.open,
        toState: IncidentState.escalated, // rank=5
        timestampMs: 1002,
      );

      // Second resolution with all three. B was already superseded in
      // the DB so it wouldn't appear in the query (supersededBy IS NULL),
      // but even if it did, the resolver handles it correctly.
      final r2 = resolver.resolveConflicts(
        incidentId: 'inc-1',
        transitions: [anchor, a, c],
      );
      expect(r2.supersededIds, {'tx-A'});
      expect(r2.winningTransitions.last.id, 'tx-C');

      // Full resolution with all three (as if B wasn't yet superseded).
      final r3 = resolver.resolveConflicts(
        incidentId: 'inc-1',
        transitions: [anchor, b, a, c],
      );
      expect(r3.supersededIds, containsAll(['tx-B', 'tx-A']));
      expect(r3.winningTransitions.last.id, 'tx-C');
    });
  });

  // =========================================================================
  // 4) debugWinReason
  // =========================================================================

  group('debugWinReason', () {
    test('reports priorityRank when it decides', () {
      final winner = _transition(
        id: 'tx-1',
        toState: IncidentState.escalated,
        timestampMs: 1000,
      );
      final loser = _transition(
        id: 'tx-2',
        toState: IncidentState.resolved,
        timestampMs: 1000,
      );

      final reason = IncidentConflictResolver.debugWinReason(winner, loser);
      expect(reason, contains('priorityRank'));
      expect(reason, contains('escalated'));
    });

    test('reports actorRoleRank when priorityRank and timestamp tie', () {
      final winner = _transition(
        id: 'tx-1',
        toState: IncidentState.resolved,
        actorRole: 'admin',
        timestampMs: 1000,
      );
      final loser = _transition(
        id: 'tx-2',
        toState: IncidentState.resolved,
        actorRole: 'supervisor',
        timestampMs: 1000,
      );

      final reason = IncidentConflictResolver.debugWinReason(winner, loser);
      expect(reason, contains('actorRoleRank'));
      expect(reason, contains('admin'));
    });

    test('reports transitionId when all previous tie', () {
      final winner = _transition(
        id: 'aaaa',
        toState: IncidentState.resolved,
        actorId: 'same',
        actorRole: 'operator',
        timestampMs: 1000,
      );
      final loser = _transition(
        id: 'zzzz',
        toState: IncidentState.resolved,
        actorId: 'same',
        actorRole: 'operator',
        timestampMs: 1000,
      );

      final reason = IncidentConflictResolver.debugWinReason(winner, loser);
      expect(reason, contains('transitionId'));
    });
  });

  // =========================================================================
  // 5) Database integration: applyRemoteTransitions
  // =========================================================================

  group('applyRemoteTransitions', () {
    late IncidentDatabase db;

    setUp(() async {
      db = IncidentDatabase(dbPathOverride: inMemoryDatabasePath);
      await db.open();
    });

    tearDown(() async {
      await db.close();
    });

    test('inserts remote transitions and resolves conflict', () async {
      final incident = _incident(id: 'inc-db-1', state: IncidentState.open);
      await insertIncident(db, incident);

      // Anchor: draft→open (establishes reachability).
      final anchor = _transition(
        id: 'tx-anchor',
        incidentId: 'inc-db-1',
        fromState: IncidentState.draft,
        toState: IncidentState.open,
        actorId: 'uid-creator',
        actorRole: 'operator',
        timestampMs: 500,
      );
      await db.database.insert('incident_transitions', anchor.toMap());

      // Local transition: open→resolved at ts=1000
      final local = _transition(
        id: 'tx-local',
        incidentId: 'inc-db-1',
        fromState: IncidentState.open,
        toState: IncidentState.resolved,
        actorId: 'uid-a',
        actorRole: 'supervisor',
        timestampMs: 1000,
      );
      await db.database.insert('incident_transitions', local.toMap());

      // Remote transition: open→escalated at ts=998
      final remote = _transition(
        id: 'tx-remote',
        incidentId: 'inc-db-1',
        fromState: IncidentState.open,
        toState: IncidentState.escalated,
        actorId: 'uid-b',
        actorRole: 'operator',
        timestampMs: 998,
      );

      await db.applyRemoteTransitions(remoteTransitions: [remote]);

      // escalated wins (higher priority rank)
      expect(await readState(db, 'inc-db-1'), 'escalated');

      // All transitions exist (append-only): anchor + local + remote
      expect(await transitionCount(db, 'inc-db-1'), 3);

      // Local is superseded
      final superseded = await supersededIds(db, 'inc-db-1');
      expect(superseded, contains('tx-local'));
    });

    test('duplicate remote transition is ignored', () async {
      final incident = _incident(id: 'inc-db-2');
      await insertIncident(db, incident);

      final remote = _transition(
        id: 'tx-dup',
        incidentId: 'inc-db-2',
        fromState: IncidentState.open,
        toState: IncidentState.escalated,
        timestampMs: 1000,
      );

      // Insert twice — second should be ignored.
      await db.applyRemoteTransitions(remoteTransitions: [remote]);
      await db.applyRemoteTransitions(remoteTransitions: [remote]);

      expect(await transitionCount(db, 'inc-db-2'), 1);
    });

    test('no conflict when non-overlapping fromStates', () async {
      final incident = _incident(id: 'inc-db-3', state: IncidentState.draft);
      await insertIncident(db, incident);

      // Local: draft→open
      final local = _transition(
        id: 'tx-open',
        incidentId: 'inc-db-3',
        fromState: IncidentState.draft,
        toState: IncidentState.open,
        timestampMs: 100,
      );
      await db.database.insert('incident_transitions', local.toMap());

      // Remote: open→assigned (sequential, not conflicting)
      final remote = _transition(
        id: 'tx-assign',
        incidentId: 'inc-db-3',
        fromState: IncidentState.open,
        toState: IncidentState.assigned,
        timestampMs: 200,
      );

      await db.applyRemoteTransitions(remoteTransitions: [remote]);

      expect(await readState(db, 'inc-db-3'), 'assigned');
      expect(await transitionCount(db, 'inc-db-3'), 2);
      expect(await supersededIds(db, 'inc-db-3'), isEmpty);
    });
  });

  // =========================================================================
  // 6) Integration convergence test
  // =========================================================================

  group('convergence', () {
    test(
      'two devices applying conflicting transitions converge to same state',
      () async {
        // Setup: two independent in-memory databases (Device A and Device B).
        final dbA = IncidentDatabase(dbPathOverride: inMemoryDatabasePath);
        final dbB = IncidentDatabase(dbPathOverride: inMemoryDatabasePath);
        await dbA.open();
        await dbB.open();

        try {
          // Both devices have the same incident in 'open' state.
          final incidentA = _incident(id: 'conv-1', state: IncidentState.open);
          final incidentB = _incident(id: 'conv-1', state: IncidentState.open);
          await insertIncident(dbA, incidentA);
          await insertIncident(dbB, incidentB);

          // Both devices share prefix: draft→open.
          final draftToOpen = _transition(
            id: 'tx-shared-open',
            incidentId: 'conv-1',
            fromState: IncidentState.draft,
            toState: IncidentState.open,
            actorId: 'uid-creator',
            actorRole: 'operator',
            timestampMs: 500,
          );
          await dbA.database.insert(
            'incident_transitions',
            draftToOpen.toMap(),
          );
          await dbB.database.insert(
            'incident_transitions',
            draftToOpen.toMap(),
          );

          // Device A: open→resolved at ts=1000
          final transitionA = _transition(
            id: 'tx-device-a',
            incidentId: 'conv-1',
            fromState: IncidentState.open,
            toState: IncidentState.resolved,
            actorId: 'uid-a',
            actorRole: 'supervisor',
            timestampMs: 1000,
          );
          // Device B: open→escalated at ts=998
          final transitionB = _transition(
            id: 'tx-device-b',
            incidentId: 'conv-1',
            fromState: IncidentState.open,
            toState: IncidentState.escalated,
            actorId: 'uid-b',
            actorRole: 'operator',
            timestampMs: 998,
          );

          // Each device has its own local transition.
          await dbA.database.insert(
            'incident_transitions',
            transitionA.toMap(),
          );
          await dbB.database.insert(
            'incident_transitions',
            transitionB.toMap(),
          );

          // Sync: Device A receives B's transition, Device B receives A's.
          await dbA.applyRemoteTransitions(remoteTransitions: [transitionB]);
          await dbB.applyRemoteTransitions(remoteTransitions: [transitionA]);

          // Both databases must converge.
          final stateA = await readState(dbA, 'conv-1');
          final stateB = await readState(dbB, 'conv-1');

          expect(stateA, stateB, reason: 'Both devices must converge');
          expect(
            stateA,
            'escalated',
            reason: 'escalate wins (higher priority rank)',
          );

          // Both transitions still exist (append-only).
          expect(await transitionCount(dbA, 'conv-1'), 3);
          expect(await transitionCount(dbB, 'conv-1'), 3);

          // The superseded set is identical.
          final supersededA = await supersededIds(dbA, 'conv-1');
          final supersededB = await supersededIds(dbB, 'conv-1');
          expect(
            supersededA..sort(),
            supersededB..sort(),
            reason: 'Same superseded IDs on both devices',
          );
          expect(supersededA, contains('tx-device-a'));
        } finally {
          await dbA.close();
          await dbB.close();
        }
      },
    );

    test(
      'timestamp tie with different actor roles: higher role wins',
      () async {
        final dbA = IncidentDatabase(dbPathOverride: inMemoryDatabasePath);
        final dbB = IncidentDatabase(dbPathOverride: inMemoryDatabasePath);
        await dbA.open();
        await dbB.open();

        try {
          final incidentA = _incident(id: 'conv-2', state: IncidentState.open);
          final incidentB = _incident(id: 'conv-2', state: IncidentState.open);
          await insertIncident(dbA, incidentA);
          await insertIncident(dbB, incidentB);

          // Anchor: draft→open on both devices.
          final anchor = _transition(
            id: 'tx-anchor-conv2',
            incidentId: 'conv-2',
            fromState: IncidentState.draft,
            toState: IncidentState.open,
            actorId: 'uid-creator',
            actorRole: 'operator',
            timestampMs: 500,
          );
          await dbA.database.insert('incident_transitions', anchor.toMap());
          await dbB.database.insert('incident_transitions', anchor.toMap());

          // Both devices: same transition type (assign), same timestamp.
          // Device A: actor is admin.
          final transitionA = _transition(
            id: 'tx-admin',
            incidentId: 'conv-2',
            fromState: IncidentState.open,
            toState: IncidentState.assigned,
            actorId: 'uid-admin',
            actorRole: 'admin',
            timestampMs: 1000,
          );
          // Device B: actor is supervisor.
          final transitionB = _transition(
            id: 'tx-supervisor',
            incidentId: 'conv-2',
            fromState: IncidentState.open,
            toState: IncidentState.assigned,
            actorId: 'uid-supervisor',
            actorRole: 'supervisor',
            timestampMs: 1000,
          );

          await dbA.database.insert(
            'incident_transitions',
            transitionA.toMap(),
          );
          await dbB.database.insert(
            'incident_transitions',
            transitionB.toMap(),
          );

          await dbA.applyRemoteTransitions(remoteTransitions: [transitionB]);
          await dbB.applyRemoteTransitions(remoteTransitions: [transitionA]);

          final stateA = await readState(dbA, 'conv-2');
          final stateB = await readState(dbB, 'conv-2');

          expect(stateA, stateB);
          expect(stateA, 'assigned');

          // Admin's transition wins — supervisor's is superseded.
          final supersededA = await supersededIds(dbA, 'conv-2');
          final supersededB = await supersededIds(dbB, 'conv-2');
          expect(supersededA, ['tx-supervisor']);
          expect(supersededB, ['tx-supervisor']);
        } finally {
          await dbA.close();
          await dbB.close();
        }
      },
    );
  });

  // =========================================================================
  // 7) Replication step: both transitions remain after resolution
  // =========================================================================

  group('append-only invariant in conflict resolution', () {
    late IncidentDatabase db;

    setUp(() async {
      db = IncidentDatabase(dbPathOverride: inMemoryDatabasePath);
      await db.open();
    });

    tearDown(() async {
      await db.close();
    });

    test('losing transition is retained with supersededBy set', () async {
      final incident = _incident(id: 'retain-1');
      await insertIncident(db, incident);

      // Anchor: draft→open.
      final anchor = _transition(
        id: 'tx-anchor-retain',
        incidentId: 'retain-1',
        fromState: IncidentState.draft,
        toState: IncidentState.open,
        actorId: 'uid-creator',
        actorRole: 'operator',
        timestampMs: 500,
      );
      await db.database.insert('incident_transitions', anchor.toMap());

      final local = _transition(
        id: 'tx-loser',
        incidentId: 'retain-1',
        fromState: IncidentState.open,
        toState: IncidentState.resolved,
        timestampMs: 1000,
      );
      await db.database.insert('incident_transitions', local.toMap());

      final remote = _transition(
        id: 'tx-winner',
        incidentId: 'retain-1',
        fromState: IncidentState.open,
        toState: IncidentState.escalated,
        timestampMs: 998,
      );

      await db.applyRemoteTransitions(remoteTransitions: [remote]);

      // All three rows exist (anchor + loser + winner).
      final rows = await db.database.query(
        'incident_transitions',
        where: 'incidentId = ?',
        whereArgs: ['retain-1'],
      );
      expect(rows, hasLength(3));

      // Loser has supersededBy set.
      final loserRow = rows.firstWhere((r) => r['id'] == 'tx-loser');
      expect(loserRow['supersededBy'], 'tx-winner');

      // Winner has supersededBy null.
      final winnerRow = rows.firstWhere((r) => r['id'] == 'tx-winner');
      expect(winnerRow['supersededBy'], isNull);
    });
  });
}
