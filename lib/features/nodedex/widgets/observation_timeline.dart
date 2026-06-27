// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Observation Timeline — compact field journal timeline strip.
//
// Renders a horizontal timeline showing key observation milestones
// for a node: first sighting, last sighting, encounter count, and
// optional activity bursts. Uses field journal vocabulary:
// "Observed", "Logged", "Sighting" instead of technical labels.
//
// The timeline reads left-to-right chronologically and adapts
// its density based on the data available. Minimal nodes show
// just first/last seen. Rich nodes show encounter density markers.
//
// Design constraints:
//   - Single-line height, suitable for embedding in detail headers
//   - No scrolling — content fits within available width
//   - Field journal aesthetic: muted colors, small type, monospace dates
//   - Fully deterministic rendering from NodeDexEntry data

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../utils/time_format.dart';
import '../../../core/theme.dart';
import '../models/nodedex_entry.dart';

/// A compact timeline strip showing observation history.
///
/// Displays firstSeen, lastSeen, encounterCount, and optional
/// activity burst markers in a horizontal layout that reads
/// like a field journal timeline.
class ObservationTimeline extends StatelessWidget {
  /// The NodeDex entry to display timeline for.
  final NodeDexEntry entry;

  /// Primary accent color (typically from the node's sigil).
  final Color accentColor;

  /// Whether to show the activity density markers on the timeline bar.
  /// Disabled by default for list tiles, enabled for detail headers.
  final bool showDensityMarkers;

  /// Whether to show the encounter count label.
  final bool showEncounterCount;

  const ObservationTimeline({
    super.key,
    required this.entry,
    required this.accentColor,
    this.showDensityMarkers = false,
    this.showEncounterCount = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label row: "Observed" ... "Last Logged"
        _buildLabelRow(context),
        const SizedBox(height: AppTheme.spacing6),

        // Timeline bar with markers
        _buildTimelineBar(context),
        const SizedBox(height: AppTheme.spacing6),

        // Date row
        _buildDateRow(context),
        const SizedBox(height: AppTheme.spacing2),

        // Relative time row
        _buildRelativeRow(context),
      ],
    );
  }

  Widget _buildLabelRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          context.l10n.nodedexFirstSighting,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: context.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
        if (showEncounterCount)
          _EncounterCountBadge(count: entry.encounterCount, color: accentColor),
        Text(
          context.l10n.nodedexLastLogged,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: context.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineBar(BuildContext context) {
    return SizedBox(
      height: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, 12),
            painter: _TimelinePainter(
              entry: entry,
              accentColor: accentColor,
              showDensityMarkers: showDensityMarkers,
              isDark: context.isDarkMode,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateRow(BuildContext context) {
    final dateFormat = AppTimeFormat.fullDate(context);
    final timeFormat = AppTimeFormat.timeOnly(context);

    final firstDate = dateFormat.format(entry.firstSeen);
    final lastDate = dateFormat.format(entry.lastSeen);
    final lastTime = timeFormat.format(entry.lastSeen);

    final isSameDay =
        entry.firstSeen.year == entry.lastSeen.year &&
        entry.firstSeen.month == entry.lastSeen.month &&
        entry.firstSeen.day == entry.lastSeen.day;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          firstDate,
          style: TextStyle(
            fontSize: 10,
            fontFamily: AppTheme.fontFamily,
            color: context.textTertiary,
          ),
        ),
        if (!isSameDay)
          Text(
            _formatDuration(context, entry.age),
            style: TextStyle(
              fontSize: 9,
              color: context.textTertiary.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        Text(
          isSameDay ? lastTime : lastDate,
          style: TextStyle(
            fontSize: 10,
            fontFamily: AppTheme.fontFamily,
            color: context.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildRelativeRow(BuildContext context) {
    final firstAgo = _formatRelative(
      context,
      DateTime.now().difference(entry.firstSeen),
    );
    final lastAgo = _formatRelative(
      context,
      DateTime.now().difference(entry.lastSeen),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          firstAgo,
          style: TextStyle(
            fontSize: 9,
            color: context.textTertiary.withValues(alpha: 0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
        Text(
          lastAgo,
          style: TextStyle(
            fontSize: 9,
            color: context.textTertiary.withValues(alpha: 0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// Formats a duration as a compact relative label.
  static String _formatRelative(BuildContext context, Duration duration) {
    final l10n = context.l10n;
    if (duration.inMinutes < 1) return l10n.nodedexRelativeJustNow;
    if (duration.inMinutes < 60) {
      return l10n.nodedexRelativeMinutesAgo(duration.inMinutes);
    }
    if (duration.inHours < 24) {
      return l10n.nodedexRelativeHoursAgo(duration.inHours);
    }
    if (duration.inDays < 30) {
      return l10n.nodedexRelativeDaysAgo(duration.inDays);
    }
    return l10n.nodedexRelativeMonthsAgo(duration.inDays ~/ 30);
  }

  static String _formatDuration(BuildContext context, Duration duration) {
    final l10n = context.l10n;
    if (duration.inDays > 365) {
      final years = duration.inDays ~/ 365;
      final months = (duration.inDays % 365) ~/ 30;
      if (months > 0) return l10n.nodedexDurationYearsMonths(years, months);
      return l10n.nodedexDurationYears(years);
    }
    if (duration.inDays > 30) {
      final months = duration.inDays ~/ 30;
      return l10n.nodedexDurationMonths(months);
    }
    if (duration.inDays > 0) return l10n.nodedexDurationDays(duration.inDays);
    if (duration.inHours > 0) {
      return l10n.nodedexDurationHours(duration.inHours);
    }
    return l10n.nodedexDurationMinutes(duration.inMinutes);
  }
}

/// Encounter count badge displayed on the timeline.
class _EncounterCountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _EncounterCountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Text(
        count == 1
            ? context.l10n.nodedexSightingsSingular(count)
            : context.l10n.nodedexSightingsPlural(count),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color.withValues(alpha: 0.8),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Custom painter for the timeline bar.
///
/// Draws a horizontal line with endpoint markers and optional
/// density dots representing encounter activity distribution.
class _TimelinePainter extends CustomPainter {
  final NodeDexEntry entry;
  final Color accentColor;
  final bool showDensityMarkers;
  final bool isDark;

  /// Endpoint dot radius.
  static const double _endpointRadius = 3.5;

  /// Density marker dot radius.
  static const double _markerRadius = 1.5;

  /// Vertical center of the timeline.
  static const double _centerY = 6.0;

  _TimelinePainter({
    required this.entry,
    required this.accentColor,
    required this.showDensityMarkers,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final leftX = _endpointRadius + 1;
    final rightX = width - _endpointRadius - 1;
    final lineWidth = rightX - leftX;

    if (lineWidth <= 0) return;

    // Draw the baseline.
    final linePaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.15 : 0.12)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(leftX, _centerY),
      Offset(rightX, _centerY),
      linePaint,
    );

    // Draw density markers if enabled and we have encounter records.
    if (showDensityMarkers && entry.encounters.length >= 2) {
      _paintDensityMarkers(canvas, leftX, rightX, lineWidth);
    }

    // Draw active segment (colored portion of the line).
    // If node was recently seen (<1h), the line extends to the right end.
    // Otherwise, it stops proportionally based on recency.
    final activeLinePaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.35 : 0.25)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(leftX, _centerY),
      Offset(rightX, _centerY),
      activeLinePaint,
    );

    // Draw endpoint dots.
    final endpointPaint = Paint()..color = accentColor.withValues(alpha: 0.7);

    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    // First seen endpoint (left).
    canvas.drawCircle(
      Offset(leftX, _centerY),
      _endpointRadius * 1.8,
      glowPaint,
    );
    canvas.drawCircle(Offset(leftX, _centerY), _endpointRadius, endpointPaint);

    // Last seen endpoint (right).
    canvas.drawCircle(
      Offset(rightX, _centerY),
      _endpointRadius * 1.8,
      glowPaint,
    );
    canvas.drawCircle(Offset(rightX, _centerY), _endpointRadius, endpointPaint);

    // Inner dot for endpoints (brighter center).
    final innerDotPaint = Paint()..color = accentColor;
    canvas.drawCircle(
      Offset(leftX, _centerY),
      _endpointRadius * 0.4,
      innerDotPaint,
    );
    canvas.drawCircle(
      Offset(rightX, _centerY),
      _endpointRadius * 0.4,
      innerDotPaint,
    );
  }

  void _paintDensityMarkers(
    Canvas canvas,
    double leftX,
    double rightX,
    double lineWidth,
  ) {
    final totalAge = entry.age;
    if (totalAge.inMinutes <= 0) return;

    final markerPaint = Paint()..color = accentColor.withValues(alpha: 0.3);

    for (final encounter in entry.encounters) {
      final elapsed = encounter.timestamp.difference(entry.firstSeen);
      final fraction = elapsed.inMinutes / totalAge.inMinutes;
      final clampedFraction = fraction.clamp(0.05, 0.95);

      final x = leftX + clampedFraction * lineWidth;

      canvas.drawCircle(Offset(x, _centerY), _markerRadius, markerPaint);
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) {
    return oldDelegate.entry.nodeNum != entry.nodeNum ||
        oldDelegate.entry.encounterCount != entry.encounterCount ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.showDensityMarkers != showDensityMarkers ||
        oldDelegate.isDark != isDark;
  }
}

/// Inline observation summary — a single-line text version of the timeline.
///
/// Used in list tiles where the full timeline strip would be too large.
/// Renders something like: "Observed 12 Mar — 47 sightings — last 2h ago"
class ObservationSummary extends StatelessWidget {
  /// The NodeDex entry to summarize.
  final NodeDexEntry entry;

  const ObservationSummary({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];

    // First seen
    final dateFormat = AppTimeFormat.monthDay(context);
    parts.add(
      context.l10n.nodedexObservedDate(dateFormat.format(entry.firstSeen)),
    );

    // Encounter count
    if (entry.encounterCount > 1) {
      parts.add(context.l10n.nodedexSightingsPlural(entry.encounterCount));
    }

    // Last seen relative
    final lastSeenDuration = entry.timeSinceLastSeen;
    if (lastSeenDuration.inMinutes < 1) {
      parts.add(context.l10n.nodedexActiveNow);
    } else {
      parts.add(
        context.l10n.nodedexLastRelative(
          _formatRelative(context, lastSeenDuration),
        ),
      );
    }

    return Text(
      parts.join(' \u2014 '),
      style: TextStyle(
        fontSize: 10,
        color: context.textTertiary,
        fontStyle: FontStyle.italic,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  static String _formatRelative(BuildContext context, Duration duration) {
    final l10n = context.l10n;
    if (duration.inDays > 0) {
      return l10n.nodedexRelativeDaysAgo(duration.inDays);
    }
    if (duration.inHours > 0) {
      return l10n.nodedexRelativeHoursAgo(duration.inHours);
    }
    return l10n.nodedexRelativeMinutesAgo(duration.inMinutes);
  }
}
