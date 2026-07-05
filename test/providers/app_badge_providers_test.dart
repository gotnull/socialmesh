// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Issue #196 - app icon unread badge. appBadgeCountProvider is the single
// cross-protocol sum pushed to the icon badge when the app backgrounds;
// this pins that it is Meshtastic unread + MeshCore unread and nothing
// else.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/providers/app_badge_providers.dart';
import 'package:socialmesh/providers/app_providers.dart';

void main() {
  ProviderContainer containerWith({
    required int meshtasticUnread,
    required int meshCoreUnread,
  }) {
    final container = ProviderContainer(
      overrides: [
        unreadMessagesCountProvider.overrideWith((ref) => meshtasticUnread),
        meshCoreUnreadCountProvider.overrideWith((ref) => meshCoreUnread),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('appBadgeCountProvider', () {
    test('sums Meshtastic and MeshCore unread counts', () {
      final container = containerWith(meshtasticUnread: 3, meshCoreUnread: 2);
      expect(container.read(appBadgeCountProvider), 5);
    });

    test('is zero when both protocols have no unread', () {
      final container = containerWith(meshtasticUnread: 0, meshCoreUnread: 0);
      expect(container.read(appBadgeCountProvider), 0);
    });

    test('passes through a single-protocol count unchanged', () {
      expect(
        containerWith(
          meshtasticUnread: 4,
          meshCoreUnread: 0,
        ).read(appBadgeCountProvider),
        4,
      );
      expect(
        containerWith(
          meshtasticUnread: 0,
          meshCoreUnread: 6,
        ).read(appBadgeCountProvider),
        6,
      );
    });
  });
}
