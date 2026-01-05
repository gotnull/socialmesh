import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/edge_fade.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';

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

    final lastHeard = node.lastHeard;
    if (lastHeard != null) {
      // Node was heard - determine if this is a join event
      final isRecent = DateTime.now().difference(lastHeard).inMinutes < 5;
      if (isRecent && node.isOnline) {
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
    if (!node.isOnline && node.lastHeard != null) {
      final lastHeardTime = node.lastHeard!;
      events.add(
        TimelineEvent(
          id: 'node_offline_${node.nodeNum}',
          type: TimelineEventType.nodeLeft,
          timestamp: lastHeardTime.add(const Duration(minutes: 15)),
          nodeNum: node.nodeNum,
          nodeName: node.shortName,
          title:
              '${node.shortName ?? _formatNodeId(node.nodeNum)} went offline',
          subtitle: 'Last heard ${_formatTimeAgo(lastHeardTime)}',
        ),
      );
    }

    // Add waypoint events if position changed recently
    if (node.latitude != null &&
        node.longitude != null &&
        node.lastHeard != null) {
      final positionAge = DateTime.now().difference(node.lastHeard!);
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
  return parts.join(' • ');
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
}

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  TimelineFilter _filter = TimelineFilter.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allEvents = ref.watch(timelineEventsProvider);
    final events = allEvents.where((e) => _filter.matches(e.type)).toList();

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text('Timeline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterChips(theme),
          // Timeline list
          Expanded(
            child: events.isEmpty
                ? _buildEmptyState(theme)
                : _buildTimeline(theme, events),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: EdgeFade.end(
        fadeSize: 32,
        fadeColor: context.background,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: TimelineFilter.values.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = TimelineFilter.values[index];
            final isSelected = _filter == filter;
            return FilterChip(
              selected: isSelected,
              showCheckmark: false,
              label: Text(filter.label),
              avatar: Icon(
                filter.icon,
                size: 18,
                color: isSelected ? Colors.white : context.textSecondary,
              ),
              onSelected: (selected) {
                setState(() {
                  _filter = filter;
                });
              },
              selectedColor: context.accentColor,
              backgroundColor: context.surface,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : context.textSecondary,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
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
            child: Icon(Icons.timeline, size: 40, color: context.textTertiary),
          ),
          SizedBox(height: 24),
          Text(
            'No events yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Activity will appear here as it happens',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(ThemeData theme, List<TimelineEvent> events) {
    // Group events by date
    final groupedEvents = <String, List<TimelineEvent>>{};
    for (final event in events) {
      final dateKey = _getDateKey(event.timestamp);
      groupedEvents.putIfAbsent(dateKey, () => []).add(event);
    }

    return Consumer(
      builder: (context, ref, _) {
        final animationsEnabled = ref.watch(animationsEnabledProvider);

        // Flatten into a list of widgets with date headers
        final widgets = <Widget>[];
        var itemIndex = 0;

        for (final dateKey in groupedEvents.keys) {
          final dateEvents = groupedEvents[dateKey]!;

          // Date header (no animation)
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                dateKey,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: context.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );

          // Individual event cards with staggered animation
          for (final event in dateEvents) {
            widgets.add(
              Perspective3DSlide(
                index: itemIndex++,
                direction: SlideDirection.left,
                enabled: animationsEnabled,
                child: _buildEventCard(theme, event),
              ),
            );
          }
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: widgets,
        );
      },
    );
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
          SizedBox(width: 12),
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
                    SizedBox(height: 4),
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

  void _showFilterDialog() {
    AppBottomSheet.show(
      context: context,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Filter Events',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
          ...TimelineFilter.values.map((filter) {
            return ListTile(
              leading: Icon(
                filter.icon,
                color: _filter == filter
                    ? context.accentColor
                    : context.textSecondary,
              ),
              title: Text(filter.label),
              trailing: _filter == filter
                  ? Icon(Icons.check, color: context.accentColor)
                  : null,
              onTap: () {
                setState(() {
                  _filter = filter;
                });
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }
}
