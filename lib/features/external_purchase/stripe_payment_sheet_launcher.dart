// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Shared Stripe Payment Sheet launcher.
//
// Personal-pack (payment_method_chooser_sheet.dart) and org-pack
// (org_checkout_sheet.dart) both need the same init + present sequence:
// re-sync publishable key, build platform-appropriate wallet params,
// call initPaymentSheet, call presentPaymentSheet. Keeping a single
// implementation here means a wallet config change applies to both
// flows together. Previously the org sheet shipped without Apple Pay
// because the chooser's init code was inlined and never copied across.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;

import '../../core/logging.dart';
import '../../services/external_purchase/external_entitlement.dart';

/// Initialise and present the native Stripe Payment Sheet for
/// [descriptor]. Both personal-pack and org-pack flows funnel through
/// this so wallet config (Apple Pay / Google Pay) cannot drift.
///
/// Throws [stripe.StripeException] on user cancel or failure. Callers
/// map the result per their own UX (snackbar vs silent vs sheet-state).
Future<void> launchStripePaymentSheet({
  required CheckoutSessionDescriptor descriptor,
  String merchantDisplayName = 'SocialMesh',
  String merchantCountryCode = 'AU',
  String currencyCode = 'AUD',
}) async {
  if (descriptor.provider != CheckoutProvider.stripe ||
      descriptor.clientSecret.isEmpty) {
    throw StateError(
      'launchStripePaymentSheet expects a Stripe descriptor with a '
      'non-empty clientSecret; got provider=${descriptor.provider} '
      'hasClientSecret=${descriptor.clientSecret.isNotEmpty}',
    );
  }

  if (descriptor.publishableKey.isNotEmpty &&
      descriptor.publishableKey != stripe.Stripe.publishableKey) {
    AppLogging.purchase(
      '[StripePaymentSheet] re-setting publishable key from server response',
    );
    stripe.Stripe.publishableKey = descriptor.publishableKey;
    await stripe.Stripe.instance.applySettings();
  }

  final merchantId = stripe.Stripe.merchantIdentifier ?? '';
  final applePay = shouldOfferApplePay(merchantId);
  final googlePay = shouldOfferGooglePay();
  AppLogging.purchase(
    '[StripePaymentSheet] initPaymentSheet '
    'applePay=$applePay googlePay=$googlePay '
    'merchantId=${merchantId.isEmpty ? '<none>' : merchantId}',
  );

  await stripe.Stripe.instance.initPaymentSheet(
    paymentSheetParameters: stripe.SetupPaymentSheetParameters(
      paymentIntentClientSecret: descriptor.clientSecret,
      merchantDisplayName: merchantDisplayName,
      applePay: applePay
          ? stripe.PaymentSheetApplePay(
              merchantCountryCode: merchantCountryCode,
            )
          : null,
      googlePay: googlePay
          ? stripe.PaymentSheetGooglePay(
              merchantCountryCode: merchantCountryCode,
              currencyCode: currencyCode,
              // Sandbox network when STRIPE_USE_TEST_MODE=true on the
              // backend - matches whatever publishable key the server
              // returned.
              testEnv: descriptor.publishableKey.startsWith('pk_test_'),
            )
          : null,
      // Required for redirect-based methods on Android (Link's
      // "Back to <app>" button, 3DS auth). The SDK uses this URL
      // as the redirect target; DeepLinkManager intercepts the
      // returning intent and forwards it to
      // Stripe.instance.handleURLCallback so the Payment Sheet can
      // complete. Must match Stripe.urlScheme set at boot.
      returnURL: 'socialmesh://stripe-redirect',
    ),
  );

  AppLogging.purchase('[StripePaymentSheet] presentPaymentSheet');
  await stripe.Stripe.instance.presentPaymentSheet();
}

/// Apple Pay is iOS-only and requires a merchant identifier set at boot.
bool shouldOfferApplePay(String merchantId) {
  if (kIsWeb) return false;
  if (merchantId.isEmpty) return false;
  try {
    return defaultTargetPlatform == TargetPlatform.iOS && Platform.isIOS;
  } catch (_) {
    return false;
  }
}

/// Google Pay is Android-only. Stripe owns the GP merchant on our
/// behalf, so no app-side merchant identifier is required.
bool shouldOfferGooglePay() {
  if (kIsWeb) return false;
  try {
    return defaultTargetPlatform == TargetPlatform.android &&
        Platform.isAndroid;
  } catch (_) {
    return false;
  }
}
