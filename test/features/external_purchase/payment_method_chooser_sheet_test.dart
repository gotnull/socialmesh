// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/config/revenuecat_config.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/features/external_purchase/payment_method_chooser_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/subscription_models.dart';
import 'package:socialmesh/providers/subscription_providers.dart';

class _Purchases extends PurchaseStateNotifier {
  _Purchases(this._owned);
  final Set<String> _owned;

  @override
  PurchaseState build() => PurchaseState(purchasedProductIds: _owned);
}

Future<void> _openChooser(
  WidgetTester tester, {
  required Set<String> owned,
  required String productId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [purchaseStateProvider.overrideWith(() => _Purchases(owned))],
      child: MaterialApp(
        theme: AppTheme.darkTheme(AccentColors.green),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showPaymentMethodChooserSheet(
                context: context,
                ref: ref,
                productId: productId,
                productName: 'Test Pack',
                priceUsd: 9.99,
                appStorePriceDisplay: r'$9.99',
                stripePriceDisplay: 'USD 9.99',
              ),
              child: const Text('Buy'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Buy'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    dotenv.loadFromString(envString: 'STRIPE_PURCHASES_ENABLED=true');
  });

  testWidgets('a product owned on either rail opens no payment options', (
    tester,
  ) async {
    await _openChooser(
      tester,
      owned: {RevenueCatConfig.completePackProductId},
      productId: RevenueCatConfig.completePackProductId,
    );

    expect(find.text('You already own Test Pack.'), findsOneWidget);
    expect(find.text('Choose payment method'), findsNothing);
  });

  testWidgets('a pack included in an owned Complete Pack is not sold again', (
    tester,
  ) async {
    await _openChooser(
      tester,
      owned: {RevenueCatConfig.completePackProductId},
      productId: RevenueCatConfig.widgetPackProductId,
    );

    expect(find.text('You already own Test Pack.'), findsOneWidget);
    expect(find.text('Choose payment method'), findsNothing);
  });

  testWidgets('an unowned product still offers both payment methods', (
    tester,
  ) async {
    await _openChooser(
      tester,
      owned: const {},
      productId: RevenueCatConfig.completePackProductId,
    );

    expect(find.text('Choose payment method'), findsOneWidget);
    expect(find.text('You already own Test Pack.'), findsNothing);
  });
}
