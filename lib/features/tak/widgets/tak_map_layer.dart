// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/logging.dart';
import '../models/tak_event.dart';
import 'tak_map_marker.dart';

/// Builds a [MarkerLayer] containing one marker per TAK entity.
///
/// This widget is stateless — selection and popup state are managed by the
/// parent (map screen). Entities at position (0, 0) are skipped with a
/// log warning.
class TakMapLayer extends StatelessWidget {
  /// Active TAK events to render.
  final List<TakEvent> events;

  /// Set of entity UIDs currently being tracked.
  final Set<String> trackedUids;

  /// Called when a TAK marker is tapped.
  final ValueChanged<TakEvent>? onMarkerTap;

  /// Called when a TAK marker is long-pressed.
  final ValueChanged<TakEvent>? onMarkerLongPress;

  const TakMapLayer({
    super.key,
    required this.events,
    this.trackedUids = const {},
    this.onMarkerTap,
    this.onMarkerLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    for (final event in events) {
      // Skip entities at (0, 0) — invalid position
      if (event.lat == 0.0 && event.lon == 0.0) {
        AppLogging.tak('Skipping marker for uid=${event.uid}: position is 0,0');
        continue;
      }

      markers.add(
        Marker(
          point: LatLng(event.lat, event.lon),
          width: TakMapMarker.labelWidth,
          height: TakMapMarker.totalHeight,
          child: TakMapMarker(
            event: event,
            isTracked: trackedUids.contains(event.uid),
            onTap: onMarkerTap != null ? () => onMarkerTap!(event) : null,
            onLongPress: onMarkerLongPress != null
                ? () => onMarkerLongPress!(event)
                : null,
          ),
        ),
      );
    }

    AppLogging.tak('TakMapLayer build: ${markers.length} markers');

    return MarkerLayer(rotate: true, markers: markers);
  }
}
