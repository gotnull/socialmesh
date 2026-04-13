// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../providers/timeline_providers.dart';

/// The left-side time gutter and horizontal grid lines for the timeline.
///
/// Displays 24 hour labels (00:00–23:00) and draws horizontal dividers
/// at each hour boundary. Also renders the current-time indicator line.
class TimelineTimeGrid extends StatelessWidget {
  /// The full grid height (24 hours * pixelsPerMinute * 60).
  final double totalHeight;

  /// Pixels per minute — controls vertical density.
  final double pixelsPerMinute;

  /// Current time for the red indicator line. Null hides it.
  final DateTime? now;

  /// Width of the gutter column.
  final double gutterWidth;

  /// Total width for the grid lines to span (gutter + all columns).
  final double totalWidth;

  const TimelineTimeGrid({
    super.key,
    required this.totalHeight,
    this.pixelsPerMinute = kTimelinePixelsPerMinute,
    this.now,
    this.gutterWidth = kTimelineGutterWidth,
    required this.totalWidth,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: totalHeight,
      width: totalWidth,
      child: Stack(
        children: [
          // Horizontal grid lines
          for (var hour = 0; hour < 24; hour++)
            Positioned(
              top: hour * 60 * pixelsPerMinute,
              left: 0,
              right: 0,
              child: _HourLine(
                hour: hour,
                gutterWidth: gutterWidth,
                lineColor: context.border.withValues(alpha: 0.3),
                textColor: context.textTertiary,
              ),
            ),

          // Current time indicator
          if (now != null)
            Positioned(
              top: (now!.hour * 60 + now!.minute) * pixelsPerMinute,
              left: 0,
              right: 0,
              child: _CurrentTimeIndicator(gutterWidth: gutterWidth),
            ),
        ],
      ),
    );
  }
}

/// A single hour label + horizontal line.
class _HourLine extends StatelessWidget {
  final int hour;
  final double gutterWidth;
  final Color lineColor;
  final Color textColor;

  const _HourLine({
    required this.hour,
    required this.gutterWidth,
    required this.lineColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final label =
        '${hour.toString().padLeft(2, '0')}:00'; // lint-allow: hardcoded-string

    return Row(
      children: [
        SizedBox(
          width: gutterWidth,
          child: Padding(
            padding: const EdgeInsets.only(right: AppTheme.spacing8),
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ),
        Expanded(child: Container(height: 0.5, color: lineColor)),
      ],
    );
  }
}

/// Red line with circle dot at the current time.
class _CurrentTimeIndicator extends StatelessWidget {
  final double gutterWidth;

  const _CurrentTimeIndicator({required this.gutterWidth});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: gutterWidth - 6),
        // Red dot
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppTheme.errorRed,
            shape: BoxShape.circle,
          ),
        ),
        // Red line
        Expanded(child: Container(height: 2, color: AppTheme.errorRed)),
      ],
    );
  }
}
