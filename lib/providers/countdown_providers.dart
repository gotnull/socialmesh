// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../core/navigation.dart';
import '../core/transport.dart';
import '../models/mesh_models.dart';
import '../models/telemetry_log.dart';
import '../features/telemetry/traceroute_log_screen.dart';
import '../features/telemetry/traceroute_summary.dart';
import '../providers/app_providers.dart';
import '../providers/telemetry_providers.dart';
import '../features/nodes/node_display_name_resolver.dart';
import '../services/haptic_service.dart';
import '../utils/snackbar.dart';
import 'package:socialmesh/l10n/l10n_utils.dart';

/// The type of countdown operation. Used for grouping, deduplication, and
/// visual styling in the [CountdownBanner].
enum CountdownType {
  /// A traceroute request waiting for mesh response.
  traceroute,

  /// Device is rebooting after a config or region change.
  /// Auto-cancelled when the device reconnects.
  deviceReboot,

  /// Waiting for mesh nodes to report their positions.
  positionRequest,

  /// Broadcasting local position to the mesh.
  positionBroadcast,

  /// A file transfer in progress (sending or receiving chunks).
  fileTransfer,

  /// An on-demand telemetry request waiting for the node's reply.
  telemetryRequest,
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

  /// Seconds remaining. Refreshed every tick by the notifier from [endsAt].
  final int remainingSeconds;

  /// Wall-clock deadline for this countdown. The tick loop recomputes
  /// [remainingSeconds] from this instead of decrementing, so time spent
  /// with the app suspended (screen locked, backgrounded) still counts —
  /// a cooldown that expired while locked completes on the first tick
  /// after resume rather than freezing where it left off.
  final DateTime endsAt;

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
    required this.endsAt,
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
      endsAt: endsAt,
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

  /// Most recent user-initiated traceroute send per target node. Gates the
  /// global "Traceroute complete" banner so passive traceroute traffic
  /// never pops a banner the user did not ask for.
  final Map<int, DateTime> _tracerouteSentAt = {};

  /// Run id of the last completion banner shown, to suppress duplicates.
  String? _lastTracerouteBannerRunId;

  /// How long after a send a response is still credited to that send. The
  /// mesh has no request-response correlation, so this window is the only
  /// tie between the banner and the user's action.
  static const _tracerouteCompletionWindow = Duration(minutes: 2);

  /// Standard traceroute cooldown duration matching Meshtastic iOS.
  static const tracerouteCooldownSeconds = 30;

  /// Expected device reboot cycle duration (BLE disconnect + firmware
  /// boot + auto-reconnect). Most devices complete within 15-25 seconds.
  static const deviceRebootSeconds = 25;

  /// Duration to wait while mesh nodes report positions. Positions
  /// trickle in over 30-90 seconds depending on hop count.
  static const positionRequestSeconds = 45;

  /// Brief duration for local position broadcast propagation.
  static const positionBroadcastSeconds = 10;

  /// File transfer: estimated seconds per chunk (matches
  /// [SmRateLimit.fileChunkInterval]).
  static const fileTransferSecondsPerChunk = 2;

  /// File transfer: negotiation timeout (awaiting accept/decline).
  static const fileTransferNegotiationSeconds = 60;

  /// On-demand telemetry request cooldown. Throttles repeat taps on the
  /// per-type reload control so we don't flood mesh airtime; replies
  /// usually arrive within a few seconds but hop count can stretch this.
  static const telemetryRequestSeconds = 30;

  /// Canonical countdown id for the device reboot operation.
  static const deviceRebootId = 'device_reboot';

  /// Canonical countdown id for the position request operation.
  static const positionRequestId = 'position_request';

  /// Canonical countdown id for the position broadcast operation.
  static const positionBroadcastId = 'position_broadcast';

  @override
  Map<String, CountdownTask> build() {
    ref.onDispose(_disposeTimer);

    // Listen for device reconnection to auto-complete reboot countdowns.
    // When the device comes back online the banner disappears immediately
    // and a success snackbar confirms the reconnection.
    ref.listen<AsyncValue<DeviceConnectionState>>(connectionStateProvider, (
      previous,
      next,
    ) {
      next.whenData((connState) {
        if (connState == DeviceConnectionState.connected) {
          _onDeviceReconnected();
        }
      });
    });

    // Listen for completed traceroute responses and show the summary
    // banner globally. Ownership lives here - not on any screen - so the
    // banner appears no matter where the traceroute was started from
    // (node details, traceroute history, or the nodes-list long-press
    // menu) and no matter which screen is on top when the reply lands.
    ref.listen<AsyncValue<TraceRouteLog>>(tracerouteCompletionStreamProvider, (
      previous,
      next,
    ) {
      next.whenData(_onTracerouteResponse);
    });

    return const {};
  }

  // -----------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------

  /// Starts a new countdown. If a countdown with the same [id] already exists
  /// and is still running, the call is ignored to prevent timer resets when
  /// the user retries during cooldown.
  void startCountdown({
    required String id,
    required String label,
    required int totalSeconds,
    required CountdownType type,
    int? targetNodeNum,
  }) {
    // Don't restart an already-active countdown for the same id.
    if (state.containsKey(id)) return;

    final task = CountdownTask(
      id: id,
      label: label,
      totalSeconds: totalSeconds,
      remainingSeconds: totalSeconds,
      endsAt: DateTime.now().add(Duration(seconds: totalSeconds)),
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

    final l10n = safeL10n();

    _tracerouteSentAt[nodeNum] = DateTime.now();

    startCountdown(
      id: tracerouteId(nodeNum),
      label: l10n.countdownTracerouteTo(displayName),
      totalSeconds: tracerouteCooldownSeconds,
      type: CountdownType.traceroute,
      targetNodeNum: nodeNum,
    );
  }

  /// Whether a completed [run] earns the global "Traceroute complete"
  /// banner: the user must have initiated a traceroute to that node
  /// recently enough for the response to be theirs, and each run id is
  /// announced at most once. Mutates the send/dedupe bookkeeping when it
  /// returns true, so one send yields one banner even when duplicate
  /// replies arrive. [now] is injectable for deterministic tests.
  @visibleForTesting
  bool shouldAnnounceTracerouteRun(TraceRouteLog run, {DateTime? now}) {
    final sentAt = _tracerouteSentAt[run.targetNode];
    if (sentAt == null) return false;
    final reference = now ?? DateTime.now();
    if (reference.difference(sentAt) > _tracerouteCompletionWindow) {
      _tracerouteSentAt.remove(run.targetNode);
      return false;
    }
    if (run.id == _lastTracerouteBannerRunId) return false;
    _lastTracerouteBannerRunId = run.id;
    _tracerouteSentAt.remove(run.targetNode);
    return true;
  }

  /// Shows the global "Traceroute complete" summary banner for a completed
  /// run that passes [shouldAnnounceTracerouteRun].
  void _onTracerouteResponse(TraceRouteLog run) {
    if (!shouldAnnounceTracerouteRun(run)) return;

    final l10n = safeL10n();
    final summary = formatTracerouteSummary(l10n, run);
    showGlobalActionSnackBar(
      '${l10n.nodeDetailTracerouteComplete}\n$summary',
      actionLabel: l10n.nodeDetailTracerouteViewDetails,
      onAction: () {
        final ctx = navigatorKey.currentContext;
        if (ctx == null) return;
        TraceRouteLogScreen.open(ctx, nodeNum: run.targetNode);
      },
      type: SnackBarType.success,
      duration: const Duration(seconds: 6),
    );
    ref.read(hapticServiceProvider).trigger(HapticType.success);
  }

  /// Convenience: start a device reboot countdown.
  ///
  /// Shown after config saves or region changes that trigger a device
  /// reboot. Automatically cancelled if the device reconnects before
  /// the timer expires (see [_onDeviceReconnected]).
  ///
  /// [reason] is a human-readable label suffix, e.g. "config saved" or
  /// "region changed".
  void startDeviceRebootCountdown({String? reason}) {
    final label = reason != null
        ? 'Device rebooting — $reason' // lint-allow: hardcoded-string
        : 'Device rebooting';

    startCountdown(
      id: deviceRebootId,
      label: label,
      totalSeconds: deviceRebootSeconds,
      type: CountdownType.deviceReboot,
    );
  }

  /// Convenience: start a position request countdown.
  ///
  /// Shown after requesting positions from all mesh nodes. The countdown
  /// sets user expectations for how long positions take to trickle in.
  void startPositionRequestCountdown() {
    final l10n = safeL10n();
    startCountdown(
      id: positionRequestId,
      label: l10n.countdownRequestingPositions,
      totalSeconds: positionRequestSeconds,
      type: CountdownType.positionRequest,
    );
  }

  /// Convenience: start a position broadcast countdown.
  ///
  /// Shown after sharing the local device position to the mesh.
  void startPositionBroadcastCountdown() {
    final l10n = safeL10n();
    startCountdown(
      id: positionBroadcastId,
      label: l10n.countdownBroadcastingPosition,
      totalSeconds: positionBroadcastSeconds,
      type: CountdownType.positionBroadcast,
    );
  }

  /// Convenience: start a file transfer countdown.
  ///
  /// [fileIdHex] uniquely identifies the transfer (used for dedup and
  /// cancellation). [label] is the banner text (e.g. "Sending photo.jpg").
  /// [totalSeconds] is the estimated completion time.
  void startFileTransferCountdown({
    required String fileIdHex,
    required String label,
    required int totalSeconds,
  }) {
    startCountdown(
      id: fileTransferId(fileIdHex),
      label: label,
      totalSeconds: totalSeconds,
      type: CountdownType.fileTransfer,
    );
  }

  /// Cancel an active file transfer countdown.
  void cancelFileTransferCountdown(String fileIdHex) {
    cancelCountdown(fileTransferId(fileIdHex));
  }

  /// Convenience: start a telemetry request cooldown for [nodeNum] / [type].
  ///
  /// Keyed per (node, type) so the three requestable metric types each have
  /// their own reload cooldown ring. No completion action — the reply is
  /// ingested asynchronously and updates the telemetry tiles on its own.
  void startTelemetryRequestCountdown(int nodeNum, TelemetryRequestType type) {
    final nodes = ref.read(nodesProvider);
    final node = nodes[nodeNum];
    final displayName =
        node?.displayName ?? NodeDisplayNameResolver.defaultName(nodeNum);

    final l10n = safeL10n();

    startCountdown(
      id: telemetryRequestId(nodeNum, type),
      label: l10n.countdownRequestingTelemetry(displayName),
      totalSeconds: telemetryRequestSeconds,
      type: CountdownType.telemetryRequest,
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

  /// The single active traceroute countdown, if any. Traceroute is globally
  /// rate-limited by the device (one request per 30s regardless of target),
  /// so at most one is ever active.
  CountdownTask? get activeTracerouteTask {
    for (final task in state.values) {
      if (task.type == CountdownType.traceroute) return task;
    }
    return null;
  }

  /// Remaining seconds on the global traceroute cooldown, or 0 if none active.
  int get globalTracerouteRemaining =>
      activeTracerouteTask?.remainingSeconds ?? 0;

  /// Whether a position request countdown is currently active.
  bool get isPositionRequestActive => state.containsKey(positionRequestId);

  /// Whether a position broadcast countdown is currently active.
  bool get isPositionBroadcastActive => state.containsKey(positionBroadcastId);

  /// Whether a device reboot countdown is currently active.
  bool get isDeviceRebootActive => state.containsKey(deviceRebootId);

  /// Whether ANY countdown is currently active (used by the banner).
  bool get hasActiveCountdowns => state.isNotEmpty;

  /// Build the canonical id for a traceroute countdown.
  static String tracerouteId(int nodeNum) => 'traceroute_$nodeNum';

  /// Build the canonical id for a file transfer countdown.
  static String fileTransferId(String fileIdHex) => 'file_transfer_$fileIdHex';

  /// Build the canonical id for a telemetry request countdown.
  static String telemetryRequestId(int nodeNum, TelemetryRequestType type) =>
      'telemetry_${type.name}_$nodeNum';

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

    final now = DateTime.now();
    final updated = <String, CountdownTask>{};
    final completed = <CountdownTask>[];

    for (final entry in state.entries) {
      // Wall-clock anchored: time spent suspended (screen locked,
      // backgrounded) counts toward the countdown, so expiry is detected
      // on the first tick after resume instead of resuming a frozen count.
      final remaining = entry.value.endsAt.difference(now).inSeconds;
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
      case CountdownType.deviceReboot:
        _onDeviceRebootComplete(task);
      case CountdownType.positionRequest:
        _onPositionRequestComplete(task);
      case CountdownType.positionBroadcast:
        _onPositionBroadcastComplete(task);
      case CountdownType.fileTransfer:
        // No completion action needed — transfer state drives the UI.
        break;
      case CountdownType.telemetryRequest:
        // No completion action — the reply (if any) arrives asynchronously
        // and updates the telemetry tiles via the inbound logger.
        break;
    }
  }

  void _onTracerouteComplete(CountdownTask task) {
    final targetNodeNum = task.targetNodeNum;
    if (targetNodeNum == null) return;
    _maybeShowTracerouteReadyNotification(targetNodeNum, task.id);
  }

  /// Whether the latest traceroute run for [nodeNum] is still awaiting a
  /// response. The global cooldown guarantees no second send within the
  /// window, so the node's latest run is the current send: a `response == true`
  /// run means a reply already arrived (and "Traceroute complete" was shown).
  /// Returns true (announce) when there is no run or the query fails, so the
  /// user is never silently left without a prompt.
  Future<bool> tracerouteAwaitingResponse(int nodeNum) async {
    try {
      final repo = await ref.read(tracerouteRepositoryProvider.future);
      final runs = await repo.listRuns(targetNodeId: nodeNum, limit: 1);
      return runs.isEmpty || !runs.first.response;
    } catch (e) {
      AppLogging.app('Traceroute response check failed for $nodeNum: $e');
      return true;
    }
  }

  /// Shows the "results may be ready" notification only when no response has
  /// arrived for [targetNodeNum]. If a reply already came back, the user has
  /// seen "Traceroute complete" and a second prompt would be noise.
  Future<void> _maybeShowTracerouteReadyNotification(
    int targetNodeNum,
    String taskId,
  ) async {
    if (!await tracerouteAwaitingResponse(targetNodeNum)) {
      AppLogging.app(
        'COUNTDOWN_COMPLETE id=$taskId: response already received, '
        'skipping ready notification',
      );
      return;
    }

    final l10n = safeL10n();
    showGlobalActionSnackBar(
      'Traceroute results may be ready', // lint-allow: hardcoded-string
      actionLabel: l10n.actionView,
      onAction: () {
        final ctx = navigatorKey.currentContext;
        if (ctx == null) return;
        TraceRouteLogScreen.open(ctx, nodeNum: targetNodeNum);
      },
      type: SnackBarType.success,
      duration: const Duration(seconds: 6),
    );
  }

  void _onDeviceRebootComplete(CountdownTask task) {
    // Timer expired but the device hasn't reconnected yet. Show a
    // "still reconnecting" message so the user knows the app is
    // still trying. The auto-reconnect system handles the actual
    // reconnection independently.
    showGlobalInfoSnackBar(
      'Device may still be rebooting — reconnecting automatically', // lint-allow: hardcoded-string
      duration: const Duration(seconds: 4),
    );
  }

  void _onPositionRequestComplete(CountdownTask task) {
    showGlobalSuccessSnackBar(
      'Mesh position updates received', // lint-allow: hardcoded-string
      duration: const Duration(seconds: 3),
    );
  }

  void _onPositionBroadcastComplete(CountdownTask task) {
    showGlobalSuccessSnackBar(
      'Position broadcast complete', // lint-allow: hardcoded-string
      duration: const Duration(seconds: 3),
    );
  }

  /// Called when the device transitions to [DeviceConnectionState.connected].
  ///
  /// If a device reboot countdown is active, it means the reboot cycle
  /// completed successfully — cancel the countdown (banner disappears)
  /// and show a success snackbar.
  void _onDeviceReconnected() {
    final rebootTasks = state.entries
        .where((e) => e.value.type == CountdownType.deviceReboot)
        .toList();

    if (rebootTasks.isEmpty) return;

    for (final entry in rebootTasks) {
      AppLogging.app(
        'COUNTDOWN_AUTO_CANCEL id=${entry.key} reason=device_reconnected '
        'remaining=${entry.value.remainingSeconds}s',
      );
      cancelCountdown(entry.key);
    }

    showGlobalSuccessSnackBar(
      'Device reconnected', // lint-allow: hardcoded-string
      duration: const Duration(seconds: 3),
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

/// The single active traceroute countdown across the whole app, or null.
///
/// Watch from any traceroute button so its cooldown ring reflects the global
/// device rate limit, not just this node's own send.
final activeTracerouteProvider = Provider<CountdownTask?>((ref) {
  final countdowns = ref.watch(countdownProvider);
  for (final task in countdowns.values) {
    if (task.type == CountdownType.traceroute) return task;
  }
  return null;
});
