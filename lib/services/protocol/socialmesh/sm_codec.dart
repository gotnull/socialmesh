// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'sm_constants.dart';
import 'sm_identity.dart';
import 'sm_presence.dart';
import 'sm_signal.dart';

/// Discriminator for decoded SM packet types.
enum SmPacketType { presence, signal, identity }

/// A decoded Socialmesh extension packet.
///
/// Use [SmCodec.decode] to obtain an instance, then switch on [type]
/// and cast [payload] to the appropriate class.
class SmPacket {
  final SmPacketType type;
  final Object payload;

  const SmPacket._(this.type, this.payload);

  /// Cast payload to [SmPresence]. Only valid when [type] == presence.
  SmPresence get presence => payload as SmPresence;

  /// Cast payload to [SmSignal]. Only valid when [type] == signal.
  SmSignal get signal => payload as SmSignal;

  /// Cast payload to [SmIdentity]. Only valid when [type] == identity.
  SmIdentity get identity => payload as SmIdentity;
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
      default:
        return const Duration(seconds: 30);
    }
  }
}
