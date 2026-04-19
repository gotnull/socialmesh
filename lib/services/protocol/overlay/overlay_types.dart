// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Enums and flag bitfields for the Socialmesh Overlay v0.2 stack.
///
/// Wire codes are anchored to `docs/sip/OVERLAY_V0_2.md` §10.1 (link
/// message types), §11.2 (resource message types), and §10.3 (link
/// states). All codes are frozen; adding a new value requires a spec
/// bump.
library;

/// MRRP v0.2 link-layer message types (byte 4 of the MRRP frame).
///
/// These codes intentionally sit in the `0x20..0x27` block so that
/// MRRP v0.1 peers drop them via the "unknown message type" path
/// (`MrrpMessageType.fromCode` returns null), preserving wire
/// backwards-compatibility.
enum OverlayLinkMsgType {
  /// Initiator asks a peer to open a link (signed in §12 future mode).
  linkOpen(0x20),

  /// Responder accepts the link, carries responder ephemeral pub (v0.3).
  linkOpenOk(0x21),

  /// Responder declines. Payload includes a [OverlayLinkCloseReason].
  linkOpenNo(0x22),

  /// Keepalive probe (plaintext, not signed).
  linkPing(0x23),

  /// Keepalive echo.
  linkPong(0x24),

  /// Explicit link close. Payload includes a [OverlayLinkCloseReason].
  linkClose(0x25),

  /// Sequenced data frame carrying a higher-layer payload (SPP v0.2).
  linkData(0x26),

  /// Selective cumulative ACK / NACK hint.
  linkAck(0x27),

  /// v0.3 secure-session Init (initiator → responder). Carries
  /// ephemeral X25519 pub, random nonce, and Ed25519 signature over
  /// the initiator-side transcript. See OVERLAY_V0_2.md §25.
  linkSecureInit(0x28),

  /// v0.3 secure-session Ack (responder → initiator). Carries
  /// responder ephemeral X25519 pub, nonce, and Ed25519 signature
  /// over the full transcript. See OVERLAY_V0_2.md §25.
  linkSecureAck(0x29),

  /// v0.3 secure data frame. Payload is
  /// `subtype(1) ‖ seq(4) ‖ aead_tag(16) ‖ ciphertext` encrypted
  /// with the session's per-direction ChaCha20-Poly1305 key. See
  /// OVERLAY_V0_2.md §25.5.
  linkSecureData(0x2A);

  const OverlayLinkMsgType(this.code);

  /// Wire code for this message type.
  final int code;

  /// Resolve a wire code to a message type, or null if unknown.
  static OverlayLinkMsgType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// SPP v0.2 resource-layer message types (byte 0 of the SPP header).
enum OverlayResourceMsgType {
  /// Sender advertises a resource. Payload is a manifest (size, mime,
  /// SHA-256, TTL).
  offer(0x01),

  /// Receiver accepts the offer.
  accept(0x02),

  /// Receiver declines the offer. Payload carries a reason byte.
  decline(0x03),

  /// Sender transmits a chunk. Payload prefixed by [OverlayResourceFrame]
  /// header.
  chunk(0x04),

  /// Receiver reports a selective-ACK bitmap.
  bitmap(0x05),

  /// Receiver explicitly asks for specific chunk indexes.
  nack(0x06),

  /// Sender announces "all chunks sent; here is the final SHA-256".
  complete(0x07),

  /// Receiver confirms hash match.
  verified(0x08),

  /// Either side aborts the transfer. Payload carries a reason byte.
  abort(0x09),

  /// Sender re-announces an in-progress offer after restart or reconnect.
  resume(0x0A);

  const OverlayResourceMsgType(this.code);

  /// Wire code for this message type.
  final int code;

  /// Resolve a wire code to a message type, or null if unknown.
  static OverlayResourceMsgType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// v0.3 secure-data subtype (byte 0 of a [OverlayLinkMsgType.linkSecureData]
/// payload). Allows Phase 2 to multiplex distinct encrypted payload
/// families (DM text, reaction, RPC envelope) onto the same frame type
/// without wire-format evolution. See OVERLAY_V0_2.md §25.5.
enum OverlaySecureDataSubtype {
  /// Phase 1 sentinel. Opaque encrypted payload; higher-layer schema
  /// is defined by the application.
  generic(0x01),

  /// Phase 2: encrypted DM text (UTF-8 bytes).
  dmText(0x02),

  /// Phase 2: encrypted reaction (UTF-8 emoji cluster).
  dmReaction(0x03),

  /// Phase 2+: encrypted MRRP RPC envelope.
  rpcEnvelope(0x04);

  const OverlaySecureDataSubtype(this.code);

  /// Wire code for this subtype.
  final int code;

  /// Resolve a wire code to a subtype, or null if unknown/reserved.
  static OverlaySecureDataSubtype? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// MRRP v0.2 link frame flags (byte 5).
///
/// Bits 0-2 are v0.2-specific. Bits 3-7 are reserved and MUST be zero
/// on the wire.
abstract final class OverlayLinkFlags {
  /// When set, the 20-byte MRRP header is extended with the 8-byte
  /// v0.2 link tuple (linkId, seq, ackHi). When clear, the frame is
  /// wire-identical to MRRP v0.1.
  static const int linkFrame = 1 << 0;

  /// Sender wants the receiver to ACK this frame.
  static const int ackRequired = 1 << 1;

  /// This frame is a response to a prior request.
  static const int isResponse = 1 << 2;

  /// Mask of bits this version defines.
  static const int definedMask = 0x07;

  /// Mask of bits that must be zero on the wire.
  static const int reservedMask = 0xF8;
}

/// Close / decline reasons carried as a single payload byte in
/// `LINK_OPEN_NO` and `LINK_CLOSE`.
enum OverlayLinkCloseReason {
  /// Normal, graceful close initiated by local side.
  normal(0x00),

  /// Responder is busy (too many active links).
  busy(0x01),

  /// Responder does not support v0.2 overlay features.
  unsupported(0x02),

  /// User declined the link open prompt.
  declined(0x03),

  /// Handshake or link open timed out.
  timeout(0x04),

  /// Signature verification failed.
  authFailure(0x05),

  /// Peer exceeded per-peer airtime budget.
  rateLimited(0x06),

  /// Feature flag `OVERLAY_LINK_ENABLED` was disabled at runtime.
  featureDisabled(0x07),

  /// Counterpart reports an internal error.
  internal(0x08),

  /// Duplicate link id collision.
  collision(0x09);

  const OverlayLinkCloseReason(this.code);

  /// Wire code for this reason.
  final int code;

  /// Resolve a wire code to a reason, or null if unknown.
  static OverlayLinkCloseReason? fromCode(int code) {
    for (final reason in values) {
      if (reason.code == code) return reason;
    }
    return null;
  }
}

/// Link lifecycle states (§10.3).
///
/// Persisted to `links.db`. Numeric codes are frozen.
enum OverlayLinkState {
  /// No link row exists yet.
  idle(0x00),

  /// Initiator sent `LINK_OPEN`, awaiting `LINK_OPEN_OK`.
  opening(0x01),

  /// Link is active; data may flow.
  active(0x02),

  /// No traffic observed for `STALE_THRESHOLD`; refresh ping needed.
  stale(0x03),

  /// Close initiated locally or remotely; flushing in-flight frames.
  draining(0x04),

  /// Link is closed.
  closed(0x05),

  /// Link failed before reaching `active`.
  failed(0x06);

  const OverlayLinkState(this.code);

  /// Wire / DB code for this state.
  final int code;

  /// Resolve a code to a state, or null if unknown.
  static OverlayLinkState? fromCode(int code) {
    for (final state in values) {
      if (state.code == code) return state;
    }
    return null;
  }
}

/// Resource transfer lifecycle states (§11.5).
///
/// Persisted to `transfers.db`. Numeric codes are frozen.
enum OverlayResourceState {
  /// Sender: nothing queued yet. Receiver: nothing offered yet.
  idle(0x00),

  /// Sender: `OFFER` dispatched, awaiting `ACCEPT`/`DECLINE`.
  offering(0x01),

  /// Sender: offer accepted, about to begin chunking.
  negotiating(0x02),

  /// Sender: chunks in flight.
  transferring(0x03),

  /// Sender: all chunks sent, awaiting `VERIFIED`.
  awaitingVerify(0x04),

  /// Receiver: `OFFER` received, awaiting user / policy accept.
  evaluating(0x05),

  /// Receiver: `ACCEPT` sent, ready to receive.
  accepting(0x06),

  /// Receiver: chunks being assembled.
  receiving(0x07),

  /// Receiver: fast-path SHA-256 verification in progress (in-memory only).
  verifying(0x08),

  /// Terminal: success.
  complete(0x09),

  /// Terminal: giving up after retries.
  failed(0x0A),

  /// Terminal: either side aborted.
  cancelled(0x0B),

  /// Terminal: `DECLINE` was received or sent.
  declined(0x0C),

  /// Terminal: integrity check failed.
  corrupt(0x0D);

  const OverlayResourceState(this.code);

  /// Wire / DB code for this state.
  final int code;

  /// Resolve a code to a state, or null if unknown.
  static OverlayResourceState? fromCode(int code) {
    for (final state in values) {
      if (state.code == code) return state;
    }
    return null;
  }
}

/// Capability TLV type codes for the overlay announcement inside
/// `CAP_BEACON` and `ID_CLAIM` frames.
enum OverlayCapabilityTlvType {
  /// `supported_features` uint32 bitset (`OverlayCapabilityFeature`).
  supportedFeatures(0x10),

  /// `overlay_max_chunk_bytes` uint16 — advertised per-chunk payload
  /// ceiling the peer will accept.
  maxChunkBytes(0x11),

  /// `overlay_max_resource_bytes` uint32 — advertised resource cap.
  maxResourceBytes(0x12);

  const OverlayCapabilityTlvType(this.code);

  /// Wire TLV type byte.
  final int code;

  /// Resolve a code to a TLV type, or null if unknown.
  static OverlayCapabilityTlvType? fromCode(int code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

/// Capability bits advertised via [OverlayCapabilityTlvType.supportedFeatures].
abstract final class OverlayCapabilityFeature {
  /// Peer supports MRRP v0.2 link frames.
  static const int linkV02 = 1 << 0;

  /// Peer supports SPP v0.2 resource transfer.
  static const int resourceV02 = 1 << 1;

  /// Peer supports `OVERLAY_SECURE_ENABLED` envelope (§12) — reserved
  /// for v0.3.
  static const int secureV03 = 1 << 2;

  /// Mask of bits this version defines.
  static const int definedMask = linkV02 | resourceV02 | secureV03;
}
