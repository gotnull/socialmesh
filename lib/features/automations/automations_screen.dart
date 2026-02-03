// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/premium_gating.dart';
import '../../models/subscription_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/help_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/subscription_providers.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/edge_fade.dart';
import 'automation_providers.dart';
import 'automation_repository.dart';
import 'automation_share_utils.dart';
import 'models/automation.dart';
import 'widgets/automation_card.dart';
import 'automation_editor_screen.dart';

/// Screen showing all configured automations
class AutomationsScreen extends ConsumerWidget {
  const AutomationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final automationsAsync = ref.watch(automationsProvider);
    final stats = ref.watch(automationStatsProvider);

    return HelpTourController(
      topicId: 'automations_overview',
      stepKeys: const {},
      child: GlassScaffold(
        title: 'Automations',
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Execution Log',
            onPressed: () => _showExecutionLog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Automation',
            onPressed: () => _showAddAutomation(context, ref),
          ),
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              if (value == 'help') {
                ref
                    .read(helpProvider.notifier)
                    .startTour('automations_overview');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'help',
                child: ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text('Help'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        slivers: automationsAsync.when(
          data: (automations) {
            if (automations.isEmpty) {
              return _buildEmptyStateSlivers(context, ref);
            }
            return _buildAutomationsListSlivers(
              context,
              ref,
              automations,
              stats,
            );
          },
          loading: () => [
            const SliverFillRemaining(
              hasScrollBody: false,
              child: ScreenLoadingIndicator(),
            ),
          ],
          error: (error, _) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppTheme.errorRed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load automations',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          ref.read(automationsProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the first-visit/empty state as a guided automation builder - returns slivers
  /// This transforms "empty list" into "invitation to create"
  List<Widget> _buildEmptyStateSlivers(BuildContext context, WidgetRef ref) {
    final hasAutomationsPack = ref.watch(
      hasFeatureProvider(PremiumFeature.automations),
    );

    return [
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            // Hero section - What this is
            _buildHeroSection(context, hasAutomationsPack),

            const SizedBox(height: 24),

            // Create from scratch CTA - Primary action
            _buildCreateFromScratchCard(context, ref, hasAutomationsPack),

            const SizedBox(height: 24),

            // Quick Start Templates - Secondary inspiration
            _buildTemplatesSection(context, ref, hasAutomationsPack),

            const SizedBox(height: 24),

            // Start with a Trigger - Exploration path
            _buildTriggerCategoriesSection(context, ref, hasAutomationsPack),

            // Bottom padding
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ]),
        ),
      ),
    ];
  }

  /// Hero section explaining what automations are
  Widget _buildHeroSection(BuildContext context, bool hasAutomationsPack) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.1),
            accentColor.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withValues(alpha: 0.7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.bolt, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'Automate Your Mesh',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Create automations to trigger actions automatically when events occur on your mesh network.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Primary CTA to create from scratch
  Widget _buildCreateFromScratchCard(
    BuildContext context,
    WidgetRef ref,
    bool hasAutomationsPack,
  ) {
    return BouncyTap(
      onTap: () => _createNewAutomation(context, ref),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.add,
                size: 28,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create from Scratch',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Build a custom automation with full control over triggers and actions',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.textTertiary),
          ],
        ),
      ),
    );
  }

  /// Quick Start Templates section
  Widget _buildTemplatesSection(
    BuildContext context,
    WidgetRef ref,
    bool hasAutomationsPack,
  ) {
    final templates = AutomationRepository.templates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Icon(Icons.flash_on, size: 18, color: Colors.amber),
              const SizedBox(width: 6),
              Text(
                'Quick Start Templates',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'One-tap setup for common use cases',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: EdgeFade.horizontal(
            fadeSize: 24,
            fadeColor: context.background,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: templates.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final template = templates[index];
                return BouncyTap(
                  onTap: () => _addFromTemplate(context, ref, template.id),
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _getTemplateColor(
                              template.id,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            template.icon,
                            size: 20,
                            color: _getTemplateColor(template.id),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          template.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Get color for template based on its type
  Color _getTemplateColor(String templateId) {
    switch (templateId) {
      case 'low_battery_alert':
        return Colors.amber;
      case 'node_offline_alert':
        return Colors.red;
      case 'geofence_exit':
        return Colors.purple;
      case 'sos_response':
        return Colors.red.shade700;
      case 'dead_mans_switch':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  /// Trigger categories section for exploration
  Widget _buildTriggerCategoriesSection(
    BuildContext context,
    WidgetRef ref,
    bool hasAutomationsPack,
  ) {
    final triggersByCategory = _getTriggersByCategory();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Icon(Icons.explore, size: 18, color: context.accentColor),
              const SizedBox(width: 6),
              Text(
                'Start with a Trigger',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Choose what event starts your automation',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
          ),
        ),
        const SizedBox(height: 16),

        // Build categories
        ..._categoryOrder.map((category) {
          final triggers = triggersByCategory[category];
          if (triggers == null || triggers.isEmpty) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category header
                Row(
                  children: [
                    Icon(
                      _categoryIcon(category),
                      size: 14,
                      color: _categoryColor(context, category),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _categoryColor(context, category),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Trigger chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: triggers.map((type) {
                    return BouncyTap(
                      onTap: () => _createWithTrigger(context, ref, type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(type.icon, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              type.displayName,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Map<String, List<TriggerType>> _getTriggersByCategory() {
    final grouped = <String, List<TriggerType>>{};
    for (final type in TriggerType.values) {
      final category = type.category;
      grouped.putIfAbsent(category, () => []).add(type);
    }
    return grouped;
  }

  static const _categoryOrder = [
    'Node Status',
    'Battery',
    'Messages',
    'Location',
    'Time',
    'Signal',
    'Sensors',
    'Manual',
  ];

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Node Status':
        return Icons.router;
      case 'Battery':
        return Icons.battery_std;
      case 'Messages':
        return Icons.chat;
      case 'Location':
        return Icons.location_on;
      case 'Time':
        return Icons.schedule;
      case 'Signal':
        return Icons.signal_cellular_alt;
      case 'Sensors':
        return Icons.sensors;
      case 'Manual':
        return Icons.touch_app;
      default:
        return Icons.bolt;
    }
  }

  Color _categoryColor(BuildContext context, String category) {
    switch (category) {
      case 'Node Status':
        return Colors.blue;
      case 'Battery':
        return Colors.amber;
      case 'Messages':
        return Colors.green;
      case 'Location':
        return Colors.purple;
      case 'Time':
        return Colors.cyan;
      case 'Signal':
        return Colors.orange;
      case 'Sensors':
        return Colors.red;
      case 'Manual':
        return Theme.of(context).colorScheme.primary;
      default:
        return Colors.grey;
    }
  }

  List<Widget> _buildAutomationsListSlivers(
    BuildContext context,
    WidgetRef ref,
    List<Automation> automations,
    AutomationStats stats,
  ) {
    return [
      // Stats header
      SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                label: 'Total',
                value: stats.total.toString(),
                icon: Icons.bolt,
              ),
              Container(width: 1, height: 40, color: context.border),
              _buildStatItem(
                context,
                label: 'Active',
                value: stats.enabled.toString(),
                icon: Icons.play_circle,
                color: AppTheme.successGreen,
              ),
              Container(width: 1, height: 40, color: context.border),
              _buildStatItem(
                context,
                label: 'Executions',
                value: stats.totalTriggers.toString(),
                icon: Icons.trending_up,
              ),
            ],
          ),
        ),
      ),

      // Automations list
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final automation = automations[index];
            final animationsEnabled = ref.watch(animationsEnabledProvider);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Perspective3DSlide(
                index: index,
                direction: SlideDirection.left,
                enabled: animationsEnabled,
                child: AutomationCard(
                  automation: automation,
                  onToggle: (enabled) {
                    ref
                        .read(automationsProvider.notifier)
                        .toggleAutomation(automation.id, enabled);
                  },
                  onTap: () => _editAutomation(context, ref, automation),
                  onDelete: () => _confirmDelete(context, ref, automation),
                  onShare: () => _shareAutomation(context, ref, automation),
                ),
              ),
            );
          }, childCount: automations.length),
        ),
      ),

      // Bottom padding for FAB
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ];
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color ?? Colors.grey),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  void _showAddAutomation(BuildContext context, WidgetRef ref) {
    // Check premium before allowing automation creation
    final hasPremium = ref.read(hasFeatureProvider(PremiumFeature.automations));
    if (!hasPremium) {
      showPremiumInfoSheet(
        context: context,
        ref: ref,
        feature: PremiumFeature.automations,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddAutomationSheet(
        onCreateNew: () {
          Navigator.pop(context);
          _createNewAutomation(context, ref);
        },
        onSelectTemplate: (templateId) {
          Navigator.pop(context);
          _addFromTemplate(context, ref, templateId);
        },
        onSelectTrigger: (triggerType) {
          Navigator.pop(context);
          _createWithTrigger(context, ref, triggerType);
        },
      ),
    );
  }

  void _createNewAutomation(BuildContext context, WidgetRef ref) {
    // Check premium before allowing automation creation
    final hasPremium = ref.read(hasFeatureProvider(PremiumFeature.automations));
    if (!hasPremium) {
      showPremiumInfoSheet(
        context: context,
        ref: ref,
        feature: PremiumFeature.automations,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AutomationEditorScreen()),
    );
  }

  void _createWithTrigger(
    BuildContext context,
    WidgetRef ref,
    TriggerType triggerType,
  ) {
    // Check premium before allowing automation creation
    final hasPremium = ref.read(hasFeatureProvider(PremiumFeature.automations));
    if (!hasPremium) {
      showPremiumInfoSheet(
        context: context,
        ref: ref,
        feature: PremiumFeature.automations,
      );
      return;
    }

    // Create a new automation with pre-filled trigger type
    final automation = Automation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${triggerType.displayName} Alert',
      description: triggerType.defaultDescription,
      trigger: AutomationTrigger(type: triggerType),
      actions: [const AutomationAction(type: ActionType.pushNotification)],
      enabled: true,
      createdAt: DateTime.now(),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AutomationEditorScreen(automation: automation, isNew: true),
      ),
    );
  }

  void _editAutomation(
    BuildContext context,
    WidgetRef ref,
    Automation automation,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AutomationEditorScreen(automation: automation),
      ),
    );
  }

  Future<void> _addFromTemplate(
    BuildContext context,
    WidgetRef ref,
    String templateId,
  ) async {
    // Check premium before adding template
    final hasPremium = ref.read(hasFeatureProvider(PremiumFeature.automations));
    if (!hasPremium) {
      showPremiumInfoSheet(
        context: context,
        ref: ref,
        feature: PremiumFeature.automations,
      );
      return;
    }

    await ref.read(automationsProvider.notifier).addFromTemplate(templateId);
    if (context.mounted) {
      showSuccessSnackBar(context, 'Automation created from template');
    }
  }

  void _shareAutomation(
    BuildContext context,
    WidgetRef ref,
    Automation automation,
  ) {
    showAutomationShareSheet(context, automation, ref: ref);
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Automation automation,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surface,
        title: const Text('Delete Automation'),
        content: Text('Are you sure you want to delete "${automation.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(automationsProvider.notifier)
                  .deleteAutomation(automation.id);
              showSuccessSnackBar(context, 'Deleted "${automation.name}"');
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showExecutionLog(BuildContext context, WidgetRef ref) {
    final log = ref.read(automationLogProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Execution Log',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (log.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(automationRepositoryProvider).clearLog();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: log.isEmpty
                  ? const Center(
                      child: Text(
                        'No executions yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: log.length,
                      itemBuilder: (context, index) {
                        final entry = log[index];
                        return ListTile(
                          leading: Icon(
                            entry.success ? Icons.check_circle : Icons.error,
                            color: entry.success
                                ? AppTheme.successGreen
                                : AppTheme.errorRed,
                          ),
                          title: Text(entry.automationName),
                          subtitle: Text(
                            entry.triggerDetails ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            _formatTime(entry.timestamp),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Bottom sheet for adding automations (when user has existing automations)
class _AddAutomationSheet extends ConsumerWidget {
  final VoidCallback onCreateNew;
  final void Function(String templateId) onSelectTemplate;
  final void Function(TriggerType triggerType) onSelectTrigger;

  const _AddAutomationSheet({
    required this.onCreateNew,
    required this.onSelectTemplate,
    required this.onSelectTrigger,
  });

  /// Get trigger types grouped by category
  Map<String, List<TriggerType>> get _triggersByCategory {
    final grouped = <String, List<TriggerType>>{};
    for (final type in TriggerType.values) {
      final category = type.category;
      grouped.putIfAbsent(category, () => []).add(type);
    }
    return grouped;
  }

  /// Category order for display
  static const _categoryOrder = [
    'Node Status',
    'Battery',
    'Messages',
    'Location',
    'Time',
    'Signal',
    'Sensors',
    'Manual',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title with premium badge if needed
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Add Automation',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Scrollable content
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Create from scratch
                BouncyTap(
                  onTap: onCreateNew,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.15),
                          Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.add,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Create from Scratch',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Build a custom automation with full control',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Templates section
                Text(
                  'Quick Start Templates',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 12),

                // Templates in horizontal scroll
                SizedBox(
                  height: 100,
                  child: EdgeFade.horizontal(
                    fadeSize: 24,
                    fadeColor: context.surface,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: AutomationRepository.templates.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final template = AutomationRepository.templates[index];
                        return BouncyTap(
                          onTap: () => onSelectTemplate(template.id),
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(template.icon, size: 24),
                                const Spacer(),
                                Text(
                                  template.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Trigger types by category
                Text(
                  'Start with Trigger',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a trigger type to get started quickly',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),

                // Build trigger categories
                ..._buildTriggerCategories(context),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTriggerCategories(BuildContext context) {
    final widgets = <Widget>[];
    final grouped = _triggersByCategory;

    for (final category in _categoryOrder) {
      final triggers = grouped[category];
      if (triggers == null || triggers.isEmpty) continue;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              Icon(
                _categoryIcon(category),
                size: 16,
                color: _categoryColor(context, category),
              ),
              const SizedBox(width: 8),
              Text(
                category,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _categoryColor(context, category),
                ),
              ),
            ],
          ),
        ),
      );

      widgets.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: triggers
              .map((type) => _buildTriggerChip(context, type))
              .toList(),
        ),
      );

      widgets.add(const SizedBox(height: 8));
    }

    return widgets;
  }

  Widget _buildTriggerChip(BuildContext context, TriggerType type) {
    return BouncyTap(
      onTap: () => onSelectTrigger(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 16),
            const SizedBox(width: 6),
            Text(type.displayName, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Node Status':
        return Icons.router;
      case 'Battery':
        return Icons.battery_std;
      case 'Messages':
        return Icons.chat;
      case 'Location':
        return Icons.location_on;
      case 'Time':
        return Icons.schedule;
      case 'Signal':
        return Icons.signal_cellular_alt;
      case 'Sensors':
        return Icons.sensors;
      case 'Manual':
        return Icons.touch_app;
      default:
        return Icons.bolt;
    }
  }

  Color _categoryColor(BuildContext context, String category) {
    switch (category) {
      case 'Node Status':
        return Colors.blue;
      case 'Battery':
        return Colors.amber;
      case 'Messages':
        return Colors.green;
      case 'Location':
        return Colors.purple;
      case 'Time':
        return Colors.cyan;
      case 'Signal':
        return Colors.orange;
      case 'Sensors':
        return Colors.red;
      case 'Manual':
        return Theme.of(context).colorScheme.primary;
      default:
        return Colors.grey;
    }
  }
}
