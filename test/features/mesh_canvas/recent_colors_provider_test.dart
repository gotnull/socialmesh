// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Provider-layer tests for the S7.B recents memory.
//
// Pins:
//   - move-to-front (no duplicate entries)
//   - cap at RecentColorsNotifier.maxRecents
//   - out-of-range push is silently rejected
//   - SelectedColorNotifier.select fans out into recentColorsProvider
//     so callers don't have to manually push.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/mesh_canvas/providers/mesh_canvas_providers.dart';

void main() {
  group('RecentColorsNotifier', () {
    test('starts empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(recentColorsProvider), isEmpty);
    });

    test('push inserts newest at head', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(recentColorsProvider.notifier).push(11);
      container.read(recentColorsProvider.notifier).push(18);
      container.read(recentColorsProvider.notifier).push(25);

      expect(container.read(recentColorsProvider), [25, 18, 11]);
    });

    test('push moves an existing entry to head rather than duplicating', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(recentColorsProvider.notifier).push(11);
      container.read(recentColorsProvider.notifier).push(18);
      container.read(recentColorsProvider.notifier).push(11); // re-tap

      expect(container.read(recentColorsProvider), [11, 18]);
    });

    test('push caps the list at maxRecents', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Push more than the cap; oldest entries should drop off the
      // tail as new ones land at the head.
      for (var i = 0; i < RecentColorsNotifier.maxRecents + 4; i++) {
        container.read(recentColorsProvider.notifier).push(i);
      }
      final recents = container.read(recentColorsProvider);
      expect(recents.length, RecentColorsNotifier.maxRecents);
      // The most-recently-pushed index is at the head.
      expect(
        recents.first,
        RecentColorsNotifier.maxRecents + 3,
        reason: 'head should be the newest pushed value',
      );
    });

    test('push silently rejects out-of-range palette indices', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(recentColorsProvider.notifier).push(-1);
      container.read(recentColorsProvider.notifier).push(64);
      container.read(recentColorsProvider.notifier).push(9999);
      expect(container.read(recentColorsProvider), isEmpty);
    });
  });

  group('SelectedColorNotifier.select → recents fan-out', () {
    test('select pushes the chosen index into recentColorsProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Touch both providers so they're materialised.
      container.read(selectedColorProvider);
      container.read(recentColorsProvider);

      container.read(selectedColorProvider.notifier).select(11);
      container.read(selectedColorProvider.notifier).select(25);

      expect(container.read(selectedColorProvider), 25);
      expect(container.read(recentColorsProvider), [25, 11]);
    });

    test('select with an out-of-range index does NOT push to recents (the '
        'invalid input is rejected upstream)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(recentColorsProvider);

      container.read(selectedColorProvider.notifier).select(999);

      expect(container.read(recentColorsProvider), isEmpty);
    });
  });
}
