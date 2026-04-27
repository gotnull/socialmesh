// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP message types, flags, error codes, and TLV type definitions.
///
/// These enums and constants define the wire-level protocol vocabulary
/// for the Socialmesh Interop Profile v0.1.
library;

/// SIP message type codes (byte 4 of the frame header).
enum SipMessageType {
  // SIP-0: Capability Discovery
  capBeacon(0x01),
  capReq(0x02),
  capResp(0x03),
  rollcallReq(0x04),
  rollcallResp(0x05),

  // SIP-1: Identity & Handshake
  idReq(0x10),
  idClaim(0x11),
  idResp(0x12),
  hsHello(0x13),
  hsChallenge(0x14),
  hsResponse(0x15),
  hsAccept(0x16),
  hsDecline(0x17),

  // SIP-3: Micro-Exchange
  txStart(0x30),
  txChunk(0x31),
  txAck(0x32),
  txNack(0x33),
  txDone(0x34),
  txCancel(0x35),

  // Ephemeral DM
  dmMsg(0x40),
  dmTyping(0x41),
  dmReaction(0x42),
  dmDelete(0x43),
  dmClose(0x44),
  dmInk(0x45),
  dmPlay(0x46),
  dmSignal(0x47),

  // MRRP (Mesh Request/Response Protocol)
  mrrpData(0x50),

  // Error
  error(0x7E);

  const SipMessageType(this.code);
  final int code;

  /// Look up a message type by its wire code. Returns null if unknown.
  static SipMessageType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// SIP frame flags bitfield (byte 5 of the frame header).
abstract final class SipFlags {
  /// Payload includes a trailing Ed25519 signature (66 bytes).
  static const int hasSignature = 1 << 0;

  /// Header extensions present (header_len > 22).
  static const int hasHeaderExt = 1 << 1;

  /// Sender expects an acknowledgement.
  static const int ackRequired = 1 << 2;

  /// This frame is a response to a previous request.
  static const int isResponse = 1 << 3;

  /// Mask for defined flag bits (bits 0-3).
  static const int definedMask = 0x0F;

  /// Mask for reserved flag bits (bits 4-7). Must be 0.
  static const int reservedMask = 0xF0;
}

/// TLV header extension type codes.
enum SipTlvType {
  /// First 8 bytes of the sender's Ed25519 public key.
  senderPubkeyHint(0x01);

  const SipTlvType(this.code);
  final int code;

  /// Look up a TLV type by its wire code. Returns null if unknown.
  static SipTlvType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// SIP error codes (first byte of ERROR frame payload).
enum SipErrorCode {
  unsupportedVersion(0x01),
  mtuExceeded(0x02),
  invalidFrame(0x03),
  signatureFailed(0x04),
  sessionUnknown(0x05),
  rateLimited(0x06),
  transferRejected(0x07),
  integrityFailed(0x08);

  const SipErrorCode(this.code);
  final int code;

  /// Look up an error code by its wire code. Returns null if unknown.
  static SipErrorCode? fromCode(int code) {
    for (final e in values) {
      if (e.code == code) return e;
    }
    return null;
  }
}

/// Ed25519 signature type constant.
const int sipSigTypeEd25519 = 1;

/// Ed25519 signature length in bytes.
const int sipSigLenEd25519 = 64;

/// SIP feature bitmap bits for capability advertisement.
abstract final class SipFeatureBits {
  /// SIP-0 discovery supported.
  static const int sip0 = 1 << 0;

  /// SIP-1 identity/handshake supported.
  static const int sip1 = 1 << 1;

  /// SIP-3 micro-exchange supported.
  static const int sip3 = 1 << 3;

  /// Overlay v0.2 link layer supported. When set, peer can accept
  /// `LINK_OPEN` and participate in the signed-identity session.
  static const int overlayLinkV02 = 1 << 8;

  /// Overlay v0.2 resource transfer (SPP v0.2) supported. Requires
  /// [overlayLinkV02]; peers advertise both together or neither.
  static const int overlayResourceV02 = 1 << 9;

  /// Reserved for overlay v0.3 secure envelope. Never set today.
  static const int overlaySecureV03 = 1 << 10;

  /// SIP Ink v1 sketch DM frames (DM_INK / 0x45) supported. Builds
  /// without this bit drop unknown 0x45 frames silently. Senders MUST
  /// gate `dmInk` transmission on the peer advertising this bit.
  /// See `docs/sip/SIP_V0_1.md` §6 "DM_INK (v0.2 amendment)".
  static const int dmInkV1 = 1 << 11;

  /// SIP Play v1 turn-based mini-game frames (DM_PLAY / 0x46)
  /// supported. Carries a compact binary game-action envelope
  /// inside an existing accepted SIP DM session. Builds without
  /// this bit drop unknown 0x46 frames silently. Senders MUST gate
  /// `dmPlay` transmission on the peer advertising this bit. The
  /// game catalogue is local-only — adding a new game does not
  /// bump this bit; an unsupported `gameType` value is rendered as
  /// a safe unsupported fallback by the receiver.
  static const int dmPlayV1 = 1 << 12;

  /// SIP Signal v1 musical-phrase + Morse signal frames
  /// (DM_SIGNAL / 0x47) supported. Carries a compact binary phrase
  /// or Morse envelope; the receiver synthesizes the actual audio
  /// locally — NO audio samples are ever placed on the wire.
  /// Builds without this bit drop unknown 0x47 frames silently.
  /// Senders MUST gate `dmSignal` transmission on the peer
  /// advertising this bit.
  static const int dmSignalV1 = 1 << 13;

  /// All features in v0.1.
  static const int allV01 = sip0 | sip1 | sip3; // 0x000B
}

/// Identity verification states for SIP peers.
enum SipIdentityState {
  /// Node seen but no verified identity claim.
  unverified,

  /// First verified claim accepted on trust-on-first-use.
  verifiedTofu,

  /// User explicitly pinned this identity.
  pinned,

  /// Node ID presented a different pubkey than previously stored.
  changedKey,

  /// Identity claim TTL expired.
  stale,
}

/// SIP-3 transfer cancel reason codes.
enum SipCancelReason {
  userCancel(0x01),
  budgetExhausted(0x02),
  timeout(0x03),
  error(0x04);

  const SipCancelReason(this.code);
  final int code;

  static SipCancelReason? fromCode(int code) {
    for (final r in values) {
      if (r.code == code) return r;
    }
    return null;
  }
}
