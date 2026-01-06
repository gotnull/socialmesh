import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../providers/auth_providers.dart';
import 'profile_social_screen.dart';

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
    // Just show the ProfileSocialScreen directly - it handles everything
    // including its own app bar, pull-to-refresh, and smooth scrolling.
    // The StoryBar is shown at the top of the profile for the user's own profile.
    return ProfileSocialScreen(
      userId: userId,
      showAppBar: true,
      showStoryBar: true, // Show stories at the top
    );
  }
}
