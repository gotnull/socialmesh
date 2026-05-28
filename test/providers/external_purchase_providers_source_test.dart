// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Source-text regressions for `external_purchase_providers.dart`.
//
// The cache-clear-on-uid-change invariant is hard to drive in a pure
// Riverpod widget test because the [ExternalPurchaseService] is a
// FutureProvider that hangs on a real SharedPreferences instance, and
// the cache is a behavioural side-effect (not state on the provider).
// Source-text pins the load-bearing observations so a refactor that
// drops the `cache.clear()` call would trip CI before users hit it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String src;

  setUpAll(() {
    src = File(
      'lib/providers/external_purchase_providers.dart',
    ).readAsStringSync();
  });

  group('externalPurchaseServiceProvider — cache isolation on auth flip', () {
    test('listens to currentUserProvider with fireImmediately', () {
      // The listen needs to observe ALL emissions including the
      // initial steady-state, otherwise the cold-start branch would
      // never set `lastSeenUid`. `fireImmediately: true` is the
      // gate that makes the very first user observation be the
      // baseline that future emissions are compared against.
      expect(src, contains('ref.listen<User?>(currentUserProvider'));
      expect(src, contains('fireImmediately: true'));
    });

    test('tracks lastSeenUid separately from lastClaimedUid', () {
      // Without a separate cursor, the first emission would either
      // wipe the cache (if we keyed off lastClaimedUid which only
      // tracks non-anonymous sign-ins) or never wipe at all (if we
      // mixed the two). Keep two cursors so the auth-flip detector
      // and the claim-fire-once detector evolve independently.
      expect(src, contains('String? lastSeenUid'));
      expect(src, contains('String? lastClaimedUid'));
    });

    test('clears the cache only on a uid CHANGE, not on first observation', () {
      // The first emission must NOT clear: a cold start with a
      // signed-in user has lastSeenUid == null AND a valid uid
      // restored from offline cache. Wiping then would lose that
      // cache before the refresh callable lands and re-populates.
      // The guard is `lastSeenUid != null && lastSeenUid != nextUid`.
      expect(
        src,
        contains('if (lastSeenUid != null && lastSeenUid != nextUid)'),
      );
    });

    test('actually invokes service.cache.clear() in the auth-flip branch', () {
      // Bound the search to the section between the auth-flip
      // detector and the next ref.listen call so we know the clear
      // sits inside the right branch.
      final guardIdx = src.indexOf(
        'if (lastSeenUid != null && lastSeenUid != nextUid)',
      );
      expect(guardIdx, greaterThan(-1));
      final blockEnd = src.indexOf('lastSeenUid = nextUid', guardIdx);
      expect(blockEnd, greaterThan(guardIdx));
      final block = src.substring(guardIdx, blockEnd);
      expect(block, contains('service.cache.clear()'));
    });

    test('updates lastSeenUid AFTER the clear runs', () {
      // The update must follow the clear so the same listener fire
      // does not race itself (set, then test the same value).
      // Source pins the ordering explicitly.
      final clearIdx = src.indexOf('service.cache.clear()');
      final setIdx = src.indexOf('lastSeenUid = nextUid', clearIdx);
      expect(clearIdx, greaterThan(-1));
      expect(setIdx, greaterThan(clearIdx));
    });

    test('cache clear is fire-and-forget (unawaited)', () {
      // The listener is synchronous; awaiting would block the next
      // emission. unawaited keeps the listener obs cheap and the
      // SharedPreferences write happens in the background.
      expect(src, contains('unawaited(service.cache.clear())'));
    });
  });
}
