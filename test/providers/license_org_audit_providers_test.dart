// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Pins the fail-closed contract of [licenseOrgRecentAuditProvider].
//
// Coverage:
//   - flag off                  -> []
//   - signed-out                -> []
//   - anonymous user            -> []
//   - empty orgId               -> []
//   - suspended parent org      -> [] (defence-in-depth guard at provider)
//   - active org, zero events   -> []
//   - active org, three events  -> the three, newest first (repo order)
//   - repo stream error         -> [], log written

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/license_org.dart';
import 'package:socialmesh/models/license_org_audit_event.dart';
import 'package:socialmesh/models/license_org_membership.dart';
import 'package:socialmesh/providers/auth_providers.dart';
import 'package:socialmesh/providers/license_org_audit_providers.dart';
import 'package:socialmesh/providers/license_org_membership_providers.dart';
import 'package:socialmesh/services/org/license_org_audit_repository.dart';
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

class _StubMembershipRepo implements LicenseOrgMembershipRepository {
  final Map<String, LicenseOrg?> _orgs;

  _StubMembershipRepo({Map<String, LicenseOrg?>? orgs})
    : _orgs = orgs ?? const {};

  @override
  Stream<LicenseOrgMembershipSetState> watchCurrentUserOrgIdState(String uid) =>
      Stream.value(LicenseOrgMembershipSetState.unresolved);

  @override
  Stream<LicenseOrg?> watchLicenseOrg(String orgId) =>
      Stream.value(_orgs[orgId]);

  @override
  Stream<LicenseOrgMembership?> watchMembership(String orgId, String uid) =>
      Stream.value(null);

  @override
  Stream<List<LicenseOrgMembership>> membersForOrg(String orgId) =>
      Stream.value(const <LicenseOrgMembership>[]);
}

class _StubAuditRepo implements LicenseOrgAuditRepository {
  final Map<String, List<LicenseOrgAuditEvent>> _events;
  int fetchPageCallCount = 0;
  Object? lastFetchStartAfter;

  _StubAuditRepo([Map<String, List<LicenseOrgAuditEvent>>? events])
    : _events = events ?? const {};

  @override
  Stream<List<LicenseOrgAuditEvent>> recentEventsForOrg(
    String orgId, {
    int limit = 5,
  }) {
    final all = _events[orgId] ?? const <LicenseOrgAuditEvent>[];
    return Stream.value(all.take(limit).toList(growable: false));
  }

  @override
  Future<LicenseOrgAuditLogPage> fetchPage(
    String orgId, {
    Object? startAfter,
    int limit = 50,
  }) async {
    fetchPageCallCount++;
    lastFetchStartAfter = startAfter;
    final all = _events[orgId] ?? const <LicenseOrgAuditEvent>[];
    final startIndex = startAfter is int ? startAfter : 0;
    final slice = all.skip(startIndex).take(limit).toList(growable: false);
    final nextIndex = startIndex + slice.length;
    return LicenseOrgAuditLogPage(
      events: slice,
      cursor: slice.isEmpty ? null : nextIndex,
      hasMore: nextIndex < all.length,
    );
  }
}

class _ThrowingAuditRepo implements LicenseOrgAuditRepository {
  @override
  Stream<List<LicenseOrgAuditEvent>> recentEventsForOrg(
    String orgId, {
    int limit = 5,
  }) => Stream<List<LicenseOrgAuditEvent>>.error(
    StateError('Firestore unavailable'),
  );

  @override
  Future<LicenseOrgAuditLogPage> fetchPage(
    String orgId, {
    Object? startAfter,
    int limit = 50,
  }) async => throw StateError('Firestore unavailable');
}

void _setFlag({required bool enabled}) {
  dotenv.env['GROUP_LICENSING_ENABLED'] = enabled ? 'true' : 'false';
}

ProviderContainer _container({
  required User? user,
  required LicenseOrgMembershipRepository membershipRepo,
  required LicenseOrgAuditRepository auditRepo,
}) {
  return ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => user),
      licenseOrgMembershipRepositoryProvider.overrideWith(
        (ref) => membershipRepo,
      ),
      licenseOrgAuditRepositoryProvider.overrideWith((ref) => auditRepo),
    ],
  );
}

Future<List<LicenseOrgAuditEvent>> _settle(
  ProviderContainer c,
  String orgId,
) async {
  final sub = c.listen<AsyncValue<List<LicenseOrgAuditEvent>>>(
    licenseOrgRecentAuditProvider(orgId),
    (_, _) {},
    fireImmediately: true,
  );
  try {
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

LicenseOrgAuditEvent _event(
  String id, {
  LicenseOrgAuditAction action = LicenseOrgAuditAction.memberJoined,
  LicenseOrgAuditOutcome outcome = LicenseOrgAuditOutcome.success,
  String? reasonCode,
  String orgId = 'acme',
}) => LicenseOrgAuditEvent(
  id: id,
  licenseOrgId: orgId,
  action: action,
  targetKind: LicenseOrgAuditTargetKind.licenseOrgMembership,
  targetId: 'target-$id',
  actorUid: 'actor-uid-$id',
  actorRole: LicenseOrgAuditActorRole.admin,
  outcome: outcome,
  reasonCode: reasonCode,
  tsServer: DateTime.utc(2026, 5, 26, 12, 0),
  metadata: const {},
);

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'GROUP_LICENSING_ENABLED=false\n');
  });

  group('licenseOrgRecentAuditProvider', () {
    test('yields [] when flag is off', () async {
      _setFlag(enabled: false);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        membershipRepo: _StubMembershipRepo(orgs: {'acme': _activeOrg('acme')}),
        auditRepo: _StubAuditRepo({
          'acme': [_event('e1'), _event('e2')],
        }),
      );
      addTearDown(c.dispose);
      final result = await _settle(c, 'acme');
      expect(result, isEmpty);
    });

    test('yields [] when user is signed out', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: null,
        membershipRepo: _StubMembershipRepo(orgs: {'acme': _activeOrg('acme')}),
        auditRepo: _StubAuditRepo({
          'acme': [_event('e1')],
        }),
      );
      addTearDown(c.dispose);
      final result = await _settle(c, 'acme');
      expect(result, isEmpty);
    });

    test('yields [] when user is anonymous', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1', isAnonymous: true),
        membershipRepo: _StubMembershipRepo(orgs: {'acme': _activeOrg('acme')}),
        auditRepo: _StubAuditRepo({
          'acme': [_event('e1')],
        }),
      );
      addTearDown(c.dispose);
      final result = await _settle(c, 'acme');
      expect(result, isEmpty);
    });

    test('yields [] on empty orgId', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        membershipRepo: _StubMembershipRepo(),
        auditRepo: _StubAuditRepo(),
      );
      addTearDown(c.dispose);
      final result = await _settle(c, '');
      expect(result, isEmpty);
    });

    test('yields [] when parent org is suspended', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        membershipRepo: _StubMembershipRepo(
          orgs: {'acme': _suspendedOrg('acme')},
        ),
        auditRepo: _StubAuditRepo({
          'acme': [_event('e1'), _event('e2')],
        }),
      );
      addTearDown(c.dispose);
      final result = await _settle(c, 'acme');
      expect(result, isEmpty);
    });

    test(
      'yields the events in repo order when active org + signed-in user',
      () async {
        _setFlag(enabled: true);
        final c = _container(
          user: _FakeUser(uid: 'u1'),
          membershipRepo: _StubMembershipRepo(
            orgs: {'acme': _activeOrg('acme')},
          ),
          auditRepo: _StubAuditRepo({
            'acme': [_event('e1'), _event('e2'), _event('e3')],
          }),
        );
        addTearDown(c.dispose);
        final result = await _settle(c, 'acme');
        expect(result, hasLength(3));
        expect(result[0].id, 'e1');
        expect(result[1].id, 'e2');
        expect(result[2].id, 'e3');
      },
    );

    test('yields [] when the audit repo stream errors', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        membershipRepo: _StubMembershipRepo(orgs: {'acme': _activeOrg('acme')}),
        auditRepo: _ThrowingAuditRepo(),
      );
      addTearDown(c.dispose);
      final result = await _settle(c, 'acme');
      expect(result, isEmpty);
    });

    test('yields [] when org with zero events is active', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        membershipRepo: _StubMembershipRepo(orgs: {'acme': _activeOrg('acme')}),
        auditRepo: _StubAuditRepo({'acme': const <LicenseOrgAuditEvent>[]}),
      );
      addTearDown(c.dispose);
      final result = await _settle(c, 'acme');
      expect(result, isEmpty);
    });
  });

  group('licenseOrgAuditLogProvider (paginated)', () {
    Future<LicenseOrgAuditLogState> settle(
      ProviderContainer c,
      String orgId,
    ) async {
      final sub = c.listen<AsyncValue<LicenseOrgAuditLogState>>(
        licenseOrgAuditLogProvider(orgId),
        (_, _) {},
        fireImmediately: true,
      );
      try {
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

    test('returns empty state when flag is off', () async {
      _setFlag(enabled: false);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        membershipRepo: _StubMembershipRepo(orgs: {'acme': _activeOrg('acme')}),
        auditRepo: _StubAuditRepo({
          'acme': [_event('e1'), _event('e2')],
        }),
      );
      addTearDown(c.dispose);
      final state = await settle(c, 'acme');
      expect(state.events, isEmpty);
      expect(state.hasMore, isFalse);
    });

    test('returns empty state when user is signed out', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: null,
        membershipRepo: _StubMembershipRepo(orgs: {'acme': _activeOrg('acme')}),
        auditRepo: _StubAuditRepo({
          'acme': [_event('e1')],
        }),
      );
      addTearDown(c.dispose);
      final state = await settle(c, 'acme');
      expect(state.events, isEmpty);
      expect(state.hasMore, isFalse);
    });

    test('returns empty state for anonymous user', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1', isAnonymous: true),
        membershipRepo: _StubMembershipRepo(orgs: {'acme': _activeOrg('acme')}),
        auditRepo: _StubAuditRepo({
          'acme': [_event('e1')],
        }),
      );
      addTearDown(c.dispose);
      final state = await settle(c, 'acme');
      expect(state.events, isEmpty);
    });

    test('returns empty state for empty orgId', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        membershipRepo: _StubMembershipRepo(),
        auditRepo: _StubAuditRepo(),
      );
      addTearDown(c.dispose);
      final state = await settle(c, '');
      expect(state.events, isEmpty);
    });

    test('fail-closes to empty page when the repo throws', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        membershipRepo: _StubMembershipRepo(orgs: {'acme': _activeOrg('acme')}),
        auditRepo: _ThrowingAuditRepo(),
      );
      addTearDown(c.dispose);
      final state = await settle(c, 'acme');
      expect(state.events, isEmpty);
      expect(state.hasMore, isFalse);
      expect(state.cursor, isNull);
    });

    test(
      'first page returns events with hasMore=false when fits in one page',
      () async {
        _setFlag(enabled: true);
        final repo = _StubAuditRepo({
          'acme': [_event('e1'), _event('e2'), _event('e3')],
        });
        final c = _container(
          user: _FakeUser(uid: 'u1'),
          membershipRepo: _StubMembershipRepo(
            orgs: {'acme': _activeOrg('acme')},
          ),
          auditRepo: repo,
        );
        addTearDown(c.dispose);
        final state = await settle(c, 'acme');
        expect(state.events.map((e) => e.id), ['e1', 'e2', 'e3']);
        expect(state.hasMore, isFalse);
        expect(repo.fetchPageCallCount, 1);
      },
    );

    test('loadMore appends next page and updates cursor', () async {
      _setFlag(enabled: true);
      final events = List.generate(120, (i) => _event('e$i'));
      final repo = _StubAuditRepo({'acme': events});
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        membershipRepo: _StubMembershipRepo(orgs: {'acme': _activeOrg('acme')}),
        auditRepo: repo,
      );
      addTearDown(c.dispose);
      final initial = await settle(c, 'acme');
      expect(initial.events, hasLength(50));
      expect(initial.hasMore, isTrue);
      expect(initial.cursor, 50);

      final notifier = c.read(licenseOrgAuditLogProvider('acme').notifier);
      await notifier.loadMore();
      final second = await settle(c, 'acme');
      expect(second.events, hasLength(100));
      expect(second.hasMore, isTrue);
      expect(second.cursor, 100);
      expect(repo.fetchPageCallCount, 2);
      expect(repo.lastFetchStartAfter, 50);

      await notifier.loadMore();
      final third = await settle(c, 'acme');
      expect(third.events, hasLength(120));
      expect(third.hasMore, isFalse);
      expect(repo.fetchPageCallCount, 3);
    });

    test('loadMore is a no-op when hasMore is false', () async {
      _setFlag(enabled: true);
      final repo = _StubAuditRepo({
        'acme': [_event('e1'), _event('e2')],
      });
      final c = _container(
        user: _FakeUser(uid: 'u1'),
        membershipRepo: _StubMembershipRepo(orgs: {'acme': _activeOrg('acme')}),
        auditRepo: repo,
      );
      addTearDown(c.dispose);
      await settle(c, 'acme');
      final notifier = c.read(licenseOrgAuditLogProvider('acme').notifier);
      await notifier.loadMore();
      final after = await settle(c, 'acme');
      expect(after.events, hasLength(2));
      expect(after.hasMore, isFalse);
      expect(repo.fetchPageCallCount, 1);
    });
  });
}
