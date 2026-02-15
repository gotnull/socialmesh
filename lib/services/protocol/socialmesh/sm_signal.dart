// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'sm_constants.dart';

/// TTL class for signal expiry (3-bit wire encoding).
enum SmSignalTtl {
  minutes15, // 0
  minutes30, // 1
  hour1, // 2 (default)
  hours6, // 3
  hours24, // 4
}

/// Signal priority (3-bit wire encoding).
enum SmSignalPriority {
  normal, // 0 -> DEFAULT (64)
  important, // 1 -> RELIABLE (70)
  urgent, // 2 -> HIGH (100)
  emergency, // 3 -> ALERT (110)
}

/// Maps [SmSignalTtl] to a [Duration].
Duration smSignalTtlToDuration(SmSignalTtl ttl) {
  switch (ttl) {
    case SmSignalTtl.minutes15:
      return const Duration(minutes: 15);
    case SmSignalTtl.minutes30:
      return const Duration(minutes: 30);
    case SmSignalTtl.hour1:
      return const Duration(hours: 1);
    case SmSignalTtl.hours6:
      return const Duration(hours: 6);
    case SmSignalTtl.hours24:
      return const Duration(hours: 24);
  }
}

/// Maps [SmSignalPriority] to Meshtastic MeshPacket_Priority int value.
int smSignalPriorityToMeshPriority(SmSignalPriority priority) {
  switch (priority) {
    case SmSignalPriority.normal:
      return 64; // DEFAULT
    case SmSignalPriority.important:
      return 70; // RELIABLE
    case SmSignalPriority.urgent:
      return 100; // HIGH
    case SmSignalPriority.emergency:
      return 110; // ALERT
  }
}

/// Decoded SM_SIGNAL packet (portnum 261).
///
/// Wire format (see docs/firmware/PACKET_TYPES.md):
/// ```
/// [header:1][flags:1][signalId:8][lat?:4][lng?:4][contentLen:1][content:0-140]
/// ```
class SmSignal {
  /// Unique signal ID (random uint64).
  final int signalId;

  /// Signal content text (max 140 bytes UTF-8).
  final String content;

  /// TTL class.
  final SmSignalTtl ttl;

  /// Signal priority.
  final SmSignalPriority priority;

  /// Whether an image is available out-of-band (cloud, local cache, or
  /// delayed transfer). Does not imply internet connectivity.
  final bool hasImage;

  /// Latitude (1e-7 degrees), or null if no location.
  final int? latitudeI;

  /// Longitude (1e-7 degrees), or null if no location.
  final int? longitudeI;

  const SmSignal({
    required this.signalId,
    required this.content,
    this.ttl = SmSignalTtl.hour1,
    this.priority = SmSignalPriority.normal,
    this.hasImage = false,
    this.latitudeI,
    this.longitudeI,
  });

  /// Generate a random signal ID using a CSPRNG (`Random.secure()`).
  ///
  /// Used for collision-resistant uniqueness, not secrecy -- the ID is
  /// transmitted in the clear. Birthday-bound collision probability is
  /// ~3e-8 for 1 million signals; negligible at expected mesh volumes.
  static int generateSignalId() {
    final rng = Random.secure();
    // Generate two full 32-bit values and combine into a 64-bit value.
    // nextInt(1 << 32) returns [0, 2^32-1] covering all 32 bits.
    // In Dart native, int is 64-bit signed; the result may be negative
    // when bit 63 is set, which is correct (same bit pattern).
    return (rng.nextInt(1 << 32) << 32) | rng.nextInt(1 << 32);
  }

  /// Convenience getters for floating-point coordinates.
  double? get latitude => latitudeI != null ? latitudeI! / 1e7 : null;

  double? get longitude => longitudeI != null ? longitudeI! / 1e7 : null;

  /// Encode to binary payload.
  ///
  /// Returns null if the payload would exceed [SmPayloadLimit.loraMtu].
  Uint8List? encode() {
    final hasLocation = latitudeI != null && longitudeI != null;
    final contentBytes = utf8.encode(content);
    final contentLen = contentBytes.length;

    if (contentLen > SmPayloadLimit.signalContentMaxBytes) return null;

    // Calculate total size.
    var size = 2; // header + flags
    size += 8; // signal_id
    if (hasLocation) size += 8;
    size += 1; // content_len
    size += contentLen;

    if (size > SmPayloadLimit.loraMtu) return null;

    final buffer = ByteData(size);
    var offset = 0;

    // Header: version=0, type=2 -> 0x02
    buffer.setUint8(offset++, 0x02);

    // Flags byte.
    var flags = 0;
    if (hasLocation) flags |= 0x01;
    if (hasImage) flags |= 0x02;
    flags |= (ttl.index & 0x07) << 2;
    flags |= (priority.index & 0x07) << 5;
    buffer.setUint8(offset++, flags);

    // Signal ID (uint64, big-endian).
    buffer.setInt64(offset, signalId, Endian.big);
    offset += 8;

    // Location.
    if (hasLocation) {
      buffer.setInt32(offset, latitudeI!, Endian.big);
      offset += 4;
      buffer.setInt32(offset, longitudeI!, Endian.big);
      offset += 4;
    }

    // Content length + string.
    buffer.setUint8(offset++, contentLen);
    if (contentLen > 0) {
      final bytes = buffer.buffer.asUint8List();
      bytes.setRange(offset, offset + contentLen, contentBytes);
      offset += contentLen;
    }

    return buffer.buffer.asUint8List(0, offset);
  }

  /// Decode from binary payload.
  ///
  /// Returns null if the payload is malformed or has an unsupported version.
  static SmSignal? decode(Uint8List data) {
    if (data.length < 11) {
      return null; // minimum: header+flags+signalId+contentLen
    }

    final buffer = ByteData.sublistView(data);
    var offset = 0;

    // Header byte.
    final header = buffer.getUint8(offset++);
    final version = (header >> 4) & 0x0F;
    if (version > SmVersion.maxSupported) return null;
    final kind = header & 0x0F;
    if (kind != SmPacketKind.signal) return null;

    // Flags byte.
    final flags = buffer.getUint8(offset++);
    final hasLocation = (flags & 0x01) != 0;
    final hasImage = (flags & 0x02) != 0;
    final ttlIndex = (flags >> 2) & 0x07;
    final priorityIndex = (flags >> 5) & 0x07;

    final ttl = ttlIndex < SmSignalTtl.values.length
        ? SmSignalTtl.values[ttlIndex]
        : SmSignalTtl.hour1;
    final priority = priorityIndex < SmSignalPriority.values.length
        ? SmSignalPriority.values[priorityIndex]
        : SmSignalPriority.normal;

    // Signal ID.
    if (offset + 8 > data.length) return null;
    final signalId = buffer.getInt64(offset, Endian.big);
    offset += 8;

    // Location.
    int? latitudeI;
    int? longitudeI;
    if (hasLocation) {
      if (offset + 8 > data.length) return null;
      latitudeI = buffer.getInt32(offset, Endian.big);
      offset += 4;
      longitudeI = buffer.getInt32(offset, Endian.big);
      offset += 4;
    }

    // Content.
    if (offset >= data.length) return null;
    final contentLen = buffer.getUint8(offset++);
    if (contentLen > SmPayloadLimit.signalContentMaxBytes) return null;

    var content = '';
    if (contentLen > 0) {
      if (offset + contentLen > data.length) return null;
      content = utf8.decode(
        data.sublist(offset, offset + contentLen),
        allowMalformed: true,
      );
    }

    return SmSignal(
      signalId: signalId,
      content: content,
      ttl: ttl,
      priority: priority,
      hasImage: hasImage,
      latitudeI: latitudeI,
      longitudeI: longitudeI,
    );
  }

  @override
  String toString() =>
      'SmSignal(id=${signalId.toRadixString(16)}, '
      'content="${content.length > 30 ? '${content.substring(0, 30)}...' : content}", '
      'ttl=$ttl, priority=$priority, '
      'hasImage=$hasImage, '
      'lat=${latitude?.toStringAsFixed(5)}, '
      'lng=${longitude?.toStringAsFixed(5)})';
}
