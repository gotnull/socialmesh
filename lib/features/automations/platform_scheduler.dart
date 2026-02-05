// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart' as wm;
import 'package:background_fetch/background_fetch.dart' as bgf;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/logging.dart';
import 'models/schedule_spec.dart';
import 'scheduler_service.dart';

/// Key used to store scheduled task IDs in SharedPreferences
const _scheduledTasksKey = 'scheduled_platform_tasks';

/// Key used to store next fire times for iOS one-shot tracking
const _iosOneShotTimesKey = 'ios_oneshot_fire_times';

/// WorkManager task names
const _workManagerOneShotTask = 'scheduled_automation_oneshot';
const _workManagerPeriodicTask = 'scheduled_automation_periodic';

/// Interface for platform-specific background scheduler implementations
///
/// This defines the contract for native schedulers that can run when the
/// app is in the background. The in-app scheduler handles scheduling while
/// the app is foregrounded, but for reliable background execution, platform
/// schedulers are needed.
///
/// Implementations:
/// - Android: WorkManager
/// - iOS: BGTaskScheduler via background_fetch
abstract class PlatformScheduler {
  /// Initialize the platform scheduler
  ///
  /// Should be called once during app startup to register background
  /// task handlers with the platform.
  Future<void> initialize();

  /// Schedule a one-shot background task
  ///
  /// The task will be executed at approximately [scheduledFor] time,
  /// subject to platform-specific constraints (battery optimization,
  /// network conditions, etc.)
  Future<void> scheduleOneShot({
    required String taskId,
    required DateTime scheduledFor,
    Map<String, dynamic>? inputData,
  });

  /// Schedule a periodic background task
  ///
  /// The task will be executed repeatedly with approximately [interval]
  /// between executions. Minimum interval varies by platform:
  /// - Android WorkManager: 15 minutes
  /// - iOS BGTaskScheduler: ~15 minutes (system-determined)
  Future<void> schedulePeriodic({
    required String taskId,
    required Duration interval,
    Map<String, dynamic>? inputData,
  });

  /// Cancel a scheduled task
  Future<void> cancelTask(String taskId);

  /// Cancel all scheduled tasks
  Future<void> cancelAllTasks();

  /// Check if a task is scheduled
  Future<bool> isTaskScheduled(String taskId);

  /// Handle a background task execution
  ///
  /// Called by the platform when a scheduled task fires.
  /// Returns true if the task completed successfully.
  Future<bool> handleTask(String taskId, Map<String, dynamic>? inputData);
}

// ============================================================================
// ANDROID: WorkManager Implementation
// ============================================================================

/// Callback for handling scheduled task execution in background isolate.
///
/// This is a TOP-LEVEL function as required by WorkManager.
/// It bootstraps minimal DI and delegates to the scheduler service.
@pragma('vm:entry-point')
void workManagerCallbackDispatcher() {
  wm.Workmanager().executeTask((taskName, inputData) async {
    try {
      AppLogging.automations(
        'WorkManager: Executing task \$taskName with data: \$inputData',
      );

      // Get the callback handler (set during app initialization)
      final handler = AndroidWorkManagerScheduler._taskHandler;
      if (handler != null) {
        final taskId = inputData?['taskId'] as String? ?? taskName;
        return await handler(taskId, inputData);
      }

      // If no handler is set, we're in a cold start scenario
      // Mark success but log that processing couldn't happen
      AppLogging.automations(
        'WorkManager: No task handler registered (cold start?)',
      );
      return true;
    } catch (e) {
      AppLogging.automations('WorkManager: Task execution error: $e');
      return false;
    }
  });
}

/// Android WorkManager implementation for background scheduling
///
/// Uses the workmanager package to schedule reliable background work.
/// WorkManager handles:
/// - Doze mode and app standby
/// - Network availability constraints
/// - Battery optimization
/// - Backoff and retry policies
class AndroidWorkManagerScheduler implements PlatformScheduler {
  /// Minimum interval enforced by WorkManager (15 minutes)
  static const minimumPeriodicInterval = Duration(minutes: 15);

  /// Handler function called when a background task fires
  static Future<bool> Function(String taskId, Map<String, dynamic>? inputData)?
  _taskHandler;

  /// Set the handler for background task execution
  ///
  /// Must be called during app initialization before any tasks fire.
  static void setTaskHandler(
    Future<bool> Function(String taskId, Map<String, dynamic>? inputData)
    handler,
  ) {
    _taskHandler = handler;
  }

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    await wm.Workmanager().initialize(
      workManagerCallbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    _initialized = true;
    AppLogging.automations('AndroidWorkManagerScheduler: Initialized');
  }

  @override
  Future<void> scheduleOneShot({
    required String taskId,
    required DateTime scheduledFor,
    Map<String, dynamic>? inputData,
  }) async {
    final now = DateTime.now();
    var delay = scheduledFor.difference(now);

    // Ensure non-negative delay
    if (delay.isNegative) {
      delay = Duration.zero;
    }

    final taskData = <String, dynamic>{
      'taskId': taskId,
      'scheduledFor': scheduledFor.toIso8601String(),
      ...?inputData,
    };

    await wm.Workmanager().registerOneOffTask(
      taskId,
      _workManagerOneShotTask,
      initialDelay: delay,
      inputData: taskData,
      existingWorkPolicy: wm.ExistingWorkPolicy.replace,
      constraints: wm.Constraints(networkType: wm.NetworkType.notRequired),
    );

    // Track scheduled task
    await _trackScheduledTask(taskId);

    AppLogging.automations(
      'AndroidWorkManagerScheduler: Scheduled one-shot task \$taskId '
      'for \${scheduledFor.toIso8601String()} (delay: \${delay.inSeconds}s)',
    );
  }

  @override
  Future<void> schedulePeriodic({
    required String taskId,
    required Duration interval,
    Map<String, dynamic>? inputData,
  }) async {
    // Enforce minimum interval
    final effectiveInterval = interval < minimumPeriodicInterval
        ? minimumPeriodicInterval
        : interval;

    if (interval < minimumPeriodicInterval) {
      AppLogging.automations(
        'AndroidWorkManagerScheduler: Interval \${interval.inMinutes}m < 15m, '
        'using minimum \${effectiveInterval.inMinutes}m',
      );
    }

    final taskData = <String, dynamic>{
      'taskId': taskId,
      'interval': effectiveInterval.inSeconds,
      ...?inputData,
    };

    await wm.Workmanager().registerPeriodicTask(
      taskId,
      _workManagerPeriodicTask,
      frequency: effectiveInterval,
      inputData: taskData,
      existingWorkPolicy: wm.ExistingPeriodicWorkPolicy.replace,
      constraints: wm.Constraints(networkType: wm.NetworkType.notRequired),
    );

    // Track scheduled task
    await _trackScheduledTask(taskId);

    AppLogging.automations(
      'AndroidWorkManagerScheduler: Scheduled periodic task \$taskId '
      'with interval \${effectiveInterval.inMinutes}m',
    );
  }

  @override
  Future<void> cancelTask(String taskId) async {
    await wm.Workmanager().cancelByUniqueName(taskId);
    await _untrackScheduledTask(taskId);

    AppLogging.automations(
      'AndroidWorkManagerScheduler: Cancelled task \$taskId',
    );
  }

  @override
  Future<void> cancelAllTasks() async {
    await wm.Workmanager().cancelAll();
    await _clearAllTrackedTasks();

    AppLogging.automations('AndroidWorkManagerScheduler: Cancelled all tasks');
  }

  @override
  Future<bool> isTaskScheduled(String taskId) async {
    // WorkManager doesn't have a direct query API
    // Use our persistent tracking
    final prefs = await SharedPreferences.getInstance();
    final tasks = prefs.getStringList(_scheduledTasksKey) ?? [];
    return tasks.contains(taskId);
  }

  @override
  Future<bool> handleTask(
    String taskId,
    Map<String, dynamic>? inputData,
  ) async {
    // This is called via the static handler mechanism
    // The actual implementation delegates to SchedulerBridge
    AppLogging.automations(
      'AndroidWorkManagerScheduler: handleTask called for \$taskId',
    );
    return true;
  }

  // ---- Task tracking helpers ----

  Future<void> _trackScheduledTask(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = prefs.getStringList(_scheduledTasksKey) ?? [];
    if (!tasks.contains(taskId)) {
      tasks.add(taskId);
      await prefs.setStringList(_scheduledTasksKey, tasks);
    }
  }

  Future<void> _untrackScheduledTask(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = prefs.getStringList(_scheduledTasksKey) ?? [];
    tasks.remove(taskId);
    await prefs.setStringList(_scheduledTasksKey, tasks);
  }

  Future<void> _clearAllTrackedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scheduledTasksKey);
  }
}

// ============================================================================
// iOS: Background Fetch Implementation
// ============================================================================

/// iOS BGTaskScheduler implementation using background_fetch
///
/// iOS has strict limitations on background execution:
/// - Minimum interval of ~15 minutes (system-determined)
/// - Limited execution time (~30 seconds)
/// - System can defer or skip tasks based on usage patterns
/// - One-shot scheduling is best-effort via fetch + local notifications
class IOSBGTaskScheduler implements PlatformScheduler {
  /// Minimum fetch interval (iOS enforces ~15 minutes minimum)
  static const minimumFetchInterval = Duration(minutes: 15);

  /// Handler function called when background fetch fires
  static Future<void> Function()? _fetchHandler;

  /// Notification plugin for exact-time UX
  final FlutterLocalNotificationsPlugin? _notifications;

  bool _initialized = false;

  IOSBGTaskScheduler({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications;

  /// Set the handler for background fetch events
  ///
  /// Must be called during app initialization.
  static void setFetchHandler(Future<void> Function() handler) {
    _fetchHandler = handler;
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    // Configure background fetch
    await bgf.BackgroundFetch.configure(
      bgf.BackgroundFetchConfig(
        minimumFetchInterval: 15, // minutes
        stopOnTerminate: false,
        startOnBoot: true,
        enableHeadless: true,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
        requiredNetworkType: bgf.NetworkType.NONE,
      ),
      _onBackgroundFetch,
      _onBackgroundFetchTimeout,
    );

    // Register headless task for iOS
    bgf.BackgroundFetch.registerHeadlessTask(_backgroundFetchHeadlessTask);

    _initialized = true;
    AppLogging.automations(
      'IOSBGTaskScheduler: Initialized with status \$status',
    );
  }

  /// Background fetch callback (when app is in memory)
  static void _onBackgroundFetch(String taskId) async {
    AppLogging.automations('IOSBGTaskScheduler: Fetch event for \$taskId');

    try {
      // Call the registered handler
      if (_fetchHandler != null) {
        await _fetchHandler!();
      }

      // Signal completion
      bgf.BackgroundFetch.finish(taskId);
    } catch (e) {
      AppLogging.automations('IOSBGTaskScheduler: Fetch error: \$e');
      bgf.BackgroundFetch.finish(taskId);
    }
  }

  /// Background fetch timeout callback
  static void _onBackgroundFetchTimeout(String taskId) {
    AppLogging.automations('IOSBGTaskScheduler: Timeout for \$taskId');
    bgf.BackgroundFetch.finish(taskId);
  }

  @override
  Future<void> scheduleOneShot({
    required String taskId,
    required DateTime scheduledFor,
    Map<String, dynamic>? inputData,
  }) async {
    // Strategy A: Store the target time and check on next fetch
    await _storeOneShotTime(taskId, scheduledFor);

    // Strategy B: Schedule a local notification for exact-time UX
    // This doesn't execute code but alerts the user
    if (_notifications != null) {
      await _scheduleLocalNotification(
        taskId: taskId,
        scheduledFor: scheduledFor,
        title: 'Scheduled Automation',
        body: 'Tap to run scheduled automation',
      );
    }

    // Track the task
    await _trackScheduledTask(taskId);

    AppLogging.automations(
      'IOSBGTaskScheduler: Scheduled one-shot \$taskId for '
      '\${scheduledFor.toIso8601String()}',
    );
  }

  @override
  Future<void> schedulePeriodic({
    required String taskId,
    required Duration interval,
    Map<String, dynamic>? inputData,
  }) async {
    // iOS background_fetch is global, not per-task
    // We just track that periodic scheduling is enabled
    // and let the fetch callback process all due schedules

    await _trackScheduledTask(taskId);

    // Start background fetch if not already running
    await bgf.BackgroundFetch.start();

    AppLogging.automations(
      'IOSBGTaskScheduler: Enabled periodic scheduling (taskId: \$taskId, '
      'requested interval: \${interval.inMinutes}m)',
    );
  }

  @override
  Future<void> cancelTask(String taskId) async {
    // Remove from tracked tasks
    await _untrackScheduledTask(taskId);

    // Remove stored one-shot time
    await _removeOneShotTime(taskId);

    // Cancel any associated local notification
    if (_notifications != null) {
      // Use taskId hash as notification ID
      final notificationId = taskId.hashCode.abs() % 0x7FFFFFFF;
      await _notifications.cancel(id: notificationId);
    }

    AppLogging.automations('IOSBGTaskScheduler: Cancelled task \$taskId');
  }

  @override
  Future<void> cancelAllTasks() async {
    // Clear all tracked tasks
    await _clearAllTrackedTasks();

    // Clear all one-shot times
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_iosOneShotTimesKey);

    // Cancel all local notifications for schedules
    if (_notifications != null) {
      await _notifications.cancelAll();
    }

    // Stop background fetch if no periodic schedules remain
    await bgf.BackgroundFetch.stop();

    AppLogging.automations('IOSBGTaskScheduler: Cancelled all tasks');
  }

  @override
  Future<bool> isTaskScheduled(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = prefs.getStringList(_scheduledTasksKey) ?? [];
    return tasks.contains(taskId);
  }

  @override
  Future<bool> handleTask(
    String taskId,
    Map<String, dynamic>? inputData,
  ) async {
    // Check if any one-shot tasks are due
    final dueTasks = await _getDueOneShotTasks();

    for (final dueTaskId in dueTasks) {
      AppLogging.automations(
        'IOSBGTaskScheduler: One-shot task \$dueTaskId is due',
      );
      await _removeOneShotTime(dueTaskId);
    }

    // The actual processing is done by the fetch handler
    // which delegates to SchedulerService
    return true;
  }

  /// Schedule a local notification for exact-time UX
  Future<void> _scheduleLocalNotification({
    required String taskId,
    required DateTime scheduledFor,
    required String title,
    required String body,
  }) async {
    if (_notifications == null) return;

    final now = DateTime.now();
    if (scheduledFor.isBefore(now)) return;

    // Use taskId hash as notification ID
    final notificationId = taskId.hashCode.abs() % 0x7FFFFFFF;

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const details = NotificationDetails(iOS: iosDetails);

    await _notifications.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledFor, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: taskId,
    );
  }

  // ---- One-shot time tracking ----

  Future<void> _storeOneShotTime(String taskId, DateTime scheduledFor) async {
    final prefs = await SharedPreferences.getInstance();
    final times = Map<String, String>.from(
      prefs.getString(_iosOneShotTimesKey) != null
          ? _parseTimesJson(prefs.getString(_iosOneShotTimesKey)!)
          : {},
    );
    times[taskId] = scheduledFor.toIso8601String();
    await prefs.setString(_iosOneShotTimesKey, _encodeTimesJson(times));
  }

  Future<void> _removeOneShotTime(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final timesStr = prefs.getString(_iosOneShotTimesKey);
    if (timesStr == null) return;

    final times = _parseTimesJson(timesStr);
    times.remove(taskId);
    await prefs.setString(_iosOneShotTimesKey, _encodeTimesJson(times));
  }

  Future<List<String>> _getDueOneShotTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final timesStr = prefs.getString(_iosOneShotTimesKey);
    if (timesStr == null) return [];

    final times = _parseTimesJson(timesStr);
    final now = DateTime.now();
    final dueTasks = <String>[];

    for (final entry in times.entries) {
      final scheduledFor = DateTime.tryParse(entry.value);
      if (scheduledFor != null && scheduledFor.isBefore(now)) {
        dueTasks.add(entry.key);
      }
    }

    return dueTasks;
  }

  Map<String, String> _parseTimesJson(String json) {
    try {
      // Simple key=value format
      final result = <String, String>{};
      for (final part in json.split(';')) {
        final kv = part.split('=');
        if (kv.length == 2) {
          result[kv[0]] = kv[1];
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  String _encodeTimesJson(Map<String, String> times) {
    return times.entries.map((e) => '\${e.key}=\${e.value}').join(';');
  }

  // ---- Task tracking helpers ----

  Future<void> _trackScheduledTask(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = prefs.getStringList(_scheduledTasksKey) ?? [];
    if (!tasks.contains(taskId)) {
      tasks.add(taskId);
      await prefs.setStringList(_scheduledTasksKey, tasks);
    }
  }

  Future<void> _untrackScheduledTask(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = prefs.getStringList(_scheduledTasksKey) ?? [];
    tasks.remove(taskId);
    await prefs.setStringList(_scheduledTasksKey, tasks);
  }

  Future<void> _clearAllTrackedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scheduledTasksKey);
  }
}

/// Headless task for iOS background execution
@pragma('vm:entry-point')
void _backgroundFetchHeadlessTask(bgf.HeadlessTask task) async {
  final taskId = task.taskId;
  AppLogging.automations('IOSBGTaskScheduler: Headless task \$taskId');

  try {
    // In headless mode, we can't access the full app state
    // Just mark the task as complete - actual processing happens when app resumes
    if (IOSBGTaskScheduler._fetchHandler != null) {
      await IOSBGTaskScheduler._fetchHandler!();
    }
  } catch (e) {
    AppLogging.automations('IOSBGTaskScheduler: Headless error: \$e');
  }

  bgf.BackgroundFetch.finish(taskId);
}

// ============================================================================
// SchedulerBridge: Unified interface
// ============================================================================

/// Bridge between InAppScheduler and PlatformScheduler
///
/// This class coordinates between the in-app scheduler (runs while app is
/// foregrounded) and platform schedulers (run in background). It ensures
/// schedules are registered with the appropriate platform scheduler when
/// the app goes to background.
///
/// Key responsibilities:
/// 1. Register schedules with both in-app and platform schedulers
/// 2. Sync state to platform when app backgrounds
/// 3. Process due schedules when platform wakes the app
/// 4. Use InAppScheduler's authoritative next-fire calculation
class SchedulerBridge {
  final InAppScheduler inAppScheduler;
  final PlatformScheduler? platformScheduler;

  /// Clock for time operations - allows testing with fake time
  final DateTime Function() _now;

  /// Whether platform scheduling is enabled
  bool _platformEnabled = true;

  SchedulerBridge({
    required this.inAppScheduler,
    this.platformScheduler,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  /// Enable or disable platform scheduling
  void setPlatformEnabled(bool enabled) {
    _platformEnabled = enabled;
    AppLogging.automations(
      'SchedulerBridge: Platform scheduling \${enabled ? "enabled" : "disabled"}',
    );
  }

  /// Initialize both schedulers
  Future<void> initialize() async {
    if (platformScheduler != null && _platformEnabled) {
      await platformScheduler!.initialize();

      // Set up platform task handlers
      if (Platform.isAndroid) {
        AndroidWorkManagerScheduler.setTaskHandler(_handlePlatformTask);
      } else if (Platform.isIOS) {
        IOSBGTaskScheduler.setFetchHandler(_handlePlatformFetch);
      }
    }

    AppLogging.automations('SchedulerBridge: Initialized');
  }

  /// Register a schedule with both schedulers
  Future<void> registerSchedule(ScheduleSpec spec) async {
    // Always register with in-app scheduler (single source of truth)
    inAppScheduler.register(spec);

    // If platform scheduler available, register for background execution
    if (platformScheduler != null && _platformEnabled && spec.enabled) {
      await _registerWithPlatform(spec);
    }
  }

  /// Unregister a schedule from both schedulers
  Future<void> unregisterSchedule(String scheduleId) async {
    inAppScheduler.unregister(scheduleId);

    if (platformScheduler != null) {
      await platformScheduler!.cancelTask(scheduleId);
    }
  }

  /// Sync platform scheduler with current in-app schedules
  ///
  /// Call this when app goes to background to ensure all schedules
  /// are registered with the platform scheduler.
  Future<void> syncToPlatform() async {
    if (platformScheduler == null || !_platformEnabled) {
      AppLogging.automations(
        'SchedulerBridge: syncToPlatform skipped (no platform scheduler)',
      );
      return;
    }

    AppLogging.automations('SchedulerBridge: Syncing to platform...');

    // Cancel all existing platform tasks to avoid duplicates
    await platformScheduler!.cancelAllTasks();

    // Register all active schedules
    final now = _now();

    for (final spec in inAppScheduler.schedules) {
      if (spec.enabled && spec.isActive(now)) {
        await _registerWithPlatform(spec);
      }
    }

    AppLogging.automations(
      'SchedulerBridge: Synced \$registered schedules to platform',
    );
  }

  /// Process due schedules when returning from background
  ///
  /// Call this when app resumes to process any missed schedules.
  void processOnResume() {
    final now = _now();
    inAppScheduler.tick(now);
    AppLogging.automations(
      'SchedulerBridge: Processed due schedules on resume',
    );
  }

  /// Handle platform task callback (Android WorkManager)
  Future<bool> _handlePlatformTask(
    String taskId,
    Map<String, dynamic>? inputData,
  ) async {
    AppLogging.automations('SchedulerBridge: Platform task fired: \$taskId');

    // Process all due schedules via the in-app scheduler
    // The in-app scheduler handles catch-up logic, deduplication, etc.
    final now = _now();
    inAppScheduler.tick(now);

    AppLogging.automations('SchedulerBridge: Platform task processed');

    // Persist state after processing
    await inAppScheduler.persist();

    // Re-sync to platform for daily/weekly schedules that need rescheduling
    await syncToPlatform();

    return true;
  }

  /// Handle platform fetch callback (iOS background_fetch)
  Future<void> _handlePlatformFetch() async {
    AppLogging.automations('SchedulerBridge: Platform fetch fired');

    // Process all due schedules via the in-app scheduler
    final now = _now();
    inAppScheduler.tick(now);

    AppLogging.automations('SchedulerBridge: Platform fetch processed');

    // Persist state after processing
    await inAppScheduler.persist();

    // Re-sync to platform for daily/weekly schedules that need rescheduling
    await syncToPlatform();
  }

  Future<void> _registerWithPlatform(ScheduleSpec spec) async {
    if (platformScheduler == null) return;

    final now = _now();

    switch (spec.kind) {
      case ScheduleKind.oneShot:
        if (spec.runAt != null && spec.runAt!.isAfter(now)) {
          await platformScheduler!.scheduleOneShot(
            taskId: spec.id,
            scheduledFor: spec.runAt!,
            inputData: {'scheduleId': spec.id},
          );
        }
        break;

      case ScheduleKind.interval:
        if (spec.every != null) {
          await platformScheduler!.schedulePeriodic(
            taskId: spec.id,
            interval: spec.every!,
            inputData: {'scheduleId': spec.id},
          );
        }
        break;

      case ScheduleKind.daily:
      case ScheduleKind.weekly:
        // For daily/weekly, use InAppScheduler's calculation for next fire time
        // This is the single source of truth for schedule timing
        final nextFireTime = inAppScheduler.computeNextOccurrence(spec, now);

        // Schedule if next fire time is at or after now (handles exact time matches)
        if (nextFireTime != null && !nextFireTime.isBefore(now)) {
          await platformScheduler!.scheduleOneShot(
            taskId: spec.id,
            scheduledFor: nextFireTime,
            inputData: {'scheduleId': spec.id},
          );
        }
        break;
    }
  }
}

/// Factory to create the appropriate platform scheduler for the current platform
PlatformScheduler? createPlatformScheduler({
  FlutterLocalNotificationsPlugin? notifications,
}) {
  if (Platform.isAndroid) {
    return AndroidWorkManagerScheduler();
  } else if (Platform.isIOS) {
    return IOSBGTaskScheduler(notifications: notifications);
  }
  return null;
}

/// Mock platform scheduler for testing
///
/// This implementation does nothing but tracks calls for verification.
class MockPlatformScheduler implements PlatformScheduler {
  final List<String> scheduledOneShotTasks = [];
  final List<String> scheduledPeriodicTasks = [];
  final List<String> cancelledTasks = [];
  bool allTasksCancelled = false;
  bool initialized = false;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> scheduleOneShot({
    required String taskId,
    required DateTime scheduledFor,
    Map<String, dynamic>? inputData,
  }) async {
    scheduledOneShotTasks.add(taskId);
  }

  @override
  Future<void> schedulePeriodic({
    required String taskId,
    required Duration interval,
    Map<String, dynamic>? inputData,
  }) async {
    scheduledPeriodicTasks.add(taskId);
  }

  @override
  Future<void> cancelTask(String taskId) async {
    cancelledTasks.add(taskId);
    scheduledOneShotTasks.remove(taskId);
    scheduledPeriodicTasks.remove(taskId);
  }

  @override
  Future<void> cancelAllTasks() async {
    allTasksCancelled = true;
    scheduledOneShotTasks.clear();
    scheduledPeriodicTasks.clear();
  }

  @override
  Future<bool> isTaskScheduled(String taskId) async {
    return scheduledOneShotTasks.contains(taskId) ||
        scheduledPeriodicTasks.contains(taskId);
  }

  @override
  Future<bool> handleTask(
    String taskId,
    Map<String, dynamic>? inputData,
  ) async {
    return true;
  }

  /// Reset all tracked state for testing
  void reset() {
    scheduledOneShotTasks.clear();
    scheduledPeriodicTasks.clear();
    cancelledTasks.clear();
    allTasksCancelled = false;
    initialized = false;
  }
}
