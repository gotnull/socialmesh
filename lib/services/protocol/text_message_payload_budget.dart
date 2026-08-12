// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';
import 'dart:typed_data';

import '../../generated/meshtastic/mesh.pb.dart' as pb;
import '../../generated/meshtastic/mesh.pbenum.dart' as mesh;
import '../../generated/meshtastic/portnums.pbenum.dart' as pn;

/// Size analysis for a standard Meshtastic text message draft.
class TextMessagePayloadBudget {
  const TextMessagePayloadBudget({
    required this.utf8Bytes,
    required this.maxUtf8Bytes,
    required this.encodedDataBytes,
    required this.maxEncodedDataBytes,
    required this.replyId,
    required this.isEmoji,
  });

  /// UTF-8 byte length of the current draft text.
  final int utf8Bytes;

  /// Maximum UTF-8 bytes that still fit for the current message shape.
  final int maxUtf8Bytes;

  /// Encoded `Data` protobuf size for the current draft.
  final int encodedDataBytes;

  /// Maximum allowed encoded `Data` size from Meshtastic shared constants.
  final int maxEncodedDataBytes;

  /// Reply target included in the message envelope, if any.
  final int? replyId;

  /// Whether the outgoing text is flagged as an emoji tapback.
  final bool isEmoji;

  bool get fitsInPacket => encodedDataBytes <= maxEncodedDataBytes;

  int get remainingUtf8Bytes => maxUtf8Bytes - utf8Bytes;
}

/// Thrown when a text message exceeds the allowed wire budget.
class TextMessagePayloadTooLargeException implements Exception {
  const TextMessagePayloadTooLargeException(this.budget);

  final TextMessagePayloadBudget budget;

  @override
  String toString() =>
      'TextMessagePayloadTooLargeException('
      'utf8Bytes=${budget.utf8Bytes}, '
      'maxUtf8Bytes=${budget.maxUtf8Bytes}, '
      'encodedDataBytes=${budget.encodedDataBytes}, '
      'maxEncodedDataBytes=${budget.maxEncodedDataBytes}, '
      'replyId=${budget.replyId}, '
      'isEmoji=${budget.isEmoji})';
}

/// Shared sizing rules for Meshtastic `TEXT_MESSAGE_APP` packets.
///
/// Meshtastic publishes the authoritative `DATA_PAYLOAD_LEN = 233` constant in
/// `mesh.proto`. Upstream Android validates the encoded `Data` protobuf against
/// that ceiling before sending. This helper mirrors that wire-level check so
/// SocialMesh's composer UI and send path rely on the same source of truth.
///
/// PKI-encrypted DMs carry extra crypto overhead on the wire, so their
/// encoded `Data` ceiling is lower — pass `pkiEncrypted: true` whenever the
/// send path will attach the recipient's public key, or the firmware NAKs
/// the packet with `Routing.Error.TOO_LARGE` even though the plain-text
/// budget looked fine.
class TextMessagePayloadSizer {
  TextMessagePayloadSizer.standard({
    this.replyId,
    this.isEmoji = false,
    this.pkiEncrypted = false,
  }) : maxEncodedDataBytes = resolveMaxEncodedDataBytes(
         pkiEncrypted: pkiEncrypted,
       ),
       maxUtf8Bytes = _resolveMaxUtf8Bytes(
         replyId: replyId,
         isEmoji: isEmoji,
         pkiEncrypted: pkiEncrypted,
       );

  /// Ceiling for the encoded `Data` protobuf on channel-PSK packets.
  static final int channelMaxEncodedDataBytes =
      mesh.Constants.DATA_PAYLOAD_LEN.value;

  // LoRa frame geometry mirrored from the Meshtastic firmware: 255-byte max
  // frame, 16-byte packet header, and 12 bytes reserved on PKI-encrypted
  // packets (8-byte auth tag + 4-byte extended nonce). Before running its
  // size check, the firmware also stamps `Data.bitfield` (field 9: the
  // ok-to-MQTT and want-response bits) onto every packet it originates,
  // which re-encodes 2 bytes larger than the `Data` the app measures here
  // (1 tag byte + 1 varint byte). The firmware rejects a PKI packet whose
  // re-encoded `Data` exceeds 255 - 16 - 12 = 227 bytes with
  // `Routing.Error.TOO_LARGE`, so the app-side ceiling is 227 - 2 = 225
  // encoded bytes. The channel-PSK path needs no bitfield reserve: its
  // firmware ceiling is 255 - 16 = 239, and `DATA_PAYLOAD_LEN` (233) plus
  // the bitfield still fits.
  static const int _maxLoraFrameBytes = 255;
  static const int _packetHeaderBytes = 16;
  static const int _pkcOverheadBytes = 12;
  static const int _firmwareBitfieldBytes = 2;

  /// Ceiling for the app-encoded `Data` protobuf on PKI-encrypted DMs.
  static const int pkiMaxEncodedDataBytes =
      _maxLoraFrameBytes -
      _packetHeaderBytes -
      _pkcOverheadBytes -
      _firmwareBitfieldBytes;

  static int resolveMaxEncodedDataBytes({required bool pkiEncrypted}) =>
      pkiEncrypted ? pkiMaxEncodedDataBytes : channelMaxEncodedDataBytes;

  final int? replyId;
  final bool isEmoji;
  final bool pkiEncrypted;
  final int maxEncodedDataBytes;
  final int maxUtf8Bytes;

  static bool hasSendableContent(String text) => text.trim().isNotEmpty;

  TextMessagePayloadBudget measure(String text) {
    final encodedText = utf8.encode(text);
    final encodedDataBytes = _encodedDataSize(
      payload: Uint8List.fromList(encodedText),
      replyId: replyId,
      isEmoji: isEmoji,
    );

    return TextMessagePayloadBudget(
      utf8Bytes: encodedText.length,
      maxUtf8Bytes: maxUtf8Bytes,
      encodedDataBytes: encodedDataBytes,
      maxEncodedDataBytes: maxEncodedDataBytes,
      replyId: replyId,
      isEmoji: isEmoji,
    );
  }

  static int utf8ByteLength(String text) => utf8.encode(text).length;

  static int resolveMaxUtf8Bytes({
    int? replyId,
    bool isEmoji = false,
    bool pkiEncrypted = false,
  }) => _resolveMaxUtf8Bytes(
    replyId: replyId,
    isEmoji: isEmoji,
    pkiEncrypted: pkiEncrypted,
  );

  static int _resolveMaxUtf8Bytes({
    int? replyId,
    required bool isEmoji,
    required bool pkiEncrypted,
  }) {
    final ceiling = resolveMaxEncodedDataBytes(pkiEncrypted: pkiEncrypted);
    var low = 0;
    var high = ceiling;

    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      final size = _encodedDataSize(
        payload: Uint8List(mid),
        replyId: replyId,
        isEmoji: isEmoji,
      );
      if (size <= ceiling) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }

    return low;
  }

  static int _encodedDataSize({
    required Uint8List payload,
    int? replyId,
    required bool isEmoji,
  }) {
    final data = pb.Data()
      ..portnum = pn.PortNum.TEXT_MESSAGE_APP
      ..payload = payload;

    if (replyId != null) {
      data.replyId = replyId;
    }
    if (isEmoji) {
      data.emoji = 1;
    }

    return data.writeToBuffer().length;
  }
}
