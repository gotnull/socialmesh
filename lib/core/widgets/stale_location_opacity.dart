// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:math' as math;

/// Row 13: age-based opacity curve for map node markers, derived from
/// the time since the node was last heard. Lets the map read at a
/// glance for "who's actually alive right now" without removing stale
/// nodes outright (they stay tappable, just visually de-emphasized).
//
// Curve:
//   - 0-15 min     : opacity 1.0 (fresh)
//   - 15-60 min    : linear fade 1.0 -> 0.5
//   - 60 min - 24h : opacity 0.5 (clearly stale, still readable)
//   - 24h+         : opacity 0.3 (very stale, ghosted)
//   - null age     : opacity 1.0 (no data; render at full opacity rather
//                    than ghosting nodes we have no timestamp for)
//
// Bounds clamped to [_floor, 1.0] so a marker never disappears.
const double _freshUntilMinutes = 15;
const double _fadeEndMinutes = 60;
const double _staleFloorOpacity = 0.5;
const double _veryStaleAfterHours = 24;
const double _veryStaleOpacity = 0.3;
const double _floor = 0.3;

/// Opacity for a marker whose underlying node was last heard at
/// [lastHeard]. Returns 1.0 when [lastHeard] is null (no data) or when
/// [now] is before [lastHeard] (clock skew).
double markerOpacityForLastHeard(DateTime? lastHeard, DateTime now) {
  if (lastHeard == null) return 1.0;
  final age = now.difference(lastHeard);
  return markerOpacityForAge(age);
}

/// Pure age -> opacity curve. Negative durations clamp to 1.0
/// (treated as "just heard").
double markerOpacityForAge(Duration age) {
  final ageMinutes = age.inMilliseconds / 60000.0;
  if (ageMinutes <= 0) return 1.0;
  if (ageMinutes <= _freshUntilMinutes) return 1.0;
  if (ageMinutes <= _fadeEndMinutes) {
    final t =
        (ageMinutes - _freshUntilMinutes) /
        (_fadeEndMinutes - _freshUntilMinutes);
    return math.max(_floor, 1.0 - t * (1.0 - _staleFloorOpacity));
  }
  final ageHours = ageMinutes / 60.0;
  if (ageHours <= _veryStaleAfterHours) return _staleFloorOpacity;
  return _veryStaleOpacity;
}
