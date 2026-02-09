// SPDX-License-Identifier: GPL-3.0-or-later

/// Global Layer Topic Explorer Screen — manage and monitor MQTT topic
/// subscriptions for the Global Layer feature.
///
/// Shows:
/// - Portal visualization at the top showing traffic flow
/// - List of subscribed topics with enable/disable toggles
/// - Per-topic message rate and last message timestamp
/// - Add custom topic capability
/// - Remove topic via swipe or long-press
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mqtt/mqtt_config.dart';
import '../../../core/mqtt/mqtt_connection_state.dart';
import '../../../core/mqtt/mqtt_constants.dart';
import '../../../core/mqtt/mqtt_metrics.dart';
import '../../../core/mqtt/mqtt_topic_builder.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/accessibility_providers.dart';
import '../../../providers/mqtt_providers.dart';
import '../../../services/haptic_service.dart';
import '../widgets/portal_view.dart';

/// Topic Explorer screen for managing Global Layer topic subscriptions.
///
/// Provides a full view of all configured topics with controls to
/// enable/disable, add, and remove subscriptions. The portal view
/// at the top gives a visual summary of traffic flow direction.
class GlobalLayerTopicExplorerScreen extends ConsumerStatefulWidget {
  const GlobalLayerTopicExplorerScreen({super.key});

  @override
  ConsumerState<GlobalLayerTopicExplorerScreen> createState() =>
      _GlobalLayerTopicExplorerScreenState();
}

class _GlobalLayerTopicExplorerScreenState
    extends ConsumerState<GlobalLayerTopicExplorerScreen>
    with LifecycleSafeMixin<GlobalLayerTopicExplorerScreen> {
  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _toggleSubscription(int index, {required bool enabled}) async {
    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticType.selection);

    if (!mounted) return;
    await ref
        .read(globalLayerConfigProvider.notifier)
        .toggleSubscription(index, enabled: enabled);
  }

  Future<void> _removeSubscription(int index) async {
    final haptics = ref.read(hapticServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    await haptics.trigger(HapticType.warning);

    if (!mounted) return;

    final configAsync = ref.read(globalLayerConfigProvider);
    final config = configAsync.value;
    if (config == null) return;
    if (index < 0 || index >= config.subscriptions.length) return;

    final removedTopic = config.subscriptions[index];

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Remove Topic',
      message:
          'Remove "${removedTopic.label}" (${removedTopic.topic}) from your '
          'subscriptions? You can add it back later.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    final updatedConfig = config.removeSubscription(index);
    await ref
        .read(globalLayerConfigProvider.notifier)
        .updateConfig(updatedConfig);

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Removed "${removedTopic.label}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            ref.read(globalLayerConfigProvider.notifier).updateConfig(config);
          },
        ),
      ),
    );
  }

  Future<void> _addCustomTopic() async {
    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticType.light);

    if (!mounted) return;

    final result = await AppBottomSheet.show<_NewTopicResult>(
      context: context,
      child: const _AddTopicSheet(),
    );

    if (result == null || !mounted) return;

    final configAsync = ref.read(globalLayerConfigProvider);
    final config = configAsync.value;
    if (config == null) return;

    final newSub = TopicSubscription(
      topic: result.topic,
      label: result.label,
      enabled: true,
    );

    final updatedConfig = config.addSubscription(newSub);
    await ref
        .read(globalLayerConfigProvider.notifier)
        .updateConfig(updatedConfig);
  }

  Future<void> _addFromTemplate() async {
    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticType.light);

    if (!mounted) return;

    final configAsync = ref.read(globalLayerConfigProvider);
    final config = configAsync.value;
    if (config == null) return;

    final existingTopics = config.subscriptions.map((s) => s.topic).toSet();

    final result = await AppBottomSheet.show<TopicSubscription>(
      context: context,
      child: _TemplatePickerSheet(
        topicRoot: config.topicRoot,
        existingTopics: existingTopics,
      ),
    );

    if (result == null || !mounted) return;

    final updatedConfig = config.addSubscription(result);
    await ref
        .read(globalLayerConfigProvider.notifier)
        .updateConfig(updatedConfig);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(globalLayerConfigProvider);
    final connectionState = ref.watch(globalLayerConnectionStateProvider);
    final metrics = ref.watch(globalLayerMetricsProvider);

    return GlassScaffold(
      title: 'Topic Explorer',
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'add_custom':
                _addCustomTopic();
              case 'add_template':
                _addFromTemplate();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'add_template',
              child: ListTile(
                leading: Icon(Icons.library_add_outlined),
                title: Text('Add from Template'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'add_custom',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Add Custom Topic'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
      slivers: [
        // Portal visualization
        const SliverToBoxAdapter(child: PortalView(height: 160)),

        // Connection status pill
        SliverToBoxAdapter(
          child: _ConnectionStatusPill(connectionState: connectionState),
        ),

        // Subscription stats
        configAsync.when(
          data: (config) => SliverToBoxAdapter(
            child: _SubscriptionStats(config: config, metrics: metrics),
          ),
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),

        // Section header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subscriptions',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                BouncyTap(
                  onTap: _addFromTemplate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: context.accentColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: context.accentColor),
                        const SizedBox(width: 4),
                        Text(
                          'Add',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: context.accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Topic list
        configAsync.when(
          data: (config) {
            if (config.subscriptions.isEmpty) {
              return SliverToBoxAdapter(
                child: _EmptyTopicsState(
                  onAddTemplate: _addFromTemplate,
                  onAddCustom: _addCustomTopic,
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final sub = config.subscriptions[index];
                final topicMetrics = _metricsForTopic(metrics, sub.topic);

                return _TopicSubscriptionTile(
                  subscription: sub,
                  index: index,
                  metrics: topicMetrics,
                  isConnected: connectionState.isActive,
                  onToggle: (enabled) =>
                      _toggleSubscription(index, enabled: enabled),
                  onRemove: () => _removeSubscription(index),
                );
              }, childCount: config.subscriptions.length),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Failed to load topics: $error',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),

        // Bottom safe area padding
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
        ),
      ],
    );
  }

  /// Extracts per-topic metrics from the global metrics object.
  ///
  /// Uses the [GlobalLayerMetrics.messageCountsByTopic] breakdown to
  /// find counts for a specific topic. Returns null if no data exists.
  _TopicMetrics? _metricsForTopic(GlobalLayerMetrics metrics, String topic) {
    final counts = metrics.messageCountsByTopic;
    final count = counts[topic];
    if (count == null || count == 0) return null;

    return _TopicMetrics(messageCount: count);
  }
}

// =============================================================================
// Data Models
// =============================================================================

/// Per-topic metrics extracted from global metrics.
class _TopicMetrics {
  final int messageCount;

  const _TopicMetrics({required this.messageCount});
}

/// Result from the Add Topic sheet.
class _NewTopicResult {
  final String topic;
  final String label;

  const _NewTopicResult({required this.topic, required this.label});
}

// =============================================================================
// Connection Status Pill
// =============================================================================

class _ConnectionStatusPill extends StatelessWidget {
  final GlobalLayerConnectionState connectionState;

  const _ConnectionStatusPill({required this.connectionState});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: connectionState.statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: connectionState.statusColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connectionState.statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  connectionState.displayLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: connectionState.statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Subscription Stats Card
// =============================================================================

class _SubscriptionStats extends StatelessWidget {
  final GlobalLayerConfig config;
  final GlobalLayerMetrics metrics;

  const _SubscriptionStats({required this.config, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final total = config.subscriptions.length;
    final enabled = config.enabledSubscriptions.length;
    final totalMessages = metrics.totalMessages;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: _StatColumn(
                value: total.toString(),
                label: 'Topics',
                icon: Icons.tag,
                color: context.accentColor,
              ),
            ),
            _VerticalDivider(color: context.border),
            Expanded(
              child: _StatColumn(
                value: enabled.toString(),
                label: 'Active',
                icon: Icons.check_circle_outline,
                color: AppTheme.successGreen,
              ),
            ),
            _VerticalDivider(color: context.border),
            Expanded(
              child: _StatColumn(
                value: _compactNumber(totalMessages),
                label: 'Messages',
                icon: Icons.chat_bubble_outline,
                color: const Color(0xFF60A5FA),
              ),
            ),
            _VerticalDivider(color: context.border),
            Expanded(
              child: _StatColumn(
                value: metrics.throughputDisplay,
                label: 'Rate',
                icon: Icons.speed,
                color: AppTheme.warningYellow,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compactNumber(int n) {
    if (n < 1000) return n.toString();
    if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}k';
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(0)}k';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatColumn({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.w700,
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.textTertiary,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  final Color color;

  const _VerticalDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: color);
  }
}

// =============================================================================
// Topic Subscription Tile
// =============================================================================

class _TopicSubscriptionTile extends StatelessWidget {
  final TopicSubscription subscription;
  final int index;
  final _TopicMetrics? metrics;
  final bool isConnected;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;

  const _TopicSubscriptionTile({
    required this.subscription,
    required this.index,
    required this.metrics,
    required this.isConnected,
    required this.onToggle,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(reduceMotionEnabledProvider);

    return Dismissible(
      key: ValueKey('topic_${subscription.topic}_$index'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onRemove();
        return false; // We handle removal ourselves with confirmation
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.errorRed.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
      ),
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : AppDurations.standard,
        curve: AppCurves.smooth,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: subscription.enabled
                ? context.accentColor.withValues(alpha: 0.2)
                : context.border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onLongPress: onRemove,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Topic icon
                  _TopicIcon(
                    label: subscription.label,
                    isEnabled: subscription.enabled,
                  ),

                  const SizedBox(width: 12),

                  // Topic info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label
                        Text(
                          subscription.label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 2),

                        // Topic string
                        Text(
                          subscription.topic,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: context.textTertiary,
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        // Metrics row
                        _TopicMetricsRow(
                          subscription: subscription,
                          metrics: metrics,
                          isConnected: isConnected,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Enable/disable toggle
                  ThemedSwitch(
                    value: subscription.enabled,
                    onChanged: (value) => onToggle(value),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Topic Icon
// =============================================================================

class _TopicIcon extends StatelessWidget {
  final String label;
  final bool isEnabled;

  const _TopicIcon({required this.label, required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    final icon = _iconForLabel(label);
    final color = isEnabled ? context.accentColor : context.textTertiary;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  IconData _iconForLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('chat') || lower.contains('message')) {
      return Icons.chat_bubble_outline;
    }
    if (lower.contains('telemetry') || lower.contains('health')) {
      return Icons.monitor_heart_outlined;
    }
    if (lower.contains('position') || lower.contains('gps')) {
      return Icons.location_on_outlined;
    }
    if (lower.contains('node') || lower.contains('info')) {
      return Icons.info_outline;
    }
    if (lower.contains('map')) {
      return Icons.map_outlined;
    }
    return Icons.tag;
  }
}

// =============================================================================
// Topic Metrics Row
// =============================================================================

class _TopicMetricsRow extends StatelessWidget {
  final TopicSubscription subscription;
  final _TopicMetrics? metrics;
  final bool isConnected;

  const _TopicMetricsRow({
    required this.subscription,
    required this.metrics,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Message count
        if (metrics != null) ...[
          _MetricChip(
            icon: Icons.chat_bubble_outline,
            value: '${metrics!.messageCount}',
            color: context.accentColor,
          ),
          const SizedBox(width: 8),
        ],

        // Last message timestamp
        if (subscription.lastMessageAt != null) ...[
          _MetricChip(
            icon: Icons.access_time,
            value: _formatTimestamp(subscription.lastMessageAt!),
            color: context.textTertiary,
          ),
          const SizedBox(width: 8),
        ],

        // Status indicator
        if (!subscription.enabled)
          _MetricChip(
            icon: Icons.pause_circle_outline,
            value: 'Paused',
            color: context.textTertiary,
          )
        else if (isConnected && metrics == null)
          _MetricChip(
            icon: Icons.hearing,
            value: 'Listening',
            color: AppTheme.successGreen.withValues(alpha: 0.7),
          )
        else if (!isConnected)
          _MetricChip(
            icon: Icons.cloud_off,
            value: 'Offline',
            color: context.textTertiary,
          ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.month}/${timestamp.day}';
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          value,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 10,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Empty Topics State
// =============================================================================

class _EmptyTopicsState extends StatelessWidget {
  final VoidCallback onAddTemplate;
  final VoidCallback onAddCustom;

  const _EmptyTopicsState({
    required this.onAddTemplate,
    required this.onAddCustom,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.rss_feed,
            size: 48,
            color: context.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Topic Subscriptions',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Add topics to control which types of mesh data flow '
            'through the Global Layer. Each topic corresponds to a '
            'category like chat, telemetry, or position.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onAddTemplate,
                icon: const Icon(Icons.library_add_outlined, size: 18),
                label: const Text('From Template'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onAddCustom,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Custom'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Add Custom Topic Bottom Sheet
// =============================================================================

class _AddTopicSheet extends ConsumerStatefulWidget {
  const _AddTopicSheet();

  @override
  ConsumerState<_AddTopicSheet> createState() => _AddTopicSheetState();
}

class _AddTopicSheetState extends ConsumerState<_AddTopicSheet> {
  final _labelController = TextEditingController();
  final _topicController = TextEditingController();
  TopicValidationResult? _validation;

  @override
  void dispose() {
    _labelController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  void _validate() {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      setState(() => _validation = null);
      return;
    }
    setState(() {
      _validation = TopicBuilder.validateTopic(topic, allowWildcards: true);
    });
  }

  bool get _canSubmit {
    final label = _labelController.text.trim();
    final topic = _topicController.text.trim();
    return label.isNotEmpty &&
        topic.isNotEmpty &&
        (_validation?.isValid ?? false);
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(
      _NewTopicResult(
        topic: _topicController.text.trim(),
        label: _labelController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Add Custom Topic',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Subscribe to a custom MQTT topic. Wildcards (+, #) '
            'are allowed for subscribe topics.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 20),

          // Label field
          TextField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: 'Label',
              hintText: 'e.g. Weather Reports',
              prefixIcon: const Icon(Icons.label_outline, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Topic field
          TextField(
            controller: _topicController,
            decoration: InputDecoration(
              labelText: 'MQTT Topic',
              hintText: 'e.g. msh/weather/+',
              prefixIcon: const Icon(Icons.tag, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              errorText: _validation != null && !_validation!.isValid
                  ? _validation!.error
                  : null,
              suffixIcon: _validation != null && _validation!.isValid
                  ? const Icon(Icons.check_circle, color: AppTheme.successGreen)
                  : null,
            ),
            textInputAction: TextInputAction.done,
            onChanged: (_) => _validate(),
            onSubmitted: (_) {
              if (_canSubmit) _submit();
            },
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSubmit ? _submit : null,
              child: const Text('Add Subscription'),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Template Picker Bottom Sheet
// =============================================================================

class _TemplatePickerSheet extends StatefulWidget {
  final String topicRoot;
  final Set<String> existingTopics;

  const _TemplatePickerSheet({
    required this.topicRoot,
    required this.existingTopics,
  });

  @override
  State<_TemplatePickerSheet> createState() => _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends State<_TemplatePickerSheet> {
  final _channelController = TextEditingController(text: 'LongFast');
  final _nodeIdController = TextEditingController();

  @override
  void dispose() {
    _channelController.dispose();
    _nodeIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templates = TopicTemplate.builtIn;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add from Template',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a predefined topic template. Placeholders will '
            'be resolved using the values below.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 16),

          // Placeholder inputs
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _channelController,
                  decoration: InputDecoration(
                    labelText: 'Channel',
                    hintText: 'LongFast',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: context.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nodeIdController,
                  decoration: InputDecoration(
                    labelText: 'Node ID',
                    hintText: '!a1b2c3d4',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Template list
          ...templates.map((template) {
            final resolved = TopicBuilder.resolveTemplate(
              template: template,
              topicRoot: widget.topicRoot,
              channel: _channelController.text.trim().isNotEmpty
                  ? _channelController.text.trim()
                  : null,
              nodeId: _nodeIdController.text.trim().isNotEmpty
                  ? _nodeIdController.text.trim()
                  : null,
            );

            final alreadyAdded = widget.existingTopics.contains(resolved.topic);
            final hasUnresolved = !TopicBuilder.isFullyResolved(resolved.topic);

            return _TemplateTile(
              template: template,
              resolvedTopic: resolved.topic,
              alreadyAdded: alreadyAdded,
              hasUnresolved: hasUnresolved,
              onTap: (alreadyAdded || hasUnresolved)
                  ? null
                  : () {
                      Navigator.of(context).pop(
                        TopicSubscription(
                          topic: resolved.topic,
                          label: template.label,
                          enabled: true,
                        ),
                      );
                    },
            );
          }),
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final TopicTemplate template;
  final String resolvedTopic;
  final bool alreadyAdded;
  final bool hasUnresolved;
  final VoidCallback? onTap;

  const _TemplateTile({
    required this.template,
    required this.resolvedTopic,
    required this.alreadyAdded,
    required this.hasUnresolved,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = alreadyAdded || hasUnresolved;
    final textColor = isDisabled ? context.textTertiary : context.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDisabled
                    ? context.border.withValues(alpha: 0.5)
                    : context.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _iconForTemplate(template.iconName),
                  size: 20,
                  color: isDisabled
                      ? context.textTertiary
                      : context.accentColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        resolvedTopic,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.textTertiary,
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (alreadyAdded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.textTertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Added',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  )
                else if (hasUnresolved)
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: context.textTertiary,
                  )
                else
                  Icon(
                    Icons.add_circle_outline,
                    size: 20,
                    color: context.accentColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForTemplate(String iconName) {
    return switch (iconName) {
      'chat_bubble_outline' => Icons.chat_bubble_outline,
      'monitor_heart_outlined' => Icons.monitor_heart_outlined,
      'location_on_outlined' => Icons.location_on_outlined,
      'info_outline' => Icons.info_outline,
      'map_outlined' => Icons.map_outlined,
      _ => Icons.tag,
    };
  }
}
