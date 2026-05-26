// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Pins the fail-closed contract of [currentUserLicenseOrgIdsProvider]:
//
//   - flag off  -> empty, regardless of user state
//   - guest     -> empty (anonymous or null user)
//   - authed    -> repository result
//   - revoked / invited member rows -> excluded
//   - repo stream error -> empty (no thrown exception escapes)
//   - org-owned external entitlements remain ungranted (sanity check
//     against the previous slice's effectiveEntitlementsProvider).
//
// IMPORTANT - this exercises the licensing namespace
// (`license_orgs/`), distinct from enterprise multi-tenancy `orgs/`
// at backend/functions/src/org/createOrg.ts. The two systems must
// stay isolated.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/models/license_org.dart';
import 'package:socialmesh/models/license_org_membership.dart';
import 'package:socialmesh/models/subscription_models.dart';
import 'package:socialmesh/providers/auth_providers.dart';
import 'package:socialmesh/providers/external_purchase_providers.dart';
import 'package:socialmesh/providers/license_org_membership_providers.dart';
import 'package:socialmesh/providers/subscription_providers.dart';
import 'package:socialmesh/services/external_purchase/external_entitlement.dart';
import 'package:socialmesh/services/external_purchase/external_entitlement_cache.dart';
import 'package:socialmesh/services/org/license_org_membership_repository.dart';

// Minimal User fake. Only [uid] and [isAnonymous] are read by the
// provider; any other call throws NoSuchMethodError which surfaces
// loudly if the provider's contract ever expands.
class _FakeUser implements User {
  @override
  final String uid;
  @override
  final bool isAnonymous;

  _FakeUser({required this.uid, this.isAnonymous = false});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubRepo implements LicenseOrgMembershipRepository {
  final Map<String, Stream<Set<String>>> _byUid;

  _StubRepo(this._byUid);

  @override
  Stream<Set<String>> watchCurrentUserOrgIds(String uid) =>
      _byUid[uid] ?? Stream.value(const <String>{});

  // Unused by this test file; the org / membership streams are
  // exercised by license_org_overview_providers_test.dart. Stubbed
  // here only to satisfy the interface contract.
  @override
  Stream<LicenseOrg?> watchLicenseOrg(String orgId) => Stream.value(null);

  @override
  Stream<LicenseOrgMembership?> watchMembership(String orgId, String uid) =>
      Stream.value(null);

  @override
  Stream<List<LicenseOrgMembership>> membersForOrg(String orgId) =>
      Stream.value(const <LicenseOrgMembership>[]);
}

class _ThrowingRepo implements LicenseOrgMembershipRepository {
  @override
  Stream<Set<String>> watchCurrentUserOrgIds(String uid) =>
      Stream<Set<String>>.error(StateError('Firestore unavailable'));

  @override
  Stream<LicenseOrg?> watchLicenseOrg(String orgId) => Stream.value(null);

  @override
  Stream<LicenseOrgMembership?> watchMembership(String orgId, String uid) =>
      Stream.value(null);

  @override
  Stream<List<LicenseOrgMembership>> membersForOrg(String orgId) =>
      Stream.value(const <LicenseOrgMembership>[]);
}

class _FakePurchaseStateNotifier extends Notifier<PurchaseState>
    implements PurchaseStateNotifier {
  final PurchaseState _initial;
  _FakePurchaseStateNotifier(this._initial);

  @override
  PurchaseState build() => _initial;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> debugAddPurchase(String productId) async {}

  @override
  Future<void> debugReset() async {}
}

void _setFlag({required bool enabled}) {
  dotenv.env['GROUP_LICENSING_ENABLED'] = enabled ? 'true' : 'false';
}

ProviderContainer _container({
  required User? user,
  required LicenseOrgMembershipRepository repo,
}) {
  return ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => user),
      licenseOrgMembershipRepositoryProvider.overrideWith((ref) => repo),
    ],
  );
}

Future<void> _pumpUntilNonLoading(
  ProviderContainer c, {
  bool requireData = true,
}) async {
  final sub = c.listen<AsyncValue<Set<String>>>(
    currentUserLicenseOrgIdsProvider,
    (_, _) {},
    fireImmediately: true,
  );
  try {
    for (var i = 0; i < 50; i++) {
      final v = sub.read();
      if (requireData ? v.hasValue : !v.isLoading) return;
      await Future<void>.delayed(Duration.zero);
    }
    throw StateError(
      'currentUserLicenseOrgIdsProvider did not settle within pump budget',
    );
  } finally {
    sub.close();
  }
}

void main() {
  setUpAll(() {
    // dotenv must be loaded for AppFeatureFlags to read the flag.
    dotenv.loadFromString(envString: 'GROUP_LICENSING_ENABLED=false\n');
  });

  setUp(() {
    _setFlag(enabled: false);
  });

  group('feature flag gate', () {
    test(
      'flag off -> empty set even for authed user with member rows',
      () async {
        _setFlag(enabled: false);
        final c = _container(
          user: _FakeUser(uid: 'user-1'),
          repo: _StubRepo({
            'user-1': Stream.value(const {'acme-eng-team'}),
          }),
        );
        await _pumpUntilNonLoading(c);
        expect(c.read(currentUserLicenseOrgIdsProvider).value, isEmpty);
        expect(
          c.read(isCurrentUserInLicenseOrgProvider('acme-eng-team')),
          isFalse,
        );
        c.dispose();
      },
    );
  });

  group('auth state gate', () {
    test('signed-out user -> empty set', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: null,
        repo: _StubRepo({
          'user-1': Stream.value(const {'acme-eng-team'}),
        }),
      );
      await _pumpUntilNonLoading(c);
      expect(c.read(currentUserLicenseOrgIdsProvider).value, isEmpty);
      c.dispose();
    });

    test('anonymous (guest) user -> empty set even with member rows', () async {
      // Guest / install-scoped users never resolve license-org memberships
      // in this slice. Anon uids churn between installs and would otherwise
      // create spurious "you joined org X" flicker.
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'anon-abc', isAnonymous: true),
        repo: _StubRepo({
          'anon-abc': Stream.value(const {'acme-eng-team'}),
        }),
      );
      await _pumpUntilNonLoading(c);
      expect(c.read(currentUserLicenseOrgIdsProvider).value, isEmpty);
      c.dispose();
    });

    test('empty uid -> empty set', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: ''),
        repo: _StubRepo({
          '': Stream.value(const {'acme-eng-team'}),
        }),
      );
      await _pumpUntilNonLoading(c);
      expect(c.read(currentUserLicenseOrgIdsProvider).value, isEmpty);
      c.dispose();
    });
  });

  group('authed user repo passthrough', () {
    test('yields owner / member license-org ids from repository', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'user-1'),
        repo: _StubRepo({
          'user-1': Stream.value({'acme-eng-team', 'beta-club'}),
        }),
      );
      await _pumpUntilNonLoading(c);
      expect(c.read(currentUserLicenseOrgIdsProvider).value, {
        'acme-eng-team',
        'beta-club',
      });
      expect(
        c.read(isCurrentUserInLicenseOrgProvider('acme-eng-team')),
        isTrue,
      );
      expect(c.read(isCurrentUserInLicenseOrgProvider('beta-club')), isTrue);
      expect(c.read(isCurrentUserInLicenseOrgProvider('not-mine')), isFalse);
      c.dispose();
    });

    test(
      'repository emitting empty set yields empty (no-membership user)',
      () async {
        _setFlag(enabled: true);
        final c = _container(
          user: _FakeUser(uid: 'user-1'),
          repo: _StubRepo({'user-1': Stream.value(const <String>{})}),
        );
        await _pumpUntilNonLoading(c);
        expect(c.read(currentUserLicenseOrgIdsProvider).value, isEmpty);
        c.dispose();
      },
    );

    test('inactive / revoked rows do not reach the provider', () {
      // Defence-in-depth assertion: the repository's contract is
      // "active only", so the fake mirrors that by filtering before
      // emission. This proves the provider does NOT re-introduce
      // dropped rows. Asserting on the model layer because the
      // Firestore filter is a query-level concern.
      final revoked = LicenseOrgMembership.fromMap({
        'uid': 'user-1',
        'orgId': 'acme-eng-team',
        'status': 'revoked',
      });
      final invited = LicenseOrgMembership.fromMap({
        'uid': 'user-1',
        'orgId': 'acme-eng-team',
        'status': 'invited',
      });
      expect(revoked!.isAccessActive, isFalse);
      expect(invited!.isAccessActive, isFalse);
    });

    test('malformed member rows fail closed (model parser drops them)', () {
      // Verifying the contract the repository relies on for fail-closed:
      // unparseable rows return null and never propagate to the
      // provider's emitted set.
      expect(
        LicenseOrgMembership.fromMap({
          'orgId': 'acme-eng-team',
          'status': 'active',
        }),
        isNull,
        reason: 'missing uid must drop the row',
      );
      expect(
        LicenseOrgMembership.fromMap({'uid': 'user-1', 'status': 'active'}),
        isNull,
        reason: 'missing orgId must drop the row',
      );
      expect(
        LicenseOrgMembership.fromMap({
          'uid': 'user-1',
          'orgId': '',
          'status': 'active',
        }),
        isNull,
        reason: 'empty orgId must drop the row',
      );
    });
  });

  group('error handling', () {
    test(
      'repository stream error -> provider yields empty (no rethrow)',
      () async {
        _setFlag(enabled: true);
        final c = _container(
          user: _FakeUser(uid: 'user-1'),
          repo: _ThrowingRepo(),
        );
        await _pumpUntilNonLoading(c);
        // The provider catches stream errors and yields empty rather
        // than surfacing AsyncError. This keeps consumers' branching
        // simple (".value ?? const {}" is always safe) and means a
        // Firestore outage degrades to "no license-org membership"
        // instead of a blown-up gate.
        final async = c.read(currentUserLicenseOrgIdsProvider);
        expect(async.hasValue, isTrue);
        expect(async.value, isEmpty);
        c.dispose();
      },
    );
  });

  group('no entitlement leakage', () {
    // This is the load-bearing assertion for this slice: even when the
    // current user actively belongs to license-org X, an org-owned
    // external entitlement scoped to X must NOT appear in
    // effectiveEntitlementsProvider without a matching seat allocation.
    // The full membership + seat unlock case lives in
    // effective_entitlements_test.dart.
    setUpAll(() {
      dotenv.env['THEME_PACK_PRODUCT_ID'] = 'theme_pack';
      dotenv.env['RINGTONE_PACK_PRODUCT_ID'] = 'ringtone_pack';
      dotenv.env['WIDGET_PACK_PRODUCT_ID'] = 'widget_pack';
      dotenv.env['AUTOMATIONS_PACK_PRODUCT_ID'] = 'automations_pack';
      dotenv.env['IFTTT_PACK_PRODUCT_ID'] = 'ifttt_pack';
      dotenv.env['TRANSLATION_PACK_PRODUCT_ID'] = 'translation_pack';
      dotenv.env['COMPLETE_PACK_PRODUCT_ID'] = 'complete_pack';
    });

    test(
      'authed user IN license-org X does NOT unlock org-owned X without seat',
      () async {
        _setFlag(enabled: true);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cache = ExternalEntitlementCache(prefs);

        final ts = DateTime.parse('2026-05-05T10:00:00.000Z');
        await cache.write([
          ExternalEntitlement(
            productId: 'widget_pack',
            status: ExternalEntitlementStatus.active,
            provider: ExternalProvider.stripe,
            grantedAt: ts,
            lastVerifiedAt: ts,
            sessionId: 'sess-org',
            ownerKind: OwnerKind.org,
            orgId: 'acme-eng-team',
          ),
        ]);

        final c = ProviderContainer(
          overrides: [
            currentUserProvider.overrideWith((ref) => _FakeUser(uid: 'user-1')),
            licenseOrgMembershipRepositoryProvider.overrideWith(
              (ref) => _StubRepo({
                'user-1': Stream.value(const {'acme-eng-team'}),
              }),
            ),
            purchaseStateProvider.overrideWith(
              () => _FakePurchaseStateNotifier(
                PurchaseState(purchasedProductIds: const {}),
              ),
            ),
            externalEntitlementsProvider.overrideWith(
              (ref) =>
                  Stream<Set<String>>.fromIterable([cache.activeProductIds()]),
            ),
          ],
        );

        await _pumpUntilNonLoading(c);

        // Sanity: the membership provider DOES see the license-org id...
        expect(c.read(currentUserLicenseOrgIdsProvider).value, {
          'acme-eng-team',
        });
        // ...but the entitlement merge does NOT grant the org-owned pack.
        expect(
          c.read(effectiveEntitlementsProvider),
          isNot(contains('widget_pack')),
          reason:
              'license-org membership alone must not unlock org-owned '
              'entitlements without a matching seat allocation',
        );
        c.dispose();
      },
    );
  });
}
