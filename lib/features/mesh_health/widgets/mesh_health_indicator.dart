// Compact Mesh Health Indicator Widget
//
// A small, embeddable widget showing mesh health at a glance.
// Suitable for placing in app bars, status bars, or other constrained spaces.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/mesh_health/mesh_health_models.dart';
import '../../../services/mesh_health/mesh_health_providers.dart';
import 'mesh_health_dashboard.dart';

/// Compact health indicator for embedding in other screens
class MeshHealthIndicator extends ConsumerWidget {
  final bool showLabel;
  final VoidCallback? onTap;

  const MeshHealthIndicator({super.key, this.showLabel = true, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meshHealthProvider);
    final snapshot = state.latestSnapshot;

    if (!state.isMonitoring || snapshot == null) {
      return _buildInactive(context);
    }

    return _buildActive(context, snapshot);
  }

  Widget _buildInactive(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => _openDashboard(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.monitor_heart_outlined,
              color: Colors.grey,
              size: 16,
            ),
            if (showLabel) ...[
              const SizedBox(width: 6),
              const Text(
                'Health',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActive(BuildContext context, MeshHealthSnapshot snapshot) {
    final color = _getHealthColor(snapshot);

    return GestureDetector(
      onTap: onTap ?? () => _openDashboard(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getHealthIcon(snapshot), color: color, size: 16),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(
                '${snapshot.channelUtilizationPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (snapshot.issueCount > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${snapshot.issueCount}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getHealthColor(MeshHealthSnapshot snapshot) {
    if (snapshot.hasCriticalIssues) return const Color(0xFFFF1744);
    if (!snapshot.isHealthy) return const Color(0xFFFFAB00);
    return const Color(0xFF00FF88);
  }

  IconData _getHealthIcon(MeshHealthSnapshot snapshot) {
    if (snapshot.hasCriticalIssues) return Icons.error;
    if (!snapshot.isHealthy) return Icons.warning;
    return Icons.check_circle;
  }

  void _openDashboard(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MeshHealthDashboard()));
  }
}

/// Small utilization bar for tight spaces
class MeshUtilizationBar extends ConsumerWidget {
  final double width;
  final double height;

  const MeshUtilizationBar({super.key, this.width = 80, this.height = 6});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilization = ref.watch(meshUtilizationProvider);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: (utilization / 100).clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: _getColor(utilization),
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }

  Color _getColor(double utilization) {
    if (utilization >= 75) return const Color(0xFFFF1744);
    if (utilization >= 50) return const Color(0xFFFFAB00);
    return const Color(0xFF00E5FF);
  }
}

/// Issue badge showing count of active issues
class MeshIssueBadge extends ConsumerWidget {
  const MeshIssueBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(meshHealthIssuesProvider);

    if (issues.isEmpty) return const SizedBox.shrink();

    final hasCritical = issues.any((i) => i.severity == IssueSeverity.critical);
    final color = hasCritical
        ? const Color(0xFFFF1744)
        : const Color(0xFFFFAB00);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${issues.length}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
