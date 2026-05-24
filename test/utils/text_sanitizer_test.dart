// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/utils/text_sanitizer.dart';

void main() {
  group('sanitizeExternalText (legacy sanitizeUtf16 tests)', () {
    test('returns input for empty string', () {
      expect(sanitizeExternalText(''), '');
    });

    test('replaces unpaired high surrogate', () {
      const input = 'A\uD800B';
      const expected = 'A\uFFFDB';
      expect(sanitizeExternalText(input), expected);
    });

    test('replaces unpaired low surrogate', () {
      const input = 'A\uDC00B';
      const expected = 'A\uFFFDB';
      expect(sanitizeExternalText(input), expected);
    });

    test('preserves valid surrogate pairs', () {
      const input = 'A\uD83D\uDE03B';
      expect(sanitizeExternalText(input), input);
    });

    test('preserves valid surrogate pairs (supplementary characters)', () {
      const input = '\uD83D\uDE03\uD800\uDC00X';
      expect(sanitizeExternalText(input), input);
    });
  });

  group('sanitizeExternalText', () {
    test('returns input for empty string', () {
      expect(sanitizeExternalText(''), '');
    });

    test('passes through normal ASCII', () {
      const input = 'Hello, World!';
      expect(sanitizeExternalText(input), input);
    });

    test('passes through multilingual text', () {
      const input = '日本語テスト Привет مرحبا';
      expect(sanitizeExternalText(input), input);
    });

    test('passes through emoji', () {
      const input = '👨‍👩‍👧‍👦 🇺🇸 😃 🏳️‍🌈';
      expect(sanitizeExternalText(input), input);
    });

    test('preserves safe whitespace (tab, newline, carriage return)', () {
      const input = 'line1\tindented\nline2\r\nline3';
      expect(sanitizeExternalText(input), input);
    });

    test('strips null bytes', () {
      const input = 'hello\x00world';
      expect(sanitizeExternalText(input), 'helloworld');
    });

    test('strips C0 control characters', () {
      const input = 'he\x01ll\x02o\x03';
      expect(sanitizeExternalText(input), 'hello');
    });

    test('strips vertical tab and form feed', () {
      const input = 'a\x0Bb\x0Cc';
      expect(sanitizeExternalText(input), 'abc');
    });

    test('strips shift-in/shift-out range (0x0E-0x1F)', () {
      const input = 'a\x0E\x0F\x10\x1Fb';
      expect(sanitizeExternalText(input), 'ab');
    });

    test('strips DEL character (0x7F)', () {
      const input = 'hello\x7Fworld';
      expect(sanitizeExternalText(input), 'helloworld');
    });

    test('strips C1 control characters (0x80-0x9F)', () {
      final buffer = StringBuffer();
      buffer.write('a');
      buffer.writeCharCode(0x80);
      buffer.writeCharCode(0x85);
      buffer.writeCharCode(0x9F);
      buffer.write('b');
      expect(sanitizeExternalText(buffer.toString()), 'ab');
    });

    test('preserves characters above C1 range (0xA0+)', () {
      const input = 'café résumé naïve';
      expect(sanitizeExternalText(input), input);
    });

    test('replaces unpaired surrogates', () {
      const input = 'A\uD800B';
      expect(sanitizeExternalText(input), 'A\uFFFDB');
    });

    test('handles combined null bytes and unpaired surrogates', () {
      const input = '\x00A\uD800\x01B';
      expect(sanitizeExternalText(input), 'A\uFFFDB');
    });

    test('returns original object for already-clean input', () {
      const input = 'clean string';
      final result = sanitizeExternalText(input);
      expect(identical(result, input), isTrue);
    });

    test('handles String.fromCharCodes with binary payload', () {
      final bytes = Uint8List.fromList([
        0x48, 0x65, 0x6C, 0x6C, 0x6F, // Hello
        0x00, // null byte
        0x01, // SOH control
        0x57, 0x6F, 0x72, 0x6C, 0x64, // World
      ]);
      final decoded = String.fromCharCodes(bytes);
      expect(sanitizeExternalText(decoded), 'HelloWorld');
    });

    test('handles String.fromCharCodes with C1 control bytes', () {
      final bytes = Uint8List.fromList([
        0x54, 0x65, 0x73, 0x74, // Test
        0x80, 0x85, 0x9F, // C1 controls
        0x41, // A
      ]);
      final decoded = String.fromCharCodes(bytes);
      expect(sanitizeExternalText(decoded), 'TestA');
    });
  });

  group('sanitizeExternalTextWithStats', () {
    test('empty input reports zero repairs', () {
      final result = sanitizeExternalTextWithStats('');
      expect(result.text, '');
      expect(result.stats.controlsStripped, 0);
      expect(result.stats.surrogateRepairs, 0);
      expect(result.stats.hadAnyRepair, isFalse);
    });

    test('clean ASCII reports zero repairs', () {
      final result = sanitizeExternalTextWithStats('hello');
      expect(result.text, 'hello');
      expect(result.stats.controlsStripped, 0);
      expect(result.stats.surrogateRepairs, 0);
    });

    test('control-char-only input yields empty text and stripped count', () {
      final result = sanitizeExternalTextWithStats('\x00\x01\x02\x7F');
      expect(result.text, '');
      expect(result.stats.controlsStripped, 4);
      expect(result.stats.surrogateRepairs, 0);
      expect(result.stats.hadAnyRepair, isTrue);
    });

    test('mixed text + controls reports only stripped controls', () {
      final result = sanitizeExternalTextWithStats('he\x01ll\x02o');
      expect(result.text, 'hello');
      expect(result.stats.controlsStripped, 2);
      expect(result.stats.surrogateRepairs, 0);
    });

    test('unpaired high surrogate increments surrogateRepairs', () {
      final result = sanitizeExternalTextWithStats('A\uD800B');
      expect(result.text, 'A�B');
      expect(result.stats.controlsStripped, 0);
      expect(result.stats.surrogateRepairs, 1);
    });

    test('valid surrogate pair (emoji) reports zero repairs', () {
      // 👋 U+1F44B = 👋
      final result = sanitizeExternalTextWithStats('👋');
      expect(result.text, '👋');
      expect(result.stats.controlsStripped, 0);
      expect(result.stats.surrogateRepairs, 0);
    });

    test('control + valid emoji preserves emoji, counts the stripped byte', () {
      // \x00 + 👋 → just 👋
      final result = sanitizeExternalTextWithStats('\x00👋');
      expect(result.text, '👋');
      expect(result.stats.controlsStripped, 1);
      expect(result.stats.surrogateRepairs, 0);
    });
  });

  group('safeSubstring', () {
    test('returns empty for empty input', () {
      expect(safeSubstring('', 10), '');
    });

    test('returns empty for zero maxLength', () {
      expect(safeSubstring('hello', 0), '');
    });

    test('returns input unchanged when shorter than maxLength', () {
      const input = 'hi';
      expect(safeSubstring(input, 10), input);
    });

    test('returns input unchanged when equal to maxLength', () {
      const input = 'hello';
      expect(safeSubstring(input, 5), input);
    });

    test('truncates ASCII with ellipsis', () {
      expect(safeSubstring('hello world', 5), 'hello…');
    });

    test('preserves emoji during truncation', () {
      const input = '😃😃😃😃😃extra';
      final result = safeSubstring(input, 5);
      expect(result, '😃😃😃😃😃…');
    });

    test('does not split multi-codeunit emoji', () {
      const input = '👨‍👩‍👧‍👦AB';
      final result = safeSubstring(input, 2);
      expect(result, '👨‍👩‍👧‍👦A…');
    });

    test('handles flag emoji correctly', () {
      const input = '🇺🇸🇬🇧🇫🇷text';
      final result = safeSubstring(input, 3);
      expect(result, '🇺🇸🇬🇧🇫🇷…');
    });

    test('handles CJK text correctly', () {
      const input = '日本語テキスト';
      final result = safeSubstring(input, 3);
      expect(result, '日本語…');
    });

    test('handles Cyrillic text correctly', () {
      const input = 'Привет мир';
      final result = safeSubstring(input, 6);
      expect(result, 'Привет…');
    });

    test('handles combining characters correctly', () {
      const input = 'e\u0301e\u0301e\u0301extra';
      final result = safeSubstring(input, 3);
      expect(result, 'e\u0301e\u0301e\u0301…');
    });
  });

  group('safeTruncate', () {
    test('returns empty for empty input', () {
      expect(safeTruncate('', 10), '');
    });

    test('returns empty for zero maxLength', () {
      expect(safeTruncate('hello', 0), '');
    });

    test('returns input unchanged when shorter than maxLength', () {
      expect(safeTruncate('hi', 10), 'hi');
    });

    test('returns input unchanged when equal to maxLength', () {
      expect(safeTruncate('hello', 5), 'hello');
    });

    test('truncates ASCII without ellipsis', () {
      expect(safeTruncate('hello world', 5), 'hello');
    });

    test('avatar-initials shape: ASCII passes through', () {
      expect(safeTruncate('Alice', 2), 'Al');
    });

    test('avatar-initials shape: emoji-led name keeps emoji intact', () {
      // The exact crash pattern from Crashlytics 1d31a53e: substring(0, 2) on
      // a string with an emoji in the first position would split the high/low
      // surrogate pair and feed a lone surrogate to _NativeParagraphBuilder.
      // safeTruncate uses grapheme clusters, so the emoji stays whole.
      const input = '😃Alice';
      final result = safeTruncate(input, 2);
      expect(result, '😃A');
      expect(_hasLoneSurrogate(result), isFalse);
    });

    test('avatar-initials shape: name ending in emoji at the cut', () {
      // 'A😃rest' with substring(0, 2) leaves A + lone high surrogate.
      const input = 'A😃rest';
      final result = safeTruncate(input, 2);
      expect(result, 'A😃');
      expect(_hasLoneSurrogate(result), isFalse);
    });

    test('avatar-initials shape: flag emoji (regional indicator pair)', () {
      // Flag emoji are two regional indicator code points, each a surrogate
      // pair, four UTF-16 code units total. substring(0, 2) on '🇺🇸AB' leaves
      // the first regional indicator's high+low pair (renders as a box, not
      // a flag, but at least not lone-surrogate). Grapheme-safe truncation
      // keeps the flag whole.
      const input = '🇺🇸AB';
      final result = safeTruncate(input, 2);
      expect(result, '🇺🇸A');
      expect(_hasLoneSurrogate(result), isFalse);
    });

    test('avatar-initials shape: ZWJ family emoji stays whole', () {
      // '👨‍👩‍👧‍👦' is a single grapheme cluster made of 4 emoji joined by ZWJ,
      // 11 UTF-16 code units total. substring(0, 2) would shred it.
      const input = '👨‍👩‍👧‍👦Family';
      final result = safeTruncate(input, 2);
      expect(result, '👨‍👩‍👧‍👦F');
      expect(_hasLoneSurrogate(result), isFalse);
    });

    test('avatar-initials shape: combining mark (e + acute) stays whole', () {
      // 'é' renders as 'é' but is two code units. substring(0, 1) on
      // 'éf' would yield bare 'e' (legal but visually wrong).
      const input = 'éfg';
      final result = safeTruncate(input, 2);
      expect(result, 'éf');
    });

    test('lone high surrogate input: does not throw, returns safely', () {
      // Defensive: even if the caller hands us already-malformed input,
      // we must not crash. The truncation respects Characters semantics.
      final input = 'A\uD800B';
      final result = safeTruncate(input, 2);
      expect(
        result.codeUnits.length,
        lessThanOrEqualTo(input.codeUnits.length),
      );
    });

    test('CJK text: counts characters, not code units', () {
      expect(safeTruncate('日本語テスト', 3), '日本語');
    });
  });

  group('safeTruncateCodeUnits', () {
    test('returns input when shorter than limit', () {
      const input = 'hello';
      expect(safeTruncateCodeUnits(input, 10), input);
    });

    test('returns input when equal to limit', () {
      const input = 'hello';
      expect(safeTruncateCodeUnits(input, 5), input);
    });

    test('truncates ASCII to exact code unit count', () {
      expect(safeTruncateCodeUnits('hello world', 5), 'hello');
    });

    test('returns empty for zero limit', () {
      expect(safeTruncateCodeUnits('hello', 0), '');
    });

    test('does not split surrogate pair at boundary', () {
      // '😃' is U+1F603, encoded as two code units: \uD83D \uDE03
      const input = 'AB😃CD';
      // Code units: A(1) B(1) \uD83D(1) \uDE03(1) C(1) D(1) = 6 total
      // Truncating at 3 would land on \uDE03 (low surrogate after high at 2)
      // But \uD83D at index 2 is a high surrogate, so truncating at 3 keeps it.
      // Truncating at 2 would end right before the emoji — that's fine.
      final result = safeTruncateCodeUnits(input, 3);
      // Position 2 is high surrogate \uD83D — backs off to 2
      expect(result, 'AB');
      expect(result.length, 2);
    });

    test('keeps complete surrogate pair when limit includes both units', () {
      const input = 'A😃B';
      // Code units: A(1) \uD83D(1) \uDE03(1) B(1) = 4
      // Limit 3 → substring(0,3) = 'A\uD83D\uDE03' = 'A😃' — last char is low surrogate, fine
      final result = safeTruncateCodeUnits(input, 3);
      expect(result, 'A😃');
    });

    test('preserves BMP characters at boundary', () {
      const input = '日本語テスト';
      final result = safeTruncateCodeUnits(input, 3);
      expect(result, '日本語');
      expect(result.length, 3);
    });
  });

  group('integration: decode + sanitize pipeline', () {
    test('mesh service schema bytes with null and control chars', () {
      final payload = Uint8List.fromList([
        0x46, 0x65, 0x65, 0x64, // Feed
        0x00, // null terminator from firmware
        0x02, // STX control char
      ]);
      final raw = String.fromCharCodes(payload);
      final sanitized = sanitizeExternalText(raw);
      expect(sanitized, 'Feed');
      expect(
        sanitized.codeUnits.every(
          (u) => u > 0x1F || u == 0x09 || u == 0x0A || u == 0x0D,
        ),
        isTrue,
      );
    });

    test('SIP identity with garbage bytes produces renderable text', () {
      final nameBytes = Uint8List.fromList([
        0x4E, 0x6F, 0x64, 0x65, // Node
        0x00, 0x7F, 0x80, 0x9F, // null + DEL + C1 controls
        0x31, // 1
      ]);
      final decoded = String.fromCharCodes(nameBytes);
      final sanitized = sanitizeExternalText(decoded);
      expect(sanitized, 'Node1');
    });

    test('utf8.decode allowMalformed + sanitize handles corrupt payload', () {
      final corruptUtf8 = Uint8List.fromList([
        0x48, 0x69, // Hi
        0xFF, 0xFE, // invalid UTF-8 bytes
        0x21, // !
      ]);
      final decoded = utf8.decode(corruptUtf8, allowMalformed: true);
      final sanitized = sanitizeExternalText(decoded);
      expect(sanitized.contains('Hi'), isTrue);
      expect(sanitized.contains('!'), isTrue);
      expect(
        sanitized.codeUnits.every(
          (u) => u > 0x1F || u == 0x09 || u == 0x0A || u == 0x0D,
        ),
        isTrue,
      );
    });
  });
}

bool _hasLoneSurrogate(String s) {
  final units = s.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final u = units[i];
    final isHigh = u >= 0xD800 && u <= 0xDBFF;
    final isLow = u >= 0xDC00 && u <= 0xDFFF;
    if (isHigh) {
      if (i + 1 >= units.length) return true;
      final next = units[i + 1];
      if (next < 0xDC00 || next > 0xDFFF) return true;
      i++;
      continue;
    }
    if (isLow) return true;
  }
  return false;
}
