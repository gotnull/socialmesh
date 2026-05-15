// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34c-B-B: pure parser for the comma-separated hex-prefix input the
// manual N-hop path sheet collects. Each hop is identified by the
// first byte of its repeater's public key.
//
// Wire constraint: the firmware accepts at most 64 hops in the
// `pathBytes` field of `CMD_ADD_UPDATE_CONTACT`. Anything longer is
// rejected before the wire write.
//
// Token discipline:
//   - tokens are split on `,`,
//   - each token is trimmed of surrounding whitespace,
//   - empty tokens (e.g. trailing comma) are skipped,
//   - the first 2 characters of each non-empty token must be ASCII
//     hex (0-9, a-f, case-insensitive). Anything else is reported as
//     an `invalidToken` outcome carrying the offending substring so
//     the UI can highlight which token failed.
//
// The parser does NOT enforce a non-empty result; an empty input
// returns `ok(<empty>)` so the caller (the sheet's apply button)
// can choose between "treat empty as cancel" or "treat empty as
// `pathOverride = 0`". Today the sheet treats it as "no-op cancel".

import 'dart:typed_data';

const int kMeshCoreManualPathMaxHops = 64;

class MeshCoreManualPathParseResult {
  final _MeshCoreManualPathParseOutcome _outcome;
  final Uint8List? bytes;
  final String? invalidToken;
  final int? overflowLength;

  const MeshCoreManualPathParseResult._({
    required _MeshCoreManualPathParseOutcome outcome,
    this.bytes,
    this.invalidToken,
    this.overflowLength,
  }) : _outcome = outcome;

  factory MeshCoreManualPathParseResult.ok(Uint8List bytes) =>
      MeshCoreManualPathParseResult._(
        outcome: _MeshCoreManualPathParseOutcome.ok,
        bytes: bytes,
      );

  factory MeshCoreManualPathParseResult.invalidToken(String token) =>
      MeshCoreManualPathParseResult._(
        outcome: _MeshCoreManualPathParseOutcome.invalidToken,
        invalidToken: token,
      );

  factory MeshCoreManualPathParseResult.tooLong(int length) =>
      MeshCoreManualPathParseResult._(
        outcome: _MeshCoreManualPathParseOutcome.tooLong,
        overflowLength: length,
      );

  bool get isOk => _outcome == _MeshCoreManualPathParseOutcome.ok;
  bool get isInvalidToken =>
      _outcome == _MeshCoreManualPathParseOutcome.invalidToken;
  bool get isTooLong => _outcome == _MeshCoreManualPathParseOutcome.tooLong;
}

enum _MeshCoreManualPathParseOutcome { ok, invalidToken, tooLong }

MeshCoreManualPathParseResult parseManualPathHexPrefixes(String input) {
  final tokens = input
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (tokens.length > kMeshCoreManualPathMaxHops) {
    return MeshCoreManualPathParseResult.tooLong(tokens.length);
  }
  final out = Uint8List(tokens.length);
  for (var i = 0; i < tokens.length; i++) {
    final raw = tokens[i];
    if (raw.length < 2) {
      return MeshCoreManualPathParseResult.invalidToken(raw);
    }
    final prefix = raw.substring(0, 2).toUpperCase();
    if (!_isHexByte(prefix)) {
      return MeshCoreManualPathParseResult.invalidToken(raw);
    }
    out[i] = int.parse(prefix, radix: 16);
  }
  return MeshCoreManualPathParseResult.ok(out);
}

bool _isHexByte(String s) {
  if (s.length != 2) return false;
  for (var i = 0; i < 2; i++) {
    final c = s.codeUnitAt(i);
    final isDigit = c >= 0x30 && c <= 0x39;
    final isUpperHex = c >= 0x41 && c <= 0x46;
    if (!isDigit && !isUpperHex) return false;
  }
  return true;
}
