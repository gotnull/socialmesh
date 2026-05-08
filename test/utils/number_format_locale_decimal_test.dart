// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/utils/number_format.dart';

/// Pins the `tryParseLocaleDouble` contract used by frequency-override
/// and ADC-multiplier text fields. Without this, IT/DE/FR/RU/ES users
/// whose system keyboard puts a comma on the decimal key get a silent
/// 0.0 fallback at the call site.
void main() {
  group('NumberFormatUtils.tryParseLocaleDouble', () {
    test('null and empty inputs return null', () {
      expect(NumberFormatUtils.tryParseLocaleDouble(null), isNull);
      expect(NumberFormatUtils.tryParseLocaleDouble(''), isNull);
      expect(NumberFormatUtils.tryParseLocaleDouble('   '), isNull);
    });

    test('dot-separated decimal parses', () {
      expect(NumberFormatUtils.tryParseLocaleDouble('869.075'), 869.075);
      expect(NumberFormatUtils.tryParseLocaleDouble('2.5'), 2.5);
      expect(NumberFormatUtils.tryParseLocaleDouble('0.0'), 0.0);
    });

    test('comma-separated decimal parses to the same value', () {
      // The headline regression-fix property: locale-comma input must
      // parse identically to locale-dot input.
      expect(NumberFormatUtils.tryParseLocaleDouble('869,075'), 869.075);
      expect(NumberFormatUtils.tryParseLocaleDouble('2,5'), 2.5);
      expect(NumberFormatUtils.tryParseLocaleDouble('0,0'), 0.0);
    });

    test('whitespace is trimmed', () {
      expect(NumberFormatUtils.tryParseLocaleDouble(' 869.075 '), 869.075);
      expect(NumberFormatUtils.tryParseLocaleDouble('\t869,075\n'), 869.075);
    });

    test('integer input parses', () {
      expect(NumberFormatUtils.tryParseLocaleDouble('869'), 869.0);
      expect(NumberFormatUtils.tryParseLocaleDouble('0'), 0.0);
    });

    test('mixed separators are rejected as ambiguous', () {
      // "1.234,56" (European thousands+decimal) and "1,234.56" (US
      // thousands+decimal) are genuinely ambiguous when only one
      // could be the decimal indicator. Frequency / multiplier fields
      // never need thousands separators, so reject rather than guess.
      expect(NumberFormatUtils.tryParseLocaleDouble('1.234,56'), isNull);
      expect(NumberFormatUtils.tryParseLocaleDouble('1,234.56'), isNull);
    });

    test('multiple of the same separator are rejected', () {
      expect(NumberFormatUtils.tryParseLocaleDouble('1,234,567'), isNull);
      expect(NumberFormatUtils.tryParseLocaleDouble('1.234.567'), isNull);
      expect(NumberFormatUtils.tryParseLocaleDouble('86,9,075'), isNull);
    });

    test('non-numeric input returns null', () {
      expect(NumberFormatUtils.tryParseLocaleDouble('abc'), isNull);
      expect(NumberFormatUtils.tryParseLocaleDouble('869.07x'), isNull);
      expect(NumberFormatUtils.tryParseLocaleDouble('--869.075'), isNull);
    });

    test('negative numbers parse (both separators)', () {
      // Frequency / multiplier inputs in our app never accept negative
      // values, but the helper itself should not invent rejection
      // rules. Range gates live at call sites (e.g. ADC multiplier
      // requires 2.0 <= x <= 6.0).
      expect(NumberFormatUtils.tryParseLocaleDouble('-869.075'), -869.075);
      expect(NumberFormatUtils.tryParseLocaleDouble('-869,075'), -869.075);
    });

    test('leading + sign is accepted (matches double.tryParse)', () {
      expect(NumberFormatUtils.tryParseLocaleDouble('+869.075'), 869.075);
      expect(NumberFormatUtils.tryParseLocaleDouble('+869,075'), 869.075);
    });
  });
}
