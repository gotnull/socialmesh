import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/verified_badge.dart';
import '../../../providers/social_providers.dart';
import '../../../services/social_service.dart';
import '../widgets/follow_button.dart';
import 'profile_social_screen.dart';

enum FollowersScreenMode { followers, following }

/// Screen showing followers or following list for a user.
class FollowersScreen extends ConsumerStatefulWidget {
  const FollowersScreen({
    super.key,
    required this.userId,
    this.initialMode = FollowersScreenMode.followers,
  });

  final String userId;
  final FollowersScreenMode initialMode;

  @override
  ConsumerState<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends ConsumerState<FollowersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialMode == FollowersScreenMode.followers ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FollowersList(userId: widget.userId),
          _FollowingList(userId: widget.userId),
        ],
      ),
    );
  }
}

class _FollowersList extends ConsumerWidget {
  const _FollowersList({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followersAsync = ref.watch(followersProvider(userId));

    return followersAsync.when(
      data: (result) {
        final followers = result.items;
        if (followers.isEmpty) {
          return _buildEmptyState(
            context,
            icon: Icons.people_outline,
            message: 'No followers yet',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(followersProvider(userId)),
          child: ListView.builder(
            itemCount: followers.length,
            itemBuilder: (context, index) {
              final follower = followers[index];
              return _UserTile(
                user: follower,
                onTap: () =>
                    _navigateToProfile(context, follower.follow.followerId),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(
        context,
        error,
        () => ref.invalidate(followersProvider(userId)),
      ),
    );
  }
}

class _FollowingList extends ConsumerWidget {
  const _FollowingList({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingProvider(userId));

    return followingAsync.when(
      data: (result) {
        final following = result.items;
        if (following.isEmpty) {
          return _buildEmptyState(
            context,
            icon: Icons.person_add_outlined,
            message: 'Not following anyone yet',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(followingProvider(userId)),
          child: ListView.builder(
            itemCount: following.length,
            itemBuilder: (context, index) {
              final user = following[index];
              return _UserTile(
                user: user,
                onTap: () =>
                    _navigateToProfile(context, user.follow.followeeId),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(
        context,
        error,
        () => ref.invalidate(followingProvider(userId)),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onTap});

  final FollowWithProfile user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = user.profile;

    // Determine the user ID to show (follower or followee depending on context)
    final targetUserId = profile?.id ?? user.follow.followeeId;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage: profile?.avatarUrl != null
            ? NetworkImage(profile!.avatarUrl!)
            : null,
        child: profile?.avatarUrl == null
            ? Text(
                (profile?.displayName ?? 'U')[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              profile?.displayName ?? 'Unknown User',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (profile?.isVerified == true) ...[
            const SizedBox(width: 4),
            const SimpleVerifiedBadge(size: 16),
          ],
        ],
      ),
      subtitle: profile?.callsign != null
          ? Text(
              profile!.callsign!,
              style: TextStyle(color: theme.colorScheme.secondary),
            )
          : null,
      trailing: FollowButton(targetUserId: targetUserId, compact: true),
    );
  }
}

Widget _buildEmptyState(
  BuildContext context, {
  required IconData icon,
  required String message,
}) {
  final theme = Theme.of(context);

  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 64, color: theme.colorScheme.primary.withAlpha(100)),
        const SizedBox(height: 16),
        Text(
          message,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.textTheme.bodyLarge?.color?.withAlpha(150),
          ),
        ),
      ],
    ),
  );
}

Widget _buildErrorState(
  BuildContext context,
  Object error,
  VoidCallback onRetry,
) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48),
        const SizedBox(height: 16),
        Text('Failed to load: $error'),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
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
