// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';
import '../models/social_activity.dart';
import '../providers/auth_providers.dart';
import '../services/social_activity_service.dart';

// ===========================================================================
// SERVICE PROVIDER
// ===========================================================================

/// Provider for the SocialActivityService singleton.
final socialActivityServiceProvider = Provider<SocialActivityService>((ref) {
  return SocialActivityService();
});

// ===========================================================================
// ACTIVITY FEED NOTIFIER
// ===========================================================================

/// Notifier for the activity feed.
///
/// Reactively watches [firebaseReadyProvider] and [currentUserProvider] so
/// that [build] automatically re-runs when:
///   - Firebase finishes initializing (was the root cause of activities never
///     showing on some devices — if Firebase initialized after the first build,
///     the notifier was stuck in empty state forever)
///   - The user signs in or out
///
/// The previous implementation used raw `Firebase.apps.isEmpty` and
/// `FirebaseAuth.instance.currentUser` checks with a manual auth stream
/// subscription. Because those are not Riverpod-reactive, the notifier
/// had no dependency that would trigger a rebuild when conditions changed.
class ActivityFeedNotifier extends Notifier<ActivityFeedState> {
  StreamSubscription<List<SocialActivity>>? _activitySubscription;

  @override
  ActivityFeedState build() {
    // Cancel any existing subscription when rebuild occurs.
    // Riverpod calls build() each time a watched dependency changes,
    // so we must clean up the previous Firestore stream.
    _activitySubscription?.cancel();
    _activitySubscription = null;

    ref.onDispose(() {
      AppLogging.social(
        '📬 [ActivityFeed] dispose — cancelling activity subscription',
      );
      _activitySubscription?.cancel();
      _activitySubscription = null;
    });

    // ---- Gate 1: Firebase readiness (reactive) ----
    // Watching this provider is the key fix. When Firebase initializes
    // asynchronously (after runApp), this future completes and triggers
    // a rebuild of this notifier automatically.
    final firebaseAsync = ref.watch(firebaseReadyProvider);
    final isFirebaseReady = firebaseAsync.whenOrNull(data: (v) => v) ?? false;

    if (!isFirebaseReady) {
      AppLogging.social(
        '📬 [ActivityFeed] build() — Firebase not ready yet '
        '(state: loading=${firebaseAsync.isLoading}, '
        'error=${firebaseAsync.error}), returning empty state',
      );
      return const ActivityFeedState(isLoading: false);
    }

    // ---- Gate 2: Auth state (reactive) ----
    // Watching currentUserProvider means build() re-runs when the user
    // signs in or out. No manual authStateChanges subscription needed.
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      AppLogging.social(
        '📬 [ActivityFeed] build() — user not signed in, '
        'returning empty state',
      );
      return const ActivityFeedState(isLoading: false);
    }

    // ---- Gate 3: Start watching activities ----
    AppLogging.social(
      '📬 [ActivityFeed] build() — signed in as uid=${currentUser.uid}, '
      'starting activity stream',
    );
    _startWatching(currentUser);
    return const ActivityFeedState(isLoading: true);
  }

  void _startWatching(User currentUser) {
    try {
      final service = ref.read(socialActivityServiceProvider);

      AppLogging.social(
        '📬 [ActivityFeed] _startWatching() — creating Firestore stream '
        'for uid=${currentUser.uid}',
      );

      _activitySubscription = service.watchActivities().listen(
        (activities) {
          final unreadCount = activities.where((a) => !a.isRead).length;
          AppLogging.social(
            '📬 [ActivityFeed] stream emitted — '
            '${activities.length} activities, $unreadCount unread',
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
        '📬 [ActivityFeed] _startWatching() — stream subscription created',
      );
    } catch (e, st) {
      AppLogging.social(
        '📬 [ActivityFeed] _startWatching() — EXCEPTION: $e\n'
        '  stackTrace: $st',
      );
      state = ActivityFeedState(error: e.toString());
    }
  }

  /// Refresh the activity feed by doing a one-shot fetch.
  Future<void> refresh() async {
    final firebaseAsync = ref.read(firebaseReadyProvider);
    final isFirebaseReady = firebaseAsync.whenOrNull(data: (v) => v) ?? false;

    if (!isFirebaseReady) {
      AppLogging.social(
        '📬 [ActivityFeed] refresh() — Firebase not ready, skip',
      );
      state = state.copyWith(isLoading: false);
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      AppLogging.social('📬 [ActivityFeed] refresh() — not signed in, skip');
      state = state.copyWith(isLoading: false);
      return;
    }

    AppLogging.social(
      '📬 [ActivityFeed] refresh() — starting for uid=${currentUser.uid}',
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
    final firebaseAsync = ref.read(firebaseReadyProvider);
    final isFirebaseReady = firebaseAsync.whenOrNull(data: (v) => v) ?? false;

    if (!isFirebaseReady) {
      AppLogging.social(
        '📬 [ActivityFeed] markAllAsRead() — Firebase not ready, skip',
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
    final firebaseAsync = ref.read(firebaseReadyProvider);
    final isFirebaseReady = firebaseAsync.whenOrNull(data: (v) => v) ?? false;

    if (!isFirebaseReady) {
      AppLogging.social(
        '📬 [ActivityFeed] markAsRead($activityId) — '
        'Firebase not ready, skip',
      );
      return;
    }

    AppLogging.social(
      '📬 [ActivityFeed] markAsRead($activityId) — marking as read',
    );

    try {
      final service = ref.read(socialActivityServiceProvider);
      await service.markAsRead(activityId);

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
