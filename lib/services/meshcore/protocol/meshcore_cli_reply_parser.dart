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

  // D49-D1: Extract a decimal value from a CLI reply. Used for lat /
  // lon / freq / tx replies that may carry a trailing unit suffix
  // (e.g. `"868.0 MHz"`). Returns null when the value-portion does
  // not start with a sign-or-digit-or-dot character.
  static double? extractDouble(String response) {
    final raw = extractValue(response);
    if (raw == null) return null;
    final v = raw.trim();
    final match = RegExp(r'^-?\d+(?:\.\d+)?').firstMatch(v);
    if (match == null) return null;
    return double.tryParse(match.group(0)!);
  }

  // D49-D1: Parse `get radio` reply into its four canonical numeric
  // fields. The firmware reply takes the shape
  // `"<freqMHz>,<bwKHz>,<sf>,<cr>"` (e.g. `"908.205017,62.5,10,7"`).
  //
  // Returns null on shape mismatch (too few fields, any field
  // non-numeric). Stripping of trailing whitespace + colon-prefix
  // happens in [extractValue] before the CSV split; the value-portion
  // we operate on is the CSV itself.
  //
  // Range validation lives at the UI layer — this helper is purely
  // structural so the caller can surface "firmware returned an
  // out-of-range value" separately from "firmware returned a garbled
  // reply".
  static ParsedMeshCoreRadioReply? parseRadioReply(String response) {
    final v = extractValue(response);
    if (v == null) return null;
    final parts = v.split(',').map((p) => p.trim()).toList();
    if (parts.length < 4) return null;
    final freq = double.tryParse(parts[0]);
    final bw = double.tryParse(parts[1]);
    final sf = int.tryParse(parts[2]);
    final cr = int.tryParse(parts[3]);
    if (freq == null || bw == null || sf == null || cr == null) {
      return null;
    }
    return ParsedMeshCoreRadioReply(
      freqMHz: freq,
      bandwidthKhz: bw,
      spreadingFactor: sf,
      codingRate: cr,
    );
  }
}

// D49-D1: value class for the four canonical radio params surfaced by
// the firmware's `get radio` reply.
class ParsedMeshCoreRadioReply {
  final double freqMHz;
  final double bandwidthKhz;
  final int spreadingFactor;
  final int codingRate;

  const ParsedMeshCoreRadioReply({
    required this.freqMHz,
    required this.bandwidthKhz,
    required this.spreadingFactor,
    required this.codingRate,
  });
}
