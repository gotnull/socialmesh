// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Pin the kill-switch behaviour for `EXTERNAL_PURCHASE_ENABLED`.
//
// Off-by-default semantics: every entry point — UI link, redeem code
// link, deep link — must be invisible/inert when the flag is unset
// or `false`. Re-enabling later is a single env flip.

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

/// Clear the flag from dotenv's in-memory map. flutter_dotenv rejects
/// empty `loadFromString` calls (`EmptyEnvFileError`), so we mutate
/// the underlying map directly to simulate "env unset".
void _clearFlag() {
  try {
    dotenv.env.remove('EXTERNAL_PURCHASE_ENABLED');
  } catch (_) {
    // dotenv not initialised yet — that's fine, the flag's try/catch
    // handles the uninitialised case as OFF.
  }
}

void _setFlag(String value) {
  // loadFromString resets the entire map, which is exactly what we
  // want between tests for isolation.
  dotenv.loadFromString(envString: 'EXTERNAL_PURCHASE_ENABLED=$value');
}

void main() {
  setUp(_clearFlag);

  // -------------------------------------------------------------------------
  // AppFeatureFlags.isExternalPurchaseEnabled
  // -------------------------------------------------------------------------

  group('AppFeatureFlags.isExternalPurchaseEnabled', () {
    test('default (env unset) is OFF — opt-in only', () {
      // The whole point of the flag: production builds without an
      // explicit opt-in see no fallback path. A regression that
      // flipped the default to true would silently expose every
      // user to BMC links before BMC config is verified.
      _clearFlag();
      expect(AppFeatureFlags.isExternalPurchaseEnabled, isFalse);
    });

    test('reads "true" as ON', () {
      _setFlag('true');
      expect(AppFeatureFlags.isExternalPurchaseEnabled, isTrue);
    });

    test('reads "1" as ON (numeric form for CI / scripts)', () {
      _setFlag('1');
      expect(AppFeatureFlags.isExternalPurchaseEnabled, isTrue);
    });

    test('reads "TRUE" as ON (case-insensitive)', () {
      _setFlag('TRUE');
      expect(AppFeatureFlags.isExternalPurchaseEnabled, isTrue);
    });

    test('reads "false" as OFF', () {
      _setFlag('false');
      expect(AppFeatureFlags.isExternalPurchaseEnabled, isFalse);
    });

    test('reads anything else as OFF (fail-safe default)', () {
      // Typo in .env — `EXTERNAL_PURCHASE_ENABLED=enabled`, `=yes`,
      // `=on` etc. should NOT enable the feature. Only the documented
      // truthy strings count.
      _setFlag('yes');
      expect(AppFeatureFlags.isExternalPurchaseEnabled, isFalse);

      _setFlag('on');
      expect(AppFeatureFlags.isExternalPurchaseEnabled, isFalse);

      _setFlag('enabled');
      expect(AppFeatureFlags.isExternalPurchaseEnabled, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // AlternativePaymentLink rendering gate
  // -------------------------------------------------------------------------

  group('AlternativePaymentLink (UI gate)', () {
    testWidgets('renders nothing when flag is OFF', (tester) async {
      _clearFlag();
      await tester.pumpWidget(
        _wrap(const AlternativePaymentLink(productId: 'theme_pack')),
      );
      // The label MUST NOT be in the tree. If the link rendered we'd
      // see "Alternative payment".
      expect(find.text('Alternative payment'), findsNothing);
      // SizedBox.shrink is what the widget returns — verify zero
      // visual footprint (no TextButton in tree).
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('renders the link when flag is ON', (tester) async {
      _setFlag('true');
      await tester.pumpWidget(
        _wrap(const AlternativePaymentLink(productId: 'theme_pack')),
      );
      expect(find.text('Alternative payment'), findsOneWidget);
    });
  });
}
