import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/utils/text_sanitizer.dart';

void main() {
  group('sanitizeUtf16', () {
    test('returns input for empty string', () {
      expect(sanitizeUtf16(''), '');
    });

    test('replaces unpaired high surrogate', () {
      const input = 'A\uD800B';
      const expected = 'A\uFFFDB';
      expect(sanitizeUtf16(input), expected);
    });

    test('replaces unpaired low surrogate', () {
      const input = 'A\uDC00B';
      const expected = 'A\uFFFDB';
      expect(sanitizeUtf16(input), expected);
    });

    test('preserves valid surrogate pairs', () {
      const input = 'A\uD83D\uDE03B';
      expect(sanitizeUtf16(input), input);
    });

    test('handles mixed valid and invalid sequences', () {
      const input = '\uD83D\uDE03\uD800\uDC00X';
      const expected = '\uD83D\uDE03\uFFFD\uFFFDX';
      expect(sanitizeUtf16(input), expected);
    });
  });
}
