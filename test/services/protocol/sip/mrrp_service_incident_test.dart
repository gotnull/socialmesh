// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/incidents/models/incident.dart';
import 'package:socialmesh/features/incidents/models/mesh_incident_report.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_incident.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';
import 'package:socialmesh/services/protocol/sip/spp_constants.dart';
import 'package:socialmesh/services/protocol/sip/spp_incident_codec.dart';
import 'package:socialmesh/services/protocol/sip/spp_types.dart';

void main() {
  group('MrrpServiceIncident', () {
    late MrrpServiceIncident handler;
    late List<MeshIncidentReport> receivedReports;

    setUp(() {
      receivedReports = [];
      handler = MrrpServiceIncident(
        onReportReceived: (report) => receivedReports.add(report),
      );
    });

    test('serviceId is incidentV1', () {
      expect(handler.serviceId, MrrpServiceId.incidentV1);
    });

    test('supports report and query actions', () {
      expect(handler.supportedActions, contains(IncidentAction.report));
      expect(handler.supportedActions, contains(IncidentAction.query));
    });

    group('handleRequest - report', () {
      MrrpFrame buildReportRequest(Uint8List payload) {
        return MrrpFrame(
          versionMajor: MrrpConstants.mrrpVersionMajor,
          versionMinor: MrrpConstants.mrrpVersionMinor,
          msgType: MrrpMessageType.request,
          flags: 0,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 1,
          serviceId: MrrpServiceId.incidentV1,
          actionId: IncidentAction.report,
          payloadLen: payload.length,
          payload: payload,
        );
      }

      test('decodes valid report and calls callback', () async {
        final report = MeshIncidentReport(
          caseId: 42,
          seqNum: 0,
          updateType: IncidentUpdateType.initial,
          confidence: IncidentConfidence.probable,
          classification: IncidentClassification.safety,
          priority: IncidentPriority.immediate,
          status: IncidentMeshStatus.reported,
          reporterRole: IncidentReporterRole.observer,
          timestamp: DateTime.utc(2025, 6, 15),
          refSeq: SppConstants.noRefSeq,
          body: 'Fire spotted',
        );

        final encoded = SppIncidentCodec.encode(report)!;
        final request = buildReportRequest(encoded);
        final response = await handler.handleRequest(request, 99);

        expect(receivedReports, hasLength(1));
        expect(receivedReports.first.caseId, 42);
        expect(receivedReports.first.body, 'Fire spotted');
        expect(receivedReports.first.senderNodeId, 99);

        // Response should be OK (zero payload)
        expect(response.msgType, MrrpMessageType.response);
        expect(response.payloadLen, 0);
      });

      test('returns error for empty payload', () async {
        final request = buildReportRequest(Uint8List(0));
        final response = await handler.handleRequest(request, 1);

        expect(receivedReports, isEmpty);
        expect(response.msgType, MrrpMessageType.error);
      });

      test('returns error for malformed payload', () async {
        final bad = Uint8List.fromList([0x10, 1, 0, 0]); // Too short
        final request = buildReportRequest(bad);
        final response = await handler.handleRequest(request, 1);

        expect(receivedReports, isEmpty);
        expect(response.msgType, MrrpMessageType.error);
      });
    });

    group('handleRequest - query', () {
      test('returns notFound when no lookupCase provided', () async {
        final caseIdBytes = Uint8List(4);
        ByteData.sublistView(caseIdBytes).setUint32(0, 42, Endian.little);

        final request = MrrpFrame(
          versionMajor: MrrpConstants.mrrpVersionMajor,
          versionMinor: MrrpConstants.mrrpVersionMinor,
          msgType: MrrpMessageType.request,
          flags: 0,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 2,
          serviceId: MrrpServiceId.incidentV1,
          actionId: IncidentAction.query,
          payloadLen: caseIdBytes.length,
          payload: caseIdBytes,
        );

        final response = await handler.handleRequest(request, 1);
        expect(response.msgType, MrrpMessageType.error);
      });

      test('returns encoded state when lookupCase finds report', () async {
        final lookupReport = MeshIncidentReport(
          caseId: 42,
          seqNum: 1,
          updateType: IncidentUpdateType.update,
          confidence: IncidentConfidence.confirmed,
          classification: IncidentClassification.safety,
          priority: IncidentPriority.flash,
          status: IncidentMeshStatus.active,
          reporterRole: IncidentReporterRole.supervisor,
          timestamp: DateTime.utc(2025, 6, 15),
          refSeq: SppConstants.noRefSeq,
          body: 'Active fire',
          senderNodeId: 50,
        );

        final handlerWithLookup = MrrpServiceIncident(
          onReportReceived: (_) {},
          lookupCase: (caseId) => caseId == 42 ? lookupReport : null,
        );

        final caseIdBytes = Uint8List(4);
        ByteData.sublistView(caseIdBytes).setUint32(0, 42, Endian.little);

        final request = MrrpFrame(
          versionMajor: MrrpConstants.mrrpVersionMajor,
          versionMinor: MrrpConstants.mrrpVersionMinor,
          msgType: MrrpMessageType.request,
          flags: 0,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 3,
          serviceId: MrrpServiceId.incidentV1,
          actionId: IncidentAction.query,
          payloadLen: caseIdBytes.length,
          payload: caseIdBytes,
        );

        final response = await handlerWithLookup.handleRequest(request, 1);
        expect(response.msgType, MrrpMessageType.response);
        expect(response.payloadLen, greaterThan(0));

        // Decode the response payload to verify it matches
        final decoded = SppIncidentCodec.decode(response.payload, 0);
        expect(decoded, isNotNull);
        expect(decoded!.caseId, 42);
        expect(decoded.body, 'Active fire');
      });

      test('returns error for too-short query payload', () async {
        final request = MrrpFrame(
          versionMajor: MrrpConstants.mrrpVersionMajor,
          versionMinor: MrrpConstants.mrrpVersionMinor,
          msgType: MrrpMessageType.request,
          flags: 0,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 4,
          serviceId: MrrpServiceId.incidentV1,
          actionId: IncidentAction.query,
          payloadLen: 2,
          payload: Uint8List(2), // Need at least 4 bytes for case_id
        );

        final response = await handler.handleRequest(request, 1);
        expect(response.msgType, MrrpMessageType.error);
      });
    });

    group('handleRequest - unsupported action', () {
      test('returns unsupported status for unknown action', () async {
        final request = MrrpFrame(
          versionMajor: MrrpConstants.mrrpVersionMajor,
          versionMinor: MrrpConstants.mrrpVersionMinor,
          msgType: MrrpMessageType.request,
          flags: 0,
          headerLen: MrrpConstants.mrrpHeaderMin,
          requestId: 5,
          serviceId: MrrpServiceId.incidentV1,
          actionId: 0xFFFF, // Unknown action
          payloadLen: 0,
          payload: Uint8List(0),
        );

        final response = await handler.handleRequest(request, 1);
        expect(response.msgType, MrrpMessageType.error);
      });
    });
  });
}
