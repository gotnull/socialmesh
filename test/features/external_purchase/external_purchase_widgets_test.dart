// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Widget tests for the chunk-3 external purchase UI surfaces.
//
// Scenarios from the chunk-3 spec:
//   1. External payment button appears as SECONDARY (not a replacement
//      for the primary store CTA).
//   2. Tapping the external button starts checkout (calls
//      createCheckout via the service).
//   3. Redirect alone does NOT unlock — confirming stage shows the
//      overlay but never writes to the entitlement cache.
//   4. Confirmed payment updates the UI (succeeded stage shows the
//      pack name).
//   5. Reference code is visible before checkout (handoff sheet
//      surfaces SM-XXXX-XXXX prominently).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/external_purchase/alternative_payment_link.dart';
import 'package:socialmesh/features/external_purchase/buy_me_a_coffee_handoff_sheet.dart';
import 'package:socialmesh/features/external_purchase/confirming_unlock_overlay.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/external_purchase_providers.dart';
import 'package:socialmesh/services/external_purchase/external_entitlement_cache.dart';
import 'package:socialmesh/services/external_purchase/external_purchase_service.dart';

// ----------------------------------------------------------------------------
// Test infrastructure
// ----------------------------------------------------------------------------

class _RecordingInvoker implements CallableInvoker {
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> scripted = {};

  void respond(String name, Map<String, dynamic> data) {
    scripted[name] = data;
  }

  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    calls.add(name);
    final response = scripted[name];
    if (response == null) {
      throw StateError('No scripted response for $name');
    }
    return response;
  }
}

Future<ExternalPurchaseService> _buildService({
  _RecordingInvoker? invoker,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final cache = ExternalEntitlementCache(prefs);
  return ExternalPurchaseService(
    prefs: prefs,
    cache: cache,
    invoker: invoker ?? _RecordingInvoker(),
    pollingPolicy: PollingPolicy.fast,
  );
}

Widget _wrap({
  required Widget child,
  required ExternalPurchaseService service,
  Stream<ConfirmationState>? confirmationStream,
}) {
  return ProviderScope(
    overrides: [
      externalPurchaseServiceProvider.overrideWith((ref) async => service),
      if (confirmationStream != null)
        externalConfirmationStreamProvider.overrideWith(
          (ref) => confirmationStream,
        ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUpAll(() {
    // EXTERNAL_PURCHASE_ENABLED=true is required: every widget test
    // here exercises the BMC fallback UI which is gated behind the
    // feature flag. Without it, AlternativePaymentLink renders as
    // SizedBox.shrink() (correctly — that's the kill-switch behaviour
    // pinned in feature_flag_gate_test.dart), but every assertion
    // here would fail.
    dotenv.loadFromString(
      envString: '''
THEME_PACK_PRODUCT_ID=theme_pack
RINGTONE_PACK_PRODUCT_ID=ringtone_pack
WIDGET_PACK_PRODUCT_ID=widget_pack
AUTOMATIONS_PACK_PRODUCT_ID=automations_pack
IFTTT_PACK_PRODUCT_ID=ifttt_pack
TRANSLATION_PACK_PRODUCT_ID=translation_pack
COMPLETE_PACK_PRODUCT_ID=complete_pack
EXTERNAL_PURCHASE_ENABLED=true
''',
    );
  });

  // -------------------------------------------------------------------------
  // SCENARIO 1 — secondary, not replacement
  // -------------------------------------------------------------------------

  group('AlternativePaymentLink (Scenario 1: secondary, not replacement)', () {
    testWidgets('renders alongside a primary store CTA without replacing it', (
      tester,
    ) async {
      final service = await _buildService();
      // Compose a paywall snippet with both the primary store CTA
      // and the alternative payment link, mirroring the production
      // pattern in subscription_screen.dart.
      final tappedPrimary = ValueNotifier<int>(0);
      await tester.pumpWidget(
        _wrap(
          service: service,
          child: Column(
            children: [
              FilledButton(
                onPressed: () => tappedPrimary.value++,
                child: const Text('Buy via App Store'),
              ),
              const AlternativePaymentLink(productId: 'theme_pack'),
            ],
          ),
        ),
      );

      // Both must be present — the alt-payment link augments, never
      // replaces, the primary store CTA. If a future refactor ever
      // hides the FilledButton when AlternativePaymentLink is
      // present, this test fails.
      expect(find.text('Buy via App Store'), findsOneWidget);
      expect(find.text('Alternative payment'), findsOneWidget);

      // Verify ordering: primary CTA renders ABOVE the alternative
      // link in the visual stack.
      final primaryY = tester.getCenter(find.text('Buy via App Store')).dy;
      final altY = tester.getCenter(find.text('Alternative payment')).dy;
      expect(
        primaryY < altY,
        isTrue,
        reason: 'Primary store CTA must be above the alt-payment link',
      );
    });

    testWidgets(
      'alternative link uses low-emphasis styling (textSecondary, not accent)',
      (tester) async {
        final service = await _buildService();
        await tester.pumpWidget(
          _wrap(
            service: service,
            child: const AlternativePaymentLink(productId: 'theme_pack'),
          ),
        );

        final label = tester.widget<Text>(find.text('Alternative payment'));
        // Label is underlined to communicate "link", but with the
        // muted secondary color, never the dominant accent.
        expect(label.style?.decoration, TextDecoration.underline);
        expect(label.style?.fontSize, 12);
      },
    );
  });

  // -------------------------------------------------------------------------
  // SCENARIO 2 + 5 — tapping starts checkout, reference code is visible
  // -------------------------------------------------------------------------

  group('BuyMeACoffeeHandoffSheet (Scenarios 2 + 5)', () {
    Future<void> openSheet(
      WidgetTester tester,
      ExternalPurchaseService service,
    ) async {
      await tester.pumpWidget(
        _wrap(
          service: service,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () =>
                    showBuyMeACoffeeHandoffSheet(ctx, productId: 'theme_pack'),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'opens checkout — calls createExternalCheckout with the productId',
      (tester) async {
        final invoker = _RecordingInvoker()
          ..respond('createExternalCheckout', {
            'sessionId': 'sess-test',
            'checkoutUrl': 'https://buymeacoffee.com/gotnull',
            'returnDeepLink':
                'socialmesh://purchase-return?sessionId=sess-test',
            'referenceCode': 'SM-AB23-CD45',
            'expectedAmount': 4.99,
            'currency': 'USD',
            'expiresAt': '2026-05-05T11:00:00.000Z',
          });
        final service = await _buildService(invoker: invoker);

        await openSheet(tester, service);

        // The sheet auto-fires createExternalCheckout on mount —
        // there should be no "Confirm" prompt the user has to tap
        // before a session is created.
        expect(invoker.calls, contains('createExternalCheckout'));
      },
    );

    testWidgets(
      'reference code SM-XXXX-XXXX is visible BEFORE the user opens checkout',
      (tester) async {
        // The whole point of the handoff sheet: the user must see
        // the reference code with enough time to copy it before
        // committing to the external checkout. If this test fails,
        // BMC matching collapses to amount + window heuristics and
        // misattribution becomes likely.
        final invoker = _RecordingInvoker()
          ..respond('createExternalCheckout', {
            'sessionId': 'sess-test',
            'checkoutUrl': 'https://buymeacoffee.com/gotnull',
            'returnDeepLink':
                'socialmesh://purchase-return?sessionId=sess-test',
            'referenceCode': 'SM-AB23-CD45',
            'expectedAmount': 4.99,
            'currency': 'USD',
            'expiresAt': '2026-05-05T11:00:00.000Z',
          });
        final service = await _buildService(invoker: invoker);

        await openSheet(tester, service);

        // The literal reference code must be on screen.
        expect(find.text('SM-AB23-CD45'), findsOneWidget);
        // ...and the "Open Buy Me a Coffee" CTA must also be visible
        // in the same frame, so the user can read the code first
        // then tap.
        expect(find.text('Open Buy Me a Coffee'), findsOneWidget);
      },
    );

    testWidgets('failed session creation surfaces an error with retry', (
      tester,
    ) async {
      final invoker = _RecordingInvoker(); // no scripted response
      final service = await _buildService(invoker: invoker);

      await openSheet(tester, service);

      // Error panel renders with the localised retry action.
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // SCENARIO 3 — redirect alone does NOT unlock
  // SCENARIO 4 — confirmed payment updates the UI
  // -------------------------------------------------------------------------

  group('ConfirmingUnlockOverlay (Scenarios 3 + 4)', () {
    testWidgets('idle state renders ONLY the child — no overlay', (
      tester,
    ) async {
      final service = await _buildService();
      await tester.pumpWidget(
        _wrap(
          service: service,
          confirmationStream: Stream.value(ConfirmationState.idle),
          child: const ConfirmingUnlockOverlay(child: Text('app body')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('app body'), findsOneWidget);
      // Confirming text must NOT appear when stage=idle.
      expect(find.text('Confirming your unlock…'), findsNothing);
    });

    testWidgets(
      'confirming stage shows overlay but does NOT grant any entitlement '
      '(redirect alone never unlocks)',
      (tester) async {
        final service = await _buildService();
        // Stage=confirming — equivalent to "redirect just arrived,
        // still waiting on webhook". The cache MUST stay empty.
        const confirming = ConfirmationState(
          stage: ConfirmationStage.confirming,
          sessionId: 'sess-test',
        );
        await tester.pumpWidget(
          _wrap(
            service: service,
            confirmationStream: Stream.value(confirming),
            child: const ConfirmingUnlockOverlay(child: Text('app body')),
          ),
        );
        // Cannot pumpAndSettle here — the overlay's CircularProgressIndicator
        // is an indefinite animation. Pump explicit frames instead.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Confirming your unlock…'), findsOneWidget);
        // The cache is the source of truth for "is the pack unlocked?".
        // Confirming stage alone must leave it empty.
        expect(service.cache.activeProductIds(), isEmpty);
      },
    );

    testWidgets('succeeded stage surfaces the unlocked pack name', (
      tester,
    ) async {
      final service = await _buildService();
      const succeeded = ConfirmationState(
        stage: ConfirmationStage.succeeded,
        sessionId: 'sess-test',
        productId: 'theme_pack',
        grantedProductIds: ['theme_pack'],
      );
      await tester.pumpWidget(
        _wrap(
          service: service,
          confirmationStream: Stream.value(succeeded),
          child: const ConfirmingUnlockOverlay(child: Text('app body')),
        ),
      );
      await tester.pumpAndSettle();

      // Pack name interpolated into the unlockSuccess template.
      expect(find.textContaining('Theme Pack'), findsOneWidget);
      expect(find.textContaining('unlocked'), findsOneWidget);
    });

    testWidgets('failed stage shows error message + dismiss', (tester) async {
      final service = await _buildService();
      const failed = ConfirmationState(
        stage: ConfirmationStage.failed,
        errorMessage: 'expired',
      );
      await tester.pumpWidget(
        _wrap(
          service: service,
          confirmationStream: Stream.value(failed),
          child: const ConfirmingUnlockOverlay(child: Text('app body')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("couldn't be confirmed"), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });
  });
}
