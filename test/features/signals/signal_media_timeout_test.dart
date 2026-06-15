// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/signals/widgets/signal_card.dart';

// A signal whose image never finished syncing on the sender (and for which the
// receiver holds no local copy) must not animate "Syncing media" forever. After
// kSignalPendingMediaTimeout the card shows a static "Media unavailable"
// placeholder instead. These tests pin that boundary.
void main() {
  group('signalMediaIsUnavailable', () {
    final created = DateTime.utc(2026, 1, 1, 12, 0, 0);

    test('is false immediately after creation', () {
      expect(signalMediaIsUnavailable(created, created), isFalse);
    });

    test('is false just inside the timeout window', () {
      final now = created.add(
        kSignalPendingMediaTimeout - const Duration(seconds: 1),
      );
      expect(signalMediaIsUnavailable(created, now), isFalse);
    });

    test('is false exactly at the timeout boundary', () {
      final now = created.add(kSignalPendingMediaTimeout);
      expect(signalMediaIsUnavailable(created, now), isFalse);
    });

    test('is true once past the timeout', () {
      final now = created.add(
        kSignalPendingMediaTimeout + const Duration(seconds: 1),
      );
      expect(signalMediaIsUnavailable(created, now), isTrue);
    });
  });
}
