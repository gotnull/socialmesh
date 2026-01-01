// Mesh Health Riverpod Providers
//
// Follows app's Riverpod 3.x patterns with Notifier classes.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
class MeshHealthNotifier extends Notifier<MeshHealthState> {
  StreamSubscription<MeshHealthSnapshot>? _subscription;

  @override
  MeshHealthState build() {
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return const MeshHealthState();
  }

  /// Start monitoring mesh health
  void startMonitoring() {
    if (state.isMonitoring) return;

    final analyzer = ref.read(meshHealthAnalyzerProvider);
    analyzer.start();

    _subscription?.cancel();
    _subscription = analyzer.snapshots.listen(_onSnapshot);

    state = state.copyWith(isMonitoring: true);
  }

  /// Stop monitoring
  void stopMonitoring() {
    if (!state.isMonitoring) return;

    final analyzer = ref.read(meshHealthAnalyzerProvider);
    analyzer.stop();

    _subscription?.cancel();
    _subscription = null;

    state = state.copyWith(isMonitoring: false);
  }

  /// Toggle monitoring
  void toggleMonitoring() {
    if (state.isMonitoring) {
      stopMonitoring();
    } else {
      startMonitoring();
    }
  }

  /// Ingest telemetry packet
  void ingestTelemetry(MeshTelemetry telemetry) {
    ref.read(meshHealthAnalyzerProvider).ingestTelemetry(telemetry);
  }

  /// Ingest telemetry from JSON
  void ingestJson(Map<String, dynamic> json) {
    ref.read(meshHealthAnalyzerProvider).ingestJson(json);
  }

  /// Reset all data
  void reset() {
    ref.read(meshHealthAnalyzerProvider).reset();
    state = const MeshHealthState();
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
