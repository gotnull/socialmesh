// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/units/temperature_format.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('celsiusToFahrenheit', () {
    test('converts known reference points', () {
      expect(celsiusToFahrenheit(0), 32);
      expect(celsiusToFahrenheit(100), 212);
      expect(celsiusToFahrenheit(-40), -40); // the crossover point
      expect(celsiusToFahrenheit(37), closeTo(98.6, 0.001));
    });
  });

  group('formatTemperatureCelsius — localized (en)', () {
    test('metric keeps Celsius', () {
      expect(
        formatTemperatureCelsius(21.5, MeasurementUnits.metric, l10n),
        '21.5°C',
      );
    });

    test('imperial converts to Fahrenheit', () {
      expect(
        formatTemperatureCelsius(0, MeasurementUnits.imperial, l10n),
        '32.0°F',
      );
      expect(
        formatTemperatureCelsius(21.5, MeasurementUnits.imperial, l10n),
        '70.7°F',
      );
    });

    test('respects fractionDigits', () {
      expect(
        formatTemperatureCelsius(
          21.5,
          MeasurementUnits.metric,
          l10n,
          fractionDigits: 0,
        ),
        '22°C',
      );
      expect(
        formatTemperatureCelsius(
          0,
          MeasurementUnits.imperial,
          l10n,
          fractionDigits: 0,
        ),
        '32°F',
      );
    });
  });

  group('formatTemperatureCelsiusAscii', () {
    test('metric and imperial use the right degree symbol', () {
      expect(
        formatTemperatureCelsiusAscii(21.5, MeasurementUnits.metric),
        '21.5°C',
      );
      expect(
        formatTemperatureCelsiusAscii(21.5, MeasurementUnits.imperial),
        '70.7°F',
      );
    });

    test('fractionDigits applies before the symbol', () {
      expect(
        formatTemperatureCelsiusAscii(
          21.5,
          MeasurementUnits.metric,
          fractionDigits: 0,
        ),
        '22°C',
      );
    });
  });
}
