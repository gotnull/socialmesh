// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import '../../../core/logging.dart';
import '../../../services/notifications/notification_service.dart';
import '../models/tak_event.dart';

/// Periodically checks tracked TAK entities for stale transitions and fires
/// local notifications via [NotificationService].
///
/// Each entity fires at most one notification per stale transition. If the
/// entity recovers (receives a new position update with a future stale time),
/// the dedup flag resets so a future stale transition will fire again.
class TakStaleMonitor {
  final NotificationService _notificationService;

  /// Returns the current set of tracked UIDs.
  final Set<String> Function() _getTrackedUids;

  /// Returns the current list of active TAK events.
  final List<TakEvent> Function() _getEvents;

  Timer? _timer;

  /// UIDs for which a stale notification has already been fired.
  final Set<String> _notifiedUids = {};

  TakStaleMonitor({
    required NotificationService notificationService,
    required Set<String> Function() getTrackedUids,
    required List<TakEvent> Function() getEvents,
  }) : _notificationService = notificationService,
       _getTrackedUids = getTrackedUids,
       _getEvents = getEvents;

  /// Whether the monitor is running.
  bool get isRunning => _timer != null && _timer!.isActive;

  /// Start the periodic stale check (every 30 seconds).
  void start() {
    if (isRunning) return;
    AppLogging.tak('StaleMonitor: started');
    _check();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  /// Stop the monitor.
  void stop() {
    _timer?.cancel();
    _timer = null;
    AppLogging.tak('StaleMonitor: stopped');
  }

  /// Clean up.
  void dispose() {
    stop();
    _notifiedUids.clear();
  }

  // ---------------------------------------------------------------------------

  void _check() {
    final trackedUids = _getTrackedUids();
    if (trackedUids.isEmpty) return;

    final events = _getEvents();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final uid in trackedUids) {
      final event = events.cast<TakEvent?>().firstWhere(
        (e) => e!.uid == uid,
        orElse: () => null,
      );
      if (event == null) continue;

      final isStale = now > event.staleUtcMs;

      if (isStale && !_notifiedUids.contains(uid)) {
        // Newly stale — fire notification.
        AppLogging.tak(
          'StaleMonitor: entity $uid (${event.displayName}) '
          'transitioned to stale',
        );
        _notifiedUids.add(uid);
        _fireNotification(event);
      } else if (!isStale && _notifiedUids.contains(uid)) {
        // Entity recovered — reset dedup.
        AppLogging.tak(
          'StaleMonitor: entity $uid (${event.displayName}) '
          'recovered from stale, resetting dedup',
        );
        _notifiedUids.remove(uid);
      }
    }

    // Clean up dedup entries for UIDs that are no longer tracked.
    _notifiedUids.removeWhere((uid) => !trackedUids.contains(uid));
  }

  void _fireNotification(TakEvent event) {
    final age = DateTime.now().millisecondsSinceEpoch - event.timeUtcMs;
    final minutes = age ~/ 60000;
    final timeAgo = minutes < 1
        ? 'just now'
        : minutes < 60
        ? '$minutes min ago'
        : '${minutes ~/ 60}h ${minutes % 60}m ago';

    AppLogging.tak(
      'StaleMonitor: firing notification for ${event.displayName}',
    );

    _notificationService.showTakStaleNotification(
      uid: event.uid,
      callsign: event.displayName,
      lat: event.lat,
      lon: event.lon,
      timeAgo: timeAgo,
    );
  }
}
