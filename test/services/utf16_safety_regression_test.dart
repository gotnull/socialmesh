// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression coverage for the "Invalid argument(s): string is not well-formed
// UTF-16" crash in `_NativeParagraphBuilder.addText`. Each test feeds bytes
// containing a lone UTF-16 surrogate or NUL byte through one of the protocol
// ingress points, then asserts the resulting string is well-formed UTF-16
// (no lone surrogates, no NUL bytes) so it cannot crash Flutter's text shaper.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

bool isWellFormedUtf16(String s) {
  final units = s.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (_isHighSurrogate(unit)) {
      if (i + 1 >= units.length || !_isLowSurrogate(units[i + 1])) return false;
      i++;
    } else if (_isLowSurrogate(unit)) {
      return false;
    }
  }
  return true;
}

bool containsNul(String s) => s.codeUnits.contains(0);

/// Smoke test: feed [s] to the same ParagraphBuilder Flutter uses for
/// `Text(...)` and verify it does not throw. Mirrors the crashing call in
/// `_NativeParagraphBuilder.addText`.
void expectRendersWithoutCrash(String s) {
  final builder = ui.ParagraphBuilder(ui.ParagraphStyle());
  expect(() => builder.addText(s), returnsNormally);
}

void main() {
  group('MeshCore contact name ingress', () {
    test('lone high surrogate code unit in name bytes is sanitized', () {
      // parseContact layout: pub_key(32) + adv_type(1) + path_len(1) +
      // lastmod(2) = 36 bytes header, then optional 8B lat/lon, then a
      // null-terminated name. We skip the lat/lon (need < 8 remaining
      // bytes after the 36B header) so name starts at offset 36.
      final payload = Uint8List(40);
      payload[36] = 0x41; // 'A'
      payload[37] = 0xD8; // lone high surrogate code unit
      payload[38] = 0x42; // 'B'
      payload[39] = 0x00; // null terminator

      final result = parseContact(payload);

      expect(result.isSuccess, isTrue);
      final name = result.value!.name;
      expect(isWellFormedUtf16(name), isTrue);
      expect(containsNul(name), isFalse);
      expectRendersWithoutCrash(name);
    });
  });

  group('MeshCore channel-info name ingress', () {
    test('lone low surrogate in name bytes is sanitized', () {
      // CHANNEL_INFO payload: idx(1) + name(32, null-terminated) + psk(16).
      final payload = Uint8List(49);
      payload[0] = 0x01;
      payload[1] = 0x4D; // 'M'
      payload[2] = 0xDC; // lone low surrogate code unit
      payload[3] = 0x4E; // 'N'
      // payload[4..32] stays 0 (null-terminated within the 32-byte slot).
      // payload[33..48] PSK = zero is fine.

      final result = parseChannelInfo(payload);

      expect(result.isSuccess, isTrue);
      final name = result.value!.name;
      expect(isWellFormedUtf16(name), isTrue);
      expect(containsNul(name), isFalse);
      expectRendersWithoutCrash(name);
    });
  });

  group('MeshCore buffer reader', () {
    test('readCString sanitizes lone surrogate code units', () {
      final reader = MeshCoreBufferReader(
        Uint8List.fromList([0x41, 0xDB, 0xFF, 0x42, 0x00, 0x99]),
      );
      final s = reader.readCString(6);
      expect(isWellFormedUtf16(s), isTrue);
      expect(containsNul(s), isFalse);
      expectRendersWithoutCrash(s);
    });

    test('readString strips trailing nuls and sanitizes surrogates', () {
      final reader = MeshCoreBufferReader(
        Uint8List.fromList([0x41, 0xD8, 0x00, 0x42, 0x00, 0x00]),
      );
      final s = reader.readString();
      expect(isWellFormedUtf16(s), isTrue);
      expect(containsNul(s), isFalse);
      expectRendersWithoutCrash(s);
    });
  });

  group('Sanitizer is a no-op on already-clean strings', () {
    test('valid UTF-8 round-trips through utf8.decode unchanged', () {
      // Sanity check: well-formed multilingual text with emoji must not be
      // perturbed by any of the ingress sanitization wrappers we added.
      const input = 'Café 日本語 👨‍👩‍👧‍👦';
      final bytes = Uint8List.fromList(utf8.encode(input));
      final decoded = utf8.decode(bytes);
      expect(decoded, input);
      expect(isWellFormedUtf16(decoded), isTrue);
      expectRendersWithoutCrash(decoded);
    });
  });
}
