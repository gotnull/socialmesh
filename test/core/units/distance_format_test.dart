// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/units/distance_format.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('formatDistanceMetersAscii — metric', () {
    test('sub-kilometre distances render whole metres', () {
      expect(formatDistanceMetersAscii(0, MeasurementUnits.metric), '0 m');
      expect(formatDistanceMetersAscii(450, MeasurementUnits.metric), '450 m');
      expect(formatDistanceMetersAscii(999, MeasurementUnits.metric), '999 m');
    });

    test('1 km boundary switches to kilometres with one decimal', () {
      expect(
        formatDistanceMetersAscii(1000, MeasurementUnits.metric),
        '1.0 km',
      );
      expect(
        formatDistanceMetersAscii(1234, MeasurementUnits.metric),
        '1.2 km',
      );
    });

    test('100 km and above round to a whole number', () {
      expect(
        formatDistanceMetersAscii(140000, MeasurementUnits.metric),
        '140 km',
      );
    });
  });

  group('formatDistanceMetersAscii — imperial', () {
    test('short distances render whole feet', () {
      // 100 m ≈ 328 ft
      expect(
        formatDistanceMetersAscii(100, MeasurementUnits.imperial),
        '328 ft',
      );
      // Just under the 1000 ft threshold (≈ 304.7 m → 999 ft).
      expect(
        formatDistanceMetersAscii(304, MeasurementUnits.imperial),
        '997 ft',
      );
    });

    test('at or above 1000 ft switches to miles', () {
      // 305 m ≈ 1000.7 ft → miles path: 305 / 1609.344 ≈ 0.2 mi
      expect(
        formatDistanceMetersAscii(305, MeasurementUnits.imperial),
        '0.2 mi',
      );
      // 1609.344 m == 1 mile exactly.
      expect(
        formatDistanceMetersAscii(1609.344, MeasurementUnits.imperial),
        '1.0 mi',
      );
    });

    test('large imperial distances round to whole miles', () {
      // 200 miles.
      expect(
        formatDistanceMetersAscii(1609.344 * 200, MeasurementUnits.imperial),
        '200 mi',
      );
    });
  });

  group('formatDistanceMeters — localized (en)', () {
    test('metric uses localized metre/kilometre symbols', () {
      expect(formatDistanceMeters(450, MeasurementUnits.metric, l10n), '450 m');
      expect(
        formatDistanceMeters(1234, MeasurementUnits.metric, l10n),
        '1.2 km',
      );
    });

    test('imperial uses localized foot/mile symbols', () {
      expect(
        formatDistanceMeters(100, MeasurementUnits.imperial, l10n),
        '328 ft',
      );
      expect(
        formatDistanceMeters(1609.344, MeasurementUnits.imperial, l10n),
        '1.0 mi',
      );
    });
  });

  group('formatDistanceKm', () {
    test('delegates to the metres path after scaling', () {
      expect(formatDistanceKm(0.45, MeasurementUnits.metric, l10n), '450 m');
      expect(formatDistanceKm(1.234, MeasurementUnits.metric, l10n), '1.2 km');
    });
  });
}
