// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../core/navigation.dart';
import '../features/telemetry/traceroute_log_screen.dart';
import '../providers/app_providers.dart';
import '../features/nodes/node_display_name_resolver.dart';
import '../utils/snackbar.dart';
import 'package:flutter/material.dart';

/// The type of countdown operation. Used for grouping, deduplication, and
/// visual styling in the [CountdownBanner].
enum CountdownType {
  /// A traceroute request waiting for mesh response.
  traceroute,
}

/// Immutable snapshot of a single active countdown.
class CountdownTask {
  /// Unique identifier for this countdown. For traceroutes this is
  /// typically `traceroute_<nodeNum>`.
  final String id;

  /// Human-readable label shown in the banner, e.g. "Traceroute to NodeName".
  final String label;

  /// Total duration in seconds (used for progress calculation).
  final int totalSeconds;

  /// Seconds remaining. Decremented every tick by the notifier.
  final int remainingSeconds;

  /// The target node number (if applicable). Used for the "View" action
  /// when the countdown completes.
  final int? targetNodeNum;

  /// The category of this countdown.
  final CountdownType type;

  const CountdownTask({
    required this.id,
    required this.label,
    required this.totalSeconds,
    required this.remainingSeconds,
    this.targetNodeNum,
    required this.type,
  });

  /// Progress value from 0.0 (complete) to 1.0 (just started).
  double get progress =>
      totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;

  /// Whether this countdown has finished.
  bool get isComplete => remainingSeconds <= 0;

  CountdownTask copyWith({int? remainingSeconds}) {
    return CountdownTask(
      id: id,
      label: label,
      totalSeconds: totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      targetNodeNum: targetNodeNum,
      type: type,
    );
  }
}

/// Global state: an unmodifiable map of active countdowns keyed by [CountdownTask.id].
///
/// Widgets can watch this provider to reactively render countdown progress
/// without owning timers or worrying about disposal on navigation.
class CountdownNotifier extends Notifier<Map<String, CountdownTask>> {
  Timer? _tickTimer;

  /// Standard traceroute cooldown duration matching Meshtastic iOS.
  static const tracerouteCooldownSeconds = 30;

  @override
  Map<String, CountdownTask> build() {
    ref.onDispose(_disposeTimer);
    return const {};
  }

  // -----------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------

  /// Starts a new countdown. If a countdown with the same [id] already exists
  /// it is replaced (restarted).
  void startCountdown({
    required String id,
    required String label,
    required int totalSeconds,
    required CountdownType type,
    int? targetNodeNum,
  }) {
    final task = CountdownTask(
      id: id,
      label: label,
      totalSeconds: totalSeconds,
      remainingSeconds: totalSeconds,
      targetNodeNum: targetNodeNum,
      type: type,
    );

    state = {...state, id: task};
    _ensureTimerRunning();

    AppLogging.app(
      'COUNTDOWN_START id=$id label="$label" seconds=$totalSeconds',
    );
  }

  /// Convenience: start a traceroute countdown for [nodeNum].
  ///
  /// Resolves the node display name from the current nodes map.
  void startTracerouteCountdown(int nodeNum) {
    final nodes = ref.read(nodesProvider);
    final node = nodes[nodeNum];
    final displayName =
        node?.displayName ?? NodeDisplayNameResolver.defaultName(nodeNum);

    startCountdown(
      id: tracerouteId(nodeNum),
      label: 'Traceroute to $displayName',
      totalSeconds: tracerouteCooldownSeconds,
      type: CountdownType.traceroute,
      targetNodeNum: nodeNum,
    );
  }

  /// Cancel and remove a countdown by [id].
  void cancelCountdown(String id) {
    if (!state.containsKey(id)) return;
    final updated = Map<String, CountdownTask>.from(state)..remove(id);
    state = updated;
    _stopTimerIfEmpty();
  }

  /// Cancel all active countdowns.
  void cancelAll() {
    if (state.isEmpty) return;
    state = const {};
    _disposeTimer();
  }

  /// Whether a traceroute countdown is active for [nodeNum].
  bool isTracerouteActive(int nodeNum) =>
      state.containsKey(tracerouteId(nodeNum));

  /// Remaining seconds for a traceroute to [nodeNum], or 0 if none active.
  int tracerouteRemaining(int nodeNum) =>
      state[tracerouteId(nodeNum)]?.remainingSeconds ?? 0;

  /// Whether ANY countdown is currently active (used by the banner).
  bool get hasActiveCountdowns => state.isNotEmpty;

  /// Build the canonical id for a traceroute countdown.
  static String tracerouteId(int nodeNum) => 'traceroute_$nodeNum';

  // -----------------------------------------------------------------------
  // Internal tick logic
  // -----------------------------------------------------------------------

  void _ensureTimerRunning() {
    if (_tickTimer != null && _tickTimer!.isActive) return;
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (state.isEmpty) {
      _disposeTimer();
      return;
    }

    final updated = <String, CountdownTask>{};
    final completed = <CountdownTask>[];

    for (final entry in state.entries) {
      final remaining = entry.value.remainingSeconds - 1;
      if (remaining <= 0) {
        completed.add(entry.value);
      } else {
        updated[entry.key] = entry.value.copyWith(remainingSeconds: remaining);
      }
    }

    state = updated;

    // Fire completion callbacks outside the state update
    for (final task in completed) {
      _onCountdownComplete(task);
    }

    _stopTimerIfEmpty();
  }

  void _onCountdownComplete(CountdownTask task) {
    AppLogging.app('COUNTDOWN_COMPLETE id=${task.id}');

    switch (task.type) {
      case CountdownType.traceroute:
        _onTracerouteComplete(task);
    }
  }

  void _onTracerouteComplete(CountdownTask task) {
    final targetNodeNum = task.targetNodeNum;
    if (targetNodeNum == null) return;

    showGlobalActionSnackBar(
      'Traceroute results may be ready',
      actionLabel: 'View',
      onAction: () {
        final ctx = navigatorKey.currentContext;
        if (ctx == null) return;
        Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => TraceRouteLogScreen(nodeNum: targetNodeNum),
          ),
        );
      },
      type: SnackBarType.success,
      duration: const Duration(seconds: 6),
    );
  }

  void _stopTimerIfEmpty() {
    if (state.isEmpty) _disposeTimer();
  }

  void _disposeTimer() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }
}

/// Global provider for active countdown operations.
///
/// Watch from widgets to render countdown banners and cooldown buttons.
/// Read the notifier to start/cancel countdowns from action handlers.
final countdownProvider =
    NotifierProvider<CountdownNotifier, Map<String, CountdownTask>>(
      CountdownNotifier.new,
    );

/// Convenience provider: whether any countdown is currently active.
///
/// Avoids unnecessary rebuilds in widgets that only care about
/// presence/absence rather than tick-by-tick progress.
final hasActiveCountdownsProvider = Provider<bool>((ref) {
  return ref.watch(countdownProvider).isNotEmpty;
});

/// Convenience provider: list of active countdown tasks sorted by remaining
/// time (shortest first).
final activeCountdownListProvider = Provider<List<CountdownTask>>((ref) {
  final countdowns = ref.watch(countdownProvider);
  final list = countdowns.values.toList()
    ..sort((a, b) => a.remainingSeconds.compareTo(b.remainingSeconds));
  return list;
});
