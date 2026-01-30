import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/logging.dart';

import '../../models/mesh_models.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/glyph_provider.dart';
import '../../services/notifications/notification_service.dart';
import 'automation_debug_service.dart';
import 'automation_engine.dart';
import 'automation_repository.dart';
import 'models/automation.dart';

/// Provider for the automation repository
final automationRepositoryProvider = Provider<AutomationRepository>((ref) {
  return AutomationRepository();
});

/// Provider for initializing the repository
final automationRepositoryInitProvider = FutureProvider<AutomationRepository>((
  ref,
) async {
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
        await protocol.sendMessage(
          text: message,
          to: 0xFFFFFFFF, // Broadcast address
          channel: channelIndex,
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
  final detectionSensorSubscription =
      protocol.detectionSensorEventStream.listen((event) async {
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

/// Provider for initializing the automation engine
/// This ensures the repository is initialized and the engine is started
final automationEngineInitProvider = FutureProvider<AutomationEngine>((
  ref,
) async {
  // First, ensure the repository is initialized
  await ref.read(automationRepositoryInitProvider.future);

  // Get the engine (repository is now initialized)
  final engine = ref.read(automationEngineProvider);

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
  @override
  AsyncValue<List<Automation>> build() {
    final repository = ref.watch(automationRepositoryProvider);
    repository.addListener(_onRepositoryChanged);

    // Watch the current user profile and restore automations from cloud prefs
    // whenever the profile changes (sign-in / sign-out / profile update).
    ref.listen<AsyncValue<UserProfile?>>(userProfileProvider, (
      prev,
      next,
    ) async {
      try {
        final profile = next.value;
        final cloudJson = profile?.preferences?.automationsJson;
        if (cloudJson != null && cloudJson.isNotEmpty) {
          // Avoid unnecessary loads if already identical
          if (repository.toJsonString() != cloudJson) {
            await repository.loadFromJson(cloudJson);
            AppLogging.automations(
              'Automations restored from cloud preferences',
            );
          }
        }
      } catch (e) {
        AppLogging.automations('Error restoring automations from cloud: $e');
      }
    });

    ref.onDispose(() {
      repository.removeListener(_onRepositoryChanged);
    });

    _loadAutomations();
    return const AsyncValue.loading();
  }

  AutomationRepository get _repository =>
      ref.read(automationRepositoryProvider);

  void _onRepositoryChanged() {
    // Update state with latest automations when repository changes
    state = AsyncValue.data(_repository.automations);
  }

  Future<void> _loadAutomations() async {
    try {
      await _repository.init();
      state = AsyncValue.data(_repository.automations);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadAutomations();
  }

  /// Sync automations to cloud
  Future<void> _syncToCloud() async {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      try {
        await ref
            .read(userProfileProvider.notifier)
            .updatePreferences(
              UserPreferences(automationsJson: _repository.toJsonString()),
            );
        AppLogging.automations('Synced automations to cloud');
      } catch (e) {
        AppLogging.automations('Failed to sync automations to cloud: $e');
      }
    }
  }

  Future<void> addAutomation(Automation automation) async {
    await _repository.addAutomation(automation);
    state = AsyncValue.data(_repository.automations);
    await _syncToCloud();
  }

  Future<void> updateAutomation(Automation automation) async {
    await _repository.updateAutomation(automation);
    state = AsyncValue.data(_repository.automations);
    await _syncToCloud();
  }

  Future<void> deleteAutomation(String id) async {
    await _repository.deleteAutomation(id);
    state = AsyncValue.data(_repository.automations);
    await _syncToCloud();
  }

  Future<void> toggleAutomation(String id, bool enabled) async {
    await _repository.toggleAutomation(id, enabled);
    state = AsyncValue.data(_repository.automations);
    await _syncToCloud();
  }

  Future<void> addFromTemplate(String templateId) async {
    final automation = AutomationRepository.createTemplate(templateId);
    await addAutomation(automation);
  }
}

/// Provider for automation execution log
final automationLogProvider = Provider<List<AutomationLogEntry>>((ref) {
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
