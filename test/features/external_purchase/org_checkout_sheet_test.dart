// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Widget tests for the slice-9 org checkout sheet.
//
// Coverage (slice 9 spec):
//   - feature-flag gate suppresses the sheet when GROUP_LICENSING_ENABLED
//     is off
//   - validation rejects empty / malformed / reserved-ish input before
//     calling the backend
//   - valid submit calls createCheckout with subjectKind='org' +
//     slugified licenseOrgId
//   - personal-pack callers are unaffected (NO subjectKind / licenseOrgId
//     keys on the createCheckout payload when invoking the existing
//     personal flow)
//   - launcher hand-off receives the descriptor
//   - error state shown on backend rejection
//   - success closes the sheet with OrgCheckoutOutcome.success

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/external_purchase/org_checkout_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/external_purchase_providers.dart';
import 'package:socialmesh/services/external_purchase/external_entitlement.dart';
import 'package:socialmesh/services/external_purchase/external_entitlement_cache.dart';
import 'package:socialmesh/services/external_purchase/external_purchase_service.dart';

// ----------------------------------------------------------------------------
// Test infrastructure
// ----------------------------------------------------------------------------

class _RecordingInvoker implements CallableInvoker {
  final List<({String name, Map<String, dynamic> data})> calls = [];
  final Map<String, Map<String, dynamic>> _responses = {};
  Object? _throwOnce;

  void respond(String name, Map<String, dynamic> data) {
    _responses[name] = data;
  }

  void throwOnce(Object error) {
    _throwOnce = error;
  }

  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    calls.add((name: name, data: Map<String, dynamic>.from(data)));
    if (_throwOnce != null) {
      final err = _throwOnce!;
      _throwOnce = null;
      throw err;
    }
    final r = _responses[name];
    if (r == null) throw StateError('No scripted response for $name');
    return r;
  }
}

Map<String, dynamic> _checkoutResponse(String sessionId) => {
  'sessionId': sessionId,
  'checkoutUrl': '',
  'clientSecret': 'pi_TEST_secret',
  'paymentIntentId': 'pi_TEST',
  'publishableKey': 'pk_test_dummy',
  'returnDeepLink': 'socialmesh://stripe-redirect',
  'referenceCode': 'SM-AAAA-BBBB',
  'expectedAmount': 49.99,
  'currency': 'AUD',
  'expiresAt': '2027-01-01T00:00:00.000Z',
  'provider': 'stripe',
};

Future<ExternalPurchaseService> _buildService(_RecordingInvoker invoker) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final cache = ExternalEntitlementCache(prefs);
  return ExternalPurchaseService(
    prefs: prefs,
    cache: cache,
    invoker: invoker,
    pollingPolicy: PollingPolicy.fast,
  );
}

Widget _hostApp({
  required ExternalPurchaseService service,
  required void Function(BuildContext) onReady,
}) {
  return ProviderScope(
    overrides: [
      externalPurchaseServiceProvider.overrideWith((ref) async => service),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => onReady(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void _setFlag({required bool enabled}) {
  dotenv.env['GROUP_LICENSING_ENABLED'] = enabled ? 'true' : 'false';
}

// ----------------------------------------------------------------------------
// Tests
// ----------------------------------------------------------------------------

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'GROUP_LICENSING_ENABLED=false\n');
  });

  setUp(() => _setFlag(enabled: true));

  testWidgets(
    'feature flag off: showOrgCheckoutSheet returns canceled and does NOT '
    'open the sheet',
    (tester) async {
      _setFlag(enabled: false);
      final invoker = _RecordingInvoker();
      final service = await _buildService(invoker);

      OrgCheckoutOutcome? outcome;
      await tester.pumpWidget(
        _hostApp(
          service: service,
          onReady: (ctx) async {
            outcome = await showOrgCheckoutSheet(
              ctx,
              productId: 'community_pack_20seat',
            );
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(outcome, OrgCheckoutOutcome.canceled);
      // Sheet body never rendered.
      expect(find.text('Buy a group license'), findsNothing);
      // No backend call.
      expect(invoker.calls, isEmpty);
    },
  );

  testWidgets('renders title, body, field, submit when flag is on', (
    tester,
  ) async {
    final invoker = _RecordingInvoker();
    final service = await _buildService(invoker);

    await tester.pumpWidget(
      _hostApp(
        service: service,
        onReady: (ctx) {
          showOrgCheckoutSheet(ctx, productId: 'community_pack_20seat');
        },
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Title + body copy present.
    expect(find.text('Buy a group license'), findsOneWidget);
    expect(
      find.textContaining('Seats are NOT assigned automatically'),
      findsOneWidget,
    );
    // Field + submit button present.
    expect(find.text('License org id'), findsOneWidget);
    expect(find.text('Continue to payment'), findsOneWidget);
  });

  testWidgets(
    'submit button is disabled when input is empty (no backend call)',
    (tester) async {
      final invoker = _RecordingInvoker();
      final service = await _buildService(invoker);

      await tester.pumpWidget(
        _hostApp(
          service: service,
          onReady: (ctx) {
            showOrgCheckoutSheet(ctx, productId: 'community_pack_20seat');
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tap the disabled button - Flutter tester fires the hit but
      // the onPressed callback is null, so no work happens.
      await tester.tap(find.text('Continue to payment'));
      await tester.pumpAndSettle();

      // The FilledButton's onPressed must be null when input is empty.
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNull);
      expect(invoker.calls, isEmpty);
    },
  );

  testWidgets(
    'submit button stays disabled when input is malformed (underscores) '
    'and shows inline error',
    (tester) async {
      final invoker = _RecordingInvoker();
      final service = await _buildService(invoker);

      await tester.pumpWidget(
        _hostApp(
          service: service,
          onReady: (ctx) {
            showOrgCheckoutSheet(ctx, productId: 'community_pack_20seat');
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Underscores aren't in the slug alphabet.
      await tester.enterText(find.byType(TextField), 'acme_eng_team');
      await tester.pumpAndSettle();

      // Inline error message appears (errorText shown under the field).
      expect(
        find.textContaining('lowercase letters, digits, and hyphens'),
        findsWidgets,
      );
      // Button is disabled.
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNull);
      expect(invoker.calls, isEmpty);
    },
  );

  testWidgets(
    'reserved namespace (socialmesh) shows specific error inline + button '
    'stays disabled',
    (tester) async {
      // Slice 10a: client-side mirror of slice-7 backend reserved set.
      // 'socialmesh' is the canonical example - was the original bug
      // report on the org-checkout sheet that prompted this fix.
      final invoker = _RecordingInvoker();
      final service = await _buildService(invoker);

      await tester.pumpWidget(
        _hostApp(
          service: service,
          onReady: (ctx) {
            showOrgCheckoutSheet(ctx, productId: 'community_pack_20seat');
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'socialmesh');
      await tester.pumpAndSettle();

      expect(find.textContaining('reserved'), findsWidgets);
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNull);
      expect(invoker.calls, isEmpty);
    },
  );

  testWidgets(
    'reserved prefix (enterprise-pilot) shows specific error inline',
    (tester) async {
      final invoker = _RecordingInvoker();
      final service = await _buildService(invoker);

      await tester.pumpWidget(
        _hostApp(
          service: service,
          onReady: (ctx) {
            showOrgCheckoutSheet(ctx, productId: 'community_pack_20seat');
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'enterprise-pilot');
      await tester.pumpAndSettle();

      expect(find.textContaining('reserved'), findsWidgets);
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNull);
      expect(invoker.calls, isEmpty);
    },
  );

  testWidgets(
    'lowercase formatter normalizes uppercase input as the user types',
    (tester) async {
      // Slice 10a: TextInputFormatter lowercases every keystroke so
      // the visible field state always matches what gets sent to the
      // backend. Previous behavior was lowercasing only at submit -
      // confused users typing uppercase letters that appeared in the
      // field unchanged.
      final invoker = _RecordingInvoker();
      final service = await _buildService(invoker);

      await tester.pumpWidget(
        _hostApp(
          service: service,
          onReady: (ctx) {
            showOrgCheckoutSheet(ctx, productId: 'community_pack_20seat');
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tap-enter uppercase; formatter should immediately lowercase.
      await tester.enterText(find.byType(TextField), 'ACME-Eng-Team');
      await tester.pumpAndSettle();

      // The field's controller text should be lowercase.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'acme-eng-team');
    },
  );

  testWidgets(
    'submit button is enabled when input is a valid non-reserved slug',
    (tester) async {
      final invoker = _RecordingInvoker();
      final service = await _buildService(invoker);

      await tester.pumpWidget(
        _hostApp(
          service: service,
          onReady: (ctx) {
            showOrgCheckoutSheet(ctx, productId: 'community_pack_20seat');
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'acme-eng-team');
      await tester.pumpAndSettle();

      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNotNull);
    },
  );

  testWidgets(
    'valid submit calls createCheckout with subjectKind=org + slugified '
    'licenseOrgId',
    (tester) async {
      final invoker = _RecordingInvoker();
      invoker.respond('createExternalCheckout', _checkoutResponse('sess-1'));
      final service = await _buildService(invoker);

      // Capture the descriptor handed to the launcher.
      CheckoutSessionDescriptor? captured;
      Future<void> launcher(
        WidgetRef _,
        ExternalPurchaseService _,
        CheckoutSessionDescriptor d,
      ) async {
        captured = d;
      }

      await tester.pumpWidget(
        _hostApp(
          service: service,
          onReady: (ctx) {
            showOrgCheckoutSheet(
              ctx,
              productId: 'community_pack_20seat',
              launcher: launcher,
            );
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'acme-eng-team');
      // Pump for the controller listener + setState so the FilledButton
      // re-enables (slice 10a: button is disabled until input passes
      // client-side validation).
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to payment'));
      await tester.pumpAndSettle();

      expect(invoker.calls, hasLength(1));
      final call = invoker.calls.single;
      expect(call.name, 'createExternalCheckout');
      expect(call.data['productId'], 'community_pack_20seat');
      expect(call.data['provider'], 'stripe');
      expect(call.data['subjectKind'], 'org');
      expect(call.data['licenseOrgId'], 'acme-eng-team');

      expect(captured, isNotNull);
      expect(captured!.sessionId, 'sess-1');
    },
  );

  testWidgets(
    'input is trimmed + lowercased before being sent to the backend',
    (tester) async {
      final invoker = _RecordingInvoker();
      invoker.respond('createExternalCheckout', _checkoutResponse('sess-1'));
      final service = await _buildService(invoker);

      await tester.pumpWidget(
        _hostApp(
          service: service,
          onReady: (ctx) {
            showOrgCheckoutSheet(
              ctx,
              productId: 'community_pack_20seat',
              launcher: (_, _, _) async {},
            );
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  ACME-Eng-Team  ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to payment'));
      await tester.pumpAndSettle();

      expect(invoker.calls.single.data['licenseOrgId'], 'acme-eng-team');
    },
  );

  testWidgets(
    'backend rejection surfaces an error message and leaves the sheet open',
    (tester) async {
      final invoker = _RecordingInvoker();
      invoker.throwOnce(StateError('permission-denied'));
      final service = await _buildService(invoker);

      await tester.pumpWidget(
        _hostApp(
          service: service,
          onReady: (ctx) {
            showOrgCheckoutSheet(
              ctx,
              productId: 'community_pack_20seat',
              launcher: (_, _, _) async {},
            );
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'acme-eng-team');
      // Pump for the controller listener + setState so the FilledButton
      // re-enables (slice 10a: button is disabled until input passes
      // client-side validation).
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to payment'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not start the group license checkout'),
        findsWidgets,
      );
      // Sheet still on screen (title still visible).
      expect(find.text('Buy a group license'), findsOneWidget);
    },
  );

  testWidgets('successful checkout returns OrgCheckoutOutcome.success', (
    tester,
  ) async {
    final invoker = _RecordingInvoker();
    invoker.respond('createExternalCheckout', _checkoutResponse('sess-1'));
    final service = await _buildService(invoker);

    OrgCheckoutOutcome? outcome;
    await tester.pumpWidget(
      _hostApp(
        service: service,
        onReady: (ctx) async {
          outcome = await showOrgCheckoutSheet(
            ctx,
            productId: 'community_pack_20seat',
            launcher: (_, _, _) async {},
          );
        },
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'acme-eng-team');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to payment'));
    await tester.pumpAndSettle();

    expect(outcome, OrgCheckoutOutcome.success);
  });

  testWidgets(
    'personal-pack invocations (no org args) still produce clean payloads '
    '- this is a SHEET test that verifies the personal call shape is '
    'unchanged when invoked directly against the service',
    (tester) async {
      // Slice 9 must not regress the personal-pack wire shape. The
      // OrgCheckoutSheet itself only emits org-pack requests, so we
      // exercise the service's createCheckout directly to pin that
      // null subjectKind keeps the payload clean. This complements
      // the wire-compat tests in external_purchase_service_test.dart.
      final invoker = _RecordingInvoker();
      invoker.respond(
        'createExternalCheckout',
        _checkoutResponse('sess-personal'),
      );
      final service = await _buildService(invoker);

      await service.createCheckout('theme_pack', provider: 'stripe');

      expect(invoker.calls, hasLength(1));
      final data = invoker.calls.single.data;
      expect(data.containsKey('subjectKind'), isFalse);
      expect(data.containsKey('licenseOrgId'), isFalse);
    },
  );
}
