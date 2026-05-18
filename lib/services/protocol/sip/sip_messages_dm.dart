// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP DM_MSG message encode/decode.
///
/// DM messages carry UTF-8 text scoped to a session_tag from a
/// completed SIP-1 handshake. The session_tag is carried in the
/// SIP frame header's session_id field, not the payload.
///
/// Payload layout:
///   bytes 0..N: UTF-8 text content (max [SipDmConstants.maxDmTextBytes])
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../../core/logging.dart';
import '../../../utils/text_sanitizer.dart';
import 'sip_constants.dart';

/// DM-specific constants.
abstract final class SipDmConstants {
  /// Maximum UTF-8 bytes for a DM text payload.
  ///
  /// The SIP frame header is [SipConstants.sipWrapperMin] = 22 bytes.
  /// SIP_MTU_APP = 237 bytes. So max payload = 215 bytes.
  /// We cap DM text at 180 bytes to leave headroom for future
  /// envelope fields (e.g. sequence number, flags).
  static const int maxDmTextBytes = 180;
}

/// A parsed DM message.
class SipDmMessage {
  /// UTF-8 text content.
  final String text;

  /// Raw payload bytes (the encoded UTF-8).
  final Uint8List rawPayload;

  const SipDmMessage({required this.text, required this.rawPayload});

  @override
  String toString() => 'SipDmMessage(text=${text.length} chars)';
}

/// Encode/decode helpers for DM_MSG payloads.
abstract final class SipDmMessages {
  /// Encode a DM text message into a payload [Uint8List].
  ///
  /// Returns null if the text exceeds [SipDmConstants.maxDmTextBytes]
  /// after UTF-8 encoding, or if the text is empty.
  static Uint8List? encodeDm(String text) {
    if (text.isEmpty) {
      AppLogging.sip('SIP_DM: encode rejected: empty text');
      return null;
    }

    final encoded = utf8.encode(text);
    if (encoded.length > SipDmConstants.maxDmTextBytes) {
      AppLogging.sip(
        'SIP_DM: encode rejected: ${encoded.length}B > '
        '${SipDmConstants.maxDmTextBytes}B max',
      );
      return null;
    }

    return Uint8List.fromList(encoded);
  }

  /// Decode a DM payload into a [SipDmMessage].
  ///
  /// Returns null if the payload is empty or not valid UTF-8.
  static SipDmMessage? decodeDm(Uint8List payload) {
    if (payload.isEmpty) {
      AppLogging.sip('SIP_DM: decode rejected: empty payload');
      return null;
    }

    if (payload.length > SipDmConstants.maxDmTextBytes) {
      AppLogging.sip(
        'SIP_DM: decode rejected: ${payload.length}B > '
        '${SipDmConstants.maxDmTextBytes}B max',
      );
      return null;
    }

    try {
      final text = sanitizeExternalText(utf8.decode(payload));
      if (text.trim().isEmpty) {
        AppLogging.sip('SIP_DM: decode rejected: sanitized empty');
        return null;
      }
      return SipDmMessage(text: text, rawPayload: Uint8List.fromList(payload));
    } on FormatException {
      AppLogging.sip('SIP_DM: decode rejected: invalid UTF-8');
      return null;
    }
  }

  /// Calculate the UTF-8 byte length of a string without allocating
  /// the full encoded buffer. Useful for pre-flight size checks.
  static int utf8ByteLength(String text) => utf8.encode(text).length;

  // ---------------------------------------------------------------------------
  // DM_REACTION encode/decode
  // ---------------------------------------------------------------------------

  /// Encode a DM reaction payload.
  ///
  /// Payload layout (5 bytes):
  ///   byte 0:    emoji index (0–6, maps to [SipDmReactionEmojis.all])
  ///   bytes 1–4: target message timestamp in seconds (big-endian uint32)
  ///
  /// Returns null if [emojiIndex] is out of range.
  static Uint8List? encodeReaction({
    required int emojiIndex,
    required int targetTimestampS,
  }) {
    if (emojiIndex < 0 || emojiIndex > 6) {
      AppLogging.sip('SIP_DM: encodeReaction rejected: bad index $emojiIndex');
      return null;
    }
    final bytes = Uint8List(5);
    bytes[0] = emojiIndex;
    final bd = ByteData.sublistView(bytes);
    bd.setUint32(1, targetTimestampS, Endian.big);
    return bytes;
  }

  /// Decode a DM reaction payload.
  ///
  /// Returns null if the payload is malformed.
  static SipDmReaction? decodeReaction(Uint8List payload) {
    if (payload.length < 5) {
      AppLogging.sip(
        'SIP_DM: decodeReaction rejected: ${payload.length}B < 5B',
      );
      return null;
    }
    final emojiIndex = payload[0];
    if (emojiIndex > 6) {
      AppLogging.sip('SIP_DM: decodeReaction rejected: bad index $emojiIndex');
      return null;
    }
    final bd = ByteData.sublistView(payload);
    final targetTimestampS = bd.getUint32(1, Endian.big);
    return SipDmReaction(
      emojiIndex: emojiIndex,
      targetTimestampS: targetTimestampS,
    );
  }

  // ---------------------------------------------------------------------------
  // DM_DELETE encode/decode
  // ---------------------------------------------------------------------------

  /// Encode a DM delete payload.
  ///
  /// Payload layout (4 bytes):
  ///   bytes 0–3: target message timestamp in seconds (big-endian uint32)
  ///
  /// The receiver removes the matching message from their local history.
  static Uint8List encodeDelete({required int targetTimestampS}) {
    final bytes = Uint8List(4);
    final bd = ByteData.sublistView(bytes);
    bd.setUint32(0, targetTimestampS, Endian.big);
    return bytes;
  }

  /// Decode a DM delete payload.
  ///
  /// Returns the target timestamp in seconds, or null if malformed.
  static int? decodeDelete(Uint8List payload) {
    if (payload.length < 4) {
      AppLogging.sip('SIP_DM: decodeDelete rejected: ${payload.length}B < 4B');
      return null;
    }
    final bd = ByteData.sublistView(payload);
    return bd.getUint32(0, Endian.big);
  }

  // ---------------------------------------------------------------------------
  // Secure DM payload codecs (Phase 2)
  //
  // These wrap the plaintext `0x40` / `0x42` content with a sender-provided
  // timestamp so the decrypted payload can be reconstructed into a
  // synthetic [SipFrame] that flows through the existing
  // `SipDmManager.handleInboundDm` / `handleInboundReaction` paths
  // unchanged. Typing (`0x41`) is explicitly NOT carried over secure —
  // its high frequency / low content value doesn't justify the 62 B
  // per-frame overhead.
  //
  // Wire-layout inside `LINK_SECURE_DATA` (after AEAD strip):
  //   subtype=0x02  dmText       : timestamp_s(4) ‖ utf8_text
  //   subtype=0x03  dmReaction   : timestamp_s(4) ‖ emoji_index(1) ‖ target_ts(4)
  // ---------------------------------------------------------------------------

  /// Prefix-overhead (bytes) added by the secure DM text envelope.
  static const int secureDmTextOverhead = 4;

  /// Total size (bytes) of a secure DM reaction payload.
  static const int secureDmReactionSize = 9;

  /// Encode a secure DM text payload. Prepends [timestampS] (seconds)
  /// to the raw UTF-8 bytes so the receiver can reconstruct a synthetic
  /// SIP frame with the original sender time.
  static Uint8List? encodeSecureDmText({
    required String text,
    required int timestampS,
  }) {
    if (timestampS < 0 || timestampS > 0xFFFFFFFF) return null;
    final body = encodeDm(text);
    if (body == null) return null;
    final out = Uint8List(secureDmTextOverhead + body.length);
    ByteData.sublistView(out).setUint32(0, timestampS, Endian.big);
    out.setRange(secureDmTextOverhead, out.length, body);
    return out;
  }

  /// Decode a secure DM text payload into its timestamp + parsed
  /// message. Returns null when too short, out-of-range, or the body
  /// fails UTF-8 decoding.
  static SecureDmTextDecoded? decodeSecureDmText(Uint8List payload) {
    if (payload.length < secureDmTextOverhead + 1) {
      AppLogging.sip(
        'SIP_DM: decodeSecureDmText rejected: ${payload.length}B too short',
      );
      return null;
    }
    final timestampS = ByteData.sublistView(
      payload,
      0,
      secureDmTextOverhead,
    ).getUint32(0, Endian.big);
    final body = Uint8List.sublistView(payload, secureDmTextOverhead);
    final msg = decodeDm(body);
    if (msg == null) return null;
    return SecureDmTextDecoded(timestampS: timestampS, message: msg);
  }

  /// Encode a secure DM reaction payload.
  static Uint8List? encodeSecureReaction({
    required int timestampS,
    required int emojiIndex,
    required int targetTimestampS,
  }) {
    if (timestampS < 0 || timestampS > 0xFFFFFFFF) return null;
    if (emojiIndex < 0 || emojiIndex > 6) return null;
    if (targetTimestampS < 0 || targetTimestampS > 0xFFFFFFFF) return null;
    final out = Uint8List(secureDmReactionSize);
    final bd = ByteData.sublistView(out);
    bd.setUint32(0, timestampS, Endian.big);
    out[4] = emojiIndex;
    bd.setUint32(5, targetTimestampS, Endian.big);
    return out;
  }

  /// Decode a secure DM reaction payload. Returns null when length or
  /// emoji index is out of range.
  static SecureDmReactionDecoded? decodeSecureReaction(Uint8List payload) {
    if (payload.length != secureDmReactionSize) {
      AppLogging.sip(
        'SIP_DM: decodeSecureReaction rejected: '
        '${payload.length}B != ${secureDmReactionSize}B',
      );
      return null;
    }
    final bd = ByteData.sublistView(payload);
    final timestampS = bd.getUint32(0, Endian.big);
    final emojiIndex = payload[4];
    if (emojiIndex > 6) return null;
    final targetTimestampS = bd.getUint32(5, Endian.big);
    return SecureDmReactionDecoded(
      timestampS: timestampS,
      reaction: SipDmReaction(
        emojiIndex: emojiIndex,
        targetTimestampS: targetTimestampS,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Secure DM ink envelope (Phase 2)
  //
  // Wire layout inside `LINK_SECURE_DATA` subtype 0x05:
  //   timestamp_s(4 BE) ‖ sip_ink_v1_payload[]
  //
  // The inner `sip_ink_v1_payload` is the same byte sequence that
  // travels in plaintext DM_INK (0x45) frames. Receiver reconstructs a
  // synthetic SIP frame and feeds it through `handleInboundInk`.
  // ---------------------------------------------------------------------------

  /// Prefix-overhead (bytes) added by the secure DM ink envelope.
  static const int secureDmInkOverhead = 4;

  /// Encode a secure DM ink payload. Prepends [timestampS] (seconds) to
  /// [inkPayload] so the receiver can reconstruct a synthetic SIP
  /// frame with the original sender time.
  ///
  /// Returns null if the timestamp is out of range, the ink payload is
  /// empty, or the combined size exceeds the DM byte cap.
  static Uint8List? encodeSecureDmInk({
    required Uint8List inkPayload,
    required int timestampS,
  }) {
    if (timestampS < 0 || timestampS > 0xFFFFFFFF) return null;
    if (inkPayload.isEmpty) return null;
    if (inkPayload.length > SipDmConstants.maxDmTextBytes) {
      AppLogging.sip(
        'SIP_DM: encodeSecureDmInk rejected: ${inkPayload.length}B > '
        '${SipDmConstants.maxDmTextBytes}B max',
      );
      return null;
    }
    final out = Uint8List(secureDmInkOverhead + inkPayload.length);
    ByteData.sublistView(out).setUint32(0, timestampS, Endian.big);
    out.setRange(secureDmInkOverhead, out.length, inkPayload);
    return out;
  }

  /// Decode a secure DM ink payload into its timestamp + raw ink
  /// bytes. Returns null when too short or oversized; the inner ink
  /// payload itself is parsed by `SipInkDecoder.decode` further down
  /// the pipeline.
  static SecureDmInkDecoded? decodeSecureDmInk(Uint8List payload) {
    if (payload.length <= secureDmInkOverhead) {
      AppLogging.sip(
        'SIP_DM: decodeSecureDmInk rejected: ${payload.length}B too short',
      );
      return null;
    }
    if (payload.length - secureDmInkOverhead > SipDmConstants.maxDmTextBytes) {
      AppLogging.sip(
        'SIP_DM: decodeSecureDmInk rejected: '
        '${payload.length - secureDmInkOverhead}B > '
        '${SipDmConstants.maxDmTextBytes}B max',
      );
      return null;
    }
    final timestampS = ByteData.sublistView(
      payload,
      0,
      secureDmInkOverhead,
    ).getUint32(0, Endian.big);
    final inkPayload = Uint8List.sublistView(payload, secureDmInkOverhead);
    return SecureDmInkDecoded(
      timestampS: timestampS,
      inkPayload: Uint8List.fromList(inkPayload),
    );
  }

  // ---------------------------------------------------------------------------
  // Secure DM Play envelope — same shape as secure DM Ink: a 4-byte
  // big-endian sender timestamp prefix, followed by the v1 SIP Play
  // envelope bytes (typeAndVersion ‖ gameType ‖ instanceId ‖ action ‖
  // seq ‖ game-payload). Travels in
  // OverlaySecureDataSubtype.dmPlay frames; receiver reconstructs a
  // synthetic SIP DM_PLAY (0x46) frame and feeds it through
  // `handleInboundPlay`.
  // ---------------------------------------------------------------------------

  /// Prefix-overhead (bytes) added by the secure DM play envelope.
  static const int secureDmPlayOverhead = 4;

  /// Encode a secure DM play payload. Prepends [timestampS] (seconds)
  /// to [playPayload] so the receiver reconstructs a synthetic SIP
  /// frame with the original sender time.
  ///
  /// Returns null when the timestamp is out of range, the play
  /// payload is empty, or the combined size exceeds the DM byte cap.
  static Uint8List? encodeSecureDmPlay({
    required Uint8List playPayload,
    required int timestampS,
  }) {
    if (timestampS < 0 || timestampS > 0xFFFFFFFF) return null;
    if (playPayload.isEmpty) return null;
    if (playPayload.length > SipDmConstants.maxDmTextBytes) {
      AppLogging.sip(
        'SIP_DM: encodeSecureDmPlay rejected: ${playPayload.length}B > '
        '${SipDmConstants.maxDmTextBytes}B max',
      );
      return null;
    }
    final out = Uint8List(secureDmPlayOverhead + playPayload.length);
    ByteData.sublistView(out).setUint32(0, timestampS, Endian.big);
    out.setRange(secureDmPlayOverhead, out.length, playPayload);
    return out;
  }

  /// Decode a secure DM play payload into its timestamp + raw envelope
  /// bytes. Returns null when too short or oversized; the envelope
  /// itself is parsed by `SipPlayCodec.decode` further down.
  static SecureDmPlayDecoded? decodeSecureDmPlay(Uint8List payload) {
    if (payload.length <= secureDmPlayOverhead) {
      AppLogging.sip(
        'SIP_DM: decodeSecureDmPlay rejected: ${payload.length}B too short',
      );
      return null;
    }
    if (payload.length - secureDmPlayOverhead > SipDmConstants.maxDmTextBytes) {
      AppLogging.sip(
        'SIP_DM: decodeSecureDmPlay rejected: '
        '${payload.length - secureDmPlayOverhead}B > '
        '${SipDmConstants.maxDmTextBytes}B max',
      );
      return null;
    }
    final timestampS = ByteData.sublistView(
      payload,
      0,
      secureDmPlayOverhead,
    ).getUint32(0, Endian.big);
    final playPayload = Uint8List.sublistView(payload, secureDmPlayOverhead);
    return SecureDmPlayDecoded(
      timestampS: timestampS,
      playPayload: Uint8List.fromList(playPayload),
    );
  }

  // ---------------------------------------------------------------------------
  // Secure DM Signal envelope — same shape as secure DM Play / Ink:
  // a 4-byte big-endian sender timestamp prefix followed by the v1
  // SIP Signal envelope bytes. Travels in
  // OverlaySecureDataSubtype.dmSignal frames; receiver reconstructs
  // a synthetic DM_SIGNAL (0x47) frame and feeds it through
  // `handleInboundSignal`.
  // ---------------------------------------------------------------------------

  /// Prefix-overhead (bytes) added by the secure DM signal envelope.
  static const int secureDmSignalOverhead = 4;

  /// Encode a secure DM signal payload. Prepends [timestampS] (seconds)
  /// to [signalPayload].
  static Uint8List? encodeSecureDmSignal({
    required Uint8List signalPayload,
    required int timestampS,
  }) {
    if (timestampS < 0 || timestampS > 0xFFFFFFFF) return null;
    if (signalPayload.isEmpty) return null;
    if (signalPayload.length > SipDmConstants.maxDmTextBytes) {
      AppLogging.sip(
        'SIP_DM: encodeSecureDmSignal rejected: ${signalPayload.length}B > '
        '${SipDmConstants.maxDmTextBytes}B max',
      );
      return null;
    }
    final out = Uint8List(secureDmSignalOverhead + signalPayload.length);
    ByteData.sublistView(out).setUint32(0, timestampS, Endian.big);
    out.setRange(secureDmSignalOverhead, out.length, signalPayload);
    return out;
  }

  /// Decode a secure DM signal payload into timestamp + raw envelope
  /// bytes. The envelope itself is parsed by `SipSignalCodec.decode`.
  static SecureDmSignalDecoded? decodeSecureDmSignal(Uint8List payload) {
    if (payload.length <= secureDmSignalOverhead) {
      AppLogging.sip(
        'SIP_DM: decodeSecureDmSignal rejected: ${payload.length}B too short',
      );
      return null;
    }
    if (payload.length - secureDmSignalOverhead >
        SipDmConstants.maxDmTextBytes) {
      AppLogging.sip(
        'SIP_DM: decodeSecureDmSignal rejected: '
        '${payload.length - secureDmSignalOverhead}B > '
        '${SipDmConstants.maxDmTextBytes}B max',
      );
      return null;
    }
    final timestampS = ByteData.sublistView(
      payload,
      0,
      secureDmSignalOverhead,
    ).getUint32(0, Endian.big);
    final signalPayload = Uint8List.sublistView(
      payload,
      secureDmSignalOverhead,
    );
    return SecureDmSignalDecoded(
      timestampS: timestampS,
      signalPayload: Uint8List.fromList(signalPayload),
    );
  }
}

/// Parsed result of a secure DM ink payload.
class SecureDmInkDecoded {
  final int timestampS;
  final Uint8List inkPayload;
  const SecureDmInkDecoded({
    required this.timestampS,
    required this.inkPayload,
  });
}

/// Parsed result of a secure DM play payload.
class SecureDmPlayDecoded {
  final int timestampS;
  final Uint8List playPayload;
  const SecureDmPlayDecoded({
    required this.timestampS,
    required this.playPayload,
  });
}

/// Parsed result of a secure DM signal payload.
class SecureDmSignalDecoded {
  final int timestampS;
  final Uint8List signalPayload;
  const SecureDmSignalDecoded({
    required this.timestampS,
    required this.signalPayload,
  });
}

/// Parsed result of a secure DM text payload.
class SecureDmTextDecoded {
  final int timestampS;
  final SipDmMessage message;
  const SecureDmTextDecoded({required this.timestampS, required this.message});
}

/// Parsed result of a secure DM reaction payload.
class SecureDmReactionDecoded {
  final int timestampS;
  final SipDmReaction reaction;
  const SecureDmReactionDecoded({
    required this.timestampS,
    required this.reaction,
  });
}

/// Predefined reaction emojis for DM messages.
///
/// Index maps 1:1 to the wire format emoji index byte.
abstract final class SipDmReactionEmojis {
  /// The seven reaction emojis: ❤️ 👍 😁 😂 👏 👎 🔥
  static const List<String> all = ['❤️', '👍', '😁', '😂', '👏', '👎', '🔥'];
}

/// A parsed DM reaction.
class SipDmReaction {
  /// Index into [SipDmReactionEmojis.all].
  final int emojiIndex;

  /// Timestamp (seconds) of the message being reacted to.
  final int targetTimestampS;

  const SipDmReaction({
    required this.emojiIndex,
    required this.targetTimestampS,
  });

  /// The emoji character for this reaction.
  String get emoji => SipDmReactionEmojis.all[emojiIndex];

  @override
  String toString() =>
      'SipDmReaction(emoji=$emoji, target=${targetTimestampS}s)';
}
