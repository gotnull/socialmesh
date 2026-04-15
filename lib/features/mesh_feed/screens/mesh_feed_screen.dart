// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Mesh Feed screen — ranked, trust-scored, transport-agnostic content feed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
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
    return switch (_filter) {
      MeshFeedFilter.all => posts,
      MeshFeedFilter.trusted =>
        posts.where((p) => p.trustComponent >= 0.35).toList(),
      MeshFeedFilter.nearby =>
        posts
            .where(
              (p) =>
                  p.post.isLocal ||
                  (p.post.hopCount != null && p.post.hopCount! <= 1),
            )
            .toList(),
      MeshFeedFilter.local => posts.where((p) => p.post.isLocal).toList(),
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

    // Kick off LAN sync by watching the provider — Riverpod lazily creates
    // the service only when watched.
    ref.watch(lanSyncServiceProvider);

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
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: l10n.meshFeedComposeTitle,
            onPressed: _openComposer,
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
              rebuildKey: Object.hashAll([_filter, _sort, posts.length]),
              filterChips: [
                StatusFilterChip(
                  label: l10n.meshFeedFilterAll,
                  count: feedState.posts.length,
                  icon: Icons.dynamic_feed,
                  color: AccentColors.cyan,
                  isSelected: _filter == MeshFeedFilter.all,
                  onTap: () {
                    ref.haptics.toggle();
                    safeSetState(() => _filter = MeshFeedFilter.all);
                  },
                ),
                StatusFilterChip(
                  label: l10n.meshFeedFilterTrusted,
                  icon: Icons.verified_user_outlined,
                  color: AccentColors.cyan,
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
                  icon: Icons.near_me_outlined,
                  color: AccentColors.cyan,
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
                  icon: Icons.person_outlined,
                  color: AccentColors.cyan,
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
                StatusFilterChip(
                  label: l10n.meshFeedSortRanked,
                  icon: Icons.auto_awesome,
                  color: AccentColors.purple,
                  isSelected: _sort == MeshFeedSort.ranked,
                  onTap: () {
                    ref.haptics.toggle();
                    safeSetState(() => _sort = MeshFeedSort.ranked);
                  },
                ),
                StatusFilterChip(
                  label: l10n.meshFeedSortNewest,
                  icon: Icons.schedule,
                  color: AccentColors.purple,
                  isSelected: _sort == MeshFeedSort.newest,
                  onTap: () {
                    ref.haptics.toggle();
                    safeSetState(() => _sort = MeshFeedSort.newest);
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
            if (_filter == MeshFeedFilter.all)
              SliverFillRemaining(
                child: MeshFeedEmptyState(onCompose: _openComposer),
              )
            else
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_list_off,
                          size: 48,
                          color: context.textTertiary,
                        ),
                        const SizedBox(height: AppTheme.spacing16),
                        Text(
                          l10n.meshFeedEmptyFilterTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        Text(
                          l10n.meshFeedEmptyFilterDescription,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
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
}
