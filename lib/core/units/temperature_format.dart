// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../l10n/app_localizations.dart';
import 'distance_format.dart';

// Re-export so callers can obtain both the units enum and the temperature
// formatter from a single import.
export 'distance_format.dart' show MeasurementUnits;

// Centralized temperature formatting that honours the device's display-units
// preference (Meshtastic DisplayConfig.units). Telemetry temperatures are
// stored and transported in Celsius; this converts to Fahrenheit for display
// when the user selects Imperial. Every user-facing temperature readout must
// route through here so the Imperial setting is reflected app-wide. Webhook
// payloads, debug logs, and threshold-config inputs deliberately stay Celsius
// (they are data contracts / raw inputs, not localized readouts).

double celsiusToFahrenheit(double celsius) => celsius * 9 / 5 + 32;

// Localized temperature string for a value in Celsius. `fractionDigits`
// matches the precision the surface wants (0 for chart axes, 1 for readouts).
String formatTemperatureCelsius(
  double celsius,
  MeasurementUnits units,
  AppLocalizations l10n, {
  int fractionDigits = 1,
}) {
  if (units == MeasurementUnits.imperial) {
    final fahrenheit = celsiusToFahrenheit(celsius);
    return l10n.unitTemperatureFahrenheit(
      fahrenheit.toStringAsFixed(fractionDigits),
    );
  }
  return l10n.unitTemperatureCelsius(celsius.toStringAsFixed(fractionDigits));
}

// Non-localized variant for surfaces with no AppLocalizations handle (e.g. the
// English-only constellation graph rows). Degree symbols are universal.
String formatTemperatureCelsiusAscii(
  double celsius,
  MeasurementUnits units, {
  int fractionDigits = 1,
}) {
  if (units == MeasurementUnits.imperial) {
    return '${celsiusToFahrenheit(celsius).toStringAsFixed(fractionDigits)}°F';
  }
  return '${celsius.toStringAsFixed(fractionDigits)}°C';
}
