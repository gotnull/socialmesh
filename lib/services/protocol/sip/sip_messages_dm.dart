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
      final text = sanitizeUtf16(utf8.decode(payload));
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
