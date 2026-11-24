// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/meshcore_constants.dart';
import '../../../utils/text_sanitizer.dart';
import 'meshcore_frame.dart';

/// A MeshCore advert packet as `CMD_EXPORT_CONTACT` returns it and
/// `CMD_IMPORT_CONTACT` takes it: the raw packet the firmware stored when it
/// heard the advert (`Packet::writeTo`), carried in `meshcore://<hex>` links.
///
/// Layout: header byte (route type bits 0-1, payload type bits 2-5),
/// 4 transport-code bytes for the two transport route types, `path_len`
/// (low 6 bits the hop count, top 2 bits the hash width minus 1), the path,
/// then the advert payload: public key (32), timestamp (u32 LE),
/// signature (64) and app data (flags byte with the advert type in the low
/// nibble; lat/lon int32 x 1e6 if 0x10; feature words if 0x20 / 0x40; the
/// name in the remaining bytes if 0x80).
class MeshCoreAdvertPacket {
  const MeshCoreAdvertPacket({
    required this.publicKey,
    required this.timestamp,
    required this.advType,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  /// Byte bounds meshcore-open accepts for an advert packet link; the upper
  /// bound is one command byte short of the 172-byte send limit.
  static const int minBytes = 98;
  static const int maxBytes = 171;

  static const int _payloadTypeAdvert = 0x04;
  static const int _flagLatLon = 0x10;
  static const int _flagFeat1 = 0x20;
  static const int _flagFeat2 = 0x40;
  static const int _flagName = 0x80;

  final Uint8List publicKey;

  /// Advert timestamp, Unix seconds.
  final int timestamp;
  final int advType;
  final String name;
  final double? latitude;
  final double? longitude;

  /// Parses [packet], or returns null when it is not an advert packet.
  static MeshCoreAdvertPacket? parse(Uint8List packet) {
    if (packet.length < minBytes || packet.length > maxBytes) return null;
    final header = packet[0];
    if ((header >> 2) & 0x0F != _payloadTypeAdvert) return null;
    var i = 1;
    final routeType = header & 0x03;
    if (routeType == 0x00 || routeType == 0x03) i += 4;
    if (i >= packet.length) return null;
    final pathLen = packet[i++];
    i += (pathLen & 0x3F) * ((pathLen >> 6) + 1);

    const fixed = meshCorePubKeySize + 4 + 64 + 1;
    if (i + fixed > packet.length) return null;
    final publicKey = Uint8List.fromList(
      packet.sublist(i, i + meshCorePubKeySize),
    );
    i += meshCorePubKeySize;
    final timestamp = ByteData.sublistView(
      packet,
      i,
      i + 4,
    ).getUint32(0, Endian.little);
    i += 4 + 64;

    final flags = packet[i++];
    double? lat;
    double? lon;
    if (flags & _flagLatLon != 0) {
      if (i + 8 > packet.length) return null;
      final data = ByteData.sublistView(packet, i, i + 8);
      final latRaw = data.getInt32(0, Endian.little);
      final lonRaw = data.getInt32(4, Endian.little);
      if (latRaw != 0 || lonRaw != 0) {
        lat = latRaw / kMeshCoreAdvertLatLonScale;
        lon = lonRaw / kMeshCoreAdvertLatLonScale;
      }
      i += 8;
    }
    if (flags & _flagFeat1 != 0) i += 2;
    if (flags & _flagFeat2 != 0) i += 2;
    var name = '';
    if (flags & _flagName != 0 && i < packet.length) {
      var end = packet.length;
      final nul = packet.indexOf(0, i);
      if (nul >= 0) end = nul;
      name = sanitizeExternalText(
        utf8.decode(packet.sublist(i, end), allowMalformed: true),
      );
    }

    return MeshCoreAdvertPacket(
      publicKey: publicKey,
      timestamp: timestamp,
      advType: flags & 0x0F,
      name: name,
      latitude: lat,
      longitude: lon,
    );
  }
}
