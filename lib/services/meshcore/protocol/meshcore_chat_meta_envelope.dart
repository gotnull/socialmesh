// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// chat-meta.v1 envelope codec — D33 (replies only).
//
// Encodes and decodes a small SocialMesh-internal envelope that
// rides INSIDE the plaintext text body of an ordinary MeshCore
// `CMD_SEND_TXT_MSG` (contact, 0x02) or `CMD_SEND_CHANNEL_TXT_MSG`
// (channel, 0x03) frame. The envelope carries reply / hello /
// (future) reaction structured payloads.
//
// Wire shape (the full text body bytes the firmware sees):
//
//   [fallback_prefix:6 bytes "[mrrp]"]
//   [base64url_envelope: variable]
//   [fallback_suffix:7 bytes "[/mrrp]"]
//   [single space:1 byte]
//   [human_summary:UTF-8 variable]
//
// The base64url-decoded envelope is:
//
//   [magic:5 bytes "MRRP/"]
//   [version:u8 = 0x01]
//   [svc:u8 = 0x06]            // chat-meta.v1
//   [op:u8]                    // 0x00 HELLO, 0x02 REPLY (D33);
//                              // 0x01 REACTION reserved (D34)
//   [len:u8]                   // 0..240, length of the payload
//                              // bytes that follow
//   [payload:len bytes]        // op-specific, see encode/decode helpers
//
// The plain-ASCII fallback wrapper exists so non-SocialMesh clients
// that receive a reply still see a comprehensible "[mrrp]…[/mrrp]
// Bob replied: yes" instead of binary garbage. SocialMesh's chat
// renderer strips both the `[mrrp]…[/mrrp]` block AND the trailing
// human summary; only the structured op-payload reaches the bubble
// UI.
//
// See `docs/protocol/MESHCORE_REACTIONS_REPLIES_RFC_V0_1.md` and
// `docs/protocol/MESHCORE_REPLIES_D33_IMPLEMENTATION_PLAN.md` for
// the locked spec this implementation pins.
//
// Hard rules carried forward from the spec:
//   - No firmware fork (envelope rides inside ordinary text bodies).
//   - No code copied from upstream MeshCore reference.
//   - No production comments referencing meshcore-open.
//   - Logs are secret-safe: never print message text, full pubkeys,
//     or raw envelope bytes outside structured event lines.

import 'dart:convert';
import 'dart:typed_data';

import '../../../core/logging.dart';

/// Magic byte sequence identifying a chat-meta.v1 envelope.
/// 5 ASCII bytes: `M R R P /`.
final Uint8List kChatMetaMagic = Uint8List.fromList([
  0x4D,
  0x52,
  0x52,
  0x50,
  0x2F,
]);

/// Envelope version this codec produces and accepts. Bumped when an
/// incompatible change to the magic+version+svc+op+len framing
/// lands. Forward-compatible new ops within the same version are
/// silently ignored by decoders.
const int kChatMetaVersion = 0x01;

/// Service id for chat-meta.v1 inside the envelope's `svc` byte.
/// Reserved as the 32-bit `0x00000006` in
/// `docs/sip/MRRP_SERVICES_V0_1.md`; truncated to a single byte for
/// the embedded envelope's bandwidth.
const int kChatMetaSvc = 0x06;

/// Op codes for the v0.1 envelope.
class ChatMetaOps {
  ChatMetaOps._();

  /// One-shot capability advertisement. D33 ships the codec but the
  /// "send on first contact" trigger is gated off; only HELLOs sent
  /// by future code are surfaced to capability tracking.
  static const int hello = 0x00;

  /// Future emoji reaction (D34, NOT implemented in D33). Decoders
  /// must reject this op in v0.1 — encoders never emit it.
  static const int reactionReservedD34 = 0x01;

  /// D33 reply to an existing message. See [ChatMetaReplyPayload].
  static const int reply = 0x02;
}

/// Plain-ASCII fallback sentinel chosen by the D33 plan §3 after the
/// iOS render check showed `U+E000`/`U+E001` could not be reliably
/// validated. This format guarantees byte-equal rendering on every
/// UTF-8 platform.
const String kFallbackPrefix = '[mrrp]';
const String kFallbackSuffix = '[/mrrp]';

/// Maximum value the 1-byte `len` field can hold.
const int kChatMetaMaxPayloadBytes = 240;

/// Hard cap on the total over-the-air text body length, including
/// the fallback wrapper, base64url envelope, and human summary.
/// Senders truncate or refuse before exceeding this.
const int kChatMetaMaxOtaTextBytes = 220;

/// Maximum length of the human-readable fallback summary appended
/// after `[/mrrp]`. Senders truncate the reply body inside the
/// summary at this many UTF-8 bytes.
const int kChatMetaSummaryMaxBytes = 80;

// ---------------------------------------------------------------------------
// MeshCore Message Fingerprint (MMF)
// ---------------------------------------------------------------------------

/// Discriminates the two MMF shapes carried inside reply payloads.
class MmfScope {
  MmfScope._();

  /// Channel scope: `[scope:0x01][channel_idx:u8][target_ts:u32_LE]` = 6 B.
  static const int channel = 0x01;

  /// Contact scope: `[scope:0x02][peer_pubkey_prefix:6B][target_ts:u32_LE]`
  /// = 11 B. The 6-byte prefix is **the other party's** public-key
  /// prefix (sender's prefix on inbound; recipient's prefix on
  /// outbound) so both ends derive the same MMF for the same
  /// logical conversation.
  static const int contact = 0x02;
}

/// A MeshCore Message Fingerprint. Cross-device target identifier
/// for replies (and future reactions).
///
/// Always built from wire fields the sender sets and the receiver
/// echoes verbatim, so both ends compute the same `MeshCoreMmf` for
/// the same logical message. Stored as a lowercase hex string with
/// colons (e.g. `"01:00:67abc1d2"` for a channel slot 0 message
/// stamped at unix-epoch-seconds `0x67abc1d2`) for readability in
/// logs and JSON.
class MeshCoreMmf {
  /// `MmfScope.channel` or `MmfScope.contact`.
  final int scope;

  /// For channel scope: the slot index (0..7).
  /// For contact scope: zero (use [peerPubkeyPrefix] instead).
  final int channelIndex;

  /// For contact scope: the 6-byte prefix of the OTHER party's
  /// public key. Empty Uint8List for channel scope.
  final Uint8List peerPubkeyPrefix;

  /// The firmware-supplied 32-bit Unix-epoch-seconds timestamp from
  /// the wire frame. Set by sender, copied verbatim through flood.
  final int targetTimestampS;

  const MeshCoreMmf._({
    required this.scope,
    required this.channelIndex,
    required this.peerPubkeyPrefix,
    required this.targetTimestampS,
  });

  /// Build a channel-scope MMF.
  factory MeshCoreMmf.channel({
    required int channelIndex,
    required int targetTimestampS,
  }) {
    if (channelIndex < 0 || channelIndex > 0xFF) {
      throw ArgumentError.value(channelIndex, 'channelIndex', 'must fit in u8');
    }
    if (targetTimestampS < 0 || targetTimestampS > 0xFFFFFFFF) {
      throw ArgumentError.value(
        targetTimestampS,
        'targetTimestampS',
        'must fit in u32',
      );
    }
    return MeshCoreMmf._(
      scope: MmfScope.channel,
      channelIndex: channelIndex,
      peerPubkeyPrefix: Uint8List(0),
      targetTimestampS: targetTimestampS,
    );
  }

  /// Build a contact-scope MMF. [peerPubkeyPrefix] must be exactly
  /// 6 bytes — the first 6 bytes of the OTHER party's public key.
  factory MeshCoreMmf.contact({
    required Uint8List peerPubkeyPrefix,
    required int targetTimestampS,
  }) {
    if (peerPubkeyPrefix.length != 6) {
      throw ArgumentError.value(
        peerPubkeyPrefix.length,
        'peerPubkeyPrefix.length',
        'must be exactly 6 bytes',
      );
    }
    if (targetTimestampS < 0 || targetTimestampS > 0xFFFFFFFF) {
      throw ArgumentError.value(
        targetTimestampS,
        'targetTimestampS',
        'must fit in u32',
      );
    }
    return MeshCoreMmf._(
      scope: MmfScope.contact,
      channelIndex: 0,
      peerPubkeyPrefix: Uint8List.fromList(peerPubkeyPrefix),
      targetTimestampS: targetTimestampS,
    );
  }

  /// Serialise to bytes for embedding in a reply payload.
  /// Channel: 6 bytes. Contact: 11 bytes.
  Uint8List toBytes() {
    final builder = BytesBuilder();
    builder.addByte(scope);
    if (scope == MmfScope.channel) {
      builder.addByte(channelIndex);
    } else if (scope == MmfScope.contact) {
      builder.add(peerPubkeyPrefix);
    } else {
      throw StateError('Unsupported MMF scope: $scope');
    }
    final tsBytes = ByteData(4)..setUint32(0, targetTimestampS, Endian.little);
    builder.add(tsBytes.buffer.asUint8List());
    return builder.toBytes();
  }

  /// Parse from raw bytes. Returns null on malformed input rather
  /// than throwing; receivers treat unparseable MMFs as "drop the
  /// envelope" and the caller falls through to plain-text rendering.
  static MeshCoreMmf? parse(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    final scope = bytes[0];
    switch (scope) {
      case MmfScope.channel:
        if (bytes.length != 6) return null;
        final ts = ByteData.sublistView(
          bytes,
          2,
          6,
        ).getUint32(0, Endian.little);
        return MeshCoreMmf.channel(
          channelIndex: bytes[1],
          targetTimestampS: ts,
        );
      case MmfScope.contact:
        if (bytes.length != 11) return null;
        final ts = ByteData.sublistView(
          bytes,
          7,
          11,
        ).getUint32(0, Endian.little);
        return MeshCoreMmf.contact(
          peerPubkeyPrefix: Uint8List.fromList(bytes.sublist(1, 7)),
          targetTimestampS: ts,
        );
      default:
        return null;
    }
  }

  /// Total byte length when serialised. Channel = 6, contact = 11.
  int get byteLength => scope == MmfScope.channel ? 6 : 11;

  /// Stable string form: `"01:00:67abc1d2"` for channel,
  /// `"02:79426d8db8fd:67abc1d2"` for contact. Lowercase hex.
  /// Round-trips losslessly via [parseString].
  String toStableString() {
    final ts = targetTimestampS.toRadixString(16).padLeft(8, '0').toLowerCase();
    if (scope == MmfScope.channel) {
      final idx = channelIndex.toRadixString(16).padLeft(2, '0').toLowerCase();
      return '01:$idx:$ts';
    }
    final prefixHex = peerPubkeyPrefix
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toLowerCase();
    return '02:$prefixHex:$ts';
  }

  /// Parse the stable-string form. Returns null on malformed input.
  static MeshCoreMmf? parseString(String s) {
    final parts = s.split(':');
    if (parts.length != 3) return null;
    if (parts[0] == '01') {
      // channel: scope:idx:ts
      if (parts[1].length != 2 || parts[2].length != 8) return null;
      final idx = int.tryParse(parts[1], radix: 16);
      final ts = int.tryParse(parts[2], radix: 16);
      if (idx == null || ts == null) return null;
      return MeshCoreMmf.channel(channelIndex: idx, targetTimestampS: ts);
    }
    if (parts[0] == '02') {
      // contact: scope:prefixHex(12chars):ts
      if (parts[1].length != 12 || parts[2].length != 8) return null;
      final prefix = Uint8List(6);
      for (var i = 0; i < 6; i++) {
        final byte = int.tryParse(
          parts[1].substring(i * 2, i * 2 + 2),
          radix: 16,
        );
        if (byte == null) return null;
        prefix[i] = byte;
      }
      final ts = int.tryParse(parts[2], radix: 16);
      if (ts == null) return null;
      return MeshCoreMmf.contact(
        peerPubkeyPrefix: prefix,
        targetTimestampS: ts,
      );
    }
    return null;
  }

  @override
  String toString() => 'MeshCoreMmf(${toStableString()})';

  @override
  bool operator ==(Object other) {
    if (other is! MeshCoreMmf) return false;
    if (scope != other.scope) return false;
    if (targetTimestampS != other.targetTimestampS) return false;
    if (channelIndex != other.channelIndex) return false;
    if (peerPubkeyPrefix.length != other.peerPubkeyPrefix.length) return false;
    for (var i = 0; i < peerPubkeyPrefix.length; i++) {
      if (peerPubkeyPrefix[i] != other.peerPubkeyPrefix[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => toStableString().hashCode;
}

// ---------------------------------------------------------------------------
// Decoded envelope + payloads
// ---------------------------------------------------------------------------

/// A successfully-decoded chat-meta envelope.
class ChatMetaEnvelope {
  /// Op code (`ChatMetaOps.*`).
  final int op;

  /// Raw payload bytes, len-prefixed by the envelope. Caller decodes
  /// op-specific structure via [ChatMetaReplyPayload.parse] etc.
  final Uint8List payload;

  /// The trailing human-readable summary (after `[/mrrp]`), with the
  /// leading separator space already stripped. Empty when the
  /// sender omitted the fallback summary (D34+ feature, NOT in D33;
  /// every D33 sender includes a summary).
  final String summary;

  const ChatMetaEnvelope({
    required this.op,
    required this.payload,
    required this.summary,
  });
}

/// Decoded REPLY payload (`op = 0x02`).
class ChatMetaReplyPayload {
  /// MMF the reply targets.
  final MeshCoreMmf target;

  /// Reply text, exactly as the sender typed it.
  final String body;

  const ChatMetaReplyPayload({required this.target, required this.body});

  /// Parse a REPLY payload (op-payload bytes, NOT the full envelope).
  /// Returns null on malformed input.
  static ChatMetaReplyPayload? parse(Uint8List payload) {
    if (payload.isEmpty) return null;
    // First byte tells us how long the MMF is.
    final scope = payload[0];
    final mmfLen = switch (scope) {
      MmfScope.channel => 6,
      MmfScope.contact => 11,
      _ => -1,
    };
    if (mmfLen < 0) return null;
    if (payload.length < mmfLen) return null;
    final mmf = MeshCoreMmf.parse(payload.sublist(0, mmfLen));
    if (mmf == null) return null;
    final body = utf8.decode(payload.sublist(mmfLen), allowMalformed: true);
    return ChatMetaReplyPayload(target: mmf, body: body);
  }

  /// Encode this payload to envelope-payload bytes (NOT the full
  /// envelope; the caller wraps with [ChatMetaEnvelopeCodec.encode]).
  Uint8List toBytes() {
    final builder = BytesBuilder();
    builder.add(target.toBytes());
    builder.add(utf8.encode(body));
    return builder.toBytes();
  }
}

/// Decoded HELLO payload (`op = 0x00`). D33 ships the codec but does
/// not trigger HELLO sends. Receivers persist `cap_bits` for future
/// fallback-summary suppression decisions.
class ChatMetaHelloPayload {
  /// Bit 0 = supports replies. Bit 1 reserved for D34 reactions.
  /// Bits 2..15 reserved.
  final int capBits;

  const ChatMetaHelloPayload({required this.capBits});

  bool get supportsReplies => (capBits & 0x01) != 0;
  bool get supportsReactions => (capBits & 0x02) != 0;

  static ChatMetaHelloPayload? parse(Uint8List payload) {
    if (payload.length < 3) return null;
    final caps = ByteData.sublistView(
      payload,
      0,
      2,
    ).getUint16(0, Endian.little);
    return ChatMetaHelloPayload(capBits: caps);
  }

  Uint8List toBytes() {
    final out = Uint8List(3);
    ByteData.sublistView(out).setUint16(0, capBits, Endian.little);
    out[2] = 0x00; // reserved
    return out;
  }
}

// ---------------------------------------------------------------------------
// Envelope codec
// ---------------------------------------------------------------------------

/// Result of attempting to decode a wire text body.
class ChatMetaDecodeResult {
  /// Set when an envelope was successfully extracted. Null when the
  /// body was plain text (no chat-meta envelope present).
  final ChatMetaEnvelope? envelope;

  /// True iff the receiver should treat the message as a regular
  /// plain-text message (no envelope, OR envelope failed to decode
  /// and the body is rendered as-is).
  final bool isPlainText;

  /// The "display text" the receiver should render in the chat
  /// bubble. For plain-text messages this is the raw body. For
  /// successfully-decoded reply envelopes this is the empty string
  /// (caller renders via `replyPayload.body`). For decode failures
  /// this is the trimmed remainder of the body so the user sees
  /// SOMETHING readable rather than envelope bytes.
  final String displayText;

  const ChatMetaDecodeResult.plain(this.displayText)
    : envelope = null,
      isPlainText = true;

  const ChatMetaDecodeResult.envelope({
    required ChatMetaEnvelope this.envelope,
    required this.displayText,
  }) : isPlainText = false;
}

/// The chat-meta envelope codec — encode + decode helpers.
class ChatMetaEnvelopeCodec {
  ChatMetaEnvelopeCodec._();

  // -------------------------------------------------------------------
  // Encode
  // -------------------------------------------------------------------

  /// Encode a REPLY envelope into a full text body string the caller
  /// passes to `_buildSendTextMsgFrame` / `_buildSendChannelTextMsgFrame`.
  ///
  /// [target] is the MMF of the message being replied to.
  /// [body] is the reply text.
  /// [summary] is the human-readable fallback summary appended after
  /// `[/mrrp]` so non-SocialMesh clients see comprehensible text.
  /// Senders should construct it as e.g. `"$senderName replied: …"`.
  /// Empty summaries are accepted but discouraged; D33 always supplies
  /// one.
  ///
  /// Returns the assembled wire text body.
  /// Throws [ArgumentError] when the resulting body would exceed
  /// [kChatMetaMaxOtaTextBytes]. Senders should truncate the body
  /// before calling rather than catching the throw.
  static String encodeReply({
    required MeshCoreMmf target,
    required String body,
    required String summary,
  }) {
    final inner = _packEnvelope(
      op: ChatMetaOps.reply,
      payload: ChatMetaReplyPayload(target: target, body: body).toBytes(),
    );
    return _wrapFallback(inner, summary);
  }

  /// Encode a HELLO envelope. D33 ships the codec but does not
  /// trigger HELLO sends.
  ///
  /// Visible for testing / future implementation.
  static String encodeHello({
    required ChatMetaHelloPayload payload,
    required String summary,
  }) {
    final inner = _packEnvelope(
      op: ChatMetaOps.hello,
      payload: payload.toBytes(),
    );
    return _wrapFallback(inner, summary);
  }

  // -------------------------------------------------------------------
  // Decode
  // -------------------------------------------------------------------

  /// Try to decode an inbound text body.
  ///
  /// On a plain text message: returns
  /// `ChatMetaDecodeResult.plain(body)`.
  ///
  /// On a recognised envelope: extracts the structured payload and
  /// returns `ChatMetaDecodeResult.envelope(...)` with `displayText`
  /// set to the trimmed-and-stripped string the receiver should
  /// render (typically empty for replies — the caller pulls the
  /// reply body out of the envelope payload itself).
  ///
  /// On a malformed envelope (bad version, bad svc, bad len, etc.)
  /// the result is `ChatMetaDecodeResult.plain(body)` so the chat
  /// renderer falls through to plain text.
  ///
  /// Detection is anchored at offset 0 of the body so a user message
  /// containing the literal `[mrrp]` mid-string is NOT mis-detected.
  static ChatMetaDecodeResult decode(String body) {
    if (!body.startsWith(kFallbackPrefix)) {
      return ChatMetaDecodeResult.plain(body);
    }
    final suffixIdx = body.indexOf(kFallbackSuffix, kFallbackPrefix.length);
    if (suffixIdx < 0) {
      AppLogging.meshcore('event=chat_meta.decode.rejected reason=no_suffix');
      return ChatMetaDecodeResult.plain(body);
    }

    final base64Text = body.substring(kFallbackPrefix.length, suffixIdx);
    Uint8List inner;
    try {
      inner = base64Url.decode(_padBase64(base64Text));
    } on FormatException {
      AppLogging.meshcore(
        'event=chat_meta.decode.rejected reason=base64_decode_failed',
      );
      return ChatMetaDecodeResult.plain(body);
    }

    final envelope = _unpackEnvelope(inner);
    if (envelope == null) {
      // Bad inner envelope: still strip the wrapper so the user sees
      // the human summary (less ugly than raw base64).
      final summary = _readSummary(body, suffixIdx);
      return ChatMetaDecodeResult.plain(summary.isNotEmpty ? summary : body);
    }

    // Successful envelope decode. The bubble-display text is empty
    // for replies (caller pulls body from the payload). For unknown
    // ops it falls back to the human summary so the bubble is at
    // least readable.
    final summary = _readSummary(body, suffixIdx);
    final displayText = (envelope.op == ChatMetaOps.reply) ? '' : summary;
    return ChatMetaDecodeResult.envelope(
      envelope: ChatMetaEnvelope(
        op: envelope.op,
        payload: envelope.payload,
        summary: summary,
      ),
      displayText: displayText,
    );
  }

  // -------------------------------------------------------------------
  // Internal — pack / unpack the inner envelope (magic..payload)
  // -------------------------------------------------------------------

  /// Internal helper: build the inner envelope bytes (everything
  /// inside `[mrrp]…[/mrrp]`, base64url encoded by the caller).
  static Uint8List _packEnvelope({
    required int op,
    required Uint8List payload,
  }) {
    if (payload.length > kChatMetaMaxPayloadBytes) {
      throw ArgumentError.value(
        payload.length,
        'payload.length',
        'must be <= $kChatMetaMaxPayloadBytes',
      );
    }
    final builder = BytesBuilder();
    builder.add(kChatMetaMagic);
    builder.addByte(kChatMetaVersion);
    builder.addByte(kChatMetaSvc);
    builder.addByte(op);
    builder.addByte(payload.length);
    builder.add(payload);
    return builder.toBytes();
  }

  /// Internal helper: parse an inner envelope's bytes. Returns null
  /// when the magic / version / svc / len fields don't match.
  static _UnpackedEnvelope? _unpackEnvelope(Uint8List bytes) {
    if (bytes.length < 9) return null; // 5 magic + 4 header

    for (var i = 0; i < kChatMetaMagic.length; i++) {
      if (bytes[i] != kChatMetaMagic[i]) {
        return null;
      }
    }
    final version = bytes[5];
    if (version != kChatMetaVersion) {
      AppLogging.meshcore(
        'event=chat_meta.decode.rejected reason=version_mismatch '
        'got=0x${version.toRadixString(16)} '
        'want=0x${kChatMetaVersion.toRadixString(16)}',
      );
      return null;
    }
    final svc = bytes[6];
    if (svc != kChatMetaSvc) {
      AppLogging.meshcore(
        'event=chat_meta.decode.rejected reason=svc_mismatch '
        'got=0x${svc.toRadixString(16)}',
      );
      return null;
    }
    final op = bytes[7];
    final len = bytes[8];
    if (len > kChatMetaMaxPayloadBytes) {
      AppLogging.meshcore(
        'event=chat_meta.decode.rejected reason=len_over_cap len=$len',
      );
      return null;
    }
    if (bytes.length < 9 + len) {
      AppLogging.meshcore(
        'event=chat_meta.decode.rejected reason=truncated_payload '
        'declared=$len got=${bytes.length - 9}',
      );
      return null;
    }

    // D33 v0.1 only knows HELLO and REPLY. REACTION (0x01) is reserved
    // for D34 — reject explicitly so an early-shipping reaction frame
    // doesn't mis-render.
    if (op == ChatMetaOps.reactionReservedD34) {
      AppLogging.meshcore(
        'event=chat_meta.decode.rejected reason=reaction_d34_reserved',
      );
      return null;
    }
    // Forward-compat: unknown ops in `0x03..0xFF` are rejected here
    // (caller falls through to plain text). Future ops bump version
    // OR add explicit handling.
    if (op != ChatMetaOps.hello && op != ChatMetaOps.reply) {
      AppLogging.meshcore(
        'event=chat_meta.decode.rejected reason=unknown_op '
        'op=0x${op.toRadixString(16)}',
      );
      return null;
    }

    return _UnpackedEnvelope(
      op: op,
      payload: Uint8List.fromList(bytes.sublist(9, 9 + len)),
    );
  }

  // -------------------------------------------------------------------
  // Internal — fallback wrapper
  // -------------------------------------------------------------------

  static String _wrapFallback(Uint8List inner, String summary) {
    final base64Text = base64Url.encode(inner).replaceAll('=', '');
    final body = '$kFallbackPrefix$base64Text$kFallbackSuffix';
    final trimmedSummary = _trimSummary(summary);
    final result = trimmedSummary.isEmpty ? body : '$body $trimmedSummary';
    if (utf8.encode(result).length > kChatMetaMaxOtaTextBytes) {
      throw ArgumentError(
        'chat-meta envelope body would exceed '
        '$kChatMetaMaxOtaTextBytes bytes; truncate inputs',
      );
    }
    return result;
  }

  static String _readSummary(String body, int suffixIdx) {
    final after = body.substring(suffixIdx + kFallbackSuffix.length);
    if (after.isEmpty) return '';
    if (after.startsWith(' ')) return after.substring(1);
    return after;
  }

  static String _trimSummary(String s) {
    final encoded = utf8.encode(s);
    if (encoded.length <= kChatMetaSummaryMaxBytes) return s;
    // Truncate at byte boundary that respects UTF-8 — find the last
    // safe break.
    var cut = kChatMetaSummaryMaxBytes;
    while (cut > 0 && (encoded[cut] & 0xC0) == 0x80) {
      cut--;
    }
    return utf8.decode(encoded.sublist(0, cut), allowMalformed: true);
  }

  /// Re-pad a base64url string that was emitted without `=` padding.
  static String _padBase64(String s) {
    final remainder = s.length % 4;
    if (remainder == 0) return s;
    return '$s${'=' * (4 - remainder)}';
  }
}

class _UnpackedEnvelope {
  final int op;
  final Uint8List payload;
  const _UnpackedEnvelope({required this.op, required this.payload});
}
