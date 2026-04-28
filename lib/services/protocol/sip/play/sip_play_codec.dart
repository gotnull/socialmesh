// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import '../../../../core/logging.dart';
import 'sip_play_constants.dart';
import 'sip_play_payload.dart';

/// Encodes / decodes the SIP Play v1 envelope.
///
/// Layout (big-endian):
///
/// ```
/// offset  size  field
/// 0       1     typeAndVersion  (0x11 = type=1 version=1)
/// 1       1     gameType
/// 2       2     instanceId      (big-endian u16)
/// 4       1     action
/// 5       1     seq             (0..0xFF)
/// 6       N     game-payload    (per-game; may be empty)
/// ```
///
/// The codec is intentionally pure — no clock, no I/O, no rate
/// limiting. Validation strictly checks the wire format. Per-game
/// payload validation is delegated to the registered game's own
/// codec via [SipPlayCodec.decodeGamePayload].
abstract final class SipPlayCodec {
  /// Encode an envelope to wire bytes. Returns null when the resulting
  /// envelope would exceed [SipPlayConstants.maxEnvelopeBytes] — the
  /// caller should treat this as a programmer error (per-game budget
  /// not being enforced upstream).
  static Uint8List? encode(SipPlayEnvelope envelope) {
    final headerBytes = SipPlayConstants.envelopeHeaderBytes;
    final total = headerBytes + envelope.gamePayload.length;
    if (total > SipPlayConstants.maxEnvelopeBytes) {
      AppLogging.sipPlay(
        'encode_blocked reason=envelope_too_large bytes=$total '
        'max=${SipPlayConstants.maxEnvelopeBytes}',
      );
      return null;
    }
    if (envelope.seq < 0 || envelope.seq > SipPlayConstants.maxSeqValue) {
      AppLogging.sipPlay(
        'encode_blocked reason=seq_out_of_range seq=${envelope.seq}',
      );
      return null;
    }
    if (envelope.instanceId < 0 || envelope.instanceId > 0xFFFF) {
      AppLogging.sipPlay(
        'encode_blocked reason=instance_id_out_of_range '
        'instance=${envelope.instanceId}',
      );
      return null;
    }
    if (envelope.gameTypeCode < 0 || envelope.gameTypeCode > 0xFF) {
      AppLogging.sipPlay(
        'encode_blocked reason=game_type_out_of_range '
        'gameType=${envelope.gameTypeCode}',
      );
      return null;
    }

    final out = Uint8List(total);
    out[0] = envelope.typeAndVersion & 0xFF;
    out[1] = envelope.gameTypeCode & 0xFF;
    // big-endian u16
    out[2] = (envelope.instanceId >> 8) & 0xFF;
    out[3] = envelope.instanceId & 0xFF;
    out[4] = envelope.action.code & 0xFF;
    out[5] = envelope.seq & 0xFF;
    if (envelope.gamePayload.isNotEmpty) {
      out.setRange(headerBytes, total, envelope.gamePayload);
    }
    return out;
  }

  /// Decode wire bytes into a [SipPlayEnvelope]. Pure — no I/O, no
  /// clock — and never throws. Every error path returns a structured
  /// [SipPlayDecodeResult.fail] so the dispatcher layer can drop+log
  /// without exception handling.
  ///
  /// Validation order matches the wire layout:
  ///   1. enough bytes for the 6-byte header,
  ///   2. envelope size within [SipPlayConstants.maxEnvelopeBytes],
  ///   3. typeAndVersion byte equals the v1 sentinel,
  ///   4. action code resolves to a known [SipPlayAction].
  ///
  /// Game-payload validity is NOT checked here — call the registered
  /// game's codec on `result.envelope.gamePayload` for that. Unknown
  /// game-type codes deliberately decode successfully so the engine
  /// can render the safe "unsupported" fallback.
  static SipPlayDecodeResult decode(Uint8List bytes) {
    if (bytes.length < SipPlayConstants.envelopeHeaderBytes) {
      AppLogging.sipPlay(
        'decode_failed reason=truncated_header bytes=${bytes.length}',
      );
      return const SipPlayDecodeResult.fail(SipPlayDecodeError.truncatedHeader);
    }
    if (bytes.length > SipPlayConstants.maxEnvelopeBytes) {
      AppLogging.sipPlay(
        'decode_failed reason=payload_too_large bytes=${bytes.length} '
        'max=${SipPlayConstants.maxEnvelopeBytes}',
      );
      return const SipPlayDecodeResult.fail(SipPlayDecodeError.payloadTooLarge);
    }

    final typeAndVersion = bytes[0];
    if (typeAndVersion != SipPlayConstants.envelopeTypeAndVersionV1) {
      AppLogging.sipPlay(
        'decode_failed reason=unsupported_version '
        'typeAndVersion=0x${typeAndVersion.toRadixString(16)}',
      );
      return const SipPlayDecodeResult.fail(
        SipPlayDecodeError.unsupportedVersion,
      );
    }

    final gameTypeCode = bytes[1];
    final instanceId = (bytes[2] << 8) | bytes[3];
    final actionCode = bytes[4];
    final seq = bytes[5];

    final action = SipPlayAction.fromCode(actionCode);
    if (action == null) {
      AppLogging.sipPlay(
        'decode_failed reason=unknown_action '
        'action=0x${actionCode.toRadixString(16)}',
      );
      return const SipPlayDecodeResult.fail(SipPlayDecodeError.unknownAction);
    }

    final headerBytes = SipPlayConstants.envelopeHeaderBytes;
    final gamePayload = bytes.length == headerBytes
        ? Uint8List(0)
        : Uint8List.fromList(bytes.sublist(headerBytes));

    return SipPlayDecodeResult.ok(
      SipPlayEnvelope(
        typeAndVersion: typeAndVersion,
        gameTypeCode: gameTypeCode,
        instanceId: instanceId,
        action: action,
        seq: seq,
        gamePayload: gamePayload,
      ),
    );
  }
}
