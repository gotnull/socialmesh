// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';

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
