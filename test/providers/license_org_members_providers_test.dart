// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Pins the fail-closed contract of [licenseOrgMembersProvider] and
// [licenseOrgMemberCountProvider].
//
// Coverage:
//   - flag off                 -> []
//   - signed-out               -> []
//   - anonymous user           -> []
//   - empty orgId              -> []
//   - suspended parent org     -> [] (privacy gate at provider layer)
//   - active org, zero members -> []
//   - active org, three members -> the three, in repo order
//   - repo stream error        -> [], log written

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/license_org.dart';
import 'package:socialmesh/models/license_org_membership.dart';
import 'package:socialmesh/providers/auth_providers.dart';
import 'package:socialmesh/providers/license_org_members_providers.dart';
import 'package:socialmesh/providers/license_org_membership_providers.dart';
import 'package:socialmesh/services/org/license_org_membership_repository.dart';

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
  final Map<String, List<LicenseOrgMembership>> _members;

  _StubRepo({
    Map<String, LicenseOrg?>? orgs,
    Map<String, List<LicenseOrgMembership>>? members,
  }) : _orgs = orgs ?? const {},
       _members = members ?? const {};

  @override
  Stream<Set<String>> watchCurrentUserOrgIds(String uid) =>
      Stream.value(const <String>{});

  @override
  Stream<LicenseOrg?> watchLicenseOrg(String orgId) =>
      Stream.value(_orgs[orgId]);

  @override
  Stream<LicenseOrgMembership?> watchMembership(String orgId, String uid) =>
      Stream.value(null);

  @override
  Stream<List<LicenseOrgMembership>> membersForOrg(String orgId) =>
      Stream.value(_members[orgId] ?? const <LicenseOrgMembership>[]);
}

class _ThrowingMembersRepo implements LicenseOrgMembershipRepository {
  final LicenseOrg activeOrg;

  _ThrowingMembersRepo(this.activeOrg);

  @override
  Stream<Set<String>> watchCurrentUserOrgIds(String uid) =>
      Stream.value(const <String>{});

  @override
  Stream<LicenseOrg?> watchLicenseOrg(String orgId) => Stream.value(activeOrg);

  @override
  Stream<LicenseOrgMembership?> watchMembership(String orgId, String uid) =>
      Stream.value(null);

  @override
  Stream<List<LicenseOrgMembership>> membersForOrg(String orgId) =>
      Stream<List<LicenseOrgMembership>>.error(
        StateError('Firestore unavailable'),
      );
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

Future<T> _settle<T>(ProviderContainer c, dynamic p) async {
  final sub = c.listen<AsyncValue<T>>(
    p as dynamic,
    (_, _) {},
    fireImmediately: true,
  );
  try {
    // Pump aggressively so the async* provider emits both its initial
    // guard (yield const []) AND the downstream repo stream value.
    // Returning on the first hasValue would lock in the initial empty
    // guard and miss the real data.
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    final v = sub.read();
    if (v.hasValue) return v.requireValue;
    throw StateError('Provider did not settle within pump budget');
  } finally {
    sub.close();
  }
}

LicenseOrg _activeOrg(String id) => LicenseOrg(
  id: id,
  name: id,
  ownerUid: 'owner-uid',
  createdAt: null,
  status: LicenseOrgStatus.active,
);

LicenseOrg _suspendedOrg(String id) => LicenseOrg(
  id: id,
  name: id,
  ownerUid: 'owner-uid',
  createdAt: null,
  status: LicenseOrgStatus.suspended,
);

LicenseOrgMembership _member(String uid, {DateTime? joinedAt}) =>
    LicenseOrgMembership(
      uid: uid,
      orgId: 'acme',
      role: LicenseOrgMemberRole.member,
      joinedAt: joinedAt,
      invitedBy: null,
      status: LicenseOrgMemberStatus.active,
    );

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'GROUP_LICENSING_ENABLED=false\n');
  });

  group('licenseOrgMembersProvider', () {
    test('yields [] when flag is off', () async {
      _setFlag(enabled: false);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(
          orgs: {'acme': _activeOrg('acme')},
          members: {
            'acme': [_member('m1'), _member('m2')],
          },
        ),
      );
      addTearDown(c.dispose);
      final result = await _settle(c, licenseOrgMembersProvider('acme'));
      expect(result, isEmpty);
    });

    test('yields [] when user is signed out', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: null,
        repo: _StubRepo(
          orgs: {'acme': _activeOrg('acme')},
          members: {
            'acme': [_member('m1')],
          },
        ),
      );
      addTearDown(c.dispose);
      final result = await _settle(c, licenseOrgMembersProvider('acme'));
      expect(result, isEmpty);
    });

    test('yields [] when user is anonymous', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1', isAnonymous: true),
        repo: _StubRepo(
          orgs: {'acme': _activeOrg('acme')},
          members: {
            'acme': [_member('m1')],
          },
        ),
      );
      addTearDown(c.dispose);
      final result = await _settle(c, licenseOrgMembersProvider('acme'));
      expect(result, isEmpty);
    });

    test('yields [] when orgId is empty', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(),
      );
      addTearDown(c.dispose);
      final result = await _settle(c, licenseOrgMembersProvider(''));
      expect(result, isEmpty);
    });

    test('yields [] when parent org is suspended', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(
          orgs: {'acme': _suspendedOrg('acme')},
          members: {
            'acme': [_member('m1'), _member('m2')],
          },
        ),
      );
      addTearDown(c.dispose);
      final result = await _settle(c, licenseOrgMembersProvider('acme'));
      expect(result, isEmpty);
    });

    test('yields the repo members for an active org', () async {
      _setFlag(enabled: true);
      final members = [
        _member('m1', joinedAt: DateTime.utc(2026, 1, 1)),
        _member('m2', joinedAt: DateTime.utc(2026, 2, 1)),
        _member('m3', joinedAt: DateTime.utc(2026, 3, 1)),
      ];
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(
          orgs: {'acme': _activeOrg('acme')},
          members: {'acme': members},
        ),
      );
      addTearDown(c.dispose);
      final result = await _settle(c, licenseOrgMembersProvider('acme'));
      expect(result, members);
    });

    test(
      'yields [] when the repo stream errors (logged, not thrown)',
      () async {
        _setFlag(enabled: true);
        final c = _container(
          user: _FakeUser(uid: 'u1'),
          repo: _ThrowingMembersRepo(_activeOrg('acme')),
        );
        addTearDown(c.dispose);
        final result = await _settle(c, licenseOrgMembersProvider('acme'));
        expect(result, isEmpty);
      },
    );
  });

  group('licenseOrgMemberCountProvider', () {
    test('returns the member list length on data', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(
          orgs: {'acme': _activeOrg('acme')},
          members: {
            'acme': [_member('m1'), _member('m2')],
          },
        ),
      );
      addTearDown(c.dispose);
      await _settle(c, licenseOrgMembersProvider('acme'));
      expect(c.read(licenseOrgMemberCountProvider('acme')), 2);
    });

    test('returns 0 when the list provider is empty', () async {
      _setFlag(enabled: false);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        repo: _StubRepo(
          orgs: {'acme': _activeOrg('acme')},
          members: {
            'acme': [_member('m1')],
          },
        ),
      );
      addTearDown(c.dispose);
      await _settle(c, licenseOrgMembersProvider('acme'));
      expect(c.read(licenseOrgMemberCountProvider('acme')), 0);
    });
  });
}
