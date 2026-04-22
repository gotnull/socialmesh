// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetRemoteClient — builds pet.v1 REQUEST frames and decodes responses.
//
// ## Peer-targeting model (v1)
//
// Socialmesh does not have a peer-targeted MRRP request API. `sendSipPacket`
// broadcasts over the Meshtastic mesh (`to: 0xFFFFFFFF`, hopLimit=3), and
// every peer that holds an accepted SIP handshake with us will see our
// REQUEST. Any of them that has pet sharing enabled will encode their own
// `PetPublicState` and return a RESPONSE carrying the same `requestId`.
//
// `MrrpDispatcher.sendRequest` correlates a single completer per
// `requestId` — it completes on the first matching RESPONSE, and the
// `MrrpDedupCache` silently drops later responses with the same id.
// That means the `PetFetchOutcome` returned here represents "one peer
// answered"; it does NOT uniquely identify which peer.
//
// For correct peer→pet attribution we MUST rely on the Meshtastic packet's
// `from` field (the broadcast sender's nodeNum), which enters the MRRP
// engine at `_routeFrame(frame, senderNodeId, ...)`. The response observer
// installed in `mrrp_providers.dart` uses that `senderNodeId` to call
// `PetIngestController.ingestRemotePet(senderNodeId, decoded)` — so the
// cache key is always the authoritative sender, not the requester's
// assumed target.
//
// Consequences:
//   - A "fetch on detail open" in NodeDex broadcasts a REQUEST; peers in
//     range answer; the cache is warmed with each responder's pet, keyed
//     by their own nodeNum. The detail screen shows a preview only if one
//     of the responders matches the detail's nodeNum.
//   - True peer-targeted pull requires a protocol extension (e.g. a
//     target-nodeNum TLV that non-target peers ignore). That's a
//     follow-up; it's why we ship the broad push / publisher phase last.
//   - Dedup is keyed on `requestId`, not on `(requestId, senderNodeId)`.
//     That means we observe at most ONE responder per fetch today. Ingest
//     of additional responders requires relaxing dedup or hooking before
//     dedup fires (see response observer wiring).
//
// The `fetchSummary()` function here returns a single outcome — the
// reassembled view from the dispatcher's completer. Cache population is
// a side effect of the response observer, not of this return value.

import 'dart:typed_data';

import '../../../services/protocol/sip/mrrp_constants.dart';
import '../../../services/protocol/sip/mrrp_dispatcher.dart';
import '../../../services/protocol/sip/mrrp_frame.dart';
import '../../../services/protocol/sip/mrrp_types.dart';
import '../models/pet_public_state.dart';
import 'pet_public_state_codec.dart';

/// Result of a pet.v1 fetch attempt.
sealed class PetFetchOutcome {
  const PetFetchOutcome();
}

/// Remote peer returned a valid public state.
class PetFetchSuccess extends PetFetchOutcome {
  final PetPublicState state;
  final Duration? latency;
  const PetFetchSuccess(this.state, {this.latency});
}

/// Remote peer responded but has no pet bound yet (0-byte response).
class PetFetchEmpty extends PetFetchOutcome {
  const PetFetchEmpty();
}

/// Remote peer rejected the request (sharing disabled, unsupported, etc.).
class PetFetchRejected extends PetFetchOutcome {
  final MrrpStatusCode status;
  const PetFetchRejected(this.status);
}

/// No response received in time, or transport rejected the send.
class PetFetchFailed extends PetFetchOutcome {
  final MrrpStatusCode status;
  const PetFetchFailed(this.status);
}

class PetRemoteClient {
  final MrrpDispatcher _dispatcher;

  PetRemoteClient(this._dispatcher);

  /// Fetch the pet summary from the currently-active SIP peer. Returns one
  /// of the [PetFetchOutcome] subclasses describing what happened.
  Future<PetFetchOutcome> fetchSummary() async {
    final frame = MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.request,
      flags: MrrpFlags.ackRequired,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: 0, // dispatcher allocates
      serviceId: MrrpServiceId.petV1,
      actionId: PetAction.getSummary,
      payloadLen: 0,
      payload: Uint8List(0),
    );

    final result = await _dispatcher.sendRequest(frame);
    if (!result.isSuccess) {
      return PetFetchFailed(result.status);
    }
    final response = result.response;
    if (response == null) {
      return PetFetchFailed(MrrpStatusCode.timeout);
    }
    if ((response.flags & MrrpFlags.isError) != 0) {
      return PetFetchRejected(result.status);
    }
    if (response.payload.isEmpty) {
      return const PetFetchEmpty();
    }
    final decoded = PetPublicStateCodec.tryDecode(
      Uint8List.fromList(response.payload),
    );
    if (decoded == null) {
      return const PetFetchFailed(MrrpStatusCode.invalid);
    }
    return PetFetchSuccess(decoded, latency: result.latency);
  }
}
