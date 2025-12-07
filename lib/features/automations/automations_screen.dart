import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/animations.dart';
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

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Automations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Execution Log',
            onPressed: () => _showExecutionLog(context, ref),
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
        loading: () => const Center(child: CircularProgressIndicator()),
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
      floatingActionButton: BouncyTap(
        onTap: () => _showAddAutomation(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'New Automation',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
                color: AppTheme.darkCard,
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
            const SizedBox(height: 24),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: AutomationRepository.templates.map((template) {
                return BouncyTap(
                  onTap: () => _addFromTemplate(context, ref, template.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkBorder),
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
              }).toList(),
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
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.darkBorder),
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
                Container(width: 1, height: 40, color: AppTheme.darkBorder),
                _buildStatItem(
                  context,
                  label: 'Active',
                  value: stats.enabled.toString(),
                  icon: Icons.play_circle,
                  color: AppTheme.successGreen,
                ),
                Container(width: 1, height: 40, color: AppTheme.darkBorder),
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SlideInAnimation(
                  delay: Duration(milliseconds: index * 50),
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
      backgroundColor: AppTheme.darkSurface,
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
      ),
    );
  }

  void _createNewAutomation(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AutomationEditorScreen()),
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
      showAppSnackBar(context, 'Automation created from template');
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
        backgroundColor: AppTheme.darkSurface,
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
              showAppSnackBar(context, 'Deleted "${automation.name}"');
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
      backgroundColor: AppTheme.darkSurface,
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

  const _AddAutomationSheet({
    required this.onCreateNew,
    required this.onSelectTemplate,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
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
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkBorder),
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create from Scratch',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Build a custom automation',
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

                const SizedBox(height: 16),
                Text(
                  'Templates',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 12),

                // Templates
                ...AutomationRepository.templates.map(
                  (template) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: BouncyTap(
                      onTap: () => onSelectTemplate(template.id),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(template.icon, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    template.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    template.description,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.add_circle_outline,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
