// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import '../protocol/socialmesh/sm_file_transfer.dart';
import 'spp_constants.dart';

/// SPP v1 ACCEPT packet — receiver accepts an offered transfer.
///
/// Wire format:
/// ```
/// [header:1][payloadId:16]
/// ```
/// Total: 17 bytes.
class SppAccept {
  /// The payloadId of the accepted offer.
  final Uint8List payloadId;

  const SppAccept({required this.payloadId});

  /// Encode to wire format.
  Uint8List? encode() {
    if (payloadId.length != 16) return null;

    final buffer = Uint8List(17);
    buffer[0] = (SppVersion.current << 4) | SppPacketKind.accept;
    buffer.setRange(1, 17, payloadId);
    return buffer;
  }

  /// Decode from wire format.
  static SppAccept? decode(Uint8List data) {
    if (data.length < 17) return null;

    final kind = data[0] & 0x0F;
    if (kind != SppPacketKind.accept) return null;

    return SppAccept(payloadId: Uint8List.fromList(data.sublist(1, 17)));
  }

  /// Hex representation of the payloadId.
  String get payloadIdHex => fileIdToHex(payloadId);
}

/// SPP v1 DECLINE packet — receiver rejects an offered transfer.
///
/// Wire format:
/// ```
/// [header:1][payloadId:16][reason:1]
/// ```
/// Total: 18 bytes.
class SppDecline {
  /// The payloadId of the declined offer.
  final Uint8List payloadId;

  /// Decline reason code (see [SppDeclineReason]).
  final int reason;

  const SppDecline({required this.payloadId, required this.reason});

  /// Encode to wire format.
  Uint8List? encode() {
    if (payloadId.length != 16) return null;

    final buffer = Uint8List(18);
    buffer[0] = (SppVersion.current << 4) | SppPacketKind.decline;
    buffer.setRange(1, 17, payloadId);
    buffer[17] = reason;
    return buffer;
  }

  /// Decode from wire format.
  static SppDecline? decode(Uint8List data) {
    if (data.length < 18) return null;

    final kind = data[0] & 0x0F;
    if (kind != SppPacketKind.decline) return null;

    return SppDecline(
      payloadId: Uint8List.fromList(data.sublist(1, 17)),
      reason: data[17],
    );
  }

  /// Hex representation of the payloadId.
  String get payloadIdHex => fileIdToHex(payloadId);
}

/// SPP v1 ABORT packet — cancel an in-progress transfer.
///
/// Wire format:
/// ```
/// [header:1][payloadId:16][reason:1]
/// ```
/// Total: 18 bytes.
class SppAbort {
  /// The payloadId of the transfer to abort.
  final Uint8List payloadId;

  /// Abort reason code (see [SppAbortReason]).
  final int reason;

  const SppAbort({required this.payloadId, required this.reason});

  /// Encode to wire format.
  Uint8List? encode() {
    if (payloadId.length != 16) return null;

    final buffer = Uint8List(18);
    buffer[0] = (SppVersion.current << 4) | SppPacketKind.abort;
    buffer.setRange(1, 17, payloadId);
    buffer[17] = reason;
    return buffer;
  }

  /// Decode from wire format.
  static SppAbort? decode(Uint8List data) {
    if (data.length < 18) return null;

    final kind = data[0] & 0x0F;
    if (kind != SppPacketKind.abort) return null;

    return SppAbort(
      payloadId: Uint8List.fromList(data.sublist(1, 17)),
      reason: data[17],
    );
  }

  /// Hex representation of the payloadId.
  String get payloadIdHex => fileIdToHex(payloadId);
}

/// Decode any SPP v1 negotiation packet (ACCEPT, DECLINE, ABORT).
///
/// Returns the decoded packet, or null if the data is not a valid
/// SPP v1 negotiation packet.
Object? decodeSppNegotiation(Uint8List data) {
  if (data.isEmpty) return null;

  final kind = data[0] & 0x0F;
  return switch (kind) {
    SppPacketKind.accept => SppAccept.decode(data),
    SppPacketKind.decline => SppDecline.decode(data),
    SppPacketKind.abort => SppAbort.decode(data),
    _ => null,
  };
}

/// Check whether a payload is an SPP packet (v0 or v1).
///
/// SPP packets have kind nibble in range [0x04, 0x0A].
bool isSppPayload(Uint8List data) {
  if (data.isEmpty) return false;
  final kind = data[0] & 0x0F;
  return SppPacketKind.isValid(kind);
}

/// Check whether a payload is specifically an SPP v1 negotiation packet
/// (ACCEPT, DECLINE, or ABORT).
bool isSppNegotiationPayload(Uint8List data) {
  if (data.isEmpty) return false;
  final kind = data[0] & 0x0F;
  return kind == SppPacketKind.accept ||
      kind == SppPacketKind.decline ||
      kind == SppPacketKind.abort;
}
