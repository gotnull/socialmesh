// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PR-7A: inbound help_request events reach IncidentModeStore ONLY after the
// feature flag, decode, workflow and Handshake-trust gates pass.

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'package:socialmesh/features/incidents/models/incident.dart';
import 'package:socialmesh/features/incidents/models/incident_mode_models.dart';
import 'package:socialmesh/features/incidents/models/mesh_incident_report.dart';
import 'package:socialmesh/features/incidents/providers/mesh_incident_providers.dart';
import 'package:socialmesh/features/incidents/services/incident_mode_store.dart';
import 'package:socialmesh/features/incidents/services/mesh_incident_database.dart';
import 'package:socialmesh/providers/mrrp_providers.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_incident.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';
import 'package:socialmesh/services/protocol/sip/sip_handshake.dart';
import 'package:socialmesh/services/protocol/sip/sip_replay_cache.dart';
import 'package:socialmesh/services/protocol/sip/spp_incident_codec.dart';
import 'package:socialmesh/services/protocol/sip/spp_incident_mode_codec.dart';
import 'package:socialmesh/services/protocol/sip/spp_types.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _seq = 0;
final _pid = pid;
String _dbPath() =>
    p.join(Directory.systemTemp.path, 'incident_inbound_${_pid}_${_seq++}.db');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    if (!kIsWeb) databaseFactory = databaseFactoryFfi;
  });

  final ts = DateTime.utc(2026, 6, 17, 10);
  const incidentId = 0xC0DE;
  const trustedNode = 42;
  const untrustedNode = 99;

  IncidentEvent helpEvent(
    IncidentEventType type, {
    int seq = 0,
    IncidentQuickUpdate? quickUpdate,
  }) => IncidentEvent(
    incidentId: incidentId,
    workflowKind: IncidentWorkflowKind.helpRequest,
    type: type,
    senderNodeId: 0, // ignored by encode; bound from transport on decode
    seq: seq,
    timestamp: ts,
    quickUpdate: quickUpdate,
  );

  MrrpFrame helpFrame(Uint8List payload, {int requestId = 1}) => MrrpFrame(
    versionMajor: MrrpConstants.mrrpVersionMajor,
    versionMinor: MrrpConstants.mrrpVersionMinor,
    msgType: MrrpMessageType.request,
    flags: 0,
    headerLen: MrrpConstants.mrrpHeaderMin,
    requestId: requestId,
    serviceId: MrrpServiceId.incidentV1,
    actionId: IncidentAction.helpEvent,
    payloadLen: payload.length,
    payload: payload,
  );

  // Builds a handler wired exactly like the production provider: trust gate
  // paired with a store sink. The sink's futures are tracked so tests can
  // await persistence deterministically (production fire-and-forgets).
  ({
    MrrpServiceIncident handler,
    List<Future<void>> pending,
    List<MeshIncidentReport> legacyReports,
  })
  wire(
    IncidentModeStore store, {
    required bool helpEnabled,
    required Set<int> trusted,
  }) {
    final pending = <Future<void>>[];
    final legacy = <MeshIncidentReport>[];
    final handler = MrrpServiceIncident(
      onReportReceived: legacy.add,
      helpRequestEnabled: helpEnabled,
      isSenderTrusted: helpEnabled ? (n) => trusted.contains(n) : null,
      onIncidentEvent: helpEnabled
          ? (e) => pending.add(store.ingestEvent(e))
          : null,
    );
    return (handler: handler, pending: pending, legacyReports: legacy);
  }

  Future<(MeshIncidentDatabaseImpl, IncidentModeStore)> openStore() async {
    final db = MeshIncidentDatabaseImpl(dbPathOverride: _dbPath());
    await db.open();
    return (db, IncidentModeStore(db: db));
  }

  group('trust gate -> persistence', () {
    test('trusted IncidentCreate persists one event', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      final w = wire(store, helpEnabled: true, trusted: {trustedNode});

      await w.handler.handleRequest(
        helpFrame(
          SppIncidentModeCodec.encode(helpEvent(IncidentEventType.create))!,
        ),
        trustedNode,
      );
      await Future.wait(w.pending);

      final proj = await store.loadIncidentProjection(incidentId);
      expect(proj, isNotNull);
      expect(proj!.helpState, IncidentLifecycleState.broadcasting);
      expect((await store.getTimeline(incidentId)), hasLength(1));
    });

    test('untrusted sender persists nothing', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      final w = wire(store, helpEnabled: true, trusted: {trustedNode});

      final resp = await w.handler.handleRequest(
        helpFrame(
          SppIncidentModeCodec.encode(helpEvent(IncidentEventType.create))!,
        ),
        untrustedNode,
      );
      await Future.wait(w.pending);

      expect(w.pending, isEmpty); // sink never invoked
      expect(await store.loadIncidentProjection(incidentId), isNull);
      expect(resp.msgType, MrrpMessageType.error);
    });

    test('feature flag off persists nothing', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      final w = wire(store, helpEnabled: false, trusted: {trustedNode});

      final resp = await w.handler.handleRequest(
        helpFrame(
          SppIncidentModeCodec.encode(helpEvent(IncidentEventType.create))!,
        ),
        trustedNode,
      );
      await Future.wait(w.pending);
      expect(await store.loadIncidentProjection(incidentId), isNull);
      expect(resp.msgType, MrrpMessageType.error);
    });

    test('malformed helpEvent persists nothing and does not crash', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      final w = wire(store, helpEnabled: true, trusted: {trustedNode});

      final resp = await w.handler.handleRequest(
        helpFrame(Uint8List.fromList([0x13, 0x01, 0x99])),
        trustedNode,
      );
      await Future.wait(w.pending);
      expect(await store.loadIncidentProjection(incidentId), isNull);
      expect(resp.msgType, MrrpMessageType.error);
    });

    test('duplicate trusted event is idempotent', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      final w = wire(store, helpEnabled: true, trusted: {trustedNode});
      final payload = SppIncidentModeCodec.encode(
        helpEvent(IncidentEventType.create),
      )!;

      await w.handler.handleRequest(helpFrame(payload), trustedNode);
      await w.handler.handleRequest(
        helpFrame(payload, requestId: 2),
        trustedNode,
      );
      await Future.wait(w.pending);

      expect(await store.getTimeline(incidentId), hasLength(1));
    });

    test('trusted ResponderAccept projects activeWithResponder', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      final w = wire(store, helpEnabled: true, trusted: {trustedNode, 200});

      await w.handler.handleRequest(
        helpFrame(
          SppIncidentModeCodec.encode(helpEvent(IncidentEventType.create))!,
        ),
        trustedNode,
      );
      await w.handler.handleRequest(
        helpFrame(
          SppIncidentModeCodec.encode(
            helpEvent(IncidentEventType.responderAccept),
          )!,
          requestId: 2,
        ),
        200,
      );
      await Future.wait(w.pending);

      final proj = await store.loadIncidentProjection(incidentId);
      expect(proj!.helpState, IncidentLifecycleState.activeWithResponder);
      expect(proj.responderCount, 1);
    });

    test('trusted RequesterStatus persists', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      final w = wire(store, helpEnabled: true, trusted: {trustedNode});

      await w.handler.handleRequest(
        helpFrame(
          SppIncidentModeCodec.encode(helpEvent(IncidentEventType.create))!,
        ),
        trustedNode,
      );
      await w.handler.handleRequest(
        helpFrame(
          SppIncidentModeCodec.encode(
            helpEvent(
              IncidentEventType.requesterStatus,
              seq: 1,
              quickUpdate: IncidentQuickUpdate.imInjured,
            ),
          )!,
          requestId: 2,
        ),
        trustedNode,
      );
      await Future.wait(w.pending);

      final proj = await store.loadIncidentProjection(incidentId);
      expect(proj!.lastRequesterStatus, IncidentQuickUpdate.imInjured);
    });

    test('trusted IncidentResolve projects resolvedSafe', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      final w = wire(store, helpEnabled: true, trusted: {trustedNode});

      await w.handler.handleRequest(
        helpFrame(
          SppIncidentModeCodec.encode(helpEvent(IncidentEventType.create))!,
        ),
        trustedNode,
      );
      await w.handler.handleRequest(
        helpFrame(
          SppIncidentModeCodec.encode(
            helpEvent(IncidentEventType.resolve, seq: 1),
          )!,
          requestId: 2,
        ),
        trustedNode,
      );
      await Future.wait(w.pending);

      final proj = await store.loadIncidentProjection(incidentId);
      expect(proj!.helpState, IncidentLifecycleState.resolvedSafe);
    });

    test('trusted IncidentCancel projects cancelled', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      final w = wire(store, helpEnabled: true, trusted: {trustedNode});

      await w.handler.handleRequest(
        helpFrame(
          SppIncidentModeCodec.encode(helpEvent(IncidentEventType.create))!,
        ),
        trustedNode,
      );
      await w.handler.handleRequest(
        helpFrame(
          SppIncidentModeCodec.encode(
            helpEvent(IncidentEventType.cancel, seq: 1),
          )!,
          requestId: 2,
        ),
        trustedNode,
      );
      await Future.wait(w.pending);

      final proj = await store.loadIncidentProjection(incidentId);
      expect(proj!.helpState, IncidentLifecycleState.cancelled);
    });

    test('sender identity is bound from MRRP context, not payload', () async {
      final (db, store) = await openStore();
      addTearDown(db.close);
      const wireSender = 777;
      final w = wire(store, helpEnabled: true, trusted: {wireSender});

      await w.handler.handleRequest(
        helpFrame(
          SppIncidentModeCodec.encode(helpEvent(IncidentEventType.create))!,
        ),
        wireSender,
      );
      await Future.wait(w.pending);

      final events = await store.getTimeline(incidentId);
      expect(events.single.senderNodeId, wireSender);
    });
  });

  group('legacy hazard path untouched', () {
    test(
      'report action uses legacy codec and does not hit the store',
      () async {
        final (db, store) = await openStore();
        addTearDown(db.close);
        final w = wire(store, helpEnabled: true, trusted: {trustedNode});

        final report = MeshIncidentReport(
          caseId: 7,
          seqNum: 0,
          updateType: IncidentUpdateType.initial,
          confidence: IncidentConfidence.probable,
          classification: IncidentClassification.safety,
          priority: IncidentPriority.immediate,
          status: IncidentMeshStatus.reported,
          reporterRole: IncidentReporterRole.observer,
          timestamp: ts,
          body: 'Fire spotted',
        );
        final frame = MrrpFrame(
          versionMajor: MrrpConstants.mrrpVersionMajor,
          versionMinor: MrrpConstants.mrrpVersionMinor,
          msgType: MrrpMessageType.request,
          flags: 0,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 1,
          serviceId: MrrpServiceId.incidentV1,
          actionId: IncidentAction.report,
          payloadLen: 0,
          payload: SppIncidentCodec.encode(report)!,
        );
        final resp = await w.handler.handleRequest(frame, trustedNode);
        await Future.wait(w.pending);

        expect(w.legacyReports, hasLength(1));
        expect(w.pending, isEmpty); // help store never touched by legacy path
        expect(await store.getTimeline(incidentId), isEmpty);
        expect(resp.msgType, MrrpMessageType.response);
      },
    );

    test('query action still works (notFound without lookup)', () async {
      final handler = MrrpServiceIncident(helpRequestEnabled: true);
      final caseId = Uint8List(4);
      ByteData.sublistView(caseId).setUint32(0, 1, Endian.little);
      final resp = await handler.handleRequest(
        MrrpFrame(
          versionMajor: MrrpConstants.mrrpVersionMajor,
          versionMinor: MrrpConstants.mrrpVersionMinor,
          msgType: MrrpMessageType.request,
          flags: 0,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 1,
          serviceId: MrrpServiceId.incidentV1,
          actionId: IncidentAction.query,
          payloadLen: 4,
          payload: caseId,
        ),
        trustedNode,
      );
      expect(resp.msgType, MrrpMessageType.error);
    });
  });

  group('trust predicate semantics (SipHandshakeManager)', () {
    test('only a completed handshake counts as trusted', () async {
      final initiator = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: 0xAAAA,
      )..isDmAvailable = true;
      final responder = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: 0xBBBB,
      )..isDmAvailable = true;
      const nodeA = 0xAAAA;
      const nodeB = 0xBBBB;

      // Not trusted before the handshake completes.
      expect(initiator.getState(nodeB), isNot(SipHandshakeState.accepted));

      final hello = initiator.initiateHandshake(nodeB)!;
      responder.handleHello(nodeA, hello);
      final challenge = responder.acceptHandshake(nodeA)!;
      final response = (await initiator.handleChallenge(nodeB, challenge))!;
      final accept = (await responder.handleResponse(nodeA, response))!;
      initiator.handleAccept(nodeB, accept);

      // The exact predicate used by the inbound wiring.
      expect(initiator.getState(nodeB), SipHandshakeState.accepted);
      // An unrelated node is never trusted.
      expect(initiator.getState(0x1234), isNot(SipHandshakeState.accepted));
    });
  });

  group('provider gating', () {
    test('registry is null and store is constructible when flags off', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Flags default off in tests (dotenv not loaded) -> no MRRP registry,
      // so nothing advertises or stores.
      expect(container.read(mrrpServiceRegistryProvider), isNull);
      // The store provider builds cleanly (no circular dependency) but is only
      // consumed by the registry when the flags are enabled.
      expect(
        container.read(incidentModeStoreProvider),
        isA<IncidentModeStore>(),
      );
    });
  });
}
