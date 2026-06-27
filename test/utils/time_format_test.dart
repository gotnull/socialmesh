// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:socialmesh/models/accessibility_preferences.dart';
import 'package:socialmesh/services/accessibility_preferences_service.dart';
import 'package:socialmesh/utils/time_format.dart';

void main() {
  group('AppTimeFormat', () {
    // A fixed test timestamp: 2025-03-15 14:30:45 (2:30:45 PM)
    final testDate = DateTime(2025, 3, 15, 14, 30, 45);

    // -------------------------------------------------------------------------
    // Helper: builds a widget tree with MediaQuery controlling the system
    // 24-hour flag, and sets the AccessibilityPreferencesService singleton
    // to the desired TimeFormatMode so AppTimeFormat.is24Hour reads it.
    // -------------------------------------------------------------------------

    /// Update the service singleton's cached preferences to the given mode.
    Future<void> setTimeFormatMode(TimeFormatMode mode) async {
      final service = AccessibilityPreferencesService();
      await service.updatePreferences(
        AccessibilityPreferences(timeFormatMode: mode),
      );
    }

    /// Update the date-ordering preference, preserving the time mode.
    Future<void> setDateFormatMode(DateFormatMode mode) async {
      final service = AccessibilityPreferencesService();
      await service.updatePreferences(
        service.current.copyWith(dateFormatMode: mode),
      );
    }

    Widget buildTestHarness({
      required bool alwaysUse24HourFormat,
      required void Function(BuildContext context) onBuild,
    }) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(alwaysUse24HourFormat: alwaysUse24HourFormat),
          child: Builder(
            builder: (context) {
              onBuild(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    setUp(() async {
      // Ensure the service is initialized for each test.
      final service = AccessibilityPreferencesService();
      // Reset to defaults before each test.
      await service.updatePreferences(AccessibilityPreferences.defaults);
    });

    // =========================================================================
    // is24Hour — preference resolution
    // =========================================================================

    group('is24Hour', () {
      testWidgets('returns device setting when mode is system (device=24h)', (
        tester,
      ) async {
        await setTimeFormatMode(TimeFormatMode.system);
        late bool result;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: true,
            onBuild: (ctx) => result = AppTimeFormat.is24Hour(ctx),
          ),
        );
        expect(result, isTrue);
      });

      testWidgets('returns device setting when mode is system (device=12h)', (
        tester,
      ) async {
        await setTimeFormatMode(TimeFormatMode.system);
        late bool result;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) => result = AppTimeFormat.is24Hour(ctx),
          ),
        );
        expect(result, isFalse);
      });

      testWidgets(
        'returns false when mode is twelveHour regardless of device',
        (tester) async {
          await setTimeFormatMode(TimeFormatMode.twelveHour);
          late bool result;
          await tester.pumpWidget(
            buildTestHarness(
              alwaysUse24HourFormat: true,
              onBuild: (ctx) => result = AppTimeFormat.is24Hour(ctx),
            ),
          );
          expect(result, isFalse);
        },
      );

      testWidgets(
        'returns true when mode is twentyFourHour regardless of device',
        (tester) async {
          await setTimeFormatMode(TimeFormatMode.twentyFourHour);
          late bool result;
          await tester.pumpWidget(
            buildTestHarness(
              alwaysUse24HourFormat: false,
              onBuild: (ctx) => result = AppTimeFormat.is24Hour(ctx),
            ),
          );
          expect(result, isTrue);
        },
      );
    });

    // =========================================================================
    // timeOnly
    // =========================================================================

    group('timeOnly', () {
      testWidgets('formats as 12-hour with AM/PM', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.timeOnly(ctx).format(testDate);
            },
          ),
        );
        expect(formatted, DateFormat('h:mm a').format(testDate));
      });

      testWidgets('formats as 24-hour', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.timeOnly(ctx).format(testDate);
            },
          ),
        );
        expect(formatted, '14:30');
      });
    });

    // =========================================================================
    // timeWithSeconds
    // =========================================================================

    group('timeWithSeconds', () {
      testWidgets('formats 12-hour with seconds', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.timeWithSeconds(ctx).format(testDate);
            },
          ),
        );
        expect(formatted, DateFormat('h:mm:ss a').format(testDate));
      });

      testWidgets('formats 24-hour with seconds', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.timeWithSeconds(ctx).format(testDate);
            },
          ),
        );
        expect(formatted, '14:30:45');
      });
    });

    // =========================================================================
    // dateAndTime
    // =========================================================================

    group('dateAndTime', () {
      testWidgets('formats with 12-hour time', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.dateAndTime(ctx).format(testDate);
            },
          ),
        );
        expect(formatted, DateFormat('MMM d, h:mm a').format(testDate));
      });

      testWidgets('formats with 24-hour time', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.dateAndTime(ctx).format(testDate);
            },
          ),
        );
        expect(formatted, DateFormat('MMM d, HH:mm').format(testDate));
      });
    });

    // =========================================================================
    // dateAndTimeCompact
    // =========================================================================

    group('dateAndTimeCompact', () {
      testWidgets('formats compact 12-hour (no space before am/pm)', (
        tester,
      ) async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.dateAndTimeCompact(
                ctx,
              ).format(testDate);
            },
          ),
        );
        expect(formatted, DateFormat('MMM d, h:mma').format(testDate));
      });

      testWidgets('formats compact 24-hour', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.dateAndTimeCompact(
                ctx,
              ).format(testDate);
            },
          ),
        );
        expect(formatted, DateFormat('MMM d, HH:mm').format(testDate));
      });
    });

    // =========================================================================
    // fullDateAndTime
    // =========================================================================

    group('fullDateAndTime', () {
      testWidgets('formats full date with 12-hour time', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.fullDateAndTime(ctx).format(testDate);
            },
          ),
        );
        expect(formatted, DateFormat('MMM d, yyyy h:mm a').format(testDate));
      });

      testWidgets('formats full date with 24-hour time', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.fullDateAndTime(ctx).format(testDate);
            },
          ),
        );
        expect(formatted, DateFormat('MMM d, yyyy HH:mm').format(testDate));
      });
    });

    // =========================================================================
    // fullDateBulletTime
    // =========================================================================

    group('fullDateBulletTime', () {
      testWidgets('formats with bullet separator and 12-hour', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.fullDateBulletTime(
                ctx,
              ).format(testDate);
            },
          ),
        );
        expect(
          formatted,
          DateFormat("MMM d, yyyy '\u2022' h:mm a").format(testDate),
        );
      });

      testWidgets('formats with bullet separator and 24-hour', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.fullDateBulletTime(
                ctx,
              ).format(testDate);
            },
          ),
        );
        expect(
          formatted,
          DateFormat("MMM d, yyyy '\u2022' HH:mm").format(testDate),
        );
      });
    });

    // =========================================================================
    // numericDateAndTimeWithSeconds
    // =========================================================================

    group('numericDateAndTimeWithSeconds', () {
      testWidgets('formats numeric date with 12-hour seconds', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        await setDateFormatMode(DateFormatMode.dayMonthYear);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.numericDateAndTimeWithSeconds(
                ctx,
              ).format(testDate);
            },
          ),
        );
        expect(formatted, DateFormat('dd/MM/yyyy, h:mm:ss a').format(testDate));
      });

      testWidgets('formats numeric date with 24-hour seconds', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        await setDateFormatMode(DateFormatMode.dayMonthYear);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.numericDateAndTimeWithSeconds(
                ctx,
              ).format(testDate);
            },
          ),
        );
        expect(formatted, DateFormat('dd/MM/yyyy, HH:mm:ss').format(testDate));
      });
    });

    // =========================================================================
    // numericDateAndTime
    // =========================================================================

    group('numericDateAndTime', () {
      testWidgets('formats numeric date with 12-hour (compact)', (
        tester,
      ) async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        await setDateFormatMode(DateFormatMode.dayMonthYear);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.numericDateAndTime(
                ctx,
              ).format(testDate);
            },
          ),
        );
        expect(formatted, DateFormat('dd/MM/yyyy, h:mma').format(testDate));
      });

      testWidgets('formats numeric date with 24-hour', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        await setDateFormatMode(DateFormatMode.dayMonthYear);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.numericDateAndTime(
                ctx,
              ).format(testDate);
            },
          ),
        );
        expect(formatted, DateFormat('dd/MM/yyyy, HH:mm').format(testDate));
      });
    });

    // =========================================================================
    // pattern helpers
    // =========================================================================

    group('pattern helpers', () {
      testWidgets('timePattern returns 12h pattern', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        late String pattern;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) => pattern = AppTimeFormat.timePattern(ctx),
          ),
        );
        expect(pattern, 'h:mm a');
      });

      testWidgets('timePattern returns 24h pattern', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        late String pattern;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) => pattern = AppTimeFormat.timePattern(ctx),
          ),
        );
        expect(pattern, 'HH:mm');
      });

      testWidgets('timeWithSecondsPattern returns 12h pattern', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        late String pattern;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) =>
                pattern = AppTimeFormat.timeWithSecondsPattern(ctx),
          ),
        );
        expect(pattern, 'h:mm:ss a');
      });

      testWidgets('timeWithSecondsPattern returns 24h pattern', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        late String pattern;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) =>
                pattern = AppTimeFormat.timeWithSecondsPattern(ctx),
          ),
        );
        expect(pattern, 'HH:mm:ss');
      });
    });

    // =========================================================================
    // withDatePrefix
    // =========================================================================

    group('withDatePrefix', () {
      testWidgets('combines custom prefix with 12h time', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.withDatePrefix(
                ctx,
                'MMM d, yyyy',
              ).format(testDate);
            },
          ),
        );
        expect(formatted, DateFormat('MMM d, yyyy h:mm a').format(testDate));
      });

      testWidgets('combines custom prefix with 24h time', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.withDatePrefix(
                ctx,
                'MMM d, yyyy',
              ).format(testDate);
            },
          ),
        );
        expect(formatted, DateFormat('MMM d, yyyy HH:mm').format(testDate));
      });
    });

    // =========================================================================
    // is24HourFromPreferences (no-context variant)
    // =========================================================================

    group('is24HourFromPreferences', () {
      test(
        'returns false for system mode (safe fallback, no context)',
        () async {
          await setTimeFormatMode(TimeFormatMode.system);
          expect(AppTimeFormat.is24HourFromPreferences(), isFalse);
        },
      );

      test('returns false for twelveHour mode', () async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        expect(AppTimeFormat.is24HourFromPreferences(), isFalse);
      });

      test('returns true for twentyFourHour mode', () async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        expect(AppTimeFormat.is24HourFromPreferences(), isTrue);
      });

      test('timeOnlyFromPreferences returns valid 12h format', () async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        final fmt = AppTimeFormat.timeOnlyFromPreferences();
        final result = fmt.format(testDate);
        expect(result, DateFormat('h:mm a').format(testDate));
      });

      test('timeOnlyFromPreferences returns valid 24h format', () async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        final fmt = AppTimeFormat.timeOnlyFromPreferences();
        final result = fmt.format(testDate);
        expect(result, '14:30');
      });
    });

    // =========================================================================
    // Edge cases — midnight and noon
    // =========================================================================

    group('edge cases', () {
      testWidgets('midnight formats correctly in 12h', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        final midnight = DateTime(2025, 1, 1, 0, 0, 0);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.timeOnly(ctx).format(midnight);
            },
          ),
        );
        expect(formatted, DateFormat('h:mm a').format(midnight));
      });

      testWidgets('midnight formats correctly in 24h', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        final midnight = DateTime(2025, 1, 1, 0, 0, 0);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.timeOnly(ctx).format(midnight);
            },
          ),
        );
        expect(formatted, '00:00');
      });

      testWidgets('noon formats correctly in 12h', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        final noon = DateTime(2025, 1, 1, 12, 0, 0);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.timeOnly(ctx).format(noon);
            },
          ),
        );
        expect(formatted, DateFormat('h:mm a').format(noon));
      });

      testWidgets('noon formats correctly in 24h', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        final noon = DateTime(2025, 1, 1, 12, 0, 0);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.timeOnly(ctx).format(noon);
            },
          ),
        );
        expect(formatted, '12:00');
      });
    });

    // =========================================================================
    // System mode delegates to MediaQuery
    // =========================================================================

    group('system mode delegates to MediaQuery', () {
      testWidgets('system mode uses 24h when device says so', (tester) async {
        await setTimeFormatMode(TimeFormatMode.system);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: true,
            onBuild: (ctx) {
              formatted = AppTimeFormat.timeOnly(ctx).format(testDate);
            },
          ),
        );
        expect(formatted, '14:30');
      });

      testWidgets('system mode uses 12h when device says so', (tester) async {
        await setTimeFormatMode(TimeFormatMode.system);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.timeOnly(ctx).format(testDate);
            },
          ),
        );
        expect(formatted, DateFormat('h:mm a').format(testDate));
      });
    });

    // =========================================================================
    // Explicit mode overrides device setting
    // =========================================================================

    group('explicit mode overrides device setting', () {
      testWidgets('twelveHour forces 12h even when device is 24h', (
        tester,
      ) async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: true,
            onBuild: (ctx) {
              formatted = AppTimeFormat.timeOnly(ctx).format(testDate);
            },
          ),
        );
        expect(formatted, DateFormat('h:mm a').format(testDate));
      });

      testWidgets('twentyFourHour forces 24h even when device is 12h', (
        tester,
      ) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.timeOnly(ctx).format(testDate);
            },
          ),
        );
        expect(formatted, '14:30');
      });
    });

    // =========================================================================
    // relativeDateTime — calendar-relative date + time for detail surfaces
    // =========================================================================

    // =========================================================================
    // Date helpers honour the date format preference
    // =========================================================================

    group('date format preference', () {
      final d = DateTime(2026, 1, 3, 9, 5); // 3 January 2026

      testWidgets('fullDate uses month-first order for monthDayYear', (
        tester,
      ) async {
        await setDateFormatMode(DateFormatMode.monthDayYear);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: true,
            onBuild: (ctx) => formatted = AppTimeFormat.fullDate(ctx).format(d),
          ),
        );
        expect(formatted, 'Jan 3, 2026');
      });

      testWidgets('fullDate uses day-first order for dayMonthYear', (
        tester,
      ) async {
        await setDateFormatMode(DateFormatMode.dayMonthYear);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: true,
            onBuild: (ctx) => formatted = AppTimeFormat.fullDate(ctx).format(d),
          ),
        );
        expect(formatted, '3 Jan 2026');
      });

      testWidgets('numericDate uses ISO order for yearMonthDay', (
        tester,
      ) async {
        await setDateFormatMode(DateFormatMode.yearMonthDay);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: true,
            onBuild: (ctx) =>
                formatted = AppTimeFormat.numericDate(ctx).format(d),
          ),
        );
        expect(formatted, '2026-01-03');
      });

      testWidgets('monthDay drops the year and honours day-first order', (
        tester,
      ) async {
        await setDateFormatMode(DateFormatMode.dayMonthYear);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: true,
            onBuild: (ctx) => formatted = AppTimeFormat.monthDay(ctx).format(d),
          ),
        );
        expect(formatted, '3 Jan');
      });
    });

    group('relativeDateTime', () {
      // Fixed "now" so day-delta arithmetic is deterministic.
      final now = DateTime(2026, 6, 3, 9, 0);

      testWidgets('today renders "Today, HH:mm" (24h)', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: true,
            onBuild: (ctx) {
              formatted = AppTimeFormat.relativeDateTime(
                ctx,
                DateTime(2026, 6, 3, 22, 27),
                todayLabel: 'Today',
                yesterdayLabel: 'Yesterday',
                now: now,
              );
            },
          ),
        );
        expect(formatted, 'Today, 22:27');
      });

      testWidgets('today renders "Today, h:mm a" (12h)', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twelveHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: false,
            onBuild: (ctx) {
              formatted = AppTimeFormat.relativeDateTime(
                ctx,
                DateTime(2026, 6, 3, 22, 27),
                todayLabel: 'Today',
                yesterdayLabel: 'Yesterday',
                now: now,
              );
            },
          ),
        );
        expect(formatted, 'Today, 10:27 PM');
      });

      testWidgets('yesterday renders "Yesterday, HH:mm"', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: true,
            onBuild: (ctx) {
              formatted = AppTimeFormat.relativeDateTime(
                ctx,
                DateTime(2026, 6, 2, 22, 27),
                todayLabel: 'Today',
                yesterdayLabel: 'Yesterday',
                now: now,
              );
            },
          ),
        );
        expect(formatted, 'Yesterday, 22:27');
      });

      testWidgets('older date renders "d MMM yyyy, HH:mm"', (tester) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        await setDateFormatMode(DateFormatMode.dayMonthYear);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: true,
            onBuild: (ctx) {
              formatted = AppTimeFormat.relativeDateTime(
                ctx,
                DateTime(2026, 5, 30, 22, 27),
                todayLabel: 'Today',
                yesterdayLabel: 'Yesterday',
                now: now,
              );
            },
          ),
        );
        expect(formatted, '30 May 2026, 22:27');
      });

      testWidgets('older date crossing a year boundary uses full date', (
        tester,
      ) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        await setDateFormatMode(DateFormatMode.dayMonthYear);
        late String formatted;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: true,
            onBuild: (ctx) {
              formatted = AppTimeFormat.relativeDateTime(
                ctx,
                DateTime(2025, 12, 31, 23, 59),
                todayLabel: 'Today',
                yesterdayLabel: 'Yesterday',
                now: DateTime(2026, 1, 2, 0, 30),
              );
            },
          ),
        );
        expect(formatted, '31 Dec 2025, 23:59');
      });

      testWidgets('uses localized labels supplied by the caller', (
        tester,
      ) async {
        await setTimeFormatMode(TimeFormatMode.twentyFourHour);
        late String today;
        late String yesterday;
        await tester.pumpWidget(
          buildTestHarness(
            alwaysUse24HourFormat: true,
            onBuild: (ctx) {
              today = AppTimeFormat.relativeDateTime(
                ctx,
                DateTime(2026, 6, 3, 8, 5),
                todayLabel: 'Oggi',
                yesterdayLabel: 'Ieri',
                now: now,
              );
              yesterday = AppTimeFormat.relativeDateTime(
                ctx,
                DateTime(2026, 6, 2, 8, 5),
                todayLabel: 'Oggi',
                yesterdayLabel: 'Ieri',
                now: now,
              );
            },
          ),
        );
        expect(today, 'Oggi, 08:05');
        expect(yesterday, 'Ieri, 08:05');
      });
    });
  });
}
