// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import '../../payload/spp_protocol.dart';
import 'sm_constants.dart';
import 'sm_file_transfer.dart';
import 'sm_identity.dart';
import 'sm_presence.dart';
import 'sm_signal.dart';

/// Discriminator for decoded SM packet types.
enum SmPacketType {
  presence,
  signal,
  identity,
  fileOffer,
  fileChunk,
  fileNack,
  fileAck,
  sppAccept,
  sppDecline,
  sppAbort,
  feedPost,
}

/// A decoded Socialmesh extension packet.
///
/// Use [SmCodec.decode] to obtain an instance, then switch on [type]
/// and cast [payload] to the appropriate class.
class SmPacket {
  final SmPacketType type;
  final Object payload;

  /// Protocol version from the header byte (bits 7-4). Defaults to 0.
  final int version;

  const SmPacket._(this.type, this.payload, [this.version = 0]);

  /// Cast payload to [SmPresence]. Only valid when [type] == presence.
  SmPresence get presence => payload as SmPresence;

  /// Cast payload to [SmSignal]. Only valid when [type] == signal.
  SmSignal get signal => payload as SmSignal;

  /// Cast payload to [SmIdentity]. Only valid when [type] == identity.
  SmIdentity get identity => payload as SmIdentity;

  /// Cast payload to [SmFileOffer]. Only valid when [type] == fileOffer.
  SmFileOffer get fileOffer => payload as SmFileOffer;

  /// Cast payload to [SmFileChunk]. Only valid when [type] == fileChunk.
  SmFileChunk get fileChunk => payload as SmFileChunk;

  /// Cast payload to [SmFileNack]. Only valid when [type] == fileNack.
  SmFileNack get fileNack => payload as SmFileNack;

  /// Cast payload to [SmFileAck]. Only valid when [type] == fileAck.
  SmFileAck get fileAck => payload as SmFileAck;

  /// Cast payload to [SppAccept]. Only valid when [type] == sppAccept.
  SppAccept get sppAccept => payload as SppAccept;

  /// Cast payload to [SppDecline]. Only valid when [type] == sppDecline.
  SppDecline get sppDecline => payload as SppDecline;

  /// Cast payload to [SppAbort]. Only valid when [type] == sppAbort.
  SppAbort get sppAbort => payload as SppAbort;

  /// Cast payload to raw [Uint8List]. Only valid when [type] == feedPost.
  /// The raw bytes are the full wire payload (header + body) for
  /// further decoding by [MeshPost.decodeFromLora].
  Uint8List get feedPostPayload => payload as Uint8List;
}

/// Top-level codec for Socialmesh extension packets.
///
/// Routes incoming packets to the correct sub-codec based on portnum,
/// and provides encoding helpers.
class SmCodec {
  const SmCodec._();

  /// Returns true if [portnum] is a Socialmesh extension portnum.
  static bool isSocialmeshPortnum(int portnum) =>
      SmPortnum.isSocialmesh(portnum);

  /// Decode a raw payload from a Meshtastic MeshPacket's `Data.payload`.
  ///
  /// [portnum] is the portnum from the `Data` protobuf field.
  /// [data] is the raw payload bytes.
  ///
  /// Returns null if:
  /// - The portnum is not a Socialmesh extension portnum
  /// - The payload is malformed or has an unsupported version
  static SmPacket? decode(int portnum, Uint8List data) {
    switch (portnum) {
      case SmPortnum.presence:
        final p = SmPresence.decode(data);
        if (p == null) return null;
        return SmPacket._(SmPacketType.presence, p);

      case SmPortnum.signal:
        final s = SmSignal.decode(data);
        if (s == null) return null;
        return SmPacket._(SmPacketType.signal, s);

      case SmPortnum.identity:
        final i = SmIdentity.decode(data);
        if (i == null) return null;
        return SmPacket._(SmPacketType.identity, i);

      case SmPortnum.fileTransfer:
        return decodeFileTransfer(data);

      case SmPortnum.feedPost:
        return decodeFeedPost(data);

      default:
        return null;
    }
  }

  /// Encode a presence packet to bytes, ready for `Data.payload`.
  static Uint8List? encodePresence(SmPresence presence) => presence.encode();

  /// Encode a signal packet to bytes, ready for `Data.payload`.
  static Uint8List? encodeSignal(SmSignal signal) => signal.encode();

  /// Encode an identity packet to bytes, ready for `Data.payload`.
  static Uint8List? encodeIdentity(SmIdentity identity) => identity.encode();

  /// Encode a file offer to bytes, ready for `Data.payload`.
  static Uint8List? encodeFileOffer(SmFileOffer offer) => offer.encode();

  /// Encode a file chunk to bytes, ready for `Data.payload`.
  static Uint8List? encodeFileChunk(SmFileChunk chunk) => chunk.encode();

  /// Encode a file NACK to bytes, ready for `Data.payload`.
  static Uint8List? encodeFileNack(SmFileNack nack) => nack.encode();

  /// Encode a file ACK to bytes, ready for `Data.payload`.
  static Uint8List? encodeFileAck(SmFileAck ack) => ack.encode();

  /// Decode a feed post payload (portnum 264).
  ///
  /// Validates the header kind nibble matches SM_FEED_POST (0x0B).
  /// Returns the raw payload wrapped in an [SmPacket] for routing;
  /// final decode to [MeshPost] happens in the handler (which supplies
  /// the author node number from the MeshPacket envelope).
  static SmPacket? decodeFeedPost(Uint8List data) {
    // minimum: header + createdAtSec + flags + contentLen
    if (data.length < 7) {
      return null;
    }
    final kind = data[0] & 0x0F;
    if (kind != SmPacketKind.feedPost) return null;
    final version = (data[0] >> 4) & 0x0F;
    if (version > SmVersion.maxSupported) return null;
    return SmPacket._(SmPacketType.feedPost, Uint8List.fromList(data), version);
  }

  /// Returns true if [data] looks like a binary file-transfer payload
  /// (header kind nibble in 4..0xA, covering data + negotiation packets).
  ///
  /// Useful for distinguishing binary SM packets from legacy JSON signals
  /// when both arrive on PRIVATE_APP (256).
  static bool isFileTransferPayload(Uint8List data) {
    if (data.isEmpty) return false;
    final kind = data[0] & 0x0F;
    return kind >= SmPacketKind.fileOffer && kind <= SmPacketKind.sppAbort;
  }

  /// Decode file transfer sub-types by inspecting the header kind nibble.
  ///
  /// Public so that callers can decode file-transfer payloads arriving on
  /// PRIVATE_APP (256) without going through [decode].
  static SmPacket? decodeFileTransfer(Uint8List data) {
    if (data.isEmpty) return null;
    final version = (data[0] >> 4) & 0x0F;
    final kind = data[0] & 0x0F;
    switch (kind) {
      case SmPacketKind.fileOffer:
        final o = SmFileOffer.decode(data);
        if (o == null) return null;
        return SmPacket._(SmPacketType.fileOffer, o, version);
      case SmPacketKind.fileChunk:
        final c = SmFileChunk.decode(data);
        if (c == null) return null;
        return SmPacket._(SmPacketType.fileChunk, c, version);
      case SmPacketKind.fileNack:
        final n = SmFileNack.decode(data);
        if (n == null) return null;
        return SmPacket._(SmPacketType.fileNack, n, version);
      case SmPacketKind.fileAck:
        final a = SmFileAck.decode(data);
        if (a == null) return null;
        return SmPacket._(SmPacketType.fileAck, a, version);
      case SmPacketKind.sppAccept:
        final accept = SppAccept.decode(data);
        if (accept == null) return null;
        return SmPacket._(SmPacketType.sppAccept, accept, version);
      case SmPacketKind.sppDecline:
        final decline = SppDecline.decode(data);
        if (decline == null) return null;
        return SmPacket._(SmPacketType.sppDecline, decline, version);
      case SmPacketKind.sppAbort:
        final abort = SppAbort.decode(data);
        if (abort == null) return null;
        return SmPacket._(SmPacketType.sppAbort, abort, version);
      default:
        return null;
    }
  }
}

/// Tracks rate limits for outgoing SM packets per type.
///
/// Usage:
/// ```dart
/// final limiter = SmRateLimiter();
/// if (limiter.canSend(SmPortnum.presence)) {
///   // send the packet
///   limiter.recordSend(SmPortnum.presence);
/// }
/// ```
class SmRateLimiter {
  final Map<int, DateTime> _lastSent = {};

  /// Returns true if enough time has passed since the last send
  /// for the given [portnum].
  bool canSend(int portnum) {
    final last = _lastSent[portnum];
    if (last == null) return true;

    final interval = _intervalForPortnum(portnum);
    return DateTime.now().difference(last) >= interval;
  }

  /// Record that a packet was sent for [portnum] at the current time.
  void recordSend(int portnum) {
    _lastSent[portnum] = DateTime.now();
  }

  /// Returns the remaining cooldown duration, or [Duration.zero] if ready.
  Duration cooldownRemaining(int portnum) {
    final last = _lastSent[portnum];
    if (last == null) return Duration.zero;

    final interval = _intervalForPortnum(portnum);
    final elapsed = DateTime.now().difference(last);
    final remaining = interval - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Reset all rate limit state.
  void reset() => _lastSent.clear();

  Duration _intervalForPortnum(int portnum) {
    switch (portnum) {
      case SmPortnum.presence:
        return SmRateLimit.presenceInterval;
      case SmPortnum.signal:
        return SmRateLimit.signalInterval;
      case SmPortnum.identity:
        return SmRateLimit.identityBroadcastInterval;
      case SmPortnum.fileTransfer:
        return SmRateLimit.fileChunkInterval;
      case SmPortnum.feedPost:
        return SmRateLimit.feedPostInterval;
      default:
        return const Duration(seconds: 30);
    }
  }
}
