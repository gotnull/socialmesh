// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../utils/time_format.dart';

// Time-proportional x-axis for telemetry line charts.
//
// Every chart that plots readings over time must place each point at its
// actual timestamp (epoch milliseconds as the FlSpot x), not at its list
// index: index spacing renders a 3-minute gap identically to a 1-minute
// one and hides quiet stretches entirely. This helper owns the shared
// pieces of that contract - spot x values, the padded x-domain, "nice"
// label intervals, and label formatting - so the device metrics,
// environment metrics, and node history charts stay in lockstep. It lives
// in core because those surfaces span feature modules that must not
// import each other.

/// How a bottom-axis label renders for a given chart span.
enum TimeSeriesLabelStyle {
  /// Time of day only - spans shorter than a day.
  time,

  /// Compact date + time - sub-day label steps across a multi-day span,
  /// where a bare time would repeat ambiguously.
  dateTime,

  /// Date only - label steps of a day or more.
  date,
}

/// Shared x-axis maths for time-series line charts (fl_chart).
abstract final class TimeSeriesAxis {
  /// Target number of bottom-axis labels across the visible span. Matches
  /// the historical `sorted.length / 5` label density of the metric charts.
  static const int targetLabelCount = 5;

  /// Half-window applied when all samples share one timestamp, so fl_chart
  /// never receives a zero-width `minX == maxX` domain.
  static const Duration zeroSpanPadding = Duration(seconds: 30);

  /// Reserved height for the bottom-axis labels.
  static const double bottomReservedSize = 28;

  /// Gap between the plot area and a bottom-axis label.
  static const double _labelTopPadding = 6;

  /// "Nice" label steps, smallest first. fl_chart aligns interior labels to
  /// multiples of the interval relative to the Unix epoch, so these steps
  /// land labels on round wall-clock times.
  static const List<Duration> _labelSteps = [
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 3),
    Duration(hours: 6),
    Duration(hours: 12),
    Duration(days: 1),
    Duration(days: 2),
    Duration(days: 7),
    Duration(days: 14),
    Duration(days: 30),
  ];

  /// The x coordinate for a sample: epoch milliseconds.
  static double xOf(DateTime timestamp) =>
      timestamp.millisecondsSinceEpoch.toDouble();

  /// Inverse of [xOf]. Accepts any [FlSpot] (including [LineBarSpot]).
  static DateTime timestampOfSpot(FlSpot spot) =>
      DateTime.fromMillisecondsSinceEpoch(spot.x.round());

  /// The chart x-domain for samples spanning [firstXMs]..[lastXMs].
  ///
  /// A zero (or negative) span is padded by [zeroSpanPadding] on both sides
  /// so single readings and duplicate timestamps still get a drawable
  /// domain.
  static ({double minX, double maxX}) domain(double firstXMs, double lastXMs) {
    if (lastXMs - firstXMs <= 0) {
      final pad = zeroSpanPadding.inMilliseconds.toDouble();
      return (minX: firstXMs - pad, maxX: firstXMs + pad);
    }
    return (minX: firstXMs, maxX: lastXMs);
  }

  /// [domain] from the first and last sample timestamps.
  static ({double minX, double maxX}) domainOf(DateTime first, DateTime last) =>
      domain(xOf(first), xOf(last));

  /// Bottom-axis label interval in milliseconds.
  ///
  /// Picks the smallest step from [_labelSteps] that both fits inside the
  /// span (guaranteeing at least one epoch-aligned label lands within it)
  /// and yields at most [targetLabelCount] labels. Sub-minute and
  /// beyond-ladder spans fall back to an even `span / targetLabelCount`
  /// split, floored at 1 ms (fl_chart asserts a nonzero interval).
  static double labelIntervalMs(double minX, double maxX) {
    final span = maxX - minX;
    for (final step in _labelSteps) {
      final stepMs = step.inMilliseconds.toDouble();
      if (stepMs <= span && span / stepMs <= targetLabelCount) return stepMs;
    }
    return math.max(span / targetLabelCount, 1.0);
  }

  /// The label style matching [labelIntervalMs] for the same domain.
  static TimeSeriesLabelStyle labelStyleFor(double minX, double maxX) {
    final stepMs = labelIntervalMs(minX, maxX);
    if (stepMs >= Duration.millisecondsPerDay) return TimeSeriesLabelStyle.date;
    if (maxX - minX >= Duration.millisecondsPerDay) {
      return TimeSeriesLabelStyle.dateTime;
    }
    return TimeSeriesLabelStyle.time;
  }

  /// Formats the epoch-ms axis value [xMs] per [style], honouring the
  /// user's 12/24-hour and date-format preferences via [AppTimeFormat].
  static String formatLabel(
    BuildContext context,
    double xMs,
    TimeSeriesLabelStyle style,
  ) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(xMs.round());
    return switch (style) {
      TimeSeriesLabelStyle.time => AppTimeFormat.timeOnly(
        context,
      ).format(timestamp),
      TimeSeriesLabelStyle.dateTime => AppTimeFormat.dateAndTimeCompact(
        context,
      ).format(timestamp),
      TimeSeriesLabelStyle.date => AppTimeFormat.monthDay(
        context,
      ).format(timestamp),
    };
  }

  /// Ready-made top-axis placeholder that reserves headroom above the plot.
  ///
  /// The topmost left/right axis label is vertically centred on its
  /// gridline, so half of it renders above the plot's top edge; with
  /// topTitles fully disabled the plot starts at the widget edge and that
  /// half is clipped. An empty axis-name slot pushes the plot down just far
  /// enough for the label to render whole, scaling with the user's text
  /// size. [labelFontSize] is the side-axis label font size the headroom
  /// must clear.
  static AxisTitles topHeadroom(
    BuildContext context, {
    double labelFontSize = 11,
  }) {
    final halfLabel = MediaQuery.textScalerOf(context).scale(labelFontSize) / 2;
    return AxisTitles(
      axisNameWidget: const SizedBox.shrink(),
      axisNameSize: halfLabel + _labelTopPadding,
      sideTitles: const SideTitles(showTitles: false),
    );
  }

  /// Ready-made bottom-axis titles for a time-proportional chart.
  ///
  /// Interior labels are epoch-aligned to [labelIntervalMs]; the domain
  /// edges are excluded (`minIncluded`/`maxIncluded` false) because edge
  /// labels render half-clipped against the plot border and usually repeat
  /// an interior label. Callers pass their surface's existing text [style].
  static SideTitles bottomTitles(
    BuildContext context, {
    required double minX,
    required double maxX,
    required TextStyle? style,
  }) {
    final labelStyle = labelStyleFor(minX, maxX);
    return SideTitles(
      showTitles: true,
      reservedSize: bottomReservedSize,
      interval: labelIntervalMs(minX, maxX),
      minIncluded: false,
      maxIncluded: false,
      getTitlesWidget: (value, meta) => Padding(
        padding: const EdgeInsets.only(top: _labelTopPadding),
        child: Text(formatLabel(context, value, labelStyle), style: style),
      ),
    );
  }
}
