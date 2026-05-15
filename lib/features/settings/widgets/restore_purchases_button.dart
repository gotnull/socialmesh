// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
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
      showErrorSnackBar(context, context.l10n.restorePurchasesRequiresInternet);
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

    // Check whether the underlying service hit PaymentPendingError during
    // this restore — the store may have a receipt the user thinks of as a
    // valid purchase but RevenueCat has not yet accepted. Surface a helpful
    // message instead of the misleading "no purchases found" fallback.
    bool hadPendingPayment = false;
    try {
      final service = await ref.read(subscriptionServiceProvider.future);
      hadPendingPayment = service.lastRestoreHadPendingPayment;
    } on Object {
      // ref may be disposed or the provider unavailable — fall through
      // with hadPendingPayment = false.
    }

    // External (Stripe / Buy Me a Coffee) packs are keyed to a Firebase
    // uid, not the App Store / Google Play account. Anonymous or
    // signed-out users won't get those back from the platform restore
    // alone — surface the sign-in path as the action when there's
    // nothing to celebrate from the IAP side.
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final needsSignInForExternal =
        firebaseUser == null || firebaseUser.isAnonymous;

    // Post-frame callbacks avoid BuildContext use across async gaps
    safePostFrame(() {
      if (success && restoredNew) {
        // New purchases were restored
        showSuccessSnackBar(context, context.l10n.restorePurchasesSuccess);
      } else if (success) {
        // Purchases exist but none were new
        showInfoSnackBar(context, context.l10n.restorePurchasesAlreadyActive);
      } else if (hadPendingPayment) {
        // Store has a pending receipt — explain rather than say "none".
        AppLogging.subscriptions(
          '[RestorePurchases] Showing pending-payment message to user',
        );
        showInfoSnackBar(context, context.l10n.restorePurchasesPending);
      } else if (needsSignInForExternal) {
        // No store purchases found AND signed out — they may still have
        // Stripe / Buy Me a Coffee packs bound to their email. The
        // backend's claimEntitlementsToAccount auto-matches verified
        // Firebase Auth email to buyer email at sign-in time.
        showActionSnackBar(
          context,
          context.l10n.restorePurchasesSignInForExternal,
          actionLabel: context.l10n.commonSignIn,
          onAction: () => Navigator.pushNamed(context, '/account'),
          type: SnackBarType.info,
        );
      } else {
        // Signed in, no purchases found anywhere.
        showInfoSnackBar(context, context.l10n.restorePurchasesNone);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final globalLoading = ref.watch(subscriptionLoadingProvider);
    final isLoading = globalLoading || _isLocalLoading;

    return Column(
      children: [
        const SizedBox(height: AppTheme.spacing16),
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
            label: Text(context.l10n.restorePurchasesTitle),
            style: TextButton.styleFrom(foregroundColor: context.accentColor),
          ),
        ),
      ],
    );
  }
}
