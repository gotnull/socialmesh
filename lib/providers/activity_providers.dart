// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';

import '../models/social.dart';
import '../models/social_activity.dart';
import '../services/social_activity_service.dart';

// ===========================================================================
// SERVICE PROVIDER
// ===========================================================================

/// Provider for the SocialActivityService singleton.
final socialActivityServiceProvider = Provider<SocialActivityService>((ref) {
  return SocialActivityService();
});

// ===========================================================================
// ACTIVITY FEED
// ===========================================================================

/// Notifier for the activity feed.
///
/// Listens to auth state changes to restart the activity stream when the user
/// signs in or out.
class ActivityFeedNotifier extends Notifier<ActivityFeedState> {
  StreamSubscription<List<SocialActivity>>? _activitySubscription;
  StreamSubscription<User?>? _authSubscription;

  @override
  ActivityFeedState build() {
    ref.onDispose(() {
      _activitySubscription?.cancel();
      _authSubscription?.cancel();
    });
    _listenToAuthChanges();
    _startWatching();
    return const ActivityFeedState(isLoading: true);
  }

  void _listenToAuthChanges() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      // Auth state changed - restart the activity stream
      AppLogging.social(
        '📬 [ActivityFeed] Auth state changed, restarting stream',
      );
      _startWatching();
    });
  }

  void _startWatching() {
    final service = ref.read(socialActivityServiceProvider);
    _activitySubscription?.cancel();
    _activitySubscription = service.watchActivities().listen(
      (activities) {
        final unreadCount = activities.where((a) => !a.isRead).length;
        state = ActivityFeedState(
          activities: activities,
          unreadCount: unreadCount,
          hasMore: activities.length >= 50,
        );
      },
      onError: (e) {
        AppLogging.social('📬 [ActivityFeed] Error: $e');
        state = ActivityFeedState(error: e.toString());
      },
    );
  }

  /// Refresh the activity feed.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final service = ref.read(socialActivityServiceProvider);
      final activities = await service.getActivities();
      final unreadCount = activities.where((a) => !a.isRead).length;
      state = ActivityFeedState(
        activities: activities,
        unreadCount: unreadCount,
        hasMore: activities.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Mark all activities as read.
  Future<void> markAllAsRead() async {
    try {
      final service = ref.read(socialActivityServiceProvider);
      await service.markAllAsRead();

      // Update local state
      final updatedActivities = state.activities
          .map((a) => a.copyWith(isRead: true))
          .toList();
      state = state.copyWith(activities: updatedActivities, unreadCount: 0);
    } catch (e) {
      AppLogging.social('📬 [ActivityFeed] Error marking all as read: $e');
    }
  }

  /// Mark a single activity as read.
  Future<void> markAsRead(String activityId) async {
    try {
      final service = ref.read(socialActivityServiceProvider);
      await service.markAsRead(activityId);

      // Update local state
      final updatedActivities = state.activities.map((a) {
        if (a.id == activityId) {
          return a.copyWith(isRead: true);
        }
        return a;
      }).toList();
      final unreadCount = updatedActivities.where((a) => !a.isRead).length;
      state = state.copyWith(
        activities: updatedActivities,
        unreadCount: unreadCount,
      );
    } catch (e) {
      AppLogging.social('📬 [ActivityFeed] Error marking as read: $e');
    }
  }

  /// Delete an activity.
  Future<void> deleteActivity(String activityId) async {
    try {
      final service = ref.read(socialActivityServiceProvider);
      await service.deleteActivity(activityId);

      // Update local state
      final updatedActivities = state.activities
          .where((a) => a.id != activityId)
          .toList();
      final unreadCount = updatedActivities.where((a) => !a.isRead).length;
      state = state.copyWith(
        activities: updatedActivities,
        unreadCount: unreadCount,
      );
    } catch (e) {
      AppLogging.social('📬 [ActivityFeed] Error deleting activity: $e');
    }
  }

  /// Clear all activities.
  Future<void> clearAll() async {
    try {
      final service = ref.read(socialActivityServiceProvider);
      await service.clearAllActivities();
      state = const ActivityFeedState();
    } catch (e) {
      AppLogging.social('📬 [ActivityFeed] Error clearing activities: $e');
    }
  }

  /// Inject placeholder activities for testing/preview purposes.
  ///
  /// This adds mock signal activities directly to state without touching Firebase.
  /// Useful for development and UI testing.
  /// Includes signalLike, signalComment, signalCommentReply, and signalResponseVote.
  void injectTestActivities() {
    final now = DateTime.now();
    final testActivities = <SocialActivity>[
      // =========================================================
      // TODAY - Mix of unread activities
      // =========================================================
      SocialActivity(
        id: 'test_signalLike_1',
        type: SocialActivityType.signalLike,
        actorId: 'user_alice',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Alice Chen',
          avatarUrl: 'https://i.pravatar.cc/150?u=alice',
          isVerified: true,
        ),
        targetUserId: 'me',
        contentId: 'signal_001',
        textContent: 'Emergency beacon active - all clear',
        createdAt: now.subtract(const Duration(minutes: 5)),
      ),

      SocialActivity(
        id: 'test_signalComment_1',
        type: SocialActivityType.signalComment,
        actorId: 'user_bob',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Bob Martinez',
          avatarUrl: 'https://i.pravatar.cc/150?u=bob',
        ),
        targetUserId: 'me',
        contentId: 'signal_002',
        textContent: 'Great coverage from that location!',
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),

      SocialActivity(
        id: 'test_signalResponseVote_1',
        type: SocialActivityType.signalResponseVote,
        actorId: 'user_charlie',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Charlie Wang',
          avatarUrl: 'https://i.pravatar.cc/150?u=charlie',
          isVerified: true,
        ),
        targetUserId: 'me',
        contentId: 'signal_003',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),

      SocialActivity(
        id: 'test_signalCommentReply_1',
        type: SocialActivityType.signalCommentReply,
        actorId: 'user_diana',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Diana Rodriguez',
          avatarUrl: 'https://i.pravatar.cc/150?u=diana',
        ),
        targetUserId: 'me',
        contentId: 'signal_004',
        textContent: 'Thanks for the tip!',
        createdAt: now.subtract(const Duration(hours: 2)),
        isRead: true,
      ),

      SocialActivity(
        id: 'test_signalLike_5',
        type: SocialActivityType.signalLike,
        actorId: 'user_eve',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Eve Thompson',
          avatarUrl: 'https://i.pravatar.cc/150?u=eve',
        ),
        targetUserId: 'me',
        contentId: 'signal_005',
        createdAt: now.subtract(const Duration(hours: 4)),
        isRead: true,
      ),

      SocialActivity(
        id: 'test_signalComment_2',
        type: SocialActivityType.signalComment,
        actorId: 'user_frank',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Frank Lee',
          avatarUrl: 'https://i.pravatar.cc/150?u=frank',
          isVerified: true,
        ),
        targetUserId: 'me',
        contentId: 'signal_006',
        textContent: 'What antenna are you using?',
        createdAt: now.subtract(const Duration(hours: 6)),
        isRead: true,
      ),

      // =========================================================
      // YESTERDAY
      // =========================================================
      SocialActivity(
        id: 'test_signalResponseVote_2',
        type: SocialActivityType.signalResponseVote,
        actorId: 'user_grace',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Grace Kim',
          avatarUrl: 'https://i.pravatar.cc/150?u=grace',
        ),
        targetUserId: 'me',
        contentId: 'signal_007',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        isRead: true,
      ),

      SocialActivity(
        id: 'test_signalLike_8',
        type: SocialActivityType.signalLike,
        actorId: 'user_henry',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Henry Nguyen',
          avatarUrl: 'https://i.pravatar.cc/150?u=henry',
          isVerified: true,
        ),
        targetUserId: 'me',
        contentId: 'signal_008',
        textContent: 'Hiking trail checkpoint',
        createdAt: now.subtract(const Duration(days: 1, hours: 5)),
        isRead: true,
      ),

      SocialActivity(
        id: 'test_signalCommentReply_2',
        type: SocialActivityType.signalCommentReply,
        actorId: 'user_iris',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Iris Patel',
          avatarUrl: 'https://i.pravatar.cc/150?u=iris',
        ),
        targetUserId: 'me',
        contentId: 'signal_009',
        textContent: 'Exactly what I was looking for',
        createdAt: now.subtract(const Duration(days: 1, hours: 10)),
        isRead: true,
      ),

      SocialActivity(
        id: 'test_signalComment_3',
        type: SocialActivityType.signalComment,
        actorId: 'user_jack',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Jack Wilson',
          avatarUrl: 'https://i.pravatar.cc/150?u=jack',
        ),
        targetUserId: 'me',
        contentId: 'signal_010',
        textContent: 'How long did the battery last?',
        createdAt: now.subtract(const Duration(days: 1, hours: 14)),
        isRead: true,
      ),

      // =========================================================
      // THIS WEEK
      // =========================================================
      SocialActivity(
        id: 'test_signalLike_11',
        type: SocialActivityType.signalLike,
        actorId: 'user_kate',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Kate Johnson',
          avatarUrl: 'https://i.pravatar.cc/150?u=kate',
          isVerified: true,
        ),
        targetUserId: 'me',
        contentId: 'signal_011',
        createdAt: now.subtract(const Duration(days: 3)),
        isRead: true,
      ),

      SocialActivity(
        id: 'test_signalResponseVote_3',
        type: SocialActivityType.signalResponseVote,
        actorId: 'user_leo',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Leo Garcia',
          avatarUrl: 'https://i.pravatar.cc/150?u=leo',
        ),
        targetUserId: 'me',
        contentId: 'signal_012',
        createdAt: now.subtract(const Duration(days: 4)),
        isRead: true,
      ),

      SocialActivity(
        id: 'test_signalComment_4',
        type: SocialActivityType.signalComment,
        actorId: 'user_maya',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Maya Singh',
          avatarUrl: 'https://i.pravatar.cc/150?u=maya',
        ),
        targetUserId: 'me',
        contentId: 'signal_013',
        textContent: 'This is super helpful for our group!',
        createdAt: now.subtract(const Duration(days: 5)),
        isRead: true,
      ),

      // =========================================================
      // THIS MONTH
      // =========================================================
      SocialActivity(
        id: 'test_signalCommentReply_3',
        type: SocialActivityType.signalCommentReply,
        actorId: 'user_noah',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Noah Brown',
          avatarUrl: 'https://i.pravatar.cc/150?u=noah',
          isVerified: true,
        ),
        targetUserId: 'me',
        contentId: 'signal_014',
        textContent: 'That worked perfectly!',
        createdAt: now.subtract(const Duration(days: 12)),
        isRead: true,
      ),

      SocialActivity(
        id: 'test_signalResponseVote_4',
        type: SocialActivityType.signalResponseVote,
        actorId: 'user_olivia',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Olivia Davis',
          avatarUrl: 'https://i.pravatar.cc/150?u=olivia',
        ),
        targetUserId: 'me',
        contentId: 'signal_015',
        createdAt: now.subtract(const Duration(days: 18)),
        isRead: true,
      ),

      SocialActivity(
        id: 'test_signalLike_16',
        type: SocialActivityType.signalLike,
        actorId: 'user_paul',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Paul Miller',
          avatarUrl: 'https://i.pravatar.cc/150?u=paul',
        ),
        targetUserId: 'me',
        contentId: 'signal_016',
        textContent: 'Community event beacon',
        createdAt: now.subtract(const Duration(days: 22)),
        isRead: true,
      ),

      // =========================================================
      // EARLIER
      // =========================================================
      SocialActivity(
        id: 'test_signalComment_5',
        type: SocialActivityType.signalComment,
        actorId: 'user_quinn',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Quinn Taylor',
          avatarUrl: 'https://i.pravatar.cc/150?u=quinn',
          isVerified: true,
        ),
        targetUserId: 'me',
        contentId: 'signal_017',
        textContent: 'Amazing range from this spot!',
        createdAt: now.subtract(const Duration(days: 45)),
        isRead: true,
      ),

      SocialActivity(
        id: 'test_signalLike_18',
        type: SocialActivityType.signalLike,
        actorId: 'user_rachel',
        actorSnapshot: const PostAuthorSnapshot(
          displayName: 'Rachel Moore',
          avatarUrl: 'https://i.pravatar.cc/150?u=rachel',
        ),
        targetUserId: 'me',
        contentId: 'signal_018',
        textContent: 'First signal test!',
        createdAt: now.subtract(const Duration(days: 60)),
        isRead: true,
      ),
    ];

    final unreadCount = testActivities.where((a) => !a.isRead).length;
    state = ActivityFeedState(
      activities: testActivities,
      unreadCount: unreadCount,
    );

    AppLogging.social(
      '📬 [ActivityFeed] Injected ${testActivities.length} test signal activities '
      '($unreadCount unread)',
    );
  }

  /// Clear test activities and reset to empty state.
  void clearTestActivities() {
    state = const ActivityFeedState();
    AppLogging.social('📬 [ActivityFeed] Cleared test activities');
  }
}

/// Provider for the activity feed.
final activityFeedProvider =
    NotifierProvider<ActivityFeedNotifier, ActivityFeedState>(
      ActivityFeedNotifier.new,
    );

// ===========================================================================
// HELPER PROVIDERS
// ===========================================================================

/// Provider for unread activity count.
final unreadActivityCountProvider = Provider<int>((ref) {
  final feedState = ref.watch(activityFeedProvider);
  return feedState.unreadCount;
});

/// Provider for checking if there are unread activities.
final hasUnreadActivitiesProvider = Provider<bool>((ref) {
  final unreadCount = ref.watch(unreadActivityCountProvider);
  return unreadCount > 0;
});
