// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
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
  /// Example: formatCount(1107, suffix: 'x') → "1,107x"
  static String formatCount(int value, {String? suffix}) {
    final formatted = formatWithThousandsSeparators(value);
    return suffix != null ? '$formatted$suffix' : formatted;
  }

  /// Locale-aware parse for free-form decimal text input.
  ///
  /// Dart's `double.tryParse` only accepts dot-separated decimals
  /// ("869.075"). Users in IT / DE / FR / RU / ES locales whose system
  /// keyboard puts a comma on the decimal key end up typing "869,075",
  /// which `double.tryParse` rejects. Without normalisation, the call
  /// site falls through to 0.0 silently. Use this helper for any
  /// user-typed decimal value (frequency override, ADC multiplier,
  /// etc.) so both forms parse identically.
  ///
  /// Rules:
  /// - `null` / empty / whitespace-only -> `null`.
  /// - Single `.` or single `,` -> normalised and parsed.
  /// - Mixed (e.g. `"1.234,56"` or `"1,234.56"`) -> rejected as
  ///   ambiguous. Frequency / multiplier inputs never need thousands
  ///   separators, so accepting them risks misinterpretation.
  /// - Multiple of the same separator (e.g. `"1,234,567"`) -> rejected.
  /// - Anything `double.tryParse` rejects after normalisation ->
  ///   `null`.
  static double? tryParseLocaleDouble(String? text) {
    if (text == null) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final commaCount = trimmed.split(',').length - 1;
    final dotCount = trimmed.split('.').length - 1;

    if (commaCount > 0 && dotCount > 0) return null;
    if (commaCount > 1 || dotCount > 1) return null;

    final normalised = commaCount == 1 ? trimmed.replaceAll(',', '.') : trimmed;
    return double.tryParse(normalised);
  }
}
