// Mesh Health Dashboard Widget
//
// Live display of mesh network health metrics, utilization graphs,
// and detected issues. Uses Riverpod for state management.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../services/mesh_health/mesh_health_models.dart';
import '../../../services/mesh_health/mesh_health_providers.dart';

/// Main mesh health dashboard widget
class MeshHealthDashboard extends ConsumerWidget {
  const MeshHealthDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(meshHealthProvider);

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          'Mesh Health',
          style: TextStyle(color: context.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(
              healthState.isMonitoring ? Icons.pause : Icons.play_arrow,
              color: healthState.isMonitoring
                  ? const Color(0xFF00E5FF)
                  : context.textSecondary,
            ),
            tooltip: healthState.isMonitoring ? 'Pause' : 'Resume',
            onPressed: () {
              ref.read(meshHealthProvider.notifier).toggleMonitoring();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Data',
            onPressed: () {
              ref.read(meshHealthProvider.notifier).reset();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(healthState),
            const SizedBox(height: 16),
            _buildMetricsRow(healthState),
            const SizedBox(height: 16),
            _buildUtilizationChart(healthState),
            const SizedBox(height: 16),
            _buildIssuesSection(healthState),
            const SizedBox(height: 16),
            _buildTopContributors(healthState),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(MeshHealthState state) {
    final status = state.latestSnapshot;
    final isHealthy = status?.isHealthy ?? true;
    final isCritical = status?.hasCriticalIssues ?? false;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (!state.isMonitoring) {
      statusColor = Colors.grey;
      statusText = 'Monitoring Paused';
      statusIcon = Icons.pause_circle_outline;
    } else if (isCritical) {
      statusColor = const Color(0xFFFF1744);
      statusText = 'Critical Issues Detected';
      statusIcon = Icons.error;
    } else if (!isHealthy) {
      statusColor = const Color(0xFFFFAB00);
      statusText = 'Issues Detected';
      statusIcon = Icons.warning;
    } else {
      statusColor = const Color(0xFF00FF88);
      statusText = 'Mesh Healthy';
      statusIcon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (status != null)
                  Text(
                    '${status.activeNodeCount} active nodes • ${status.totalPackets} packets',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          if (state.isMonitoring && status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${status.issueCount} issues',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(MeshHealthState state) {
    final snapshot = state.latestSnapshot;

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Utilization',
            value:
                '${(snapshot?.channelUtilizationPercent ?? 0).toStringAsFixed(1)}%',
            subtitle: snapshot?.isSaturated == true ? 'SATURATED' : 'Normal',
            color: _getUtilizationColor(
              snapshot?.channelUtilizationPercent ?? 0,
            ),
            icon: Icons.network_check,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            title: 'Reliability',
            value:
                '${((snapshot?.avgReliability ?? 1.0) * 100).toStringAsFixed(1)}%',
            subtitle: _getReliabilityLabel(snapshot?.avgReliability ?? 1.0),
            color: _getReliabilityColor(snapshot?.avgReliability ?? 1.0),
            icon: Icons.verified,
          ),
        ),
      ],
    );
  }

  Widget _buildUtilizationChart(MeshHealthState state) {
    final history = state.utilizationHistory;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Channel Utilization',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFAB00).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '50% threshold',
                  style: TextStyle(color: Color(0xFFFFAB00), fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: history.isEmpty
                ? Center(
                    child: Text(
                      'No data yet',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : _UtilizationGraph(data: history),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesSection(MeshHealthState state) {
    final issues = state.issues;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detected Issues',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (issues.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No issues detected',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...issues.map((issue) => _IssueCard(issue: issue)),
        ],
      ),
    );
  }

  Widget _buildTopContributors(MeshHealthState state) {
    final contributors = state.nodeStats.take(5).toList();
    final snapshot = state.latestSnapshot;
    final totalAirtime = snapshot?.totalAirtimeMs ?? 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Contributors',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (contributors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No nodes detected',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                ),
              ),
            )
          else
            ...contributors.map(
              (node) =>
                  _NodeContributorRow(node: node, totalAirtime: totalAirtime),
            ),
        ],
      ),
    );
  }

  Color _getUtilizationColor(double utilization) {
    if (utilization >= 75) return const Color(0xFFFF1744);
    if (utilization >= 50) return const Color(0xFFFFAB00);
    return const Color(0xFF00E5FF);
  }

  Color _getReliabilityColor(double reliability) {
    if (reliability < 0.5) return const Color(0xFFFF1744);
    if (reliability < 0.8) return const Color(0xFFFFAB00);
    return const Color(0xFF00FF88);
  }

  String _getReliabilityLabel(double reliability) {
    if (reliability < 0.5) return 'Poor';
    if (reliability < 0.8) return 'Fair';
    return 'Good';
  }
}

/// Metric card widget
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Issue card widget
class _IssueCard extends StatelessWidget {
  final HealthIssue issue;

  const _IssueCard({required this.issue});

  @override
  Widget build(BuildContext context) {
    final color = _getSeverityColor(issue.severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_getSeverityIcon(issue.severity), color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        issue.typeLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      issue.severityLabel,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  issue.message,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                if (issue.nodeId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Node: ${issue.nodeId}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(IssueSeverity severity) {
    switch (severity) {
      case IssueSeverity.critical:
        return const Color(0xFFFF1744);
      case IssueSeverity.warning:
        return const Color(0xFFFFAB00);
      case IssueSeverity.info:
        return const Color(0xFF448AFF);
    }
  }

  IconData _getSeverityIcon(IssueSeverity severity) {
    switch (severity) {
      case IssueSeverity.critical:
        return Icons.error;
      case IssueSeverity.warning:
        return Icons.warning;
      case IssueSeverity.info:
        return Icons.info;
    }
  }
}

/// Node contributor row widget
class _NodeContributorRow extends StatelessWidget {
  final NodeStats node;
  final int totalAirtime;

  const _NodeContributorRow({required this.node, required this.totalAirtime});

  @override
  Widget build(BuildContext context) {
    final contribution = totalAirtime > 0
        ? (node.totalAirtimeMs / totalAirtime) * 100
        : 0.0;

    final hasIssue = node.isSpamming || node.isHopFlooding;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: node.isKnownNode
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasIssue
                    ? const Color(0xFFFFAB00).withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: Center(
              child: Icon(
                node.isKnownNode ? Icons.check : Icons.help_outline,
                color: node.isKnownNode
                    ? const Color(0xFF00E5FF)
                    : Colors.white.withValues(alpha: 0.5),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      node.nodeId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    if (node.isSpamming) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFAB00).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'SPAM',
                          style: TextStyle(
                            color: Color(0xFFFFAB00),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    if (node.isHopFlooding) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF1744).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'FLOOD',
                          style: TextStyle(
                            color: Color(0xFFFF1744),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${node.packetCount} packets • ${node.totalAirtimeMs}ms airtime',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${contribution.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'of airtime',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Simple utilization graph using CustomPaint
class _UtilizationGraph extends StatelessWidget {
  final List<UtilizationDataPoint> data;

  const _UtilizationGraph({required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 120),
      painter: _UtilizationGraphPainter(data: data),
    );
  }
}

class _UtilizationGraphPainter extends CustomPainter {
  final List<UtilizationDataPoint> data;

  _UtilizationGraphPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxUtil = data.fold<double>(
      100,
      (max, p) => p.utilizationPercent > max ? p.utilizationPercent : max,
    );
    final scale = size.height / maxUtil;

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = size.height - (i * size.height / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 50% threshold line
    final thresholdY = size.height - (50 * scale);
    final thresholdPaint = Paint()
      ..color = const Color(0xFFFFAB00).withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, thresholdY),
      Offset(size.width, thresholdY),
      thresholdPaint,
    );

    // Data line
    if (data.length < 2) return;

    final path = Path();
    final fillPath = Path();
    final step = size.width / (data.length - 1);

    for (var i = 0; i < data.length; i++) {
      final x = i * step;
      final y = size.height - (data[i].utilizationPercent * scale);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: 0.3),
          const Color(0xFF00E5FF).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_UtilizationGraphPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
