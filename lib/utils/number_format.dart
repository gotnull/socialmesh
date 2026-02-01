// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:intl/intl.dart';

/// Number formatting utilities.
class NumberFormatUtils {
  static final _thousandsFormatter = NumberFormat.decimalPattern('en_US');

  /// Format integer with thousands separators (e.g., 1107 → "1,107").
  /// Returns the number as-is for small values (< 1000).
  static String formatWithThousandsSeparators(int value) {
    return _thousandsFormatter.format(value);
  }

  /// Format count with thousands separators and optional suffix.
  /// Example: formatCount(1107, suffix: '×') → "1,107×"
  static String formatCount(int value, {String? suffix}) {
    final formatted = formatWithThousandsSeparators(value);
    return suffix != null ? '$formatted$suffix' : formatted;
  }
}
