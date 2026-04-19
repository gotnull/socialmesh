// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP-1 handshake message payload encode/decode.
///
/// Handles HS_HELLO, HS_CHALLENGE, HS_RESPONSE, and HS_ACCEPT
/// payload serialization for the consent-first handshake flow.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../../core/logging.dart';

/// Decoded HS_HELLO payload.
class SipHsHello {
  /// 16-byte client nonce.
  final Uint8List clientNonce;

  /// 32-byte ephemeral public key (Ed25519 or X25519, depending on implementation).
  final Uint8List clientEphemeralPub;

  /// Requested feature mask.
  final int requestedFeatures;

  const SipHsHello({
    required this.clientNonce,
    required this.clientEphemeralPub,
    required this.requestedFeatures,
  });
}

/// Decoded HS_CHALLENGE payload.
class SipHsChallenge {
  /// 16-byte server nonce.
  final Uint8List serverNonce;

  /// 16-byte echoed client nonce.
  final Uint8List echoedClientNonce;

  /// 32-byte server ephemeral public key.
  final Uint8List serverEphemeralPub;

  /// Session expiry in seconds from now.
  final int expiresInS;

  const SipHsChallenge({
    required this.serverNonce,
    required this.echoedClientNonce,
    required this.serverEphemeralPub,
    required this.expiresInS,
  });
}

/// Decoded HS_RESPONSE payload.
class SipHsResponse {
  /// 16-byte echoed server nonce.
  final Uint8List echoedServerNonce;

  /// 16-byte echoed client nonce.
  final Uint8List echoedClientNonce;

  /// 4-byte session tag derived from both nonces.
  final int sessionTag;

  const SipHsResponse({
    required this.echoedServerNonce,
    required this.echoedClientNonce,
    required this.sessionTag,
  });
}

/// Decoded HS_DECLINE payload.
///
/// Wire format: echoed_client_nonce(16) + reason(1) = 17 bytes.
class SipHsDecline {
  /// 16-byte client nonce echoed from the original HS_HELLO, for correlation.
  final Uint8List echoedClientNonce;

  /// Decline reason: 0x00 = user declined, 0x01 = busy, 0xFF = unspecified.
  final int reason;

  const SipHsDecline({required this.echoedClientNonce, required this.reason});
}

/// Decoded HS_ACCEPT payload.
class SipHsAccept {
  /// 4-byte session tag.
  final int sessionTag;

  /// DM TTL in seconds (default 86400).
  final int dmTtlS;

  /// Accept flags.
  final int flags;

  const SipHsAccept({
    required this.sessionTag,
    required this.dmTtlS,
    required this.flags,
  });
}

/// Encode/decode SIP-1 handshake message payloads.
abstract final class SipHsMessages {
  // ---------------------------------------------------------------------------
  // HS_HELLO: client_nonce(16) + client_ephemeral_pub(32) + features(2) = 50
  // ---------------------------------------------------------------------------

  /// Encode an HS_HELLO payload (50 bytes).
  static Uint8List encodeHello(SipHsHello hello) {
    final data = Uint8List(50);
    data.setRange(0, 16, hello.clientNonce);
    data.setRange(16, 48, hello.clientEphemeralPub);
    final bd = ByteData.sublistView(data);
    bd.setUint16(48, hello.requestedFeatures, Endian.little);
    return data;
  }

  /// Decode an HS_HELLO payload. Returns null on invalid data.
  static SipHsHello? decodeHello(Uint8List payload) {
    if (payload.length < 50) {
      AppLogging.sip(
        'SIP_HS: HS_HELLO decode failed: payload too short '
        '(${payload.length} < 50)',
      );
      return null;
    }
    final bd = ByteData.sublistView(payload);
    return SipHsHello(
      clientNonce: Uint8List.fromList(payload.sublist(0, 16)),
      clientEphemeralPub: Uint8List.fromList(payload.sublist(16, 48)),
      requestedFeatures: bd.getUint16(48, Endian.little),
    );
  }

  // ---------------------------------------------------------------------------
  // HS_CHALLENGE: server_nonce(16) + echoed_client_nonce(16) +
  //               server_ephemeral_pub(32) + expires_in_s(4) = 68
  // ---------------------------------------------------------------------------

  /// Encode an HS_CHALLENGE payload (68 bytes).
  static Uint8List encodeChallenge(SipHsChallenge challenge) {
    final data = Uint8List(68);
    data.setRange(0, 16, challenge.serverNonce);
    data.setRange(16, 32, challenge.echoedClientNonce);
    data.setRange(32, 64, challenge.serverEphemeralPub);
    final bd = ByteData.sublistView(data);
    bd.setUint32(64, challenge.expiresInS, Endian.little);
    return data;
  }

  /// Decode an HS_CHALLENGE payload. Returns null on invalid data.
  static SipHsChallenge? decodeChallenge(Uint8List payload) {
    if (payload.length < 68) {
      AppLogging.sip(
        'SIP_HS: HS_CHALLENGE decode failed: payload too short '
        '(${payload.length} < 68)',
      );
      return null;
    }
    final bd = ByteData.sublistView(payload);
    return SipHsChallenge(
      serverNonce: Uint8List.fromList(payload.sublist(0, 16)),
      echoedClientNonce: Uint8List.fromList(payload.sublist(16, 32)),
      serverEphemeralPub: Uint8List.fromList(payload.sublist(32, 64)),
      expiresInS: bd.getUint32(64, Endian.little),
    );
  }

  // ---------------------------------------------------------------------------
  // HS_RESPONSE: echoed_server_nonce(16) + echoed_client_nonce(16) +
  //              session_tag(4) = 36
  // ---------------------------------------------------------------------------

  /// Encode an HS_RESPONSE payload (36 bytes).
  static Uint8List encodeResponse(SipHsResponse response) {
    final data = Uint8List(36);
    data.setRange(0, 16, response.echoedServerNonce);
    data.setRange(16, 32, response.echoedClientNonce);
    final bd = ByteData.sublistView(data);
    bd.setUint32(32, response.sessionTag, Endian.little);
    return data;
  }

  /// Decode an HS_RESPONSE payload. Returns null on invalid data.
  static SipHsResponse? decodeResponse(Uint8List payload) {
    if (payload.length < 36) {
      AppLogging.sip(
        'SIP_HS: HS_RESPONSE decode failed: payload too short '
        '(${payload.length} < 36)',
      );
      return null;
    }
    final bd = ByteData.sublistView(payload);
    return SipHsResponse(
      echoedServerNonce: Uint8List.fromList(payload.sublist(0, 16)),
      echoedClientNonce: Uint8List.fromList(payload.sublist(16, 32)),
      sessionTag: bd.getUint32(32, Endian.little),
    );
  }

  // ---------------------------------------------------------------------------
  // HS_ACCEPT: session_tag(4) + dm_ttl_s(4) + flags(1) = 9
  // ---------------------------------------------------------------------------

  /// Encode an HS_ACCEPT payload (9 bytes).
  static Uint8List encodeAccept(SipHsAccept accept) {
    final data = ByteData(9);
    data.setUint32(0, accept.sessionTag, Endian.little);
    data.setUint32(4, accept.dmTtlS, Endian.little);
    data.setUint8(8, accept.flags);
    return data.buffer.asUint8List();
  }

  /// Decode an HS_ACCEPT payload. Returns null on invalid data.
  static SipHsAccept? decodeAccept(Uint8List payload) {
    if (payload.length < 9) {
      AppLogging.sip(
        'SIP_HS: HS_ACCEPT decode failed: payload too short '
        '(${payload.length} < 9)',
      );
      return null;
    }
    final bd = ByteData.sublistView(payload);
    return SipHsAccept(
      sessionTag: bd.getUint32(0, Endian.little),
      dmTtlS: bd.getUint32(4, Endian.little),
      flags: bd.getUint8(8),
    );
  }

  // ---------------------------------------------------------------------------
  // HS_DECLINE: echoed_client_nonce(16) + reason(1) = 17
  // ---------------------------------------------------------------------------

  /// Encode an HS_DECLINE payload (17 bytes).
  static Uint8List encodeDecline(SipHsDecline decline) {
    final data = Uint8List(17);
    data.setRange(0, 16, decline.echoedClientNonce);
    data[16] = decline.reason;
    return data;
  }

  /// Decode an HS_DECLINE payload. Returns null on invalid data.
  static SipHsDecline? decodeDecline(Uint8List payload) {
    if (payload.length < 17) {
      AppLogging.sip(
        'SIP_HS: HS_DECLINE decode failed: payload too short '
        '(${payload.length} < 17)',
      );
      return null;
    }
    return SipHsDecline(
      echoedClientNonce: Uint8List.fromList(payload.sublist(0, 16)),
      reason: payload[16],
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
