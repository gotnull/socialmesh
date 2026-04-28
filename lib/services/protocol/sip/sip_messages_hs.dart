// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// SIP-1 handshake message payload encode/decode (SIP v0.2).
//
// Wire format: every handshake payload begins with a u32
// little-endian `target_node_id`. The receiver MUST drop a frame
// whose target does not match its local nodeId before any consent
// UI, notification, or session state mutation runs. The sender MUST
// stamp the field with the intended peer's nodeId; the broadcast
// sentinel `0xFFFFFFFF` is forbidden for HS_* frames (a handshake
// is always directed at a specific peer). This is enforced at
// encode time so a buggy caller crashes in debug rather than
// silently leaking consent prompts in production.
//
// Spec: docs/sip/SIP_V0_2_TARGET_NODE_ID_PLAN.md §3.

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../../core/logging.dart';
import 'sip_constants.dart';

// ---------------------------------------------------------------------------
// Payload sizes (v0.2)
// ---------------------------------------------------------------------------

/// HS_HELLO payload: target_node_id(4) + client_nonce(16) +
/// client_ephemeral_pub(32) + requested_features(2) = 54 bytes.
const int kSipHsHelloLen = 54;

/// HS_CHALLENGE payload: target_node_id(4) + server_nonce(16) +
/// echoed_client_nonce(16) + server_ephemeral_pub(32) +
/// expires_in_s(4) = 72 bytes.
const int kSipHsChallengeLen = 72;

/// HS_RESPONSE payload: target_node_id(4) + echoed_server_nonce(16) +
/// echoed_client_nonce(16) + session_tag(4) = 40 bytes.
const int kSipHsResponseLen = 40;

/// HS_ACCEPT payload: target_node_id(4) + session_tag(4) +
/// dm_ttl_s(4) + flags(1) = 13 bytes.
const int kSipHsAcceptLen = 13;

/// HS_DECLINE payload: target_node_id(4) + echoed_client_nonce(16) +
/// reason(1) = 21 bytes.
const int kSipHsDeclineLen = 21;

/// Decoded HS_HELLO payload.
class SipHsHello {
  /// Intended recipient's u32 nodeId. v0.2 receivers drop the frame
  /// before any state mutation if this does not match `_myNodeNum`.
  final int targetNodeId;

  /// 16-byte client nonce.
  final Uint8List clientNonce;

  /// 32-byte ephemeral public key (Ed25519 or X25519, depending on implementation).
  final Uint8List clientEphemeralPub;

  /// Requested feature mask.
  final int requestedFeatures;

  const SipHsHello({
    required this.targetNodeId,
    required this.clientNonce,
    required this.clientEphemeralPub,
    required this.requestedFeatures,
  });
}

/// Decoded HS_CHALLENGE payload.
class SipHsChallenge {
  /// Intended recipient's u32 nodeId (the original initiator).
  final int targetNodeId;

  /// 16-byte server nonce.
  final Uint8List serverNonce;

  /// 16-byte echoed client nonce.
  final Uint8List echoedClientNonce;

  /// 32-byte server ephemeral public key.
  final Uint8List serverEphemeralPub;

  /// Session expiry in seconds from now.
  final int expiresInS;

  const SipHsChallenge({
    required this.targetNodeId,
    required this.serverNonce,
    required this.echoedClientNonce,
    required this.serverEphemeralPub,
    required this.expiresInS,
  });
}

/// Decoded HS_RESPONSE payload.
class SipHsResponse {
  /// Intended recipient's u32 nodeId (the original responder).
  final int targetNodeId;

  /// 16-byte echoed server nonce.
  final Uint8List echoedServerNonce;

  /// 16-byte echoed client nonce.
  final Uint8List echoedClientNonce;

  /// 4-byte session tag derived from both nonces.
  final int sessionTag;

  const SipHsResponse({
    required this.targetNodeId,
    required this.echoedServerNonce,
    required this.echoedClientNonce,
    required this.sessionTag,
  });
}

/// Decoded HS_DECLINE payload.
///
/// Wire format (v0.2): target_node_id(4) + echoed_client_nonce(16) +
/// reason(1) = 21 bytes.
class SipHsDecline {
  /// Intended recipient's u32 nodeId (the original initiator).
  final int targetNodeId;

  /// 16-byte client nonce echoed from the original HS_HELLO, for correlation.
  final Uint8List echoedClientNonce;

  /// Decline reason: 0x00 = user declined, 0x01 = busy, 0xFF = unspecified.
  final int reason;

  const SipHsDecline({
    required this.targetNodeId,
    required this.echoedClientNonce,
    required this.reason,
  });
}

/// Decoded HS_ACCEPT payload.
class SipHsAccept {
  /// Intended recipient's u32 nodeId (the original initiator).
  final int targetNodeId;

  /// 4-byte session tag.
  final int sessionTag;

  /// DM TTL in seconds (default 86400).
  final int dmTtlS;

  /// Accept flags.
  final int flags;

  const SipHsAccept({
    required this.targetNodeId,
    required this.sessionTag,
    required this.dmTtlS,
    required this.flags,
  });
}

/// Encode/decode SIP-1 handshake message payloads (SIP v0.2).
abstract final class SipHsMessages {
  /// Common encode-time guard: HS_* frames are always directed.
  /// `0xFFFFFFFF` is reserved as a sentinel and MUST NOT appear on
  /// the wire as a handshake target. Throws in debug, returns null
  /// in release. Callers MUST handle the null return.
  static bool _validTarget(int targetNodeId, String which) {
    if (targetNodeId == SipConstants.sipTargetNodeIdBroadcast) {
      assert(
        false,
        'SipHsMessages.encode$which: target_node_id MUST NOT be '
        '0xFFFFFFFF (handshakes are always directed)',
      );
      AppLogging.sip(
        'SIP_HS: encode${which.toUpperCase()} REJECTED: '
        'target_node_id=0xFFFFFFFF is invalid for HS_* frames',
      );
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // HS_HELLO: target_node_id(4) + client_nonce(16) +
  //           client_ephemeral_pub(32) + features(2) = 54
  // ---------------------------------------------------------------------------

  /// Encode an HS_HELLO payload (54 bytes). Returns null if
  /// [SipHsHello.targetNodeId] is the broadcast sentinel.
  static Uint8List? encodeHello(SipHsHello hello) {
    if (!_validTarget(hello.targetNodeId, 'Hello')) return null;
    final data = Uint8List(kSipHsHelloLen);
    final bd = ByteData.sublistView(data);
    bd.setUint32(0, hello.targetNodeId, Endian.little);
    data.setRange(4, 20, hello.clientNonce);
    data.setRange(20, 52, hello.clientEphemeralPub);
    bd.setUint16(52, hello.requestedFeatures, Endian.little);
    return data;
  }

  /// Decode an HS_HELLO payload. Returns null on invalid data.
  static SipHsHello? decodeHello(Uint8List payload) {
    if (payload.length < kSipHsHelloLen) {
      AppLogging.sip(
        'SIP_HS: HS_HELLO decode failed: payload too short '
        '(${payload.length} < $kSipHsHelloLen)',
      );
      return null;
    }
    final bd = ByteData.sublistView(payload);
    return SipHsHello(
      targetNodeId: bd.getUint32(0, Endian.little),
      clientNonce: Uint8List.fromList(payload.sublist(4, 20)),
      clientEphemeralPub: Uint8List.fromList(payload.sublist(20, 52)),
      requestedFeatures: bd.getUint16(52, Endian.little),
    );
  }

  // ---------------------------------------------------------------------------
  // HS_CHALLENGE: target_node_id(4) + server_nonce(16) +
  //               echoed_client_nonce(16) + server_ephemeral_pub(32) +
  //               expires_in_s(4) = 72
  // ---------------------------------------------------------------------------

  /// Encode an HS_CHALLENGE payload (72 bytes). Returns null if the
  /// target is the broadcast sentinel.
  static Uint8List? encodeChallenge(SipHsChallenge challenge) {
    if (!_validTarget(challenge.targetNodeId, 'Challenge')) return null;
    final data = Uint8List(kSipHsChallengeLen);
    final bd = ByteData.sublistView(data);
    bd.setUint32(0, challenge.targetNodeId, Endian.little);
    data.setRange(4, 20, challenge.serverNonce);
    data.setRange(20, 36, challenge.echoedClientNonce);
    data.setRange(36, 68, challenge.serverEphemeralPub);
    bd.setUint32(68, challenge.expiresInS, Endian.little);
    return data;
  }

  /// Decode an HS_CHALLENGE payload. Returns null on invalid data.
  static SipHsChallenge? decodeChallenge(Uint8List payload) {
    if (payload.length < kSipHsChallengeLen) {
      AppLogging.sip(
        'SIP_HS: HS_CHALLENGE decode failed: payload too short '
        '(${payload.length} < $kSipHsChallengeLen)',
      );
      return null;
    }
    final bd = ByteData.sublistView(payload);
    return SipHsChallenge(
      targetNodeId: bd.getUint32(0, Endian.little),
      serverNonce: Uint8List.fromList(payload.sublist(4, 20)),
      echoedClientNonce: Uint8List.fromList(payload.sublist(20, 36)),
      serverEphemeralPub: Uint8List.fromList(payload.sublist(36, 68)),
      expiresInS: bd.getUint32(68, Endian.little),
    );
  }

  // ---------------------------------------------------------------------------
  // HS_RESPONSE: target_node_id(4) + echoed_server_nonce(16) +
  //              echoed_client_nonce(16) + session_tag(4) = 40
  // ---------------------------------------------------------------------------

  /// Encode an HS_RESPONSE payload (40 bytes). Returns null if the
  /// target is the broadcast sentinel.
  static Uint8List? encodeResponse(SipHsResponse response) {
    if (!_validTarget(response.targetNodeId, 'Response')) return null;
    final data = Uint8List(kSipHsResponseLen);
    final bd = ByteData.sublistView(data);
    bd.setUint32(0, response.targetNodeId, Endian.little);
    data.setRange(4, 20, response.echoedServerNonce);
    data.setRange(20, 36, response.echoedClientNonce);
    bd.setUint32(36, response.sessionTag, Endian.little);
    return data;
  }

  /// Decode an HS_RESPONSE payload. Returns null on invalid data.
  static SipHsResponse? decodeResponse(Uint8List payload) {
    if (payload.length < kSipHsResponseLen) {
      AppLogging.sip(
        'SIP_HS: HS_RESPONSE decode failed: payload too short '
        '(${payload.length} < $kSipHsResponseLen)',
      );
      return null;
    }
    final bd = ByteData.sublistView(payload);
    return SipHsResponse(
      targetNodeId: bd.getUint32(0, Endian.little),
      echoedServerNonce: Uint8List.fromList(payload.sublist(4, 20)),
      echoedClientNonce: Uint8List.fromList(payload.sublist(20, 36)),
      sessionTag: bd.getUint32(36, Endian.little),
    );
  }

  // ---------------------------------------------------------------------------
  // HS_ACCEPT: target_node_id(4) + session_tag(4) + dm_ttl_s(4) +
  //            flags(1) = 13
  // ---------------------------------------------------------------------------

  /// Encode an HS_ACCEPT payload (13 bytes). Returns null if the
  /// target is the broadcast sentinel.
  static Uint8List? encodeAccept(SipHsAccept accept) {
    if (!_validTarget(accept.targetNodeId, 'Accept')) return null;
    final data = ByteData(kSipHsAcceptLen);
    data.setUint32(0, accept.targetNodeId, Endian.little);
    data.setUint32(4, accept.sessionTag, Endian.little);
    data.setUint32(8, accept.dmTtlS, Endian.little);
    data.setUint8(12, accept.flags);
    return data.buffer.asUint8List();
  }

  /// Decode an HS_ACCEPT payload. Returns null on invalid data.
  static SipHsAccept? decodeAccept(Uint8List payload) {
    if (payload.length < kSipHsAcceptLen) {
      AppLogging.sip(
        'SIP_HS: HS_ACCEPT decode failed: payload too short '
        '(${payload.length} < $kSipHsAcceptLen)',
      );
      return null;
    }
    final bd = ByteData.sublistView(payload);
    return SipHsAccept(
      targetNodeId: bd.getUint32(0, Endian.little),
      sessionTag: bd.getUint32(4, Endian.little),
      dmTtlS: bd.getUint32(8, Endian.little),
      flags: bd.getUint8(12),
    );
  }

  // ---------------------------------------------------------------------------
  // HS_DECLINE: target_node_id(4) + echoed_client_nonce(16) +
  //             reason(1) = 21
  // ---------------------------------------------------------------------------

  /// Encode an HS_DECLINE payload (21 bytes). Returns null if the
  /// target is the broadcast sentinel.
  static Uint8List? encodeDecline(SipHsDecline decline) {
    if (!_validTarget(decline.targetNodeId, 'Decline')) return null;
    final data = Uint8List(kSipHsDeclineLen);
    final bd = ByteData.sublistView(data);
    bd.setUint32(0, decline.targetNodeId, Endian.little);
    data.setRange(4, 20, decline.echoedClientNonce);
    data[20] = decline.reason;
    return data;
  }

  /// Decode an HS_DECLINE payload. Returns null on invalid data.
  static SipHsDecline? decodeDecline(Uint8List payload) {
    if (payload.length < kSipHsDeclineLen) {
      AppLogging.sip(
        'SIP_HS: HS_DECLINE decode failed: payload too short '
        '(${payload.length} < $kSipHsDeclineLen)',
      );
      return null;
    }
    final bd = ByteData.sublistView(payload);
    return SipHsDecline(
      targetNodeId: bd.getUint32(0, Endian.little),
      echoedClientNonce: Uint8List.fromList(payload.sublist(4, 20)),
      reason: payload[20],
    );
  }

  // ---------------------------------------------------------------------------
  // Session tag derivation
  // ---------------------------------------------------------------------------

  /// Derive a deterministic session_tag from client and server nonces.
  ///
  /// session_tag = first 4 bytes of SHA-256(client_nonce || server_nonce).
  static Future<int> deriveSessionTag(
    Uint8List clientNonce,
    Uint8List serverNonce,
  ) async {
    final combined = Uint8List(clientNonce.length + serverNonce.length);
    combined.setRange(0, clientNonce.length, clientNonce);
    combined.setRange(clientNonce.length, combined.length, serverNonce);
    final sha256 = Sha256();
    final hash = await sha256.hash(combined);
    final bd = ByteData.sublistView(Uint8List.fromList(hash.bytes));
    return bd.getUint32(0, Endian.little);
  }
}
