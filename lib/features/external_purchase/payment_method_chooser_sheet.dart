// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;

import '../../core/constants.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../providers/external_purchase_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../services/external_purchase/external_entitlement.dart';
import '../../services/haptic_service.dart';
import '../../services/subscription/subscription_service.dart'
    show PurchaseResult;
import '../../utils/snackbar.dart';

// Outcome of the chooser flow.
//
//   - success: payment captured (either store IAP or Stripe Payment Sheet
//     confirmed). The webhook still has to land for Stripe before the
//     entitlement is visible; the confirmation overlay polls.
//   - canceled: user dismissed the sheet, the store sheet, or the Stripe
//     Payment Sheet. Silent.
//   - error: a non-cancel failure. Caller shows a snackbar.
enum _PaymentMethodResult { success, canceled, error }

// Method the user picked, returned via Navigator.pop. Internal to the
// sheet - the orchestrator routes by it.
enum _PaymentMethod { store, stripe }

// Public entry point. Always returns - if the user dismisses, you get
// canceled. Caller drives any success-state UI (celebration, etc.).
//
// Skip the chooser entirely (go straight to the store path) when
// STRIPE_PURCHASES_ENABLED is off - keeps current behavior for builds
// where Stripe is not provisioned.
Future<void> showPaymentMethodChooserSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String productId,
  required String productName,
  required double priceAud,
  VoidCallback? onSuccess,
}) async {
  AppLogging.purchase(
    '[PaymentChooser] open productId=$productId productName="$productName" '
    'price=A\$${priceAud.toStringAsFixed(2)} '
    'stripeEnabled=${AppFeatureFlags.isStripePurchasesEnabled}',
  );

  if (!AppFeatureFlags.isStripePurchasesEnabled) {
    // No external provider on - go direct to store IAP, matching the
    // pre-Chunk-C behavior.
    AppLogging.purchase(
      '[PaymentChooser] Stripe disabled - routing direct to store IAP',
    );
    final result = await _runStorePurchase(ref, productId);
    if (!context.mounted) return;
    _handleOrchestratorResult(context, ref, result, onSuccess: onSuccess);
    return;
  }

  final picked = await AppBottomSheet.show<_PaymentMethod>(
    context: context,
    child: _PaymentMethodChooserContent(
      productName: productName,
      priceAud: priceAud,
    ),
  );
  AppLogging.purchase('[PaymentChooser] user picked=$picked');
  if (picked == null) return;
  if (!context.mounted) return;

  switch (picked) {
    case _PaymentMethod.store:
      final result = await _runStorePurchase(ref, productId);
      if (!context.mounted) return;
      AppLogging.purchase('[PaymentChooser] store path result=$result');
      _handleOrchestratorResult(context, ref, result, onSuccess: onSuccess);
    case _PaymentMethod.stripe:
      final result = await _runStripePurchase(context, ref, productId);
      if (!context.mounted) return;
      AppLogging.purchase('[PaymentChooser] stripe path result=$result');
      _handleOrchestratorResult(context, ref, result, onSuccess: onSuccess);
  }
}

void _handleOrchestratorResult(
  BuildContext context,
  WidgetRef ref,
  _PaymentMethodResult result, {
  VoidCallback? onSuccess,
}) {
  switch (result) {
    case _PaymentMethodResult.success:
      ref.haptics.success();
      onSuccess?.call();
    case _PaymentMethodResult.canceled:
      break;
    case _PaymentMethodResult.error:
      ref.haptics.error();
      showErrorSnackBar(context, context.l10n.premiumPurchaseFailed);
  }
}

Future<_PaymentMethodResult> _runStorePurchase(
  WidgetRef ref,
  String productId,
) async {
  final result = await purchaseProduct(ref, productId);
  switch (result) {
    case PurchaseResult.success:
      return _PaymentMethodResult.success;
    case PurchaseResult.canceled:
      return _PaymentMethodResult.canceled;
    case PurchaseResult.error:
      return _PaymentMethodResult.error;
  }
}

Future<_PaymentMethodResult> _runStripePurchase(
  BuildContext context,
  WidgetRef ref,
  String productId,
) async {
  AppLogging.purchase(
    '[StripePurchase] start productId=$productId '
    'stripeFlag=${AppFeatureFlags.isStripePurchasesEnabled} '
    'publishableKeyAtBoot=${stripe.Stripe.publishableKey.isEmpty ? '<empty>' : '${stripe.Stripe.publishableKey.substring(0, 8)}...'}',
  );
  try {
    final service = await ref.read(externalPurchaseServiceProvider.future);
    AppLogging.purchase(
      '[StripePurchase] calling createCheckout(provider=stripe)',
    );
    final descriptor = await service.createCheckout(
      productId,
      provider: 'stripe',
    );
    AppLogging.purchase(
      '[StripePurchase] descriptor received '
      'provider=${descriptor.provider} '
      'sessionId=${descriptor.sessionId} '
      'paymentIntentId=${descriptor.paymentIntentId} '
      'hasClientSecret=${descriptor.clientSecret.isNotEmpty} '
      'hasPublishableKey=${descriptor.publishableKey.isNotEmpty} '
      'checkoutUrl="${descriptor.checkoutUrl}"',
    );

    if (descriptor.provider != CheckoutProvider.stripe ||
        descriptor.clientSecret.isEmpty) {
      AppLogging.purchase(
        '[StripePurchase] ABORT: backend returned non-Stripe descriptor or empty clientSecret '
        'provider=${descriptor.provider} hasClientSecret=${descriptor.clientSecret.isNotEmpty}',
      );
      return _PaymentMethodResult.error;
    }

    // Re-set the publishable key if the server returned one for the
    // active mode that differs from the one we booted with. This is the
    // mechanism that lets us flip test->live mode entirely server-side.
    if (descriptor.publishableKey.isNotEmpty &&
        descriptor.publishableKey != stripe.Stripe.publishableKey) {
      AppLogging.purchase(
        '[StripePurchase] re-setting publishable key from server response',
      );
      stripe.Stripe.publishableKey = descriptor.publishableKey;
      await stripe.Stripe.instance.applySettings();
    }

    final merchantId = stripe.Stripe.merchantIdentifier ?? '';
    final applePay = _shouldOfferApplePay(merchantId);
    AppLogging.purchase(
      '[StripePurchase] initPaymentSheet '
      'applePay=$applePay merchantId=${merchantId.isEmpty ? '<none>' : merchantId}',
    );

    await stripe.Stripe.instance.initPaymentSheet(
      paymentSheetParameters: stripe.SetupPaymentSheetParameters(
        paymentIntentClientSecret: descriptor.clientSecret,
        merchantDisplayName: 'SocialMesh',
        applePay: applePay
            ? stripe.PaymentSheetApplePay(merchantCountryCode: 'AU')
            : null,
      ),
    );
    AppLogging.purchase('[StripePurchase] presentPaymentSheet');
    await stripe.Stripe.instance.presentPaymentSheet();

    // Payment Sheet returned success. Kick the confirmation overlay so
    // the UI surfaces a spinner until the webhook lands; the entitlement
    // merge then auto-flips ownership state across every consumer.
    if (context.mounted) {
      service.handleDeepLink(descriptor.sessionId);
    }

    AppLogging.purchase(
      '[StripePurchase] Payment Sheet confirmed sessionId=${descriptor.sessionId} '
      'paymentIntent=${descriptor.paymentIntentId}',
    );
    return _PaymentMethodResult.success;
  } on stripe.StripeException catch (e) {
    // Stripe surfaces user cancel via StripeException with code=Canceled.
    if (e.error.code == stripe.FailureCode.Canceled) {
      AppLogging.purchase('[StripePurchase] user canceled Payment Sheet');
      return _PaymentMethodResult.canceled;
    }
    AppLogging.purchase(
      '[StripePurchase] StripeException code=${e.error.code} '
      'message=${e.error.message} '
      'localizedMessage=${e.error.localizedMessage}',
    );
    return _PaymentMethodResult.error;
  } catch (e, st) {
    AppLogging.purchase('[StripePurchase] FAILED $e\n$st');
    return _PaymentMethodResult.error;
  }
}

bool _shouldOfferApplePay(String merchantId) {
  if (kIsWeb) return false;
  if (merchantId.isEmpty) return false;
  try {
    return defaultTargetPlatform == TargetPlatform.iOS && Platform.isIOS;
  } catch (_) {
    return false;
  }
}

// =============================================================================
// UI
// =============================================================================

class _PaymentMethodChooserContent extends StatelessWidget {
  final String productName;
  final double priceAud;

  const _PaymentMethodChooserContent({
    required this.productName,
    required this.priceAud,
  });

  String _storeLabel(BuildContext context) {
    if (kIsWeb) {
      return context.l10n.paymentChooserStoreLabelGeneric;
    }
    try {
      if (Platform.isIOS) {
        return context.l10n.paymentChooserStoreLabelApple;
      }
      if (Platform.isAndroid) {
        return context.l10n.paymentChooserStoreLabelGoogle;
      }
    } catch (_) {
      // Platform not available (web) - fall through.
    }
    return context.l10n.paymentChooserStoreLabelGeneric;
  }

  IconData _storeIcon() {
    if (kIsWeb) {
      return Icons.shopping_bag_outlined;
    }
    try {
      if (Platform.isIOS) {
        return Icons.apple;
      }
      if (Platform.isAndroid) {
        return Icons.shop_outlined;
      }
    } catch (_) {
      // Fall through.
    }
    return Icons.shopping_bag_outlined;
  }

  String _formatPrice() {
    return 'A\$${priceAud.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
          child: Text(
            context.l10n.paymentChooserTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
          child: Text(
            '$productName · ${_formatPrice()}',
            style: TextStyle(
              fontSize: 13,
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ),
        _PaymentMethodRow(
          icon: _storeIcon(),
          label: _storeLabel(context),
          subtitle: context.l10n.paymentChooserStoreSubtitle,
          price: _formatPrice(),
          onTap: () => Navigator.of(context).pop(_PaymentMethod.store),
        ),
        const SizedBox(height: AppTheme.spacing12),
        _PaymentMethodRow(
          icon: Icons.credit_card_outlined,
          label: context.l10n.paymentChooserStripeLabel,
          subtitle: context.l10n.paymentChooserStripeSubtitle,
          price: _formatPrice(),
          onTap: () => Navigator.of(context).pop(_PaymentMethod.stripe),
        ),
      ],
    );
  }
}

class _PaymentMethodRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String price;
  final VoidCallback onTap;

  const _PaymentMethodRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(AppTheme.radius12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          child: Row(
            children: [
              Icon(icon, size: 24, color: context.accentColor),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Icon(Icons.chevron_right, size: 18, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
