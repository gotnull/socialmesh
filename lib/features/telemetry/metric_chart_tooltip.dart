// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../utils/time_format.dart';

/// Shared touch-tooltip config for telemetry metric charts.
///
/// Keeps the tooltip inside the chart area (`fitInsideHorizontally` /
/// `fitInsideVertically`) and renders one coloured value line per touched
/// series, with the sample date appended once on the bottom entry only.
/// Repeating the date on every series makes the tooltip taller than the
/// chart at large text scales, at which point fl_chart's vertical fitting
/// can no longer hold it inside the plot and it bleeds over the widgets
/// above the chart.
LineTouchTooltipData metricTouchTooltipData(
  BuildContext context, {
  required String Function(LineBarSpot spot) formatValue,
  required DateTime Function(LineBarSpot spot) timestampOf,
}) {
  return LineTouchTooltipData(
    maxContentWidth: 180,
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    getTooltipColor: (_) => context.card,
    getTooltipItems: (spots) => [
      for (final (i, spot) in spots.indexed)
        LineTooltipItem(
          formatValue(spot),
          TextStyle(
            color: spot.bar.color ?? context.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          children: [
            if (i == spots.length - 1)
              TextSpan(
                text:
                    '\n${AppTimeFormat.withDatePrefix(context, 'MMM d').format(timestampOf(spot))}',
                style: TextStyle(
                  color: context.textSecondary,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                ),
              ),
          ],
        ),
    ],
  );
}
