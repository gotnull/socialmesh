// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// Mesh Health Dashboard Widget
//
// Live display of mesh network health metrics, utilization graphs,
// and detected issues. Uses Riverpod for state management.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../services/mesh_health/mesh_health_models.dart';
import '../../../services/mesh_health/mesh_health_providers.dart';
import 'mesh_health_battery_reminder.dart';

/// SharedPreferences key — when true the back-button reminder is suppressed.
const _backReminderDismissedKey = 'mesh_health_back_reminder_dismissed';

/// Main mesh health dashboard widget
class MeshHealthDashboard extends ConsumerWidget {
  const MeshHealthDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(meshHealthProvider);

    return PopScope(
      canPop: !healthState.isMonitoring,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final prefs = await SharedPreferences.getInstance();
        final dismissed = prefs.getBool(_backReminderDismissedKey) ?? false;
        if (dismissed) {
          navigator.pop();
          return;
        }
        if (!context.mounted) return;
        await _showBatteryReminder(context, ref, navigator, prefs);
        if (!context.mounted) return;
      },
      child: HelpTourController(
        topicId: 'mesh_health_overview',
        stepKeys: const {},
        child: GlassScaffold(
          title: context.l10n.meshHealthTitle,
          actions: [
            IconButton(
              icon: Icon(
                healthState.isMonitoring ? Icons.pause : Icons.play_arrow,
                color: healthState.isMonitoring
                    ? const Color(0xFF00E5FF)
                    : context.textSecondary,
              ),
              tooltip: healthState.isMonitoring
                  ? context.l10n.meshHealthPauseTooltip
                  : context.l10n.meshHealthResumeTooltip,
              onPressed: () {
                ref.read(meshHealthProvider.notifier).toggleMonitoring();
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: context.l10n.meshHealthResetDataTooltip,
              onPressed: () {
                ref.read(meshHealthProvider.notifier).reset();
              },
            ),
            IcoHelpAppBarButton(topicId: 'mesh_health_overview'),
          ],
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const MeshHealthBatteryReminder(),
                  _buildStatusHeader(context, healthState),
                  const SizedBox(height: AppTheme.spacing16),
                  _buildMetricsRow(context, healthState),
                  const SizedBox(height: AppTheme.spacing16),
                  _buildUtilizationChart(context, healthState),
                  const SizedBox(height: AppTheme.spacing16),
                  _buildIssuesSection(context, healthState),
                  const SizedBox(height: AppTheme.spacing16),
                  _buildTopContributors(context, healthState),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBatteryReminder(
    BuildContext context,
    WidgetRef ref,
    NavigatorState navigator,
    SharedPreferences prefs,
  ) async {
    HapticFeedback.lightImpact();
    final result = await AppBottomSheet.show<String>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppTheme.spacing8),
          Icon(
            Icons.battery_alert_rounded,
            size: 40,
            color: AppTheme.warningYellow,
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            context.l10n.meshHealthMonitoringActiveTitle,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing6),
          Text(
            context.l10n.meshHealthMonitoringBatteryWarning,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spacing20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, 'pause'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.warningYellow,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
              child: Text(
                context.l10n.meshHealthPauseAndLeave,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, 'keep'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                side: BorderSide(color: context.border.withValues(alpha: 0.3)),
              ),
              child: Text(
                context.l10n.meshHealthKeepRunning,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          TextButton(
            onPressed: () => Navigator.pop(context, 'dismiss'),
            child: Text(
              context.l10n.meshHealthDontRemindAgain,
              style: TextStyle(fontSize: 12, color: context.textTertiary),
            ),
          ),
        ],
      ),
    );
    if (!context.mounted) return;

    if (result == 'pause') {
      ref.read(meshHealthProvider.notifier).stopMonitoring();
      navigator.pop();
    } else if (result == 'keep') {
      navigator.pop();
    } else if (result == 'dismiss') {
      await prefs.setBool(_backReminderDismissedKey, true);
      navigator.pop();
    }
  }

  Widget _buildStatusHeader(BuildContext context, MeshHealthState state) {
    final status = state.latestSnapshot;
    final isHealthy = status?.isHealthy ?? true;
    final isCritical = status?.hasCriticalIssues ?? false;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (!state.isMonitoring) {
      statusColor = SemanticColors.disabled;
      statusText = context.l10n.meshHealthMonitoringPaused;
      statusIcon = Icons.pause_circle_outline;
    } else if (isCritical) {
      statusColor = AppTheme.errorRed;
      statusText = context.l10n.meshHealthCriticalIssues;
      statusIcon = Icons.error;
    } else if (!isHealthy) {
      statusColor = const Color(0xFFFFAB00);
      statusText = context.l10n.meshHealthIssuesDetected;
      statusIcon = Icons.warning;
    } else {
      statusColor = const Color(0xFF00FF88);
      statusText = context.l10n.meshHealthHealthy;
      statusIcon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 32),
          const SizedBox(width: AppTheme.spacing12),
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
                    context.l10n.meshHealthActiveNodesPackets(
                      status.activeNodeCount,
                      status.totalPackets,
                    ),
                    style: TextStyle(
                      color: context.textSecondary,
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
                color: context.isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radius16),
              ),
              child: Text(
                context.l10n.meshHealthIssueCount(status.issueCount),
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(BuildContext context, MeshHealthState state) {
    final snapshot = state.latestSnapshot;

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: context.l10n.meshHealthUtilization,
            value:
                '${(snapshot?.channelUtilizationPercent ?? 0).toStringAsFixed(1)}%',
            subtitle: snapshot?.isSaturated == true
                ? context.l10n.meshHealthSaturated
                : context.l10n.meshHealthNormal,
            color: _getUtilizationColor(
              snapshot?.channelUtilizationPercent ?? 0,
            ),
            icon: Icons.network_check,
          ),
        ),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: _MetricCard(
            title: context.l10n.meshHealthReliability,
            value:
                '${((snapshot?.avgReliability ?? 1.0) * 100).toStringAsFixed(1)}%',
            subtitle: _getReliabilityLabel(
              context,
              snapshot?.avgReliability ?? 1.0,
            ),
            color: _getReliabilityColor(snapshot?.avgReliability ?? 1.0),
            icon: Icons.verified,
          ),
        ),
      ],
    );
  }

  Widget _buildUtilizationChart(BuildContext context, MeshHealthState state) {
    final history = state.utilizationHistory;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: context.isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.meshHealthChannelUtilization,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFAB00).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Text(
                  context.l10n.meshHealthThresholdLabel,
                  style: TextStyle(color: Color(0xFFFFAB00), fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),
          SizedBox(
            height: 120,
            child: history.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.meshHealthNoDataYet,
                      style: TextStyle(color: context.textTertiary),
                    ),
                  )
                : _UtilizationGraph(data: history),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesSection(BuildContext context, MeshHealthState state) {
    final issues = state.issues;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: context.isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.meshHealthDetectedIssues,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          if (issues.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: context.textTertiary,
                      size: 32,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      context.l10n.meshHealthNoIssuesDetected,
                      style: TextStyle(color: context.textTertiary),
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

  Widget _buildTopContributors(BuildContext context, MeshHealthState state) {
    final contributors = state.nodeStats.take(5).toList();
    final snapshot = state.latestSnapshot;
    final totalAirtime = snapshot?.totalAirtimeMs ?? 1;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: context.isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.meshHealthTopContributors,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          if (contributors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  context.l10n.meshHealthNoNodesDetected,
                  style: TextStyle(color: context.textTertiary),
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
    if (utilization >= 75) return AppTheme.errorRed;
    if (utilization >= 50) return const Color(0xFFFFAB00);
    return const Color(0xFF00E5FF);
  }

  Color _getReliabilityColor(double reliability) {
    if (reliability < 0.5) return AppTheme.errorRed;
    if (reliability < 0.8) return const Color(0xFFFFAB00);
    return const Color(0xFF00FF88);
  }

  String _getReliabilityLabel(BuildContext context, double reliability) {
    if (reliability < 0.5) return context.l10n.meshHealthReliabilityPoor;
    if (reliability < 0.8) return context.l10n.meshHealthReliabilityFair;
    return context.l10n.meshHealthReliabilityGood;
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
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: AppTheme.spacing6),
              Text(
                title,
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
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
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_getSeverityIcon(issue.severity), color: color, size: 20),
          const SizedBox(width: AppTheme.spacing10),
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
                        borderRadius: BorderRadius.circular(AppTheme.radius4),
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
                    const SizedBox(width: AppTheme.spacing6),
                    Text(
                      issue.severityLabel,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  issue.message,
                  style: TextStyle(color: context.textPrimary, fontSize: 13),
                ),
                if (issue.nodeId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      context.l10n.meshHealthNodePrefix(issue.nodeId!),
                      style: TextStyle(
                        color: context.textTertiary,
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
        return AppTheme.errorRed;
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
                  : context.textPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
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
                    : context.textTertiary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      node.nodeId,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 13,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    if (node.isSpamming) ...[
                      const SizedBox(width: AppTheme.spacing6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFAB00).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppTheme.radius3),
                        ),
                        child: Text(
                          context.l10n.meshHealthSpamBadge,
                          style: TextStyle(
                            color: Color(0xFFFFAB00),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    if (node.isHopFlooding) ...[
                      const SizedBox(width: AppTheme.spacing6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppTheme.radius3),
                        ),
                        child: Text(
                          context.l10n.meshHealthFloodBadge,
                          style: TextStyle(
                            color: AppTheme.errorRed,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  context.l10n.meshHealthPacketsAirtime(
                    node.packetCount,
                    node.totalAirtimeMs,
                  ),
                  style: TextStyle(color: context.textTertiary, fontSize: 11),
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
                context.l10n.meshHealthOfAirtime,
                style: TextStyle(color: context.textTertiary, fontSize: 10),
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
      painter: _UtilizationGraphPainter(
        data: data,
        gridColor: context.textPrimary.withValues(alpha: 0.1),
      ),
    );
  }
}

class _UtilizationGraphPainter extends CustomPainter {
  final List<UtilizationDataPoint> data;
  final Color gridColor;

  _UtilizationGraphPainter({required this.data, required this.gridColor});

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
      ..color = gridColor
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
    return oldDelegate.data != data || oldDelegate.gridColor != gridColor;
  }
}
