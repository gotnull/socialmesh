// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Pin the kill-switch behaviour for the external-purchase flags:
//   - STRIPE_PURCHASES_ENABLED  (primary external path, Chunk B+)
//   - BMC_PURCHASE_ENABLED      (secondary external path)
//   - AppFeatureFlags.isExternalPurchaseEnabled (computed union of the two)
//
// Off-by-default semantics: every entry point - UI link, redeem code
// link, deep link, entitlement merge - must be invisible/inert when
// both flags are unset or `false`. Re-enabling later is a single env
// flip per provider.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/constants.dart';
import 'package:socialmesh/features/external_purchase/alternative_payment_link.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: Scaffold(body: child),
    ),
  );
}

/// Clear both flags from dotenv's in-memory map. flutter_dotenv
/// rejects empty `loadFromString` calls (`EmptyEnvFileError`), so we
/// mutate the underlying map directly to simulate "env unset".
void _clearFlags() {
  try {
    dotenv.env.remove('STRIPE_PURCHASES_ENABLED');
    dotenv.env.remove('BMC_PURCHASE_ENABLED');
  } catch (_) {
    // dotenv not initialised yet - that's fine, the flag's try/catch
    // handles the uninitialised case as OFF.
  }
}

void _setStripe(String value) {
  dotenv.env['STRIPE_PURCHASES_ENABLED'] = value;
}

void _setBmc(String value) {
  dotenv.env['BMC_PURCHASE_ENABLED'] = value;
}

void main() {
  setUpAll(() {
    // flutter_dotenv throws NotInitializedError on the very first
    // `dotenv.env` access, AND rejects an empty `loadFromString` call
    // with EmptyEnvFileError. Seed the map once with a throwaway key
    // so per-test mutations (_clearFlags / _setStripe / _setBmc) can
    // operate on it. The seed leaves every gated flag OFF.
    dotenv.loadFromString(envString: '_FLAG_GATE_TEST_INIT=1');
  });

  setUp(_clearFlags);

  // -------------------------------------------------------------------------
  // AppFeatureFlags.isStripePurchasesEnabled
  // -------------------------------------------------------------------------

  group('AppFeatureFlags.isStripePurchasesEnabled', () {
    test('default (env unset) is OFF - opt-in only', () {
      _clearFlags();
      expect(AppFeatureFlags.isStripePurchasesEnabled, isFalse);
    });

    test('reads "true" as ON', () {
      _setStripe('true');
      expect(AppFeatureFlags.isStripePurchasesEnabled, isTrue);
    });

    test('reads "1" as ON (numeric form for CI / scripts)', () {
      _setStripe('1');
      expect(AppFeatureFlags.isStripePurchasesEnabled, isTrue);
    });

    test('reads "TRUE" as ON (case-insensitive)', () {
      _setStripe('TRUE');
      expect(AppFeatureFlags.isStripePurchasesEnabled, isTrue);
    });

    test('reads "false" as OFF', () {
      _setStripe('false');
      expect(AppFeatureFlags.isStripePurchasesEnabled, isFalse);
    });

    test('reads anything else as OFF (fail-safe default)', () {
      _setStripe('yes');
      expect(AppFeatureFlags.isStripePurchasesEnabled, isFalse);
      _setStripe('on');
      expect(AppFeatureFlags.isStripePurchasesEnabled, isFalse);
      _setStripe('enabled');
      expect(AppFeatureFlags.isStripePurchasesEnabled, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // AppFeatureFlags.isBuyMeACoffeeEnabled
  // -------------------------------------------------------------------------

  group('AppFeatureFlags.isBuyMeACoffeeEnabled', () {
    test('default (env unset) is OFF - opt-in only', () {
      _clearFlags();
      expect(AppFeatureFlags.isBuyMeACoffeeEnabled, isFalse);
    });

    test('reads "true" as ON', () {
      _setBmc('true');
      expect(AppFeatureFlags.isBuyMeACoffeeEnabled, isTrue);
    });

    test('reads "1" as ON', () {
      _setBmc('1');
      expect(AppFeatureFlags.isBuyMeACoffeeEnabled, isTrue);
    });

    test('reads "false" as OFF', () {
      _setBmc('false');
      expect(AppFeatureFlags.isBuyMeACoffeeEnabled, isFalse);
    });

    test('is independent of the Stripe flag', () {
      _setStripe('true');
      _setBmc('false');
      expect(AppFeatureFlags.isBuyMeACoffeeEnabled, isFalse);
      _setBmc('true');
      _setStripe('false');
      expect(AppFeatureFlags.isBuyMeACoffeeEnabled, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // AppFeatureFlags.isExternalPurchaseEnabled (computed union)
  // -------------------------------------------------------------------------

  group('AppFeatureFlags.isExternalPurchaseEnabled (computed)', () {
    test('OFF when both providers are off (or unset)', () {
      _clearFlags();
      expect(AppFeatureFlags.isExternalPurchaseEnabled, isFalse);
      _setStripe('false');
      _setBmc('false');
      expect(AppFeatureFlags.isExternalPurchaseEnabled, isFalse);
    });

    test('ON when only Stripe is on', () {
      _setStripe('true');
      _setBmc('false');
      expect(AppFeatureFlags.isExternalPurchaseEnabled, isTrue);
    });

    test('ON when only BMC is on', () {
      _setStripe('false');
      _setBmc('true');
      expect(AppFeatureFlags.isExternalPurchaseEnabled, isTrue);
    });

    test('ON when both are on', () {
      _setStripe('true');
      _setBmc('true');
      expect(AppFeatureFlags.isExternalPurchaseEnabled, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // AlternativePaymentLink rendering gate (BMC-specific surface).
  //
  // The link opens the BMC handoff sheet today, so it's gated on
  // isBuyMeACoffeeEnabled NOT the computed umbrella flag. Stripe will
  // get its own dedicated link primitive in Chunk C.
  // -------------------------------------------------------------------------

  group('AlternativePaymentLink (BMC-only UI gate)', () {
    testWidgets('renders nothing when BMC flag is OFF (and Stripe OFF)', (
      tester,
    ) async {
      _clearFlags();
      await tester.pumpWidget(
        _wrap(const AlternativePaymentLink(productId: 'theme_pack')),
      );
      expect(find.text('Alternative payment'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('renders nothing when BMC is OFF even with Stripe ON '
        '(Stripe needs its own primitive in Chunk C)', (tester) async {
      _setStripe('true');
      _setBmc('false');
      await tester.pumpWidget(
        _wrap(const AlternativePaymentLink(productId: 'theme_pack')),
      );
      expect(find.text('Alternative payment'), findsNothing);
    });

    testWidgets('renders the link when BMC flag is ON', (tester) async {
      _setBmc('true');
      await tester.pumpWidget(
        _wrap(const AlternativePaymentLink(productId: 'theme_pack')),
      );
      expect(find.text('Alternative payment'), findsOneWidget);
    });
  });
}
