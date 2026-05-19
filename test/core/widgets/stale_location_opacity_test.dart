// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/stale_location_opacity.dart';

void main() {
  group('markerOpacityForAge', () {
    test('0 age renders at full opacity', () {
      expect(markerOpacityForAge(Duration.zero), 1.0);
    });

    test('negative duration (clock skew) clamps to full opacity', () {
      expect(markerOpacityForAge(const Duration(seconds: -5)), 1.0);
    });

    test('within the fresh window (under 15 min) stays at 1.0', () {
      expect(markerOpacityForAge(const Duration(minutes: 1)), 1.0);
      expect(markerOpacityForAge(const Duration(minutes: 14)), 1.0);
      expect(markerOpacityForAge(const Duration(minutes: 15)), 1.0);
    });

    test('linear fade between 15 and 60 minutes', () {
      // Midpoint of the linear fade: 37.5 min = halfway between 15 and 60
      // Expected: halfway between 1.0 and 0.5 = 0.75
      final mid = markerOpacityForAge(const Duration(minutes: 37, seconds: 30));
      expect(mid, closeTo(0.75, 0.001));
      // 30 min = 33% through the fade window -> 1.0 - 0.33*0.5 = ~0.833
      expect(
        markerOpacityForAge(const Duration(minutes: 30)),
        closeTo(0.8333, 0.001),
      );
      // 45 min = 66% through -> ~0.667
      expect(
        markerOpacityForAge(const Duration(minutes: 45)),
        closeTo(0.6667, 0.001),
      );
    });

    test('60 minutes lands exactly on the stale floor', () {
      expect(markerOpacityForAge(const Duration(minutes: 60)), 0.5);
    });

    test('1 hour to 24 hours stays at the 0.5 stale floor', () {
      expect(markerOpacityForAge(const Duration(hours: 2)), 0.5);
      expect(markerOpacityForAge(const Duration(hours: 12)), 0.5);
      expect(markerOpacityForAge(const Duration(hours: 23, minutes: 59)), 0.5);
    });

    test('beyond 24 hours drops to 0.3 very-stale floor', () {
      expect(markerOpacityForAge(const Duration(hours: 24, minutes: 1)), 0.3);
      expect(markerOpacityForAge(const Duration(days: 3)), 0.3);
      expect(markerOpacityForAge(const Duration(days: 30)), 0.3);
    });

    test('never returns less than the very-stale floor', () {
      expect(
        markerOpacityForAge(const Duration(days: 365 * 10)) >= 0.3,
        isTrue,
      );
    });
  });

  group('markerOpacityForLastHeard', () {
    final now = DateTime(2026, 5, 19, 12, 0, 0);

    test('null lastHeard returns full opacity', () {
      expect(markerOpacityForLastHeard(null, now), 1.0);
    });

    test('lastHeard just now returns full opacity', () {
      expect(markerOpacityForLastHeard(now, now), 1.0);
    });

    test('lastHeard 30 minutes ago is in the fade window', () {
      final heard = now.subtract(const Duration(minutes: 30));
      expect(markerOpacityForLastHeard(heard, now), closeTo(0.8333, 0.001));
    });

    test('lastHeard 2 hours ago is at the stale floor', () {
      final heard = now.subtract(const Duration(hours: 2));
      expect(markerOpacityForLastHeard(heard, now), 0.5);
    });

    test('lastHeard 2 days ago is at the very-stale floor', () {
      final heard = now.subtract(const Duration(days: 2));
      expect(markerOpacityForLastHeard(heard, now), 0.3);
    });

    test('future lastHeard (clock skew) clamps to full opacity', () {
      final future = now.add(const Duration(minutes: 5));
      expect(markerOpacityForLastHeard(future, now), 1.0);
    });
  });
}
