// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Issue #197 - telemetry charts must plot readings at their actual
// timestamps, not equally spaced list indices. TimeSeriesAxis owns the
// shared x-axis maths for the device metrics, environment metrics, and
// node history charts; these tests pin the gap-proportionality contract
// and the label interval/style ladder.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/time_series_axis.dart';
import 'package:socialmesh/models/accessibility_preferences.dart';
import 'package:socialmesh/services/accessibility_preferences_service.dart';

void main() {
  final base = DateTime(2026, 6, 10, 12, 0);
  double ms(Duration d) => d.inMilliseconds.toDouble();

  group('xOf / timestampOfSpot', () {
    test('x is the epoch-millisecond timestamp', () {
      expect(TimeSeriesAxis.xOf(base), base.millisecondsSinceEpoch.toDouble());
    });

    test('gaps between readings are proportional to elapsed time', () {
      // Three readings: 5 minutes apart, then 1 hour apart. The second
      // gap must render 12x wider than the first - the core of #197.
      final x0 = TimeSeriesAxis.xOf(base);
      final x1 = TimeSeriesAxis.xOf(base.add(const Duration(minutes: 5)));
      final x2 = TimeSeriesAxis.xOf(
        base.add(const Duration(minutes: 5, hours: 1)),
      );
      expect(x1 - x0, ms(const Duration(minutes: 5)));
      expect((x2 - x1) / (x1 - x0), 12.0);
    });

    test('timestampOfSpot inverts xOf', () {
      final spot = FlSpot(TimeSeriesAxis.xOf(base), 42);
      expect(TimeSeriesAxis.timestampOfSpot(spot), base);
    });
  });

  group('domain', () {
    test('normal span passes through first/last', () {
      final last = base.add(const Duration(hours: 2));
      final d = TimeSeriesAxis.domainOf(base, last);
      expect(d.minX, TimeSeriesAxis.xOf(base));
      expect(d.maxX, TimeSeriesAxis.xOf(last));
    });

    test('zero span is padded on both sides', () {
      final d = TimeSeriesAxis.domainOf(base, base);
      final pad = ms(TimeSeriesAxis.zeroSpanPadding);
      expect(d.minX, TimeSeriesAxis.xOf(base) - pad);
      expect(d.maxX, TimeSeriesAxis.xOf(base) + pad);
      expect(d.minX, lessThan(d.maxX));
    });
  });

  group('labelIntervalMs', () {
    double intervalFor(Duration span) =>
        TimeSeriesAxis.labelIntervalMs(0, ms(span));

    test('picks the smallest nice step yielding <= 5 labels', () {
      expect(
        intervalFor(const Duration(minutes: 10)),
        ms(const Duration(minutes: 2)),
      );
      expect(
        intervalFor(const Duration(hours: 1)),
        ms(const Duration(minutes: 15)),
      );
      expect(
        intervalFor(const Duration(hours: 24)),
        ms(const Duration(hours: 6)),
      );
      expect(intervalFor(const Duration(days: 7)), ms(const Duration(days: 2)));
    });

    test('sub-minute span falls back to an even split', () {
      expect(intervalFor(const Duration(seconds: 30)), 6000);
    });

    test('beyond-ladder span falls back to an even split', () {
      final span = const Duration(days: 365);
      expect(intervalFor(span), ms(span) / TimeSeriesAxis.targetLabelCount);
    });

    test('never returns zero', () {
      expect(TimeSeriesAxis.labelIntervalMs(0, 0), greaterThan(0));
      expect(TimeSeriesAxis.labelIntervalMs(0, 2), greaterThan(0));
    });
  });

  group('labelStyleFor', () {
    TimeSeriesLabelStyle styleFor(Duration span) =>
        TimeSeriesAxis.labelStyleFor(0, ms(span));

    test('sub-day span uses time-only labels', () {
      expect(styleFor(const Duration(hours: 6)), TimeSeriesLabelStyle.time);
    });

    test('multi-day span with sub-day steps uses date+time labels', () {
      expect(
        styleFor(const Duration(hours: 30)),
        TimeSeriesLabelStyle.dateTime,
      );
    });

    test('day-step spans use date-only labels', () {
      expect(styleFor(const Duration(days: 5)), TimeSeriesLabelStyle.date);
    });
  });

  group('bottomTitles', () {
    setUp(() async {
      await AccessibilityPreferencesService().updatePreferences(
        AccessibilityPreferences.defaults,
      );
    });

    testWidgets('configures interval and excludes edge labels', (tester) async {
      late SideTitles titles;
      final minX = TimeSeriesAxis.xOf(base);
      final maxX = TimeSeriesAxis.xOf(base.add(const Duration(hours: 1)));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              titles = TimeSeriesAxis.bottomTitles(
                context,
                minX: minX,
                maxX: maxX,
                style: const TextStyle(),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(titles.showTitles, isTrue);
      expect(titles.interval, ms(const Duration(minutes: 15)));
      expect(titles.minIncluded, isFalse);
      expect(titles.maxIncluded, isFalse);
      expect(titles.reservedSize, TimeSeriesAxis.bottomReservedSize);
    });

    testWidgets('formatLabel renders a clock time for sub-day spans', (
      tester,
    ) async {
      late String label;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(alwaysUse24HourFormat: true),
            child: Builder(
              builder: (context) {
                label = TimeSeriesAxis.formatLabel(
                  context,
                  TimeSeriesAxis.xOf(DateTime(2026, 6, 10, 14, 30)),
                  TimeSeriesLabelStyle.time,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(label, '14:30');
    });
  });
}
