// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q7: pure parser + derivation helpers for the upstream meshcore-open
// community-QR wire format (documented at
// `meshcore-open/documentation/channels.md`). Wire-compatible by design:
// a user scans a community QR exported by any meshcore-open client and
// SocialMesh derives the same PSKs.
//
// Wire shape (JSON):
//   {"v": 1, "type": "meshcore_community",
//    "name": "<display name>", "k": "<base64url-no-pad 32 bytes>"}
//
// Channel-PSK derivation (per upstream channels.md §"Hashtag channels"):
//   psk(tag) = HMAC-SHA256(secret_bytes, "channel:v1:" + tag)[:16]
//
// The implicit public channel uses the literal tag `__public__`.
//
// This file is pure: no Riverpod, no widgets, no I/O. The scanner
// screen wraps the parser and feeds each derived channel into the
// existing `MeshCoreChannelsNotifier.setChannel` write path.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const String _kCommunityPayloadType = 'meshcore_community';
const int _kCommunityPayloadVersion = 1;

/// Literal hashtag for the implicit public channel that every
/// community ships. Matches upstream channels.md §"Public channel".
const String kMeshCoreCommunityPublicTag = '__public__';

/// Upstream-defined HMAC derivation prefix. PSK = HMAC-SHA256(secret,
/// `${kMeshCoreCommunityHmacPrefix}${tag}`)[:16]. Frozen by wire spec
/// — do not change without bumping the payload version.
const String kMeshCoreCommunityHmacPrefix = 'channel:v1:';

/// Parsed community QR payload. `secret` is the raw 32-byte community
/// key decoded from the `k` base64url field. `name` is the display
/// name shown in the preview sheet.
class MeshCoreCommunityPayload {
  final int version;
  final String name;
  final Uint8List secret;

  const MeshCoreCommunityPayload({
    required this.version,
    required this.name,
    required this.secret,
  });

  /// Derive a 16-byte PSK for a hashtag channel inside this community.
  /// Pass [kMeshCoreCommunityPublicTag] for the implicit public
  /// channel. The returned bytes are a defensive copy.
  Uint8List derivePskFor(String tag) {
    return deriveMeshCoreCommunityPsk(secret, tag);
  }
}

/// Why a parse attempt failed. Kept as an enum so the UI can map
/// each variant to a localised user-facing message rather than
/// surfacing raw exception types.
enum MeshCoreCommunityParseError {
  notJson,
  wrongType,
  unsupportedVersion,
  missingName,
  missingSecret,
  badSecretEncoding,
  badSecretLength,
  emptyName,
}

/// Result of a parse attempt: either `payload` is non-null and the
/// rest of the fields are unused, or `payload` is null and `error`
/// carries the specific failure reason.
class MeshCoreCommunityParseResult {
  final MeshCoreCommunityPayload? payload;
  final MeshCoreCommunityParseError? error;

  const MeshCoreCommunityParseResult.ok(MeshCoreCommunityPayload p)
    : payload = p,
      error = null;

  const MeshCoreCommunityParseResult.fail(MeshCoreCommunityParseError e)
    : payload = null,
      error = e;

  bool get isSuccess => payload != null;
}

/// Pure parser for the upstream community-QR JSON payload. Caller
/// passes the raw scanned string. Returns a typed result so the UI
/// can render a specific error rather than catching exceptions.
MeshCoreCommunityParseResult parseMeshCoreCommunityPayload(String raw) {
  // Step 1: JSON.
  final dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return const MeshCoreCommunityParseResult.fail(
      MeshCoreCommunityParseError.notJson,
    );
  }
  if (decoded is! Map<String, dynamic>) {
    return const MeshCoreCommunityParseResult.fail(
      MeshCoreCommunityParseError.notJson,
    );
  }

  // Step 2: discriminator.
  if (decoded['type'] != _kCommunityPayloadType) {
    return const MeshCoreCommunityParseResult.fail(
      MeshCoreCommunityParseError.wrongType,
    );
  }

  // Step 3: version. Anything other than the currently-pinned
  // version is rejected up-front so a forward-compatible importer
  // never silently mis-derives PSKs.
  final v = decoded['v'];
  if (v != _kCommunityPayloadVersion) {
    return const MeshCoreCommunityParseResult.fail(
      MeshCoreCommunityParseError.unsupportedVersion,
    );
  }

  // Step 4: name.
  final name = decoded['name'];
  if (name is! String) {
    return const MeshCoreCommunityParseResult.fail(
      MeshCoreCommunityParseError.missingName,
    );
  }
  if (name.trim().isEmpty) {
    return const MeshCoreCommunityParseResult.fail(
      MeshCoreCommunityParseError.emptyName,
    );
  }

  // Step 5: secret.
  final k = decoded['k'];
  if (k is! String) {
    return const MeshCoreCommunityParseResult.fail(
      MeshCoreCommunityParseError.missingSecret,
    );
  }
  final Uint8List secret;
  try {
    secret = base64Url.decode(_padBase64(k));
  } catch (_) {
    return const MeshCoreCommunityParseResult.fail(
      MeshCoreCommunityParseError.badSecretEncoding,
    );
  }
  if (secret.length != 32) {
    return const MeshCoreCommunityParseResult.fail(
      MeshCoreCommunityParseError.badSecretLength,
    );
  }

  return MeshCoreCommunityParseResult.ok(
    MeshCoreCommunityPayload(version: v, name: name.trim(), secret: secret),
  );
}

/// Pure HMAC-SHA256 derivation. Public so tests can exercise it
/// directly with known vectors. Returns the first 16 bytes of the
/// HMAC, matching upstream's 128-bit PSK width.
Uint8List deriveMeshCoreCommunityPsk(Uint8List secret, String tag) {
  final hmac = Hmac(sha256, secret);
  final digest = hmac.convert(utf8.encode('$kMeshCoreCommunityHmacPrefix$tag'));
  return Uint8List.fromList(digest.bytes.sublist(0, 16));
}

/// Sanitise a user-typed hashtag for derivation. Strips a leading
/// '#', lower-cases, and trims. Empty / pure-whitespace input
/// returns the empty string so the caller can flag it.
String normaliseMeshCoreCommunityTag(String input) {
  var t = input.trim();
  if (t.startsWith('#')) t = t.substring(1);
  return t.toLowerCase();
}

/// Base64url decode helper that re-pads a string truncated to omit
/// `=` characters (per RFC 4648 §3.2 base64url-no-pad, which the
/// upstream payload uses).
String _padBase64(String s) {
  final mod = s.length % 4;
  if (mod == 0) return s;
  return s + ('=' * (4 - mod));
}
