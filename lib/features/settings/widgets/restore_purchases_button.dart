import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../utils/snackbar.dart';
import '../../../providers/subscription_providers.dart';

class RestorePurchasesButton extends ConsumerStatefulWidget {
  const RestorePurchasesButton({super.key});

  @override
  ConsumerState<RestorePurchasesButton> createState() =>
      _RestorePurchasesButtonState();
}

class _RestorePurchasesButtonState
    extends ConsumerState<RestorePurchasesButton> {
  bool _isLocalLoading = false;

  Future<void> _onPressed(BuildContext context) async {
    setState(() => _isLocalLoading = true);
    bool success = false;

    // Capture state before restore to detect new purchases
    final stateBefore = ref.read(purchaseStateProvider);
    final countBefore = stateBefore.purchasedProductIds.length;

    try {
      success = await restorePurchases(ref);
    } catch (e) {
      // Treat errors as no-ops for the UI; logs are handled within the restore flow
      success = false;
    }

    if (!mounted) return;

    setState(() => _isLocalLoading = false);

    // Check if new purchases were restored
    final stateAfter = ref.read(purchaseStateProvider);
    final countAfter = stateAfter.purchasedProductIds.length;
    final restoredNew = countAfter > countBefore;

    // Post-frame callbacks avoid BuildContext use across async gaps
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
