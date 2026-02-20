// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/tak/models/tak_event.dart';
import 'package:socialmesh/features/tak/providers/tak_navigation_provider.dart';

TakEvent _targetEvent({double speed = 0, double? course}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return TakEvent(
    uid: 'TARGET-1',
    type: 'a-f-G-U-C',
    callsign: 'Alpha',
    lat: 38.0,
    lon: -122.0,
    timeUtcMs: now - 5000,
    staleUtcMs: now + 300000,
    receivedUtcMs: now,
    speed: speed,
    course: course,
  );
}

void main() {
  group('TakNavigationState.formattedEta', () {
    test('returns null when distance is null', () {
      final state = TakNavigationState(
        target: _targetEvent(speed: 10, course: 180),
        bearingDegrees: 0,
        distanceKm: null,
      );
      expect(state.formattedEta, isNull);
    });

    test('returns null when distance is zero', () {
      final state = TakNavigationState(
        target: _targetEvent(speed: 10, course: 180),
        bearingDegrees: 0,
        distanceKm: 0,
      );
      expect(state.formattedEta, isNull);
    });

    test('returns null when target speed is null', () {
      final state = TakNavigationState(
        target: _targetEvent(),
        bearingDegrees: 0,
        distanceKm: 10,
      );
      expect(state.formattedEta, isNull);
    });

    test('returns null when target speed is zero', () {
      final state = TakNavigationState(
        target: _targetEvent(speed: 0, course: 180),
        bearingDegrees: 0,
        distanceKm: 10,
      );
      expect(state.formattedEta, isNull);
    });

    test('returns null when course is null', () {
      final state = TakNavigationState(
        target: _targetEvent(speed: 10),
        bearingDegrees: 0,
        distanceKm: 10,
      );
      expect(state.formattedEta, isNull);
    });

    test('returns null when bearing is null', () {
      final state = TakNavigationState(
        target: _targetEvent(speed: 10, course: 180),
        distanceKm: 10,
      );
      expect(state.formattedEta, isNull);
    });

    test('returns null when target moving away (>= 90° off)', () {
      // Bearing to target is 0° (target is north of user).
      // Reverse bearing is 180° (user is south of target).
      // Target course is 0° (moving further north, away from user).
      // Diff = |0 - 180| = 180° >= 90°, so no ETA.
      final state = TakNavigationState(
        target: _targetEvent(speed: 10, course: 0),
        bearingDegrees: 0,
        distanceKm: 10,
      );
      expect(state.formattedEta, isNull);
    });

    test('returns ETA when target approaching head-on', () {
      // Bearing to target is 0° (target is north of user).
      // Reverse bearing is 180° (user is south of target).
      // Target course is 180° (heading south toward user).
      // Diff = |180 - 180| = 0°, cos(0) = 1.0, full closing speed.
      // Speed: 10 m/s = 36 km/h. Distance: 10 km.
      // ETA: 10/36 hours = ~16.7 min → "17 min"
      final state = TakNavigationState(
        target: _targetEvent(speed: 10, course: 180),
        bearingDegrees: 0,
        distanceKm: 10,
      );
      expect(state.formattedEta, '17 min');
    });

    test('returns < 1 min for very short ETA', () {
      // 10 m/s heading straight at user, 0.005 km (5m) away.
      // ETA = 0.005 / 36 hours = 0.5 seconds → rounds to 0 min → "< 1 min"
      final state = TakNavigationState(
        target: _targetEvent(speed: 10, course: 180),
        bearingDegrees: 0,
        distanceKm: 0.005,
      );
      expect(state.formattedEta, '< 1 min');
    });

    test('formats hours and minutes for long ETA', () {
      // 5 m/s = 18 km/h heading straight at user, 50 km away.
      // ETA = 50/18 = 2.78 hours → 167 min → "2h 47m"
      final state = TakNavigationState(
        target: _targetEvent(speed: 5, course: 180),
        bearingDegrees: 0,
        distanceKm: 50,
      );
      expect(state.formattedEta, '2h 47m');
    });

    test('returns null for exactly 90° offset (perpendicular)', () {
      // Bearing to target is 0°, reverse is 180°.
      // Target course is 90° (heading east). Diff = |90 - 180| = 90°.
      // 90° is the boundary — >= 90° means no ETA.
      final state = TakNavigationState(
        target: _targetEvent(speed: 10, course: 90),
        bearingDegrees: 0,
        distanceKm: 10,
      );
      expect(state.formattedEta, isNull);
    });

    test('returns ETA for slight approach angle (< 90°)', () {
      // Bearing to target is 0°, reverse is 180°.
      // Target course is 91° → diff = |91 - 180| = 89° < 90°.
      // cos(89°) ≈ 0.0175. Closing speed = 10*3.6*0.0175 ≈ 0.63 km/h.
      // ETA = 10 / 0.63 ≈ 15.9 hours → 952 min → "15h 52m"
      final state = TakNavigationState(
        target: _targetEvent(speed: 10, course: 91),
        bearingDegrees: 0,
        distanceKm: 10,
      );
      final eta = state.formattedEta;
      expect(eta, isNotNull);
      // Should contain 'h' since it's a multi-hour ETA.
      expect(eta, contains('h'));
    });
  });

  group('TakNavigationState.formattedBearing', () {
    test('returns null when bearing is null', () {
      final state = TakNavigationState(target: _targetEvent());
      expect(state.formattedBearing, isNull);
    });

    test('formats zero degrees as 000° N', () {
      final state = TakNavigationState(
        target: _targetEvent(),
        bearingDegrees: 0,
        distanceKm: 1,
      );
      expect(state.formattedBearing, '000\u00B0 N');
    });

    test('formats 45° as 045° NE', () {
      final state = TakNavigationState(
        target: _targetEvent(),
        bearingDegrees: 45,
        distanceKm: 1,
      );
      expect(state.formattedBearing, '045\u00B0 NE');
    });

    test('formats 180° as 180° S', () {
      final state = TakNavigationState(
        target: _targetEvent(),
        bearingDegrees: 180,
        distanceKm: 1,
      );
      expect(state.formattedBearing, '180\u00B0 S');
    });
  });

  group('TakNavigationState.formattedDistance', () {
    test('returns null when distance is null', () {
      final state = TakNavigationState(target: _targetEvent());
      expect(state.formattedDistance, isNull);
    });

    test('formats sub-km distance in meters', () {
      final state = TakNavigationState(target: _targetEvent(), distanceKm: 0.5);
      expect(state.formattedDistance, '500 m');
    });

    test('formats km distance with one decimal', () {
      final state = TakNavigationState(
        target: _targetEvent(),
        distanceKm: 12.34,
      );
      expect(state.formattedDistance, '12.3 km');
    });
  });

  group('TakNavigationState.targetSpeedText', () {
    test('returns stationary when speed is null', () {
      final state = TakNavigationState(target: _targetEvent());
      expect(state.targetSpeedText, 'Target stationary');
    });

    test('returns stationary when speed is 0', () {
      final state = TakNavigationState(target: _targetEvent(speed: 0));
      expect(state.targetSpeedText, 'Target stationary');
    });

    test('includes direction when course is available', () {
      final state = TakNavigationState(
        target: _targetEvent(speed: 10, course: 45),
      );
      expect(state.targetSpeedText, contains('NE'));
      expect(state.targetSpeedText, contains('36.0'));
    });

    test('omits direction when course is null', () {
      final state = TakNavigationState(target: _targetEvent(speed: 10));
      expect(state.targetSpeedText, contains('36.0'));
      expect(state.targetSpeedText, isNot(contains('NE')));
    });
  });
}
