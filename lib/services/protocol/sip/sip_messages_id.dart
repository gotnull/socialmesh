// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP-1 identity message payload encode/decode.
///
/// Handles ID_REQ, ID_CLAIM, and ID_RESP payload serialization.
/// ID_CLAIM/ID_RESP carry a signature trailer (Ed25519).
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import '../../../utils/text_sanitizer.dart';
import 'sip_constants.dart';
import 'sip_types.dart';

/// ID_REQ request modes.
enum SipIdRequestMode {
  basic(0x01),
  full(0x02);

  const SipIdRequestMode(this.code);
  final int code;

  static SipIdRequestMode? fromCode(int code) {
    for (final m in values) {
      if (m.code == code) return m;
    }
    return null;
  }
}

/// Decoded ID_REQ payload (2 bytes).
class SipIdReq {
  final SipIdRequestMode mode;

  const SipIdReq({required this.mode});
}

/// Decoded ID_CLAIM / ID_RESP payload (variable length).
///
/// Layout:
///   key_type(1) + display_name_len(1) + display_name(0..32) +
///   status_len(1) + status(0..48) + device_model_len(1) + device_model(0..32) +
///   created_at(4) + persona_id(16) + pubkey(32) + claim_ttl(4)
///   [+ signature trailer (66 bytes) if signed]
class SipIdClaim {
  final int keyType;
  final String displayName;
  final String status;
  final String deviceModel;
  final int createdAt;
  final Uint8List personaId;
  final Uint8List pubkey;
  final int claimTtlS;

  const SipIdClaim({
    required this.keyType,
    required this.displayName,
    required this.status,
    required this.deviceModel,
    required this.createdAt,
    required this.personaId,
    required this.pubkey,
    required this.claimTtlS,
  });
}

/// Encode/decode SIP-1 identity message payloads.
abstract final class SipIdMessages {
  // ---------------------------------------------------------------------------
  // ID_REQ (2 bytes: mode + reserved)
  // ---------------------------------------------------------------------------

  /// Encode an ID_REQ payload.
  static Uint8List encodeIdReq(SipIdReq req) {
    final data = Uint8List(2);
    data[0] = req.mode.code;
    data[1] = 0; // reserved
    return data;
  }

  /// Decode an ID_REQ payload.
  static SipIdReq? decodeIdReq(Uint8List payload) {
    if (payload.length < 2) {
      AppLogging.sip(
        'SIP_ID: ID_REQ decode failed: payload too short (${payload.length})',
      );
      return null;
    }
    final mode = SipIdRequestMode.fromCode(payload[0]);
    if (mode == null) {
      AppLogging.sip(
        'SIP_ID: ID_REQ decode failed: unknown mode=0x${payload[0].toRadixString(16)}',
      );
      return null;
    }
    return SipIdReq(mode: mode);
  }

  // ---------------------------------------------------------------------------
  // ID_CLAIM / ID_RESP (variable length, max SipConstants.sipMaxSignedPayload)
  // ---------------------------------------------------------------------------

  /// Encode an ID_CLAIM payload (without signature trailer).
  ///
  /// The caller is responsible for appending the signature trailer
  /// (sig_type + sig_len + signature) after encoding.
  static Uint8List encodeIdClaim(SipIdClaim claim) {
    final nameBytes = _truncateUtf8(claim.displayName, 32);
    final statusBytes = _truncateUtf8(claim.status, 48);
    final modelBytes = _truncateUtf8(claim.deviceModel, 32);

    final totalLen =
        1 + // key_type
        1 +
        nameBytes.length + // display_name_len + display_name
        1 +
        statusBytes.length + // status_len + status
        1 +
        modelBytes.length + // device_model_len + device_model
        4 + // created_at
        16 + // persona_id
        32 + // pubkey
        4; // claim_ttl

    final data = Uint8List(totalLen);
    var offset = 0;

    data[offset++] = claim.keyType;
    data[offset++] = nameBytes.length;
    for (var i = 0; i < nameBytes.length; i++) {
      data[offset++] = nameBytes[i];
    }
    data[offset++] = statusBytes.length;
    for (var i = 0; i < statusBytes.length; i++) {
      data[offset++] = statusBytes[i];
    }
    data[offset++] = modelBytes.length;
    for (var i = 0; i < modelBytes.length; i++) {
      data[offset++] = modelBytes[i];
    }

    final bd = ByteData.sublistView(data);
    bd.setUint32(offset, claim.createdAt, Endian.little);
    offset += 4;

    data.setRange(offset, offset + 16, claim.personaId);
    offset += 16;

    data.setRange(offset, offset + 32, claim.pubkey);
    offset += 32;

    bd.setUint32(offset, claim.claimTtlS, Endian.little);

    return data;
  }

  /// Decode an ID_CLAIM/ID_RESP payload.
  ///
  /// If [hasSig] is true, the payload includes a 66-byte signature trailer
  /// which is stripped before decoding fields.
  static SipIdClaim? decodeIdClaim(Uint8List payload, {bool hasSig = false}) {
    var effectivePayload = payload;
    if (hasSig) {
      if (payload.length < SipConstants.sipSignatureTrailer) {
        AppLogging.sip(
          'SIP_ID: ID_CLAIM decode failed: too short for signature',
        );
        return null;
      }
      effectivePayload = Uint8List.fromList(
        payload.sublist(0, payload.length - SipConstants.sipSignatureTrailer),
      );
    }

    // Minimum: key_type(1) + name_len(1) + status_len(1) + model_len(1) +
    //          created_at(4) + persona_id(16) + pubkey(32) + claim_ttl(4) = 60
    if (effectivePayload.length < 60) {
      AppLogging.sip(
        'SIP_ID: ID_CLAIM decode failed: too short '
        '(${effectivePayload.length})',
      );
      return null;
    }

    var offset = 0;
    final keyType = effectivePayload[offset++];

    final nameLen = effectivePayload[offset++];
    if (offset + nameLen > effectivePayload.length) return null;
    final nameBytes = effectivePayload.sublist(offset, offset + nameLen);
    offset += nameLen;

    if (offset >= effectivePayload.length) return null;
    final statusLen = effectivePayload[offset++];
    if (offset + statusLen > effectivePayload.length) return null;
    final statusBytes = effectivePayload.sublist(offset, offset + statusLen);
    offset += statusLen;

    if (offset >= effectivePayload.length) return null;
    final modelLen = effectivePayload[offset++];
    if (offset + modelLen > effectivePayload.length) return null;
    final modelBytes = effectivePayload.sublist(offset, offset + modelLen);
    offset += modelLen;

    if (offset + 56 > effectivePayload.length) return null;

    final bd = ByteData.sublistView(effectivePayload);
    final createdAt = bd.getUint32(offset, Endian.little);
    offset += 4;

    final personaId = Uint8List.fromList(
      effectivePayload.sublist(offset, offset + 16),
    );
    offset += 16;

    final pubkey = Uint8List.fromList(
      effectivePayload.sublist(offset, offset + 32),
    );
    offset += 32;

    final claimTtlS = bd.getUint32(offset, Endian.little);

    return SipIdClaim(
      keyType: keyType,
      displayName: sanitizeExternalText(String.fromCharCodes(nameBytes)),
      status: sanitizeExternalText(String.fromCharCodes(statusBytes)),
      deviceModel: sanitizeExternalText(String.fromCharCodes(modelBytes)),
      createdAt: createdAt,
      personaId: personaId,
      pubkey: pubkey,
      claimTtlS: claimTtlS,
    );
  }

  /// Extract the signature trailer from an ID_CLAIM/ID_RESP payload.
  ///
  /// Returns (sigType, sigLen, signatureBytes) or null if invalid.
  static ({int sigType, int sigLen, Uint8List signature})? extractSignature(
    Uint8List payload,
  ) {
    if (payload.length < SipConstants.sipSignatureTrailer) return null;
    final trailerStart = payload.length - SipConstants.sipSignatureTrailer;
    final sigType = payload[trailerStart];
    final sigLen = payload[trailerStart + 1];
    if (sigType != sipSigTypeEd25519 || sigLen != sipSigLenEd25519) {
      return null;
    }
    final signature = Uint8List.fromList(
      payload.sublist(trailerStart + 2, trailerStart + 2 + sigLen),
    );
    return (sigType: sigType, sigLen: sigLen, signature: signature);
  }

  /// Build the data-to-sign buffer: SIP header bytes + payload (excluding signature trailer).
  static Uint8List buildSignedData(
    Uint8List headerBytes,
    Uint8List claimPayloadWithoutSig,
  ) {
    final result = Uint8List(
      headerBytes.length + claimPayloadWithoutSig.length,
    );
    result.setRange(0, headerBytes.length, headerBytes);
    result.setRange(headerBytes.length, result.length, claimPayloadWithoutSig);
    return result;
  }

  /// Append the Ed25519 signature trailer to a claim payload.
  static Uint8List appendSignature(
    Uint8List claimPayload,
    Uint8List signature,
  ) {
    final result = Uint8List(
      claimPayload.length + SipConstants.sipSignatureTrailer,
    );
    result.setRange(0, claimPayload.length, claimPayload);
    final trailerStart = claimPayload.length;
    result[trailerStart] = sipSigTypeEd25519;
    result[trailerStart + 1] = sipSigLenEd25519;
    result.setRange(trailerStart + 2, result.length, signature);
    return result;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  static Uint8List _truncateUtf8(String text, int maxBytes) {
    final codeUnits = text.codeUnits;
    if (codeUnits.length <= maxBytes) return Uint8List.fromList(codeUnits);
    return Uint8List.fromList(codeUnits.sublist(0, maxBytes));
  }
}
