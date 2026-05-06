// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Inbound MeshCore message frame parsers.
//
// These parsers decode `MeshCoreFrame` payloads into typed value objects
// that the chat UI can render directly. They were extracted out of the
// chat widget so unit tests can feed canned firmware-shaped bytes
// without spinning a Flutter widget tree.
//
// Wire formats below mirror the canonical firmware source at
// `MeshCore/examples/companion_radio/MyMesh.cpp` (D12 recon). The app
// sends `appProtocolVersion = 3` to firmware, so V3 shapes are the
// production case. Legacy shapes are kept for older firmware builds the
// user might still be carrying.
//
// CRITICAL: do NOT invent a sender public-key field for these
// responses. Firmware contact frames include only the first 6 bytes of
// the sender pubkey, and channel frames include no sender identity at
// all (channel messages are flooded). The pre-D12 chat widget assumed
// a fictional 32-byte sender field, dropped every V3 frame at the
// length guard, and silently failed every contact match by comparing a
// 12-char prefix to a 64-char full hex.

import 'dart:convert';
import 'dart:typed_data';

import '../../../core/meshcore_constants.dart';
import '../../../services/meshcore/protocol/meshcore_frame.dart';

/// Discriminates legacy vs V3 firmware frame layouts.
enum MeshCoreMessageProtocol {
  /// `RESP_CODE_*_MSG_RECV` (0x07 / 0x08). No SNR / reserved prefix.
  legacy,

  /// `RESP_CODE_*_MSG_RECV_V3` (0x10 / 0x11). Carries SNR + reserved
  /// header before the payload body.
  v3,
}

/// Parsed channel-receive frame. Channel messages are flooded over the
/// mesh and carry no sender identity in firmware; the sender is
/// inferred from the topology (or shown anonymously) by the UI layer.
class MeshCoreChannelMessageFrame {
  final MeshCoreMessageProtocol protocol;

  /// Raw firmware SNR byte (signed int8) multiplied by 4 (units:
  /// quarter-dB). Null on legacy frames where the field is absent.
  /// Convert with `snr = snrQuarter / 4.0` for dB.
  final int? snrQuarter;

  /// Channel slot 0..7.
  final int channelIndex;

  /// LoRa path length, or `0xFF` if firmware reports the message took
  /// the direct (non-flood) path.
  final int pathLen;

  /// `TXT_TYPE_*` byte. Currently only `TXT_TYPE_PLAIN` is rendered.
  final int txtType;

  /// Sender-set firmware timestamp (seconds since epoch).
  final DateTime timestamp;

  /// UTF-8 message body.
  final String text;

  const MeshCoreChannelMessageFrame({
    required this.protocol,
    required this.snrQuarter,
    required this.channelIndex,
    required this.pathLen,
    required this.txtType,
    required this.timestamp,
    required this.text,
  });
}

/// Parsed contact-receive frame. Sender identity is firmware-supplied
/// as a 6-byte public-key prefix (12 lowercase hex chars). The UI
/// matches incoming frames to a known contact by prefix-matching the
/// contact's full hex pubkey.
class MeshCoreContactMessageFrame {
  final MeshCoreMessageProtocol protocol;
  final int? snrQuarter;

  /// Lowercase hex of the firmware-supplied 6-byte sender pubkey
  /// prefix. Always exactly 12 chars.
  final String senderPrefixHex;

  final int pathLen;
  final int txtType;
  final DateTime timestamp;
  final String text;

  const MeshCoreContactMessageFrame({
    required this.protocol,
    required this.snrQuarter,
    required this.senderPrefixHex,
    required this.pathLen,
    required this.txtType,
    required this.timestamp,
    required this.text,
  });
}

/// Result of a parse attempt. Either [value] is non-null and
/// [rejectReason] is null, or vice versa. The reason string is for
/// observability logs, not for end users.
class MeshCoreFrameParseResult<T> {
  final T? value;
  final String? rejectReason;

  const MeshCoreFrameParseResult.ok(T this.value) : rejectReason = null;
  const MeshCoreFrameParseResult.rejected(String this.rejectReason)
    : value = null;

  bool get ok => value != null;
}

/// Static parsers for inbound channel + contact message frames.
class MeshCoreMessageFrameParser {
  MeshCoreMessageFrameParser._();

  /// V3 channel `payload[0]` is the SNR byte. The channel index lives
  /// at `payload[3]`. See [MeshCoreChannelMessageFrame] for the full
  /// layout.
  static const int _v3ChannelMinLen = 10;

  /// Legacy channel `payload[0]` is the channel index directly. Text
  /// starts at `payload[7]`.
  static const int _legacyChannelMinLen = 7;

  /// V3 contact `payload[0]` is the SNR byte. Sender prefix lives at
  /// `payload[3..8]`. Text starts at `payload[15]` for a plaintext
  /// message; signed messages may carry an extra 4-byte sender prefix
  /// before text but we do not yet render those.
  static const int _v3ContactMinLen = 15;

  /// Legacy contact carries the 6-byte sender prefix at the front,
  /// followed by path/txt/timestamp.
  static const int _legacyContactMinLen = 12;

  /// Parse a frame whose `command` is one of
  /// [MeshCoreResponses.channelMsgRecv] or
  /// [MeshCoreResponses.channelMsgRecvV3].
  ///
  /// Returns a rejected result for unknown command codes or undersized
  /// payloads. Never returns a partially-populated value.
  static MeshCoreFrameParseResult<MeshCoreChannelMessageFrame>
  parseChannelMessage(MeshCoreFrame frame) {
    final code = frame.command;
    final p = frame.payload;

    if (code == MeshCoreResponses.channelMsgRecvV3) {
      if (p.length < _v3ChannelMinLen) {
        return MeshCoreFrameParseResult.rejected(
          'v3_channel_too_short len=${p.length} min=$_v3ChannelMinLen',
        );
      }
      // signed int8 SNR per firmware: `(int8_t)(getSNR() * 4)`.
      final snrQuarter = _toSignedInt8(p[0]);
      // p[1..2] are reserved zeros and unused here.
      final channelIndex = p[3];
      final pathLen = p[4];
      final txtType = p[5];
      final tsRaw = _readUint32LE(p, 6);
      final text = _decodeText(p, 10);
      return MeshCoreFrameParseResult.ok(
        MeshCoreChannelMessageFrame(
          protocol: MeshCoreMessageProtocol.v3,
          snrQuarter: snrQuarter,
          channelIndex: channelIndex,
          pathLen: pathLen,
          txtType: txtType,
          timestamp: _epochSecondsToDateTime(tsRaw),
          text: text,
        ),
      );
    }

    if (code == MeshCoreResponses.channelMsgRecv) {
      if (p.length < _legacyChannelMinLen) {
        return MeshCoreFrameParseResult.rejected(
          'legacy_channel_too_short len=${p.length} '
          'min=$_legacyChannelMinLen',
        );
      }
      final channelIndex = p[0];
      final pathLen = p[1];
      final txtType = p[2];
      final tsRaw = _readUint32LE(p, 3);
      final text = _decodeText(p, 7);
      return MeshCoreFrameParseResult.ok(
        MeshCoreChannelMessageFrame(
          protocol: MeshCoreMessageProtocol.legacy,
          snrQuarter: null,
          channelIndex: channelIndex,
          pathLen: pathLen,
          txtType: txtType,
          timestamp: _epochSecondsToDateTime(tsRaw),
          text: text,
        ),
      );
    }

    return MeshCoreFrameParseResult.rejected(
      'unknown_channel_command 0x${code.toRadixString(16).padLeft(2, '0')}',
    );
  }

  /// Parse a frame whose `command` is one of
  /// [MeshCoreResponses.contactMsgRecv] or
  /// [MeshCoreResponses.contactMsgRecvV3].
  static MeshCoreFrameParseResult<MeshCoreContactMessageFrame>
  parseContactMessage(MeshCoreFrame frame) {
    final code = frame.command;
    final p = frame.payload;

    if (code == MeshCoreResponses.contactMsgRecvV3) {
      if (p.length < _v3ContactMinLen) {
        return MeshCoreFrameParseResult.rejected(
          'v3_contact_too_short len=${p.length} min=$_v3ContactMinLen',
        );
      }
      final snrQuarter = _toSignedInt8(p[0]);
      // p[1..2] reserved.
      final senderPrefixHex = _hexLower(p, 3, 6);
      final pathLen = p[9];
      final txtType = p[10];
      final tsRaw = _readUint32LE(p, 11);
      final text = _decodeText(p, 15);
      return MeshCoreFrameParseResult.ok(
        MeshCoreContactMessageFrame(
          protocol: MeshCoreMessageProtocol.v3,
          snrQuarter: snrQuarter,
          senderPrefixHex: senderPrefixHex,
          pathLen: pathLen,
          txtType: txtType,
          timestamp: _epochSecondsToDateTime(tsRaw),
          text: text,
        ),
      );
    }

    if (code == MeshCoreResponses.contactMsgRecv) {
      if (p.length < _legacyContactMinLen) {
        return MeshCoreFrameParseResult.rejected(
          'legacy_contact_too_short len=${p.length} '
          'min=$_legacyContactMinLen',
        );
      }
      final senderPrefixHex = _hexLower(p, 0, 6);
      final pathLen = p[6];
      final txtType = p[7];
      final tsRaw = _readUint32LE(p, 8);
      final text = _decodeText(p, 12);
      return MeshCoreFrameParseResult.ok(
        MeshCoreContactMessageFrame(
          protocol: MeshCoreMessageProtocol.legacy,
          snrQuarter: null,
          senderPrefixHex: senderPrefixHex,
          pathLen: pathLen,
          txtType: txtType,
          timestamp: _epochSecondsToDateTime(tsRaw),
          text: text,
        ),
      );
    }

    return MeshCoreFrameParseResult.rejected(
      'unknown_contact_command 0x${code.toRadixString(16).padLeft(2, '0')}',
    );
  }

  /// True if [contactPublicKeyHex] starts with the firmware-supplied
  /// 6-byte prefix (12 lowercase hex chars). Used by the chat UI to
  /// route an inbound contact message to the open conversation.
  static bool senderPrefixMatches({
    required String contactPublicKeyHex,
    required String senderPrefixHex,
  }) {
    if (senderPrefixHex.length != 12) return false;
    if (contactPublicKeyHex.length < 12) return false;
    final contactPrefix = contactPublicKeyHex.substring(0, 12).toLowerCase();
    return contactPrefix == senderPrefixHex.toLowerCase();
  }

  /// Decode raw byte at [b] (0..255) as a signed int8 (-128..127).
  static int _toSignedInt8(int b) => b < 128 ? b : b - 256;

  static int _readUint32LE(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  /// Decode UTF-8 text starting at [offset]. Strips a single trailing
  /// null if firmware happened to include one (legacy builds did),
  /// otherwise returns the full slice. Lossy on invalid UTF-8 so a
  /// glitched byte does not blank the entire bubble.
  static String _decodeText(Uint8List bytes, int offset) {
    if (offset >= bytes.length) return '';
    var end = bytes.length;
    if (end > offset && bytes[end - 1] == 0) end -= 1;
    final slice = bytes.sublist(offset, end);
    return utf8.decode(slice, allowMalformed: true);
  }

  static String _hexLower(Uint8List bytes, int start, int len) {
    final buf = StringBuffer();
    for (var i = 0; i < len; i++) {
      buf.write(bytes[start + i].toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }

  static DateTime _epochSecondsToDateTime(int seconds) {
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
}
