import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_content.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../features/onboarding/widgets/mesh_node_brain.dart';
import '../../../providers/help_providers.dart';

/// Help Center screen with searchable topics and tour replay
class HelpCenterScreen extends ConsumerStatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  ConsumerState<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends ConsumerState<HelpCenterScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HelpTopic> get _filteredTopics {
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

  @override
  Widget build(BuildContext context) {
    final helpState = ref.watch(helpProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Help Center'),
      ),
      body: Column(
        children: [
          // Ico mascot header
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: MeshNodeBrain(mood: MeshBrainMood.inviting, size: 80),
                ),
                const SizedBox(height: 16),
                Text(
                  'Hey! I\'m Ico, your mesh guide.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'I\'ll help you understand Meshtastic!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search for help...',
                hintStyle: TextStyle(color: context.textSecondary),
                prefixIcon: Icon(Icons.search, color: context.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: context.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryMagenta,
                    width: 2,
                  ),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          const SizedBox(height: 16),

          // Category filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildCategoryChip(null, 'All'),
                ...HelpContent.allCategories.map(
                  (category) => _buildCategoryChip(category, category),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Help topics list
          Expanded(
            child: _filteredTopics.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: context.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No topics found',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredTopics.length,
                    itemBuilder: (context, index) {
                      final topic = _filteredTopics[index];
                      final isCompleted = helpState.isTopicCompleted(topic.id);
                      return _buildTopicCard(topic, isCompleted);
                    },
                  ),
          ),

          // Settings section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surface,
              border: Border(top: BorderSide(color: context.border, width: 1)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Show Help Hints',
                    style: TextStyle(color: context.textPrimary),
                  ),
                  subtitle: Text(
                    'Display pulsing help buttons on screens',
                    style: TextStyle(color: context.textSecondary),
                  ),
                  value: !helpState.skipFutureHelp,
                  onChanged: (value) {
                    ref.read(helpProvider.notifier).setSkipFutureHelp(!value);
                  },
                  activeTrackColor: AppTheme.primaryMagenta,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showResetDialog(context),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset All Help Progress'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AccentColors.cyan,
                    side: BorderSide(color: AccentColors.cyan),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String? category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _selectedCategory = category);
        },
        backgroundColor: context.surface,
        selectedColor: AppTheme.primaryMagenta.withValues(alpha: 0.2),
        checkmarkColor: AppTheme.primaryMagenta,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryMagenta : context.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryMagenta : context.border,
          width: isSelected ? 2 : 1,
        ),
      ),
    );
  }

  Widget _buildTopicCard(HelpTopic topic, bool isCompleted) {
    return BouncyTap(
      onTap: () => _startTour(topic.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryMagenta.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(topic.icon, color: AppTheme.primaryMagenta),
            ),
            const SizedBox(width: 16),

            // Content
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
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isCompleted)
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.successGreen,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topic.description,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 14,
                        color: context.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        topic.category,
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.list, size: 14, color: context.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        '${topic.steps.length} steps',
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action icon
            Icon(
              isCompleted ? Icons.replay : Icons.play_arrow,
              color: AppTheme.primaryMagenta,
            ),
          ],
        ),
      ),
    );
  }

  void _startTour(String topicId) {
    final helpNotifier = ref.read(helpProvider.notifier);

    // Reset topic if already completed (replay)
    final helpState = ref.read(helpProvider);
    if (helpState.isTopicCompleted(topicId)) {
      helpNotifier.resetTopic(topicId);
    }

    // Navigate back and start tour
    Navigator.pop(context);

    // Delay to allow navigation to complete
    Future.delayed(const Duration(milliseconds: 500), () {
      helpNotifier.startTour(topicId);
    });
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Reset Help Progress?'),
        content: const Text(
          'This will mark all help topics as unread and show help hints again. You can replay any tour from the help center.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(helpProvider.notifier).resetAll();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryMagenta,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
