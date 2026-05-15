// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-C: free-text reply parser for MeshCore CLI GET commands.
//
// Repeater firmware replies to `get <key>` with a free-form text
// frame whose shape varies slightly per command. Observed formats:
//
//   "> name: Heltec1"
//   "name: 5"
//   "> on"
//   "> ok"
//   "advert.interval: 120"
//
// The pure helpers below extract a value-portion the form layer can
// feed into a typed field. They never throw; they return null when
// the shape is unrecognised so the caller can fall back to the raw
// reply.
//
// The shape is deliberately permissive — different upstream firmware
// versions reflow whitespace and order — so we trim, drop empty
// lines, and accept either a leading `>` prompt-style line or a
// `key: value` line. The whole-reply fallback covers single-token
// replies like `"on"` or `"42"`.

class MeshCoreCliReplyParser {
  MeshCoreCliReplyParser._();

  // Extract the first usable value-portion from a CLI reply.
  //
  // Returns the trimmed substring after the first recognised
  // separator. Returns null when no line is non-empty.
  static String? extractValue(String response) {
    final lines = response.split('\n');
    String? fallback;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      fallback ??= trimmed;
      if (trimmed.startsWith('>')) {
        final v = trimmed.substring(1).trim();
        if (v.isEmpty) continue;
        // `> name: foo` -- prefer the colon-tail when present.
        final colon = v.indexOf(':');
        if (colon > 0 && colon < v.length - 1) {
          final tail = v.substring(colon + 1).trim();
          if (tail.isNotEmpty) return tail;
        }
        return v;
      }
      final colon = trimmed.indexOf(':');
      if (colon > 0 && colon < trimmed.length - 1) {
        final tail = trimmed.substring(colon + 1).trim();
        if (tail.isNotEmpty) return tail;
      }
    }
    return fallback;
  }

  // Extract a boolean from a CLI reply.
  //
  // Accepts `on`, `true`, `1`, `yes` (true) and `off`, `false`, `0`,
  // `no` (false), case-insensitive. Returns null for everything
  // else (including a missing value).
  static bool? extractBool(String response) {
    final raw = extractValue(response);
    if (raw == null) return null;
    final v = raw.toLowerCase().trim();
    if (v == 'on' || v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'off' || v == 'false' || v == '0' || v == 'no') return false;
    return null;
  }

  // Extract an integer from a CLI reply.
  //
  // Strips any trailing unit suffix (e.g. `"120 min"` -> 120) by
  // taking the leading digit run. Returns null when the value-portion
  // does not start with digits.
  static int? extractInt(String response) {
    final raw = extractValue(response);
    if (raw == null) return null;
    final v = raw.trim();
    final match = RegExp(r'^-?\d+').firstMatch(v);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }
}
