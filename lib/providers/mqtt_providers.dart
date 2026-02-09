// SPDX-License-Identifier: GPL-3.0-or-later

/// Riverpod 3.x providers for the Global Layer (MQTT) feature.
///
/// These providers manage the reactive state for:
/// - [GlobalLayerConfig] — broker settings, privacy toggles, topics
/// - [GlobalLayerConnectionState] — connection state machine
/// - [GlobalLayerMetrics] — health metrics and throughput
/// - [GlobalLayerSecureStorage] — persistence layer
///
/// All providers follow Riverpod 3.x patterns:
/// - [Notifier] / [AsyncNotifier] instead of StateNotifier
/// - [NotifierProvider] / [AsyncNotifierProvider] instead of StateNotifierProvider
/// - ref.watch in builds, ref.read in callbacks
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../core/mqtt/mqtt_config.dart';
import '../core/mqtt/mqtt_connection_state.dart';

import '../core/mqtt/mqtt_diagnostics.dart';
import '../core/mqtt/mqtt_metrics.dart';
import '../core/mqtt/mqtt_secure_storage.dart';

// ---------------------------------------------------------------------------
// Secure storage provider (singleton)
// ---------------------------------------------------------------------------

/// Provides the [GlobalLayerSecureStorage] singleton for persisting
/// Global Layer config and credentials.
final globalLayerStorageProvider = Provider<GlobalLayerSecureStorage>((ref) {
  return GlobalLayerSecureStorage();
});

// ---------------------------------------------------------------------------
// Config provider
// ---------------------------------------------------------------------------

/// Notifier that manages the [GlobalLayerConfig] state.
///
/// Config is loaded asynchronously from storage on first access.
/// All mutations are persisted automatically.
class GlobalLayerConfigNotifier extends AsyncNotifier<GlobalLayerConfig> {
  @override
  Future<GlobalLayerConfig> build() async {
    final storage = ref.read(globalLayerStorageProvider);
    final config = await storage.loadConfig();
    AppLogging.settings(
      'GlobalLayer: config provider initialized '
      '(enabled: ${config.enabled}, setup: ${config.setupComplete})',
    );
    return config;
  }

  /// Updates the config and persists it to storage.
  ///
  /// This is the primary mutation method. All config changes should
  /// go through this to ensure persistence and state consistency.
  Future<void> updateConfig(GlobalLayerConfig config) async {
    final storage = ref.read(globalLayerStorageProvider);
    final timestamped = config.copyWith(lastModifiedAt: DateTime.now());
    await storage.saveConfig(timestamped);
    state = AsyncData(timestamped);
    AppLogging.settings(
      'GlobalLayer: config updated (host: ${config.host}, '
      'enabled: ${config.enabled})',
    );
  }

  /// Updates a single field via a transform function.
  ///
  /// Usage:
  /// ```dart
  /// ref.read(globalLayerConfigProvider.notifier).transform(
  ///   (config) => config.copyWith(enabled: true),
  /// );
  /// ```
  Future<void> transform(
    GlobalLayerConfig Function(GlobalLayerConfig current) fn,
  ) async {
    final current = state.value ?? GlobalLayerConfig.initial;
    await updateConfig(fn(current));
  }

  /// Enables the Global Layer feature.
  Future<void> enable() async {
    await transform((c) => c.copyWith(enabled: true));
  }

  /// Disables the Global Layer feature (pause).
  Future<void> disable() async {
    await transform((c) => c.copyWith(enabled: false));
  }

  /// Marks the setup wizard as completed and enables the feature.
  Future<void> completeSetup(GlobalLayerConfig config) async {
    final storage = ref.read(globalLayerStorageProvider);
    final finalConfig = config.copyWith(
      setupComplete: true,
      enabled: true,
      lastModifiedAt: DateTime.now(),
    );
    await storage.saveConfig(finalConfig);
    await storage.markSetupComplete();
    state = AsyncData(finalConfig);
    AppLogging.settings('GlobalLayer: setup completed');
  }

  /// Resets the Global Layer to its initial state, clearing all
  /// configuration and credentials.
  Future<void> reset() async {
    final storage = ref.read(globalLayerStorageProvider);
    await storage.clearAll();
    state = const AsyncData(GlobalLayerConfig.initial);

    // Also reset connection state and metrics
    ref.read(globalLayerConnectionStateProvider.notifier).reset();
    ref.read(globalLayerMetricsProvider.notifier).reset();

    AppLogging.settings('GlobalLayer: config reset to initial state');
  }

  /// Updates the privacy settings.
  Future<void> updatePrivacy(GlobalLayerPrivacySettings privacy) async {
    await transform((c) => c.copyWith(privacy: privacy));
  }

  /// Toggles a specific topic subscription on or off.
  Future<void> toggleSubscription(int index, {required bool enabled}) async {
    final current = state.value;
    if (current == null) return;
    if (index < 0 || index >= current.subscriptions.length) return;

    final sub = current.subscriptions[index].copyWith(enabled: enabled);
    await updateConfig(current.withSubscription(index, sub));
  }

  /// Records a successful connection timestamp.
  Future<void> recordConnection() async {
    await transform((c) => c.copyWith(lastConnectedAt: DateTime.now()));
  }
}

/// Async provider for the Global Layer configuration.
///
/// Loads from storage on first access, then provides synchronous
/// updates via [GlobalLayerConfigNotifier].
final globalLayerConfigProvider =
    AsyncNotifierProvider<GlobalLayerConfigNotifier, GlobalLayerConfig>(
      GlobalLayerConfigNotifier.new,
    );

// ---------------------------------------------------------------------------
// Connection state provider
// ---------------------------------------------------------------------------

/// Notifier that manages the [GlobalLayerConnectionState] with
/// validated transitions via [GlobalLayerStateMachine].
class GlobalLayerConnectionStateNotifier
    extends Notifier<GlobalLayerConnectionState> {
  @override
  GlobalLayerConnectionState build() {
    return GlobalLayerConnectionState.disabled;
  }

  /// Attempts to transition to [target].
  ///
  /// Returns `true` if the transition was valid and applied.
  /// Returns `false` and logs a warning if the transition is invalid.
  bool transitionTo(
    GlobalLayerConnectionState target, {
    String? reason,
    String? errorMessage,
  }) {
    final current = state;

    if (current == target) {
      return false; // No-op for same state
    }

    final error = GlobalLayerStateMachine.transitionError(current, target);
    if (error != null) {
      AppLogging.settings('GlobalLayer: rejected transition — $error');
      return false;
    }

    // Record the transition for diagnostics
    final transition = GlobalLayerStateTransition(
      from: current,
      to: target,
      timestamp: DateTime.now(),
      reason: reason,
      errorMessage: errorMessage,
    );

    // Add to transition history
    ref.read(_transitionHistoryProvider.notifier).addTransition(transition);

    state = target;
    AppLogging.settings(
      'GlobalLayer: ${current.name} -> ${target.name}'
      '${reason != null ? ' ($reason)' : ''}',
    );

    return true;
  }

  /// Resets the connection state to [disabled].
  ///
  /// This bypasses the state machine validation and is only used
  /// during full config reset.
  void reset() {
    state = GlobalLayerConnectionState.disabled;
    AppLogging.settings('GlobalLayer: connection state reset to disabled');
  }

  /// Convenience method: transition to connecting.
  bool connect({String? reason}) {
    return transitionTo(
      GlobalLayerConnectionState.connecting,
      reason: reason ?? 'User initiated connect',
    );
  }

  /// Convenience method: transition to disconnecting.
  bool disconnect({String? reason}) {
    return transitionTo(
      GlobalLayerConnectionState.disconnecting,
      reason: reason ?? 'User initiated disconnect',
    );
  }

  /// Convenience method: mark connection as established.
  bool markConnected({String? reason}) {
    return transitionTo(
      GlobalLayerConnectionState.connected,
      reason: reason ?? 'Connection established',
    );
  }

  /// Convenience method: mark connection as degraded.
  bool markDegraded({String? reason}) {
    return transitionTo(
      GlobalLayerConnectionState.degraded,
      reason: reason ?? 'Connection degraded',
    );
  }

  /// Convenience method: mark an error.
  bool markError({required String errorMessage, String? reason}) {
    return transitionTo(
      GlobalLayerConnectionState.error,
      reason: reason ?? 'Error occurred',
      errorMessage: errorMessage,
    );
  }

  /// Convenience method: transition to reconnecting.
  bool startReconnecting({String? reason}) {
    return transitionTo(
      GlobalLayerConnectionState.reconnecting,
      reason: reason ?? 'Attempting to reconnect',
    );
  }

  /// Convenience method: transition to disconnected (from any valid state).
  bool markDisconnected({String? reason}) {
    return transitionTo(
      GlobalLayerConnectionState.disconnected,
      reason: reason ?? 'Disconnected',
    );
  }
}

/// Provider for the Global Layer connection state.
final globalLayerConnectionStateProvider =
    NotifierProvider<
      GlobalLayerConnectionStateNotifier,
      GlobalLayerConnectionState
    >(GlobalLayerConnectionStateNotifier.new);

// ---------------------------------------------------------------------------
// Transition history provider
// ---------------------------------------------------------------------------

/// Notifier that maintains a bounded list of recent state transitions
/// for diagnostics and the status panel.
class _TransitionHistoryNotifier
    extends Notifier<List<GlobalLayerStateTransition>> {
  /// Maximum number of transitions to retain.
  static const int _maxHistory = 100;

  @override
  List<GlobalLayerStateTransition> build() => const [];

  void addTransition(GlobalLayerStateTransition transition) {
    final updated = [...state, transition];
    if (updated.length > _maxHistory) {
      state = updated.sublist(updated.length - _maxHistory);
    } else {
      state = updated;
    }
  }

  void clear() {
    state = const [];
  }
}

final _transitionHistoryProvider =
    NotifierProvider<
      _TransitionHistoryNotifier,
      List<GlobalLayerStateTransition>
    >(_TransitionHistoryNotifier.new);

/// Public read-only access to the transition history.
final globalLayerTransitionHistoryProvider =
    Provider<List<GlobalLayerStateTransition>>((ref) {
      return ref.watch(_transitionHistoryProvider);
    });

// ---------------------------------------------------------------------------
// Metrics provider
// ---------------------------------------------------------------------------

/// Notifier that manages [GlobalLayerMetrics] for the status panel.
class GlobalLayerMetricsNotifier extends Notifier<GlobalLayerMetrics> {
  @override
  GlobalLayerMetrics build() => GlobalLayerMetrics.empty;

  /// Records a throughput sample (inbound or outbound message).
  void recordSample(ThroughputSample sample) {
    state = state.recordSample(sample);
  }

  /// Records a ping response.
  void recordPing(int roundTripMs) {
    state = state.recordPing(roundTripMs);
  }

  /// Records a connection error.
  void recordError(ConnectionErrorRecord error) {
    state = state.recordError(error);
    AppLogging.settings(
      'GlobalLayer: error recorded — ${error.type.displayLabel}: '
      '${error.message}',
    );
  }

  /// Increments the reconnect counter.
  void incrementReconnectCount() {
    state = state.incrementReconnectCount();
  }

  /// Starts a new metrics session (called on successful connect).
  void startSession() {
    state = state.startSession();
  }

  /// Ends the current metrics session (called on disconnect).
  void endSession() {
    state = state.endSession();
  }

  /// Clears all error history.
  void clearErrors() {
    state = state.clearErrors();
  }

  /// Resets metrics to empty state.
  void reset() {
    state = GlobalLayerMetrics.empty;
  }
}

/// Provider for Global Layer health metrics.
final globalLayerMetricsProvider =
    NotifierProvider<GlobalLayerMetricsNotifier, GlobalLayerMetrics>(
      GlobalLayerMetricsNotifier.new,
    );

// ---------------------------------------------------------------------------
// Diagnostics provider
// ---------------------------------------------------------------------------

/// Notifier that manages the diagnostics report state.
///
/// The diagnostics flow is driven by the UI — each check is executed
/// sequentially, and results are pushed into this provider. The
/// actual network checks are performed by a service layer, not here.
class GlobalLayerDiagnosticsNotifier extends Notifier<DiagnosticReport?> {
  @override
  DiagnosticReport? build() => null;

  /// Initializes a new diagnostics run with all checks in pending state.
  void startRun({
    required bool tlsEnabled,
    GlobalLayerConnectionState connectionState =
        GlobalLayerConnectionState.disconnected,
    Map<String, dynamic>? configSnapshot,
  }) {
    state = DiagnosticReport.initial(
      tlsEnabled: tlsEnabled,
      connectionState: connectionState,
      configSnapshot: configSnapshot,
    );
    AppLogging.settings('GlobalLayer: diagnostics run started');
  }

  /// Updates the result for a specific check type.
  void updateResult(DiagnosticCheckResult result) {
    final current = state;
    if (current == null) return;
    state = current.updateResult(result);
    AppLogging.settings(
      'GlobalLayer: diagnostic ${result.type.name} '
      '-> ${result.status.name}'
      '${result.message.isNotEmpty ? ' (${result.message})' : ''}',
    );
  }

  /// Marks the diagnostics run as complete.
  void complete() {
    final current = state;
    if (current == null) return;
    state = current.markComplete();
    AppLogging.settings(
      'GlobalLayer: diagnostics completed — '
      '${state!.overallStatus.displayLabel}',
    );
  }

  /// Clears the diagnostics report.
  void clear() {
    state = null;
  }
}

/// Provider for the diagnostics report.
final globalLayerDiagnosticsProvider =
    NotifierProvider<GlobalLayerDiagnosticsNotifier, DiagnosticReport?>(
      GlobalLayerDiagnosticsNotifier.new,
    );

// ---------------------------------------------------------------------------
// Derived providers
// ---------------------------------------------------------------------------

/// Whether the Global Layer feature is enabled and setup is complete.
final globalLayerEnabledProvider = Provider<bool>((ref) {
  final configAsync = ref.watch(globalLayerConfigProvider);
  return configAsync.whenOrNull(
        data: (config) => config.enabled && config.setupComplete,
      ) ??
      false;
});

/// Whether the Global Layer setup wizard has been completed.
final globalLayerSetupCompleteProvider = Provider<bool>((ref) {
  final configAsync = ref.watch(globalLayerConfigProvider);
  return configAsync.whenOrNull(data: (config) => config.setupComplete) ??
      false;
});

/// Whether the Global Layer connection is currently active
/// (connected or degraded).
final globalLayerIsActiveProvider = Provider<bool>((ref) {
  final connectionState = ref.watch(globalLayerConnectionStateProvider);
  return connectionState.isActive;
});

/// The display URI for the current broker (e.g. "mqtts://broker.example.com").
final globalLayerDisplayUriProvider = Provider<String?>((ref) {
  final configAsync = ref.watch(globalLayerConfigProvider);
  return configAsync.whenOrNull(
    data: (config) => config.hasBrokerConfig ? config.displayUri : null,
  );
});

/// Whether the NEW badge should be shown for Global Layer in the drawer.
///
/// The badge is hidden once the user has viewed the feature at least once.
final globalLayerShowNewBadgeProvider = FutureProvider<bool>((ref) async {
  final storage = ref.read(globalLayerStorageProvider);
  final hasBeenViewed = await storage.hasBeenViewed();
  return !hasBeenViewed;
});

/// The number of active (unrecovered) errors in the metrics.
final globalLayerActiveErrorCountProvider = Provider<int>((ref) {
  final metrics = ref.watch(globalLayerMetricsProvider);
  return metrics.activeErrorCount;
});

/// Health status derived from metrics — used for the status indicator.
final globalLayerIsHealthyProvider = Provider<bool>((ref) {
  final connectionState = ref.watch(globalLayerConnectionStateProvider);
  if (!connectionState.isActive) return false;
  final metrics = ref.watch(globalLayerMetricsProvider);
  return metrics.isHealthy;
});
