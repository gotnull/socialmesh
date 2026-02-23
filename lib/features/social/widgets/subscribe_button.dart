// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../utils/snackbar.dart';

/// A compact subscribe/unsubscribe button for author signals.
class SubscribeButton extends ConsumerStatefulWidget {
  const SubscribeButton({
    super.key,
    required this.authorId,
    this.compact = false,
  });

  final String authorId;
  final bool compact;

  @override
  ConsumerState<SubscribeButton> createState() => _SubscribeButtonState();
}

class _SubscribeButtonState extends ConsumerState<SubscribeButton>
    with LifecycleSafeMixin {
  /// Tracks whether an optimistic toggle is pending (for visual feedback).
  bool _isToggling = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    // Don't show for own profile
    if (currentUser?.uid == widget.authorId) return const SizedBox.shrink();

    if (currentUser == null) {
      return TextButton(
        onPressed: () => showSignInRequiredSnackBar(
          context,
          'Sign in to manage subscriptions',
        ),
        child: const Text('Subscribe'),
      );
    }

    final subscribedAsync = ref.watch(
      signalSubscriptionProvider(widget.authorId),
    );

    return subscribedAsync.when(
      data: (isSubscribed) => _buildButton(isSubscribed),
      loading: () => widget.compact
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : SizedBox(
              width: 110,
              height: 40,
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
      error: (e, s) => TextButton(
        onPressed: () =>
            ref.invalidate(signalSubscriptionProvider(widget.authorId)),
        child: const Text('Subscribe'),
      ),
    );
  }

  Widget _buildButton(bool isSubscribed) {
    if (_isToggling) {
      return widget.compact
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : SizedBox(
              width: 110,
              height: 40,
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
    }

    if (widget.compact) {
      // Compact mode shows a small icon-only button aligned to top
      return GestureDetector(
        onTap: _handleToggle,
        child: Tooltip(
          message: isSubscribed ? 'Subscribed' : 'Subscribe',
          child: Icon(
            isSubscribed ? Icons.check : Icons.notifications_active,
            size: 18,
          ),
        ),
      );
    }

    return isSubscribed
        ? OutlinedButton.icon(
            onPressed: _handleToggle,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Subscribed'),
          )
        : FilledButton.icon(
            onPressed: _handleToggle,
            icon: const Icon(Icons.notifications_active, size: 18),
            label: const Text('Subscribe'),
          );
  }

  Future<void> _handleToggle() async {
    final service = ref.read(socialServiceProvider);
    final queue = ref.read(mutationQueueProvider);

    // Determine current subscription state
    final isSubscribed = await service.isSubscribedToAuthorSignals(
      widget.authorId,
    );

    safeSetState(() => _isToggling = true);

    try {
      await queue.enqueue<void>(
        key: 'subscribe:${widget.authorId}',
        optimisticApply: () {
          // Optimistic feedback handled by _isToggling spinner
        },
        execute: () async {
          if (isSubscribed) {
            await service.unsubscribeFromAuthorSignals(widget.authorId);
          } else {
            await service.subscribeToAuthorSignals(widget.authorId);
          }
        },
        commitApply: (_) {
          if (!mounted) return;
          showInfoSnackBar(
            context,
            isSubscribed ? 'Unsubscribed' : 'Subscribed',
          );
          ref.invalidate(signalSubscriptionProvider(widget.authorId));
        },
        rollbackApply: () {
          // Provider state unchanged — just invalidate to refresh
          if (mounted) {
            ref.invalidate(signalSubscriptionProvider(widget.authorId));
          }
        },
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to update subscription: $e');
      }
    } finally {
      safeSetState(() => _isToggling = false);
    }
  }
}
