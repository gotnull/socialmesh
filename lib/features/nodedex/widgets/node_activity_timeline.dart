// SPDX-License-Identifier: GPL-3.0-or-later

// Node Activity Timeline — unified chronological event feed.
//
// Renders a scrollable list of all observable events for a single
// node: encounters, messages, presence transitions, signals, and
// milestones. Each event type has a distinct icon, color, and
// one-line summary for scanability.
//
// Design constraints:
//   - Vertical timeline with left-aligned dot + connector line
//   - Type-specific icons in colored circles
//   - Relative + absolute timestamps
//   - Paginated: initial 50 events, "load more" trigger at bottom
//   - Field journal aesthetic (muted tones, monospace dates)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../models/presence_confidence.dart';
import '../models/node_activity_event.dart';
import '../providers/nodedex_providers.dart';

/// A unified chronological timeline of all activity for a single node.
///
/// Embedded in the NodeDex detail screen as a sticky-header section.
/// Shows encounters, messages, presence changes, signals, and milestones
/// in one scrollable feed.
class NodeActivityTimeline extends ConsumerStatefulWidget {
  /// The node number to display the timeline for.
  final int nodeNum;

  /// Primary accent color (typically from the node's sigil).
  final Color accentColor;

  const NodeActivityTimeline({
    super.key,
    required this.nodeNum,
    required this.accentColor,
  });

  @override
  ConsumerState<NodeActivityTimeline> createState() =>
      _NodeActivityTimelineState();
}

class _NodeActivityTimelineState extends ConsumerState<NodeActivityTimeline> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final asyncEvents = ref.watch(nodeActivityTimelineProvider(widget.nodeNum));

    return asyncEvents.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (e, st) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Could not load timeline',
            style: TextStyle(fontSize: 13, color: context.textTertiary),
          ),
        ),
      ),
      data: (allEvents) {
        if (allEvents.isEmpty) {
          return _EmptyTimeline(accentColor: widget.accentColor);
        }

        final pageSize = NodeDexConfig.timelinePageSize;
        final totalPages = (allEvents.length / pageSize).ceil();

        // Clamp current page to valid range.
        var page = _currentPage;
        if (page >= totalPages && totalPages > 0) {
          page = totalPages - 1;
        }

        final startIndex = page * pageSize;
        final endIndex = (startIndex + pageSize).clamp(0, allEvents.length);
        final pageItems = allEvents.sublist(startIndex, endIndex);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < pageItems.length; i++)
              _TimelineEventTile(
                event: pageItems[i],
                accentColor: widget.accentColor,
                isFirst: i == 0,
                isLast: i == pageItems.length - 1,
              ),
            // Pagination footer
            if (totalPages > 1) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PaginationButton(
                    icon: Icons.chevron_left,
                    enabled: page > 0,
                    accentColor: widget.accentColor,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _currentPage = page - 1);
                    },
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${page + 1} / $totalPages',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _PaginationButton(
                    icon: Icons.chevron_right,
                    enabled: page < totalPages - 1,
                    accentColor: widget.accentColor,
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
      },
    );
  }
}

// =============================================================================
// Empty state
// =============================================================================

class _EmptyTimeline extends StatelessWidget {
  final Color accentColor;

  const _EmptyTimeline({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timeline_outlined,
            size: 40,
            color: context.textTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'No activity yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Events will appear here as you interact with this node.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.textTertiary),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Single event tile
// =============================================================================

class _TimelineEventTile extends StatelessWidget {
  final NodeActivityEvent event;
  final Color accentColor;
  final bool isFirst;
  final bool isLast;

  const _TimelineEventTile({
    required this.event,
    required this.accentColor,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(context);
    final icon = _eventIcon();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline connector + dot column
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Top connector
                Container(
                  width: 1.5,
                  height: 8,
                  color: isFirst
                      ? Colors.transparent
                      : context.border.withValues(alpha: 0.3),
                ),
                // Dot
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.15),
                    border: Border.all(
                      color: color.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(icon, size: 12, color: color),
                ),
                // Bottom connector
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: isLast
                        ? Colors.transparent
                        : context.border.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Content column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary line
                  Text(
                    _summaryText(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Timestamp row
                  Text(
                    _formatTimestamp(event.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textTertiary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                  // Optional detail line
                  if (_detailText() != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _detailText()!,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  IconData _eventIcon() {
    return switch (event) {
      EncounterActivityEvent() => Icons.radar,
      MessageActivityEvent(outgoing: true) => Icons.arrow_upward,
      MessageActivityEvent(outgoing: false) => Icons.arrow_downward,
      PresenceChangeActivityEvent() => Icons.swap_vert,
      SignalActivityEvent() => Icons.bolt,
      MilestoneActivityEvent() => Icons.flag_outlined,
    };
  }

  Color _eventColor(BuildContext context) {
    return switch (event) {
      EncounterActivityEvent() => accentColor,
      MessageActivityEvent() => const Color(0xFF0EA5E9),
      PresenceChangeActivityEvent() => const Color(0xFFF97316),
      SignalActivityEvent() => const Color(0xFF8B5CF6),
      MilestoneActivityEvent() => const Color(0xFFFBBF24),
    };
  }

  String _summaryText() {
    return switch (event) {
      EncounterActivityEvent(
        :final count,
        :final distanceMeters,
        :final snr,
        :final sessionStart,
        :final timestamp,
      ) =>
        count > 1
            ? _encounterSessionText(
                count,
                sessionStart,
                timestamp,
                distanceMeters,
                snr,
              )
            : distanceMeters != null
            ? 'Encountered at ${_formatDistance(distanceMeters)}'
            : snr != null
            ? 'Encountered (SNR ${snr}dB)'
            : 'Encountered',
      MessageActivityEvent(:final outgoing, :final text) =>
        outgoing
            ? 'Sent: ${_truncate(text, 60)}'
            : 'Received: ${_truncate(text, 60)}',
      PresenceChangeActivityEvent(:final fromState, :final toState) =>
        '${_presenceLabel(fromState)} \u2192 ${_presenceLabel(toState)}',
      SignalActivityEvent(:final content) =>
        'Signal: ${_truncate(content, 60)}',
      MilestoneActivityEvent(:final label) => label,
    };
  }

  static String _encounterSessionText(
    int count,
    DateTime start,
    DateTime end,
    double? distance,
    int? snr,
  ) {
    final duration = end.difference(start);
    final durationLabel = duration.inMinutes < 1
        ? '<1 min'
        : duration.inMinutes < 60
        ? '${duration.inMinutes} min'
        : '${(duration.inMinutes / 60).toStringAsFixed(1)} hr';

    final detail = distance != null
        ? ', closest ${_formatDistance(distance)}'
        : snr != null
        ? ', best SNR ${snr}dB'
        : '';

    return '$count encounters over $durationLabel$detail';
  }

  String? _detailText() {
    return switch (event) {
      EncounterActivityEvent(:final latitude, :final longitude)
          when latitude != null && longitude != null =>
        '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
      MessageActivityEvent(:final channel) when channel != null =>
        'Channel $channel',
      _ => null,
    };
  }

  static String _presenceLabel(PresenceConfidence c) {
    return switch (c) {
      PresenceConfidence.active => 'Active',
      PresenceConfidence.fading => 'Fading',
      PresenceConfidence.stale => 'Stale',
      PresenceConfidence.unknown => 'Unknown',
    };
  }

  static String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  static String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 1)}\u2026';
  }

  static String _formatTimestamp(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);

    final relative = _relativeTime(diff);
    final absolute = DateFormat('MMM d, HH:mm').format(ts);
    return '$relative \u00B7 $absolute';
  }

  static String _relativeTime(Duration diff) {
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}

// =============================================================================
// Pagination button
// =============================================================================

class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color accentColor;
  final VoidCallback onTap;

  const _PaginationButton({
    required this.icon,
    required this.enabled,
    required this.accentColor,
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
          color: enabled ? accentColor.withValues(alpha: 0.1) : context.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? accentColor.withValues(alpha: 0.3)
                : context.border.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? accentColor : context.textTertiary,
        ),
      ),
    );
  }
}
