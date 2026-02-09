// SPDX-License-Identifier: GPL-3.0-or-later

/// Global Layer Status Screen — always-accessible dashboard for the
/// Global Layer (MQTT) connection.
///
/// Shows:
/// - Connection state with animated indicator
/// - Broker identity and last connected timestamp
/// - Health metrics: last ping, reconnect count, errors, throughput
/// - Quick actions: Connect/Disconnect, Run Diagnostics, Pause, Reset
/// - Recent state transition history
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mqtt/mqtt_config.dart';
import '../../../core/mqtt/mqtt_connection_state.dart';
import '../../../core/mqtt/mqtt_constants.dart';
import '../../../core/mqtt/mqtt_metrics.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/mqtt_providers.dart';
import '../../../services/haptic_service.dart';

import 'global_layer_diagnostics_screen.dart';
import 'global_layer_setup_wizard.dart';
import 'global_layer_topic_explorer_screen.dart';

/// Status dashboard for the Global Layer feature.
///
/// This screen is shown when setup has been completed. It provides
/// full observability into the MQTT connection and quick actions
/// for non-technical users.
class GlobalLayerStatusScreen extends ConsumerStatefulWidget {
  const GlobalLayerStatusScreen({super.key});

  @override
  ConsumerState<GlobalLayerStatusScreen> createState() =>
      _GlobalLayerStatusScreenState();
}

class _GlobalLayerStatusScreenState
    extends ConsumerState<GlobalLayerStatusScreen>
    with TickerProviderStateMixin, LifecycleSafeMixin<GlobalLayerStatusScreen> {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _handleConnectDisconnect() async {
    final haptics = ref.read(hapticServiceProvider);
    final connectionNotifier = ref.read(
      globalLayerConnectionStateProvider.notifier,
    );
    final connectionState = ref.read(globalLayerConnectionStateProvider);

    await haptics.trigger(HapticType.medium);

    if (connectionState.isActive) {
      connectionNotifier.disconnect(reason: 'User tapped Disconnect');
      // Simulate disconnect completion for V1
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      connectionNotifier.markDisconnected(reason: 'Disconnect complete');
    } else if (connectionState == GlobalLayerConnectionState.disconnected ||
        connectionState == GlobalLayerConnectionState.error) {
      connectionNotifier.connect(reason: 'User tapped Connect');
      // Simulate connection for V1
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      connectionNotifier.markConnected(reason: 'Connection established');
      ref.read(globalLayerMetricsProvider.notifier).startSession();
      ref.read(globalLayerConfigProvider.notifier).recordConnection();
    }
  }

  Future<void> _handlePause() async {
    final haptics = ref.read(hapticServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    await haptics.trigger(HapticType.medium);

    final connectionNotifier = ref.read(
      globalLayerConnectionStateProvider.notifier,
    );
    final configNotifier = ref.read(globalLayerConfigProvider.notifier);

    connectionNotifier.disconnect(reason: 'User paused Global Layer');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    connectionNotifier.markDisconnected(reason: 'Paused');
    await configNotifier.disable();

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Global Layer paused')),
    );
  }

  Future<void> _handleResume() async {
    final haptics = ref.read(hapticServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    await haptics.trigger(HapticType.medium);

    final configNotifier = ref.read(globalLayerConfigProvider.notifier);
    await configNotifier.enable();

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Global Layer resumed')),
    );
  }

  void _openDiagnostics() {
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const GlobalLayerDiagnosticsScreen(),
      ),
    );
  }

  void _openTopicExplorer() {
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const GlobalLayerTopicExplorerScreen(),
      ),
    );
  }

  Future<void> _handleReset() async {
    final navigator = Navigator.of(context);
    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticType.warning);

    if (!mounted) return;

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Reset Global Layer',
      message:
          'This will clear all broker configuration, credentials, and '
          'connection history. You will need to run the setup wizard again.',
      confirmLabel: 'Reset',
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    final configNotifier = ref.read(globalLayerConfigProvider.notifier);
    await configNotifier.reset();

    if (!mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const GlobalLayerSetupWizard()),
    );
  }

  Future<void> _copyDiagnosticsSummary() async {
    final haptics = ref.read(hapticServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    await haptics.trigger(HapticType.light);

    final storage = ref.read(globalLayerStorageProvider);
    final summary = await storage.getRedactedDiagnosticsString();

    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: summary));

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Diagnostics copied to clipboard')),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(globalLayerConfigProvider);
    final connectionState = ref.watch(globalLayerConnectionStateProvider);
    final metrics = ref.watch(globalLayerMetricsProvider);
    final transitions = ref.watch(globalLayerTransitionHistoryProvider);

    return GlassScaffold(
      title: GlobalLayerConstants.featureLabel,
      actions: [
        IconButton(
          icon: const Icon(Icons.copy_outlined),
          tooltip: 'Copy diagnostics',
          onPressed: _copyDiagnosticsSummary,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'topics':
                _openTopicExplorer();
              case 'diagnostics':
                _openDiagnostics();
              case 'reconfigure':
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GlobalLayerSetupWizard(),
                  ),
                );
              case 'reset':
                _handleReset();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'topics',
              child: ListTile(
                leading: Icon(Icons.rss_feed),
                title: Text('Topic Explorer'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'diagnostics',
              child: ListTile(
                leading: Icon(Icons.troubleshoot),
                title: Text('Run Diagnostics'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'reconfigure',
              child: ListTile(
                leading: Icon(Icons.settings),
                title: Text('Reconfigure'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'reset',
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Reset', style: TextStyle(color: Colors.red)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
      slivers: [
        // Connection state hero
        SliverToBoxAdapter(
          child: _ConnectionStateHero(
            connectionState: connectionState,
            pulseController: _pulseController,
          ),
        ),

        // Broker info card
        configAsync.when(
          data: (config) =>
              SliverToBoxAdapter(child: _BrokerInfoCard(config: config)),
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),

        // Quick actions
        SliverToBoxAdapter(
          child: _QuickActionsSection(
            connectionState: connectionState,
            isEnabled: configAsync.whenOrNull(data: (c) => c.enabled) ?? false,
            onConnectDisconnect: _handleConnectDisconnect,
            onPause: _handlePause,
            onResume: _handleResume,
            onDiagnostics: _openDiagnostics,
            onTopics: _openTopicExplorer,
          ),
        ),

        // Health metrics
        SliverToBoxAdapter(
          child: _HealthMetricsCard(
            metrics: metrics,
            connectionState: connectionState,
          ),
        ),

        // Privacy summary
        configAsync.when(
          data: (config) => SliverToBoxAdapter(
            child: _PrivacySummaryCard(privacy: config.privacy),
          ),
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),

        // Transition history
        if (transitions.isNotEmpty) ...[
          SliverToBoxAdapter(child: _SectionHeader(title: 'Recent Activity')),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              // Show most recent first
              final transition = transitions[transitions.length - 1 - index];
              return _TransitionTile(transition: transition);
            }, childCount: transitions.length.clamp(0, 20)),
          ),
        ],

        // Bottom safe area padding
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Connection State Hero
// =============================================================================

class _ConnectionStateHero extends StatelessWidget {
  final GlobalLayerConnectionState connectionState;
  final AnimationController pulseController;

  const _ConnectionStateHero({
    required this.connectionState,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final shouldPulse = connectionState.shouldAnimate;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: connectionState.statusColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // Animated status icon
            shouldPulse
                ? AnimatedBuilder(
                    animation: pulseController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: 0.5 + (pulseController.value * 0.5),
                        child: child,
                      );
                    },
                    child: _StatusIcon(connectionState: connectionState),
                  )
                : _StatusIcon(connectionState: connectionState),

            const SizedBox(height: 16),

            // Status label
            Text(
              connectionState.displayLabel,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            // Status description
            Text(
              connectionState.displayDescription,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final GlobalLayerConnectionState connectionState;

  const _StatusIcon({required this.connectionState});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: connectionState.statusColor.withValues(alpha: 0.15),
        border: Border.all(
          color: connectionState.statusColor.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: Icon(
        connectionState.icon,
        size: 36,
        color: connectionState.statusColor,
      ),
    );
  }
}

// =============================================================================
// Broker Info Card
// =============================================================================

class _BrokerInfoCard extends StatelessWidget {
  final GlobalLayerConfig config;

  const _BrokerInfoCard({required this.config});

  @override
  Widget build(BuildContext context) {
    if (!config.hasBrokerConfig) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.dns_outlined,
                  size: 18,
                  color: context.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Broker',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Host', value: config.host),
            const SizedBox(height: 6),
            _InfoRow(label: 'Port', value: '${config.effectivePort}'),
            const SizedBox(height: 6),
            _InfoRow(
              label: 'TLS',
              value: config.useTls ? 'Enabled' : 'Disabled',
              valueColor: config.useTls ? const Color(0xFF4ADE80) : null,
            ),
            if (config.username.isNotEmpty) ...[
              const SizedBox(height: 6),
              _InfoRow(label: 'User', value: config.username),
            ],
            if (config.lastConnectedAt != null) ...[
              const SizedBox(height: 6),
              _InfoRow(
                label: 'Last connected',
                value: _formatTimestamp(config.lastConnectedAt!),
              ),
            ],
            const SizedBox(height: 6),
            _InfoRow(
              label: 'Topics',
              value: '${config.enabledSubscriptions.length} active',
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: valueColor ?? context.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Quick Actions Section
// =============================================================================

class _QuickActionsSection extends StatelessWidget {
  final GlobalLayerConnectionState connectionState;
  final bool isEnabled;
  final VoidCallback onConnectDisconnect;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onDiagnostics;
  final VoidCallback onTopics;

  const _QuickActionsSection({
    required this.connectionState,
    required this.isEnabled,
    required this.onConnectDisconnect,
    required this.onPause,
    required this.onResume,
    required this.onDiagnostics,
    required this.onTopics,
  });

  @override
  Widget build(BuildContext context) {
    final allowsActions = connectionState.allowsUserActions;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: context.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            children: [
              // Connect / Disconnect button
              Expanded(
                child: _ActionButton(
                  icon: connectionState.isActive
                      ? Icons.cloud_off_outlined
                      : Icons.cloud_outlined,
                  label: connectionState.isActive ? 'Disconnect' : 'Connect',
                  onTap: allowsActions ? onConnectDisconnect : null,
                  color: connectionState.isActive
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF4ADE80),
                ),
              ),
              const SizedBox(width: 8),
              // Pause / Resume button
              Expanded(
                child: _ActionButton(
                  icon: isEnabled
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  label: isEnabled ? 'Pause' : 'Resume',
                  onTap: isEnabled ? onPause : onResume,
                  color: const Color(0xFFFBBF24),
                ),
              ),
              const SizedBox(width: 8),
              // Diagnostics button
              Expanded(
                child: _ActionButton(
                  icon: Icons.troubleshoot,
                  label: 'Diagnose',
                  onTap: onDiagnostics,
                  color: context.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Topic Explorer button
              Expanded(
                child: _ActionButton(
                  icon: Icons.rss_feed,
                  label: 'Topics',
                  onTap: onTopics,
                  color: const Color(0xFF60A5FA),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    final effectiveColor = isDisabled
        ? context.textTertiary.withValues(alpha: 0.5)
        : color;

    return BouncyTap(
      onTap: onTap,
      enabled: !isDisabled,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: effectiveColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: effectiveColor),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: effectiveColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Health Metrics Card
// =============================================================================

class _HealthMetricsCard extends StatelessWidget {
  final GlobalLayerMetrics metrics;
  final GlobalLayerConnectionState connectionState;

  const _HealthMetricsCard({
    required this.metrics,
    required this.connectionState,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monitor_heart_outlined,
                  size: 18,
                  color: context.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Health',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (connectionState.isActive)
                  _HealthBadge(isHealthy: metrics.isHealthy),
              ],
            ),
            const SizedBox(height: 12),

            // Metrics grid
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    icon: Icons.speed,
                    label: 'Ping',
                    value: metrics.lastPingMs != null
                        ? '${metrics.lastPingMs}ms'
                        : '--',
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.sync,
                    label: 'Reconnects',
                    value: '${metrics.reconnectCount}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    icon: Icons.arrow_downward,
                    label: 'Inbound',
                    value: '${metrics.totalInbound}',
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.arrow_upward,
                    label: 'Outbound',
                    value: '${metrics.totalOutbound}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    icon: Icons.data_usage,
                    label: 'Throughput',
                    value: metrics.throughputDisplay,
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.timer_outlined,
                    label: 'Session',
                    value: metrics.sessionDurationDisplay,
                  ),
                ),
              ],
            ),

            // Errors summary
            if (metrics.activeErrorCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      size: 18,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${metrics.activeErrorCount} active '
                        '${metrics.activeErrorCount == 1 ? 'error' : 'errors'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFEF4444),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (metrics.lastError != null)
                      Flexible(
                        child: Text(
                          metrics.lastError!.type.displayLabel,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.7),
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  final bool isHealthy;

  const _HealthBadge({required this.isHealthy});

  @override
  Widget build(BuildContext context) {
    final color = isHealthy ? const Color(0xFF4ADE80) : const Color(0xFFEF4444);
    final label = isHealthy ? 'Healthy' : 'Unhealthy';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: context.textTertiary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textTertiary,
                fontSize: 9,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Privacy Summary Card
// =============================================================================

class _PrivacySummaryCard extends StatelessWidget {
  final GlobalLayerPrivacySettings privacy;

  const _PrivacySummaryCard({required this.privacy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: context.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Privacy',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (!privacy.isAnythingShared)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'All Off',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF4ADE80),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _PrivacyToggleRow(
              label: 'Share Messages',
              description: 'Forward local messages to broker',
              isEnabled: privacy.shareMessages,
            ),
            const SizedBox(height: 6),
            _PrivacyToggleRow(
              label: 'Share Telemetry',
              description: 'Publish device health data',
              isEnabled: privacy.shareTelemetry,
            ),
            const SizedBox(height: 6),
            _PrivacyToggleRow(
              label: 'Accept Inbound',
              description: 'Receive messages from broker',
              isEnabled: privacy.allowInboundGlobal,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyToggleRow extends StatelessWidget {
  final String label;
  final String description;
  final bool isEnabled;

  const _PrivacyToggleRow({
    required this.label,
    required this.description,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isEnabled
        ? const Color(0xFFFBBF24)
        : const Color(0xFF4ADE80);
    final statusLabel = isEnabled ? 'ON' : 'OFF';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            statusLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Section Header
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: context.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// =============================================================================
// Transition History Tile
// =============================================================================

class _TransitionTile extends StatelessWidget {
  final GlobalLayerStateTransition transition;

  const _TransitionTile({required this.transition});

  @override
  Widget build(BuildContext context) {
    final toState = transition.to;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // State color dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: toState.statusColor,
              ),
            ),
            const SizedBox(width: 10),

            // Transition description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${transition.from.displayLabel} \u2192 '
                    '${toState.displayLabel}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (transition.reason != null)
                    Text(
                      transition.reason!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (transition.errorMessage != null)
                    Text(
                      transition.errorMessage!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFEF4444),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Timestamp
            Text(
              _formatAge(transition.age),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAge(Duration age) {
    if (age.inSeconds < 60) return '${age.inSeconds}s ago';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }
}
