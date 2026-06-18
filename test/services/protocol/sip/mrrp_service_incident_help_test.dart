// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/incidents/models/incident.dart';
import 'package:socialmesh/features/incidents/models/incident_mode_models.dart';
import 'package:socialmesh/features/incidents/models/mesh_incident_report.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_incident.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';
import 'package:socialmesh/services/protocol/sip/spp_incident_codec.dart';
import 'package:socialmesh/services/protocol/sip/spp_incident_mode_codec.dart';
import 'package:socialmesh/services/protocol/sip/spp_types.dart';

void main() {
  final ts = DateTime.utc(2026, 6, 17, 10);
  const incidentId = 0x0A0B0C0D;

  IncidentEvent helpEvent(
    IncidentEventType type, {
    IncidentQuickUpdate? quickUpdate,
    IncidentAckCategory? ackCategory,
  }) => IncidentEvent(
    incidentId: incidentId,
    workflowKind: IncidentWorkflowKind.helpRequest,
    type: type,
    senderNodeId: 0, // ignored by encode; bound on decode from transport
    seq: 0,
    timestamp: ts,
    quickUpdate: quickUpdate,
    ackCategory: ackCategory,
  );

  MrrpFrame helpRequestFrame(Uint8List payload, {int requestId = 1}) =>
      MrrpFrame(
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

  group('IncidentAction constants', () {
    test('helpEvent is 0x0003 and non-colliding', () {
      expect(IncidentAction.helpEvent, 0x0003);
      final ids = {
        IncidentAction.report,
        IncidentAction.query,
        IncidentAction.helpEvent,
      };
      expect(ids.length, 3); // all distinct
    });
  });

  group('SipFeatureBits.incidentHelpV1', () {
    test('is bit 14 and does not collide with existing bits', () {
      expect(SipFeatureBits.incidentHelpV1, 1 << 14);
      const existing = [
        SipFeatureBits.sip0,
        SipFeatureBits.sip1,
        SipFeatureBits.sip3,
        SipFeatureBits.overlayLinkV02,
        SipFeatureBits.overlayResourceV02,
        SipFeatureBits.overlaySecureV03,
        SipFeatureBits.dmInkV1,
        SipFeatureBits.dmPlayV1,
        SipFeatureBits.dmSignalV1,
      ];
      for (final bit in existing) {
        expect(SipFeatureBits.incidentHelpV1 & bit, 0, reason: 'collides');
      }
      // Not implicitly part of the v0.1 baseline advert.
      expect(SipFeatureBits.allV01 & SipFeatureBits.incidentHelpV1, 0);
    });
  });

  group('help_request dispatch (flag enabled)', () {
    late List<IncidentEvent> sink;
    late MrrpServiceIncident handler;

    setUp(() {
      sink = [];
      handler = MrrpServiceIncident(
        helpRequestEnabled: true,
        onIncidentEvent: sink.add,
      );
    });

    test('advertises helpEvent in supportedActions when enabled', () {
      expect(handler.supportedActions, contains(IncidentAction.helpEvent));
      expect(handler.supportedActions, contains(IncidentAction.report));
      expect(handler.supportedActions, contains(IncidentAction.query));
    });

    test('decodes IncidentCreate and dispatches one event', () async {
      final payload = SppIncidentModeCodec.encode(
        helpEvent(IncidentEventType.create),
      )!;
      final response = await handler.handleRequest(
        helpRequestFrame(payload),
        314,
      );

      expect(sink, hasLength(1));
      expect(sink.first.type, IncidentEventType.create);
      expect(sink.first.incidentId, incidentId);
      expect(sink.first.senderNodeId, 314); // bound from transport, not payload
      expect(response.msgType, MrrpMessageType.response);
      expect(response.payloadLen, 0);
    });

    test('decodes ResponderAccept and dispatches one event', () async {
      final payload = SppIncidentModeCodec.encode(
        helpEvent(IncidentEventType.responderAccept),
      )!;
      await handler.handleRequest(helpRequestFrame(payload), 200);
      expect(sink, hasLength(1));
      expect(sink.first.type, IncidentEventType.responderAccept);
      expect(sink.first.senderNodeId, 200);
    });

    test('decodes RequesterStatus and dispatches one event', () async {
      final payload = SppIncidentModeCodec.encode(
        helpEvent(
          IncidentEventType.requesterStatus,
          quickUpdate: IncidentQuickUpdate.imInjured,
        ),
      )!;
      await handler.handleRequest(helpRequestFrame(payload), 100);
      expect(sink, hasLength(1));
      expect(sink.first.type, IncidentEventType.requesterStatus);
      expect(sink.first.quickUpdate, IncidentQuickUpdate.imInjured);
    });

    test('decodes IncidentResolve and dispatches one event', () async {
      final payload = SppIncidentModeCodec.encode(
        helpEvent(IncidentEventType.resolve),
      )!;
      await handler.handleRequest(helpRequestFrame(payload), 100);
      expect(sink, hasLength(1));
      expect(sink.first.type, IncidentEventType.resolve);
    });

    test(
      'malformed 0x13 payload is rejected without dispatch or crash',
      () async {
        final response = await handler.handleRequest(
          helpRequestFrame(Uint8List.fromList([0x13, 0x01, 0x99])),
          1,
        );
        expect(sink, isEmpty);
        expect(response.msgType, MrrpMessageType.error);
      },
    );

    test('empty payload is rejected without dispatch', () async {
      final response = await handler.handleRequest(
        helpRequestFrame(Uint8List(0)),
        1,
      );
      expect(sink, isEmpty);
      expect(response.msgType, MrrpMessageType.error);
    });

    test(
      'a hazard_report carried over 0x13 is rejected (stays on legacy)',
      () async {
        final hazardOver13 = SppIncidentModeCodec.encode(
          IncidentEvent(
            incidentId: incidentId,
            workflowKind: IncidentWorkflowKind.hazardReport,
            type: IncidentEventType.hazardReport,
            senderNodeId: 0,
            seq: 0,
            timestamp: ts,
            hazardStatus: IncidentMeshStatus.reported,
            hazardUpdateType: IncidentUpdateType.initial,
          ),
        )!;
        final response = await handler.handleRequest(
          helpRequestFrame(hazardOver13),
          1,
        );
        expect(sink, isEmpty);
        expect(response.msgType, MrrpMessageType.error);
      },
    );
  });

  group('help_request gating (flag disabled)', () {
    test('helpEvent not advertised and rejected as unsupported', () async {
      final sink = <IncidentEvent>[];
      final handler = MrrpServiceIncident(
        helpRequestEnabled: false,
        onIncidentEvent: sink.add,
      );
      expect(
        handler.supportedActions,
        isNot(contains(IncidentAction.helpEvent)),
      );

      final payload = SppIncidentModeCodec.encode(
        helpEvent(IncidentEventType.create),
      )!;
      final response = await handler.handleRequest(
        helpRequestFrame(payload),
        1,
      );
      expect(sink, isEmpty);
      expect(response.msgType, MrrpMessageType.error);
    });
  });

  group('Handshake-trust seam', () {
    test('untrusted sender is dropped without dispatch', () async {
      final sink = <IncidentEvent>[];
      final handler = MrrpServiceIncident(
        helpRequestEnabled: true,
        onIncidentEvent: sink.add,
        isSenderTrusted: (_) => false,
      );
      final payload = SppIncidentModeCodec.encode(
        helpEvent(IncidentEventType.create),
      )!;
      final response = await handler.handleRequest(
        helpRequestFrame(payload),
        9,
      );
      expect(sink, isEmpty);
      expect(response.msgType, MrrpMessageType.error);
    });

    test('trusted sender is dispatched', () async {
      final sink = <IncidentEvent>[];
      final handler = MrrpServiceIncident(
        helpRequestEnabled: true,
        onIncidentEvent: sink.add,
        isSenderTrusted: (node) => node == 42,
      );
      final payload = SppIncidentModeCodec.encode(
        helpEvent(IncidentEventType.create),
      )!;
      await handler.handleRequest(helpRequestFrame(payload), 42);
      expect(sink, hasLength(1));
      expect(sink.first.senderNodeId, 42);
    });
  });

  group('legacy hazard path non-regression', () {
    test('report action still uses the legacy SppIncidentCodec path', () async {
      final reports = <MeshIncidentReport>[];
      final events = <IncidentEvent>[];
      final handler = MrrpServiceIncident(
        onReportReceived: reports.add,
        helpRequestEnabled: true,
        onIncidentEvent: events.add,
      );

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
      final legacyPayload = SppIncidentCodec.encode(report)!;

      final frame = MrrpFrame(
        versionMajor: MrrpConstants.mrrpVersionMajor,
        versionMinor: MrrpConstants.mrrpVersionMinor,
        msgType: MrrpMessageType.request,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 1,
        serviceId: MrrpServiceId.incidentV1,
        actionId: IncidentAction.report,
        payloadLen: legacyPayload.length,
        payload: legacyPayload,
      );
      final response = await handler.handleRequest(frame, 55);

      // Legacy report path fired; help event sink untouched.
      expect(reports, hasLength(1));
      expect(reports.first.caseId, 7);
      expect(reports.first.body, 'Fire spotted');
      expect(reports.first.senderNodeId, 55);
      expect(events, isEmpty);
      expect(response.msgType, MrrpMessageType.response);
    });

    test('query action still works (notFound without lookup)', () async {
      final handler = MrrpServiceIncident(helpRequestEnabled: true);
      final caseId = Uint8List(4);
      ByteData.sublistView(caseId).setUint32(0, 42, Endian.little);
      final frame = MrrpFrame(
        versionMajor: MrrpConstants.mrrpVersionMajor,
        versionMinor: MrrpConstants.mrrpVersionMinor,
        msgType: MrrpMessageType.request,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 2,
        serviceId: MrrpServiceId.incidentV1,
        actionId: IncidentAction.query,
        payloadLen: caseId.length,
        payload: caseId,
      );
      final response = await handler.handleRequest(frame, 1);
      expect(response.msgType, MrrpMessageType.error);
    });

    test('unknown action remains safe (unsupported)', () async {
      final handler = MrrpServiceIncident(helpRequestEnabled: true);
      final frame = MrrpFrame(
        versionMajor: MrrpConstants.mrrpVersionMajor,
        versionMinor: MrrpConstants.mrrpVersionMinor,
        msgType: MrrpMessageType.request,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 3,
        serviceId: MrrpServiceId.incidentV1,
        actionId: 0xFFFF,
        payloadLen: 0,
        payload: Uint8List(0),
      );
      final response = await handler.handleRequest(frame, 1);
      expect(response.msgType, MrrpMessageType.error);
    });
  });
}
