// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
/// signs in or out. Handles the not-signed-in and Firebase-not-initialized
/// cases explicitly to avoid stuck loading states.
class ActivityFeedNotifier extends Notifier<ActivityFeedState> {
  StreamSubscription<List<SocialActivity>>? _activitySubscription;
  StreamSubscription<User?>? _authSubscription;

  @override
  ActivityFeedState build() {
    ref.onDispose(() {
      AppLogging.social(
        '📬 [ActivityFeed] build() dispose callback — cancelling subscriptions',
      );
      _activitySubscription?.cancel();
      _authSubscription?.cancel();
    });

    // Gate 1: Firebase not initialized — nothing to do
    if (Firebase.apps.isEmpty) {
      AppLogging.social(
        '📬 [ActivityFeed] build() — Firebase.apps.isEmpty=true, '
        'returning isLoading=false immediately',
      );
      return const ActivityFeedState(isLoading: false);
    }

    // Gate 2: User not signed in — no activities to fetch
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      AppLogging.social(
        '📬 [ActivityFeed] build() — currentUser is null (not signed in), '
        'returning isLoading=false, starting auth listener for future sign-in',
      );
      _listenToAuthChanges();
      return const ActivityFeedState(isLoading: false);
    }

    // Gate 3: Signed in — start watching and return loading state
    AppLogging.social(
      '📬 [ActivityFeed] build() — signed in as uid=${currentUser.uid}, '
      'starting auth listener and activity stream, returning isLoading=true',
    );
    _listenToAuthChanges();
    _startWatching();
    return const ActivityFeedState(isLoading: true);
  }

  void _listenToAuthChanges() {
    _authSubscription?.cancel();

    // Check if Firebase is initialized before accessing FirebaseAuth
    if (Firebase.apps.isEmpty) {
      AppLogging.social(
        '📬 [ActivityFeed] _listenToAuthChanges() — Firebase not initialized, '
        'skipping auth listener',
      );
      return;
    }

    AppLogging.social(
      '📬 [ActivityFeed] _listenToAuthChanges() — subscribing to '
      'authStateChanges()',
    );

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      AppLogging.social(
        '📬 [ActivityFeed] authStateChanges fired — '
        'user=${user?.uid ?? 'null'}, restarting stream',
      );
      _startWatching();
    });
  }

  void _startWatching() {
    // Gate 1: Firebase not initialized
    if (Firebase.apps.isEmpty) {
      AppLogging.social(
        '📬 [ActivityFeed] _startWatching() — Firebase not initialized, '
        'setting isLoading=false',
      );
      state = const ActivityFeedState(isLoading: false);
      return;
    }

    // Gate 2: Not signed in — cancel any existing subscription, show empty
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      AppLogging.social(
        '📬 [ActivityFeed] _startWatching() — currentUser is null '
        '(not signed in), cancelling activity subscription, '
        'setting isLoading=false with empty activities',
      );
      _activitySubscription?.cancel();
      _activitySubscription = null;
      state = const ActivityFeedState(isLoading: false);
      return;
    }

    // Gate 3: Signed in — subscribe to activity stream
    AppLogging.social(
      '📬 [ActivityFeed] _startWatching() — signed in as '
      'uid=${currentUser.uid}, setting up activity stream',
    );

    try {
      final service = ref.read(socialActivityServiceProvider);

      // Cancel previous subscription before creating new one
      if (_activitySubscription != null) {
        AppLogging.social(
          '📬 [ActivityFeed] _startWatching() — cancelling previous '
          'activity subscription',
        );
      }
      _activitySubscription?.cancel();

      AppLogging.social(
        '📬 [ActivityFeed] _startWatching() — calling '
        'service.watchActivities()',
      );

      _activitySubscription = service.watchActivities().listen(
        (activities) {
          final unreadCount = activities.where((a) => !a.isRead).length;
          AppLogging.social(
            '📬 [ActivityFeed] stream emitted — '
            '${activities.length} activities, $unreadCount unread, '
            'setting isLoading=false',
          );
          state = ActivityFeedState(
            activities: activities,
            unreadCount: unreadCount,
            hasMore: activities.length >= 50,
          );
        },
        onError: (Object e, StackTrace st) {
          AppLogging.social(
            '📬 [ActivityFeed] stream error — $e\n'
            '  stackTrace: $st',
          );
          state = ActivityFeedState(error: e.toString());
        },
        onDone: () {
          AppLogging.social(
            '📬 [ActivityFeed] stream completed (onDone) — '
            'current state: isLoading=${state.isLoading}, '
            'activities=${state.activities.length}',
          );
        },
      );

      AppLogging.social(
        '📬 [ActivityFeed] _startWatching() — stream subscription created '
        'successfully',
      );
    } catch (e, st) {
      AppLogging.social(
        '📬 [ActivityFeed] _startWatching() — EXCEPTION creating stream: '
        '$e\n  stackTrace: $st',
      );
      state = ActivityFeedState(error: e.toString());
    }
  }

  /// Refresh the activity feed.
  Future<void> refresh() async {
    // Check if Firebase is initialized
    if (Firebase.apps.isEmpty) {
      AppLogging.social(
        '📬 [ActivityFeed] refresh() — Firebase not initialized, '
        'setting isLoading=false',
      );
      state = state.copyWith(isLoading: false);
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      AppLogging.social(
        '📬 [ActivityFeed] refresh() — not signed in, '
        'setting isLoading=false',
      );
      state = state.copyWith(isLoading: false);
      return;
    }

    AppLogging.social(
      '📬 [ActivityFeed] refresh() — starting refresh for '
      'uid=${currentUser.uid}',
    );
    state = state.copyWith(isLoading: true);

    try {
      final service = ref.read(socialActivityServiceProvider);
      final activities = await service.getActivities();
      final unreadCount = activities.where((a) => !a.isRead).length;
      AppLogging.social(
        '📬 [ActivityFeed] refresh() — success, '
        '${activities.length} activities, $unreadCount unread',
      );
      state = ActivityFeedState(
        activities: activities,
        unreadCount: unreadCount,
        hasMore: activities.length >= 20,
      );
    } catch (e, st) {
      AppLogging.social(
        '📬 [ActivityFeed] refresh() — FAILED: $e\n  stackTrace: $st',
      );
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Mark all activities as read.
  Future<void> markAllAsRead() async {
    if (Firebase.apps.isEmpty) {
      AppLogging.social(
        '📬 [ActivityFeed] markAllAsRead() — Firebase not initialized, skip',
      );
      return;
    }

    AppLogging.social(
      '📬 [ActivityFeed] markAllAsRead() — marking '
      '${state.activities.length} activities as read',
    );

    try {
      final service = ref.read(socialActivityServiceProvider);
      await service.markAllAsRead();

      // Update local state
      final updatedActivities = state.activities
          .map((a) => a.copyWith(isRead: true))
          .toList();
      state = state.copyWith(activities: updatedActivities, unreadCount: 0);
      AppLogging.social('📬 [ActivityFeed] markAllAsRead() — success');
    } catch (e) {
      AppLogging.social('📬 [ActivityFeed] markAllAsRead() — ERROR: $e');
    }
  }

  /// Mark a single activity as read.
  Future<void> markAsRead(String activityId) async {
    if (Firebase.apps.isEmpty) {
      AppLogging.social(
        '📬 [ActivityFeed] markAsRead($activityId) — '
        'Firebase not initialized, skip',
      );
      return;
    }

    AppLogging.social(
      '📬 [ActivityFeed] markAsRead($activityId) — marking as read',
    );

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
      AppLogging.social(
        '📬 [ActivityFeed] markAsRead($activityId) — success, '
        '$unreadCount unread remaining',
      );
    } catch (e) {
      AppLogging.social(
        '📬 [ActivityFeed] markAsRead($activityId) — ERROR: $e',
      );
    }
  }

  /// Delete an activity.
  Future<void> deleteActivity(String activityId) async {
    AppLogging.social(
      '📬 [ActivityFeed] deleteActivity($activityId) — deleting',
    );

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
      AppLogging.social(
        '📬 [ActivityFeed] deleteActivity($activityId) — success, '
        '${updatedActivities.length} activities remaining',
      );
    } catch (e) {
      AppLogging.social(
        '📬 [ActivityFeed] deleteActivity($activityId) — ERROR: $e',
      );
    }
  }

  /// Clear all activities.
  Future<void> clearAll() async {
    AppLogging.social(
      '📬 [ActivityFeed] clearAll() — clearing '
      '${state.activities.length} activities',
    );

    try {
      final service = ref.read(socialActivityServiceProvider);
      await service.clearAllActivities();
      state = const ActivityFeedState();
      AppLogging.social('📬 [ActivityFeed] clearAll() — success');
    } catch (e) {
      AppLogging.social('📬 [ActivityFeed] clearAll() — ERROR: $e');
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
