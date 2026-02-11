// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/section_header.dart';

import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../providers/app_providers.dart';
import '../../providers/presence_providers.dart';

/// Types of events that can appear in the timeline
enum TimelineEventType {
  message,
  nodeJoined,
  nodeLeft,
  signalChange,
  waypoint,
  channelActivity,
}

/// A single event in the mesh timeline
class TimelineEvent {
  final String id;
  final TimelineEventType type;
  final DateTime timestamp;
  final int? nodeNum;
  final String? nodeName;
  final String title;
  final String? subtitle;
  final Map<String, dynamic>? metadata;

  TimelineEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    this.nodeNum,
    this.nodeName,
    required this.title,
    this.subtitle,
    this.metadata,
  });

  IconData get icon {
    switch (type) {
      case TimelineEventType.message:
        return Icons.message;
      case TimelineEventType.nodeJoined:
        return Icons.person_add;
      case TimelineEventType.nodeLeft:
        return Icons.person_remove;
      case TimelineEventType.signalChange:
        return Icons.signal_cellular_alt;
      case TimelineEventType.waypoint:
        return Icons.place;
      case TimelineEventType.channelActivity:
        return Icons.wifi_tethering;
    }
  }

  Color get color {
    switch (type) {
      case TimelineEventType.message:
        return AppTheme.primaryBlue;
      case TimelineEventType.nodeJoined:
        return AppTheme.successGreen;
      case TimelineEventType.nodeLeft:
        return AppTheme.warningYellow;
      case TimelineEventType.signalChange:
        return AppTheme.primaryPurple;
      case TimelineEventType.waypoint:
        return AppTheme.accentOrange;
      case TimelineEventType.channelActivity:
        return AccentColors.magenta;
    }
  }
}

/// Provider that aggregates all mesh events into a timeline
final timelineEventsProvider = Provider<List<TimelineEvent>>((ref) {
  final messages = ref.watch(messagesProvider);
  final nodes = ref.watch(nodesProvider);
  final myNodeNum = ref.watch(myNodeNumProvider);
  final presenceMap = ref.watch(presenceMapProvider);
  final now = ref.watch(presenceClockProvider)();

  final events = <TimelineEvent>[];

  // Add message events
  for (final message in messages) {
    final fromNode = nodes[message.from];
    final toNode = nodes[message.to];

    // Use cached sender info from message, with node lookup as enhancement
    final fromName = fromNode?.shortName ?? message.senderAvatarName;
    final toName = toNode?.shortName ?? _formatNodeId(message.to);

    String title;
    if (message.from == myNodeNum) {
      title = 'You sent a message';
    } else {
      title = '$fromName sent a message';
    }

    String? subtitle;
    if (message.text.isNotEmpty) {
      subtitle = message.text.length > 50
          ? '${message.text.substring(0, 50)}...'
          : message.text;
    }

    // Determine if it's a broadcast or DM
    final isBroadcast = message.to == 0xFFFFFFFF;
    if (!isBroadcast && message.from != myNodeNum) {
      title = '$fromName → $toName';
    }

    events.add(
      TimelineEvent(
        id: 'msg_${message.id}',
        type: TimelineEventType.message,
        timestamp: message.timestamp,
        nodeNum: message.from,
        nodeName: fromNode?.shortName ?? message.senderShortName,
        title: title,
        subtitle: subtitle,
        metadata: {
          'messageId': message.id,
          'channel': message.channel,
          'status': message.status.name,
        },
      ),
    );
  }

  // Add node events based on lastHeard changes
  for (final node in nodes.values) {
    if (node.nodeNum == myNodeNum) continue;

    final presence = presenceConfidenceFor(presenceMap, node);
    final lastHeard = node.lastHeard;
    if (lastHeard != null) {
      // Node was heard - determine if this is a join event
      final isRecent = now.difference(lastHeard).inMinutes < 5;
      if (isRecent && presence.isActive) {
        events.add(
          TimelineEvent(
            id: 'node_heard_${node.nodeNum}_${lastHeard.millisecondsSinceEpoch}',
            type: TimelineEventType.nodeJoined,
            timestamp: lastHeard,
            nodeNum: node.nodeNum,
            nodeName: node.shortName,
            title: '${node.shortName ?? _formatNodeId(node.nodeNum)} is active',
            subtitle: _formatSignalInfo(node),
            metadata: {'rssi': node.rssi, 'snr': node.snr},
          ),
        );
      }

      // Add signal quality info as separate events if significant
      if (node.snr != null && node.snr! < -5) {
        events.add(
          TimelineEvent(
            id: 'signal_${node.nodeNum}_${lastHeard.millisecondsSinceEpoch}',
            type: TimelineEventType.signalChange,
            timestamp: lastHeard,
            nodeNum: node.nodeNum,
            nodeName: node.shortName,
            title:
                'Weak signal from ${node.shortName ?? _formatNodeId(node.nodeNum)}',
            subtitle: 'SNR: ${node.snr?.toStringAsFixed(1)} dB',
            metadata: {'rssi': node.rssi, 'snr': node.snr},
          ),
        );
      }
    }

    // Check for offline nodes
    if (presence.isStale && node.lastHeard != null) {
      final lastHeardTime = node.lastHeard!;
      events.add(
        TimelineEvent(
          id: 'node_offline_${node.nodeNum}',
          type: TimelineEventType.nodeLeft,
          timestamp: lastHeardTime.add(const Duration(minutes: 10)),
          nodeNum: node.nodeNum,
          nodeName: node.shortName,
          title:
              '${node.shortName ?? _formatNodeId(node.nodeNum)} became inactive',
          subtitle: 'Last heard ${_formatTimeAgo(lastHeardTime)}',
        ),
      );
    }

    // Add waypoint events if position changed recently
    if (node.latitude != null &&
        node.longitude != null &&
        node.lastHeard != null) {
      final positionAge = now.difference(node.lastHeard!);
      if (positionAge.inMinutes < 10) {
        events.add(
          TimelineEvent(
            id: 'waypoint_${node.nodeNum}_${node.lastHeard!.millisecondsSinceEpoch}',
            type: TimelineEventType.waypoint,
            timestamp: node.lastHeard!,
            nodeNum: node.nodeNum,
            nodeName: node.shortName,
            title:
                '${node.shortName ?? _formatNodeId(node.nodeNum)} updated position',
            subtitle: _formatPosition(node.latitude!, node.longitude!),
            metadata: {
              'latitude': node.latitude,
              'longitude': node.longitude,
              'altitude': node.altitude,
            },
          ),
        );
      }
    }
  }

  // Sort by timestamp, newest first
  events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  // Remove duplicates based on id
  final seen = <String>{};
  return events.where((e) => seen.add(e.id)).toList();
});

String _formatNodeId(int nodeNum) {
  return '!${nodeNum.toRadixString(16).padLeft(8, '0')}';
}

String _formatSignalInfo(MeshNode node) {
  final parts = <String>[];
  if (node.rssi != null) parts.add('RSSI: ${node.rssi} dBm');
  if (node.snr != null) parts.add('SNR: ${node.snr} dB');
  return parts.join(' · ');
}

String _formatTimeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String _formatPosition(double lat, double lon) {
  final latDir = lat >= 0 ? 'N' : 'S';
  final lonDir = lon >= 0 ? 'E' : 'W';
  return '${lat.abs().toStringAsFixed(4)}°$latDir, ${lon.abs().toStringAsFixed(4)}°$lonDir';
}

/// Filter options for the timeline
enum TimelineFilter { all, messages, nodes, signals, waypoints }

extension TimelineFilterExt on TimelineFilter {
  String get label {
    switch (this) {
      case TimelineFilter.all:
        return 'All';
      case TimelineFilter.messages:
        return 'Messages';
      case TimelineFilter.nodes:
        return 'Nodes';
      case TimelineFilter.signals:
        return 'Signals';
      case TimelineFilter.waypoints:
        return 'Waypoints';
    }
  }

  IconData get icon {
    switch (this) {
      case TimelineFilter.all:
        return Icons.list;
      case TimelineFilter.messages:
        return Icons.message;
      case TimelineFilter.nodes:
        return Icons.people;
      case TimelineFilter.signals:
        return Icons.signal_cellular_alt;
      case TimelineFilter.waypoints:
        return Icons.place;
    }
  }

  bool matches(TimelineEventType type) {
    switch (this) {
      case TimelineFilter.all:
        return true;
      case TimelineFilter.messages:
        return type == TimelineEventType.message;
      case TimelineFilter.nodes:
        return type == TimelineEventType.nodeJoined ||
            type == TimelineEventType.nodeLeft;
      case TimelineFilter.signals:
        return type == TimelineEventType.signalChange;
      case TimelineFilter.waypoints:
        return type == TimelineEventType.waypoint;
    }
  }

  Color color(BuildContext context) {
    switch (this) {
      case TimelineFilter.all:
        return AppTheme.primaryBlue;
      case TimelineFilter.messages:
        return AccentColors.blue;
      case TimelineFilter.nodes:
        return AccentColors.green;
      case TimelineFilter.signals:
        return AppTheme.primaryPurple;
      case TimelineFilter.waypoints:
        return AppTheme.accentOrange;
    }
  }
}

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  TimelineFilter _filter = TimelineFilter.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  List<TimelineEvent> _applyFilter(List<TimelineEvent> events) {
    return events.where((e) => _filter.matches(e.type)).toList();
  }

  List<TimelineEvent> _applySearch(List<TimelineEvent> events) {
    if (_searchQuery.isEmpty) return events;
    final query = _searchQuery.toLowerCase();
    return events.where((e) {
      return e.title.toLowerCase().contains(query) ||
          (e.subtitle?.toLowerCase().contains(query) ?? false) ||
          (e.nodeName?.toLowerCase().contains(query) ?? false) ||
          e.type.name.toLowerCase().contains(query);
    }).toList();
  }

  int _countForFilter(TimelineFilter filter, List<TimelineEvent> allEvents) {
    if (filter == TimelineFilter.all) return allEvents.length;
    return allEvents.where((e) => filter.matches(e.type)).length;
  }

  @override
  Widget build(BuildContext context) {
    final allEvents = ref.watch(timelineEventsProvider);
    final filtered = _applySearch(_applyFilter(allEvents));

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: HelpTourController(
        topicId: 'timeline_overview',
        stepKeys: const {},
        child: GlassScaffold(
          title: 'Timeline',
          centerTitle: true,
          actions: [IcoHelpAppBarButton(topicId: 'timeline_overview')],
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Pinned search + filter chips (consistent with Nodes, NodeDex,
            // Bug Reports)
            SliverPersistentHeader(
              pinned: true,
              delegate: SearchFilterHeaderDelegate(
                searchController: _searchController,
                searchQuery: _searchQuery,
                onSearchChanged: (value) =>
                    setState(() => _searchQuery = value),
                hintText: 'Search events',
                textScaler: MediaQuery.textScalerOf(context),
                rebuildKey: Object.hashAll([
                  _filter,
                  allEvents.length,
                  _countForFilter(TimelineFilter.messages, allEvents),
                  _countForFilter(TimelineFilter.nodes, allEvents),
                  _countForFilter(TimelineFilter.signals, allEvents),
                  _countForFilter(TimelineFilter.waypoints, allEvents),
                ]),
                filterChips: [
                  SectionFilterChip(
                    label: 'All',
                    count: _countForFilter(TimelineFilter.all, allEvents),
                    isSelected: _filter == TimelineFilter.all,
                    color: TimelineFilter.all.color(context),
                    onTap: () => setState(() => _filter = TimelineFilter.all),
                  ),
                  SectionFilterChip(
                    label: 'Messages',
                    count: _countForFilter(TimelineFilter.messages, allEvents),
                    isSelected: _filter == TimelineFilter.messages,
                    color: TimelineFilter.messages.color(context),
                    icon: Icons.message,
                    onTap: () =>
                        setState(() => _filter = TimelineFilter.messages),
                  ),
                  SectionFilterChip(
                    label: 'Nodes',
                    count: _countForFilter(TimelineFilter.nodes, allEvents),
                    isSelected: _filter == TimelineFilter.nodes,
                    color: TimelineFilter.nodes.color(context),
                    icon: Icons.people,
                    onTap: () => setState(() => _filter = TimelineFilter.nodes),
                  ),
                  SectionFilterChip(
                    label: 'Signals',
                    count: _countForFilter(TimelineFilter.signals, allEvents),
                    isSelected: _filter == TimelineFilter.signals,
                    color: TimelineFilter.signals.color(context),
                    icon: Icons.signal_cellular_alt,
                    onTap: () =>
                        setState(() => _filter = TimelineFilter.signals),
                  ),
                  SectionFilterChip(
                    label: 'Waypoints',
                    count: _countForFilter(TimelineFilter.waypoints, allEvents),
                    isSelected: _filter == TimelineFilter.waypoints,
                    color: TimelineFilter.waypoints.color(context),
                    icon: Icons.place,
                    onTap: () =>
                        setState(() => _filter = TimelineFilter.waypoints),
                  ),
                ],
              ),
            ),

            // Content
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(context),
              )
            else
              ..._buildTimelineSlivers(context, filtered),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final hasActiveSearch = _searchQuery.isNotEmpty;
    final hasActiveFilter = _filter != TimelineFilter.all;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              hasActiveSearch
                  ? Icons.search_off
                  : hasActiveFilter
                  ? Icons.filter_list_off
                  : Icons.timeline,
              size: 40,
              color: context.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            hasActiveSearch
                ? 'No events match your search'
                : hasActiveFilter
                ? 'No events match this filter'
                : 'No events yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasActiveSearch || hasActiveFilter
                ? 'Try a different search or filter'
                : 'Activity will appear here as it happens',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textTertiary,
            ),
          ),
          if (hasActiveFilter && !hasActiveSearch) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _filter = TimelineFilter.all),
              child: const Text('Show all events'),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildTimelineSlivers(
    BuildContext context,
    List<TimelineEvent> events,
  ) {
    final theme = Theme.of(context);
    final animationsEnabled = ref.watch(animationsEnabledProvider);

    // Group events by date
    final groupedEvents = <String, List<TimelineEvent>>{};
    for (final event in events) {
      final dateKey = _getDateKey(event.timestamp);
      groupedEvents.putIfAbsent(dateKey, () => []).add(event);
    }

    // Build slivers per date group
    final slivers = <Widget>[];
    var itemIndex = 0;

    for (final entry in groupedEvents.entries) {
      // Date header
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              entry.key,
              style: theme.textTheme.labelLarge?.copyWith(
                color: context.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );

      // Event cards for this date
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final event = entry.value[index];
              final cardIndex = itemIndex + index;
              return Perspective3DSlide(
                index: cardIndex,
                direction: SlideDirection.left,
                enabled: animationsEnabled,
                child: _buildEventCard(theme, event),
              );
            }, childCount: entry.value.length),
          ),
        ),
      );

      itemIndex += entry.value.length;
    }

    // Bottom safe area padding
    slivers.add(
      SliverToBoxAdapter(
        child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ),
    );

    return slivers;
  }

  Widget _buildEventCard(ThemeData theme, TimelineEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: event.color.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(event.icon, color: event.color, size: 20),
              ),
              Container(
                width: 2,
                height: 40,
                color: context.border.withAlpha(77),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Event content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(event.timestamp),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  if (event.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDateKey(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (eventDate == today) {
      return 'Today';
    } else if (eventDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(timestamp).inDays < 7) {
      return _weekdayName(timestamp.weekday);
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday - 1];
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}
