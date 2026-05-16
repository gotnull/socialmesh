// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/logging.dart';

import '../../models/mesh_models.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';

import '../../providers/cloud_sync_entitlement_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/glyph_provider.dart';
import '../../services/notifications/notification_service.dart';
import 'automation_debug_service.dart';
import 'automation_engine.dart';
import 'automation_history_presenter.dart';
import 'automation_repository.dart';
import 'models/automation.dart';
import 'models/schedule_spec.dart';
import 'platform_scheduler.dart';
import 'scheduler_service.dart';
import 'services/automation_database.dart';
import 'services/automation_sqlite_store.dart';
import 'services/automation_sync_service.dart';

// =============================================================================
// Storage Providers
// =============================================================================

/// Provides the Automation SQLite database instance.
final automationDatabaseProvider = Provider<AutomationDatabase>((ref) {
  final db = AutomationDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});

/// Provides an initialized AutomationSqliteStore instance.
///
/// The store is initialized once and shared across all providers.
final automationStoreProvider = FutureProvider<AutomationSqliteStore>((
  ref,
) async {
  final db = ref.watch(automationDatabaseProvider);
  final store = AutomationSqliteStore(db);
  await store.init();
  return store;
});

/// Provides the Automation Cloud Sync service.
///
/// Enabled/disabled based on the user's Cloud Sync entitlement.
final automationSyncServiceProvider = Provider<AutomationSyncService?>((ref) {
  final storeAsync = ref.watch(automationStoreProvider);
  final store = storeAsync.asData?.value;
  if (store == null) return null;

  final syncService = AutomationSyncService(store);

  // Watch cloud sync entitlement to enable/disable.
  final canWrite = ref.watch(canCloudSyncWriteProvider);
  syncService.setEnabled(canWrite);

  ref.onDispose(() async {
    await syncService.dispose();
  });

  return syncService;
});

/// Provider for the automation repository.
///
/// Hands out a stable repository instance for the lifetime of the provider.
/// The SQLite store is wired in via [ref.listen] when [automationStoreProvider]
/// resolves, so this provider does NOT rebuild when the store transitions
/// loading -> data. Rebuilding the repo on store resolution caused the
/// Quick Start flash on cold start (no-store repo briefly emitted an empty
/// list before the store-backed repo took over).
final automationRepositoryProvider = Provider<AutomationRepository>((ref) {
  final repository = AutomationRepository();

  ref.listen<AsyncValue<AutomationSqliteStore>>(automationStoreProvider, (
    prev,
    next,
  ) {
    next.whenData(repository.setStore);
  }, fireImmediately: true);

  return repository;
});

/// Provider for initializing the repository.
final automationRepositoryInitProvider = FutureProvider<AutomationRepository>((
  ref,
) async {
  // Ensure the store is initialized first
  await ref.read(automationStoreProvider.future);

  final repository = ref.read(automationRepositoryProvider);
  await repository.init();
  return repository;
});

/// Provider for the automation engine
/// NOTE: The engine must be initialized via automationEngineInitProvider before use
final automationEngineProvider = Provider<AutomationEngine>((ref) {
  final repository = ref.watch(automationRepositoryProvider);
  final iftttService = ref.watch(iftttServiceProvider);
  final protocol = ref.watch(protocolServiceProvider);
  final glyphService = ref.watch(glyphServiceProvider);

  // Get the notification plugin instance
  final notifications = FlutterLocalNotificationsPlugin();

  final engine = AutomationEngine(
    repository: repository,
    iftttService: iftttService,
    notifications: notifications,
    glyphService: glyphService,
    debugService: ref.watch(automationDebugServiceProvider),
    onGetMyNodeNum: () => ref.read(myNodeNumProvider),
    onGetPhonePosition: () async {
      try {
        final locationService = ref.read(locationServiceProvider);
        final position = await locationService.getCurrentPosition();
        if (position != null) {
          return (position.latitude, position.longitude);
        }
      } catch (e) {
        AppLogging.automations('Failed to get phone GPS position: $e');
      }
      return null;
    },
    onSendMessage: (nodeNum, message) async {
      try {
        await protocol.sendMessage(
          text: message,
          to: nodeNum,
          source: MessageSource.automation,
        );
        return true;
      } catch (e) {
        AppLogging.automations('Failed to send message to node $nodeNum: $e');
        return false;
      }
    },
    onSendToChannel: (channelIndex, message) async {
      try {
        // Channel 0 is broadcast, send to all nodes
        // Broadcast messages never receive ACKs, so wantAck must be false
        // to avoid the message being stuck in pending status forever.
        await protocol.sendMessage(
          text: message,
          to: 0xFFFFFFFF, // Broadcast address
          channel: channelIndex,
          wantAck: false,
          source: MessageSource.automation,
        );
        return true;
      } catch (e) {
        AppLogging.automations('Failed to send to channel $channelIndex: $e');
        return false;
      }
    },
  );

  // Subscribe to detection sensor events and forward to automation engine
  final detectionSensorSubscription = protocol.detectionSensorEventStream
      .listen((event) async {
        // Forward to automation engine
        engine.processDetectionSensorEvent(
          nodeNum: event.senderNodeId,
          sensorName: event.sensorName,
          detected: event.detected,
        );

        // Check if notifications are enabled and show one
        final prefs = await SharedPreferences.getInstance();
        final notificationsEnabled =
            prefs.getBool('enableDetectionNotifications') ?? false;

        if (notificationsEnabled) {
          // Get node name for display
          final nodes = ref.read(nodesProvider);
          final nodeName = nodes[event.senderNodeId]?.displayName;

          await NotificationService().showDetectionSensorNotification(
            sensorName: event.sensorName,
            detected: event.detected,
            nodeNum: event.senderNodeId,
            nodeName: nodeName,
          );
        }
      });

  ref.onDispose(() {
    engine.stop();
    detectionSensorSubscription.cancel();
  });

  return engine;
});

/// Provider for the InAppScheduler
///
/// This is the single source of truth for schedule timing and execution.
final inAppSchedulerProvider = Provider<InAppScheduler>((ref) {
  final repository = ref.read(automationRepositoryProvider);

  final scheduler = InAppScheduler(
    onPersist: (schedules) => repository.persistSchedules(schedules),
    onLoad: () => repository.loadSchedules(),
  );

  ref.onDispose(() {
    scheduler.dispose();
  });

  return scheduler;
});

/// Provider for the PlatformScheduler (Android WorkManager / iOS background_fetch)
final platformSchedulerProvider = Provider<PlatformScheduler?>((ref) {
  final notifications = FlutterLocalNotificationsPlugin();
  return createPlatformScheduler(notifications: notifications);
});

/// Provider for the SchedulerBridge
///
/// Coordinates between InAppScheduler and platform schedulers.
final schedulerBridgeProvider = Provider<SchedulerBridge>((ref) {
  final inAppScheduler = ref.read(inAppSchedulerProvider);
  final platformScheduler = ref.read(platformSchedulerProvider);

  return SchedulerBridge(
    inAppScheduler: inAppScheduler,
    platformScheduler: platformScheduler,
  );
});

/// Provider for initializing the SchedulerBridge
final schedulerBridgeInitProvider = FutureProvider<SchedulerBridge>((
  ref,
) async {
  final bridge = ref.read(schedulerBridgeProvider);

  // Initialize platform scheduler (registers callbacks)
  await bridge.initialize();

  // Resync schedules from storage
  await bridge.inAppScheduler.resyncFromStore();

  // Start the in-app scheduler
  bridge.inAppScheduler.start();

  AppLogging.automations('SchedulerBridge: Fully initialized');

  return bridge;
});

/// Provider for initializing the automation engine
/// This ensures the repository is initialized and the engine is started
final automationEngineInitProvider = FutureProvider<AutomationEngine>((
  ref,
) async {
  // First, ensure the repository is initialized
  await ref.read(automationRepositoryInitProvider.future);

  // Initialize the scheduler bridge (includes platform scheduler)
  final bridge = await ref.read(schedulerBridgeInitProvider.future);

  // Get the engine (repository is now initialized)
  final engine = ref.read(automationEngineProvider);

  // Wire up the scheduler to the engine
  engine.setScheduler(bridge.inAppScheduler);

  // Start the engine (for silent node monitoring, etc.)
  engine.start();

  AppLogging.automations('AutomationEngine: Initialized and started');

  return engine;
});

/// Provider for the list of automations
final automationsProvider =
    NotifierProvider<AutomationsNotifier, AsyncValue<List<Automation>>>(
      AutomationsNotifier.new,
    );

/// State notifier for automations
class AutomationsNotifier extends Notifier<AsyncValue<List<Automation>>> {
  int _emitCount = 0;

  void _emit(AsyncValue<List<Automation>> next, String reason) {
    _emitCount++;
    final desc = next.when(
      data: (list) => 'data(${list.length})',
      loading: () => 'loading',
      error: (e, _) => 'error($e)',
    );
    AppLogging.automations('#$_emitCount emit -> $desc via $reason');
    state = next;
  }

  @override
  AsyncValue<List<Automation>> build() {
    AppLogging.automations(
      'build() entered (notifier id=${identityHashCode(this)})',
    );
    // Repository is now lifetime-stable (see automationRepositoryProvider).
    // build() runs once per notifier lifetime — no churn on store / sync /
    // entitlement resolution. That keeps the UI from flashing Quick Start
    // templates while the cold-start providers settle.
    final repository = ref.read(automationRepositoryProvider);
    repository.addListener(_onRepositoryChanged);

    // Sync service is wired via listen, not watch — its rebuilds (entitlement
    // changes, store resolution) must not retrigger AutomationsNotifier.build.
    ref.listen<AutomationSyncService?>(automationSyncServiceProvider, (
      prev,
      next,
    ) {
      AppLogging.automations(
        'syncService listen fired '
        '(prev=${prev != null}, next=${next != null})',
      );
      next?.onPullApplied = (appliedCount) {
        if (!ref.mounted) return;
        _emit(
          AsyncValue.data(_repository.automations),
          'onPullApplied(applied=$appliedCount, repoCount=${_repository.automations.length})',
        );
      };
    }, fireImmediately: true);

    // One-time safety net: if the profile still has automationsJson from
    // the old blob-sync approach, import it into SQLite (only if empty).
    ref.listen<AsyncValue<UserProfile?>>(userProfileProvider, (
      prev,
      next,
    ) async {
      try {
        final profile = next.value;
        final cloudJson = profile?.preferences?.automationsJson;
        if (cloudJson != null && cloudJson.isNotEmpty) {
          await repository.importFromCloudPrefsIfEmpty(cloudJson);
        }
      } catch (e) {
        AppLogging.automations(
          'Error importing automations from cloud prefs: $e',
        );
      }
    });

    ref.onDispose(() {
      AppLogging.automations(
        'notifier disposed (id=${identityHashCode(this)})',
      );
      repository.removeListener(_onRepositoryChanged);
    });

    _loadAutomations();
    AppLogging.automations('build() returning initial AsyncValue.loading()');
    return const AsyncValue.loading();
  }

  AutomationRepository get _repository =>
      ref.read(automationRepositoryProvider);

  void _onRepositoryChanged() {
    final list = _repository.automations;
    _emit(
      AsyncValue.data(list),
      '_onRepositoryChanged(repoCount=${list.length})',
    );
    // Also bump the log revision so automationLogProvider rebuilds
    // when new execution log entries are added by the engine.
    ref.read(_logRevisionProvider.notifier).bump();
  }

  Future<void> _loadAutomations() async {
    AppLogging.automations('_loadAutomations() start, awaiting store');
    try {
      // Wait for the SQLite store before initing the repository, so we never
      // emit an empty list from the legacy SharedPreferences fallback path
      // while the store is still resolving.
      await ref.read(automationStoreProvider.future);
      AppLogging.automations('_loadAutomations() store ready, calling init');
      await _repository.init();
      AppLogging.automations(
        '_loadAutomations() init complete, '
        'repoCount=${_repository.automations.length}',
      );
      _emit(AsyncValue.data(_repository.automations), '_loadAutomations()');
    } catch (e, st) {
      _emit(AsyncValue.error(e, st), '_loadAutomations() error');
    }
  }

  Future<void> refresh() async {
    await _loadAutomations();
  }

  /// Drain the sync outbox immediately after a local mutation.
  void _drainOutbox() {
    final syncService = ref.read(automationSyncServiceProvider);
    syncService?.drainOutboxNow();
  }

  Future<void> addAutomation(Automation automation) async {
    await _repository.addAutomation(automation);
    state = AsyncValue.data(_repository.automations);
    _drainOutbox();

    // Register schedule if this is a scheduled trigger
    if (automation.enabled &&
        automation.trigger.type == TriggerType.scheduled) {
      await _registerSchedule(automation);
    }
  }

  Future<void> updateAutomation(Automation automation) async {
    // Unregister old schedule first (if any)
    await _unregisterSchedule(automation.id);

    await _repository.updateAutomation(automation);
    state = AsyncValue.data(_repository.automations);
    _drainOutbox();

    // Register new schedule if enabled and scheduled
    if (automation.enabled &&
        automation.trigger.type == TriggerType.scheduled) {
      await _registerSchedule(automation);
    }
  }

  Future<void> deleteAutomation(String id) async {
    // Unregister schedule before deleting
    await _unregisterSchedule(id);

    await _repository.deleteAutomation(id);
    state = AsyncValue.data(_repository.automations);
    _drainOutbox();
  }

  Future<void> toggleAutomation(String id, bool enabled) async {
    final automation = _repository.automations.firstWhereOrNull(
      (a) => a.id == id,
    );

    await _repository.toggleAutomation(id, enabled);
    state = AsyncValue.data(_repository.automations);
    _drainOutbox();

    // Handle schedule registration/unregistration
    if (automation?.trigger.type == TriggerType.scheduled) {
      if (enabled) {
        final updated = _repository.automations.firstWhereOrNull(
          (a) => a.id == id,
        );
        if (updated != null) {
          await _registerSchedule(updated);
        }
      } else {
        await _unregisterSchedule(id);
      }
    }
  }

  /// Register a scheduled automation with the platform scheduler
  Future<void> _registerSchedule(Automation automation) async {
    final scheduleSpec = _createScheduleSpec(automation);
    if (scheduleSpec == null) {
      AppLogging.automations(
        'Failed to create ScheduleSpec for automation ${automation.id}',
      );
      return;
    }

    try {
      final bridge = ref.read(schedulerBridgeProvider);
      await bridge.registerSchedule(scheduleSpec);
      AppLogging.automations(
        'Registered schedule for automation ${automation.id}: ${scheduleSpec.id}',
      );
    } catch (e) {
      AppLogging.automations('Failed to register schedule: $e');
    }
  }

  /// Unregister a scheduled automation from the platform scheduler
  Future<void> _unregisterSchedule(String automationId) async {
    try {
      final bridge = ref.read(schedulerBridgeProvider);
      // Schedule ID matches automation ID for direct lookup
      await bridge.unregisterSchedule(automationId);
      AppLogging.automations(
        'Unregistered schedule for automation $automationId',
      );
    } catch (e) {
      AppLogging.automations('Failed to unregister schedule: $e');
    }
  }

  /// Create a ScheduleSpec from automation trigger config
  ScheduleSpec? _createScheduleSpec(Automation automation) {
    final config = automation.trigger.config;
    final scheduleType = config['scheduleType'] as String? ?? 'daily';
    final hour = config['hour'] as int? ?? 9;
    final minute = config['minute'] as int? ?? 0;

    switch (scheduleType) {
      case 'daily':
        return ScheduleSpec.daily(
          id: automation.id,
          hour: hour,
          minute: minute,
        );

      case 'weekly':
        final daysOfWeek =
            (config['daysOfWeek'] as List<dynamic>?)?.cast<int>() ??
            [DateTime.monday];
        return ScheduleSpec.weekly(
          id: automation.id,
          hour: hour,
          minute: minute,
          daysOfWeek: daysOfWeek,
        );

      case 'interval':
        final intervalMinutes = config['intervalMinutes'] as int? ?? 60;
        // Anchor the interval to the configured hour/minute so that fire
        // times align to deterministic slots (e.g. 09:00, 10:00, 11:00…)
        // instead of drifting relative to app-start time.
        final now = DateTime.now();
        var anchor = DateTime(now.year, now.month, now.day, hour, minute);
        // If today's anchor is in the future, use yesterday's so the first
        // interval fires at the next aligned slot.
        if (anchor.isAfter(now)) {
          anchor = anchor.subtract(const Duration(days: 1));
        }
        return ScheduleSpec.interval(
          id: automation.id,
          every: Duration(minutes: intervalMinutes),
          startAt: anchor,
          catchUpPolicy: CatchUpPolicy.lastOnly,
        );

      default:
        AppLogging.automations('Unknown schedule type: $scheduleType');
        return null;
    }
  }

  /// Clear all execution log entries and refresh provider state.
  Future<void> clearExecutionLog() async {
    await _repository.clearLog();
    ref.read(_logRevisionProvider.notifier).bump();
  }

  Future<void> addFromTemplate(String templateId) async {
    final automation = AutomationRepository.createTemplate(templateId);
    await addAutomation(automation);
  }
}

/// Revision counter that forces [automationLogProvider] to rebuild when bumped.
final _logRevisionProvider = NotifierProvider<_LogRevision, int>(
  _LogRevision.new,
);

class _LogRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Provider for automation execution log
final automationLogProvider = Provider<List<AutomationLogEntry>>((ref) {
  // Watch the revision counter so that clearing the log (which bumps the
  // counter) forces dependents to see the updated (empty) list.
  ref.watch(_logRevisionProvider);
  final repository = ref.watch(automationRepositoryProvider);
  return repository.log;
});

/// Provider for enabled automations count
final enabledAutomationsCountProvider = Provider<int>((ref) {
  final automations = ref.watch(automationsProvider);
  return automations.whenOrNull(
        data: (list) => list.where((a) => a.enabled).length,
      ) ??
      0;
});

/// Provider for automation stats
final automationStatsProvider = Provider<AutomationStats>((ref) {
  final automations = ref.watch(automationsProvider);
  final log = ref.watch(automationLogProvider);

  return automations.when(
    data: (list) => AutomationStats(
      total: list.length,
      enabled: list.where((a) => a.enabled).length,
      totalTriggers: list.fold(0, (sum, a) => sum + a.triggerCount),
      recentExecutions: log.take(10).toList(),
    ),
    loading: () => const AutomationStats(),
    error: (e, s) => const AutomationStats(),
  );
});

/// Automation statistics
class AutomationStats {
  final int total;
  final int enabled;
  final int totalTriggers;
  final List<AutomationLogEntry> recentExecutions;

  const AutomationStats({
    this.total = 0,
    this.enabled = 0,
    this.totalTriggers = 0,
    this.recentExecutions = const [],
  });
}

/// Provider for the automation debug service
final automationDebugServiceProvider = Provider<AutomationDebugService>((ref) {
  return AutomationDebugService();
});

/// Provider for debug evaluations (reactive)
final automationDebugEvaluationsProvider = Provider<List<AutomationEvaluation>>(
  (ref) {
    final debugService = ref.watch(automationDebugServiceProvider);
    return debugService.evaluations;
  },
);

/// Provider for merged automation history (persisted logs + in-memory skips).
final automationHistoryProvider = Provider<List<AutomationHistoryEntry>>((ref) {
  ref.watch(_logRevisionProvider);
  final log = ref.watch(automationLogProvider);
  final evaluations = ref.watch(automationDebugEvaluationsProvider);
  return AutomationHistoryMerger.merge(
    logEntries: log,
    evaluations: evaluations,
  );
});

/// Provider for a single automation's history.
final automationHistoryByIdProvider =
    Provider.family<List<AutomationHistoryEntry>, String>((ref, automationId) {
      ref.watch(_logRevisionProvider);
      final log = ref.watch(automationLogProvider);
      final evaluations = ref.watch(automationDebugEvaluationsProvider);
      return AutomationHistoryMerger.merge(
        logEntries: log,
        evaluations: evaluations,
        automationId: automationId,
      );
    });
