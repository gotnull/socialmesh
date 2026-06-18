// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Riverpod wiring for the outbound Incident Mode (Help Mode) controller.
///
/// This is a leaf provider file: it depends on the SIP, MRRP, and incident
/// store providers but nothing imports it except UI, so it introduces no
/// provider cycle.
///
/// Eligibility for sending = in the user's Help Circle (per-peer opt-in;
/// optionally also a completed SIP Handshake on internal builds) AND advertises
/// `SipFeatureBits.incidentHelpV1`. The transport is broadcast-only, so the
/// controller transmits a single broadcast help event when at least one
/// eligible recipient exists and transmits nothing otherwise (the event is
/// still persisted locally).
///
/// Plan: docs/engineering/INCIDENT_MODE_SIP_MRRP_PLAN.md (PR-7B)
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/incidents/providers/mesh_incident_providers.dart';
import '../features/incidents/services/incident_help_controller.dart';
import '../services/protocol/sip/mrrp_constants.dart';
import '../services/protocol/sip/mrrp_frame.dart';
import '../services/protocol/sip/mrrp_service_incident.dart';
import '../services/protocol/sip/mrrp_types.dart';
import '../features/incidents/providers/incident_help_trust_provider.dart';
import 'app_providers.dart';
import 'mrrp_providers.dart';
import 'sip_providers.dart';

/// The outbound Incident Mode controller, wired to live SIP/MRRP state.
final incidentHelpControllerProvider = Provider<IncidentHelpController>((ref) {
  return IncidentHelpController(
    store: ref.read(incidentModeStoreProvider),
    ensureStoreReady: () => ref.read(meshIncidentDatabaseProvider).open(),
    localNodeId: () => ref.read(myNodeNumProvider) ?? 0,
    discoveredPeers: () {
      final discovery = ref.read(sipDiscoveryProvider);
      if (discovery == null) return const <IncidentPeer>[];
      return [
        for (final p in discovery.discoveredPeers)
          (nodeId: p.nodeId, features: p.features),
      ];
    },
    isTrusted: (nodeId) => incidentHelpTrustGate(
      circle: ref.read(incidentHelpTrustedIdsProvider),
      handshake: ref.read(sipHandshakeProvider),
      nodeId: nodeId,
    ),
    sendHelpEvent: (payload, recipients) => _broadcastHelpEvent(ref, payload),
  );
});

/// Hands one help-event frame to the broadcast MRRP transport.
///
/// The transport is broadcast-only; the eligibility decision (>=1 trusted +
/// capable recipient) was already made by the controller. Fire-and-forget: the
/// UI never blocks on a response and delivery is never implied as guaranteed.
/// Returns whether the frame was handed to the dispatcher.
Future<bool> _broadcastHelpEvent(Ref ref, Uint8List payload) async {
  final dispatcher = ref.read(mrrpDispatcherProvider);
  if (dispatcher == null) return false;
  final frame = MrrpFrame(
    versionMajor: MrrpConstants.mrrpVersionMajor,
    versionMinor: MrrpConstants.mrrpVersionMinor,
    msgType: MrrpMessageType.request,
    flags: MrrpFlags.ackRequired,
    headerLen: MrrpConstants.mrrpHeaderMin,
    requestId: 0, // dispatcher allocates
    serviceId: MrrpServiceId.incidentV1,
    actionId: IncidentAction.helpEvent,
    payloadLen: payload.length,
    payload: payload,
  );
  // Help events ride the standard MRRP request path: dispatcher.sendRequest ->
  // mrrpEngine onSend -> sendViaSip, which consults the shared SipRateLimiter
  // (1024 B / 60 s) before transport. There is NO airtime exemption for help
  // packets -- priority is queue ordering only. If the budget is exhausted the
  // send is throttled like any other MRRP frame; the event is already persisted
  // locally regardless.
  unawaited(() async {
    try {
      await dispatcher.sendRequest(frame);
    } catch (_) {
      // Send failures are non-fatal: the event is already persisted locally.
    }
  }());
  return true;
}
