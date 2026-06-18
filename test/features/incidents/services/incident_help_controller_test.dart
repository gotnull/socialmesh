// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/features/incidents/models/incident_mode_models.dart';
import 'package:socialmesh/features/incidents/services/incident_help_controller.dart';
import 'package:socialmesh/features/incidents/services/incident_mode_store.dart';
import 'package:socialmesh/features/incidents/services/mesh_incident_database.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';
import 'package:socialmesh/services/protocol/sip/spp_incident_mode_codec.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _seq = 0;
final _pid = pid;
String _dbPath() =>
    p.join(Directory.systemTemp.path, 'incident_ctrl_${_pid}_${_seq++}.db');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => databaseFactory = databaseFactoryFfi);

  const localNode = 555;
  final clock = DateTime.utc(2026, 6, 17, 10);

  // Peers: A trusted+capable, B capable-but-untrusted, C trusted-but-noncapable.
  const peerA = 1, peerB = 2, peerC = 3;
  final peers = <IncidentPeer>[
    (nodeId: peerA, features: SipFeatureBits.incidentHelpV1),
    (nodeId: peerB, features: SipFeatureBits.incidentHelpV1),
    (nodeId: peerC, features: 0),
  ];
  const trusted = {peerA, peerC};

  Future<
    ({
      MeshIncidentDatabaseImpl db,
      IncidentModeStore store,
      List<(Uint8List, List<int>)> sends,
      IncidentHelpController controller,
    })
  >
  build({
    List<IncidentPeer>? discovered,
    Set<int>? trustedSet,
    bool failSend = false,
    int Function()? idGenerator,
  }) async {
    final db = MeshIncidentDatabaseImpl(dbPathOverride: _dbPath());
    await db.open();
    final store = IncidentModeStore(db: db);
    final sends = <(Uint8List, List<int>)>[];
    // Deterministic, distinct ids by default so existing tests are stable.
    var nextId = 0x1000;
    final controller = IncidentHelpController(
      store: store,
      ensureStoreReady: db.open,
      localNodeId: () => localNode,
      discoveredPeers: () => discovered ?? peers,
      isTrusted: (n) => (trustedSet ?? trusted).contains(n),
      sendHelpEvent: (payload, recipients) async {
        if (failSend) throw StateError('send boom');
        sends.add((payload, recipients));
        return true;
      },
      clock: () => clock,
      idGenerator: idGenerator ?? (() => nextId++),
    );
    return (db: db, store: store, sends: sends, controller: controller);
  }

  group('eligibility', () {
    test('only trusted AND capable peers are eligible', () async {
      final h = await build();
      addTearDown(h.db.close);
      expect(h.controller.eligibleRecipients(), [peerA]);
    });
  });

  group('createHelpRequest', () {
    test('persists a local IncidentCreate', () async {
      final h = await build();
      addTearDown(h.db.close);
      final outcome = await h.controller.createHelpRequest();

      final proj = await h.store.loadIncidentProjection(outcome.incidentId);
      expect(proj, isNotNull);
      expect(proj!.helpState, IncidentLifecycleState.broadcasting);
      final events = await h.store.getTimeline(outcome.incidentId);
      expect(events, hasLength(1));
      expect(events.single.type, IncidentEventType.create);
      // Sender identity is the LOCAL node, not payload-derived.
      expect(events.single.senderNodeId, localNode);
    });

    test('sends only to trusted + capable peers', () async {
      final h = await build();
      addTearDown(h.db.close);
      final outcome = await h.controller.createHelpRequest();

      expect(outcome.recipients, [peerA]); // not B (untrusted), not C (no cap)
      expect(h.sends, hasLength(1));
      expect(h.sends.single.$2, [peerA]);
      // Payload is a real help create event on the wire.
      final decoded = SppIncidentModeCodec.decode(h.sends.single.$1, peerA);
      expect(decoded!.type, IncidentEventType.create);
      expect(decoded.workflowKind, IncidentWorkflowKind.helpRequest);
    });

    test(
      'with no eligible peers, persists locally and does not send',
      () async {
        final h = await build(discovered: const []);
        addTearDown(h.db.close);
        final outcome = await h.controller.createHelpRequest();

        expect(outcome.hadEligibleRecipients, isFalse);
        expect(h.sends, isEmpty);
        expect(
          await h.store.loadIncidentProjection(outcome.incidentId),
          isNotNull,
        );
      },
    );

    test('untrusted-only peers receive nothing', () async {
      final h = await build(trustedSet: const {}); // nobody trusted
      addTearDown(h.db.close);
      final outcome = await h.controller.createHelpRequest();
      expect(outcome.recipients, isEmpty);
      expect(h.sends, isEmpty);
    });

    test('non-capable-only peers receive nothing', () async {
      final h = await build(
        discovered: const [(nodeId: peerC, features: 0)],
        trustedSet: const {peerC},
      );
      addTearDown(h.db.close);
      final outcome = await h.controller.createHelpRequest();
      expect(outcome.recipients, isEmpty);
      expect(h.sends, isEmpty);
    });

    test('initial status is sent as a follow-up requester status', () async {
      final h = await build();
      addTearDown(h.db.close);
      final outcome = await h.controller.createHelpRequest(
        initialStatus: IncidentQuickUpdate.imInjured,
      );
      final proj = await h.store.loadIncidentProjection(outcome.incidentId);
      expect(proj!.lastRequesterStatus, IncidentQuickUpdate.imInjured);
    });
  });

  group('participant + status actions persist and send', () {
    test('RequesterStatus', () async {
      final h = await build();
      addTearDown(h.db.close);
      final c = await h.controller.createHelpRequest();
      final o = await h.controller.sendRequesterStatus(
        incidentId: c.incidentId,
        code: IncidentQuickUpdate.cantMove,
      );
      expect(o.recipients, [peerA]);
      final proj = await h.store.loadIncidentProjection(c.incidentId);
      expect(proj!.lastRequesterStatus, IncidentQuickUpdate.cantMove);
    });

    test('ResponderAccept', () async {
      final h = await build();
      addTearDown(h.db.close);
      final c = await h.controller.createHelpRequest();
      await h.controller.acceptHelpRequest(incidentId: c.incidentId);
      final proj = await h.store.loadIncidentProjection(c.incidentId);
      // Local node is the responder here.
      expect(proj!.helpState, IncidentLifecycleState.activeWithResponder);
      expect(h.sends.length, greaterThanOrEqualTo(2));
    });

    test('ResponderStatus', () async {
      final h = await build();
      addTearDown(h.db.close);
      final c = await h.controller.createHelpRequest();
      await h.controller.acceptHelpRequest(incidentId: c.incidentId);
      await h.controller.sendResponderStatus(
        incidentId: c.incidentId,
        code: IncidentQuickUpdate.onMyWay,
      );
      final proj = await h.store.loadIncidentProjection(c.incidentId);
      expect(proj!.helpState, IncidentLifecycleState.responderEnRoute);
    });

    test('ResponderLeave', () async {
      final h = await build();
      addTearDown(h.db.close);
      final c = await h.controller.createHelpRequest();
      await h.controller.acceptHelpRequest(incidentId: c.incidentId);
      await h.controller.leaveResponse(incidentId: c.incidentId);
      final proj = await h.store.loadIncidentProjection(c.incidentId);
      expect(proj!.responderCount, 0);
    });
  });

  group('terminal actions', () {
    test('resolveSafe projects resolvedSafe', () async {
      final h = await build();
      addTearDown(h.db.close);
      final c = await h.controller.createHelpRequest();
      await h.controller.resolveSafe(incidentId: c.incidentId);
      final proj = await h.store.loadIncidentProjection(c.incidentId);
      expect(proj!.helpState, IncidentLifecycleState.resolvedSafe);
    });

    test('cancelRequest projects cancelled (distinct from resolved)', () async {
      final h = await build();
      addTearDown(h.db.close);
      final c = await h.controller.createHelpRequest();
      await h.controller.cancelRequest(incidentId: c.incidentId);
      final proj = await h.store.loadIncidentProjection(c.incidentId);
      expect(proj!.helpState, IncidentLifecycleState.cancelled);
    });

    test('falseAlarm quick status does NOT terminate', () async {
      final h = await build();
      addTearDown(h.db.close);
      final c = await h.controller.createHelpRequest();
      await h.controller.sendRequesterStatus(
        incidentId: c.incidentId,
        code: IncidentQuickUpdate.falseAlarm,
      );
      final proj = await h.store.loadIncidentProjection(c.incidentId);
      expect(proj!.isTerminal, isFalse);
      expect(proj.lastRequesterStatus, IncidentQuickUpdate.falseAlarm);
    });
  });

  group('acknowledge (PR-9)', () {
    test(
      'emits a seen event and does NOT make the local node a responder',
      () async {
        final h = await build();
        addTearDown(h.db.close);
        // An inbound incident raised by a remote peer.
        await h.store.ingestEvent(
          IncidentEvent(
            incidentId: 0x7,
            workflowKind: IncidentWorkflowKind.helpRequest,
            type: IncidentEventType.create,
            senderNodeId: 200,
            seq: 0,
            timestamp: clock,
          ),
        );
        final outcome = await h.controller.acknowledge(incidentId: 0x7);
        expect(outcome.idAllocationFailed, isFalse);

        final events = await h.store.getTimeline(0x7);
        expect(
          events.any(
            (e) =>
                e.type == IncidentEventType.seen && e.senderNodeId == localNode,
          ),
          isTrue,
        );
        final proj = await h.store.loadIncidentProjection(0x7);
        expect(proj!.responderCount, 0);
        expect(
          proj.helpState,
          isNot(IncidentLifecycleState.activeWithResponder),
        );
      },
    );

    test('acknowledge emits no location event', () async {
      final h = await build();
      addTearDown(h.db.close);
      await h.store.ingestEvent(
        IncidentEvent(
          incidentId: 0x8,
          workflowKind: IncidentWorkflowKind.helpRequest,
          type: IncidentEventType.create,
          senderNodeId: 200,
          seq: 0,
          timestamp: clock,
        ),
      );
      await h.controller.acknowledge(incidentId: 0x8);
      final events = await h.store.getTimeline(0x8);
      expect(events.every((e) => e.location == null), isTrue);
      expect(events.any((e) => e.type == IncidentEventType.location), isFalse);
    });
  });

  group('robustness', () {
    test('send failure leaves the local event stored', () async {
      final h = await build(failSend: true);
      addTearDown(h.db.close);
      final outcome = await h.controller.createHelpRequest();
      expect(outcome.transmitted, isFalse);
      expect(outcome.persisted, isTrue);
      expect(
        await h.store.loadIncidentProjection(outcome.incidentId),
        isNotNull,
      );
    });

    test('per-sender seq is monotonic across local actions', () async {
      final h = await build();
      addTearDown(h.db.close);
      final c = await h.controller.createHelpRequest();
      final s1 = await h.controller.sendRequesterStatus(
        incidentId: c.incidentId,
        code: IncidentQuickUpdate.imOk,
      );
      final s2 = await h.controller.sendRequesterStatus(
        incidentId: c.incidentId,
        code: IncidentQuickUpdate.needWater,
      );
      expect(c.seq, 0);
      expect(s1.seq, 1);
      expect(s2.seq, 2);
    });

    test('duplicate local event is idempotent at the store', () async {
      final h = await build();
      addTearDown(h.db.close);
      final event = IncidentEvent(
        incidentId: 0xAB,
        workflowKind: IncidentWorkflowKind.helpRequest,
        type: IncidentEventType.create,
        senderNodeId: localNode,
        seq: 0,
        timestamp: clock,
      );
      expect(await h.store.ingestEvent(event), isTrue);
      expect(await h.store.ingestEvent(event), isFalse);
      expect(await h.store.getTimeline(0xAB), hasLength(1));
    });

    test(
      'distinct createHelpRequest calls get distinct incident ids',
      () async {
        final h = await build();
        addTearDown(h.db.close);
        final a = await h.controller.createHelpRequest();
        final b = await h.controller.createHelpRequest();
        expect(a.incidentId, isNot(b.incidentId));
      },
    );
  });

  group('incident id allocation (PR-7C)', () {
    test('uses the injected id generator', () async {
      final h = await build(idGenerator: () => 0x1234);
      addTearDown(h.db.close);
      final outcome = await h.controller.createHelpRequest();
      expect(outcome.incidentId, 0x1234);
      expect(outcome.idAllocationFailed, isFalse);
    });

    test('generated id is persisted and sent', () async {
      final h = await build(idGenerator: () => 0xABCD);
      addTearDown(h.db.close);
      final outcome = await h.controller.createHelpRequest();
      expect(await h.store.getTimeline(0xABCD), hasLength(1));
      expect(h.sends, hasLength(1));
      final decoded = SppIncidentModeCodec.decode(h.sends.single.$1, peerA);
      expect(decoded!.incidentId, 0xABCD);
      expect(outcome.incidentId, 0xABCD);
    });

    test('retries on local collision', () async {
      final h = await build(idGenerator: _sequence([0x1234, 0x1234, 0x5678]));
      addTearDown(h.db.close);
      await h.store.ingestEvent(_seed(0x1234));
      final outcome = await h.controller.createHelpRequest();
      expect(outcome.incidentId, 0x5678);
    });

    test('skips reserved sentinel ids (0 and 0xFFFFFFFF)', () async {
      final h = await build(idGenerator: _sequence([0, 0xFFFFFFFF, 0x42]));
      addTearDown(h.db.close);
      final outcome = await h.controller.createHelpRequest();
      expect(outcome.incidentId, 0x42);
    });

    test('exhausted retries return a safe failure', () async {
      final h = await build(idGenerator: () => 0x1234); // always collides
      addTearDown(h.db.close);
      await h.store.ingestEvent(_seed(0x1234));
      final outcome = await h.controller.createHelpRequest();
      expect(outcome.idAllocationFailed, isTrue);
      expect(outcome.persisted, isFalse);
      expect(h.sends, isEmpty);
      expect(await h.store.getTimeline(0x1234), hasLength(1));
    });

    test('default generator is random and avoids sentinels', () {
      final values = {
        for (var i = 0; i < 200; i++) defaultIncidentIdGenerator(),
      };
      expect(values.length, greaterThan(190));
      expect(values.any((v) => v <= 0 || v >= 0xFFFFFFFF), isFalse);
    });
  });

  group('location safety guardrails (PR-7C / PR-8 precondition)', () {
    test('precise location sending latch is OFF', () {
      expect(IncidentHelpController.preciseLocationSendingSupported, isFalse);
    });

    test('no help action emits a location event', () async {
      final h = await build();
      addTearDown(h.db.close);
      final c = await h.controller.createHelpRequest(
        initialStatus: IncidentQuickUpdate.imInjured,
      );
      await h.controller.acceptHelpRequest(incidentId: c.incidentId);
      await h.controller.sendResponderStatus(
        incidentId: c.incidentId,
        code: IncidentQuickUpdate.onMyWay,
      );
      await h.controller.resolveSafe(incidentId: c.incidentId);

      final events = await h.store.getTimeline(c.incidentId);
      expect(events, isNotEmpty);
      expect(events.any((e) => e.type == IncidentEventType.location), isFalse);
      expect(events.every((e) => e.location == null), isTrue);
      for (final (payload, _) in h.sends) {
        final decoded = SppIncidentModeCodec.decode(payload, peerA);
        expect(decoded!.type, isNot(IncidentEventType.location));
        expect(decoded.location, isNull);
      }
    });
  });
}

IncidentEvent _seed(int incidentId) => IncidentEvent(
  incidentId: incidentId,
  workflowKind: IncidentWorkflowKind.helpRequest,
  type: IncidentEventType.create,
  senderNodeId: 1,
  seq: 0,
  timestamp: DateTime.utc(2026, 6, 17, 10),
);

/// Returns the given values in order, repeating the last once exhausted.
int Function() _sequence(List<int> values) {
  var i = 0;
  return () {
    final v = values[i < values.length ? i : values.length - 1];
    i++;
    return v;
  };
}
