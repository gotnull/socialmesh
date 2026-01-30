import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/ico_help_system.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../providers/app_providers.dart';
import '../../providers/help_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/edge_fade.dart';
import 'automation_providers.dart';
import 'automation_repository.dart';
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
      child: Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          centerTitle: true,
          title: const Text('Automations'),
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
        ),
        body: automationsAsync.when(
          data: (automations) {
            if (automations.isEmpty) {
              return _buildEmptyState(context, ref);
            }
            return _buildAutomationsList(context, ref, automations, stats);
          },
          loading: () => const ScreenLoadingIndicator(),
          error: (error, _) => Center(
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
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: context.card,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bolt,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Automations Yet',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Create automations to trigger actions automatically when events occur on your mesh network.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            // Quick start templates
            Text(
              'Quick Start Templates',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: EdgeFade.horizontal(
                fadeSize: 24,
                fadeColor: context.background,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: AutomationRepository.templates.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final template = AutomationRepository.templates[index];
                    return BouncyTap(
                      onTap: () => _addFromTemplate(context, ref, template.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(template.icon, size: 20),
                            const SizedBox(width: 8),
                            Text(template.name),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomationsList(
    BuildContext context,
    WidgetRef ref,
    List<Automation> automations,
    AutomationStats stats,
  ) {
    return CustomScrollView(
      slivers: [
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
                  ),
                ),
              );
            }, childCount: automations.length),
          ),
        ),

        // Bottom padding for FAB
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
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
    await ref.read(automationsProvider.notifier).addFromTemplate(templateId);
    if (context.mounted) {
      showSuccessSnackBar(context, 'Automation created from template');
    }
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

/// Bottom sheet for adding automations
class _AddAutomationSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add Automation',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
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
                              Text(
                                'Create from Scratch',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 4),
                              Text(
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
