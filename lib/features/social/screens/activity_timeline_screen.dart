// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../models/social.dart';
import '../../../models/social_activity.dart';
import '../../../providers/activity_providers.dart';
import '../../../providers/signal_providers.dart';
import '../../../providers/social_providers.dart';
import '../../signals/screens/signal_detail_screen.dart';

/// Activity timeline screen showing signal interactions.
///
/// Displays signal-related activities grouped by time periods
/// (Today, Yesterday, This Week, etc.) with timeline icons.
///
/// Note: Only signal-related activities are shown since social
/// features (posts, stories, follows) have been disabled.
class ActivityTimelineScreen extends ConsumerStatefulWidget {
  const ActivityTimelineScreen({super.key});

  @override
  ConsumerState<ActivityTimelineScreen> createState() =>
      _ActivityTimelineScreenState();
}

class _ActivityTimelineScreenState
    extends ConsumerState<ActivityTimelineScreen> {
  /// Signal-related activity types to display
  static const _signalActivityTypes = {
    SocialActivityType.signalLike,
    SocialActivityType.signalComment,
    SocialActivityType.signalCommentReply,
    SocialActivityType.signalResponseVote,
  };

  /// Set of activity IDs that have been validated as having missing signals
  final Set<String> _invalidActivityIds = {};

  /// Whether we've started the validation process
  bool _validationStarted = false;

  @override
  void initState() {
    super.initState();
    // Validate activities after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateActivities();
    });
  }

  /// Validates that all signal activities have existing signals.
  /// Removes activities where the signal no longer exists.
  Future<void> _validateActivities() async {
    if (_validationStarted) return;
    _validationStarted = true;

    final feedState = ref.read(activityFeedProvider);
    final signalService = ref.read(signalServiceProvider);

    final signalActivities = feedState.activities
        .where((a) => _signalActivityTypes.contains(a.type))
        .where((a) => a.contentId != null)
        .toList();

    for (final activity in signalActivities) {
      // Skip if already marked invalid
      if (_invalidActivityIds.contains(activity.id)) continue;

      // Check if signal exists locally
      final localSignal = await signalService.getSignalById(
        activity.contentId!,
      );
      if (localSignal != null) continue;

      // Check if signal exists in cloud
      final cloudSignal = await signalService.getSignalFromCloudById(
        activity.contentId!,
      );
      if (cloudSignal != null) continue;

      // Signal doesn't exist anywhere - mark as invalid and delete
      _invalidActivityIds.add(activity.id);
      ref.read(activityFeedProvider.notifier).deleteActivity(activity.id);
    }

    // Trigger rebuild if any were removed
    if (_invalidActivityIds.isNotEmpty && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(activityFeedProvider);
    final isAdmin = ref
        .watch(isAdminProvider)
        .maybeWhen(data: (value) => value, orElse: () => false);

    // Re-validate when activities change (new activities may have arrived)
    ref.listen(activityFeedProvider, (previous, next) {
      if (previous?.activities.length != next.activities.length) {
        _validationStarted = false;
        _validateActivities();
      }
    });

    // Only show signal-related activities (filter out ones being validated as invalid)
    final signalActivities = feedState.activities
        .where((a) => _signalActivityTypes.contains(a.type))
        .where((a) => !_invalidActivityIds.contains(a.id))
        .toList();

    return GlassScaffold(
      title: 'Activity',
      actions: [
        AppBarOverflowMenu<String>(
          onSelected: (value) {
            switch (value) {
              case 'clear':
                _showClearConfirmation();
              case 'markAllRead':
                ref.read(activityFeedProvider.notifier).markAllAsRead();
              case 'injectTest':
                ref.read(activityFeedProvider.notifier).injectTestActivities();
              case 'clearTest':
                ref.read(activityFeedProvider.notifier).clearTestActivities();
            }
          },
          itemBuilder: (context) {
            final hasActivities = signalActivities.isNotEmpty;
            final hasUnread = signalActivities.any((a) => !a.isRead);

            return [
              if (hasUnread)
                const PopupMenuItem(
                  value: 'markAllRead',
                  child: Row(
                    children: [
                      Icon(Icons.done_all, size: 20),
                      SizedBox(width: 12),
                      Text('Mark all as read'),
                    ],
                  ),
                ),
              if (hasActivities)
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20),
                      SizedBox(width: 12),
                      Text('Clear all'),
                    ],
                  ),
                ),
              // Admin-only options (visible to admins in release builds)
              if (isAdmin) ...[
                if (hasActivities || hasUnread) const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'injectTest',
                  child: Row(
                    children: [
                      Icon(Icons.science_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Add test activities'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clearTest',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, size: 20),
                      SizedBox(width: 12),
                      Text('Clear test data'),
                    ],
                  ),
                ),
              ],
            ];
          },
        ),
      ],
      slivers: [
        if (feedState.isLoading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (feedState.error != null)
          SliverFillRemaining(child: _buildError(feedState.error!))
        else if (signalActivities.isEmpty)
          SliverFillRemaining(child: _buildEmpty())
        else
          ..._buildActivitySlivers(signalActivities),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.notifications_none_outlined,
                size: 40,
                color: context.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No activity yet',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When people like your signals,\nyou\'ll see it here',
              style: TextStyle(color: context.textTertiary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.error_outline,
                size: 40,
                color: context.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Failed to load activity',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: context.textTertiary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () =>
                  ref.read(activityFeedProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActivitySlivers(List<SocialActivity> activities) {
    // Group activities by time period
    final grouped = _groupActivities(activities);
    final slivers = <Widget>[];

    for (int i = 0; i < grouped.length; i++) {
      final group = grouped[i];

      // Section header with count
      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: group.title,
            count: group.activities.length,
          ),
        ),
      );

      // Activities in this section
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final activity = group.activities[index];
            final isLast = index == group.activities.length - 1;
            final isLastGroup = i == grouped.length - 1;

            return _TimelineActivityTile(
              activity: activity,
              showLine: !isLast || !isLastGroup,
              onTap: () => _handleActivityTap(activity),
              onDismiss: () => _handleActivityDismiss(activity),
            );
          }, childCount: group.activities.length),
        ),
      );
    }

    // Bottom padding
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 32)));

    return slivers;
  }

  List<_ActivityGroupData> _groupActivities(List<SocialActivity> activities) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeek = today.subtract(Duration(days: now.weekday - 1));
    final thisMonth = DateTime(now.year, now.month);

    final todayActivities = <SocialActivity>[];
    final yesterdayActivities = <SocialActivity>[];
    final thisWeekActivities = <SocialActivity>[];
    final thisMonthActivities = <SocialActivity>[];
    final olderActivities = <SocialActivity>[];

    for (final activity in activities) {
      final activityDate = DateTime(
        activity.createdAt.year,
        activity.createdAt.month,
        activity.createdAt.day,
      );

      if (activityDate.isAtSameMomentAs(today)) {
        todayActivities.add(activity);
      } else if (activityDate.isAtSameMomentAs(yesterday)) {
        yesterdayActivities.add(activity);
      } else if (activityDate.isAfter(thisWeek)) {
        thisWeekActivities.add(activity);
      } else if (activityDate.isAfter(thisMonth)) {
        thisMonthActivities.add(activity);
      } else {
        olderActivities.add(activity);
      }
    }

    final groups = <_ActivityGroupData>[];

    if (todayActivities.isNotEmpty) {
      groups.add(
        _ActivityGroupData(title: 'Today', activities: todayActivities),
      );
    }
    if (yesterdayActivities.isNotEmpty) {
      groups.add(
        _ActivityGroupData(title: 'Yesterday', activities: yesterdayActivities),
      );
    }
    if (thisWeekActivities.isNotEmpty) {
      groups.add(
        _ActivityGroupData(title: 'This Week', activities: thisWeekActivities),
      );
    }
    if (thisMonthActivities.isNotEmpty) {
      groups.add(
        _ActivityGroupData(
          title: 'This Month',
          activities: thisMonthActivities,
        ),
      );
    }
    if (olderActivities.isNotEmpty) {
      groups.add(
        _ActivityGroupData(title: 'Earlier', activities: olderActivities),
      );
    }

    return groups;
  }

  /// Get a signal by ID, trying local DB first, then cloud fallback.
  /// If found in cloud, saves locally so it appears in Presence Feed.
  Future<Post?> _getSignalWithCloudFallback(String signalId) async {
    final signalService = ref.read(signalServiceProvider);

    // Try local first
    final localSignal = await signalService.getSignalById(signalId);
    if (localSignal != null) {
      return localSignal;
    }

    // Try cloud fallback
    final cloudSignal = await signalService.getSignalFromCloudById(signalId);
    if (cloudSignal != null) {
      // Save to local DB so it appears in Presence Feed
      await signalService.saveSignalLocally(cloudSignal);
      // Refresh the signal feed to show the newly cached signal
      ref.read(signalFeedProvider.notifier).refresh(silent: true);
    }
    return cloudSignal;
  }

  void _handleActivityTap(SocialActivity activity) {
    // Mark as read when tapped
    if (!activity.isRead) {
      ref.read(activityFeedProvider.notifier).markAsRead(activity.id);
    }

    // Navigate to signal detail
    if (activity.contentId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FutureBuilder(
            future: _getSignalWithCloudFallback(activity.contentId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Loading Signal')),
                  body: const Center(child: CircularProgressIndicator()),
                );
              }
              final signal = snapshot.data;
              if (signal == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Signal not found')),
                  body: const Center(child: Text('Signal not found')),
                );
              }
              return SignalDetailScreen(signal: signal);
            },
          ),
        ),
      );
    }
  }

  void _handleActivityDismiss(SocialActivity activity) {
    ref.read(activityFeedProvider.notifier).deleteActivity(activity.id);
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surface,
        title: Text(
          'Clear all activity?',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Text(
          'This will remove all activity from your feed. '
          'This action cannot be undone.',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(activityFeedProvider.notifier).clearAll();
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TIMELINE ACTIVITY TILE
// ============================================================================

class _TimelineActivityTile extends StatelessWidget {
  final SocialActivity activity;
  final bool showLine;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _TimelineActivityTile({
    required this.activity,
    required this.showLine,
    required this.onTap,
    required this.onDismiss,
  });

  /// Returns the appropriate icon and color for the activity type
  Widget _buildActivityIcon(BuildContext context) {
    final (IconData icon, Color color) = switch (activity.type) {
      SocialActivityType.signalLike => (Icons.favorite, Colors.redAccent),
      SocialActivityType.signalComment => (Icons.chat_bubble, Colors.blue),
      SocialActivityType.signalCommentReply => (
        Icons.chat_bubble_outline,
        Colors.blue,
      ),
      SocialActivityType.signalResponseVote => (Icons.thumb_up, Colors.green),
      _ => (Icons.notifications, Colors.grey),
    };

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: Icon(icon, color: color, size: 18)),
    );
  }

  /// Returns the action text for the activity type
  String _getActionText() {
    return switch (activity.type) {
      SocialActivityType.signalLike => ' liked your signal',
      SocialActivityType.signalComment => ' commented on your signal',
      SocialActivityType.signalCommentReply => ' replied to your comment',
      SocialActivityType.signalResponseVote => ' upvoted your response',
      _ => ' interacted with your signal',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(activity.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.withValues(alpha: 0.2),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) => onDismiss(),
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left edge spacing
              const SizedBox(width: 12),
              // Timeline indicator with continuous line
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Activity type icon (centered) - always heart for signal likes
                    _buildActivityIcon(context),
                    // Vertical line that extends to fill remaining space
                    if (showLine)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: context.border.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Avatar with unread dot
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: context.surface,
                      backgroundImage: activity.actorSnapshot?.avatarUrl != null
                          ? NetworkImage(activity.actorSnapshot!.avatarUrl!)
                          : null,
                      child: activity.actorSnapshot?.avatarUrl == null
                          ? Text(
                              (activity.actorSnapshot?.displayName ?? 'U')[0]
                                  .toUpperCase(),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            )
                          : null,
                    ),
                    // Unread indicator
                    if (!activity.isRead)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: context.accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.background,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  activity.actorSnapshot?.displayName ??
                                  'Someone',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (activity.actorSnapshot?.isVerified ??
                                false) ...[
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: SimpleVerifiedBadge(size: 14),
                                ),
                              ),
                            ],
                            TextSpan(
                              text: _getActionText(),
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (activity.textContent != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          activity.textContent!,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        timeago.format(activity.createdAt),
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Preview image if available
              if (activity.previewImageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      activity.previewImageUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),

              // Right edge spacing
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

class _ActivityGroupData {
  final String title;
  final List<SocialActivity> activities;

  const _ActivityGroupData({required this.title, required this.activities});
}
