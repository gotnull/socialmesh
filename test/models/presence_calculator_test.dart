// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/presence_confidence.dart';

void main() {
  test(
    'PresenceCalculator.fromLastHeard returns expected confidence levels',
    () {
      final now = DateTime.now();

      // Null lastHeard => unknown
      expect(
        PresenceCalculator.fromLastHeard(null, now: now),
        PresenceConfidence.unknown,
      );

      // Within active window
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        PresenceConfidence.active,
      );

      // Within fading window
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(minutes: 3)),
          now: now,
        ),
        PresenceConfidence.fading,
      );

      // Within stale window
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(minutes: 30)),
          now: now,
        ),
        PresenceConfidence.stale,
      );

      // Older than stale window => unknown
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(hours: 2)),
          now: now,
        ),
        PresenceConfidence.unknown,
      );
    },
  );

  group('PresenceCalculator.isOnline (2-hour Meshtastic online window)', () {
    test('null lastHeard is not online', () {
      expect(PresenceCalculator.isOnline(null, now: DateTime.now()), isFalse);
    });

    test('heard just now is online', () {
      final now = DateTime.now();
      expect(PresenceCalculator.isOnline(now, now: now), isTrue);
    });

    test('heard 1 minute ago is online', () {
      final now = DateTime.now();
      expect(
        PresenceCalculator.isOnline(
          now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        isTrue,
      );
    });

    test('heard 30 minutes ago is online', () {
      final now = DateTime.now();
      expect(
        PresenceCalculator.isOnline(
          now.subtract(const Duration(minutes: 30)),
          now: now,
        ),
        isTrue,
      );
    });

    test('heard 90 minutes ago is online', () {
      final now = DateTime.now();
      expect(
        PresenceCalculator.isOnline(
          now.subtract(const Duration(minutes: 90)),
          now: now,
        ),
        isTrue,
      );
    });

    test('heard exactly 2 hours ago is online (boundary)', () {
      final now = DateTime.now();
      expect(
        PresenceCalculator.isOnline(
          now.subtract(const Duration(hours: 2)),
          now: now,
        ),
        isTrue,
      );
    });

    test('heard 2 hours and 1 second ago is not online', () {
      final now = DateTime.now();
      expect(
        PresenceCalculator.isOnline(
          now.subtract(const Duration(hours: 2, seconds: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('heard 5 hours ago is not online', () {
      final now = DateTime.now();
      expect(
        PresenceCalculator.isOnline(
          now.subtract(const Duration(hours: 5)),
          now: now,
        ),
        isFalse,
      );
    });

    test('heard 3 days ago is not online', () {
      final now = DateTime.now();
      expect(
        PresenceCalculator.isOnline(
          now.subtract(const Duration(days: 3)),
          now: now,
        ),
        isFalse,
      );
    });
  });

  test('onlineWindow matches Meshtastic firmware default of 2 hours', () {
    expect(PresenceThresholds.onlineWindow, const Duration(hours: 2));
  });
}
