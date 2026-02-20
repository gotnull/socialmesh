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
///
/// This is a [StatefulWidget] that caches the built marker list and the
/// event-by-UID index between rebuilds. The expensive marker creation and
/// clustering setup only runs when the input data actually changes — not on
/// every parent `setState` that doesn't affect TAK entities.
class TakMapLayer extends StatefulWidget {
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
  State<TakMapLayer> createState() => _TakMapLayerState();
}

class _TakMapLayerState extends State<TakMapLayer> {
  /// Cached marker list from the last [_rebuildMarkers] call.
  List<Marker> _markers = const [];

  /// Cached event-by-UID index for cluster affiliation lookups.
  Map<String, TakEvent> _eventByUid = const {};

  /// Fingerprint of the data that produced [_markers].
  /// When this changes, markers are rebuilt.
  _MarkerFingerprint? _fingerprint;

  @override
  void initState() {
    super.initState();
    _rebuildMarkers();
  }

  @override
  void didUpdateWidget(covariant TakMapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newFingerprint = _MarkerFingerprint.from(
      widget.events,
      widget.trackedUids,
    );

    if (_fingerprint != null && _fingerprint == newFingerprint) {
      // Data is unchanged — skip the expensive marker rebuild.
      return;
    }

    _rebuildMarkers();
  }

  /// Rebuild the marker list and event index from the current widget props.
  void _rebuildMarkers() {
    final eventByUid = <String, TakEvent>{};
    final markers = <Marker>[];

    for (final event in widget.events) {
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
            isTracked: widget.trackedUids.contains(event.uid),
            onTap: widget.onMarkerTap != null
                ? () => widget.onMarkerTap!(event)
                : null,
            onLongPress: widget.onMarkerLongPress != null
                ? () => widget.onMarkerLongPress!(event)
                : null,
          ),
        ),
      );
    }

    _markers = markers;
    _eventByUid = eventByUid;
    _fingerprint = _MarkerFingerprint.from(widget.events, widget.trackedUids);

    AppLogging.tak(
      'TakMapLayer build: ${markers.length} markers, '
      'clustering=${markers.length > _clusterThreshold}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_markers.length > _clusterThreshold) {
      return MarkerClusterLayerWidget(
        options: MarkerClusterLayerOptions(
          maxClusterRadius: 80,
          size: const Size(48, 48),
          padding: const EdgeInsets.all(50),
          markers: _markers,
          popupOptions: PopupOptions(
            popupBuilder: (_, _) => const SizedBox.shrink(),
          ),
          builder: (context, clusterMarkers) =>
              _buildCluster(clusterMarkers, _eventByUid),
        ),
      );
    }

    return MarkerLayer(rotate: true, markers: _markers);
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

/// Lightweight fingerprint of the data that drives [TakMapLayer] markers.
///
/// Compared in [_TakMapLayerState.didUpdateWidget] to decide whether the
/// expensive marker list needs to be rebuilt. The fingerprint captures:
///
/// - Number of events
/// - A hash combining each event's identity key fields AND mutable display
///   fields (position, callsign, motion data, stale time) so that any
///   content change triggers a rebuild.
/// - The set of tracked UIDs (which changes marker appearance).
class _MarkerFingerprint {
  final int eventCount;
  final int contentHash;
  final int trackedHash;

  const _MarkerFingerprint({
    required this.eventCount,
    required this.contentHash,
    required this.trackedHash,
  });

  factory _MarkerFingerprint.from(
    List<TakEvent> events,
    Set<String> trackedUids,
  ) {
    // Build a combined hash of all event content that affects marker display.
    // Using Jenkins-style hash accumulation via Object.hash chains.
    var hash = 0;
    for (final e in events) {
      hash = Object.hash(
        hash,
        e.uid,
        e.type,
        e.lat,
        e.lon,
        e.callsign,
        e.staleUtcMs,
        e.speed,
        e.course,
        e.hae,
      );
    }

    return _MarkerFingerprint(
      eventCount: events.length,
      contentHash: hash,
      trackedHash: Object.hashAll(trackedUids.toList()..sort()),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MarkerFingerprint &&
          eventCount == other.eventCount &&
          contentHash == other.contentHash &&
          trackedHash == other.trackedHash;

  @override
  int get hashCode => Object.hash(eventCount, contentHash, trackedHash);
}
