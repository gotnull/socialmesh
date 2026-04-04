// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../models/accessibility_preferences.dart';
import '../services/accessibility_preferences_service.dart';

/// Centralized time formatting that respects the user's time format preference.
///
/// The user can choose between:
/// - **System Default** — follows the device's 24-hour clock setting
/// - **12-hour** — always uses AM/PM format (e.g. 1:30 PM)
/// - **24-hour** — always uses 24-hour format (e.g. 13:30)
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

  /// Short month + day + time — e.g. "Jan 5, 2:30 PM" or "Jan 5, 14:30".
  static DateFormat dateAndTime(BuildContext context) {
    return is24Hour(context)
        ? DateFormat('MMM d, HH:mm')
        : DateFormat('MMM d, h:mm a');
  }

  /// Short month + day + time (compact, no space before am/pm) —
  /// e.g. "Jan 5, 2:30PM" or "Jan 5, 14:30".
  static DateFormat dateAndTimeCompact(BuildContext context) {
    return is24Hour(context)
        ? DateFormat('MMM d, HH:mm')
        : DateFormat('MMM d, h:mma');
  }

  /// Full date + time — e.g. "Jan 5, 2025 2:30 PM" or "Jan 5, 2025 14:30".
  static DateFormat fullDateAndTime(BuildContext context) {
    return is24Hour(context)
        ? DateFormat('MMM d, yyyy HH:mm')
        : DateFormat('MMM d, yyyy h:mm a');
  }

  /// Full date + time with bullet separator —
  /// e.g. "Jan 5, 2025 • 2:30 PM" or "Jan 5, 2025 • 14:30".
  static DateFormat fullDateBulletTime(BuildContext context) {
    return is24Hour(context)
        ? DateFormat("MMM d, yyyy '\u2022' HH:mm")
        : DateFormat("MMM d, yyyy '\u2022' h:mm a");
  }

  /// Day/month/year + time with seconds —
  /// e.g. "05/01/25, 2:30:15 PM" or "05/01/25, 14:30:15".
  static DateFormat numericDateAndTimeWithSeconds(BuildContext context) {
    return is24Hour(context)
        ? DateFormat('dd/MM/yy, HH:mm:ss')
        : DateFormat('dd/MM/yy, h:mm:ss a');
  }

  /// Day/month/year + time (no seconds) —
  /// e.g. "05/01/2025, 2:30PM" or "05/01/2025, 14:30".
  static DateFormat numericDateAndTime(BuildContext context) {
    return is24Hour(context)
        ? DateFormat('dd/MM/yyyy, HH:mm')
        : DateFormat('dd/MM/yyyy, h:mma');
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
    return DateFormat('$datePrefix ${timePattern(context)}');
  }
}
