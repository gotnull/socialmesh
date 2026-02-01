// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/utils/number_format.dart';

void main() {
  group('NumberFormatUtils', () {
    group('formatWithThousandsSeparators', () {
      test('formats single digit numbers without separators', () {
        expect(NumberFormatUtils.formatWithThousandsSeparators(0), '0');
        expect(NumberFormatUtils.formatWithThousandsSeparators(5), '5');
        expect(NumberFormatUtils.formatWithThousandsSeparators(9), '9');
      });

      test('formats two digit numbers without separators', () {
        expect(NumberFormatUtils.formatWithThousandsSeparators(10), '10');
        expect(NumberFormatUtils.formatWithThousandsSeparators(99), '99');
      });

      test('formats three digit numbers without separators', () {
        expect(NumberFormatUtils.formatWithThousandsSeparators(100), '100');
        expect(NumberFormatUtils.formatWithThousandsSeparators(999), '999');
      });

      test('formats four digit numbers with one separator', () {
        expect(NumberFormatUtils.formatWithThousandsSeparators(1000), '1,000');
        expect(NumberFormatUtils.formatWithThousandsSeparators(1107), '1,107');
        expect(NumberFormatUtils.formatWithThousandsSeparators(9999), '9,999');
      });

      test('formats five digit numbers with one separator', () {
        expect(
          NumberFormatUtils.formatWithThousandsSeparators(10000),
          '10,000',
        );
        expect(
          NumberFormatUtils.formatWithThousandsSeparators(12345),
          '12,345',
        );
      });

      test('formats six digit numbers with two separators', () {
        expect(
          NumberFormatUtils.formatWithThousandsSeparators(100000),
          '100,000',
        );
        expect(
          NumberFormatUtils.formatWithThousandsSeparators(123456),
          '123,456',
        );
      });

      test('formats seven digit numbers with two separators', () {
        expect(
          NumberFormatUtils.formatWithThousandsSeparators(1000000),
          '1,000,000',
        );
        expect(
          NumberFormatUtils.formatWithThousandsSeparators(1234567),
          '1,234,567',
        );
      });

      test('formats negative numbers with separators', () {
        expect(
          NumberFormatUtils.formatWithThousandsSeparators(-1107),
          '-1,107',
        );
      });
    });

    group('formatCount', () {
      test('formats count without suffix', () {
        expect(NumberFormatUtils.formatCount(1107), '1,107');
        expect(NumberFormatUtils.formatCount(5), '5');
      });

      test('formats count with suffix', () {
        expect(NumberFormatUtils.formatCount(1107, suffix: '×'), '1,107×');
        expect(NumberFormatUtils.formatCount(5, suffix: '×'), '5×');
        expect(
          NumberFormatUtils.formatCount(1000000, suffix: ' nodes'),
          '1,000,000 nodes',
        );
      });
    });
  });
}
