// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_content.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../../features/onboarding/widgets/mesh_node_brain.dart';
import '../../../providers/help_providers.dart';
import '../../../services/haptic_service.dart';

/// Help Center screen with searchable topics, category filtering, and tour replay
class HelpCenterScreen extends ConsumerStatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  ConsumerState<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends ConsumerState<HelpCenterScreen>
    with LifecycleSafeMixin<HelpCenterScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HelpTopic> _filteredTopics(HelpState helpState) {
    var topics = _selectedCategory != null
        ? HelpContent.getTopicsByCategory(_selectedCategory!)
        : HelpContent.topicsByPriority;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      topics = topics.where((topic) {
        return topic.title.toLowerCase().contains(query) ||
            topic.description.toLowerCase().contains(query) ||
            topic.steps.any(
              (step) => step.bubbleText.toLowerCase().contains(query),
            );
      }).toList();
    }

    return topics;
  }

  int _completedCount(HelpState helpState) {
    return HelpContent.allTopics
        .where((t) => helpState.isTopicCompleted(t.id))
        .length;
  }

  int _categoryCount(String category) {
    return HelpContent.getTopicsByCategory(category).length;
  }

  /// Group topics by category, preserving category order from HelpContent.
  Map<String, List<HelpTopic>> _groupByCategory(List<HelpTopic> topics) {
    final grouped = <String, List<HelpTopic>>{};
    // Maintain category ordering from HelpContent.allCategories
    for (final cat in HelpContent.allCategories) {
      final catTopics = topics.where((t) => t.category == cat).toList();
      if (catTopics.isNotEmpty) {
        grouped[cat] = catTopics;
      }
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final helpState = ref.watch(helpProvider);
    final topics = _filteredTopics(helpState);
    final completedCount = _completedCount(helpState);
    final totalCount = HelpContent.allTopics.length;
    final isSearching = _searchQuery.isNotEmpty;
    final isFiltered = _selectedCategory != null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        resizeToAvoidBottomInset: false,
        title: 'Help Center',
        slivers: [
          // Ico mascot + progress header
          SliverToBoxAdapter(
            child: _ProgressHeader(
              completedCount: completedCount,
              totalCount: totalCount,
            ),
          ),

          // Pinned search + category filter chips
          SliverPersistentHeader(
            pinned: true,
            delegate: SearchFilterHeaderDelegate(
              textScaler: MediaQuery.textScalerOf(context),
              searchController: _searchController,
              searchQuery: _searchQuery,
              hintText: 'Search help topics',
              onSearchChanged: (value) {
                safeSetState(() => _searchQuery = value);
              },
              rebuildKey: Object.hashAll([
                _selectedCategory,
                completedCount,
                totalCount,
              ]),
              filterChips: [
                SectionFilterChip(
                  label: 'All',
                  count: totalCount,
                  isSelected: _selectedCategory == null,
                  onTap: () {
                    ref.haptics.toggle();
                    safeSetState(() => _selectedCategory = null);
                  },
                ),
                ...HelpContent.allCategories.map(
                  (category) => SectionFilterChip(
                    label: category,
                    count: _categoryCount(category),
                    isSelected: _selectedCategory == category,
                    color: _categoryColor(category),
                    icon: _categoryIcon(category),
                    onTap: () {
                      ref.haptics.toggle();
                      safeSetState(() => _selectedCategory = category);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Content: grouped topics, empty state, or search results
          if (topics.isEmpty)
            _buildEmptyState(isSearching, isFiltered)
          else if (_selectedCategory == null && !isSearching)
            // Grouped by category with sticky headers
            ..._buildGroupedSlivers(topics, helpState)
          else
            // Flat list for filtered / search views
            _buildFlatList(topics, helpState),

          // Settings section
          SliverToBoxAdapter(
            child: _HelpSettingsSection(
              helpState: helpState,
              onResetProgress: () => _showResetDialog(),
            ),
          ),

          // Bottom safe area padding
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sliver builders
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(bool isSearching, bool isFiltered) {
    if (isSearching) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AnimatedEmptyState(
          config: AnimatedEmptyStateConfig(
            icons: const [
              Icons.search_off_rounded,
              Icons.help_outline,
              Icons.lightbulb_outline,
              Icons.school_outlined,
            ],
            taglines: const [
              'No topics match your search.\nTry different keywords.',
              'Search by topic name, description,\nor step content.',
            ],
            titlePrefix: 'No ',
            titleKeyword: 'results',
            titleSuffix: ' found',
          ),
        ),
      );
    }

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.help_outline,
                size: 56,
                color: context.textTertiary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                isFiltered
                    ? 'No topics in this category'
                    : 'No help topics available',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isFiltered
                    ? 'Try selecting a different category from the filter chips above.'
                    : 'Help content is being prepared. Check back soon.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.textTertiary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedSlivers(
    List<HelpTopic> topics,
    HelpState helpState,
  ) {
    final grouped = _groupByCategory(topics);
    final slivers = <Widget>[];

    for (final entry in grouped.entries) {
      final category = entry.key;
      final categoryTopics = entry.value;

      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: category,
            count: categoryTopics.length,
          ),
        ),
      );

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final topic = categoryTopics[index];
              final isCompleted = helpState.isTopicCompleted(topic.id);
              return _HelpTopicTile(
                topic: topic,
                isCompleted: isCompleted,
                onTap: () => _startTour(topic.id),
              );
            }, childCount: categoryTopics.length),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildFlatList(List<HelpTopic> topics, HelpState helpState) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final topic = topics[index];
          final isCompleted = helpState.isTopicCompleted(topic.id);
          return _HelpTopicTile(
            topic: topic,
            isCompleted: isCompleted,
            onTap: () => _startTour(topic.id),
          );
        }, childCount: topics.length),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _startTour(String topicId) {
    ref.haptics.buttonTap();

    // Capture refs before any async gap
    final helpNotifier = ref.read(helpProvider.notifier);
    final helpState = ref.read(helpProvider);

    // Reset topic if already completed (replay)
    if (helpState.isTopicCompleted(topicId)) {
      helpNotifier.resetTopic(topicId);
    }

    // Navigate back and start tour
    Navigator.pop(context);

    // Delay to allow navigation to complete, then start tour
    Future.delayed(const Duration(milliseconds: 500), () {
      // helpNotifier is a captured Notifier — safe to call even if
      // this widget is disposed, since it operates on provider state
      // not widget state.
      helpNotifier.startTour(topicId);
    });
  }

  Future<void> _showResetDialog() async {
    ref.haptics.buttonTap();

    // Capture notifier before await
    final helpNotifier = ref.read(helpProvider.notifier);

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Reset Help Progress?',
      message:
          'This will mark all help topics as unread and show help hints again. '
          'You can replay any tour from the help center.',
      confirmLabel: 'Reset',
      isDestructive: true,
    );

    if (!mounted) return;

    if (confirmed == true) {
      HapticFeedback.heavyImpact();
      helpNotifier.resetAll();
    }
  }

  // ---------------------------------------------------------------------------
  // Category theming
  // ---------------------------------------------------------------------------

  Color _categoryColor(String category) {
    return switch (category) {
      HelpContent.catChannels => AccentColors.blue,
      HelpContent.catMessaging => AccentColors.green,
      HelpContent.catNodes => AccentColors.yellow,
      HelpContent.catDevice => AccentColors.orange,
      HelpContent.catNetwork => AccentColors.cyan,
      HelpContent.catAutomations => AccentColors.purple,
      HelpContent.catSettings => AccentColors.pink,
      HelpContent.catLegal => AccentColors.red,
      _ => AppTheme.primaryMagenta,
    };
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      HelpContent.catChannels => Icons.forum_outlined,
      HelpContent.catMessaging => Icons.chat_outlined,
      HelpContent.catNodes => Icons.hexagon_outlined,
      HelpContent.catDevice => Icons.developer_board_outlined,
      HelpContent.catNetwork => Icons.cell_tower,
      HelpContent.catAutomations => Icons.bolt_outlined,
      HelpContent.catSettings => Icons.tune,
      HelpContent.catLegal => Icons.gavel_outlined,
      _ => Icons.help_outline,
    };
  }
}

// =============================================================================
// Progress Header
// =============================================================================

class _ProgressHeader extends StatelessWidget {
  final int completedCount;
  final int totalCount;

  const _ProgressHeader({
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    final allDone = completedCount == totalCount && totalCount > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          // Ico mascot
          SizedBox(
            width: 72,
            height: 72,
            child: MeshNodeBrain(
              mood: allDone ? MeshBrainMood.happy : MeshBrainMood.inviting,
              size: 60,
            ),
          ),
          const SizedBox(width: 16),

          // Text + progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allDone
                      ? 'Great work! All topics complete.'
                      : 'Hey! I\'m Ico, your mesh guide.',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  allDone
                      ? 'You can replay any tour anytime.'
                      : 'Tap a topic to learn with interactive guides.',
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 10),

                // Progress bar + count
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: context.border.withValues(
                            alpha: 0.3,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            allDone
                                ? AppTheme.successGreen
                                : AppTheme.primaryMagenta,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$completedCount / $totalCount',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
// Help Topic Tile
// =============================================================================

class _HelpTopicTile extends StatelessWidget {
  final HelpTopic topic;
  final bool isCompleted;
  final VoidCallback onTap;

  const _HelpTopicTile({
    required this.topic,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCompleted
                ? AppTheme.successGreen.withValues(alpha: 0.3)
                : context.border,
            width: isCompleted ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Topic icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppTheme.successGreen.withValues(alpha: 0.1)
                    : AppTheme.primaryMagenta.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                topic.icon,
                color: isCompleted
                    ? AppTheme.successGreen
                    : AppTheme.primaryMagenta,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Title + description + metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          topic.title,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isCompleted)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.check_circle,
                            color: AppTheme.successGreen,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    topic.description,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _MetadataChip(
                        icon: Icons.play_circle_outline,
                        label: '${topic.steps.length} steps',
                      ),
                      _MetadataChip(
                        icon: isCompleted ? Icons.replay : Icons.play_arrow,
                        label: isCompleted ? 'Replay' : 'Start',
                        color: isCompleted
                            ? AppTheme.successGreen
                            : AppTheme.primaryMagenta,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Metadata Chip (inline label for topic cards)
// =============================================================================

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MetadataChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? context.textTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: chipColor),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: chipColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Help Settings Section
// =============================================================================

class _HelpSettingsSection extends ConsumerWidget {
  final HelpState helpState;
  final VoidCallback onResetProgress;

  const _HelpSettingsSection({
    required this.helpState,
    required this.onResetProgress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HELP PREFERENCES',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Show Help Hints toggle
          _HelpSettingRow(
            icon: Icons.lightbulb_outline,
            title: 'Show Help Hints',
            subtitle: 'Display pulsing help buttons on screens',
            trailing: ThemedSwitch(
              value: !helpState.skipFutureHelp,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                ref.read(helpProvider.notifier).setSkipFutureHelp(!value);
              },
            ),
          ),

          Divider(color: context.border.withValues(alpha: 0.3), height: 16),

          // Haptic Feedback toggle
          _HelpSettingRow(
            icon: Icons.vibration,
            title: 'Haptic Feedback',
            subtitle: 'Vibrate during typewriter text effect',
            trailing: ThemedSwitch(
              value: helpState.hapticFeedback,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                ref.read(helpProvider.notifier).setHapticFeedback(value);
              },
            ),
          ),

          const SizedBox(height: 12),

          // Reset progress button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onResetProgress,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset All Help Progress'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AccentColors.cyan,
                side: BorderSide(color: AccentColors.cyan),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Help Setting Row (replaces SwitchListTile)
// =============================================================================

class _HelpSettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _HelpSettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.textSecondary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: context.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }
}
