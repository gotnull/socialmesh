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

import 'dart:io';

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

  @override
  Stream<int> watchOrgActiveSeatCount(String orgId) => Stream.value(0);
}

class _ThrowingRepo implements SeatAllocationRepository {
  @override
  Stream<Set<SeatAllocationRef>> watchCurrentUserSeats(String uid) =>
      Stream<Set<SeatAllocationRef>>.error(StateError('Firestore unavailable'));

  @override
  Stream<int> watchOrgActiveSeatCount(String orgId) =>
      Stream<int>.error(StateError('Firestore unavailable'));
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

  group('licenseOrgActiveSeatCountProvider — auth-change re-subscribe', () {
    // Regression for the wedge bug observed on 2026-05-28:
    // - foolvo signs in, opens the org overview, Capacity reads 1/10.
    // - foolvo signs out, socialmeshapp signs in, then back to foolvo.
    // - Capacity reads 0/10 even though Firestore has 1 active seat.
    // - Recovers only after `flutter run` relaunches the app.
    //
    // The root cause was that the provider's body did not watch
    // [currentUserProvider], so the underlying Firestore snapshot
    // subscription survived the auth flip with a stale auth context.
    // The fix is `ref.watch(currentUserProvider.select((u) => u?.uid))`
    // which forces a teardown + re-subscribe when uid changes. We
    // pin that invariant via source-text inspection because the
    // observable behaviour requires a live Firestore subscription
    // and a real auth flip — neither is easy to fake in pure-dart
    // tests, and a stub stream would re-emit naturally without
    // surfacing the bug. The source-text check guards against
    // someone removing the watch line.
    test('provider body watches currentUserProvider uid', () {
      final src = File(
        'lib/providers/seat_allocation_providers.dart',
      ).readAsStringSync();
      // Bound the search to the org-count provider body so a watch
      // line that drifts into the per-user seats provider does not
      // accidentally satisfy this test.
      final orgCountIdx = src.indexOf(
        'final licenseOrgActiveSeatCountProvider',
      );
      expect(orgCountIdx, greaterThan(-1));
      // Find the closing `});` of the provider body. The literal
      // appears multiple times in the file; we want the FIRST one
      // after the provider declaration.
      final closeIdx = src.indexOf('});', orgCountIdx);
      expect(closeIdx, greaterThan(orgCountIdx));
      final body = src.substring(orgCountIdx, closeIdx);
      expect(
        body,
        contains('ref.watch(currentUserProvider.select((u) => u?.uid))'),
        reason:
            'licenseOrgActiveSeatCountProvider must watch the current uid '
            'so the Firestore subscription tears down + re-subscribes on '
            'sign-out/sign-in. Removing this watch reintroduces the '
            '2026-05-28 wedge.',
      );
    });
  });
}
