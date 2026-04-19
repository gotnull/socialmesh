// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodeboard/services/ansi_sanitizer.dart';

void main() {
  group('AnsiSanitizer.sanitize', () {
    test('strips CSI escape sequences', () {
      const input = '\x1B[31mRED\x1B[0m text \x1B[1;32mgreen\x1B[m';
      expect(AnsiSanitizer.sanitize(input), 'RED text green');
    });

    test('strips CSI with no params', () {
      expect(AnsiSanitizer.sanitize('\x1B[Hhome'), 'home');
    });

    test('strips bare ESC', () {
      expect(AnsiSanitizer.sanitize('a\x1Bb'), 'ab');
    });

    test('strips null bytes', () {
      expect(AnsiSanitizer.sanitize('hello\u0000world'), 'helloworld');
    });

    test('strips DEL and C1 control chars', () {
      expect(AnsiSanitizer.sanitize('x\u007Fy\u0080z\u009F'), 'xyz');
    });

    test('preserves box-drawing characters', () {
      const splash = '╔══╗\n║  ║\n╚══╝';
      expect(AnsiSanitizer.sanitize(splash), splash);
    });

    test('preserves newlines', () {
      expect(AnsiSanitizer.sanitize('a\nb\nc'), 'a\nb\nc');
    });

    test('caps at maxLength', () {
      final big = 'x' * 5000;
      expect(AnsiSanitizer.sanitize(big, maxLength: 100).length, 100);
    });

    test('returns empty for all-unsafe input', () {
      expect(AnsiSanitizer.sanitize('\x1B[31m\x1B[0m\u0000'), '');
    });
  });

  group('AnsiSanitizer.sanitizeLines', () {
    test('splits by newline', () {
      expect(AnsiSanitizer.sanitizeLines('a\nb\nc'), ['a', 'b', 'c']);
    });

    test('handles empty lines', () {
      expect(AnsiSanitizer.sanitizeLines('a\n\nb'), ['a', '', 'b']);
    });

    test('sanitizes each line of ANSI input', () {
      const input = '\x1B[32mline1\x1B[0m\n\x1B[31mline2\x1B[0m';
      expect(AnsiSanitizer.sanitizeLines(input), ['line1', 'line2']);
    });
  });
}
