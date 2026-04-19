// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP incident.v1 service handler.
///
/// Handles inbound incident report requests and dispatches them to
/// [MeshIncidentService] for persistence and UI notification.
///
/// Service ID: 0x00000004
/// Actions:
///   - report  (0x0001): Submit a new/updated incident report
///   - query   (0x0002): Request current state of a case
///
/// Spec: docs/protocol/INCIDENT_SPP_V0_1.md
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import '../../../features/incidents/models/mesh_incident_report.dart';
import 'mrrp_constants.dart';
import 'mrrp_frame.dart';
import 'mrrp_service_handler.dart';
import 'mrrp_types.dart';
import 'spp_incident_codec.dart';

/// Well-known action IDs for incident.v1 service.
abstract final class IncidentAction {
  /// Submit a new or updated incident report.
  static const int report = 0x0001;

  /// Query the current state of a case.
  static const int query = 0x0002;
}

/// Callback signature for when a mesh incident report is received.
typedef OnMeshIncidentReceived = void Function(MeshIncidentReport report);

/// incident.v1 MRRP service handler.
///
/// Decodes inbound SPP incident payloads and notifies the application
/// via [onReportReceived]. For query actions, returns the latest known
/// state for the requested case_id.
class MrrpServiceIncident implements MrrpServiceHandler {
  /// Callback invoked when a valid incident report is received.
  final OnMeshIncidentReceived? onReportReceived;

  /// Lookup function for case state (for query responses).
  final MeshIncidentReport? Function(int caseId)? lookupCase;

  MrrpServiceIncident({this.onReportReceived, this.lookupCase});

  @override
  int get serviceId => MrrpServiceId.incidentV1;

  @override
  Set<int> get supportedActions => const {
    IncidentAction.report,
    IncidentAction.query,
  };

  @override
  Future<MrrpFrame> handleRequest(MrrpFrame request, int senderNodeId) async {
    switch (request.actionId) {
      case IncidentAction.report:
        return _handleReport(request, senderNodeId);
      case IncidentAction.query:
        return _handleQuery(request, senderNodeId);
      default:
        return _buildError(request, MrrpStatusCode.unsupported);
    }
  }

  MrrpFrame _handleReport(MrrpFrame request, int senderNodeId) {
    if (request.payload.isEmpty) {
      AppLogging.protocol(
        'MRRP_SERVICE: incident.v1 report - '
        'empty payload', // lint-allow: hardcoded-string
      );
      return _buildError(request, MrrpStatusCode.invalid);
    }

    final report = SppIncidentCodec.decode(request.payload, senderNodeId);
    if (report == null) {
      AppLogging.protocol(
        'MRRP_SERVICE: incident.v1 report - '
        'decode failed', // lint-allow: hardcoded-string
      );
      return _buildError(request, MrrpStatusCode.invalid);
    }

    AppLogging.protocol(
      'MRRP_SERVICE: incident.v1 report case=${report.caseId} '
      'seq=${report.seqNum} type=${report.updateType.name} '
      'from=$senderNodeId', // lint-allow: hardcoded-string
    );

    onReportReceived?.call(report);

    // ACK with OK status
    return MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.response,
      flags: MrrpFlags.isResponse,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: serviceId,
      actionId: request.actionId,
      payloadLen: 0,
      payload: Uint8List(0),
    );
  }

  MrrpFrame _handleQuery(MrrpFrame request, int senderNodeId) {
    if (request.payload.length < 4) {
      return _buildError(request, MrrpStatusCode.invalid);
    }

    final caseId = ByteData.sublistView(
      request.payload,
    ).getUint32(0, Endian.little);

    AppLogging.protocol(
      'MRRP_SERVICE: incident.v1 query case=$caseId '
      'from=$senderNodeId', // lint-allow: hardcoded-string
    );

    final latest = lookupCase?.call(caseId);
    if (latest == null) {
      return _buildError(request, MrrpStatusCode.notFound);
    }

    final encoded = SppIncidentCodec.encode(latest);
    if (encoded == null) {
      return _buildError(request, MrrpStatusCode.internal);
    }

    return MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.response,
      flags: MrrpFlags.isResponse,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: serviceId,
      actionId: request.actionId,
      payloadLen: encoded.length,
      payload: encoded,
    );
  }

  MrrpFrame _buildError(MrrpFrame request, MrrpStatusCode statusCode) {
    final payload = Uint8List(1);
    payload[0] = statusCode.code;
    return MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.error,
      flags: MrrpFlags.isResponse | MrrpFlags.isError,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: serviceId,
      actionId: request.actionId,
      payloadLen: 1,
      payload: payload,
    );
  }
}
