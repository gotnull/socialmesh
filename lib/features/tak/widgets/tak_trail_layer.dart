// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/logging.dart';
import '../models/tak_event.dart';
import '../services/tak_database.dart';
import '../utils/cot_affiliation.dart';

/// Builds a [PolylineLayer] with movement trails for tracked TAK entities.
///
/// Each trail is a dotted polyline in the entity's affiliation color at
/// 60 % opacity. Maximum 50 points per trail (most recent).
class TakTrailLayer extends StatelessWidget {
  /// Tracked entities with their position histories.
  final Map<String, TakTrailData> trails;

  const TakTrailLayer({super.key, required this.trails});

  @override
  Widget build(BuildContext context) {
    if (trails.isEmpty) return const SizedBox.shrink();

    final polylines = <Polyline>[];
    for (final entry in trails.entries) {
      final data = entry.value;
      if (data.points.length < 2) continue;

      final color = data.affiliationColor.withValues(alpha: 0.6);
      polylines.add(
        Polyline(
          points: data.points,
          color: color,
          strokeWidth: 2,
          pattern: const StrokePattern.dotted(spacingFactor: 1.5),
        ),
      );
    }

    AppLogging.tak(
      'TakTrailLayer: building trails for ${trails.length} tracked entities',
    );

    return PolylineLayer(polylines: polylines);
  }
}

/// Trail data for a single tracked entity.
class TakTrailData {
  /// LatLng points for the trail polyline (newest first from DB, reversed
  /// for rendering oldest-to-newest).
  final List<LatLng> points;

  /// Affiliation color for the trail line.
  final Color affiliationColor;

  const TakTrailData({required this.points, required this.affiliationColor});

  /// Build trail data from a TakEvent and its position history.
  factory TakTrailData.fromHistory(
    TakEvent event,
    List<PositionHistoryPoint> history,
  ) {
    final affiliation = parseAffiliation(event.type);
    // History is newest-first from DB; reverse for polyline rendering
    final points = history.reversed
        .where((p) => p.lat != 0.0 || p.lon != 0.0)
        .map((p) => LatLng(p.lat, p.lon))
        .toList();

    // Add current position as the trail endpoint
    if (event.lat != 0.0 || event.lon != 0.0) {
      final currentPos = LatLng(event.lat, event.lon);
      if (points.isEmpty || points.last != currentPos) {
        points.add(currentPos);
      }
    }

    return TakTrailData(points: points, affiliationColor: affiliation.color);
  }
}
