// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../models/accessibility_preferences.dart';
import '../services/accessibility_preferences_service.dart';

/// Centralized date and time formatting that respects the user's format
/// preferences (see [AccessibilityPreferences]).
///
/// Time honours the time format preference:
/// - **System Default** follows the device's 24-hour clock setting
/// - **12-hour** always uses AM/PM format (e.g. 1:30 PM)
/// - **24-hour** always uses 24-hour format (e.g. 13:30)
///
/// Date order honours the date format preference (System / MM/DD/YYYY /
/// DD/MM/YYYY / YYYY-MM-DD). Month names, when shown, follow the active locale;
/// the preference only controls component ordering. Build dates via [fullDate],
/// [monthDay], [numericDate], or the date+time combos rather than constructing
/// raw [DateFormat] patterns, so every surface stays consistent.
///
/// Usage in widget build methods (preferred — reactive to setting changes):
/// ```dart
/// final fmt = AppTimeFormat.timeOnly(context);
/// Text(fmt.format(timestamp));
/// ```
///
/// Usage outside widgets (reads from service singleton, not reactive):
/// ```dart
/// final fmt = AppTimeFormat.timeOnlyFromPreferences();
/// ```
abstract final class AppTimeFormat {
  // ---------------------------------------------------------------------------
  // Core resolution
  // ---------------------------------------------------------------------------

  /// Whether 24-hour format should be used, based on user preference.
  ///
  /// Reads the user's choice from [AccessibilityPreferencesService] singleton
  /// (always pre-initialized and kept in sync by the notifier). For
  /// [TimeFormatMode.system], falls back to [MediaQuery.alwaysUse24HourFormatOf].
  static bool is24Hour(BuildContext context) {
    final mode = AccessibilityPreferencesService().current.timeFormatMode;
    switch (mode) {
      case TimeFormatMode.system:
        return MediaQuery.alwaysUse24HourFormatOf(context);
      case TimeFormatMode.twelveHour:
        return false;
      case TimeFormatMode.twentyFourHour:
        return true;
    }
  }

  /// Whether 24-hour format should be used, without a [BuildContext].
  ///
  /// Reads directly from the [AccessibilityPreferencesService] singleton.
  /// For [TimeFormatMode.system], defaults to `false` (12-hour) since
  /// [MediaQuery] is not available.
  static bool is24HourFromPreferences() {
    final mode = AccessibilityPreferencesService().current.timeFormatMode;
    switch (mode) {
      case TimeFormatMode.system:
        return false; // Safe fallback when no BuildContext
      case TimeFormatMode.twelveHour:
        return false;
      case TimeFormatMode.twentyFourHour:
        return true;
    }
  }

  // ---------------------------------------------------------------------------
  // Date-ordering resolution
  // ---------------------------------------------------------------------------

  /// The active date-ordering preference from the user's settings.
  static DateFormatMode dateMode() {
    return AccessibilityPreferencesService().current.dateFormatMode;
  }

  /// Locale name for date symbol lookup. The current locale's `intl` date
  /// symbols are guaranteed loaded by `GlobalMaterialLocalizations`, so passing
  /// this to [DateFormat] is safe even for month/day name patterns.
  static String _localeName(BuildContext context) =>
      Localizations.localeOf(context).toString();

  /// Full date with month name and year, ordered per the user's preference —
  /// e.g. "Jan 3, 2026", "3 Jan 2026", or "2026 Jan 3". For
  /// [DateFormatMode.system] the order follows the active locale.
  static String fullDatePattern(BuildContext context) {
    switch (dateMode()) {
      case DateFormatMode.system:
        return DateFormat.yMMMd(_localeName(context)).pattern ?? 'MMM d, yyyy';
      case DateFormatMode.monthDayYear:
        return 'MMM d, yyyy';
      case DateFormatMode.dayMonthYear:
        return 'd MMM yyyy';
      case DateFormatMode.yearMonthDay:
        return 'yyyy MMM d';
    }
  }

  /// Month name and day without year, ordered per preference —
  /// e.g. "Jan 3" or "3 Jan".
  static String monthDayPattern(BuildContext context) {
    switch (dateMode()) {
      case DateFormatMode.system:
        return DateFormat.MMMd(_localeName(context)).pattern ?? 'MMM d';
      case DateFormatMode.dayMonthYear:
        return 'd MMM';
      case DateFormatMode.monthDayYear:
      case DateFormatMode.yearMonthDay:
        return 'MMM d';
    }
  }

  /// All-numeric date, ordered per preference —
  /// e.g. "01/03/2026", "03/01/2026", or "2026-01-03".
  static String numericDatePattern(BuildContext context) {
    switch (dateMode()) {
      case DateFormatMode.system:
        return DateFormat.yMd(_localeName(context)).pattern ?? 'dd/MM/yyyy';
      case DateFormatMode.monthDayYear:
        return 'MM/dd/yyyy';
      case DateFormatMode.dayMonthYear:
        return 'dd/MM/yyyy';
      case DateFormatMode.yearMonthDay:
        return 'yyyy-MM-dd';
    }
  }

  /// Full date ([fullDatePattern]) as a ready-to-use [DateFormat].
  static DateFormat fullDate(BuildContext context) =>
      DateFormat(fullDatePattern(context), _localeName(context));

  /// Month + day ([monthDayPattern]) as a ready-to-use [DateFormat].
  static DateFormat monthDay(BuildContext context) =>
      DateFormat(monthDayPattern(context), _localeName(context));

  /// Numeric date ([numericDatePattern]) as a ready-to-use [DateFormat].
  static DateFormat numericDate(BuildContext context) =>
      DateFormat(numericDatePattern(context), _localeName(context));

  /// Weekday name + date, ordered per preference —
  /// e.g. "Friday, Jan 3, 2026" or "Friday, 3 Jan 2026". Pass
  /// `withYear: false` for a weekday + month/day label without the year.
  static DateFormat weekdayDate(BuildContext context, {bool withYear = true}) {
    final datePat = withYear
        ? fullDatePattern(context)
        : monthDayPattern(context);
    return DateFormat('EEEE, $datePat', _localeName(context));
  }

  // ---------------------------------------------------------------------------
  // Time-only patterns
  // ---------------------------------------------------------------------------

  /// Time without seconds — e.g. "2:30 PM" or "14:30".
  static DateFormat timeOnly(BuildContext context) {
    return is24Hour(context) ? DateFormat('HH:mm') : DateFormat('h:mm a');
  }

  /// Time without seconds, without [BuildContext].
  static DateFormat timeOnlyFromPreferences() {
    return is24HourFromPreferences()
        ? DateFormat('HH:mm')
        : DateFormat('h:mm a');
  }

  /// Time with seconds — e.g. "2:30:15 PM" or "14:30:15".
  static DateFormat timeWithSeconds(BuildContext context) {
    return is24Hour(context) ? DateFormat('HH:mm:ss') : DateFormat('h:mm:ss a');
  }

  // ---------------------------------------------------------------------------
  // Date + time patterns
  // ---------------------------------------------------------------------------

  /// Short month + day + time, e.g. "Jan 5, 2:30 PM" or "Jan 5, 14:30".
  /// Date order honours the user's date format preference.
  static DateFormat dateAndTime(BuildContext context) {
    return DateFormat(
      '${monthDayPattern(context)}, ${timePattern(context)}',
      _localeName(context),
    );
  }

  /// Short month + day + time (compact, no space before am/pm),
  /// e.g. "Jan 5, 2:30PM" or "Jan 5, 14:30".
  static DateFormat dateAndTimeCompact(BuildContext context) {
    final timePat = is24Hour(context) ? 'HH:mm' : 'h:mma';
    return DateFormat(
      '${monthDayPattern(context)}, $timePat',
      _localeName(context),
    );
  }

  /// Full date + time, e.g. "Jan 5, 2025 2:30 PM" or "Jan 5, 2025 14:30".
  /// Date order honours the user's date format preference.
  static DateFormat fullDateAndTime(BuildContext context) {
    return DateFormat(
      '${fullDatePattern(context)} ${timePattern(context)}',
      _localeName(context),
    );
  }

  /// Full date + time with bullet separator —
  /// e.g. "Jan 5, 2025 • 2:30 PM" or "Jan 5, 2025 • 14:30".
  static DateFormat fullDateBulletTime(BuildContext context) {
    return DateFormat(
      "${fullDatePattern(context)} '\u2022' ${timePattern(context)}",
      _localeName(context),
    );
  }

  /// Numeric date + time with seconds,
  /// e.g. "01/05/2025, 2:30:15 PM" or "05/01/2025, 14:30:15".
  static DateFormat numericDateAndTimeWithSeconds(BuildContext context) {
    return DateFormat(
      '${numericDatePattern(context)}, ${timeWithSecondsPattern(context)}',
      _localeName(context),
    );
  }

  /// Numeric date + time (no seconds),
  /// e.g. "01/05/2025, 2:30PM" or "05/01/2025, 14:30".
  static DateFormat numericDateAndTime(BuildContext context) {
    final timePat = is24Hour(context) ? 'HH:mm' : 'h:mma';
    return DateFormat(
      '${numericDatePattern(context)}, $timePat',
      _localeName(context),
    );
  }

  // ---------------------------------------------------------------------------
  // Raw pattern helpers
  // ---------------------------------------------------------------------------

  /// Returns just the time pattern string — "HH:mm" or "h:mm a".
  static String timePattern(BuildContext context) {
    return is24Hour(context) ? 'HH:mm' : 'h:mm a';
  }

  /// Returns the time-with-seconds pattern — "HH:mm:ss" or "h:mm:ss a".
  static String timeWithSecondsPattern(BuildContext context) {
    return is24Hour(context) ? 'HH:mm:ss' : 'h:mm:ss a';
  }

  /// Builds a [DateFormat] by combining a caller-supplied date pattern with
  /// the user-appropriate time pattern.
  ///
  /// Example:
  /// ```dart
  /// final fmt = AppTimeFormat.withDatePrefix(context, 'MMM d, yyyy \u2022');
  /// // → "MMM d, yyyy • HH:mm" or "MMM d, yyyy • h:mm a"
  /// ```
  static DateFormat withDatePrefix(BuildContext context, String datePrefix) {
    return DateFormat(
      '$datePrefix ${timePattern(context)}',
      _localeName(context),
    );
  }

  // ---------------------------------------------------------------------------
  // Calendar-relative date + time (for detail/metadata surfaces)
  // ---------------------------------------------------------------------------

  /// Full local date + time for detail surfaces, using calendar-relative
  /// labels for recent days. Produces, with the phone's local timezone:
  ///
  /// - "Today, 22:27" when [timestamp] falls on the current local day
  /// - "Yesterday, 22:27" when it falls on the previous local day
  /// - "3 Jun 2026, 22:27" for any older day
  ///
  /// The time portion honours the user's 12/24-hour preference. The relative
  /// day labels are supplied by the caller so this utility stays free of any
  /// localization dependency. [now] is injectable for deterministic tests;
  /// it defaults to the current wall clock.
  static String relativeDateTime(
    BuildContext context,
    DateTime timestamp, {
    required String todayLabel,
    required String yesterdayLabel,
    DateTime? now,
  }) {
    final local = timestamp.toLocal();
    final reference = (now ?? DateTime.now()).toLocal();
    final today = DateTime(reference.year, reference.month, reference.day);
    final messageDay = DateTime(local.year, local.month, local.day);
    final dayDelta = today.difference(messageDay).inDays;

    final timeText = DateFormat(timePattern(context)).format(local);

    if (dayDelta == 0) {
      return '$todayLabel, $timeText';
    }
    if (dayDelta == 1) {
      return '$yesterdayLabel, $timeText';
    }
    final dateText = DateFormat(
      fullDatePattern(context),
      _localeName(context),
    ).format(local);
    return '$dateText, $timeText';
  }
}
