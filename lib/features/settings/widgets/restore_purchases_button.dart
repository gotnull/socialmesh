// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../providers/connectivity_providers.dart';
import '../../../utils/snackbar.dart';
import '../../../providers/subscription_providers.dart';

class RestorePurchasesButton extends ConsumerStatefulWidget {
  /// If true, will pop the current route (e.g., dismiss a bottom sheet)
  /// before showing the result snackbar so it's visible to the user.
  final bool dismissSheetOnComplete;

  const RestorePurchasesButton({
    super.key,
    this.dismissSheetOnComplete = false,
  });

  @override
  ConsumerState<RestorePurchasesButton> createState() =>
      _RestorePurchasesButtonState();
}

class _RestorePurchasesButtonState extends ConsumerState<RestorePurchasesButton>
    with LifecycleSafeMixin<RestorePurchasesButton> {
  bool _isLocalLoading = false;

  Future<void> _onPressed(BuildContext context) async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      AppLogging.subscriptions('[RestorePurchases] Blocked — offline');
      showErrorSnackBar(
        context,
        'Restoring purchases requires an internet connection.',
      );
      return;
    }

    safeSetState(() => _isLocalLoading = true);
    bool success = false;

    // Capture state and providers before any await
    final stateBefore = ref.read(purchaseStateProvider);
    final countBefore = stateBefore.purchasedProductIds.length;

    // Capture navigator early to avoid BuildContext use across async gaps
    final navigator = widget.dismissSheetOnComplete
        ? Navigator.of(context)
        : null;

    try {
      success = await restorePurchases(ref);
    } catch (e) {
      // Treat errors as no-ops for the UI; logs are handled within the restore flow
      success = false;
    }

    if (!mounted) return;

    safeSetState(() => _isLocalLoading = false);

    // Check if new purchases were restored (use captured notifier's state)
    final stateAfter = ref.read(purchaseStateProvider);
    final countAfter = stateAfter.purchasedProductIds.length;
    final restoredNew = countAfter > countBefore;

    // Dismiss sheet first if requested, so snackbar is visible
    if (navigator != null) {
      navigator.pop();
      // Small delay to allow sheet animation to complete
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
    }

    // Post-frame callbacks avoid BuildContext use across async gaps
    safePostFrame(() {
      if (success && restoredNew) {
        // New purchases were restored
        showSuccessSnackBar(context, 'Purchases restored successfully!');
      } else if (success) {
        // Purchases exist but none were new
        showInfoSnackBar(context, 'Your purchases are already active');
      } else {
        // No purchases found at all
        showInfoSnackBar(context, 'No purchases found to restore');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final globalLoading = ref.watch(subscriptionLoadingProvider);
    final isLoading = globalLoading || _isLocalLoading;

    return Column(
      children: [
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: isLoading ? null : () => _onPressed(context),
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: const Text('Restore Purchases'),
            style: TextButton.styleFrom(foregroundColor: context.accentColor),
          ),
        ),
      ],
    );
  }
}
