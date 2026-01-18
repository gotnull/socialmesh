import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class _SubscribeButtonState extends ConsumerState<SubscribeButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    // Don't show for own profile
    if (currentUser?.uid == widget.authorId) return const SizedBox.shrink();

    if (currentUser == null) {
      return TextButton(
        onPressed: () =>
            showInfoSnackBar(context, 'Sign in to manage subscriptions'),
        child: const Text('Subscribe'),
      );
    }

    final subscribedAsync = ref.watch(
      signalSubscriptionProvider(widget.authorId),
    );

    return subscribedAsync.when(
      data: (isSubscribed) => _buildButton(isSubscribed),
      loading: () => SizedBox(
        width: widget.compact ? 90 : 110,
        height: widget.compact ? 32 : 40,
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
    if (_isLoading) {
      return SizedBox(
        width: widget.compact ? 90 : 110,
        height: widget.compact ? 32 : 40,
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
      return SizedBox(
        width: 90,
        height: 32,
        child: isSubscribed
            ? OutlinedButton.icon(
                onPressed: _handleToggle,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Subscribed'),
              )
            : FilledButton.icon(
                onPressed: _handleToggle,
                icon: const Icon(Icons.notifications_active, size: 16),
                label: const Text('Subscribe'),
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
    setState(() => _isLoading = true);
    final service = ref.read(socialServiceProvider);
    try {
      final isSubscribed = await service.isSubscribedToAuthorSignals(
        widget.authorId,
      );
      if (isSubscribed) {
        await service.unsubscribeFromAuthorSignals(widget.authorId);
        if (!mounted) return;
        showInfoSnackBar(context, 'Unsubscribed from ${widget.authorId}');
      } else {
        await service.subscribeToAuthorSignals(widget.authorId);
        if (!mounted) return;
        showInfoSnackBar(context, 'Subscribed to ${widget.authorId}');
      }
      // invalidate provider to refresh state
      if (!mounted) return;
      ref.invalidate(signalSubscriptionProvider(widget.authorId));
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to update subscription: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
