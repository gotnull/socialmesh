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

    try {
      success = await restorePurchases(ref);
    } catch (e) {
      // Treat errors as no-ops for the UI; logs are handled within the restore flow
      success = false;
    }

    if (!mounted) return;

    setState(() => _isLocalLoading = false);

    // Post-frame callbacks avoid BuildContext use across async gaps
    if (success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showSuccessSnackBar(context, 'Purchases restored');
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showInfoSnackBar(context, 'No purchases found to restore');
      });
    }
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
