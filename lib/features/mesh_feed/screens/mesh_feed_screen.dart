// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Mesh Feed screen — ranked, trust-scored, transport-agnostic content feed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_gradient_background.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/status_filter_chip.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/mesh_feed_providers.dart';
import '../../../services/haptic_service.dart';
import '../../../services/mesh_feed/mesh_feed_ranking.dart';
import '../widgets/mesh_feed_empty_state.dart';
import '../widgets/mesh_post_card.dart';
import '../widgets/mesh_post_composer.dart';

// ---------------------------------------------------------------------------
// Filter / sort enums
// ---------------------------------------------------------------------------

/// Filter options for the mesh feed.
enum MeshFeedFilter {
  /// Show all posts.
  all,

  /// Only posts from trusted nodes (trust score >= 0.35).
  trusted,

  /// Only nearby posts (hop count <= 1 or local).
  nearby,

  /// Only posts authored locally.
  local,
}

/// Sort options for the mesh feed.
enum MeshFeedSort {
  /// Ranked composite score (default).
  ranked,

  /// Newest first.
  newest,
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// The mesh feed screen.
class MeshFeedScreen extends ConsumerStatefulWidget {
  const MeshFeedScreen({super.key});

  @override
  ConsumerState<MeshFeedScreen> createState() => _MeshFeedScreenState();
}

class _MeshFeedScreenState extends ConsumerState<MeshFeedScreen>
    with LifecycleSafeMixin<MeshFeedScreen> {
  MeshFeedFilter _filter = MeshFeedFilter.all;
  MeshFeedSort _sort = MeshFeedSort.ranked;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openComposer() {
    final myNodeNum = ref.read(myNodeNumProvider);
    if (myNodeNum == null) return;

    final notifier = ref.read(meshFeedNotifierProvider.notifier);

    showMeshPostComposer(
      context: context,
      onPost: (content, ttl) async {
        final post = await notifier.createPost(
          authorNodeNum: myNodeNum,
          content: content,
          ttl: ttl,
        );
        return post != null;
      },
    );
  }

  List<RankedPost> _applyFilter(List<RankedPost> posts) {
    final myNodeNum = ref.read(myNodeNumProvider);
    return switch (_filter) {
      MeshFeedFilter.all => posts,
      MeshFeedFilter.trusted =>
        posts.where((p) => p.trustComponent >= 0.35).toList(),
      MeshFeedFilter.nearby =>
        posts
            .where(
              (p) =>
                  (myNodeNum != null && p.post.authorNodeNum == myNodeNum) ||
                  (p.post.hopCount != null && p.post.hopCount! <= 1),
            )
            .toList(),
      MeshFeedFilter.local =>
        posts
            .where(
              (p) => myNodeNum != null && p.post.authorNodeNum == myNodeNum,
            )
            .toList(),
    };
  }

  List<RankedPost> _applySort(List<RankedPost> posts) {
    if (_sort == MeshFeedSort.newest) {
      return [...posts]
        ..sort((a, b) => b.post.createdAtMs.compareTo(a.post.createdAtMs));
    }
    // ranked sort is the default from the ranking engine
    return posts;
  }

  List<RankedPost> _applySearch(List<RankedPost> posts) {
    if (_searchQuery.isEmpty) return posts;
    final query = _searchQuery.toLowerCase();
    return posts
        .where((p) => p.post.content.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final feedState = ref.watch(meshFeedNotifierProvider);
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final canCompose = myNodeNum != null;

    // Kick off LAN sync by watching the provider — Riverpod lazily creates
    // the service only when watched.
    ref.watch(lanSyncServiceProvider);

    // Kick off Meshtastic RF transport — wires send/receive for feed posts.
    ref.watch(meshFeedRfTransportProvider);

    final allPosts = feedState.posts;
    final allCount = allPosts.length;
    final trustedCount = allPosts.where((p) => p.trustComponent >= 0.35).length;
    final nearbyCount = allPosts
        .where(
          (p) =>
              (myNodeNum != null && p.post.authorNodeNum == myNodeNum) ||
              (p.post.hopCount != null && p.post.hopCount! <= 1),
        )
        .length;
    final localCount = allPosts
        .where((p) => myNodeNum != null && p.post.authorNodeNum == myNodeNum)
        .length;

    var posts = feedState.posts;
    posts = _applyFilter(posts);
    posts = _applySort(posts);
    posts = _applySearch(posts);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.meshFeedTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AccentColors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radius4),
                border: Border.all(
                  color: AccentColors.orange.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                l10n.meshFeedBetaLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AccentColors.orange,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _buildComposeButton(
              canCompose: canCompose,
              blockedReason: canCompose ? null : l10n.signalDeviceNotConnected,
            ),
          ),
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              if (value == 'compose') {
                _openComposer();
              } else if (value == 'refresh') {
                ref.haptics.toggle();
                ref.read(meshFeedNotifierProvider.notifier).refresh();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'compose',
                enabled: canCompose,
                child: ListTile(
                  leading: const Icon(Icons.blur_on_rounded),
                  title: Text(l10n.meshFeedComposeTitle),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: Text(
                    MaterialLocalizations.of(
                      context,
                    ).refreshIndicatorSemanticLabel,
                  ),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
        slivers: [
          // Search + filter chips
          SliverPersistentHeader(
            pinned: true,
            delegate: SearchFilterHeaderDelegate(
              searchController: _searchController,
              searchQuery: _searchQuery,
              onSearchChanged: (value) =>
                  safeSetState(() => _searchQuery = value),
              hintText: l10n.meshFeedSearchHint,
              textScaler: textScaler,
              rebuildKey: Object.hashAll([
                _filter,
                _sort,
                allCount,
                trustedCount,
                nearbyCount,
                localCount,
                posts.length,
              ]),
              filterChips: [
                StatusFilterChip(
                  label: l10n.meshFeedFilterAll,
                  count: allCount,
                  color: context.accentColor,
                  isSelected: _filter == MeshFeedFilter.all,
                  onTap: () {
                    ref.haptics.toggle();
                    safeSetState(() => _filter = MeshFeedFilter.all);
                  },
                ),
                StatusFilterChip(
                  label: l10n.meshFeedFilterTrusted,
                  count: trustedCount,
                  icon: Icons.verified_user_rounded,
                  color: AccentColors.yellow,
                  isSelected: _filter == MeshFeedFilter.trusted,
                  onTap: () {
                    ref.haptics.toggle();
                    safeSetState(
                      () => _filter = _filter == MeshFeedFilter.trusted
                          ? MeshFeedFilter.all
                          : MeshFeedFilter.trusted,
                    );
                  },
                ),
                StatusFilterChip(
                  label: l10n.meshFeedFilterNearby,
                  count: nearbyCount,
                  icon: Icons.near_me,
                  color: context.accentColor,
                  isSelected: _filter == MeshFeedFilter.nearby,
                  onTap: () {
                    ref.haptics.toggle();
                    safeSetState(
                      () => _filter = _filter == MeshFeedFilter.nearby
                          ? MeshFeedFilter.all
                          : MeshFeedFilter.nearby,
                    );
                  },
                ),
                StatusFilterChip(
                  label: l10n.meshFeedFilterLocal,
                  count: localCount,
                  icon: Icons.person_rounded,
                  color: AccentColors.purple,
                  isSelected: _filter == MeshFeedFilter.local,
                  onTap: () {
                    ref.haptics.toggle();
                    safeSetState(
                      () => _filter = _filter == MeshFeedFilter.local
                          ? MeshFeedFilter.all
                          : MeshFeedFilter.local,
                    );
                  },
                ),
              ],
              trailingControls: [
                _MeshFeedSortSelector(
                  sort: _sort,
                  onChanged: (sort) {
                    ref.haptics.toggle();
                    safeSetState(() => _sort = sort);
                  },
                ),
              ],
            ),
          ),

          // Post count
          if (posts.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing4,
                ),
                child: Text(
                  l10n.meshFeedPostCount(posts.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
              ),
            ),

          // Content
          if (feedState.isLoading && posts.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (posts.isEmpty)
            if (_filter == MeshFeedFilter.all && _searchQuery.isEmpty)
              SliverFillRemaining(
                child: MeshFeedEmptyState(onCompose: _openComposer),
              )
            else
              SliverFillRemaining(
                child: MeshFeedEmptyState.filtered(
                  onShowAll: () {
                    ref.haptics.toggle();
                    safeSetState(() {
                      _filter = MeshFeedFilter.all;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                ),
              )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index == posts.length) {
                  // Pull-to-refresh padding
                  return const SizedBox(
                    height: AppTheme.spacing60 + AppTheme.spacing20,
                  );
                }
                return MeshPostCard(rankedPost: posts[index]);
              }, childCount: posts.length + 1),
            ),
        ],
      ),
    );
  }

  Widget _buildComposeButton({
    required bool canCompose,
    required String? blockedReason,
  }) {
    final gradientColors = AccentColors.gradientFor(context.accentColor);
    final gradient = LinearGradient(
      colors: [gradientColors[0], gradientColors[1]],
    );

    return Tooltip(
      message:
          blockedReason ?? AppLocalizations.of(context).meshFeedComposeTitle,
      child: BouncyTap(
        onTap: canCompose ? _openComposer : null,
        enabled: canCompose,
        child: AnimatedGradientBackground(
          gradient: gradient,
          animate: canCompose,
          enabled: canCompose,
          borderRadius: BorderRadius.circular(AppTheme.radius18),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: canCompose ? null : context.border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radius18),
            ),
            child: Icon(
              Icons.blur_on_rounded,
              size: 24,
              color: canCompose ? Colors.white : context.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MeshFeedSortSelector extends StatelessWidget {
  const _MeshFeedSortSelector({required this.sort, required this.onChanged});

  final MeshFeedSort sort;
  final ValueChanged<MeshFeedSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MeshFeedSortButton(
          icon: Icons.auto_awesome_rounded,
          isSelected: sort == MeshFeedSort.ranked,
          onTap: () => onChanged(MeshFeedSort.ranked),
          tooltip: l10n.meshFeedSortRanked,
        ),
        const SizedBox(width: AppTheme.spacing4),
        _MeshFeedSortButton(
          icon: Icons.schedule_rounded,
          isSelected: sort == MeshFeedSort.newest,
          onTap: () => onChanged(MeshFeedSort.newest),
          tooltip: l10n.meshFeedSortNewest,
        ),
      ],
    );
  }
}

class _MeshFeedSortButton extends StatelessWidget {
  const _MeshFeedSortButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing6),
          decoration: BoxDecoration(
            color: isSelected
                ? context.accentColor.withValues(alpha: 0.2)
                : context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            border: Border.all(
              color: isSelected
                  ? context.accentColor.withValues(alpha: 0.5)
                  : context.border.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? context.accentColor : context.textTertiary,
          ),
        ),
      ),
    );
  }
}
