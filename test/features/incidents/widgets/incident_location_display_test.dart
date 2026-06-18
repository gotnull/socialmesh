// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/incidents/models/incident_mode_models.dart';
import 'package:socialmesh/features/incidents/widgets/help_mode/incident_location_display.dart';

void main() {
  IncidentLocation loc(DateTime fixedAt, {double? accuracy}) =>
      IncidentLocation(
        incidentId: 1,
        nodeId: 2,
        latitude: 0,
        longitude: 0,
        accuracyMeters: accuracy,
        fixedAt: fixedAt,
      );

  group('formatIncidentAge', () {
    test('seconds / minutes / hours / days', () {
      expect(formatIncidentAge(const Duration(seconds: 5)), '5s');
      expect(formatIncidentAge(const Duration(minutes: 3)), '3 min');
      expect(formatIncidentAge(const Duration(hours: 2)), '2 h');
      expect(formatIncidentAge(const Duration(days: 4)), '4 d');
    });

    test('negative durations clamp to 0s', () {
      expect(formatIncidentAge(const Duration(seconds: -10)), '0s');
    });
  });

  group('classifyLocationFreshness', () {
    final now = DateTime.utc(2026, 6, 17, 12);
    test('null -> none', () {
      expect(
        classifyLocationFreshness(null, now: now),
        IncidentLocationFreshness.none,
      );
    });
    test('within fresh window -> fresh', () {
      expect(
        classifyLocationFreshness(
          loc(now.subtract(const Duration(seconds: 30))),
          now: now,
        ),
        IncidentLocationFreshness.fresh,
      );
    });
    test('between fresh and stale -> aging', () {
      expect(
        classifyLocationFreshness(
          loc(now.subtract(const Duration(minutes: 5))),
          now: now,
        ),
        IncidentLocationFreshness.aging,
      );
    });
    test('beyond stale window -> stale', () {
      expect(
        classifyLocationFreshness(
          loc(now.subtract(const Duration(minutes: 30))),
          now: now,
        ),
        IncidentLocationFreshness.stale,
      );
    });
  });

  group('roundedAccuracyMeters', () {
    test('null / NaN / negative -> null', () {
      expect(roundedAccuracyMeters(null), isNull);
      expect(roundedAccuracyMeters(double.nan), isNull);
      expect(roundedAccuracyMeters(-3), isNull);
    });
    test('rounds to whole metres', () {
      expect(roundedAccuracyMeters(12.4), 12);
      expect(roundedAccuracyMeters(12.6), 13);
    });
  });
}
