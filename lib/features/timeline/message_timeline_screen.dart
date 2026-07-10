// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../nodedex/widgets/sigil_painter.dart';
import 'adapters/message_timeline_adapter.dart';
import 'adapters/message_timeline_delegate.dart';
import 'domain/timeline_item.dart';
import 'providers/timeline_providers.dart';

/// Feature-local provider that projects messages into weekly timeline items.
///
/// Watches the global messages and nodes providers and runs the adapter to
/// produce [TimelineItem] sessions for the given week and filter.
final _messageTimelineItemsProvider = Provider.autoDispose
    .family<List<TimelineItem>, _TimelineQuery>((ref, query) {
      final messages = ref.watch(messagesProvider);
      final nodes = ref.watch(nodesProvider);
      final myNodeNum = ref.watch(myNodeNumProvider);
      final channels = ref.watch(channelsProvider);

      if (myNodeNum == null) {
        AppLogging.messages(
          '[MsgTimeline] myNodeNum is null — returning empty',
        );
        return const [];
      }

      final nodeNames = <int, String>{};
      for (final node in nodes.values) {
        final name = node.shortName ?? node.longName;
        if (name != null) nodeNames[node.nodeNum] = name;
      }

      final channelNames = <int, String>{};
      for (final ch in channels) {
        if (ch.name.isNotEmpty) channelNames[ch.index] = ch.name;
      }

      AppLogging.messages(
        '[MsgTimeline] Provider: ${messages.length} messages, '
        '${nodes.length} nodes, weekStart=${query.weekStart}, '
        'filter=${query.filter}',
      );

      final items = MessageTimelineAdapter.projectMessages(
        messages: messages,
        weekStart: query.weekStart,
        myNodeNum: myNodeNum,
        nodeNames: nodeNames,
        channelNames: channelNames,
        filter: query.filter,
      );

      AppLogging.messages(
        '[MsgTimeline] Projected ${items.length} timeline items',
      );
      for (final item in items) {
        AppLogging.messages(
          '  [Item] ${item.id}: "${item.title}" '
          '${item.start.hour}:${item.start.minute.toString().padLeft(2, '0')}'
          '–${item.end.hour}:${item.end.minute.toString().padLeft(2, '0')} '
          '(${item.durationMinutes}min, ${item.messageCount} msgs, '
          '${item.priority.name})',
        );
      }

      return items;
    });

/// Query key for the family provider.
class _TimelineQuery {
  final DateTime weekStart;
  final MessageTimelineFilter filter;

  const _TimelineQuery({required this.weekStart, required this.filter});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TimelineQuery &&
          weekStart == other.weekStart &&
          filter == other.filter;

  @override
  int get hashCode => Object.hash(weekStart, filter);
}

/// Full-screen weekly timeline view of message activity.
///
/// Reachable from the Messages overflow menu. Shows communication sessions
/// (DM and channel) projected onto a seven-day calendar grid using
/// [EventsPlanner] from the `infinite_calendar_view` package.
class MessageTimelineScreen extends ConsumerStatefulWidget {
  const MessageTimelineScreen({super.key});

  @override
  ConsumerState<MessageTimelineScreen> createState() =>
      _MessageTimelineScreenState();
}

class _MessageTimelineScreenState extends ConsumerState<MessageTimelineScreen> {
  MessageTimelineFilter _filter = MessageTimelineFilter.all;
  late DateTime _weekStart;

  /// Incremented only by explicit user actions (buttons, filters) to force
  /// the [EventsPlanner] to rebuild via [ValueKey]. Scroll-driven week
  /// changes from [onDayChange] do NOT touch this — keeping the planner
  /// alive prevents a crash in `_onPointerUp` when the widget is disposed
  /// mid-gesture (the library calls `setState` without a `mounted` check).
  int _rebuildKey = 0;

  /// Persistent controller shared across planner rebuilds. Updated
  /// imperatively via [updateCalendarData] so scroll-driven week changes
  /// refresh data without disposing the planner.
  late final EventsController _controller;

  @override
  void initState() {
    super.initState();
    _weekStart = weekStartFor(DateTime.now());
    _controller = EventsController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onFilterChanged(MessageTimelineFilter filter) {
    HapticFeedback.selectionClick();
    AppLogging.messages(
      '[MsgTimeline] Filter changed: ${_filter.name} → ${filter.name}',
    );
    setState(() {
      _filter = filter;
      _rebuildKey++;
    });
  }

  void _onWeekForward() {
    HapticFeedback.selectionClick();
    final next = _weekStart.add(const Duration(days: 7));
    AppLogging.messages('[MsgTimeline] Week forward: $_weekStart → $next');
    setState(() {
      _weekStart = next;
      _rebuildKey++;
    });
  }

  void _onWeekBack() {
    HapticFeedback.selectionClick();
    final prev = _weekStart.subtract(const Duration(days: 7));
    AppLogging.messages('[MsgTimeline] Week back: $_weekStart → $prev');
    setState(() {
      _weekStart = prev;
      _rebuildKey++;
    });
  }

  void _onWeekToday() {
    HapticFeedback.selectionClick();
    final today = weekStartFor(DateTime.now());
    AppLogging.messages('[MsgTimeline] Week today: $_weekStart → $today');
    setState(() {
      _weekStart = today;
      _rebuildKey++;
    });
  }

  /// Converts [TimelineItem] objects to [Event] objects for the calendar.
  List<Event> _timelineItemsToEvents(List<TimelineItem> items) {
    return items.map((item) {
      final isDm = item.id.startsWith('dm_');
      return Event(
        startTime: item.start,
        endTime: item.end,
        title: item.title,
        description:
            item.subtitle ??
            (item.messageCount > 0
                ? '${item.messageCount} msgs' // lint-allow: hardcoded-string
                : null),
        color: _colorForItem(isDm, item.priority),
        textColor: Colors.white,
        data: item,
      );
    }).toList();
  }

  /// DMs: cyan/teal tones. Channels: purple/indigo tones.
  /// Intensity (priority) adjusts the specific hue within the family.
  Color _colorForItem(bool isDm, TimelinePriority priority) {
    if (isDm) {
      return switch (priority) {
        TimelinePriority.high => AccentColors.cyan,
        TimelinePriority.medium => AccentColors.teal,
        TimelinePriority.low => AccentColors.sky,
        TimelinePriority.done => context.textTertiary.withValues(alpha: 0.5),
      };
    }
    return switch (priority) {
      TimelinePriority.high => AccentColors.purple,
      TimelinePriority.medium => AccentColors.indigo,
      TimelinePriority.low => AccentColors.lavender,
      TimelinePriority.done => context.textTertiary.withValues(alpha: 0.5),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = _TimelineQuery(weekStart: _weekStart, filter: _filter);
    final items = ref.watch(_messageTimelineItemsProvider(query));
    final nodes = ref.watch(nodesProvider);
    final channels = ref.watch(channelsProvider);

    AppLogging.messages(
      '[MsgTimeline] build: filter=${_filter.name}, '
      'weekStart=$_weekStart, ${items.length} items',
    );

    // Build name maps for the delegate.
    final nodeNames = <int, String>{};
    for (final node in nodes.values) {
      final name = node.shortName ?? node.longName;
      if (name != null) nodeNames[node.nodeNum] = name;
    }
    final channelNames = <int, String>{};
    for (final ch in channels) {
      if (ch.name.isNotEmpty) channelNames[ch.index] = ch.name;
    }

    final delegate = MessageTimelineDelegate(
      nodeNames: nodeNames,
      channelNames: channelNames,
    );

    return GlassScaffold(
      title: l10n.messageTimelineTitle,
      centerTitle: true,
      slivers: [
        // Filter bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing4,
            ),
            child: Row(
              children: [
                _WeekNav(
                  weekStart: _weekStart,
                  onBack: _onWeekBack,
                  onForward: _onWeekForward,
                  onToday: _onWeekToday,
                ),
                const Spacer(),
                _FilterChipRow(current: _filter, onChanged: _onFilterChanged),
              ],
            ),
          ),
        ),

        // Calendar planner
        SliverFillRemaining(
          hasScrollBody: true,
          child: _buildPlanner(context, delegate, nodes, items),
        ),
      ],
    );
  }

  Widget _buildPlanner(
    BuildContext context,
    MessageTimelineDelegate delegate,
    Map<int, MeshNode> nodes,
    List<TimelineItem> items,
  ) {
    final surfaceColor = context.surface;
    final borderColor = context.border;
    final textTertiary = context.textTertiary;

    // Show 3 days at a time so columns are wide enough for readable cards.
    // Users swipe horizontally to see the rest of the week.
    const daysShowed = 3;
    const heightPerMinute = 3.0;

    // Start scrolled to ~7 AM.
    final initialOffset = 7 * 60 * heightPerMinute;

    // Populate the persistent controller with current events.
    // Direct mutation (not updateCalendarData) avoids notifyListeners during
    // the build phase. The planner rebuilds anyway because the parent's
    // setState always produces a new widget subtree.
    final events = _timelineItemsToEvents(items);
    _controller.calendarData.clearAll();
    _controller.calendarData.addEvents(events);

    return EventsPlanner(
      // _rebuildKey is only incremented by explicit user actions (nav buttons,
      // filter chips). Scroll-driven onDayChange does NOT increment it, so
      // the planner survives mid-gesture — preventing a crash in the
      // library's _onPointerUp which calls setState without a mounted check.
      key: ValueKey('planner_$_rebuildKey'),
      controller: _controller,
      daysShowed: daysShowed,
      initialDate: _weekStart,
      maxPreviousDays: 365,
      maxNextDays: 365,
      heightPerMinute: heightPerMinute,
      initialVerticalScrollOffset: initialOffset,
      daySeparationWidth: AppTheme.spacing1,
      automaticAdjustHorizontalScrollToDay: false,
      onDayChange: (firstDay) {
        final newWeekStart = weekStartFor(firstDay);
        if (newWeekStart != _weekStart) {
          setState(() => _weekStart = newWeekStart);
        }
      },
      daysHeaderParam: DaysHeaderParam(
        daysHeaderVisibility: true,
        daysHeaderHeight: 52,
        daysHeaderColor: surfaceColor.withValues(alpha: 0.6),
        dayHeaderBuilder: (day, isToday) {
          final dayAbbr = DateFormat.E(
            Localizations.localeOf(context).toString(),
          ).format(day).toUpperCase();
          final dayNum = day.day.toString();
          return SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayAbbr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: isToday ? AppTheme.primaryPurple : textTertiary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Container(
                  width: AppTheme.spacing28,
                  height: AppTheme.spacing28,
                  decoration: isToday
                      ? BoxDecoration(
                          color: AppTheme.primaryPurple,
                          shape: BoxShape.circle,
                        )
                      : null,
                  alignment: Alignment.center,
                  child: Text(
                    dayNum,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isToday
                          ? SemanticColors.onAccent
                          : context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      currentHourIndicatorParam: CurrentHourIndicatorParam(
        currentHourIndicatorColor: AppTheme.errorRed,
        currentHourIndicatorLineVisibility: true,
        currentHourIndicatorHourVisibility: true,
      ),
      timesIndicatorsParam: TimesIndicatorsParam(
        timesIndicatorsWidth: 48,
        timesIndicatorsHorizontalPadding: 4,
        timesIndicatorsCustomPainter: (heightPerMinute) => HoursPainter(
          heightPerMinute: heightPerMinute,
          showCurrentHour: true,
          hourColor: textTertiary.withValues(alpha: 0.7),
          halfHourColor: borderColor.withValues(alpha: 0.3),
          quarterHourColor: Colors.transparent,
          currentHourIndicatorColor: AppTheme.errorRed,
          halfHourMinHeightPerMinute: 1.3,
          quarterHourMinHeightPerMinute: 2,
        ),
      ),
      offTimesParam: OffTimesParam(
        offTimesAllDaysRanges: [
          OffTimeRange(
            const TimeOfDay(hour: 0, minute: 0),
            const TimeOfDay(hour: 6, minute: 0),
          ),
          OffTimeRange(
            const TimeOfDay(hour: 23, minute: 0),
            const TimeOfDay(hour: 24, minute: 0),
          ),
        ],
        offTimesColor: surfaceColor.withValues(alpha: 0.15),
      ),
      dayParam: DayParam(
        todayColor: AppTheme.primaryPurple.withValues(alpha: 0.04),
        dayEventBuilder: (event, height, width, heightPerMinute) {
          return _MessageEventCard(
            event: event,
            height: height,
            width: width,
            nodes: nodes,
            onTap: () {
              HapticFeedback.lightImpact();
              final timelineItem = event.data;
              if (timelineItem is TimelineItem) {
                delegate.accentColor = event.color;
                delegate.onItemTap(context, timelineItem);
              }
            },
          );
        },
      ),
      pinchToZoomParam: PinchToZoomParameters(
        pinchToZoom: true,
        pinchToZoomMinHeightPerMinute: 1.0,
        pinchToZoomMaxHeightPerMinute: 5.0,
        pinchToZoomSpeed: 1,
      ),
      fullDayParam: const FullDayParam(fullDayEventsBarVisibility: false),
    );
  }
}

/// Event card with DM/channel visual distinction.
///
/// - **DMs**: Cyan accent, person icon, subtle horizontal gradient.
/// - **Channels**: Purple accent, broadcast icon, subtle horizontal gradient.
///
/// Three layout tiers based on available height:
/// - **Compact** (<36px): type icon + title only.
/// - **Standard** (36–75px): type icon + title + message count badge.
/// - **Expanded** (>75px): icon + title + count + participant sigil row.
class _MessageEventCard extends StatelessWidget {
  final Event event;
  final double height;
  final double width;
  final Map<int, MeshNode> nodes;
  final VoidCallback? onTap;

  const _MessageEventCard({
    required this.event,
    required this.height,
    required this.width,
    required this.nodes,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final item = event.data as TimelineItem?;
    final isDm = item != null && item.id.startsWith('dm_');
    final isCompact = height < 36;
    final showSigils = height > 75 && item != null && item.hasParticipants;
    final msgCount = item?.messageCount ?? 0;

    final accentColor = event.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing1,
          vertical: AppTheme.spacing1,
        ),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              accentColor.withValues(alpha: 0.18),
              context.card.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius4),
          border: Border(left: BorderSide(color: accentColor, width: 3)),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacing4,
          vertical: isCompact ? AppTheme.spacing1 : AppTheme.spacing4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row: type icon + name + optional count badge
            Row(
              children: [
                // Type indicator icon
                Icon(
                  isDm
                      ? Icons.person_outline_rounded
                      : Icons.cell_tower_rounded,
                  size: isCompact ? 10 : 13,
                  color: accentColor,
                ),
                const SizedBox(width: AppTheme.spacing2),
                Expanded(
                  child: Text(
                    event.title ?? '',
                    style: TextStyle(
                      fontSize: isCompact ? 10 : 12,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                    maxLines: isCompact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isCompact && msgCount > 0) ...[
                  const SizedBox(width: AppTheme.spacing2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing4,
                      vertical: AppTheme.spacing1,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                    child: Text(
                      '$msgCount',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Participant sigils row
            if (showSigils) ...[const Spacer(), _buildSigilRow(item)],
          ],
        ),
      ),
    );
  }

  Widget _buildSigilRow(TimelineItem item) {
    final sigils = <Widget>[];
    for (final id in item.participantIds.take(4)) {
      final nodeNum = int.tryParse(id);
      if (nodeNum == null) continue;
      sigils.add(
        Padding(
          padding: const EdgeInsets.only(right: AppTheme.spacing2),
          child: SigilWidget(nodeNum: nodeNum, size: 20),
        ),
      );
    }
    if (item.participantIds.length > 4) {
      sigils.add(
        Text(
          '+${item.participantIds.length - 4}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: event.color.withValues(alpha: 0.7),
          ),
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: sigils);
  }
}

/// Compact week navigation controls.
class _WeekNav extends StatelessWidget {
  final DateTime weekStart;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onToday;

  const _WeekNav({
    required this.weekStart,
    required this.onBack,
    required this.onForward,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentWeek = weekStartFor(now) == weekStart;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final label =
        '${weekStart.day}/${weekStart.month}'
        ' – ${weekEnd.day}/${weekEnd.month}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavButton(icon: Icons.chevron_left, onTap: onBack),
        const SizedBox(width: AppTheme.spacing4),
        GestureDetector(
          onTap: isCurrentWeek ? null : onToday,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isCurrentWeek ? context.accentColor : context.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacing4),
        _NavButton(icon: Icons.chevron_right, onTap: onForward),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing4),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius8),
        ),
        child: Icon(icon, size: 18, color: context.textSecondary),
      ),
    );
  }
}

/// Filter chips row for message type filtering.
class _FilterChipRow extends StatelessWidget {
  final MessageTimelineFilter current;
  final ValueChanged<MessageTimelineFilter> onChanged;

  const _FilterChipRow({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterPill(
          label: l10n.messageTimelineFilterAll,
          isSelected: current == MessageTimelineFilter.all,
          onTap: () => onChanged(MessageTimelineFilter.all),
        ),
        const SizedBox(width: AppTheme.spacing4),
        _FilterPill(
          label: l10n.messageTimelineFilterDm,
          isSelected: current == MessageTimelineFilter.directMessages,
          onTap: () => onChanged(MessageTimelineFilter.directMessages),
        ),
        const SizedBox(width: AppTheme.spacing4),
        _FilterPill(
          label: l10n.messageTimelineFilterChannel,
          isSelected: current == MessageTimelineFilter.channels,
          onTap: () => onChanged(MessageTimelineFilter.channels),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing10,
          vertical: AppTheme.spacing4,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? context.accentColor.withValues(alpha: 0.2)
              : context.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(
            color: isSelected ? context.accentColor : context.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? context.accentColor : context.textSecondary,
          ),
        ),
      ),
    );
  }
}
