// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D46-A: codec for the `meshcore://<hex>` contact share URL.
//
// The URL is a thin app-side wrapper around the advert packet the firmware
// stored for a contact: the bytes that `CMD_EXPORT_CONTACT 0x11` returns and
// that `CMD_IMPORT_CONTACT 0x12` accepts. Firmware never
// sees the URL form - it only ever encodes/decodes the byte frame.
//
// Wire-compat with meshcore-open: their `contacts_screen.dart` builds
// `meshcore://<pubKeyToHex(rawPacket)>` from the same response bytes.
// A SocialMesh-encoded URL pastes cleanly into meshcore-open and vice
// versa.
//
// Legacy `<pubkeyhex>:<name>` format support (the SocialMesh-only
// stopgap that shipped before D46-A) is preserved as a separate
// fallback for one release so users' saved codes / scanned QRs don't
// break overnight.

import 'meshcore_advert_packet.dart';

import 'dart:convert';
import 'dart:typed_data';

import '../../../models/meshcore_contact.dart';
import '../../../utils/text_sanitizer.dart';

class MeshCoreContactUrl {
  MeshCoreContactUrl._();

  /// Canonical URL scheme. Matches meshcore-open's
  /// `meshcore://<hex>` exactly.
  static const String scheme = 'meshcore://';

  /// Byte bounds of the advert packet the URL carries (see
  /// [MeshCoreAdvertPacket]); the same bounds meshcore-open accepts.
  static const int minFrameBytes = MeshCoreAdvertPacket.minBytes;
  static const int maxFrameBytes = MeshCoreAdvertPacket.maxBytes;

  /// Encode contact-frame bytes as the canonical `meshcore://<hex>`
  /// URL. Throws [ArgumentError] when [frame] is outside the advert
  /// packet byte bounds.
  static String encode(Uint8List frame) {
    if (frame.length < minFrameBytes || frame.length > maxFrameBytes) {
      throw ArgumentError.value(
        frame.length,
        'frame.length',
        'must be in $minFrameBytes..$maxFrameBytes',
      );
    }
    final hex = _bytesToHex(frame);
    return '$scheme$hex';
  }

  /// Decode a `meshcore://<hex>` URL into raw contact-frame bytes.
  /// Returns null on any parse failure (bad scheme, odd hex length,
  /// non-hex chars, out-of-range byte count). Never throws -
  /// clipboard contents are untrusted input.
  static Uint8List? decode(String url) {
    final trimmed = url.trim();
    if (!trimmed.startsWith(scheme)) return null;
    final hex = trimmed.substring(scheme.length);
    if (hex.isEmpty || hex.length.isOdd) return null;
    final bytes = _hexToBytes(hex);
    if (bytes == null) return null;
    if (bytes.length < minFrameBytes || bytes.length > maxFrameBytes) {
      return null;
    }
    return bytes;
  }

  static String _bytesToHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static Uint8List? _hexToBytes(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      final byte = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (byte == null) return null;
      out[i ~/ 2] = byte;
    }
    return out;
  }
}

/// D46-A: parse the legacy SocialMesh-only `<pubkeyhex>:<name>`
/// contact-code format. Returns a stub [MeshCoreContact] with
/// `pathLength = -1` (flood), `type = chat`, and empty path bytes
/// since the format only carried pubkey + name.
///
/// New encodes always use [MeshCoreContactUrl.encode]; this is the
/// one-release transition path for users' saved codes / scanned QRs.
/// Returns null when [code] does not match the legacy format.
MeshCoreContact? parseLegacyContactCode(String code) {
  final trimmed = code.trim();
  // The legacy format is `<64-char hex>:<name>`. A leading
  // `meshcore://` scheme means this is the modern form; defer to
  // `MeshCoreContactUrl.decode` + `parseContact` for that.
  if (trimmed.startsWith(MeshCoreContactUrl.scheme)) return null;
  final parts = trimmed.split(':');
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
      name: _fitContactName(name),
      type: MeshCoreAdvType.chat,
      pathLength: -1,
      path: Uint8List(0),
      lastSeen: DateTime.now(),
    );
  } catch (_) {
    return null;
  }
}

/// Parses meshcore-open's contact card link,
/// `meshcore://contact/add?public_key=<64 hex>&name=<name>&type=<1-4>`,
/// into a contact. The type defaults to chat when absent or unknown.
/// Returns null for anything else.
MeshCoreContact? parseMeshCoreContactCard(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null || uri.scheme != 'meshcore') return null;
  final path = '${uri.host}${uri.path}'.toLowerCase().replaceAll(
    RegExp(r'^/+|/+$'),
    '',
  );
  if (path != 'contact/add') return null;
  final keyHex = (uri.queryParameters['public_key'] ?? '').trim();
  if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(keyHex)) return null;
  final pubKey = Uint8List.fromList([
    for (var i = 0; i < 64; i += 2)
      int.parse(keyHex.substring(i, i + 2), radix: 16),
  ]);
  final type = int.tryParse(uri.queryParameters['type'] ?? '');
  return MeshCoreContact(
    publicKey: pubKey,
    name: _fitContactName(
      sanitizeExternalText(uri.queryParameters['name'] ?? '').trim(),
    ),
    type: type != null && type >= 1 && type <= 4 ? type : MeshCoreAdvType.chat,
    pathLength: -1,
    path: Uint8List(0),
    lastSeen: DateTime.now(),
  );
}

// The radio stores at most 31 bytes of name; cut longer names on a UTF-8
// boundary so the contact write is not refused.
String _fitContactName(String name) {
  final bytes = utf8.encode(name);
  if (bytes.length <= 31) return name;
  var cut = 31;
  while (cut > 0 && (bytes[cut] & 0xC0) == 0x80) {
    cut--;
  }
  return utf8.decode(bytes.sublist(0, cut));
}
