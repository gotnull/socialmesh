// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Tests for the ExternalPurchaseService — the Flutter side of the
// external (fallback) purchase pipeline. The Cloud Function shapes
// being mocked here mirror backend/functions/src/external_checkout.ts;
// drift is caught by the round-trip JSON tests in
// external_entitlement_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/external_purchase/external_entitlement.dart';
import 'package:socialmesh/services/external_purchase/external_entitlement_cache.dart';
import 'package:socialmesh/services/external_purchase/external_purchase_service.dart';

class _FakeInvoker implements CallableInvoker {
  final List<_RecordedCall> calls = [];
  final Map<String, List<Map<String, dynamic>>> _scriptedResponses = {};
  Object? _scriptedThrow;

  void scriptResponse(String name, Map<String, dynamic> response) {
    _scriptedResponses.putIfAbsent(name, () => []).add(response);
  }

  void scriptThrow(Object error) {
    _scriptedThrow = error;
  }

  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    calls.add(_RecordedCall(name, Map<String, dynamic>.from(data)));
    if (_scriptedThrow != null) {
      final t = _scriptedThrow!;
      _scriptedThrow = null;
      throw t;
    }
    final queue = _scriptedResponses[name];
    if (queue == null || queue.isEmpty) {
      throw StateError('No scripted response for $name');
    }
    return queue.removeAt(0);
  }
}

class _RecordedCall {
  final String name;
  final Map<String, dynamic> data;
  _RecordedCall(this.name, this.data);
}

void main() {
  late SharedPreferences prefs;
  late ExternalEntitlementCache cache;
  late _FakeInvoker invoker;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cache = ExternalEntitlementCache(prefs);
    invoker = _FakeInvoker();
  });

  ExternalPurchaseService buildService({
    PollingPolicy policy = PollingPolicy.fast,
  }) {
    return ExternalPurchaseService(
      prefs: prefs,
      cache: cache,
      invoker: invoker,
      pollingPolicy: policy,
    );
  }

  // ---------------------------------------------------------------------------
  // createCheckout
  // ---------------------------------------------------------------------------

  group('createCheckout', () {
    test(
      'returns the descriptor and includes deviceInstallId payload',
      () async {
        invoker.scriptResponse('createExternalCheckout', {
          'sessionId': 'sess-1',
          'checkoutUrl': 'https://buymeacoffee.com/gotnull',
          'returnDeepLink': 'socialmesh://purchase-return?sessionId=sess-1',
          'referenceCode': 'SM-AB23-CD45',
          'expectedAmount': 4.99,
          'currency': 'USD',
          'expiresAt': '2026-05-05T11:00:00.000Z',
        });

        final service = buildService();
        final descriptor = await service.createCheckout('theme_pack');

        expect(descriptor.sessionId, 'sess-1');
        expect(descriptor.referenceCode, 'SM-AB23-CD45');
        expect(invoker.calls, hasLength(1));
        expect(invoker.calls.first.name, 'createExternalCheckout');
        expect(invoker.calls.first.data['productId'], 'theme_pack');
        // Anonymous caller — installId must be present so the backend
        // can key entitlements off the device.
        expect(invoker.calls.first.data['deviceInstallId'], isNotNull);
        expect(
          (invoker.calls.first.data['deviceInstallId'] as String).length >= 8,
          isTrue,
        );
      },
    );

    test('reuses the same deviceInstallId across calls', () async {
      // Stable identity is the whole point - a fresh id per call would
      // mean the user's first checkout and second would be split
      // across two anonymous owners on the backend.
      invoker.scriptResponse('createExternalCheckout', _checkoutResponse('a'));
      invoker.scriptResponse('createExternalCheckout', _checkoutResponse('b'));

      final service = buildService();
      await service.createCheckout('theme_pack');
      await service.createCheckout('widget_pack');

      final firstId = invoker.calls[0].data['deviceInstallId'];
      final secondId = invoker.calls[1].data['deviceInstallId'];
      expect(firstId, secondId);
    });

    test('personal checkout payload omits subjectKind + licenseOrgId entirely '
        '(slice 8 wire-compat)', () async {
      // The pre-slice-8 wire never carried these keys. The personal
      // path must keep that shape so backend logs and the
      // existing webhook continue to behave identically.
      invoker.scriptResponse('createExternalCheckout', _checkoutResponse('a'));
      await buildService().createCheckout('theme_pack');
      final data = invoker.calls.first.data;
      expect(data.containsKey('subjectKind'), isFalse);
      expect(data.containsKey('licenseOrgId'), isFalse);
    });

    test('explicit subjectKind="user" also suppresses org keys', () async {
      // The server treats absent subjectKind as 'user', so the
      // client may either omit or send 'user' with the same
      // intent. Slice 8 contract: never send org keys for the
      // user-side path, regardless of whether the caller passed
      // 'user' explicitly or left it null.
      invoker.scriptResponse('createExternalCheckout', _checkoutResponse('a'));
      await buildService().createCheckout('theme_pack', subjectKind: 'user');
      final data = invoker.calls.first.data;
      expect(data.containsKey('subjectKind'), isFalse);
      expect(data.containsKey('licenseOrgId'), isFalse);
    });

    test('org checkout sends subjectKind="org" + licenseOrgId', () async {
      invoker.scriptResponse('createExternalCheckout', _checkoutResponse('a'));
      await buildService().createCheckout(
        'community_pack_20seat',
        subjectKind: 'org',
        licenseOrgId: 'acme-eng-team',
      );
      final data = invoker.calls.first.data;
      expect(data['productId'], 'community_pack_20seat');
      expect(data['subjectKind'], 'org');
      expect(data['licenseOrgId'], 'acme-eng-team');
      // Identity payload still carries deviceInstallId. The backend
      // ignores it when auth.uid is present (slice 7 enforces
      // uid-scoped sessions for org-pack); sending it here is
      // harmless and keeps the personal/org wire shape unified.
      expect(data['deviceInstallId'], isNotNull);
    });

    test('org checkout without licenseOrgId still sends subjectKind '
        '(server validates)', () async {
      // Client does not pre-validate; if the caller passes
      // subjectKind="org" without a licenseOrgId, the request
      // reaches the backend which rejects with invalid-argument
      // (slice 7). This test pins that the client does not
      // silently swallow the org intent.
      invoker.scriptResponse('createExternalCheckout', _checkoutResponse('a'));
      await buildService().createCheckout(
        'community_pack_20seat',
        subjectKind: 'org',
      );
      final data = invoker.calls.first.data;
      expect(data['subjectKind'], 'org');
      expect(data.containsKey('licenseOrgId'), isFalse);
    });

    test(
      'server-side errors bubble unchanged from the org-pack path',
      () async {
        // Existing FunctionsException behaviour: the service does not
        // wrap or transform backend errors. Slice 8 must NOT change
        // that contract for org-pack calls.
        invoker.scriptThrow(StateError('permission-denied'));
        await expectLater(
          buildService().createCheckout(
            'community_pack_20seat',
            subjectKind: 'org',
            licenseOrgId: 'acme-eng-team',
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // refreshEntitlements
  // ---------------------------------------------------------------------------

  group('refreshEntitlements', () {
    test('writes server response into the cache', () async {
      invoker.scriptResponse('getExternalEntitlements', {
        'ownerKind': 'install',
        'entitlements': [
          _entitlementJson('theme_pack'),
          _entitlementJson('widget_pack'),
        ],
      });

      final service = buildService();
      final list = await service.refreshEntitlements();

      expect(list, hasLength(2));
      expect(cache.activeProductIds(), {'theme_pack', 'widget_pack'});
    });

    test(
      'parses entitlements when cloud_functions returns Map<Object?, Object?> '
      '(regression — silent filter dropped all entitlements)',
      () async {
        // The cloud_functions plugin decodes nested JSON objects as
        // `Map<Object?, Object?>`, not `Map<String, dynamic>`. The
        // earlier `whereType<Map<String, dynamic>>()` filter silently
        // dropped every entitlement against this shape — backend
        // returned count=1, client cache wrote 0, UI never updated.
        // This test fixture mimics the real plugin shape so we never
        // regress.
        final pluginShapedEntitlement = <Object?, Object?>{
          'productId': 'ringtone_pack',
          'status': 'active',
          'provider': 'manual',
          'grantedAt': '2026-05-05T02:50:49.408Z',
          'lastVerifiedAt': '2026-05-05T02:50:49.408Z',
          'sessionId': null,
        };
        invoker.scriptResponse('getExternalEntitlements', {
          'ownerKind': 'install',
          'entitlements': [pluginShapedEntitlement],
        });

        final service = buildService();
        final list = await service.refreshEntitlements();

        expect(list, hasLength(1));
        expect(list.first.productId, 'ringtone_pack');
        expect(cache.activeProductIds(), {'ringtone_pack'});
      },
    );

    test('falls back to the cache on error (offline contract)', () async {
      // Pre-populate the cache as if a previous refresh had landed.
      await cache.write([
        ExternalEntitlement(
          productId: 'theme_pack',
          status: ExternalEntitlementStatus.active,
          provider: ExternalProvider.buymeacoffee,
          grantedAt: DateTime.parse('2026-05-05T10:00:00.000Z'),
          lastVerifiedAt: DateTime.parse('2026-05-05T10:00:00.000Z'),
          sessionId: null,
        ),
      ]);

      invoker.scriptThrow(Exception('network down'));

      final service = buildService();
      final list = await service.refreshEntitlements();

      // Returned the cache content rather than throwing.
      expect(list.map((e) => e.productId).toList(), ['theme_pack']);
      expect(cache.activeProductIds(), {'theme_pack'});
    });
  });

  // ---------------------------------------------------------------------------
  // redeemCode
  // ---------------------------------------------------------------------------

  group('redeemCode', () {
    test('returns granted productIds and refreshes entitlements', () async {
      invoker.scriptResponse('redeemUnlockCode', {
        'productIds': ['theme_pack', 'widget_pack'],
      });
      invoker.scriptResponse('getExternalEntitlements', {
        'ownerKind': 'install',
        'entitlements': [
          _entitlementJson('theme_pack'),
          _entitlementJson('widget_pack'),
        ],
      });

      final service = buildService();
      final result = await service.redeemCode('SM-AB23-CD45');

      expect(result, ['theme_pack', 'widget_pack']);
      // Cache must have been populated by the implicit refresh -
      // otherwise the UI would still show "locked" until the next
      // app launch.
      expect(cache.activeProductIds(), {'theme_pack', 'widget_pack'});
      expect(invoker.calls.map((c) => c.name).toList(), [
        'redeemUnlockCode',
        'getExternalEntitlements',
      ]);
    });

    test(
      'non-LSEAT codes route through redeemUnlockCode (existing path unchanged)',
      () async {
        // Defence-in-depth: the slice 4b routing must NOT touch the
        // personal-pack path for codes without the licensing prefix.
        // Pre-existing customers using SM-XXXX-XXXX support codes
        // continue to hit the same Cloud Function with the same
        // identity payload.
        invoker.scriptResponse('redeemUnlockCode', {
          'productIds': ['theme_pack'],
        });
        invoker.scriptResponse('getExternalEntitlements', {
          'ownerKind': 'install',
          'entitlements': [_entitlementJson('theme_pack')],
        });

        final service = buildService();
        await service.redeemCode('SM-AB23-CD45');

        // First call MUST be redeemUnlockCode (not the licensing one).
        expect(invoker.calls.first.name, 'redeemUnlockCode');
        // Identity payload still carries deviceInstallId on this path.
        expect(invoker.calls.first.data.containsKey('deviceInstallId'), isTrue);
        // No licensing call.
        expect(
          invoker.calls.any((c) => c.name == 'redeemLicenseSeatCode'),
          isFalse,
        );
      },
    );

    test(
      'LSEAT- codes route through redeemLicenseSeatCode and refresh cache',
      () async {
        // Slice 4b happy path on the client. The backend returns a
        // single allocation tied to one productId; the client adapts
        // it into the same `List<String>` shape the UI expects from
        // the personal path so call sites don't branch.
        invoker.scriptResponse('redeemLicenseSeatCode', {
          'allocationId': 'acme-eng-team__user-1__widget_pack',
          'licenseOrgId': 'acme-eng-team',
          'productId': 'widget_pack',
          'alreadyAllocated': false,
        });
        invoker.scriptResponse('getExternalEntitlements', {
          'ownerKind': 'install',
          'entitlements': const [],
        });

        final service = buildService();
        final result = await service.redeemCode('LSEAT-ABCD-EFGH');

        expect(result, ['widget_pack']);
        expect(invoker.calls.map((c) => c.name).toList(), [
          'redeemLicenseSeatCode',
          'getExternalEntitlements',
        ]);
        // Licensing path MUST NOT pass deviceInstallId. The Cloud
        // Function rejects anonymous callers and the seat is bound to
        // uid; sending an install id would muddy the audit trail.
        expect(
          invoker.calls.first.data.containsKey('deviceInstallId'),
          isFalse,
          reason: 'license seat redeem must not echo deviceInstallId',
        );
        expect(invoker.calls.first.data['code'], 'LSEAT-ABCD-EFGH');
      },
    );

    test(
      'LSEAT routing is case + whitespace insensitive on the prefix',
      () async {
        invoker.scriptResponse('redeemLicenseSeatCode', {
          'allocationId': 'a__u__p',
          'licenseOrgId': 'a',
          'productId': 'widget_pack',
          'alreadyAllocated': false,
        });
        invoker.scriptResponse('getExternalEntitlements', {
          'ownerKind': 'install',
          'entitlements': const [],
        });

        final service = buildService();
        await service.redeemCode('  lseat-abcd-efgh  ');

        expect(invoker.calls.first.name, 'redeemLicenseSeatCode');
      },
    );

    test(
      'LSEAT replay returns the same productId with alreadyAllocated=true',
      () async {
        invoker.scriptResponse('redeemLicenseSeatCode', {
          'allocationId': 'a__u__p',
          'licenseOrgId': 'a',
          'productId': 'widget_pack',
          'alreadyAllocated': true,
        });
        invoker.scriptResponse('getExternalEntitlements', {
          'ownerKind': 'install',
          'entitlements': const [],
        });

        final service = buildService();
        final result = await service.redeemCode('LSEAT-RPLY-RPLY');

        expect(result, ['widget_pack']);
        // The service does not surface alreadyAllocated to the caller
        // - the user-facing message is the same "you have widget_pack"
        // either way, and the backend already de-duped on its side.
      },
    );

    test(
      'empty code falls through to the personal path (existing behavior)',
      () async {
        // An empty string is not a license seat code; the personal Cloud
        // Function already rejects empty strings, so falling through
        // preserves the existing error semantics. The slice 4b routing
        // must NOT swallow this.
        invoker.scriptThrow(StateError('empty code rejected by backend'));

        final service = buildService();
        await expectLater(service.redeemCode(''), throwsA(isA<StateError>()));
        expect(invoker.calls.first.name, 'redeemUnlockCode');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // handleDeepLink → polling
  // ---------------------------------------------------------------------------

  group('handleDeepLink', () {
    test('redirect alone does NOT unlock — only webhook does', () async {
      // Backend says still pending. Cache must stay empty even though
      // we received the redirect. This is the spec's hard rule.
      invoker.scriptResponse('getCheckoutStatus', {
        'sessionId': 'sess-1',
        'status': 'pending',
        'productId': 'theme_pack',
        'grantedProductIds': ['theme_pack'],
        'lastUpdatedAt': '2026-05-05T10:00:00.000Z',
      });

      final service = buildService();
      service.handleDeepLink('sess-1');

      // Pump until either polling lands a terminal state or times out.
      await _waitForStage(service, ConfirmationStage.failed, maxIterations: 20);

      expect(cache.activeProductIds(), isEmpty);
      // Confirmation should have transitioned to failed (deadline)
      // because the response stayed `pending` for the fast policy's
      // entire window. The cache being empty proves no unlock leaked.
    });

    test('polling unlocks once backend reports paid', () async {
      // First poll: still pending. Second poll: paid. Then the
      // entitlement refresh that lands after success.
      invoker.scriptResponse('getCheckoutStatus', {
        'sessionId': 'sess-1',
        'status': 'pending',
        'productId': 'theme_pack',
        'grantedProductIds': ['theme_pack'],
        'lastUpdatedAt': '2026-05-05T10:00:00.000Z',
      });
      invoker.scriptResponse('getCheckoutStatus', {
        'sessionId': 'sess-1',
        'status': 'paid',
        'productId': 'theme_pack',
        'grantedProductIds': ['theme_pack'],
        'lastUpdatedAt': '2026-05-05T10:00:01.000Z',
      });
      invoker.scriptResponse('getExternalEntitlements', {
        'ownerKind': 'install',
        'entitlements': [_entitlementJson('theme_pack')],
      });

      final service = buildService();
      final states = <ConfirmationState>[];
      final sub = service.confirmationStream.listen(states.add);

      service.handleDeepLink('sess-1');

      await _waitForStage(service, ConfirmationStage.succeeded);

      // Cache flipped to unlocked.
      expect(cache.activeProductIds(), {'theme_pack'});
      // Stream observed the lifecycle: confirming → succeeded.
      expect(
        states.map((s) => s.stage).toList(),
        contains(ConfirmationStage.confirming),
      );
      expect(states.last.stage, ConfirmationStage.succeeded);
      expect(states.last.productId, 'theme_pack');

      await sub.cancel();
      await service.dispose();
    });

    test(
      'failed status flips confirmation to failed without unlocking',
      () async {
        invoker.scriptResponse('getCheckoutStatus', {
          'sessionId': 'sess-1',
          'status': 'failed',
          'productId': 'theme_pack',
          'grantedProductIds': ['theme_pack'],
          'lastUpdatedAt': '2026-05-05T10:00:00.000Z',
        });

        final service = buildService();
        service.handleDeepLink('sess-1');

        await _waitForStage(service, ConfirmationStage.failed);

        expect(cache.activeProductIds(), isEmpty);
        expect(service.currentConfirmation.stage, ConfirmationStage.failed);

        await service.dispose();
      },
    );

    test('empty sessionId is ignored', () async {
      final service = buildService();
      service.handleDeepLink('');
      // No call should have been made — guard short-circuits.
      expect(invoker.calls, isEmpty);
      expect(service.currentConfirmation.stage, ConfirmationStage.idle);
    });

    test('acknowledgeConfirmation returns to idle', () async {
      invoker.scriptResponse('getCheckoutStatus', {
        'sessionId': 'sess-1',
        'status': 'paid',
        'productId': 'theme_pack',
        'grantedProductIds': ['theme_pack'],
        'lastUpdatedAt': '2026-05-05T10:00:00.000Z',
      });
      invoker.scriptResponse('getExternalEntitlements', {
        'ownerKind': 'install',
        'entitlements': [_entitlementJson('theme_pack')],
      });

      final service = buildService();
      service.handleDeepLink('sess-1');
      await _waitForStage(service, ConfirmationStage.succeeded);

      service.acknowledgeConfirmation();
      expect(service.currentConfirmation.stage, ConfirmationStage.idle);

      await service.dispose();
    });
  });
}

Map<String, dynamic> _checkoutResponse(String sessionId) => {
  'sessionId': sessionId,
  'checkoutUrl': 'https://buymeacoffee.com/gotnull',
  'returnDeepLink': 'socialmesh://purchase-return?sessionId=$sessionId',
  'referenceCode': 'SM-AB23-CD45',
  'expectedAmount': 4.99,
  'currency': 'USD',
  'expiresAt': '2026-05-05T11:00:00.000Z',
};

Map<String, dynamic> _entitlementJson(String productId) => {
  'productId': productId,
  'status': 'active',
  'provider': 'buymeacoffee',
  'grantedAt': '2026-05-05T10:00:00.000Z',
  'lastVerifiedAt': '2026-05-05T10:00:00.000Z',
  'sessionId': 'sess-1',
};

/// Helper: wait until the service reaches [stage] or until
/// [maxIterations] microtask pumps have elapsed without a transition.
Future<void> _waitForStage(
  ExternalPurchaseService service,
  ConfirmationStage stage, {
  int maxIterations = 30,
}) async {
  for (var i = 0; i < maxIterations; i++) {
    if (service.currentConfirmation.stage == stage) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}
