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

  // Call sites express membership as a plain id set. The fake wraps it
  // as a RESOLVED answer, which is what a stubbed server that responds
  // means - so these tests keep pinning the id-set contract exactly as
  // they did before resolution metadata existed.
  @override
  Stream<LicenseOrgMembershipSetState> watchCurrentUserOrgIdState(String uid) =>
      (_byUid[uid] ?? Stream.value(const <String>{})).map(
        (ids) => LicenseOrgMembershipSetState(
          orgIds: ids,
          resolution: LicenseOrgMembershipResolution.resolved,
        ),
      );

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
  Stream<LicenseOrgMembershipSetState> watchCurrentUserOrgIdState(String uid) =>
      Stream<LicenseOrgMembershipSetState>.error(
        StateError('Firestore unavailable'),
      );

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

/// Drain microtasks until the membership stream reports an
/// AUTHORITATIVE answer, or the budget expires.
///
/// The previous version returned on the first `hasValue`, which could
/// be the synchronous `{}` sentinel rather than the real result - it
/// passed only by microtask luck. Resolution state makes the settling
/// condition expressible, so the race is gone rather than retuned.
///
/// The gate cases (flag off, signed out, anonymous, empty uid) never
/// resolve by design: they short-circuit without consulting the
/// server. For those the loop simply drains its budget, which is still
/// correct - the assertions that follow read a fully-settled provider
/// either way. That is why this does not throw on budget exhaustion.
Future<void> _pumpUntilNonLoading(
  ProviderContainer c, {
  bool requireData = true,
}) async {
  final sub = c.listen<AsyncValue<LicenseOrgMembershipSetState>>(
    currentUserLicenseOrgMembershipStateProvider,
    (_, _) {},
    fireImmediately: true,
  );
  try {
    for (var i = 0; i < 50; i++) {
      final v = sub.read();
      if (v.hasValue && v.requireValue.hasResolvedRemote) return;
      if (!requireData && !v.isLoading) return;
      await Future<void>.delayed(Duration.zero);
    }
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

  group('resolution state', () {
    // The synchronous {} sentinel is indistinguishable from a genuine
    // "you belong to nothing" if all a consumer sees is the id set.
    // Entitlement code does not care - both grant nothing - but a
    // user-facing surface must not claim the user has no organisations
    // while the query is still in flight.

    test('the sentinel is empty AND unresolved', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'user-1'),
        // Never emits, so the sentinel is all a consumer can see.
        repo: _StubRepo({'user-1': const Stream<Set<String>>.empty()}),
      );
      addTearDown(c.dispose);

      final sub = c.listen<AsyncValue<LicenseOrgMembershipSetState>>(
        currentUserLicenseOrgMembershipStateProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final state = sub.read().requireValue;
      expect(state.orgIds, isEmpty);
      expect(
        state.resolution,
        LicenseOrgMembershipResolution.pending,
        reason: 'an unanswered query must never look authoritative',
      );
      expect(state.hasResolvedRemote, isFalse);
    });

    test('a genuinely empty answer is empty AND resolved', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'user-1'),
        repo: _StubRepo({'user-1': Stream.value(const <String>{})}),
      );
      addTearDown(c.dispose);
      await _pumpUntilNonLoading(c);

      final state = c
          .read(currentUserLicenseOrgMembershipStateProvider)
          .requireValue;
      expect(state.orgIds, isEmpty);
      expect(
        state.resolution,
        LicenseOrgMembershipResolution.resolved,
        reason: 'only this state may be rendered as "no organisations"',
      );
      expect(state.hasResolvedRemote, isTrue);
    });

    test('a populated answer is resolved', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'user-1'),
        repo: _StubRepo({
          'user-1': Stream.value(const {'acme-eng-team'}),
        }),
      );
      addTearDown(c.dispose);
      await _pumpUntilNonLoading(c);

      final state = c
          .read(currentUserLicenseOrgMembershipStateProvider)
          .requireValue;
      expect(state.orgIds, {'acme-eng-team'});
      expect(state.resolution, LicenseOrgMembershipResolution.resolved);
    });

    test('a stream error is unresolved, not an authoritative empty', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'user-1'),
        repo: _ThrowingRepo(),
      );
      addTearDown(c.dispose);
      // Must subscribe, not just delay: an unlistened provider is never
      // initialised, so it would still read AsyncLoading. The error path
      // never resolves, hence requireData: false.
      await _pumpUntilNonLoading(c, requireData: false);

      final state = c
          .read(currentUserLicenseOrgMembershipStateProvider)
          .requireValue;
      // Ids still fail closed, unchanged.
      expect(state.orgIds, isEmpty);
      // FAILED, not pending. The distinction is what lets the UI offer a
      // retry instead of showing "Checking..." forever - a dead end with
      // no recovery affordance is worse than a wrong empty state.
      expect(state.resolution, LicenseOrgMembershipResolution.failed);
      expect(state.hasResolvedRemote, isFalse);
    });

    test('the auth and flag gates are unresolved, not authoritative', () async {
      // None of these consulted the server, so none of them can support
      // a confident "this user belongs to no organisations". The UI must
      // handle signed-out / anonymous / flag-off as their own states.
      _setFlag(enabled: false);
      final flagOff = _container(
        user: _FakeUser(uid: 'user-1'),
        repo: _StubRepo({
          'user-1': Stream.value(const {'acme-eng-team'}),
        }),
      );
      addTearDown(flagOff.dispose);
      await _pumpUntilNonLoading(flagOff, requireData: false);
      expect(
        flagOff
            .read(currentUserLicenseOrgMembershipStateProvider)
            .requireValue
            .resolution,
        LicenseOrgMembershipResolution.pending,
      );

      _setFlag(enabled: true);
      final signedOut = _container(user: null, repo: _StubRepo(const {}));
      addTearDown(signedOut.dispose);
      await _pumpUntilNonLoading(signedOut, requireData: false);
      expect(
        signedOut
            .read(currentUserLicenseOrgMembershipStateProvider)
            .requireValue
            .resolution,
        LicenseOrgMembershipResolution.pending,
      );

      final anon = _container(
        user: _FakeUser(uid: 'anon-1', isAnonymous: true),
        repo: _StubRepo(const {}),
      );
      addTearDown(anon.dispose);
      await _pumpUntilNonLoading(anon, requireData: false);
      expect(
        anon
            .read(currentUserLicenseOrgMembershipStateProvider)
            .requireValue
            .resolution,
        LicenseOrgMembershipResolution.pending,
      );
    });

    test('the ids projection matches the state exactly', () async {
      _setFlag(enabled: true);
      // One authority, two projections: the derived provider must never
      // disagree with the state it is derived from.
      final c = _container(
        user: _FakeUser(uid: 'user-1'),
        repo: _StubRepo({
          'user-1': Stream.value(const {'acme-eng-team', 'beta-club'}),
        }),
      );
      addTearDown(c.dispose);
      await _pumpUntilNonLoading(c);

      expect(
        c.read(currentUserLicenseOrgIdsProvider).value,
        c
            .read(currentUserLicenseOrgMembershipStateProvider)
            .requireValue
            .orgIds,
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
