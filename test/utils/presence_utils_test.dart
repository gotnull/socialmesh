// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/l10n/l10n_utils.dart';
import 'package:socialmesh/models/presence_confidence.dart';
import 'package:socialmesh/utils/presence_utils.dart';

// Pins the user-facing copy contract for the 10-60 minute band
// (PresenceConfidence.stale). The historical label was "Inactive", which
// users read as "offline / dead" even when the node was heard only
// minutes ago. The new label is "Quiet" — same threshold, softer word.
//
// Reported via user feedback on v1.40.0 (178): two nodes heard 17 min
// and 46 min before the report anchor were grouped under "Inactive",
// which felt wrong. Thresholds are unchanged; only the rendered word.
void main() {
  setUp(() => setPreferredLocaleOverride(const Locale('en')));
  tearDown(() => setPreferredLocaleOverride(null));

  group('presenceStatusText for PresenceConfidence.stale', () {
    test('17-min-old node renders as "Quiet", never as "Inactive"', () {
      const age = Duration(minutes: 17, seconds: 55);
      final text = presenceStatusText(PresenceConfidence.stale, age);
      expect(text, 'Quiet');
      expect(text, isNot('Inactive'));
    });

    test('46-min-old node renders as "Quiet"', () {
      const age = Duration(minutes: 46, seconds: 55);
      final text = presenceStatusText(PresenceConfidence.stale, age);
      expect(text, 'Quiet');
    });

    test('boundary just past fadingWindow (11 min) renders as "Quiet"', () {
      const age = Duration(minutes: 11);
      final text = presenceStatusText(PresenceConfidence.stale, age);
      expect(text, 'Quiet');
    });

    test(
      'boundary just before staleWindow expiry (59 min) renders as "Quiet"',
      () {
        const age = Duration(minutes: 59);
        final text = presenceStatusText(PresenceConfidence.stale, age);
        expect(text, 'Quiet');
      },
    );
  });

  group(
    'presenceStatusText for other PresenceConfidence values (unchanged)',
    () {
      test('active renders as "Active"', () {
        const age = Duration(minutes: 1);
        expect(presenceStatusText(PresenceConfidence.active, age), 'Active');
      });

      test('fading renders as "Seen Xm ago"', () {
        const age = Duration(minutes: 5);
        expect(
          presenceStatusText(PresenceConfidence.fading, age),
          'Seen 5m ago',
        );
      });

      test('fading with <30s age renders as "Just now"', () {
        const age = Duration(seconds: 20);
        expect(presenceStatusText(PresenceConfidence.fading, age), 'Just now');
      });

      test('unknown renders as "Unknown"', () {
        expect(presenceStatusText(PresenceConfidence.unknown, null), 'Unknown');
      });
    },
  );

  group('PresenceConfidence.stale.label extension', () {
    test('renders as "Quiet" (used by presence_screen.dart filter + card)', () {
      expect(PresenceConfidence.stale.label, 'Quiet');
      expect(PresenceConfidence.stale.label, isNot('Inactive'));
    });

    test('classification thresholds remain pinned (regression guard)', () {
      final now = DateTime.now();
      // 17-min-old is still stale (not fading, not unknown).
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(minutes: 17)),
          now: now,
        ),
        PresenceConfidence.stale,
      );
      // 46-min-old is still stale.
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(minutes: 46)),
          now: now,
        ),
        PresenceConfidence.stale,
      );
    });
  });
}
