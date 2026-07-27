// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../generated/meshtastic/mesh.pb.dart' as pb;

// Receive-path metadata helpers shared by the foreground
// (ProtocolService) and background (BackgroundMessageProcessor) text
// message ingest paths, so both produce identical Message metadata.

/// Compute hop count from hopStart and hopLimit fields in a MeshPacket.
/// Returns null if hop info is unavailable.
int? computeHopCount(pb.MeshPacket packet) {
  if (packet.hasHopStart() && packet.hopStart > 0) {
    final hops = packet.hopStart - packet.hopLimit;
    return hops < 0 ? 0 : hops;
  }
  return null;
}

/// Delivery-path flag for a live decoded packet.
///
/// `MeshPacket.via_mqtt` is a plain proto3 bool: `false` is never encoded
/// on the wire, so absence IS the value `false` — `hasViaMqtt()` cannot
/// distinguish "firmware said RF" from "field missing" and gating on it
/// would classify every RF delivery as unknown. A packet decoded from the
/// connected radio therefore always carries a definitive answer: `true`
/// means the packet passed through an MQTT gateway, `false` means it
/// reached the radio purely over RF. "Unknown" (null) is reserved for
/// rows persisted before this field was stored and for messages that
/// never came from a decoded packet (push payloads, sent messages).
bool receiveViaMqtt(pb.MeshPacket packet) => packet.viaMqtt;
