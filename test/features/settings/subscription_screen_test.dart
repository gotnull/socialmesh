// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/config/revenuecat_config.dart';
import 'package:socialmesh/features/settings/subscription_screen.dart';
import 'package:socialmesh/features/settings/widgets/restore_purchases_button.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/subscription_models.dart';
import 'package:socialmesh/providers/connectivity_providers.dart';
import 'package:socialmesh/providers/subscription_providers.dart';

final _l10n = AppLocalizationsEn();

/// Create a test-wrapped SubscriptionScreen with providers overridden.
Widget _buildTestWidget({
  PurchaseState purchaseState = const PurchaseState(),
  bool isLoading = false,
  String? error,
  Map<String, StoreProductInfo> storeProducts = const {},
  bool isOnline = true,
}) {
  return ProviderScope(
    overrides: [
      purchaseStateProvider.overrideWith(
        () => _TestPurchaseStateNotifier(purchaseState),
      ),
      subscriptionLoadingProvider.overrideWith(
        () => _TestLoadingNotifier(isLoading),
      ),
      subscriptionErrorProvider.overrideWith(() => _TestErrorNotifier(error)),
      storeProductsProvider.overrideWith((ref) => Future.value(storeProducts)),
      isOnlineProvider.overrideWithValue(isOnline),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: const SubscriptionScreen(),
    ),
  );
}

class _TestPurchaseStateNotifier extends PurchaseStateNotifier {
  _TestPurchaseStateNotifier(this._state);
  final PurchaseState _state;

  @override
  PurchaseState build() => _state;
}

class _TestLoadingNotifier extends SubscriptionLoadingNotifier {
  _TestLoadingNotifier(this._loading);
  final bool _loading;

  @override
  bool build() => _loading;
}

class _TestErrorNotifier extends SubscriptionErrorNotifier {
  _TestErrorNotifier(this._error);
  final String? _error;

  @override
  String? build() => _error;
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString: '''
THEME_PACK_PRODUCT_ID=theme_pack
RINGTONE_PACK_PRODUCT_ID=ringtone_pack
WIDGET_PACK_PRODUCT_ID=widget_pack
AUTOMATIONS_PACK_PRODUCT_ID=automations_pack
IFTTT_PACK_PRODUCT_ID=ifttt_pack
TRANSLATION_PACK_PRODUCT_ID=translation_pack
COMPLETE_PACK_PRODUCT_ID=complete_pack
TRANSLATION_ENABLED=false
''',
    );
  });

  group('SubscriptionScreen — paywall copy', () {
    testWidgets('header shows lifetime value proposition', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      // Use pump() instead of pumpAndSettle() because AnimatedGoldButton
      // has a perpetual shimmer animation that never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header subtitle: "One purchase. Yours forever. No subscription."
      expect(find.text(_l10n.subscriptionOneTimePurchases), findsOneWidget);
    });

    testWidgets('Complete Pack card renders with improved subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Complete Pack title
      expect(find.text(_l10n.subscriptionCompletePack), findsOneWidget);

      // Subtitle: "All premium features in one lifetime purchase"
      expect(find.text(_l10n.subscriptionCompletePackSubtitle), findsOneWidget);
    });

    testWidgets('CTA reads "Unlock Everything"', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(_l10n.subscriptionGetAll), findsOneWidget);
    });

    testWidgets('price framing reinforces lifetime and no subscription', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // "Lifetime access · No subscription"
      expect(find.text(_l10n.subscriptionBestValue), findsOneWidget);
    });

    testWidgets('benefit lines render outcome-driven descriptions', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Accent colors benefit
      expect(find.text(_l10n.subscriptionAccentColors), findsOneWidget);

      // Widgets benefit
      expect(find.text(_l10n.subscriptionUnlimitedWidgets), findsOneWidget);

      // Automations benefit
      expect(find.text(_l10n.subscriptionTriggersSchedules), findsOneWidget);

      // IFTTT benefit
      expect(find.text(_l10n.subscriptionAppIntegrations), findsOneWidget);
    });

    testWidgets('restore purchases button is visible after scrolling', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll down to reveal the RestorePurchasesButton (lazy slivers)
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byType(RestorePurchasesButton),
        300,
        scrollable: scrollable,
      );
      await tester.pump();
      expect(find.byType(RestorePurchasesButton), findsWidgets);
    });

    testWidgets('savings badge shows localized discount percentage', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The badge should show "SAVE XX%" using computed discount
      final discountPercent = OneTimePurchases.bundleDiscountPercent;
      expect(
        find.text(_l10n.subscriptionSavePercent(discountPercent.toString())),
        findsOneWidget,
      );
    });

    testWidgets(
      'all-unlocked state shows owned card instead of purchase card',
      (tester) async {
        final allOwned = PurchaseState(
          purchasedProductIds: {RevenueCatConfig.completePackProductId},
        );

        await tester.pumpWidget(_buildTestWidget(purchaseState: allOwned));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Should show "All Features Unlocked"
        expect(find.text(_l10n.subscriptionAllUnlocked), findsOneWidget);

        // CTA should NOT be present
        expect(find.text(_l10n.subscriptionGetAll), findsNothing);
      },
    );

    testWidgets('error state displays error message', (tester) async {
      await tester.pumpWidget(_buildTestWidget(error: 'Something went wrong'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Error message may be below fold — scroll to find it
      await tester.scrollUntilVisible(find.text('Something went wrong'), 200);
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('fallback price renders when store products unavailable', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(storeProducts: const {}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Fallback price uses OneTimePurchases.bundlePrice
      expect(
        find.text('\$${OneTimePurchases.bundlePrice.toStringAsFixed(2)}'),
        findsOneWidget,
      );
    });

    testWidgets('localized price renders when store products available', (
      tester,
    ) async {
      final products = {
        RevenueCatConfig.completePackProductId: const StoreProductInfo(
          productId: 'complete_pack',
          title: 'Complete Pack',
          description: 'All features',
          priceString: 'A\$22.99',
          price: 22.99,
        ),
      };

      await tester.pumpWidget(_buildTestWidget(storeProducts: products));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('A\$22.99'), findsOneWidget);
    });

    testWidgets('MOST POPULAR badge is visible on hero card', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(_l10n.subscriptionPopularBadge), findsOneWidget);
    });

    testWidgets('grouped benefit section headers render', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Personalisation and Automation group headers (uppercase)
      expect(
        find.text(_l10n.subscriptionGroupPersonalisation.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(_l10n.subscriptionGroupAutomation.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(_l10n.subscriptionGroupDashboard.toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('lifetime reinforcement line is visible below CTA', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll to find the reinforcement text if below the fold
      await tester.scrollUntilVisible(
        find.text(_l10n.subscriptionLifetimeReinforcement),
        200,
      );
      expect(
        find.text(_l10n.subscriptionLifetimeReinforcement),
        findsOneWidget,
      );
    });

    testWidgets('Starter Pack anchor card is visible when not all owned', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll to find the starter card if below the fold
      await tester.scrollUntilVisible(
        find.text(_l10n.subscriptionStarterPack),
        200,
      );
      expect(find.text(_l10n.subscriptionStarterPack), findsOneWidget);
      expect(find.text(_l10n.subscriptionStarterPackSubtitle), findsOneWidget);
    });

    testWidgets('Starter Pack anchor card is hidden when all owned', (
      tester,
    ) async {
      final allOwned = PurchaseState(
        purchasedProductIds: {RevenueCatConfig.completePackProductId},
      );

      await tester.pumpWidget(_buildTestWidget(purchaseState: allOwned));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(_l10n.subscriptionStarterPack), findsNothing);
    });
  });
}
