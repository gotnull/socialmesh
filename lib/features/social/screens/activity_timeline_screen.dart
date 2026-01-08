import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../models/social_activity.dart';
import '../../../providers/activity_providers.dart';
import 'post_detail_screen.dart';
import 'profile_social_screen.dart';

/// Activity timeline screen showing social interactions.
///
/// Displays activities grouped by time periods (Today, Yesterday, This Week, etc.)
/// with unread indicators and the ability to mark as read.
class ActivityTimelineScreen extends ConsumerStatefulWidget {
  const ActivityTimelineScreen({super.key});

  @override
  ConsumerState<ActivityTimelineScreen> createState() =>
      _ActivityTimelineScreenState();
}

class _ActivityTimelineScreenState
    extends ConsumerState<ActivityTimelineScreen> {
  @override
  void initState() {
    super.initState();
    // Mark all as read when opening the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activityFeedProvider.notifier).markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(activityFeedProvider);

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        foregroundColor: context.textPrimary,
        title: const Text('Activity'),
        actions: [
          if (feedState.activities.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: context.textSecondary),
              onSelected: (value) {
                if (value == 'clear') {
                  _showClearConfirmation();
                }
              },
              itemBuilder: (context) => [
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
              ],
            ),
        ],
      ),
      body: feedState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : feedState.error != null
          ? _buildError(feedState.error!)
          : feedState.activities.isEmpty
          ? _buildEmpty()
          : _buildActivityList(feedState.activities),
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_outlined,
                size: 48,
                color: context.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No activity yet',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When people interact with you,\nyou\'ll see it here',
              style: TextStyle(color: context.textSecondary, fontSize: 14),
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
            Icon(Icons.error_outline, size: 48, color: context.textTertiary),
            const SizedBox(height: 16),
            Text(
              'Failed to load activity',
              style: TextStyle(color: context.textPrimary, fontSize: 16),
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

  Widget _buildActivityList(List<SocialActivity> activities) {
    // Group activities by time period
    final grouped = _groupActivities(activities);

    return RefreshIndicator(
      onRefresh: () => ref.read(activityFeedProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final group = grouped[index];
          return _ActivityGroup(
            title: group.title,
            activities: group.activities,
            onActivityTap: _handleActivityTap,
            onActivityDismiss: _handleActivityDismiss,
          );
        },
      ),
    );
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

  void _handleActivityTap(SocialActivity activity) {
    // Navigate based on activity type
    switch (activity.type) {
      case SocialActivityType.follow:
      case SocialActivityType.followRequest:
        // User-focused activities - go to their profile
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileSocialScreen(userId: activity.actorId),
          ),
        );
        break;
      case SocialActivityType.storyLike:
      case SocialActivityType.storyView:
        // Story activities - go to actor's profile (stories are on profile)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileSocialScreen(userId: activity.actorId),
          ),
        );
        break;
      case SocialActivityType.postLike:
      case SocialActivityType.postComment:
      case SocialActivityType.mention:
      case SocialActivityType.commentReply:
      case SocialActivityType.commentLike:
        // Post-related activities - navigate to post if content ID exists
        if (activity.contentId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(postId: activity.contentId!),
            ),
          );
        } else {
          // Fallback to profile if no content ID
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileSocialScreen(userId: activity.actorId),
            ),
          );
        }
        break;
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
          'This will remove all activity from your feed. This action cannot be undone.',
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

class _ActivityGroupData {
  final String title;
  final List<SocialActivity> activities;

  const _ActivityGroupData({required this.title, required this.activities});
}

class _ActivityGroup extends StatelessWidget {
  const _ActivityGroup({
    required this.title,
    required this.activities,
    required this.onActivityTap,
    required this.onActivityDismiss,
  });

  final String title;
  final List<SocialActivity> activities;
  final void Function(SocialActivity) onActivityTap;
  final void Function(SocialActivity) onActivityDismiss;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            title,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...activities.map(
          (activity) => Dismissible(
            key: Key(activity.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red.withValues(alpha: 0.2),
              child: const Icon(Icons.delete_outline, color: Colors.red),
            ),
            onDismissed: (_) => onActivityDismiss(activity),
            child: _ActivityTile(
              activity: activity,
              onTap: () => onActivityTap(activity),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity, required this.onTap});

  final SocialActivity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: activity.isRead
              ? Colors.transparent
              : context.accentColor.withValues(alpha: 0.05),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity icon badge on avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
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
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _getActivityColor(activity.type),
                      shape: BoxShape.circle,
                      border: Border.all(color: context.background, width: 2),
                    ),
                    child: Icon(
                      _getActivityIcon(activity.type),
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text:
                              activity.actorSnapshot?.displayName ?? 'Someone',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (activity.actorSnapshot?.isVerified ?? false) ...[
                          const WidgetSpan(
                            child: Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: SimpleVerifiedBadge(size: 14),
                            ),
                          ),
                        ],
                        TextSpan(
                          text: ' ${_getActionText(activity.type)}',
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
                    style: TextStyle(color: context.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Preview image if available
            if (activity.previewImageUrl != null) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  activity.previewImageUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ],
            // Unread indicator
            if (!activity.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.accentColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon(SocialActivityType type) {
    switch (type) {
      case SocialActivityType.storyLike:
      case SocialActivityType.postLike:
      case SocialActivityType.commentLike:
        return Icons.favorite;
      case SocialActivityType.storyView:
        return Icons.visibility;
      case SocialActivityType.follow:
      case SocialActivityType.followRequest:
        return Icons.person_add;
      case SocialActivityType.postComment:
      case SocialActivityType.commentReply:
        return Icons.chat_bubble;
      case SocialActivityType.mention:
        return Icons.alternate_email;
    }
  }

  Color _getActivityColor(SocialActivityType type) {
    switch (type) {
      case SocialActivityType.storyLike:
      case SocialActivityType.postLike:
      case SocialActivityType.commentLike:
        return Colors.redAccent;
      case SocialActivityType.storyView:
        return Colors.blueAccent;
      case SocialActivityType.follow:
      case SocialActivityType.followRequest:
        return Colors.teal;
      case SocialActivityType.postComment:
      case SocialActivityType.commentReply:
        return Colors.orangeAccent;
      case SocialActivityType.mention:
        return Colors.purpleAccent;
    }
  }

  String _getActionText(SocialActivityType type) {
    switch (type) {
      case SocialActivityType.storyLike:
        return 'liked your story';
      case SocialActivityType.storyView:
        return 'viewed your story';
      case SocialActivityType.follow:
        return 'started following you';
      case SocialActivityType.followRequest:
        return 'requested to follow you';
      case SocialActivityType.postLike:
        return 'liked your post';
      case SocialActivityType.postComment:
        return 'commented on your post';
      case SocialActivityType.mention:
        return 'mentioned you';
      case SocialActivityType.commentReply:
        return 'replied to your comment';
      case SocialActivityType.commentLike:
        return 'liked your comment';
    }
  }
}
