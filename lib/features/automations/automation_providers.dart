import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

import '../../providers/app_providers.dart';
import 'automation_engine.dart';
import 'automation_repository.dart';
import 'models/automation.dart';

/// Provider for the automation repository (ChangeNotifier for reactive updates)
final automationRepositoryProvider =
    ChangeNotifierProvider<AutomationRepository>((ref) {
      final repository = AutomationRepository();
      return repository;
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

  // Get the notification plugin instance
  final notifications = FlutterLocalNotificationsPlugin();

  final engine = AutomationEngine(
    repository: repository,
    iftttService: iftttService,
    notifications: notifications,
  );

  ref.onDispose(() {
    engine.stop();
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

  debugPrint('AutomationEngine: Initialized and started');

  return engine;
});

/// Provider for the list of automations
final automationsProvider =
    StateNotifierProvider<AutomationsNotifier, AsyncValue<List<Automation>>>((
      ref,
    ) {
      final repository = ref.watch(automationRepositoryProvider);
      return AutomationsNotifier(repository, ref);
    });

/// State notifier for automations
class AutomationsNotifier extends StateNotifier<AsyncValue<List<Automation>>> {
  final AutomationRepository _repository;

  AutomationsNotifier(this._repository, Ref ref)
    : super(const AsyncValue.loading()) {
    _loadAutomations();
    // Listen to repository changes (e.g., from engine recordTrigger)
    _repository.addListener(_onRepositoryChanged);
  }

  void _onRepositoryChanged() {
    // Update state with latest automations when repository changes
    if (mounted) {
      state = AsyncValue.data(_repository.automations);
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
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

  Future<void> addAutomation(Automation automation) async {
    await _repository.addAutomation(automation);
    state = AsyncValue.data(_repository.automations);
  }

  Future<void> updateAutomation(Automation automation) async {
    await _repository.updateAutomation(automation);
    state = AsyncValue.data(_repository.automations);
  }

  Future<void> deleteAutomation(String id) async {
    await _repository.deleteAutomation(id);
    state = AsyncValue.data(_repository.automations);
  }

  Future<void> toggleAutomation(String id, bool enabled) async {
    await _repository.toggleAutomation(id, enabled);
    state = AsyncValue.data(_repository.automations);
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
