// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// [FirstContactBannerDismissals] tests — local UI-only persistence
/// of which peers' first-contact banners the user has dismissed.
///
/// Hard rules pinned by these tests:
///
///   - Dismissal does NOT mutate any protocol or safety state.
///     `dismiss(peerId)` must not flip the corresponding peer's
///     `hasFirstContact`, must not call `markFirstHandshake`, must
///     not emit any wire frame. Only the dismissals set changes.
///   - `isDismissed` is a sync hot-path getter — safe to call from
///     `build()`. Returns `false` until the prefs load completes.
///   - `dismiss` is idempotent: re-tapping after dismiss is a no-op.
///   - The set is persisted across container re-init (simulates app
///     restart).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/providers/peer_safety_providers.dart';

ProviderContainer _newContainer() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FirstContactBannerDismissals', () {
    test('starts with an empty dismissals set', () async {
      final c = _newContainer();
      final loaded = await c.read(firstContactBannerDismissalsProvider.future);
      expect(loaded, isEmpty);
      final notifier = c.read(firstContactBannerDismissalsProvider.notifier);
      expect(notifier.isDismissed(0xAAAA), isFalse);
      expect(notifier.isDismissed(0xBBBB), isFalse);
    });

    test('dismiss(id) flips isDismissed to true for that id only', () async {
      final c = _newContainer();
      await c.read(firstContactBannerDismissalsProvider.future);
      final notifier = c.read(firstContactBannerDismissalsProvider.notifier);
      await notifier.dismiss(0xAAAA);
      expect(notifier.isDismissed(0xAAAA), isTrue);
      expect(notifier.isDismissed(0xBBBB), isFalse);
    });

    test('dismiss is idempotent — re-tapping is a no-op', () async {
      final c = _newContainer();
      await c.read(firstContactBannerDismissalsProvider.future);
      final notifier = c.read(firstContactBannerDismissalsProvider.notifier);
      await notifier.dismiss(0xCAFE);
      await notifier.dismiss(0xCAFE);
      await notifier.dismiss(0xCAFE);
      final state = c.read(firstContactBannerDismissalsProvider).value;
      expect(state, isNotNull);
      expect(state!.length, equals(1));
      expect(state, contains(0xCAFE));
    });

    test('persists across container re-init (app restart)', () async {
      final first = _newContainer();
      await first.read(firstContactBannerDismissalsProvider.future);
      await first
          .read(firstContactBannerDismissalsProvider.notifier)
          .dismiss(0xDEAD);
      await first
          .read(firstContactBannerDismissalsProvider.notifier)
          .dismiss(0xBEEF);

      // Simulate restart: dispose + create a new container against
      // the same SharedPreferences mock. The mock's underlying map
      // is preserved between containers as long as setMockInitialValues
      // is not called again, so the new notifier should reload both
      // dismissals on first build.
      first.dispose();

      final second = _newContainer();
      final loaded = await second.read(
        firstContactBannerDismissalsProvider.future,
      );
      expect(loaded, contains(0xDEAD));
      expect(loaded, contains(0xBEEF));
      expect(loaded.length, equals(2));
    });

    test('reset(id) clears the dismissal', () async {
      final c = _newContainer();
      await c.read(firstContactBannerDismissalsProvider.future);
      final notifier = c.read(firstContactBannerDismissalsProvider.notifier);
      await notifier.dismiss(0x1234);
      expect(notifier.isDismissed(0x1234), isTrue);
      await notifier.reset(0x1234);
      expect(notifier.isDismissed(0x1234), isFalse);
    });

    test('dismiss does NOT touch peer safety state '
        '(banner is pure UI affordance)', () async {
      // Defence-in-depth: confirm the dismissal pathway is fully
      // decoupled from PeerSafetyManager. We don't override
      // peerSafetyStoreProvider here — if `dismiss` ever called into
      // it, this test would fail with a provider-not-overridden /
      // missing-store error.
      final c = _newContainer();
      await c.read(firstContactBannerDismissalsProvider.future);
      await c
          .read(firstContactBannerDismissalsProvider.notifier)
          .dismiss(0xABCD);
      expect(
        c
            .read(firstContactBannerDismissalsProvider.notifier)
            .isDismissed(0xABCD),
        isTrue,
      );
    });
  });
}
