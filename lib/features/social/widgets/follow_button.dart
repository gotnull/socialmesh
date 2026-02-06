// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../utils/snackbar.dart';

/// A button that toggles follow/unfollow state for a user.
///
/// Shows different states:
/// - "Follow" when not following
/// - "Requested" when follow request is pending (private accounts)
/// - "Following" when following
/// - Loading spinner during state change
class FollowButton extends ConsumerStatefulWidget {
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
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton>
    with LifecycleSafeMixin {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    // Don't show follow button for own profile
    if (currentUser?.uid == widget.targetUserId) {
      return const SizedBox.shrink();
    }

    // Not logged in - show disabled follow button
    if (currentUser == null) {
      return _buildButton(
        context,
        buttonState: FollowButtonState.notFollowing,
        isLoading: false,
        onPressed: () {
          showSignInRequiredSnackBar(context, 'Sign in to follow users');
        },
      );
    }

    // Use cached provider for efficiency in lists
    final followState = ref.watch(
      cachedFollowStateProvider(widget.targetUserId),
    );

    return followState.when(
      data: (state) => _buildButton(
        context,
        buttonState: state.buttonState,
        isLoading: _isLoading,
        onPressed: _isLoading ? null : () => _handleToggle(context, state),
      ),
      loading: () => _buildButton(
        context,
        buttonState: FollowButtonState.notFollowing,
        isLoading: true,
        onPressed: null,
      ),
      error: (_, _) => _buildButton(
        context,
        buttonState: FollowButtonState.notFollowing,
        isLoading: false,
        onPressed: () =>
            ref.invalidate(followStateProvider(widget.targetUserId)),
      ),
    );
  }

  Future<void> _handleToggle(BuildContext context, FollowState state) async {
    safeSetState(() => _isLoading = true);
    try {
      await toggleFollow(ref, widget.targetUserId);

      // Determine new state for callback
      final wasFollowing = state.isFollowing;
      final hadRequest = state.hasPendingRequest;

      // If was following, now not following
      // If had request, now cancelled
      // If neither, now either following or requested
      if (wasFollowing) {
        widget.onFollowChanged?.call(false);
      } else if (!hadRequest) {
        // Started following or sent request
        widget.onFollowChanged?.call(true);
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to update follow: $e');
      }
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  Widget _buildButton(
    BuildContext context, {
    required FollowButtonState buttonState,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);

    if (widget.compact) {
      return SizedBox(
        width: 110,
        height: 32,
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : _buildCompactButton(buttonState, onPressed),
      );
    }

    if (isLoading) {
      return SizedBox(
        width: 120,
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

    return _buildFullButton(buttonState, onPressed);
  }

  Widget _buildCompactButton(FollowButtonState state, VoidCallback? onPressed) {
    // Fixed width for uniform button sizes
    const buttonWidth = 110.0;

    switch (state) {
      case FollowButtonState.following:
        return SizedBox(
          width: buttonWidth,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(buttonWidth, 32),
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
            ),
            child: const Text('Following'),
          ),
        );
      case FollowButtonState.requested:
        return SizedBox(
          width: buttonWidth,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(buttonWidth, 32),
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
            ),
            child: const Text('Requested'),
          ),
        );
      case FollowButtonState.notFollowing:
        return SizedBox(
          width: buttonWidth,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(buttonWidth, 32),
            ),
            child: const Text('Follow'),
          ),
        );
    }
  }

  Widget _buildFullButton(FollowButtonState state, VoidCallback? onPressed) {
    switch (state) {
      case FollowButtonState.following:
        return OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Following'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        );
      case FollowButtonState.requested:
        return OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.schedule, size: 18),
          label: const Text('Requested'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            foregroundColor: Colors.grey,
          ),
        );
      case FollowButtonState.notFollowing:
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
}

/// A text button version for use in lists
class FollowTextButton extends ConsumerStatefulWidget {
  const FollowTextButton({
    super.key,
    required this.targetUserId,
    this.onFollowChanged,
  });

  final String targetUserId;
  final void Function(bool isFollowing)? onFollowChanged;

  @override
  ConsumerState<FollowTextButton> createState() => _FollowTextButtonState();
}

class _FollowTextButtonState extends ConsumerState<FollowTextButton>
    with LifecycleSafeMixin {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser?.uid == widget.targetUserId || currentUser == null) {
      return const SizedBox.shrink();
    }

    // Use cached provider for efficiency in lists
    final followState = ref.watch(
      cachedFollowStateProvider(widget.targetUserId),
    );

    return followState.when(
      data: (state) => TextButton(
        onPressed: _isLoading ? null : () => _handleToggle(state),
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Text(
                _getButtonText(state.buttonState),
                style: TextStyle(
                  color: _getButtonColor(context, state.buttonState),
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
        onPressed: () =>
            ref.invalidate(followStateProvider(widget.targetUserId)),
        child: const Text('Retry'),
      ),
    );
  }

  Future<void> _handleToggle(FollowState state) async {
    safeSetState(() => _isLoading = true);
    try {
      await toggleFollow(ref, widget.targetUserId);

      final wasFollowing = state.isFollowing;
      final hadRequest = state.hasPendingRequest;

      if (wasFollowing) {
        widget.onFollowChanged?.call(false);
      } else if (!hadRequest) {
        widget.onFollowChanged?.call(true);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed: $e');
      }
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  String _getButtonText(FollowButtonState state) {
    switch (state) {
      case FollowButtonState.following:
        return 'Unfollow';
      case FollowButtonState.requested:
        return 'Cancel';
      case FollowButtonState.notFollowing:
        return 'Follow';
    }
  }

  Color _getButtonColor(BuildContext context, FollowButtonState state) {
    switch (state) {
      case FollowButtonState.following:
        return Colors.grey;
      case FollowButtonState.requested:
        return Colors.orange;
      case FollowButtonState.notFollowing:
        return Theme.of(context).colorScheme.primary;
    }
  }
}
