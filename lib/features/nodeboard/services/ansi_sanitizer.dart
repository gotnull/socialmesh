// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Safely prepares user-supplied ANSI/ASCII art (splash text, headers) for
// rendering as Flutter Text widgets. Strips ANSI escape sequences (ESC [
// codes), control bytes, and malformed UTF, keeping only printable chars
// plus whitespace/newlines and the set of box-drawing / block glyphs
// commonly used in BBS art.
//
// The terminal mode is an AESTHETIC LAYER, not a protocol emulator. We
// do NOT interpret ANSI colour escapes at runtime — preset palettes drive
// colour. Inputs that rely on raw escapes are reduced to plain characters.

import '../../../utils/text_sanitizer.dart';

class AnsiSanitizer {
  /// ESC 0x1B followed by CSI `[` then any params/intermediate bytes and
  /// the final byte in range 0x40-0x7E. Stripped wholesale.
  static final RegExp _csi = RegExp(r'\x1B\[[0-9;?]*[A-Za-z]');

  /// Other ESC sequences (OSC, single-char). Conservative: drop ESC +
  /// single follow byte. Full OSC parsing is out of scope.
  static final RegExp _esc = RegExp(r'\x1B[\(\)\*\+\-\.\/][0-9A-Za-z]?');

  /// Bare ESC anywhere in the stream.
  static final RegExp _bareEsc = RegExp(r'\x1B');

  /// Sanitize an ANSI splash for safe terminal rendering.
  /// Order of operations:
  ///   1. Strip CSI escape sequences.
  ///   2. Strip other ESC sequences.
  ///   3. Strip any remaining bare ESC bytes.
  ///   4. Apply sanitizeExternalText() to handle control chars + surrogates.
  ///   5. Cap output length (defense against pathological inputs).
  static String sanitize(String input, {int maxLength = 4000}) {
    var out = input.replaceAll(_csi, '');
    out = out.replaceAll(_esc, '');
    out = out.replaceAll(_bareEsc, '');
    out = sanitizeExternalText(out);
    if (out.length > maxLength) {
      out = out.substring(0, maxLength);
    }
    return out;
  }

  /// Sanitize and split into lines for per-line rendering.
  static List<String> sanitizeLines(String input, {int maxLength = 4000}) {
    final cleaned = sanitize(input, maxLength: maxLength);
    return cleaned.split('\n');
  }
}
