// SPDX-License-Identifier: GPL-3.0-or-later
/// Mesh Health Module
///
/// Real-time mesh network health detection and diagnostics.
///
/// This module provides:
/// - Rolling channel utilization calculation
/// - Saturation detection (>50% = warning, >75% = critical)
/// - Interval spam detection (TX < 20 seconds)
/// - Hop flood detection (max hop propagation)
/// - Unknown node flood detection
/// - Reliability attribution for drops
///
/// ## Usage
///
/// ```dart
/// // In a ConsumerWidget
/// final state = ref.watch(meshHealthProvider);
/// final snapshot = state.latestSnapshot;
///
/// // Ingest telemetry data
/// ref.read(meshHealthProvider.notifier).ingestTelemetry(telemetry);
///
/// // Get specific data
/// final utilization = ref.watch(meshUtilizationProvider);
/// final issues = ref.watch(meshHealthIssuesProvider);
/// ```
///
/// ## UI Widgets
///
/// - [MeshHealthDashboard] - Full screen health dashboard with graphs
/// - [MeshHealthIndicator] - Compact indicator for embedding in other screens
/// - [MeshUtilizationBar] - Small progress bar showing utilization
/// - [MeshIssueBadge] - Badge showing issue count
library;

export 'mesh_health_analyzer.dart';
export 'mesh_health_models.dart';
export 'mesh_health_providers.dart';
