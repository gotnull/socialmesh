// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../models/social.dart';
import '../../../providers/social_providers.dart';
import '../widgets/follow_button.dart';
import 'profile_social_screen.dart';

/// Screen for searching and discovering users.
class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _searchQuery = query.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: 'Search',
        slivers: [
          // Search bar in body like Direct Messages
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  style: TextStyle(color: context.textPrimary),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    hintStyle: TextStyle(color: context.textTertiary),
                    prefixIcon: Icon(Icons.search, color: context.textTertiary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: context.textTertiary,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Divider
          SliverToBoxAdapter(
            child: Container(
              height: 1,
              color: context.border.withValues(alpha: 0.3),
            ),
          ),
          // Results
          SliverFillRemaining(
            hasScrollBody: true,
            child: _searchQuery.isEmpty
                ? _SuggestionsView()
                : _SearchResultsView(query: _searchQuery),
          ),
        ],
      ),
    );
  }
}

/// Shows suggested users when no search query is entered.
class _SuggestionsView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestedAsync = ref.watch(suggestedUsersProvider);
    final recentAsync = ref.watch(recentlyActiveUsersProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Suggested users section
        Text(
          'Suggested for you',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        suggestedAsync.when(
          data: (users) {
            if (users.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No suggestions available',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withAlpha(150),
                  ),
                ),
              );
            }
            // Preload follow states for all users in the list
            final userIds = users.map((u) => u.id).toList();
            ref
                .read(batchFollowStatesProvider.notifier)
                .preloadFollowStates(userIds);
            return Column(
              children: users.map((user) => _UserTile(user: user)).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Failed to load suggestions',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Recently active section
        Text(
          'Recently active',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        recentAsync.when(
          data: (users) {
            if (users.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No recent activity',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withAlpha(150),
                  ),
                ),
              );
            }
            // Preload follow states for all users in the list
            final userIds = users.map((u) => u.id).toList();
            ref
                .read(batchFollowStatesProvider.notifier)
                .preloadFollowStates(userIds);
            return Column(
              children: users.map((user) => _UserTile(user: user)).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Failed to load recent users',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows search results for a query.
class _SearchResultsView extends ConsumerWidget {
  const _SearchResultsView({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchAsync = ref.watch(userSearchProvider(query));
    final theme = Theme.of(context);

    return searchAsync.when(
      data: (result) {
        final users = result.items;

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: theme.colorScheme.primary.withAlpha(100),
                ),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodyLarge?.color?.withAlpha(150),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try a different search term',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withAlpha(100),
                  ),
                ),
              ],
            ),
          );
        }

        // Preload follow states for all users in the search results
        final userIds = users.map((u) => u.id).toList();
        ref
            .read(batchFollowStatesProvider.notifier)
            .preloadFollowStates(userIds);

        return RefreshIndicator(
          onRefresh: () async {
            ref.read(batchFollowStatesProvider.notifier).clear();
            ref.invalidate(userSearchProvider(query));
          },
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              return _UserTile(user: users[index]);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('Search failed: $error'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(userSearchProvider(query)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final PublicProfile user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: () => _navigateToProfile(context, user.id),
      leading: CircleAvatar(
        backgroundImage: user.avatarUrl != null
            ? NetworkImage(user.avatarUrl!)
            : null,
        child: user.avatarUrl == null
            ? Text(
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(user.displayName, overflow: TextOverflow.ellipsis),
          ),
          if (user.isVerified) ...[
            const SizedBox(width: 4),
            const SimpleVerifiedBadge(size: 16),
          ],
          if (user.isPrivate) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.lock,
              size: 14,
              color: theme.textTheme.bodySmall?.color?.withAlpha(150),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (user.callsign != null)
            Text(
              user.callsign!,
              style: TextStyle(color: theme.colorScheme.secondary),
            ),
          Text(
            '${user.followerCount} followers • ${user.postCount} posts',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withAlpha(150),
            ),
          ),
        ],
      ),
      isThreeLine: user.callsign != null,
      trailing: FollowButton(targetUserId: user.id, compact: true),
    );
  }

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSocialScreen(userId: userId),
      ),
    );
  }
}
