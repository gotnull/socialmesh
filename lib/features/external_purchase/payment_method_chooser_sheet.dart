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
import '../../core/safety/lifecycle_mixin.dart';
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

  // The sheet runs the purchase internally so the chosen row shows a
  // spinner until the native confirmation surface (App Store sheet /
  // Stripe Payment Sheet) takes over. The sheet pops with the
  // _PaymentMethodResult once the purchase resolves.
  final result = await AppBottomSheet.show<_PaymentMethodResult>(
    context: context,
    isDismissible: true,
    child: _PaymentMethodChooserContent(
      productId: productId,
      productName: productName,
      priceAud: priceAud,
    ),
  );
  if (!context.mounted) return;
  AppLogging.purchase('[PaymentChooser] sheet result=$result');
  _handleOrchestratorResult(
    context,
    ref,
    result ?? _PaymentMethodResult.canceled,
    onSuccess: onSuccess,
  );
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
    final googlePay = _shouldOfferGooglePay();
    AppLogging.purchase(
      '[StripePurchase] initPaymentSheet '
      'applePay=$applePay googlePay=$googlePay '
      'merchantId=${merchantId.isEmpty ? '<none>' : merchantId}',
    );

    await stripe.Stripe.instance.initPaymentSheet(
      paymentSheetParameters: stripe.SetupPaymentSheetParameters(
        paymentIntentClientSecret: descriptor.clientSecret,
        merchantDisplayName: 'SocialMesh',
        applePay: applePay
            ? stripe.PaymentSheetApplePay(merchantCountryCode: 'AU')
            : null,
        googlePay: googlePay
            ? stripe.PaymentSheetGooglePay(
                merchantCountryCode: 'AU',
                currencyCode: 'AUD',
                // Sandbox network when STRIPE_USE_TEST_MODE=true on
                // the backend - matches whatever publishable key the
                // server returned.
                testEnv: descriptor.publishableKey.startsWith('pk_test_'),
              )
            : null,
        // Required for redirect-based methods on Android (Link's
        // "Back to <app>" button, 3DS auth). The SDK uses this URL
        // as the redirect target; DeepLinkManager intercepts the
        // returning intent and forwards it to
        // Stripe.instance.handleURLCallback so the Payment Sheet
        // can complete. Must match Stripe.urlScheme set at boot.
        returnURL: 'socialmesh://stripe-redirect',
      ),
    );
    AppLogging.purchase('[StripePurchase] presentPaymentSheet');
    await stripe.Stripe.instance.presentPaymentSheet();

    // Payment Sheet returned success. Kick the confirmation overlay so
    // the UI surfaces a spinner until the webhook lands; the entitlement
    // merge then auto-flips ownership state across every consumer.
    // Wake the confirmation overlay - polls for the webhook landing.
    // service.handleDeepLink is fire-and-forget and doesn't need a
    // BuildContext, so no mounted guard required here.
    service.handleDeepLink(descriptor.sessionId);

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

bool _shouldOfferGooglePay() {
  // Google Pay requires no app-side merchant identifier (Stripe owns
  // the GP merchant on our behalf). Android-only - on iOS the user
  // gets Apple Pay instead.
  if (kIsWeb) return false;
  try {
    return defaultTargetPlatform == TargetPlatform.android &&
        Platform.isAndroid;
  } catch (_) {
    return false;
  }
}

// =============================================================================
// UI
// =============================================================================

class _PaymentMethodChooserContent extends ConsumerStatefulWidget {
  final String productId;
  final String productName;
  final double priceAud;

  const _PaymentMethodChooserContent({
    required this.productId,
    required this.productName,
    required this.priceAud,
  });

  @override
  ConsumerState<_PaymentMethodChooserContent> createState() =>
      _PaymentMethodChooserContentState();
}

class _PaymentMethodChooserContentState
    extends ConsumerState<_PaymentMethodChooserContent>
    with LifecycleSafeMixin<_PaymentMethodChooserContent> {
  _PaymentMethod? _busy;

  Future<void> _onPicked(_PaymentMethod method) async {
    if (_busy != null) return;
    safeSetState(() => _busy = method);
    ref.haptics.buttonTap();

    final result = method == _PaymentMethod.store
        ? await _runStorePurchase(ref, widget.productId)
        : await _runStripePurchase(ref, widget.productId);
    if (!mounted) return;
    AppLogging.purchase('[PaymentChooser] ${method.name} path result=$result');
    safeNavigatorPop<_PaymentMethodResult>(result);
  }

  String _storeLabel() {
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
    if (kIsWeb) return Icons.shopping_bag_outlined;
    try {
      if (Platform.isIOS) return Icons.apple;
      if (Platform.isAndroid) return Icons.shop_outlined;
    } catch (_) {
      // Fall through.
    }
    return Icons.shopping_bag_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final price = 'A\$${widget.priceAud.toStringAsFixed(2)}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Compact header: title + product context on one tight block.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            0,
            AppTheme.spacing4,
            0,
            AppTheme.spacing4,
          ),
          child: Text(
            context.l10n.paymentChooserTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              height: 1.2,
              color: context.textPrimary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacing20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.productName,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textTertiary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: context.textSecondary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),
        ),
        // Grouped row stack: bordered card, divider between rows. This
        // is the canonical inner-settings density - mirrors the way
        // mqtt_config_screen groups related toggles.
        Container(
          // antiAlias clipping so each row's InkWell splash respects
          // the outer border radius (without it, the bottom row's
          // ripple bleeds into square corners). The matching
          // borderRadius on the Container is what the clip uses.
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(color: context.border, width: 1),
          ),
          child: Column(
            children: [
              _PaymentMethodRow(
                icon: _storeIcon(),
                label: _storeLabel(),
                subtitle: context.l10n.paymentChooserStoreSubtitle,
                enabled: _busy == null,
                busy: _busy == _PaymentMethod.store,
                onTap: () => _onPicked(_PaymentMethod.store),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: context.border,
                indent: AppTheme.spacing16,
                endIndent: AppTheme.spacing16,
              ),
              _PaymentMethodRow(
                icon: Icons.credit_card_outlined,
                label: context.l10n.paymentChooserStripeLabel,
                subtitle: context.l10n.paymentChooserStripeSubtitle,
                enabled: _busy == null,
                busy: _busy == _PaymentMethod.stripe,
                onTap: () => _onPicked(_PaymentMethod.stripe),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  const _PaymentMethodRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? context.textPrimary
        : context.textPrimary.withValues(alpha: 0.4);
    final secondary = enabled
        ? context.textTertiary
        : context.textTertiary.withValues(alpha: 0.5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing14,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                        height: 1.2,
                        color: foreground,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: secondary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              SizedBox(
                width: 16,
                height: 16,
                child: busy
                    ? CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: foreground,
                      )
                    : Icon(Icons.chevron_right, size: 16, color: secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
