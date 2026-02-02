// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// A MeshCore channel for group communication.
class MeshCoreChannel {
  /// Channel index on device (0-based).
  final int index;

  /// Channel name.
  final String name;

  /// Pre-shared key (16 bytes).
  final Uint8List psk;

  MeshCoreChannel({required this.index, required this.name, required this.psk});

  /// PSK as hex string.
  String get pskHex => _bytesToHex(psk);

  /// Whether this channel is empty/unconfigured.
  bool get isEmpty => name.isEmpty && psk.every((b) => b == 0);

  /// Whether this is the default public channel.
  bool get isPublicChannel => pskHex == publicChannelPskHex;

  /// Whether this is a public hashtag channel (PSK derived from name).
  bool get isPublic {
    if (name.isEmpty) return false;
    // Check if PSK matches what would be derived from the name
    final expectedPsk = derivePskFromHashtag(name);
    return _bytesToHex(expectedPsk) == pskHex || isPublicChannel;
  }

  /// Whether the PSK is the default (all zeros).
  bool get isDefaultPsk => psk.every((b) => b == 0);

  /// Display name for UI (shows name or "Channel N" for unnamed).
  String get displayName {
    if (name.isNotEmpty) return name;
    return 'Channel $index';
  }

  /// Default public channel PSK (shared across all MeshCore devices).
  static const String publicChannelPskHex = '8b3387e9c5cdea6ac9e5edbaa115cd72';

  /// Create an empty channel at the given index.
  static MeshCoreChannel empty(int index) {
    return MeshCoreChannel(index: index, name: '', psk: Uint8List(16));
  }

  /// Create a channel from a PSK hex string.
  static MeshCoreChannel fromHex(int index, String name, String pskHex) {
    final psk = _parsePskHex(pskHex);
    return MeshCoreChannel(index: index, name: name, psk: psk);
  }

  /// Derive PSK from hashtag name using SHA256.
  ///
  /// The hashtag is normalized to include '#' prefix.
  /// Returns first 16 bytes of SHA256 hash as PSK.
  static Uint8List derivePskFromHashtag(String hashtag) {
    final name = hashtag.startsWith('#') ? hashtag : '#$hashtag';
    final hash = crypto.sha256.convert(utf8.encode(name)).bytes;
    return Uint8List.fromList(hash.sublist(0, 16));
  }

  /// Create a channel from hashtag name (derives PSK automatically).
  static MeshCoreChannel fromHashtag(int index, String hashtag) {
    final psk = derivePskFromHashtag(hashtag);
    final name = hashtag.startsWith('#') ? hashtag : '#$hashtag';
    return MeshCoreChannel(index: index, name: name, psk: psk);
  }

  /// Create the default public channel.
  static MeshCoreChannel publicChannel(int index, [String hashtag = 'Public']) {
    // If it's a hashtag (starts with #), derive PSK from the name
    if (hashtag.startsWith('#') || hashtag != 'Public') {
      return MeshCoreChannel.fromHashtag(index, hashtag);
    }
    return MeshCoreChannel.fromHex(index, 'Public', publicChannelPskHex);
  }

  MeshCoreChannel copyWith({int? index, String? name, Uint8List? psk}) {
    return MeshCoreChannel(
      index: index ?? this.index,
      name: name ?? this.name,
      psk: psk ?? this.psk,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshCoreChannel &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          pskHex == other.pskHex;

  @override
  int get hashCode => index.hashCode ^ pskHex.hashCode;

  @override
  String toString() => 'MeshCoreChannel($index: $name)';

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _parsePskHex(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (cleaned.length != 32) {
      throw FormatException(
        'PSK must be 32 hex characters, got ${cleaned.length}',
      );
    }
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      final start = i * 2;
      bytes[i] = int.parse(cleaned.substring(start, start + 2), radix: 16);
    }
    return bytes;
  }
}

/// Parse a channel info response from MeshCore protocol.
///
/// CHANNEL_INFO format:
/// ```
/// [0] = resp_code (0x12)
/// [1] = channel_idx
/// [2-33] = name (32 bytes, null-terminated)
/// [34-49] = psk (16 bytes)
/// ```
MeshCoreChannel? parseChannelInfo(Uint8List payload) {
  // Need at least: idx(1) + name(32) + psk(16) = 49 bytes
  if (payload.length < 49) return null;

  final index = payload[0];

  // Read name (null-terminated, max 32 bytes)
  int nameEnd = 1;
  while (nameEnd < 33 && payload[nameEnd] != 0) {
    nameEnd++;
  }
  final name = String.fromCharCodes(payload.sublist(1, nameEnd));

  // Read PSK (16 bytes starting at offset 33)
  final psk = Uint8List.fromList(payload.sublist(33, 49));

  return MeshCoreChannel(index: index, name: name, psk: psk);
}

/// Generate a share code for a channel (name + PSK hex).
String generateChannelCode(MeshCoreChannel channel) {
  return '${channel.name}:${channel.pskHex}';
}

/// Parse a channel from share code.
MeshCoreChannel? parseChannelCode(String code, {int index = 0}) {
  final parts = code.split(':');
  if (parts.length < 2) return null;

  final name = parts[0];
  final pskHex = parts.sublist(1).join(':');

  if (pskHex.length != 32) return null;

  try {
    return MeshCoreChannel.fromHex(index, name, pskHex);
  } catch (_) {
    return null;
  }
}
