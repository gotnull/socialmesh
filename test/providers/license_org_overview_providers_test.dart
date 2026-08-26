// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Pins the fail-closed contract of the License Org Overview providers
// at lib/providers/license_org_overview_providers.dart.
//
// Coverage:
//   - flag off  -> licenseOrgProvider / membership provider yield null
//                  regardless of repo state
//   - signed-out / anonymous / empty-uid -> membership provider yields
//                  null
//   - flag on + authed -> repo passthrough
//   - licenseOrgRoleProvider mirrors the membership doc's role and
//     falls back to unknown on null / loading / error
//   - licenseOrgRedeemedSeatCountProvider counts only matching orgId
//     seats and returns 0 on loading / error
//
// IMPORTANT - exercises the licensing namespace (`license_orgs/`),
// distinct from enterprise multi-tenancy.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/license_org.dart';
import 'package:socialmesh/models/license_org_membership.dart';
import 'package:socialmesh/models/seat_allocation.dart';
import 'package:socialmesh/providers/auth_providers.dart';
import 'package:socialmesh/providers/license_org_membership_providers.dart';
import 'package:socialmesh/providers/license_org_overview_providers.dart';
import 'package:socialmesh/providers/seat_allocation_providers.dart';
import 'package:socialmesh/services/org/license_org_membership_repository.dart';
import 'package:socialmesh/services/org/seat_allocation_repository.dart';

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
  final Map<String, LicenseOrg?> _orgs;
  final Map<String, LicenseOrgMembership?> _memberships;

  _StubRepo({
    Map<String, LicenseOrg?>? orgs,
    Map<String, LicenseOrgMembership?>? memberships,
  }) : _orgs = orgs ?? const {},
       _memberships = memberships ?? const {};

  @override
  Stream<LicenseOrgMembershipSetState> watchCurrentUserOrgIdState(String uid) =>
      Stream.value(LicenseOrgMembershipSetState.unresolved);

  @override
  Stream<LicenseOrg?> watchLicenseOrg(String orgId) =>
      Stream.value(_orgs[orgId]);

  @override
  Stream<LicenseOrgMembership?> watchMembership(String orgId, String uid) =>
      Stream.value(_memberships['$orgId/$uid']);

  @override
  Stream<List<LicenseOrgMembership>> membersForOrg(String orgId) =>
      Stream.value(const <LicenseOrgMembership>[]);
}

class _StubSeatRepo implements SeatAllocationRepository {
  final Set<SeatAllocationRef> _seats;

  _StubSeatRepo(this._seats);

  @override
  Stream<Set<SeatAllocationRef>> watchCurrentUserSeats(String uid) =>
      Stream.value(_seats);

  @override
  Stream<int> watchOrgActiveSeatCount(String orgId) => Stream.value(0);

  @override
  Stream<Set<String>> watchOrgActiveSeatHolderUids(String orgId) =>
      Stream.value(const <String>{});
}

void _setFlag({required bool enabled}) {
  dotenv.env['GROUP_LICENSING_ENABLED'] = enabled ? 'true' : 'false';
}

ProviderContainer _container({
  required User? user,
  required LicenseOrgMembershipRepository repo,
  SeatAllocationRepository? seatRepo,
}) {
  return ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => user),
      licenseOrgMembershipRepositoryProvider.overrideWith((ref) => repo),
      if (seatRepo != null)
        seatAllocationRepositoryProvider.overrideWith((ref) => seatRepo),
    ],
  );
}

// Pump the event loop until [p] yields data or the budget runs out.
// Uses dynamic typing because flutter_riverpod 3.x does not re-export
// the [ProviderListenable] interface, and the family providers under
// test return concrete types (StreamProvider.family + Provider.family)
// that all satisfy the listen<AsyncValue<dynamic>> contract at the
// call site.
Future<T> _settle<T>(ProviderContainer c, dynamic p) async {
  final sub = c.listen<AsyncValue<T>>(
    p as dynamic,
    (_, _) {},
    fireImmediately: true,
  );
  try {
    for (var i = 0; i < 50; i++) {
      final v = sub.read();
      if (v.hasValue) return v.requireValue;
      await Future<void>.delayed(Duration.zero);
    }
    throw StateError('Provider did not settle within pump budget');
  } finally {
    sub.close();
  }
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'GROUP_LICENSING_ENABLED=false\n');
  });

  group('licenseOrgProvider', () {
    test('yields null when flag is off', () async {
      _setFlag(enabled: false);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(
          orgs: {
            'acme': LicenseOrg(
              id: 'acme',
              name: 'Acme',
              ownerUid: 'u1',
              createdAt: null,
              status: LicenseOrgStatus.active,
            ),
          },
        ),
      );
      addTearDown(c.dispose);

      final result = await _settle(c, licenseOrgProvider('acme'));
      expect(result, isNull);
    });

    test('yields null when orgId is empty', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(),
      );
      addTearDown(c.dispose);

      final result = await _settle(c, licenseOrgProvider(''));
      expect(result, isNull);
    });

    test('yields the repo value when flag is on', () async {
      _setFlag(enabled: true);
      final org = LicenseOrg(
        id: 'acme',
        name: 'Acme',
        ownerUid: 'u1',
        createdAt: DateTime.utc(2026, 1, 15),
        status: LicenseOrgStatus.active,
      );
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(orgs: {'acme': org}),
      );
      addTearDown(c.dispose);

      final result = await _settle(c, licenseOrgProvider('acme'));
      expect(result, org);
    });

    test('yields suspended org (UI decides how to render)', () async {
      _setFlag(enabled: true);
      final org = LicenseOrg(
        id: 'acme',
        name: 'Acme',
        ownerUid: 'u1',
        createdAt: null,
        status: LicenseOrgStatus.suspended,
      );
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(orgs: {'acme': org}),
      );
      addTearDown(c.dispose);

      final result = await _settle(c, licenseOrgProvider('acme'));
      expect(result?.status, LicenseOrgStatus.suspended);
    });
  });

  group('currentUserLicenseOrgMembershipProvider', () {
    test('yields null when flag is off', () async {
      _setFlag(enabled: false);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(
          memberships: {
            'acme/u1': const LicenseOrgMembership(
              uid: 'u1',
              orgId: 'acme',
              role: LicenseOrgMemberRole.admin,
              joinedAt: null,
              invitedBy: null,
              status: LicenseOrgMemberStatus.active,
            ),
          },
        ),
      );
      addTearDown(c.dispose);

      final result = await _settle(
        c,
        currentUserLicenseOrgMembershipProvider('acme'),
      );
      expect(result, isNull);
    });

    test('yields null when user is signed out', () async {
      _setFlag(enabled: true);
      final c = _container(user: null, repo: _StubRepo());
      addTearDown(c.dispose);

      final result = await _settle(
        c,
        currentUserLicenseOrgMembershipProvider('acme'),
      );
      expect(result, isNull);
    });

    test('yields null when user is anonymous', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1', isAnonymous: true),
        repo: _StubRepo(),
      );
      addTearDown(c.dispose);

      final result = await _settle(
        c,
        currentUserLicenseOrgMembershipProvider('acme'),
      );
      expect(result, isNull);
    });

    test('yields the repo membership when flag is on + signed in', () async {
      _setFlag(enabled: true);
      const membership = LicenseOrgMembership(
        uid: 'u1',
        orgId: 'acme',
        role: LicenseOrgMemberRole.admin,
        joinedAt: null,
        invitedBy: null,
        status: LicenseOrgMemberStatus.active,
      );
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(memberships: {'acme/u1': membership}),
      );
      addTearDown(c.dispose);

      final result = await _settle(
        c,
        currentUserLicenseOrgMembershipProvider('acme'),
      );
      expect(result, membership);
    });
  });

  group('licenseOrgRoleProvider', () {
    test('returns the membership role on data', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(
          memberships: {
            'acme/u1': const LicenseOrgMembership(
              uid: 'u1',
              orgId: 'acme',
              role: LicenseOrgMemberRole.owner,
              joinedAt: null,
              invitedBy: null,
              status: LicenseOrgMemberStatus.active,
            ),
          },
        ),
      );
      addTearDown(c.dispose);

      // Ensure the membership stream has settled before reading the
      // pure-derived provider.
      await _settle(c, currentUserLicenseOrgMembershipProvider('acme'));
      expect(
        c.read(licenseOrgRoleProvider('acme')),
        LicenseOrgMemberRole.owner,
      );
    });

    test('returns unknown when membership is null', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(),
      );
      addTearDown(c.dispose);

      await _settle(c, currentUserLicenseOrgMembershipProvider('acme'));
      expect(
        c.read(licenseOrgRoleProvider('acme')),
        LicenseOrgMemberRole.unknown,
      );
    });

    test('returns unknown when flag is off', () async {
      _setFlag(enabled: false);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(
          memberships: {
            'acme/u1': const LicenseOrgMembership(
              uid: 'u1',
              orgId: 'acme',
              role: LicenseOrgMemberRole.admin,
              joinedAt: null,
              invitedBy: null,
              status: LicenseOrgMemberStatus.active,
            ),
          },
        ),
      );
      addTearDown(c.dispose);

      await _settle(c, currentUserLicenseOrgMembershipProvider('acme'));
      expect(
        c.read(licenseOrgRoleProvider('acme')),
        LicenseOrgMemberRole.unknown,
      );
    });
  });

  group('licenseOrgRedeemedSeatCountProvider', () {
    test('counts only seats whose orgId matches', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(),
        seatRepo: _StubSeatRepo(<SeatAllocationRef>{
          const SeatAllocationRef(orgId: 'acme', productId: 'theme_pack'),
          const SeatAllocationRef(orgId: 'acme', productId: 'ringtone_pack'),
          const SeatAllocationRef(orgId: 'beta', productId: 'theme_pack'),
        }),
      );
      addTearDown(c.dispose);

      // Settle the seat-allocations stream.
      await _settle(c, currentUserSeatAllocationsProvider);
      expect(c.read(licenseOrgRedeemedSeatCountProvider('acme')), 2);
      expect(c.read(licenseOrgRedeemedSeatCountProvider('beta')), 1);
      expect(c.read(licenseOrgRedeemedSeatCountProvider('gamma')), 0);
    });

    test('returns 0 when flag is off', () async {
      _setFlag(enabled: false);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(),
        seatRepo: _StubSeatRepo(<SeatAllocationRef>{
          const SeatAllocationRef(orgId: 'acme', productId: 'theme_pack'),
        }),
      );
      addTearDown(c.dispose);

      await _settle(c, currentUserSeatAllocationsProvider);
      expect(c.read(licenseOrgRedeemedSeatCountProvider('acme')), 0);
    });
  });
}
