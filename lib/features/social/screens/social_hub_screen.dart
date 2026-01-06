import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../providers/story_providers.dart';
import '../../settings/settings_screen.dart';
import '../widgets/story_bar.dart';
import 'create_post_screen.dart';
import 'follow_requests_screen.dart';
import 'profile_social_screen.dart';
import 'user_search_screen.dart';

/// The main Social screen - shows stories at top + user's profile with posts.
/// Stories bar appears at the top like Instagram's home feed.
class SocialHubScreen extends ConsumerWidget {
  const SocialHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: context.background,
          title: Text(
            'Social',
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_outline,
                  size: 64,
                  color: context.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign in to access Social',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create posts, follow users, and connect with the mesh community.',
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show stories at top + user's profile with posts
    return _AuthenticatedSocialHub(userId: currentUser.uid);
  }
}

/// Authenticated social hub with stories bar at top.
class _AuthenticatedSocialHub extends ConsumerWidget {
  const _AuthenticatedSocialHub({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingRequests = ref.watch(pendingFollowRequestsProvider);
    final requestCount = pendingRequests.when(
      data: (list) => list.length,
      loading: () => 0,
      error: (_, _) => 0,
    );

    return Scaffold(
      backgroundColor: context.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // App bar with all action icons
            SliverAppBar(
              backgroundColor: context.background,
              floating: true,
              snap: true,
              title: Text(
                'Social',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.search, color: context.textPrimary),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UserSearchScreen()),
                  ),
                  tooltip: 'Search users',
                ),
                _FollowRequestsBadge(
                  count: requestCount,
                  child: IconButton(
                    icon: Icon(
                      Icons.person_add_outlined,
                      color: context.textPrimary,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FollowRequestsScreen(),
                      ),
                    ),
                    tooltip: 'Follow requests',
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add_box_outlined,
                    color: context.textPrimary,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                  ),
                  tooltip: 'Create post',
                ),
                IconButton(
                  icon: Icon(
                    Icons.settings_outlined,
                    color: context.textPrimary,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  tooltip: 'Settings',
                ),
              ],
            ),
            // Stories bar - Instagram style at top of feed
            SliverToBoxAdapter(
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref.read(storyGroupsProvider.notifier).refresh();
                },
                child: const StoryBar(),
              ),
            ),
          ];
        },
        // Profile content below stories
        body: ProfileSocialScreen(
          userId: userId,
          showAppBar: false, // Hide app bar since we have one above
        ),
      ),
    );
  }
}

/// Badge showing pending follow request count.
class _FollowRequestsBadge extends StatelessWidget {
  const _FollowRequestsBadge({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: 4,
          top: 4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.accentColor,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
