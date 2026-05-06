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
class TextMessagePayloadSizer {
  TextMessagePayloadSizer.standard({this.replyId, this.isEmoji = false})
    : maxUtf8Bytes = _resolveMaxUtf8Bytes(replyId: replyId, isEmoji: isEmoji);

  static final int maxEncodedDataBytes = mesh.Constants.DATA_PAYLOAD_LEN.value;

  final int? replyId;
  final bool isEmoji;
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

  static int resolveMaxUtf8Bytes({int? replyId, bool isEmoji = false}) =>
      _resolveMaxUtf8Bytes(replyId: replyId, isEmoji: isEmoji);

  static int _resolveMaxUtf8Bytes({int? replyId, required bool isEmoji}) {
    var low = 0;
    var high = maxEncodedDataBytes;

    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      final size = _encodedDataSize(
        payload: Uint8List(mid),
        replyId: replyId,
        isEmoji: isEmoji,
      );
      if (size <= maxEncodedDataBytes) {
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
