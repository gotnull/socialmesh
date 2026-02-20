// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/logging.dart';
import '../models/tak_event.dart';
import '../utils/cot_affiliation.dart';
import 'tak_map_marker.dart';

/// Marker threshold: when the total number of visible TAK entities exceeds
/// this value, the layer enables clustering to keep the map readable.
const _clusterThreshold = 20;

/// Builds a marker layer for TAK entities.
///
/// When the number of visible entities exceeds [_clusterThreshold], the layer
/// uses [MarkerClusterLayerWidget] to group dense markers into circles whose
/// color reflects the majority MIL-STD-2525 affiliation. Below the threshold,
/// a standard [MarkerLayer] is used.
///
/// Selection and popup state are managed by the parent (map screen).
/// Entities at position (0, 0) are skipped with a log warning.
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
    // Index events by UID so the cluster builder can look up affiliations.
    final eventByUid = <String, TakEvent>{};
    final markers = <Marker>[];

    for (final event in events) {
      // Skip entities at (0, 0) — invalid position
      if (event.lat == 0.0 && event.lon == 0.0) {
        AppLogging.tak('Skipping marker for uid=${event.uid}: position is 0,0');
        continue;
      }

      eventByUid[event.uid] = event;

      markers.add(
        Marker(
          key: ValueKey(event.uid),
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

    AppLogging.tak(
      'TakMapLayer build: ${markers.length} markers, '
      'clustering=${markers.length > _clusterThreshold}',
    );

    if (markers.length > _clusterThreshold) {
      return MarkerClusterLayerWidget(
        options: MarkerClusterLayerOptions(
          maxClusterRadius: 80,
          size: const Size(48, 48),
          padding: const EdgeInsets.all(50),
          markers: markers,
          popupOptions: PopupOptions(
            popupBuilder: (_, _) => const SizedBox.shrink(),
          ),
          builder: (context, clusterMarkers) =>
              _buildCluster(clusterMarkers, eventByUid),
        ),
      );
    }

    return MarkerLayer(rotate: true, markers: markers);
  }

  /// Builds a cluster circle coloured by the majority affiliation.
  ///
  /// If all entities share one affiliation, that colour is used. When
  /// affiliations are mixed, a caution-yellow is shown.
  static Widget _buildCluster(
    List<Marker> clusterMarkers,
    Map<String, TakEvent> eventByUid,
  ) {
    final count = clusterMarkers.length;

    // Count affiliations in this cluster.
    final affiliationCounts = <CotAffiliation, int>{};
    for (final m in clusterMarkers) {
      final key = m.key;
      if (key is ValueKey<String>) {
        final event = eventByUid[key.value];
        if (event != null) {
          final aff = parseAffiliation(event.type);
          affiliationCounts[aff] = (affiliationCounts[aff] ?? 0) + 1;
        }
      }
    }

    // Determine cluster colour.
    Color clusterColor;
    if (affiliationCounts.length == 1) {
      clusterColor = affiliationCounts.keys.first.color;
    } else if (affiliationCounts.isNotEmpty) {
      // Multiple affiliations — use majority if > 60 %, else caution yellow.
      final sorted = affiliationCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final majorityRatio = sorted.first.value / count;
      clusterColor = majorityRatio > 0.6
          ? sorted.first.key.color
          : const Color(0xFFFFD600); // caution yellow
    } else {
      clusterColor = const Color(0xFFFFD600);
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            clusterColor.withValues(alpha: 0.9),
            clusterColor.withValues(alpha: 0.5),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: clusterColor.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
