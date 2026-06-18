// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP incident.v1 service handler.
///
/// Handles inbound incident report requests and dispatches them to
/// [MeshIncidentService] for persistence and UI notification.
///
/// Service ID: 0x00000004
/// Actions:
///   - report     (0x0001): Submit a new/updated hazard report (legacy SPP
///                          type 0x10, [SppIncidentCodec] / [MeshIncidentReport]).
///   - query      (0x0002): Request current state of a hazard case.
///   - helpEvent  (0x0003): Carry one Incident Mode help_request event
///                          (unified SPP type 0x13, [SppIncidentModeCodec] /
///                          [IncidentEvent]). Gated by
///                          [MrrpServiceIncident.helpRequestEnabled].
///
/// The legacy hazard report/query path is unchanged. The help_request path is
/// additive and inert unless its feature flag is enabled.
///
/// Spec: docs/protocol/INCIDENT_SPP_V0_1.md
/// Plan: docs/engineering/INCIDENT_MODE_SIP_MRRP_PLAN.md
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import '../../../features/incidents/models/incident_mode_models.dart';
import '../../../features/incidents/models/mesh_incident_report.dart';
import 'mrrp_constants.dart';
import 'mrrp_frame.dart';
import 'mrrp_service_handler.dart';
import 'mrrp_types.dart';
import 'spp_incident_codec.dart';
import 'spp_incident_mode_codec.dart';

/// Well-known action IDs for incident.v1 service.
abstract final class IncidentAction {
  /// Submit a new or updated hazard report (legacy path, SPP type 0x10).
  static const int report = 0x0001;

  /// Query the current state of a hazard case (legacy path).
  static const int query = 0x0002;

  /// Carry one Incident Mode help_request event (unified SPP type 0x13).
  static const int helpEvent = 0x0003;
}

/// Callback signature for when a mesh incident report is received.
typedef OnMeshIncidentReceived = void Function(MeshIncidentReport report);

/// Callback signature for when a decoded help_request [IncidentEvent] is
/// received and has passed all inbound gates.
typedef OnIncidentModeEvent = void Function(IncidentEvent event);

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

  /// Whether the help_request workflow is enabled. When false, the
  /// [IncidentAction.helpEvent] action is not advertised and is rejected as
  /// unsupported, leaving the help path completely inert.
  final bool helpRequestEnabled;

  /// Callback for a decoded, gated help_request [IncidentEvent].
  final OnIncidentModeEvent? onIncidentEvent;

  /// Optional Handshake-trust predicate for the sender of a help_request
  /// frame. When provided and it returns false, the frame is dropped without
  /// dispatch. When null, no trust gating is applied at this layer -- wiring
  /// the predicate from Handshake context is a documented seam (see the help
  /// handler) deferred to the send/receive wiring change. The path stays inert
  /// in production via the default-off [helpRequestEnabled] flag.
  final bool Function(int senderNodeId)? isSenderTrusted;

  MrrpServiceIncident({
    this.onReportReceived,
    this.lookupCase,
    this.helpRequestEnabled = false,
    this.onIncidentEvent,
    this.isSenderTrusted,
  });

  @override
  int get serviceId => MrrpServiceId.incidentV1;

  @override
  Set<int> get supportedActions => {
    IncidentAction.report,
    IncidentAction.query,
    if (helpRequestEnabled) IncidentAction.helpEvent,
  };

  @override
  Future<MrrpFrame> handleRequest(MrrpFrame request, int senderNodeId) async {
    switch (request.actionId) {
      case IncidentAction.report:
        return _handleReport(request, senderNodeId);
      case IncidentAction.query:
        return _handleQuery(request, senderNodeId);
      case IncidentAction.helpEvent:
        return _handleHelpEvent(request, senderNodeId);
      default:
        return _buildError(request, MrrpStatusCode.unsupported);
    }
  }

  /// Handles a help_request event frame (unified SPP type 0x13).
  ///
  /// Inbound gates, in order: feature flag, non-empty payload, decodable
  /// help_request event, workflow is help_request (hazard via 0x13 is not
  /// wired here -- hazard stays on the legacy 0x10 path), and the optional
  /// Handshake-trust predicate. Only on passing every gate is the decoded
  /// [IncidentEvent] dispatched. The sender id is bound from the transport
  /// [senderNodeId] argument, never from the payload. Logs carry only
  /// non-sensitive metadata (id / type / sender) -- never body text or
  /// location.
  MrrpFrame _handleHelpEvent(MrrpFrame request, int senderNodeId) {
    // Incident-namespace diagnostics (gated by INCIDENTS_LOGGING_ENABLED, the
    // flag operators actually flip for Help Mode). A "received" line is logged
    // first, before any gate, so a missing log means the frame never arrived
    // (transport / LoRa) while a later "dropped" line means it arrived but a
    // gate rejected it. Metadata only -- never body text or location.
    AppLogging.incidents(
      'helpEvent inbound: received from=$senderNodeId '
      'len=${request.payload.length}', // lint-allow: hardcoded-string
    );
    if (!helpRequestEnabled) {
      AppLogging.incidents(
        'helpEvent inbound: rejected (help_request disabled)', // lint-allow: hardcoded-string
      );
      return _buildError(request, MrrpStatusCode.unsupported);
    }
    if (request.payload.isEmpty) {
      AppLogging.incidents(
        'helpEvent inbound: rejected (empty payload)', // lint-allow: hardcoded-string
      );
      return _buildError(request, MrrpStatusCode.invalid);
    }

    final event = SppIncidentModeCodec.decode(request.payload, senderNodeId);
    if (event == null) {
      AppLogging.incidents(
        'helpEvent inbound: rejected (decode failed)', // lint-allow: hardcoded-string
      );
      return _buildError(request, MrrpStatusCode.invalid);
    }

    // PR-4 wires the help_request workflow only. A hazard_report carried over
    // the unified 0x13 envelope is rejected here; hazard reporting stays on
    // the legacy 0x10 report/query actions.
    if (event.workflowKind != IncidentWorkflowKind.helpRequest) {
      AppLogging.incidents(
        'helpEvent inbound: rejected (workflow != help_request)', // lint-allow: hardcoded-string
      );
      return _buildError(request, MrrpStatusCode.unsupported);
    }

    // Help Circle trust gate. When wired and the sender is not trusted (not in
    // the Help Circle, and no internal Handshake), drop silently with no
    // dispatch and no sensitive content in the log.
    if (isSenderTrusted != null && !isSenderTrusted!(senderNodeId)) {
      AppLogging.incidents(
        'helpEvent inbound: dropped untrusted sender=$senderNodeId '
        '(not in Help Circle)', // lint-allow: hardcoded-string
      );
      return _buildError(request, MrrpStatusCode.unauthorized);
    }

    AppLogging.incidents(
      'helpEvent inbound: accepted incident=${event.incidentId} '
      'type=${event.type.name} from=$senderNodeId', // lint-allow: hardcoded-string
    );

    onIncidentEvent?.call(event);

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
