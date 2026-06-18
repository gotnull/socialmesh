// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pure helpers for displaying incident location age, freshness and accuracy.
///
/// No Flutter dependency, no raw-coordinate formatting, and null-safe by
/// design. Precise location is not transmitted (see [HelpLocationPolicy]); these
/// helpers format whatever location a projection happens to hold locally (e.g.
/// from a trusted fixture/test event) without ever exposing raw coordinates.
library;

import '../../models/incident_mode_models.dart';

/// Freshness classification for a (possibly absent) location sample.
enum IncidentLocationFreshness { none, fresh, aging, stale }

/// Coarse, metric-friendly age string (e.g. "2 min", "1 h", "3 d").
String formatIncidentAge(Duration age) {
  if (age.isNegative) return '0s';
  if (age.inSeconds < 60) return '${age.inSeconds}s';
  if (age.inMinutes < 60) return '${age.inMinutes} min';
  if (age.inHours < 24) return '${age.inHours} h';
  return '${age.inDays} d';
}

/// Classifies how fresh [loc] is relative to [now]. Null location -> [none].
IncidentLocationFreshness classifyLocationFreshness(
  IncidentLocation? loc, {
  required DateTime now,
  Duration freshWithin = const Duration(minutes: 2),
  Duration staleAfter = const Duration(minutes: 10),
}) {
  if (loc == null) return IncidentLocationFreshness.none;
  final age = now.difference(loc.fixedAt);
  if (age <= freshWithin) return IncidentLocationFreshness.fresh;
  if (age < staleAfter) return IncidentLocationFreshness.aging;
  return IncidentLocationFreshness.stale;
}

/// Rounds an accuracy in metres to a whole number for display, or null when
/// unknown / non-finite / negative.
int? roundedAccuracyMeters(double? accuracyMeters) {
  if (accuracyMeters == null ||
      !accuracyMeters.isFinite ||
      accuracyMeters < 0) {
    return null;
  }
  return accuracyMeters.round();
}
