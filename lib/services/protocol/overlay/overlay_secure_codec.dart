// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Wire-format encoder/decoder for overlay v0.3 secure-session frames.
///
/// See `docs/sip/OVERLAY_V0_2.md §25` for the authoritative byte-level
/// spec. This file is the single source of truth for the codec; every
/// constant lives next to its field.
///
/// Layouts (all big-endian):
///
/// ```
/// LINK_SECURE_INIT (121 B, msg_type 0x28)
///   0      version              u8    (0x01)
///   1      init_endpoint_id     8 B
///   9      init_x25519_pub      32 B
///   41     nonce_i              16 B
///   57     signature_ed25519    64 B   (over transcript_init)
///
/// LINK_SECURE_ACK (121 B, msg_type 0x29)
///   0      version              u8    (0x01, echo)
///   1      resp_endpoint_id     8 B
///   9      resp_x25519_pub      32 B
///   41     nonce_r              16 B
///   57     signature_ed25519    64 B   (over transcript_full)
///
/// LINK_SECURE_DATA (21 B + ciphertext, msg_type 0x2A)
///   0      subtype              u8    (0x01=generic, 0x02=dm_text, ...)
///   1      seq                  u32   (per-direction counter)
///   5      aead_tag             16 B
///   21     ciphertext           variable
/// ```
library;

import 'dart:typed_data';

import 'overlay_types.dart';

/// Current wire schema version for v0.3 secure frames. Bumped if the
/// layouts above change.
const int overlaySecureSchemaVersion = 0x01;

/// Width of an overlay endpoint ID (bytes).
const int _endpointIdLen = 8;

/// Width of an X25519 public key (bytes).
const int _x25519PubLen = 32;

/// Width of a handshake nonce (bytes).
const int _handshakeNonceLen = 16;

/// Width of an Ed25519 signature (bytes).
const int _ed25519SigLen = 64;

/// Width of a ChaCha20-Poly1305 tag (bytes).
const int _aeadTagLen = 16;

/// Fixed payload size for [OverlayLinkMsgType.linkSecureInit] and
/// [OverlayLinkMsgType.linkSecureAck]. Both have the same shape.
const int overlaySecureHandshakePayloadLen =
    1 + _endpointIdLen + _x25519PubLen + _handshakeNonceLen + _ed25519SigLen;

/// Fixed header size for [OverlayLinkMsgType.linkSecureData] (subtype
/// + seq + tag). Ciphertext appends after this.
const int overlaySecureDataHeaderLen = 1 + 4 + _aeadTagLen;

/// Decoded [OverlayLinkMsgType.linkSecureInit] payload.
class OverlaySecureInit {
  final int version;
  final Uint8List initEndpointId;
  final Uint8List initX25519Pub;
  final Uint8List nonceI;
  final Uint8List signature;

  const OverlaySecureInit({
    required this.version,
    required this.initEndpointId,
    required this.initX25519Pub,
    required this.nonceI,
    required this.signature,
  });
}

/// Decoded [OverlayLinkMsgType.linkSecureAck] payload.
class OverlaySecureAck {
  final int version;
  final Uint8List respEndpointId;
  final Uint8List respX25519Pub;
  final Uint8List nonceR;
  final Uint8List signature;

  const OverlaySecureAck({
    required this.version,
    required this.respEndpointId,
    required this.respX25519Pub,
    required this.nonceR,
    required this.signature,
  });
}

/// Decoded [OverlayLinkMsgType.linkSecureData] payload. The tag is
/// surfaced as a separate field (not concatenated into ciphertext) so
/// callers that use `package:cryptography`'s `SecretBox(Mac)` API can
/// hand the raw ciphertext in directly.
class OverlaySecureData {
  final OverlaySecureDataSubtype? subtype;
  final int rawSubtype;
  final int seq;
  final Uint8List aeadTag;
  final Uint8List ciphertext;

  const OverlaySecureData({
    required this.subtype,
    required this.rawSubtype,
    required this.seq,
    required this.aeadTag,
    required this.ciphertext,
  });
}

/// Static codec namespace.
abstract final class OverlaySecureCodec {
  // -----------------------------------------------------------------
  // Encode / decode: INIT
  // -----------------------------------------------------------------

  /// Encode a `LINK_SECURE_INIT` payload. All input widths are validated
  /// strictly; mismatched sizes throw [ArgumentError].
  static Uint8List encodeInit({
    required int version,
    required Uint8List initEndpointId,
    required Uint8List initX25519Pub,
    required Uint8List nonceI,
    required Uint8List signature,
  }) {
    _requireLen(initEndpointId, _endpointIdLen, 'initEndpointId');
    _requireLen(initX25519Pub, _x25519PubLen, 'initX25519Pub');
    _requireLen(nonceI, _handshakeNonceLen, 'nonceI');
    _requireLen(signature, _ed25519SigLen, 'signature');

    final out = Uint8List(overlaySecureHandshakePayloadLen);
    var o = 0;
    out[o++] = version & 0xFF;
    out.setRange(o, o + _endpointIdLen, initEndpointId);
    o += _endpointIdLen;
    out.setRange(o, o + _x25519PubLen, initX25519Pub);
    o += _x25519PubLen;
    out.setRange(o, o + _handshakeNonceLen, nonceI);
    o += _handshakeNonceLen;
    out.setRange(o, o + _ed25519SigLen, signature);
    return out;
  }

  /// Decode a `LINK_SECURE_INIT` payload. Returns null if length is
  /// wrong; the caller treats that as malformed and drops the frame.
  static OverlaySecureInit? decodeInit(Uint8List payload) {
    if (payload.length != overlaySecureHandshakePayloadLen) return null;
    var o = 0;
    final version = payload[o++];
    final initEndpointId = _slice(payload, o, _endpointIdLen);
    o += _endpointIdLen;
    final initX25519Pub = _slice(payload, o, _x25519PubLen);
    o += _x25519PubLen;
    final nonceI = _slice(payload, o, _handshakeNonceLen);
    o += _handshakeNonceLen;
    final signature = _slice(payload, o, _ed25519SigLen);
    return OverlaySecureInit(
      version: version,
      initEndpointId: initEndpointId,
      initX25519Pub: initX25519Pub,
      nonceI: nonceI,
      signature: signature,
    );
  }

  // -----------------------------------------------------------------
  // Encode / decode: ACK
  // -----------------------------------------------------------------

  /// Encode a `LINK_SECURE_ACK` payload. Same shape as INIT.
  static Uint8List encodeAck({
    required int version,
    required Uint8List respEndpointId,
    required Uint8List respX25519Pub,
    required Uint8List nonceR,
    required Uint8List signature,
  }) {
    _requireLen(respEndpointId, _endpointIdLen, 'respEndpointId');
    _requireLen(respX25519Pub, _x25519PubLen, 'respX25519Pub');
    _requireLen(nonceR, _handshakeNonceLen, 'nonceR');
    _requireLen(signature, _ed25519SigLen, 'signature');

    final out = Uint8List(overlaySecureHandshakePayloadLen);
    var o = 0;
    out[o++] = version & 0xFF;
    out.setRange(o, o + _endpointIdLen, respEndpointId);
    o += _endpointIdLen;
    out.setRange(o, o + _x25519PubLen, respX25519Pub);
    o += _x25519PubLen;
    out.setRange(o, o + _handshakeNonceLen, nonceR);
    o += _handshakeNonceLen;
    out.setRange(o, o + _ed25519SigLen, signature);
    return out;
  }

  /// Decode a `LINK_SECURE_ACK` payload. Returns null on length mismatch.
  static OverlaySecureAck? decodeAck(Uint8List payload) {
    if (payload.length != overlaySecureHandshakePayloadLen) return null;
    var o = 0;
    final version = payload[o++];
    final respEndpointId = _slice(payload, o, _endpointIdLen);
    o += _endpointIdLen;
    final respX25519Pub = _slice(payload, o, _x25519PubLen);
    o += _x25519PubLen;
    final nonceR = _slice(payload, o, _handshakeNonceLen);
    o += _handshakeNonceLen;
    final signature = _slice(payload, o, _ed25519SigLen);
    return OverlaySecureAck(
      version: version,
      respEndpointId: respEndpointId,
      respX25519Pub: respX25519Pub,
      nonceR: nonceR,
      signature: signature,
    );
  }

  // -----------------------------------------------------------------
  // Encode / decode: DATA
  // -----------------------------------------------------------------

  /// Encode a `LINK_SECURE_DATA` payload as `subtype ‖ seq ‖ tag ‖ ct`.
  static Uint8List encodeData({
    required int subtype,
    required int seq,
    required Uint8List aeadTag,
    required Uint8List ciphertext,
  }) {
    _requireLen(aeadTag, _aeadTagLen, 'aeadTag');
    if (seq < 0 || seq > 0xFFFFFFFF) {
      throw ArgumentError.value(seq, 'seq', 'must fit in u32');
    }
    if (subtype < 0 || subtype > 0xFF) {
      throw ArgumentError.value(subtype, 'subtype', 'must fit in u8');
    }
    final out = Uint8List(overlaySecureDataHeaderLen + ciphertext.length);
    final bd = ByteData.view(out.buffer);
    var o = 0;
    out[o++] = subtype & 0xFF;
    bd.setUint32(o, seq);
    o += 4;
    out.setRange(o, o + _aeadTagLen, aeadTag);
    o += _aeadTagLen;
    out.setRange(o, o + ciphertext.length, ciphertext);
    return out;
  }

  /// Decode a `LINK_SECURE_DATA` payload. Returns null when too short
  /// to carry the fixed header.
  static OverlaySecureData? decodeData(Uint8List payload) {
    if (payload.length < overlaySecureDataHeaderLen) return null;
    final bd = ByteData.view(payload.buffer, payload.offsetInBytes);
    var o = 0;
    final rawSubtype = payload[o];
    o += 1;
    final seq = bd.getUint32(o);
    o += 4;
    final tag = _slice(payload, o, _aeadTagLen);
    o += _aeadTagLen;
    final ct = _slice(payload, o, payload.length - o);
    return OverlaySecureData(
      subtype: OverlaySecureDataSubtype.fromCode(rawSubtype),
      rawSubtype: rawSubtype,
      seq: seq,
      aeadTag: tag,
      ciphertext: ct,
    );
  }

  // -----------------------------------------------------------------
  // Transcript construction (signed regions)
  // -----------------------------------------------------------------

  /// Build the initiator-side transcript that
  /// [OverlayLinkMsgType.linkSecureInit] signatures cover.
  ///
  /// Layout: `version ‖ 0x28 ‖ BE(linkId:4) ‖ init_ep ‖ resp_ep ‖
  /// init_x25519_pub ‖ nonce_i` = 70 B.
  static Uint8List buildTranscriptInit({
    required int version,
    required int linkId,
    required Uint8List initEndpointId,
    required Uint8List respEndpointId,
    required Uint8List initX25519Pub,
    required Uint8List nonceI,
  }) {
    _requireLen(initEndpointId, _endpointIdLen, 'initEndpointId');
    _requireLen(respEndpointId, _endpointIdLen, 'respEndpointId');
    _requireLen(initX25519Pub, _x25519PubLen, 'initX25519Pub');
    _requireLen(nonceI, _handshakeNonceLen, 'nonceI');
    final out = Uint8List(
      2 + 4 + _endpointIdLen * 2 + _x25519PubLen + _handshakeNonceLen,
    );
    final bd = ByteData.view(out.buffer);
    var o = 0;
    out[o++] = version & 0xFF;
    out[o++] = OverlayLinkMsgType.linkSecureInit.code;
    bd.setUint32(o, linkId);
    o += 4;
    out.setRange(o, o + _endpointIdLen, initEndpointId);
    o += _endpointIdLen;
    out.setRange(o, o + _endpointIdLen, respEndpointId);
    o += _endpointIdLen;
    out.setRange(o, o + _x25519PubLen, initX25519Pub);
    o += _x25519PubLen;
    out.setRange(o, o + _handshakeNonceLen, nonceI);
    return out;
  }

  /// Build the full transcript that [OverlayLinkMsgType.linkSecureAck]
  /// signatures cover and that is also hashed to derive the HKDF salt.
  ///
  /// Layout: `version ‖ 0x29 ‖ BE(linkId:4) ‖ init_ep ‖ resp_ep ‖
  /// init_x25519_pub ‖ resp_x25519_pub ‖ nonce_i ‖ nonce_r` = 118 B.
  static Uint8List buildTranscriptFull({
    required int version,
    required int linkId,
    required Uint8List initEndpointId,
    required Uint8List respEndpointId,
    required Uint8List initX25519Pub,
    required Uint8List respX25519Pub,
    required Uint8List nonceI,
    required Uint8List nonceR,
  }) {
    _requireLen(initEndpointId, _endpointIdLen, 'initEndpointId');
    _requireLen(respEndpointId, _endpointIdLen, 'respEndpointId');
    _requireLen(initX25519Pub, _x25519PubLen, 'initX25519Pub');
    _requireLen(respX25519Pub, _x25519PubLen, 'respX25519Pub');
    _requireLen(nonceI, _handshakeNonceLen, 'nonceI');
    _requireLen(nonceR, _handshakeNonceLen, 'nonceR');
    final out = Uint8List(
      2 + 4 + _endpointIdLen * 2 + _x25519PubLen * 2 + _handshakeNonceLen * 2,
    );
    final bd = ByteData.view(out.buffer);
    var o = 0;
    out[o++] = version & 0xFF;
    out[o++] = OverlayLinkMsgType.linkSecureAck.code;
    bd.setUint32(o, linkId);
    o += 4;
    out.setRange(o, o + _endpointIdLen, initEndpointId);
    o += _endpointIdLen;
    out.setRange(o, o + _endpointIdLen, respEndpointId);
    o += _endpointIdLen;
    out.setRange(o, o + _x25519PubLen, initX25519Pub);
    o += _x25519PubLen;
    out.setRange(o, o + _x25519PubLen, respX25519Pub);
    o += _x25519PubLen;
    out.setRange(o, o + _handshakeNonceLen, nonceI);
    o += _handshakeNonceLen;
    out.setRange(o, o + _handshakeNonceLen, nonceR);
    return out;
  }

  // -----------------------------------------------------------------
  // AEAD nonce and AAD (shared by wrap and unwrap)
  // -----------------------------------------------------------------

  /// Build the deterministic 12-byte AEAD nonce for a DATA frame.
  ///
  /// Layout: `BE(epoch_dir:4) ‖ 0x00000000 ‖ BE(seq:4)`. The middle
  /// four reserved-zero bytes are a future expansion slot (sub-session
  /// counter / rekey index). MUST be zero in v0.3 Phase 1.
  static Uint8List buildAeadNonce({required int epochDir, required int seq}) {
    if (epochDir < 0 || epochDir > 0xFFFFFFFF) {
      throw ArgumentError.value(epochDir, 'epochDir', 'must fit in u32');
    }
    if (seq < 0 || seq > 0xFFFFFFFF) {
      throw ArgumentError.value(seq, 'seq', 'must fit in u32');
    }
    final out = Uint8List(12);
    final bd = ByteData.view(out.buffer);
    bd.setUint32(0, epochDir);
    // bytes 4..7 stay zero (reserved)
    bd.setUint32(8, seq);
    return out;
  }

  /// Build the AEAD associated-data tag bound to every DATA frame.
  ///
  /// Layout: `0x2A ‖ subtype ‖ BE(linkId:4) ‖ BE(seq:4) ‖ init_ep ‖
  /// resp_ep` = 26 B. Never transmitted on the wire; both sides
  /// reconstruct from local session state.
  static Uint8List buildAead({
    required int subtype,
    required int linkId,
    required int seq,
    required Uint8List initEndpointId,
    required Uint8List respEndpointId,
  }) {
    _requireLen(initEndpointId, _endpointIdLen, 'initEndpointId');
    _requireLen(respEndpointId, _endpointIdLen, 'respEndpointId');
    if (subtype < 0 || subtype > 0xFF) {
      throw ArgumentError.value(subtype, 'subtype', 'must fit in u8');
    }
    if (linkId < 0 || linkId > 0xFFFFFFFF) {
      throw ArgumentError.value(linkId, 'linkId', 'must fit in u32');
    }
    if (seq < 0 || seq > 0xFFFFFFFF) {
      throw ArgumentError.value(seq, 'seq', 'must fit in u32');
    }
    final out = Uint8List(1 + 1 + 4 + 4 + _endpointIdLen * 2);
    final bd = ByteData.view(out.buffer);
    var o = 0;
    out[o++] = OverlayLinkMsgType.linkSecureData.code;
    out[o++] = subtype & 0xFF;
    bd.setUint32(o, linkId);
    o += 4;
    bd.setUint32(o, seq);
    o += 4;
    out.setRange(o, o + _endpointIdLen, initEndpointId);
    o += _endpointIdLen;
    out.setRange(o, o + _endpointIdLen, respEndpointId);
    return out;
  }

  // -----------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------

  static void _requireLen(Uint8List bytes, int expected, String name) {
    if (bytes.length != expected) {
      throw ArgumentError.value(
        bytes.length,
        '$name.length',
        'must be $expected bytes',
      );
    }
  }

  static Uint8List _slice(Uint8List src, int offset, int length) {
    return Uint8List.fromList(src.sublist(offset, offset + length));
  }
}
