// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetRecentTimeline — chronological vertical timeline of recent care
// events, with chevron pagination at the bottom.
//
// Visual language mirrors
// [features/nodedex/widgets/node_activity_timeline.dart] so pet and
// NodeDex share one "event feed" idiom:
//   * Left rail: vertical connector line + coloured dot with icon
//   * Right column: event label + relative-and-absolute timestamp
//   * Day-group headers ("TODAY", "YESTERDAY", "23 Apr") visually
//     break the feed when events span calendar days
//   * Landmark events (hatched, stage transitions, branch resolution,
//     dormancy, re-sigil) get a larger dot + glow so milestones pop
//     out of the day-to-day care noise
//   * Footer: chevron prev/next + page indicator — pagination is
//     inline in the sheet (no separate screen)
//
// Events render NEWEST-FIRST (the underlying [PetState.recentEvents]
// list is appended in chronological order; we reverse at the widget
// boundary so the user sees the latest at the top without mutating
// the source).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/time_format.dart';
import '../models/care_event.dart';
import '../models/pet_enums.dart';

class PetRecentTimeline extends StatefulWidget {
  /// Events in chronological order (oldest first). The widget
  /// reverses for rendering so the most-recent event is at the top.
  final List<CareEvent> events;

  /// Accent colour for pagination buttons + generic stage-advanced
  /// dots. Usually the pet's branch palette primary.
  final Color accent;

  /// Max events per page. Small by default so the inspect sheet
  /// stays scannable on phones.
  final int pageSize;

  const PetRecentTimeline({
    super.key,
    required this.events,
    required this.accent,
    this.pageSize = 6,
  });

  @override
  State<PetRecentTimeline> createState() => _PetRecentTimelineState();
}

class _PetRecentTimelineState extends State<PetRecentTimeline> {
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant PetRecentTimeline old) {
    super.didUpdateWidget(old);
    // If the events list shrank (e.g. recentEventsCapacity trim) the
    // current page index may now exceed the total — clamp it.
    if (widget.events.length != old.events.length) {
      final totalPages = _totalPages(widget.events.length);
      if (_currentPage >= totalPages && totalPages > 0) {
        _currentPage = totalPages - 1;
      }
    }
  }

  int _totalPages(int count) =>
      count == 0 ? 0 : (count / widget.pageSize).ceil();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (widget.events.isEmpty) {
      return _EmptyTimeline(accent: widget.accent);
    }

    // Newest-first for display.
    final ordered = widget.events.reversed.toList(growable: false);
    final totalPages = _totalPages(ordered.length);
    final page = _currentPage.clamp(0, totalPages - 1);

    final startIndex = page * widget.pageSize;
    final endIndex = (startIndex + widget.pageSize).clamp(0, ordered.length);
    final pageItems = ordered.sublist(startIndex, endIndex);

    // Interleave day-group headers between events that cross a
    // calendar-day boundary.
    final items = _interleaveWithDayHeaders(pageItems);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++)
          if (items[i] is _HeaderItem)
            _DayHeader(
              label: (items[i] as _HeaderItem).label(l10n),
              isFirst: i == 0,
            )
          else
            _TimelineEventTile(
              event: (items[i] as _EventItem).event,
              accent: widget.accent,
              isFirstOfDay: _isFirstEventAfterHeader(items, i),
              isLastOfDay: _isLastEventBeforeHeaderOrEnd(items, i),
              l10n: l10n,
            ),
        if (totalPages > 1) ...[
          const SizedBox(height: AppTheme.spacing12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PaginationButton(
                icon: Icons.chevron_left,
                enabled: page > 0,
                accent: widget.accent,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _currentPage = page - 1);
                },
              ),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                '${page + 1} / $totalPages',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              _PaginationButton(
                icon: Icons.chevron_right,
                enabled: page < totalPages - 1,
                accent: widget.accent,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _currentPage = page + 1);
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Walk this page's events (newest-first) and insert a [_HeaderItem]
  /// whenever the calendar date changes. The very first event gets a
  /// header above it so the "TODAY" anchor is always visible.
  List<_TimelineItem> _interleaveWithDayHeaders(List<CareEvent> events) {
    if (events.isEmpty) return const [];
    final out = <_TimelineItem>[];
    DateTime? lastDayKey;
    final now = DateTime.now();
    for (final e in events) {
      final key = DateTime(e.at.year, e.at.month, e.at.day);
      if (lastDayKey == null || key != lastDayKey) {
        out.add(_HeaderItem(day: key, now: now));
        lastDayKey = key;
      }
      out.add(_EventItem(e));
    }
    return out;
  }

  bool _isFirstEventAfterHeader(List<_TimelineItem> items, int i) {
    return i == 0 || items[i - 1] is _HeaderItem;
  }

  bool _isLastEventBeforeHeaderOrEnd(List<_TimelineItem> items, int i) {
    if (i == items.length - 1) return true;
    return items[i + 1] is _HeaderItem;
  }
}

// ============================================================================
// Timeline items (sealed — events + day headers)
// ============================================================================

sealed class _TimelineItem {
  const _TimelineItem();
}

final class _EventItem extends _TimelineItem {
  final CareEvent event;
  const _EventItem(this.event);
}

final class _HeaderItem extends _TimelineItem {
  final DateTime day;
  final DateTime now;
  const _HeaderItem({required this.day, required this.now});

  String label(AppLocalizations l10n) {
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return l10n.petRecentTimelineDayToday;
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == yesterday) return l10n.petRecentTimelineDayYesterday;
    if (day.year == today.year) {
      return '${day.day} ${_monthAbbrev(day.month)}';
    }
    return '${day.day} ${_monthAbbrev(day.month)} ${day.year}';
  }

  static String _monthAbbrev(int m) {
    const abbrevs = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return abbrevs[m];
  }
}

// ============================================================================
// Day group header
// ============================================================================

class _DayHeader extends StatelessWidget {
  final String label;
  final bool isFirst;
  const _DayHeader({required this.label, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 0 : AppTheme.spacing8,
        bottom: AppTheme.spacing6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Match the 32-wide left rail of the event tiles so the
          // header's "lane" aligns with the event dots below.
          SizedBox(
            width: 32,
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.textTertiary.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Container(
              height: 1,
              color: context.border.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Empty state
// ============================================================================

class _EmptyTimeline extends StatelessWidget {
  final Color accent;
  const _EmptyTimeline({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppTheme.spacing24,
        horizontal: AppTheme.spacing16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timeline_outlined,
            size: 40,
            color: context.textTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            context.l10n.petRecentTimelineEmptyTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            context.l10n.petRecentTimelineEmptySubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Event tile
// ============================================================================

class _TimelineEventTile extends StatelessWidget {
  final CareEvent event;
  final Color accent;

  /// True when this event is the first in its day-group → hide the
  /// top connector stub so the day reads as its own vertical run.
  final bool isFirstOfDay;

  /// True when this event is the last in its day-group or the very
  /// last item on the page → hide the bottom connector stub.
  final bool isLastOfDay;

  final AppLocalizations l10n;

  const _TimelineEventTile({
    required this.event,
    required this.accent,
    required this.isFirstOfDay,
    required this.isLastOfDay,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(event.kind, accent);
    final isLandmark = _isLandmark(event.kind);

    // Landmark events get a larger dot with a soft glow so they stand
    // out as "milestones" in the feed. Regular care taps stay at the
    // small size so the timeline doesn't feel shouty.
    final dotSize = isLandmark ? 30.0 : 24.0;
    final iconSize = isLandmark ? 15.0 : 12.0;
    final borderWidth = isLandmark ? 2.0 : 1.5;

    final dot = Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: visual.color.withValues(alpha: isLandmark ? 0.22 : 0.15),
        border: Border.all(
          color: visual.color.withValues(alpha: isLandmark ? 0.80 : 0.55),
          width: borderWidth,
        ),
      ),
      child: Icon(visual.icon, size: iconSize, color: visual.color),
    );

    final decoratedDot = isLandmark
        ? DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: visual.color.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: dot,
          )
        : dot;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left rail: connector stub + dot + connector tail
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 1.5,
                  height: 8,
                  color: isFirstOfDay
                      ? Colors.transparent
                      : context.border.withValues(alpha: 0.3),
                ),
                decoratedDot,
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: isLastOfDay
                        ? Colors.transparent
                        : context.border.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _eventLabel(event.kind, l10n),
                    style: TextStyle(
                      fontSize: isLandmark ? 14 : 13,
                      fontWeight: isLandmark
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: context.textPrimary,
                      fontFamily: AppTheme.fontFamily,
                      letterSpacing: isLandmark ? 0.3 : 0.0,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    _formatTimestamp(context, event.at, l10n),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textTertiary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _isLandmark(CareEventKind kind) {
    switch (kind) {
      case CareEventKind.hatched:
      case CareEventKind.stageAdvanced:
      case CareEventKind.branchResolved:
      case CareEventKind.dormantEntered:
      case CareEventKind.reSigilled:
        return true;
      default:
        return false;
    }
  }

  static String _formatTimestamp(
    BuildContext context,
    DateTime ts,
    AppLocalizations l10n,
  ) {
    final diff = DateTime.now().difference(ts);
    final relative = _relative(diff, l10n);
    final absolute = AppTimeFormat.dateAndTime(context).format(ts);
    return '$relative  ·  $absolute';
  }

  static String _relative(Duration diff, AppLocalizations l10n) {
    if (diff.isNegative || diff.inMinutes < 1) return l10n.commonJustNow;
    if (diff.inHours < 1) return l10n.commonMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.commonHoursAgo(diff.inHours);
    return l10n.commonDaysAgo(diff.inDays);
  }
}

/// Icon + colour for a [CareEventKind]. All per-kind visual dispatch
/// lives in one place.
_EventVisual _visualFor(CareEventKind kind, Color accent) {
  switch (kind) {
    case CareEventKind.hatched:
      return _EventVisual(Icons.egg_outlined, AppTheme.primaryPurple);
    case CareEventKind.charged:
      return _EventVisual(Icons.bolt_outlined, AccentColors.yellow);
    case CareEventKind.surged:
      return _EventVisual(Icons.flash_on, AccentColors.orange);
    case CareEventKind.resonated:
      return _EventVisual(Icons.favorite_border, AccentColors.pink);
    case CareEventKind.stabilised:
      return _EventVisual(Icons.cleaning_services_outlined, AccentColors.teal);
    case CareEventKind.synced:
      return _EventVisual(Icons.sync, AccentColors.lavender);
    case CareEventKind.purged:
    case CareEventKind.sicknessRecovered:
      return _EventVisual(Icons.healing_outlined, AccentColors.emerald);
    case CareEventKind.dimmed:
    case CareEventKind.sleepEntered:
      return _EventVisual(Icons.nightlight_round, AccentColors.indigo);
    case CareEventKind.sleepExited:
      return _EventVisual(Icons.wb_sunny_outlined, AccentColors.yellow);
    case CareEventKind.inspected:
      return _EventVisual(Icons.visibility_outlined, AccentColors.sky);
    case CareEventKind.hygieneArtefactAppeared:
      return _EventVisual(
        Icons.cleaning_services_outlined,
        AccentColors.orange,
      );
    case CareEventKind.sicknessOnset:
      return _EventVisual(Icons.medical_services_outlined, AccentColors.red);
    case CareEventKind.callStarted:
      return _EventVisual(
        Icons.notifications_active_outlined,
        AccentColors.pink,
      );
    case CareEventKind.callAnswered:
      return _EventVisual(Icons.check_circle_outline, AccentColors.emerald);
    case CareEventKind.callMissed:
      return _EventVisual(
        Icons.notifications_off_outlined,
        AccentColors.orange,
      );
    case CareEventKind.mistakeRecorded:
      return _EventVisual(Icons.error_outline, AccentColors.red);
    case CareEventKind.stageAdvanced:
      return _EventVisual(Icons.trending_up, accent);
    case CareEventKind.branchResolved:
      return _EventVisual(Icons.account_tree_outlined, AccentColors.yellow);
    case CareEventKind.dormantEntered:
      return _EventVisual(Icons.hourglass_empty, AccentColors.slate);
    case CareEventKind.reSigilled:
      return _EventVisual(Icons.auto_awesome_outlined, AccentColors.yellow);
  }
}

String _eventLabel(CareEventKind kind, AppLocalizations l10n) {
  switch (kind) {
    case CareEventKind.hatched:
      return l10n.petEventHatched;
    case CareEventKind.charged:
      return l10n.petEventCharged;
    case CareEventKind.surged:
      return l10n.petEventSurged;
    case CareEventKind.resonated:
      return l10n.petEventResonated;
    case CareEventKind.stabilised:
      return l10n.petEventStabilised;
    case CareEventKind.synced:
      return l10n.petEventSynced;
    case CareEventKind.purged:
      return l10n.petEventPurged;
    case CareEventKind.dimmed:
      return l10n.petEventDimmed;
    case CareEventKind.inspected:
      return l10n.petEventInspected;
    case CareEventKind.hygieneArtefactAppeared:
      return l10n.petEventHygieneArtefactAppeared;
    case CareEventKind.sicknessOnset:
      return l10n.petEventSicknessOnset;
    case CareEventKind.sicknessRecovered:
      return l10n.petEventSicknessRecovered;
    case CareEventKind.sleepEntered:
      return l10n.petEventSleepEntered;
    case CareEventKind.sleepExited:
      return l10n.petEventSleepExited;
    case CareEventKind.callStarted:
      return l10n.petEventCallStarted;
    case CareEventKind.callAnswered:
      return l10n.petEventCallAnswered;
    case CareEventKind.callMissed:
      return l10n.petEventCallMissed;
    case CareEventKind.mistakeRecorded:
      return l10n.petEventMistakeRecorded;
    case CareEventKind.stageAdvanced:
      return l10n.petEventStageAdvanced;
    case CareEventKind.branchResolved:
      return l10n.petEventBranchResolved;
    case CareEventKind.dormantEntered:
      return l10n.petEventDormantEntered;
    case CareEventKind.reSigilled:
      return l10n.petEventReSigilled;
  }
}

class _EventVisual {
  final IconData icon;
  final Color color;
  const _EventVisual(this.icon, this.color);
}

// ============================================================================
// Pagination button
// ============================================================================

class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color accent;
  final VoidCallback onTap;

  const _PaginationButton({
    required this.icon,
    required this.enabled,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? accent.withValues(alpha: 0.12) : context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          border: Border.all(
            color: enabled
                ? accent.withValues(alpha: 0.35)
                : context.border.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? accent : context.textTertiary,
        ),
      ),
    );
  }
}
