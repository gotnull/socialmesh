// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Pins the fail-closed contract of [currentUserSeatAllocationsProvider]:
//
//   - flag off  -> empty, regardless of user state
//   - guest     -> empty
//   - authed    -> repository result
//   - repo error -> empty (no rethrow)
//   - hasSeatForProvider returns false during loading / error
//
// End-to-end "membership + seat unlocks org-owned entitlement" is
// asserted by the cache + provider tests in
// `external_entitlement_cache_test.dart` and
// `effective_entitlements_test.dart`.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/seat_allocation.dart';
import 'package:socialmesh/providers/auth_providers.dart';
import 'package:socialmesh/providers/seat_allocation_providers.dart';
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

class _StubRepo implements SeatAllocationRepository {
  final Map<String, Stream<Set<SeatAllocationRef>>> _byUid;

  _StubRepo(this._byUid);

  @override
  Stream<Set<SeatAllocationRef>> watchCurrentUserSeats(String uid) =>
      _byUid[uid] ?? Stream.value(const <SeatAllocationRef>{});
}

class _ThrowingRepo implements SeatAllocationRepository {
  @override
  Stream<Set<SeatAllocationRef>> watchCurrentUserSeats(String uid) =>
      Stream<Set<SeatAllocationRef>>.error(StateError('Firestore unavailable'));
}

void _setFlag({required bool enabled}) {
  dotenv.env['GROUP_LICENSING_ENABLED'] = enabled ? 'true' : 'false';
}

ProviderContainer _container({
  required User? user,
  required SeatAllocationRepository repo,
}) {
  return ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => user),
      seatAllocationRepositoryProvider.overrideWith((ref) => repo),
    ],
  );
}

Future<void> _pumpUntilNonLoading(ProviderContainer c) async {
  final sub = c.listen<AsyncValue<Set<SeatAllocationRef>>>(
    currentUserSeatAllocationsProvider,
    (_, _) {},
    fireImmediately: true,
  );
  try {
    for (var i = 0; i < 50; i++) {
      if (sub.read().hasValue) return;
      await Future<void>.delayed(Duration.zero);
    }
    throw StateError(
      'currentUserSeatAllocationsProvider did not settle within pump budget',
    );
  } finally {
    sub.close();
  }
}

const _widgetSeat = SeatAllocationRef(
  orgId: 'acme-eng-team',
  productId: 'widget_pack',
);

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'GROUP_LICENSING_ENABLED=false\n');
  });

  setUp(() {
    _setFlag(enabled: false);
  });

  group('feature flag gate', () {
    test('flag off -> empty even for authed user with seats', () async {
      _setFlag(enabled: false);
      final c = _container(
        user: _FakeUser(uid: 'user-1'),
        repo: _StubRepo({
          'user-1': Stream.value({_widgetSeat}),
        }),
      );
      await _pumpUntilNonLoading(c);
      expect(c.read(currentUserSeatAllocationsProvider).value, isEmpty);
      expect(c.read(hasSeatForProvider(_widgetSeat)), isFalse);
      c.dispose();
    });
  });

  group('auth state gate', () {
    test('signed-out user -> empty', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: null,
        repo: _StubRepo({
          'user-1': Stream.value({_widgetSeat}),
        }),
      );
      await _pumpUntilNonLoading(c);
      expect(c.read(currentUserSeatAllocationsProvider).value, isEmpty);
      c.dispose();
    });

    test('anonymous (guest) user -> empty even with seats', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'anon-abc', isAnonymous: true),
        repo: _StubRepo({
          'anon-abc': Stream.value({_widgetSeat}),
        }),
      );
      await _pumpUntilNonLoading(c);
      expect(c.read(currentUserSeatAllocationsProvider).value, isEmpty);
      c.dispose();
    });

    test('empty uid -> empty', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: ''),
        repo: _StubRepo({
          '': Stream.value({_widgetSeat}),
        }),
      );
      await _pumpUntilNonLoading(c);
      expect(c.read(currentUserSeatAllocationsProvider).value, isEmpty);
      c.dispose();
    });
  });

  group('authed user repo passthrough', () {
    test('yields seats from repository', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'user-1'),
        repo: _StubRepo({
          'user-1': Stream.value({
            _widgetSeat,
            const SeatAllocationRef(
              orgId: 'acme-eng-team',
              productId: 'theme_pack',
            ),
          }),
        }),
      );
      await _pumpUntilNonLoading(c);
      final seats = c.read(currentUserSeatAllocationsProvider).value!;
      expect(seats, hasLength(2));
      expect(c.read(hasSeatForProvider(_widgetSeat)), isTrue);
      expect(
        c.read(
          hasSeatForProvider(
            const SeatAllocationRef(orgId: 'acme', productId: 'unknown'),
          ),
        ),
        isFalse,
      );
      c.dispose();
    });

    test('empty seat set yields empty', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'user-1'),
        repo: _StubRepo({'user-1': Stream.value(const <SeatAllocationRef>{})}),
      );
      await _pumpUntilNonLoading(c);
      expect(c.read(currentUserSeatAllocationsProvider).value, isEmpty);
      c.dispose();
    });

    test('malformed rows are filtered by the model parser', () {
      // Defence-in-depth: the repository drops rows that fail the
      // parser. Verify the parser contract here so the provider can
      // trust the stream payload.
      expect(
        SeatAllocation.fromMap({
          'uid': 'user-1',
          'productId': 'widget_pack',
          'status': 'active',
        }),
        isNull,
      );
      expect(
        SeatAllocation.fromMap({
          'orgId': 'acme',
          'productId': 'widget_pack',
          'status': 'active',
        }),
        isNull,
      );
      expect(
        SeatAllocation.fromMap({
          'orgId': 'acme',
          'uid': 'user-1',
          'productId': '',
          'status': 'active',
        }),
        isNull,
      );
    });
  });

  group('error handling', () {
    test('repo stream error -> provider yields empty', () async {
      _setFlag(enabled: true);
      final c = _container(
        user: _FakeUser(uid: 'user-1'),
        repo: _ThrowingRepo(),
      );
      await _pumpUntilNonLoading(c);
      final async = c.read(currentUserSeatAllocationsProvider);
      expect(async.hasValue, isTrue);
      expect(async.value, isEmpty);
      expect(c.read(hasSeatForProvider(_widgetSeat)), isFalse);
      c.dispose();
    });
  });
}
