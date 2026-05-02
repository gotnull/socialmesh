// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/utils/utf8_byte_length_formatter.dart';

void main() {
  group('Utf8ByteLengthFormatter', () {
    TextEditingValue apply(String input, {required int maxBytes}) {
      return Utf8ByteLengthFormatter(maxBytes).formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: input,
          selection: TextSelection.collapsed(offset: input.length),
        ),
      );
    }

    test('passes through ASCII input under the byte cap', () {
      final out = apply('mqtt.example.com', maxBytes: 62);
      expect(out.text, 'mqtt.example.com');
      expect(out.selection.baseOffset, 'mqtt.example.com'.length);
    });

    test('passes through ASCII input exactly at the byte cap', () {
      final input = 'a' * 62;
      final out = apply(input, maxBytes: 62);
      expect(out.text, input);
    });

    test('truncates ASCII input over the byte cap from the right', () {
      final input = 'a' * 70;
      final out = apply(input, maxBytes: 62);
      expect(out.text, 'a' * 62);
      expect(out.selection.baseOffset, 62);
    });

    test('truncates multi-byte (CJK) input by UTF-8 bytes, not chars', () {
      // Each Chinese char is 3 UTF-8 bytes.  10 chars = 30 bytes (fits).
      // 11 chars = 33 bytes (overflows the 30B password limit).
      final input = '中' * 11;
      final out = apply(input, maxBytes: 30);
      expect(out.text, '中' * 10);
      // 30 bytes / 3 bytes-per-char = 10 chars. UTF-16 length = 10.
      expect(out.selection.baseOffset, 10);
    });

    test('truncates emoji input by UTF-8 bytes', () {
      // U+1F600 GRINNING FACE encodes as 4 UTF-8 bytes and uses two UTF-16
      // code units (surrogate pair).  Input of 8 emojis = 32 UTF-8 bytes,
      // overflows a 30B cap.
      final input = '\u{1F600}' * 8;
      final out = apply(input, maxBytes: 30);
      // Truncation must drop the trailing surrogate pair entirely, never
      // leaving a half-pair that crashes downstream UTF-8 decoders.
      expect(out.text.contains('\u{1F600}'), isTrue);
      // Resulting byte count must be within budget.
      expect(out.text.codeUnits, hasLength(lessThanOrEqualTo(14)));
    });

    test('returns input unchanged when empty', () {
      final out = apply('', maxBytes: 30);
      expect(out.text, '');
    });

    test('handles boundary right at maxBytes with mixed ASCII + multibyte', () {
      // 'a' (1B) + '中' (3B) + '中' (3B) = 7 bytes — fits in 7.
      final out = apply('a中中', maxBytes: 7);
      expect(out.text, 'a中中');
      // Same input, cap at 6 → drop last '中', leaves 'a中' (4B).
      final out2 = apply('a中中', maxBytes: 6);
      expect(out2.text, 'a中');
    });

    test('rejects construction with non-positive maxBytes', () {
      expect(() => Utf8ByteLengthFormatter(0), throwsA(isA<AssertionError>()));
      expect(() => Utf8ByteLengthFormatter(-1), throwsA(isA<AssertionError>()));
    });
  });
}
