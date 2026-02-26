// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_article.dart';
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
import '../../../providers/help_article_providers.dart';
import '../../../providers/help_providers.dart';
import '../../../services/haptic_service.dart';
import 'help_article_screen.dart';

/// Help Center screen with knowledge-base articles and guided tours.
///
/// The main view shows educational articles about Meshtastic, searchable
/// and filterable by category. An expandable section at the bottom provides
/// access to the in-app guided tour system.
class HelpCenterScreen extends ConsumerStatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  ConsumerState<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends ConsumerState<HelpCenterScreen>
    with LifecycleSafeMixin<HelpCenterScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  HelpArticleCategory? _selectedCategory;
  bool _showInteractiveTours = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HelpArticle> _filteredArticles(List<HelpArticle> articles) {
    var result = _selectedCategory != null
        ? articles.where((a) => a.category == _selectedCategory).toList()
        : articles;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((article) {
        return article.title.toLowerCase().contains(query) ||
            article.description.toLowerCase().contains(query);
      }).toList();
    }

    return result;
  }

  int _categoryCount(List<HelpArticle> articles, HelpArticleCategory category) {
    return articles.where((a) => a.category == category).length;
  }

  /// Group articles by category, preserving enum order.
  Map<HelpArticleCategory, List<HelpArticle>> _groupByCategory(
    List<HelpArticle> articles,
  ) {
    final grouped = <HelpArticleCategory, List<HelpArticle>>{};
    for (final cat in HelpArticleCategory.values) {
      final catArticles = articles.where((a) => a.category == cat).toList();
      if (catArticles.isNotEmpty) {
        grouped[cat] = catArticles;
      }
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final articlesAsync = ref.watch(helpArticlesProvider);
    final readState = ref.watch(helpArticleReadProvider);
    final helpState = ref.watch(helpProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: articlesAsync.when(
        data: (articles) =>
            _buildContent(context, articles, readState, helpState),
        loading: () => GlassScaffold(
          title: 'Help Center',
          slivers: [
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        error: (_, _) => GlassScaffold(
          title: 'Help Center',
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Failed to load help content',
                  style: TextStyle(color: context.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<HelpArticle> articles,
    HelpArticleReadState readState,
    HelpState helpState,
  ) {
    final filtered = _filteredArticles(articles);
    final readCount = readState.readCount(articles);
    final totalCount = articles.length;
    final isSearching = _searchQuery.isNotEmpty;
    final isFiltered = _selectedCategory != null;

    return GlassScaffold(
      resizeToAvoidBottomInset: false,
      title: 'Help Center',
      slivers: [
        // Ico mascot + progress header (pinned, collapses on scroll)
        SliverPersistentHeader(
          pinned: true,
          delegate: _ProgressHeaderDelegate(
            completedCount: readCount,
            totalCount: totalCount,
            label: 'articles read',
          ),
        ),

        // Pinned search + category filter chips
        SliverPersistentHeader(
          pinned: true,
          delegate: SearchFilterHeaderDelegate(
            textScaler: MediaQuery.textScalerOf(context),
            searchController: _searchController,
            searchQuery: _searchQuery,
            hintText: 'Search articles',
            onSearchChanged: (value) {
              safeSetState(() => _searchQuery = value);
            },
            rebuildKey: Object.hashAll([
              _selectedCategory,
              readCount,
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
              ...HelpArticleCategory.values.map(
                (category) => SectionFilterChip(
                  label: category.displayName,
                  count: _categoryCount(articles, category),
                  isSelected: _selectedCategory == category,
                  color: category.color,
                  icon: category.icon,
                  onTap: () {
                    ref.haptics.toggle();
                    safeSetState(() => _selectedCategory = category);
                  },
                ),
              ),
            ],
          ),
        ),

        // Content: grouped articles, empty state, or search results
        if (filtered.isEmpty)
          _buildEmptyState(isSearching, isFiltered)
        else if (_selectedCategory == null && !isSearching)
          // Grouped by category with sticky headers
          ..._buildGroupedSlivers(filtered, readState)
        else
          // Flat list for filtered / search views
          _buildFlatList(filtered, readState),

        // Interactive Tours expandable section
        SliverToBoxAdapter(
          child: _InteractiveToursSection(
            helpState: helpState,
            isExpanded: _showInteractiveTours,
            onToggle: () {
              ref.haptics.toggle();
              safeSetState(
                () => _showInteractiveTours = !_showInteractiveTours,
              );
            },
            onTopicTap: (topic, isCompleted) =>
                _showTopicDetail(topic, isCompleted),
          ),
        ),

        // Settings section
        SliverToBoxAdapter(
          child: _HelpSettingsSection(
            helpState: helpState,
            readState: readState,
            onResetProgress: () => _showResetDialog(),
          ),
        ),

        // Bottom safe area padding
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.of(context).padding.bottom + AppTheme.spacing16,
          ),
        ),
      ],
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
              Icons.article_outlined,
              Icons.lightbulb_outline,
              Icons.school_outlined,
            ],
            taglines: const [
              'No articles match your search.\nTry different keywords.',
              'Search by article title\nor description.',
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
                Icons.article_outlined,
                size: 56,
                color: context.textTertiary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                isFiltered
                    ? 'No articles in this category'
                    : 'No articles available',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                isFiltered
                    ? 'Try selecting a different category from the '
                          'filter chips above.'
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
    List<HelpArticle> articles,
    HelpArticleReadState readState,
  ) {
    final grouped = _groupByCategory(articles);
    final slivers = <Widget>[];

    for (final entry in grouped.entries) {
      final category = entry.key;
      final categoryArticles = entry.value;

      slivers.add(
        SliverPersistentHeader(
          pinned: false,
          delegate: SectionHeaderDelegate(
            title: category.displayName,
            count: categoryArticles.length,
          ),
        ),
      );

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final article = categoryArticles[index];
              final isRead = readState.isRead(article.id);
              return _HelpArticleTile(
                article: article,
                isRead: isRead,
                onTap: () => _openArticle(article),
              );
            }, childCount: categoryArticles.length),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildFlatList(
    List<HelpArticle> articles,
    HelpArticleReadState readState,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final article = articles[index];
          final isRead = readState.isRead(article.id);
          return _HelpArticleTile(
            article: article,
            isRead: isRead,
            onTap: () => _openArticle(article),
          );
        }, childCount: articles.length),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _openArticle(HelpArticle article) {
    ref.haptics.buttonTap();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HelpArticleScreen(article: article)),
    );
  }

  void _showTopicDetail(HelpTopic topic, bool isCompleted) {
    ref.haptics.buttonTap();

    AppBottomSheet.showScrollable(
      context: context,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      title: topic.title,
      footer: isCompleted
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppTheme.successGreen,
                  size: 18,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  'Completed',
                  style: TextStyle(
                    color: AppTheme.successGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final helpNotifier = ref.read(helpProvider.notifier);
                  helpNotifier.startTour(topic.id);
                  helpNotifier.completeTour();
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryMagenta,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacing14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
                child: const Text(
                  'Mark as Complete',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
      builder: (scrollController) {
        return _TopicDetailContent(
          topic: topic,
          isCompleted: isCompleted,
          scrollController: scrollController,
          screenName: _screenNameForTopic(topic.id),
        );
      },
    );
  }

  /// Returns a human-readable screen name for a topic.
  String? _screenNameForTopic(String topicId) {
    return switch (topicId) {
      'channels_overview' ||
      'channel_creation' ||
      'encryption_levels' => 'Channels',
      'message_routing' => 'Messages',
      'nodes_overview' || 'node_roles' => 'Nodes',
      'signals_overview' || 'signal_detail' => 'Signal Feed',
      'signal_creation' => 'Create Signal',
      'device_connection' => 'Scanner',
      'region_selection' => 'Region Selection',
      'radio_config_overview' => 'Radio Config',
      'signal_metrics' => 'Nodes',
      'mesh_health_overview' => 'Mesh Health',
      'reachability_overview' => 'Reachability',
      'traceroute_overview' => 'Trace Route Log',
      'map_overview' => 'Map',
      'world_mesh_overview' => 'World Mesh',
      'globe_overview' => 'Globe',
      'mesh_3d_overview' => 'Mesh 3D',
      'routes_overview' => 'Routes',
      'timeline_overview' => 'Timeline',
      'presence_overview' => 'Presence',
      'aether_overview' => 'Aether',
      'tak_gateway_overview' => 'TAK Gateway',
      'dashboard_overview' => 'Widget Dashboard',
      'widget_builder_overview' => 'Widget Builder',
      'marketplace_overview' => 'Widget Marketplace',
      'device_shop_overview' => 'Device Shop',
      'nodedex_overview' ||
      'nodedex_album' ||
      'nodedex_detail' ||
      'nodedex_constellation' => 'NodeDex',
      'settings_overview' => 'Settings',
      'profile_overview' => 'Profile',
      'automations_overview' => 'Automations',
      _ => null,
    };
  }

  Future<void> _showResetDialog() async {
    ref.haptics.buttonTap();

    // Capture notifiers before await
    final helpNotifier = ref.read(helpProvider.notifier);
    final readNotifier = ref.read(helpArticleReadProvider.notifier);

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Reset Help Progress?',
      message:
          'This will mark all articles as unread and reset interactive tour '
          'progress. You can start fresh.',
      confirmLabel: 'Reset',
      isDestructive: true,
    );

    if (!mounted) return;

    if (confirmed == true) {
      HapticFeedback.heavyImpact();
      helpNotifier.resetAll();
      readNotifier.resetAll();
    }
  }
}

// =============================================================================
// Progress Header Delegate (pinned, collapses on scroll)
// =============================================================================

class _ProgressHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int completedCount;
  final int totalCount;
  final String label;

  _ProgressHeaderDelegate({
    required this.completedCount,
    required this.totalCount,
    this.label = 'articles read',
  });

  static const double _maxHeight = 104.0;
  static const double _minHeight = 40.0;

  @override
  double get maxExtent => _maxHeight;

  @override
  double get minExtent => _minHeight;

  @override
  bool shouldRebuild(covariant _ProgressHeaderDelegate oldDelegate) {
    return completedCount != oldDelegate.completedCount ||
        totalCount != oldDelegate.totalCount;
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    final allDone = completedCount == totalCount && totalCount > 0;
    final barColor = allDone ? AppTheme.successGreen : AppTheme.primaryMagenta;

    // 0.0 = fully expanded, 1.0 = fully collapsed
    final collapseRatio = (shrinkOffset / (_maxHeight - _minHeight)).clamp(
      0.0,
      1.0,
    );
    final expandedOpacity = (1.0 - (collapseRatio / 0.6)).clamp(0.0, 1.0);
    final compactOpacity = ((collapseRatio - 0.6) / 0.4).clamp(0.0, 1.0);

    return Container(
      color: context.background,
      child: Stack(
        children: [
          // Expanded state: Ico + text + progress bar
          if (expandedOpacity > 0)
            Opacity(
              opacity: expandedOpacity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing16,
                  AppTheme.spacing12,
                  AppTheme.spacing16,
                  AppTheme.spacing8,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: MeshNodeBrain(
                        mood: allDone
                            ? MeshBrainMood.happy
                            : MeshBrainMood.inviting,
                        size: 60,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            allDone
                                ? 'You\'ve read everything!'
                                : 'Learn how Meshtastic works',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing4),
                          Text(
                            allDone
                                ? 'Come back anytime to refresh your '
                                      'knowledge.'
                                : 'Tap an article to learn about mesh '
                                      'networking, radio settings, and more.',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing10),
                          _ProgressBar(
                            progress: progress,
                            barColor: barColor,
                            label: '$completedCount / $totalCount',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Compact state: just progress bar + count
          if (compactOpacity > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Opacity(
                opacity: compactOpacity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing10,
                  ),
                  child: _ProgressBar(
                    progress: progress,
                    barColor: barColor,
                    label: '$completedCount / $totalCount',
                  ),
                ),
              ),
            ),

          // Bottom border
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 1,
              color: context.border.withValues(alpha: compactOpacity * 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Progress Bar
// =============================================================================

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color barColor;
  final String label;

  const _ProgressBar({
    required this.progress,
    required this.barColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: context.border.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacing12),
        Text(
          label,
          style: TextStyle(
            color: context.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Help Article Tile (knowledge base entry)
// =============================================================================

class _HelpArticleTile extends StatelessWidget {
  final HelpArticle article;
  final bool isRead;
  final VoidCallback onTap;

  const _HelpArticleTile({
    required this.article,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(AppTheme.spacing12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(
            color: isRead
                ? AppTheme.successGreen.withValues(alpha: 0.3)
                : context.border,
            width: isRead ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Article category icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: article.category.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
              child: Icon(
                article.icon,
                color: article.category.color,
                size: 22,
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),

            // Title + description + metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          article.title,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isRead)
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
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    article.description,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spacing6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _MetadataChip(
                        icon: Icons.schedule,
                        label: '${article.readingTimeMinutes} min',
                      ),
                      _MetadataChip(
                        icon: isRead
                            ? Icons.visibility
                            : Icons.article_outlined,
                        label: isRead ? 'Read' : 'Unread',
                        color: isRead
                            ? AppTheme.successGreen
                            : article.category.color,
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
// Metadata Chip
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
        const SizedBox(width: AppTheme.spacing3),
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
// Interactive Tours Section (expandable)
// =============================================================================

class _InteractiveToursSection extends StatelessWidget {
  final HelpState helpState;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(HelpTopic topic, bool isCompleted) onTopicTap;

  const _InteractiveToursSection({
    required this.helpState,
    required this.isExpanded,
    required this.onToggle,
    required this.onTopicTap,
  });

  @override
  Widget build(BuildContext context) {
    final completedCount = HelpContent.allTopics
        .where((t) => helpState.isTopicCompleted(t.id))
        .length;
    final totalCount = HelpContent.allTopics.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing20,
        AppTheme.spacing16,
        0,
      ),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          // Header (always visible, tappable to expand/collapse)
          BouncyTap(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AccentColors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radius10),
                    ),
                    child: Icon(
                      Icons.touch_app_outlined,
                      color: AccentColors.purple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Interactive Tours',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing2),
                        Text(
                          '$completedCount / $totalCount completed',
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, color: context.textTertiary),
                  ),
                ],
              ),
            ),
          ),

          // Expanded content: tour topic list
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildTourList(context),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildTourList(BuildContext context) {
    return Column(
      children: [
        Divider(color: context.border.withValues(alpha: 0.3), height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing12,
            AppTheme.spacing8,
            AppTheme.spacing12,
            AppTheme.spacing12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  bottom: AppTheme.spacing8,
                  left: AppTheme.spacing2,
                ),
                child: Text(
                  'Step-by-step walkthroughs for app features. These tours '
                  'guide you through each screen with Ico.',
                  style: TextStyle(
                    color: context.textTertiary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              ...HelpContent.allTopics.take(8).map((topic) {
                final isCompleted = helpState.isTopicCompleted(topic.id);
                return _TourTopicRow(
                  topic: topic,
                  isCompleted: isCompleted,
                  onTap: () => onTopicTap(topic, isCompleted),
                );
              }),
              if (HelpContent.allTopics.length > 8)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacing4),
                  child: Center(
                    child: Text(
                      '+ ${HelpContent.allTopics.length - 8} more tours',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Tour Topic Row (compact, for the expandable section)
// =============================================================================

class _TourTopicRow extends StatelessWidget {
  final HelpTopic topic;
  final bool isCompleted;
  final VoidCallback onTap;

  const _TourTopicRow({
    required this.topic,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing6),
        child: Row(
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.play_circle_outline,
              size: 18,
              color: isCompleted ? AppTheme.successGreen : context.textTertiary,
            ),
            const SizedBox(width: AppTheme.spacing10),
            Expanded(
              child: Text(
                topic.title,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '${topic.steps.length} steps',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Topic Detail Content (scrollable bottom sheet body for tours)
// =============================================================================

class _TopicDetailContent extends StatelessWidget {
  final HelpTopic topic;
  final bool isCompleted;
  final ScrollController scrollController;
  final String? screenName;

  const _TopicDetailContent({
    required this.topic,
    required this.isCompleted,
    required this.scrollController,
    required this.screenName,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
      children: [
        // Description
        Text(
          topic.description,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),

        // Related screen hint
        if (screenName != null) ...[
          const SizedBox(height: AppTheme.spacing12),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 14, color: context.textTertiary),
              const SizedBox(width: AppTheme.spacing4),
              Text(
                'Find this in: $screenName',
                style: TextStyle(
                  color: context.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: AppTheme.spacing20),

        // Guide steps
        ...topic.steps.asMap().entries.map(
          (entry) => _StepCard(
            stepNumber: entry.key + 1,
            totalSteps: topic.steps.length,
            step: entry.value,
          ),
        ),

        const SizedBox(height: AppTheme.spacing12),
      ],
    );
  }
}

// =============================================================================
// Step Card (single help step)
// =============================================================================

class _StepCard extends StatelessWidget {
  final int stepNumber;
  final int totalSteps;
  final HelpStep step;

  const _StepCard({
    required this.stepNumber,
    required this.totalSteps,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      padding: const EdgeInsets.all(AppTheme.spacing14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryMagenta.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$stepNumber',
              style: TextStyle(
                color: AppTheme.primaryMagenta,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),

          // Step text with **bold** rendering
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacing4),
              child: Text.rich(
                TextSpan(
                  children: _parseMarkdownBold(
                    step.bubbleText,
                    baseColor: context.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Parses **bold** markdown markers into styled [TextSpan]s.
  static List<TextSpan> _parseMarkdownBold(
    String text, {
    required Color baseColor,
  }) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    var lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: TextStyle(color: baseColor, fontSize: 14, height: 1.5),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            color: AppTheme.primaryMagenta,
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(color: baseColor, fontSize: 14, height: 1.5),
        ),
      );
    }

    return spans;
  }
}

// =============================================================================
// Help Settings Section
// =============================================================================

class _HelpSettingsSection extends ConsumerWidget {
  final HelpState helpState;
  final HelpArticleReadState readState;
  final VoidCallback onResetProgress;

  const _HelpSettingsSection({
    required this.helpState,
    required this.readState,
    required this.onResetProgress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing16,
        0,
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
          const SizedBox(height: AppTheme.spacing12),

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

          const SizedBox(height: AppTheme.spacing12),

          // Reset progress button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onResetProgress,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset All Progress'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AccentColors.cyan,
                side: BorderSide(color: AccentColors.cyan),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
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
// Help Setting Row
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
        const SizedBox(width: AppTheme.spacing12),
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
              const SizedBox(height: AppTheme.spacing2),
              Text(
                subtitle,
                style: TextStyle(color: context.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppTheme.spacing8),
        trailing,
      ],
    );
  }
}
