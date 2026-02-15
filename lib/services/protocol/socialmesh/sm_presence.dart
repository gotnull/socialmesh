// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:typed_data';

import 'sm_constants.dart';

/// Presence intent enum matching the 3-bit wire encoding.
enum SmPresenceIntent {
  unknown, // 0
  available, // 1
  camping, // 2
  traveling, // 3
  emergencyStandby, // 4
  relayNode, // 5
  passive, // 6
}

/// Decoded SM_PRESENCE packet (portnum 260).
///
/// Wire format (see docs/firmware/PACKET_TYPES.md):
/// ```
/// [header:1][flags:1][battery?:1][lat?:4][lng?:4][statusLen:1][status:0-63]
/// ```
class SmPresence {
  /// Battery percentage (0-100), or null if not included.
  final int? battery;

  /// Latitude (1e-7 degrees), or null if no location.
  final int? latitudeI;

  /// Longitude (1e-7 degrees), or null if no location.
  final int? longitudeI;

  /// Presence intent.
  final SmPresenceIntent intent;

  /// Short status string (max 63 bytes UTF-8), or null.
  final String? status;

  const SmPresence({
    this.battery,
    this.latitudeI,
    this.longitudeI,
    this.intent = SmPresenceIntent.unknown,
    this.status,
  });

  /// Convenience getters for floating-point coordinates.
  double? get latitude => latitudeI != null ? latitudeI! / 1e7 : null;

  double? get longitude => longitudeI != null ? longitudeI! / 1e7 : null;

  /// Encode to binary payload.
  ///
  /// Returns null if the payload would exceed [SmPayloadLimit.loraMtu].
  Uint8List? encode() {
    final hasLocation = latitudeI != null && longitudeI != null;
    final hasBattery = battery != null;
    final statusBytes = status != null && status!.isNotEmpty
        ? utf8.encode(status!)
        : null;
    final statusLen = statusBytes?.length ?? 0;

    if (statusLen > SmPayloadLimit.presenceStatusMaxBytes) return null;

    // Calculate total size.
    var size = 2; // header + flags
    if (hasBattery) size += 1;
    if (hasLocation) size += 8;
    size += 1; // status_len
    size += statusLen;

    if (size > SmPayloadLimit.loraMtu) return null;

    final buffer = ByteData(size);
    var offset = 0;

    // Header: version=0, type=1 -> 0x01
    buffer.setUint8(offset++, 0x01);

    // Flags byte.
    var flags = 0;
    if (hasLocation) flags |= 0x01;
    if (hasBattery) flags |= 0x02;
    flags |= (intent.index & 0x07) << 2;
    buffer.setUint8(offset++, flags);

    // Battery.
    if (hasBattery) {
      buffer.setUint8(offset++, battery!.clamp(0, 255));
    }

    // Location.
    if (hasLocation) {
      buffer.setInt32(offset, latitudeI!, Endian.big);
      offset += 4;
      buffer.setInt32(offset, longitudeI!, Endian.big);
      offset += 4;
    }

    // Status length + string.
    buffer.setUint8(offset++, statusLen);
    if (statusBytes != null) {
      final bytes = buffer.buffer.asUint8List();
      bytes.setRange(offset, offset + statusLen, statusBytes);
      offset += statusLen;
    }

    return buffer.buffer.asUint8List(0, offset);
  }

  /// Decode from binary payload.
  ///
  /// Returns null if the payload is malformed or has an unsupported version.
  static SmPresence? decode(Uint8List data) {
    if (data.length < 3) return null; // minimum: header + flags + statusLen

    final buffer = ByteData.sublistView(data);
    var offset = 0;

    // Header byte.
    final header = buffer.getUint8(offset++);
    final version = (header >> 4) & 0x0F;
    if (version > SmVersion.maxSupported) return null;
    final kind = header & 0x0F;
    if (kind != SmPacketKind.presence) return null;

    // Flags byte.
    final flags = buffer.getUint8(offset++);
    final hasLocation = (flags & 0x01) != 0;
    final hasBattery = (flags & 0x02) != 0;
    final intentIndex = (flags >> 2) & 0x07;
    final intent = intentIndex < SmPresenceIntent.values.length
        ? SmPresenceIntent.values[intentIndex]
        : SmPresenceIntent.unknown;

    // Battery.
    int? battery;
    if (hasBattery) {
      if (offset >= data.length) return null;
      final raw = buffer.getUint8(offset++);
      battery = raw == 255 ? null : raw;
    }

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

    // Status.
    if (offset >= data.length) return null;
    final statusLen = buffer.getUint8(offset++);
    String? status;
    if (statusLen > 0) {
      if (offset + statusLen > data.length) return null;
      status = utf8.decode(
        data.sublist(offset, offset + statusLen),
        allowMalformed: true,
      );
    }

    return SmPresence(
      battery: battery,
      latitudeI: latitudeI,
      longitudeI: longitudeI,
      intent: intent,
      status: status,
    );
  }

  @override
  String toString() =>
      'SmPresence(intent=$intent, battery=$battery, '
      'lat=${latitude?.toStringAsFixed(5)}, '
      'lng=${longitude?.toStringAsFixed(5)}, '
      'status=$status)';
}
