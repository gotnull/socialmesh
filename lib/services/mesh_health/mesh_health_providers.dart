// SPDX-License-Identifier: GPL-3.0-or-later
// Mesh Health Riverpod Providers
//
// Follows app's Riverpod 3.x patterns with Notifier classes.
// Auto-starts monitoring when a BLE device connects, subscribes to the
// protocol service's per-packet telemetry stream, and feeds data into
// the MeshHealthAnalyzer for windowed analysis.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging.dart';
import '../../core/transport.dart';
import '../../providers/app_providers.dart';
import 'mesh_health_models.dart';
import 'mesh_health_analyzer.dart';

/// Provider for the mesh health analyzer service
final meshHealthAnalyzerProvider = Provider<MeshHealthAnalyzer>((ref) {
  final analyzer = MeshHealthAnalyzer();
  ref.onDispose(() => analyzer.dispose());
  return analyzer;
});

/// State for mesh health monitoring
class MeshHealthState {
  final bool isMonitoring;
  final MeshHealthSnapshot? latestSnapshot;
  final List<UtilizationDataPoint> utilizationHistory;
  final List<NodeStats> nodeStats;
  final DateTime? lastUpdate;

  const MeshHealthState({
    this.isMonitoring = false,
    this.latestSnapshot,
    this.utilizationHistory = const [],
    this.nodeStats = const [],
    this.lastUpdate,
  });

  MeshHealthState copyWith({
    bool? isMonitoring,
    MeshHealthSnapshot? latestSnapshot,
    List<UtilizationDataPoint>? utilizationHistory,
    List<NodeStats>? nodeStats,
    DateTime? lastUpdate,
  }) {
    return MeshHealthState(
      isMonitoring: isMonitoring ?? this.isMonitoring,
      latestSnapshot: latestSnapshot ?? this.latestSnapshot,
      utilizationHistory: utilizationHistory ?? this.utilizationHistory,
      nodeStats: nodeStats ?? this.nodeStats,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  // Convenience getters
  double get utilization => latestSnapshot?.channelUtilizationPercent ?? 0;
  double get reliability => latestSnapshot?.avgReliability ?? 1.0;
  bool get isSaturated => latestSnapshot?.isSaturated ?? false;
  bool get isHealthy => latestSnapshot?.isHealthy ?? true;
  int get issueCount => latestSnapshot?.issueCount ?? 0;
  int get activeNodes => latestSnapshot?.activeNodeCount ?? 0;
  List<HealthIssue> get issues => latestSnapshot?.activeIssues ?? [];
}

/// Notifier for mesh health state
///
/// Auto-starts monitoring when the device connects and subscribes to
/// [ProtocolService.meshTelemetryStream] to feed per-packet data into
/// the [MeshHealthAnalyzer]. Stops automatically on disconnect.
class MeshHealthNotifier extends Notifier<MeshHealthState> {
  StreamSubscription<MeshHealthSnapshot>? _snapshotSubscription;
  StreamSubscription<MeshTelemetry>? _telemetrySubscription;

  @override
  MeshHealthState build() {
    ref.onDispose(() {
      _snapshotSubscription?.cancel();
      _telemetrySubscription?.cancel();
    });

    // React to connection state changes: auto-start on connect, stop on
    // disconnect. ref.listen only fires on changes, not the initial value.
    ref.listen<DeviceConnectionState>(unifiedConnectionStateProvider, (
      prev,
      next,
    ) {
      if (next == DeviceConnectionState.connected && !state.isMonitoring) {
        AppLogging.protocol('MeshHealth: auto-starting on connect');
        startMonitoring();
      } else if (next == DeviceConnectionState.disconnected &&
          state.isMonitoring) {
        AppLogging.protocol('MeshHealth: stopping on disconnect');
        stopMonitoring();
      }
    });

    // If the device is already connected when this notifier is first built,
    // schedule auto-start after build completes (cannot mutate state inside
    // build synchronously).
    Future.microtask(() {
      final conn = ref.read(unifiedConnectionStateProvider);
      if (conn == DeviceConnectionState.connected && !state.isMonitoring) {
        AppLogging.protocol('MeshHealth: auto-starting (already connected)');
        startMonitoring();
      }
    });

    return const MeshHealthState();
  }

  /// Start monitoring mesh health and subscribe to protocol telemetry.
  void startMonitoring() {
    if (state.isMonitoring) return;

    final analyzer = ref.read(meshHealthAnalyzerProvider);
    analyzer.start();

    _snapshotSubscription?.cancel();
    _snapshotSubscription = analyzer.snapshots.listen(_onSnapshot);

    // Subscribe to the protocol service's per-packet telemetry stream
    _telemetrySubscription?.cancel();
    try {
      final protocol = ref.read(protocolServiceProvider);
      _telemetrySubscription = protocol.meshTelemetryStream.listen(
        analyzer.ingestTelemetry,
      );
    } catch (e) {
      AppLogging.protocol('MeshHealth: failed to subscribe to telemetry: $e');
    }

    state = state.copyWith(isMonitoring: true);
  }

  /// Stop monitoring and cancel all subscriptions.
  void stopMonitoring() {
    if (!state.isMonitoring) return;

    final analyzer = ref.read(meshHealthAnalyzerProvider);
    analyzer.stop();

    _snapshotSubscription?.cancel();
    _snapshotSubscription = null;
    _telemetrySubscription?.cancel();
    _telemetrySubscription = null;

    state = state.copyWith(isMonitoring: false);
  }

  /// Toggle monitoring on/off (used by dashboard play/pause button).
  void toggleMonitoring() {
    if (state.isMonitoring) {
      stopMonitoring();
    } else {
      startMonitoring();
    }
  }

  /// Manually ingest a telemetry packet (for testing or external data).
  void ingestTelemetry(MeshTelemetry telemetry) {
    ref.read(meshHealthAnalyzerProvider).ingestTelemetry(telemetry);
  }

  /// Ingest telemetry from JSON (for testing or external data).
  void ingestJson(Map<String, dynamic> json) {
    ref.read(meshHealthAnalyzerProvider).ingestJson(json);
  }

  /// Reset all data and restart if currently monitoring.
  void reset() {
    final wasMonitoring = state.isMonitoring;
    if (wasMonitoring) stopMonitoring();
    ref.read(meshHealthAnalyzerProvider).reset();
    state = const MeshHealthState();
    if (wasMonitoring) startMonitoring();
  }

  void _onSnapshot(MeshHealthSnapshot snapshot) {
    final analyzer = ref.read(meshHealthAnalyzerProvider);
    state = state.copyWith(
      latestSnapshot: snapshot,
      utilizationHistory: analyzer.getUtilizationHistory(),
      nodeStats: analyzer.getNodeStats(),
      lastUpdate: DateTime.now(),
    );
  }
}

/// Provider for mesh health notifier
final meshHealthProvider =
    NotifierProvider<MeshHealthNotifier, MeshHealthState>(
      MeshHealthNotifier.new,
    );

/// Provider for just the utilization percentage (for selective rebuilds)
final meshUtilizationProvider = Provider<double>((ref) {
  return ref.watch(meshHealthProvider).utilization;
});

/// Provider for just the issues list
final meshHealthIssuesProvider = Provider<List<HealthIssue>>((ref) {
  return ref.watch(meshHealthProvider).issues;
});

/// Provider for node statistics
final meshNodeStatsProvider = Provider<List<NodeStats>>((ref) {
  return ref.watch(meshHealthProvider).nodeStats;
});

/// Provider for utilization history (graph data)
final meshUtilizationHistoryProvider = Provider<List<UtilizationDataPoint>>((
  ref,
) {
  return ref.watch(meshHealthProvider).utilizationHistory;
});

/// Provider for top contributors
final meshTopContributorsProvider = Provider<List<NodeStats>>((ref) {
  final stats = ref.watch(meshNodeStatsProvider);
  return stats.take(5).toList();
});

/// Provider for critical issues only
final meshCriticalIssuesProvider = Provider<List<HealthIssue>>((ref) {
  final issues = ref.watch(meshHealthIssuesProvider);
  return issues.where((i) => i.severity == IssueSeverity.critical).toList();
});

/// Provider for spamming nodes
final meshSpammingNodesProvider = Provider<List<NodeStats>>((ref) {
  final stats = ref.watch(meshNodeStatsProvider);
  return stats.where((n) => n.isSpamming).toList();
});

/// Provider for flooding nodes
final meshFloodingNodesProvider = Provider<List<NodeStats>>((ref) {
  final stats = ref.watch(meshNodeStatsProvider);
  return stats.where((n) => n.isHopFlooding).toList();
});
