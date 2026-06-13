// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../l10n/app_localizations.dart';

// Centralized distance formatting that honours the device's display-units
// preference (Meshtastic DisplayConfig.units). Every node/map/NodeDex/AR
// distance string must route through here so toggling Imperial in Display
// Settings is reflected app-wide. There is exactly one rounding/threshold
// policy on purpose: do not re-implement distance formatting at callsites.

enum MeasurementUnits { metric, imperial }

const double _feetPerMeter = 3.28084;
const double _metersPerMile = 1609.344;

// One decimal below 100, rounded at or above it, mirroring the legacy
// per-screen formatters (e.g. "1.2 km", "140 km").
String _scaled(double value) =>
    value >= 100 ? value.round().toString() : value.toStringAsFixed(1);

// Resolves a distance in metres to its display value + unit token, applying
// the metric/imperial threshold policy. Returns the numeric portion and a
// selector the localized/ascii wrappers map to a unit symbol.
({String value, _DistanceUnit unit}) _parts(
  double meters,
  MeasurementUnits units,
) {
  if (units == MeasurementUnits.imperial) {
    final feet = meters * _feetPerMeter;
    if (feet < 1000) {
      return (value: feet.round().toString(), unit: _DistanceUnit.feet);
    }
    final miles = meters / _metersPerMile;
    return (value: _scaled(miles), unit: _DistanceUnit.miles);
  }
  if (meters < 1000) {
    return (value: meters.round().toString(), unit: _DistanceUnit.meters);
  }
  return (value: _scaled(meters / 1000), unit: _DistanceUnit.kilometers);
}

enum _DistanceUnit { meters, kilometers, feet, miles }

// Localized distance string for the given metres and units. Use this in
// any widget/service that has an AppLocalizations handle.
String formatDistanceMeters(
  double meters,
  MeasurementUnits units,
  AppLocalizations l10n,
) {
  final parts = _parts(meters, units);
  return switch (parts.unit) {
    _DistanceUnit.meters => l10n.unitDistanceMeters(parts.value),
    _DistanceUnit.kilometers => l10n.unitDistanceKilometers(parts.value),
    _DistanceUnit.feet => l10n.unitDistanceFeet(parts.value),
    _DistanceUnit.miles => l10n.unitDistanceMiles(parts.value),
  };
}

// Convenience wrapper for callers that already hold kilometres.
String formatDistanceKm(
  double km,
  MeasurementUnits units,
  AppLocalizations l10n,
) => formatDistanceMeters(km * 1000, units, l10n);

// Non-localized variant for canvas/painter contexts (AR HUD) that have no
// AppLocalizations handle. Unit symbols (m/km/ft/mi) are internationally
// recognized and match the localized keys' tokens.
String formatDistanceMetersAscii(double meters, MeasurementUnits units) {
  final parts = _parts(meters, units);
  final symbol = switch (parts.unit) {
    _DistanceUnit.meters => 'm',
    _DistanceUnit.kilometers => 'km',
    _DistanceUnit.feet => 'ft',
    _DistanceUnit.miles => 'mi',
  };
  return '${parts.value} $symbol';
}
