// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../models/social.dart';
import '../../../providers/social_providers.dart';
import '../../../utils/snackbar.dart';
import 'profile_social_screen.dart';

/// Screen showing pending follow requests for the current user to approve/decline.
class FollowRequestsScreen extends ConsumerWidget {
  const FollowRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingFollowRequestsProvider);

    return GlassScaffold(
      title: 'Follow Requests',
      slivers: [
        requestsAsync.when(
          data: (requests) {
            if (requests.isEmpty) {
              return SliverFillRemaining(child: _buildEmptyState(context));
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final request = requests[index];
                return _RequestTile(
                  request: request,
                  onAccept: () => _handleAccept(context, ref, request),
                  onDecline: () => _handleDecline(context, ref, request),
                  onTap: () =>
                      _navigateToProfile(context, request.request.requesterId),
                );
              }, childCount: requests.length),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => SliverFillRemaining(
            child: _buildErrorState(
              context,
              error,
              () => ref.invalidate(pendingFollowRequestsProvider),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAccept(
    BuildContext context,
    WidgetRef ref,
    FollowRequestWithProfile request,
  ) async {
    try {
      await acceptFollowRequest(ref, request.request.requesterId);
      if (context.mounted) {
        showSuccessSnackBar(
          context,
          'Accepted ${request.profile?.displayName ?? 'user'}\'s request',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to accept request: $e');
      }
    }
  }

  Future<void> _handleDecline(
    BuildContext context,
    WidgetRef ref,
    FollowRequestWithProfile request,
  ) async {
    try {
      await declineFollowRequest(ref, request.request.requesterId);
      if (context.mounted) {
        showInfoSnackBar(
          context,
          'Declined ${request.profile?.displayName ?? 'user'}\'s request',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to decline request: $e');
      }
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_add_disabled_outlined,
            size: 64,
            color: theme.colorScheme.primary.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            'No pending requests',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodyLarge?.color?.withAlpha(150),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When someone requests to follow you,\nyou\'ll see it here',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withAlpha(100),
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
}

class _RequestTile extends ConsumerStatefulWidget {
  const _RequestTile({
    required this.request,
    required this.onAccept,
    required this.onDecline,
    required this.onTap,
  });

  final FollowRequestWithProfile request;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;
  final VoidCallback onTap;

  @override
  ConsumerState<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends ConsumerState<_RequestTile>
    with LifecycleSafeMixin {
  bool _isAccepting = false;
  bool _isDeclining = false;

  bool get _isProcessing => _isAccepting || _isDeclining;

  Future<void> _handleAccept() async {
    if (_isProcessing) return;
    safeSetState(() => _isAccepting = true);
    try {
      await widget.onAccept();
    } finally {
      safeSetState(() => _isAccepting = false);
    }
  }

  Future<void> _handleDecline() async {
    if (_isProcessing) return;
    safeSetState(() => _isDeclining = true);
    try {
      await widget.onDecline();
    } finally {
      safeSetState(() => _isDeclining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.request.profile;
    final createdAt = widget.request.request.createdAt;

    return ListTile(
      onTap: widget.onTap,
      leading: UserAvatar(
        imageUrl: profile?.avatarUrl,
        initials: (profile?.displayName ?? 'U').isNotEmpty
            ? (profile?.displayName ?? 'U')[0]
            : '?',
        size: 40,
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile?.callsign != null)
            Text(
              profile!.callsign!,
              style: TextStyle(color: theme.colorScheme.secondary),
            ),
          Text(
            _formatTimeAgo(createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withAlpha(150),
            ),
          ),
        ],
      ),
      isThreeLine: profile?.callsign != null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 32,
            width: 80,
            child: FilledButton(
              onPressed: _isProcessing ? null : _handleAccept,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: _isAccepting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirm', maxLines: 1),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            width: 70,
            child: FilledButton(
              onPressed: _isProcessing ? null : _handleDecline,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
              ),
              child: _isDeclining
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Delete', maxLines: 1),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
