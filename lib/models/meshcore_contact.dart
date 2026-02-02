// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

/// Advertisement types for MeshCore contacts.
class MeshCoreAdvType {
  MeshCoreAdvType._();

  static const int chat = 1;
  static const int repeater = 2;
  static const int room = 3;
  static const int sensor = 4;

  static String label(int type) {
    switch (type) {
      case chat:
        return 'Chat';
      case repeater:
        return 'Repeater';
      case room:
        return 'Room';
      case sensor:
        return 'Sensor';
      default:
        return 'Unknown';
    }
  }
}

/// A MeshCore contact (discovered via advertisement or manually added).
class MeshCoreContact {
  /// Public key (32 bytes) - unique identifier for the contact.
  final Uint8List publicKey;

  /// Display name from advertisement or manual entry.
  final String name;

  /// Advertisement type (chat, repeater, room, sensor).
  final int type;

  /// Path length: -1 = flood, 0+ = direct hops.
  final int pathLength;

  /// Path bytes from device.
  final Uint8List path;

  /// User's path override: -1 = force flood, null = auto.
  final int? pathOverride;

  /// User's path override bytes.
  final Uint8List? pathOverrideBytes;

  /// Latitude (if advertised).
  final double? latitude;

  /// Longitude (if advertised).
  final double? longitude;

  /// When this contact was last seen.
  final DateTime lastSeen;

  /// When the last message was received.
  final DateTime lastMessageAt;

  /// Unread message count.
  final int unreadCount;

  MeshCoreContact({
    required this.publicKey,
    required this.name,
    required this.type,
    required this.pathLength,
    required this.path,
    this.pathOverride,
    this.pathOverrideBytes,
    this.latitude,
    this.longitude,
    required this.lastSeen,
    DateTime? lastMessageAt,
    this.unreadCount = 0,
  }) : lastMessageAt = lastMessageAt ?? lastSeen;

  /// Public key as hex string.
  String get publicKeyHex => _bytesToHex(publicKey);

  /// Short version of public key for display.
  String get shortPubKeyHex {
    final hex = publicKeyHex;
    if (hex.length < 16) return hex;
    return '<${hex.substring(0, 8)}...${hex.substring(hex.length - 8)}>';
  }

  /// Human-readable type label.
  String get typeLabel => MeshCoreAdvType.label(type);

  /// Human-readable path description.
  String get pathLabel {
    if (pathOverride != null) {
      if (pathOverride! < 0) return 'Flood (forced)';
      if (pathOverride == 0) return 'Direct (forced)';
      return '$pathOverride hops (forced)';
    }
    if (pathLength < 0) return 'Flood';
    if (pathLength == 0) return 'Direct';
    return '$pathLength hops';
  }

  /// Whether this contact has location data.
  bool get hasLocation => latitude != null && longitude != null;

  /// Whether this is a chat-type contact.
  bool get isChat => type == MeshCoreAdvType.chat;

  /// Whether this is a repeater.
  bool get isRepeater => type == MeshCoreAdvType.repeater;

  /// Whether this is a room.
  bool get isRoom => type == MeshCoreAdvType.room;

  /// Whether this is a sensor.
  bool get isSensor => type == MeshCoreAdvType.sensor;

  MeshCoreContact copyWith({
    Uint8List? publicKey,
    String? name,
    int? type,
    int? pathLength,
    Uint8List? path,
    int? pathOverride,
    Uint8List? pathOverrideBytes,
    bool clearPathOverride = false,
    double? latitude,
    double? longitude,
    DateTime? lastSeen,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) {
    return MeshCoreContact(
      publicKey: publicKey ?? this.publicKey,
      name: name ?? this.name,
      type: type ?? this.type,
      pathLength: pathLength ?? this.pathLength,
      path: path ?? this.path,
      pathOverride: clearPathOverride
          ? null
          : (pathOverride ?? this.pathOverride),
      pathOverrideBytes: clearPathOverride
          ? null
          : (pathOverrideBytes ?? this.pathOverrideBytes),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastSeen: lastSeen ?? this.lastSeen,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshCoreContact &&
          runtimeType == other.runtimeType &&
          publicKeyHex == other.publicKeyHex;

  @override
  int get hashCode => publicKeyHex.hashCode;

  @override
  String toString() => 'MeshCoreContact($name, $typeLabel, $pathLabel)';

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Parse a contact from MeshCore protocol response.
///
/// CONTACT response format:
/// ```
/// [0] = resp_code (0x03)
/// [1-32] = pub_key (32 bytes)
/// [33] = adv_type
/// [34] = path_len (-1 for flood)
/// [35-36] = lastmod (uint16 LE)
/// [37-40] = lat (int32 LE, optional)
/// [41-44] = lon (int32 LE, optional)
/// [45+] = name (null-terminated)
/// [after name] = path_bytes (path_len bytes, if path_len > 0)
/// ```
MeshCoreContact? parseContact(Uint8List payload) {
  // Minimum: pub_key(32) + adv_type(1) + path_len(1) + lastmod(2) = 36
  if (payload.length < 36) return null;

  final pubKey = Uint8List.fromList(payload.sublist(0, 32));
  final advType = payload[32];
  final pathLen = payload[33].toSigned(8); // Signed byte
  // lastmod at [34-35] - skip for now

  // Try to read lat/lon
  double? lat;
  double? lon;
  int nameOffset = 36;

  if (payload.length >= 44) {
    final latRaw = _readInt32LE(payload, 36);
    final lonRaw = _readInt32LE(payload, 40);
    // MeshCore uses raw int32 for lat/lon, convert to degrees
    if (latRaw != 0 || lonRaw != 0) {
      lat = latRaw / 1e7;
      lon = lonRaw / 1e7;
    }
    nameOffset = 44;
  }

  // Read name (null-terminated)
  String name = '';
  if (nameOffset < payload.length) {
    int end = nameOffset;
    while (end < payload.length && payload[end] != 0) {
      end++;
    }
    name = String.fromCharCodes(payload.sublist(nameOffset, end));
  }

  // Read path bytes if path_len > 0
  Uint8List pathBytes = Uint8List(0);
  // Skip for now - path bytes follow the null-terminated name

  return MeshCoreContact(
    publicKey: pubKey,
    name: name,
    type: advType,
    pathLength: pathLen,
    path: pathBytes,
    latitude: lat,
    longitude: lon,
    lastSeen: DateTime.now(),
  );
}

int _readInt32LE(Uint8List data, int offset) {
  int val =
      data[offset] |
      (data[offset + 1] << 8) |
      (data[offset + 2] << 16) |
      (data[offset + 3] << 24);
  if (val >= 0x80000000) val -= 0x100000000;
  return val;
}

/// Generate contact code for sharing (base64 of public key + name).
String generateContactCode(MeshCoreContact contact) {
  // Simple format: pubKey:name
  // Could be encoded as QR or shared as text
  return '${contact.publicKeyHex}:${contact.name}';
}

/// Parse contact code from scanned/entered value.
MeshCoreContact? parseContactCode(String code) {
  final parts = code.split(':');
  if (parts.length < 2) return null;

  final hexKey = parts[0];
  final name = parts.sublist(1).join(':');

  if (hexKey.length != 64) return null; // 32 bytes = 64 hex chars

  try {
    final pubKey = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      pubKey[i] = int.parse(hexKey.substring(i * 2, i * 2 + 2), radix: 16);
    }

    return MeshCoreContact(
      publicKey: pubKey,
      name: name,
      type: MeshCoreAdvType.chat,
      pathLength: -1, // Flood by default
      path: Uint8List(0),
      lastSeen: DateTime.now(),
    );
  } catch (_) {
    return null;
  }
}
