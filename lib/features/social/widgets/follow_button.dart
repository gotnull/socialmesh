import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';

/// A button that toggles follow/unfollow state for a user.
///
/// Shows different states:
/// - "Follow" when not following
/// - "Following" when following
/// - Loading spinner during state change
class FollowButton extends ConsumerWidget {
  const FollowButton({
    super.key,
    required this.targetUserId,
    this.compact = false,
    this.onFollowChanged,
  });

  /// The user ID to follow/unfollow
  final String targetUserId;

  /// Use compact style (smaller button)
  final bool compact;

  /// Callback when follow state changes
  final void Function(bool isFollowing)? onFollowChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    // Don't show follow button for own profile
    if (currentUser?.uid == targetUserId) {
      return const SizedBox.shrink();
    }

    // Not logged in - show disabled follow button
    if (currentUser == null) {
      return _buildButton(
        context,
        isFollowing: false,
        isLoading: false,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign in to follow users')),
          );
        },
      );
    }

    final followState = ref.watch(followStateProvider(targetUserId));

    return followState.when(
      data: (state) => _buildButton(
        context,
        isFollowing: state.isFollowing,
        isLoading: false,
        onPressed: () => _handleToggle(context, ref, state.isFollowing),
      ),
      loading: () => _buildButton(
        context,
        isFollowing: false,
        isLoading: true,
        onPressed: null,
      ),
      error: (_, _) => _buildButton(
        context,
        isFollowing: false,
        isLoading: false,
        onPressed: () => ref.invalidate(followStateProvider(targetUserId)),
      ),
    );
  }

  Future<void> _handleToggle(
    BuildContext context,
    WidgetRef ref,
    bool currentlyFollowing,
  ) async {
    try {
      await toggleFollow(ref, targetUserId);
      onFollowChanged?.call(!currentlyFollowing);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update follow: $e')));
      }
    }
  }

  Widget _buildButton(
    BuildContext context, {
    required bool isFollowing,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);

    if (compact) {
      return SizedBox(
        height: 32,
        child: isLoading
            ? const SizedBox(
                width: 32,
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : isFollowing
            ? OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Following'),
              )
            : FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Follow'),
              ),
      );
    }

    if (isLoading) {
      return SizedBox(
        width: 100,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      );
    }

    if (isFollowing) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.check, size: 18),
        label: const Text('Following'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.person_add, size: 18),
      label: const Text('Follow'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

/// A text button version for use in lists
class FollowTextButton extends ConsumerWidget {
  const FollowTextButton({
    super.key,
    required this.targetUserId,
    this.onFollowChanged,
  });

  final String targetUserId;
  final void Function(bool isFollowing)? onFollowChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser?.uid == targetUserId || currentUser == null) {
      return const SizedBox.shrink();
    }

    final followState = ref.watch(followStateProvider(targetUserId));

    return followState.when(
      data: (state) => TextButton(
        onPressed: () async {
          try {
            await toggleFollow(ref, targetUserId);
            onFollowChanged?.call(!state.isFollowing);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Failed: $e')));
            }
          }
        },
        child: Text(
          state.isFollowing ? 'Unfollow' : 'Follow',
          style: TextStyle(
            color: state.isFollowing
                ? Colors.grey
                : Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      loading: () => const SizedBox(
        width: 60,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => TextButton(
        onPressed: () => ref.invalidate(followStateProvider(targetUserId)),
        child: const Text('Retry'),
      ),
    );
  }
}
