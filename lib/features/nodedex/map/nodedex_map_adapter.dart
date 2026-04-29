// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeDex → Map projection layer.
//
// Pure functions that turn NodeDex entries (paired with optional live
// MeshNodes) into renderable map markers. No Riverpod, no Flutter
// widgets — keeps this fast to test and free of UI churn.
//
// Position resolution order:
//   1. The live MeshNode's current latitude/longitude (freshest source).
//   2. The most recent EncounterRecord with non-null coordinates.
// Entries whose neither source yields a finite point are excluded
// silently. Coordinates are never fabricated.

import '../../../models/mesh_models.dart';
import '../models/nodedex_entry.dart';

/// Time window used to filter which NodeDex entries appear on the map.
///
/// Filtering is based on the entry's [NodeDexEntry.lastSeen] (or the
/// resolved position timestamp when the live node is present), so the
/// behaviour matches what NodeDex itself considers "recently seen".
enum NodeDexMapTimeWindow { hour1, hours24, days7, all }

extension NodeDexMapTimeWindowDuration on NodeDexMapTimeWindow {
  Duration? get duration {
    switch (this) {
      case NodeDexMapTimeWindow.hour1:
        return const Duration(hours: 1);
      case NodeDexMapTimeWindow.hours24:
        return const Duration(hours: 24);
      case NodeDexMapTimeWindow.days7:
        return const Duration(days: 7);
      case NodeDexMapTimeWindow.all:
        return null;
    }
  }
}

/// Filter state owned by the map screen.
///
/// Held in a Notifier so providers can react without triggering full
/// map widget rebuilds for unrelated state changes.
class NodeDexMapFilter {
  final NodeDexMapTimeWindow timeWindow;
  final bool favouritesOnly;

  const NodeDexMapFilter({
    this.timeWindow = NodeDexMapTimeWindow.all,
    this.favouritesOnly = false,
  });

  NodeDexMapFilter copyWith({
    NodeDexMapTimeWindow? timeWindow,
    bool? favouritesOnly,
  }) {
    return NodeDexMapFilter(
      timeWindow: timeWindow ?? this.timeWindow,
      favouritesOnly: favouritesOnly ?? this.favouritesOnly,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NodeDexMapFilter &&
          other.timeWindow == timeWindow &&
          other.favouritesOnly == favouritesOnly);

  @override
  int get hashCode => Object.hash(timeWindow, favouritesOnly);
}

/// View-model for a single map marker derived from a NodeDex entry.
///
/// Carries enough metadata for the screen to (a) render the existing
/// MeshNodeMarkerData with proper styling, (b) show a tap-detail
/// bottom sheet without hitting providers again, and (c) classify
/// recent vs. stale visually.
class NodeDexMapMarker {
  final int nodeNum;
  final String? shortName;
  final String? longName;
  final double latitude;
  final double longitude;

  /// Best-known timestamp for the resolved position. Falls back to
  /// the entry's lastSeen when the encounter has no explicit timestamp.
  final DateTime lastHeard;

  final bool isSelf;
  final bool isFavourite;

  /// Distance in metres from the user's node, when known via the
  /// live MeshNode. Null when the live node is unavailable or did
  /// not report a distance.
  final double? distanceMeters;

  /// Cached presence-style classification. Mirrors PresenceConfidence
  /// semantics but is computed from [lastHeard] alone, so it is stable
  /// even when the live MeshNode is missing.
  final NodeDexMapStaleness staleness;

  /// The live MeshNode when present. Used by the screen to hand off
  /// to MeshNodeMarkerData.fromNode for richer rendering. May be null
  /// when the position came from a historical encounter only.
  final MeshNode? liveNode;

  const NodeDexMapMarker({
    required this.nodeNum,
    required this.shortName,
    required this.longName,
    required this.latitude,
    required this.longitude,
    required this.lastHeard,
    required this.isSelf,
    required this.isFavourite,
    required this.distanceMeters,
    required this.staleness,
    required this.liveNode,
  });
}

/// Coarse staleness buckets used for marker styling. Distinct from
/// PresenceConfidence so the map is readable independently of whether
/// the device is currently connected to a radio.
enum NodeDexMapStaleness { recent, fading, stale, unknown }

class NodeDexMapAdapter {
  /// Builds the unfiltered marker list for a set of NodeDex entries.
  ///
  /// [pairs] is the canonical NodeDex source — `nodeDexSortedEntriesProvider`
  /// returns it directly. [now] is injected for deterministic testing.
  /// Entries with no resolvable finite position are excluded silently;
  /// the count of exclusions is returned via [excludedCount] (logged
  /// by the caller).
  static NodeDexMapProjection project({
    required List<(NodeDexEntry, MeshNode?)> pairs,
    required int? myNodeNum,
    required DateTime now,
  }) {
    final markers = <NodeDexMapMarker>[];
    var excludedNoPosition = 0;

    for (final (entry, liveNode) in pairs) {
      final resolved = _resolvePosition(entry, liveNode);
      if (resolved == null) {
        excludedNoPosition++;
        continue;
      }

      final lastHeard = resolved.timestamp;
      final isSelf = myNodeNum != null && entry.nodeNum == myNodeNum;
      final isFavourite = liveNode?.isFavorite ?? false;

      markers.add(
        NodeDexMapMarker(
          nodeNum: entry.nodeNum,
          shortName: liveNode?.shortName ?? entry.lastKnownName,
          longName: liveNode?.longName ?? entry.lastKnownName,
          latitude: resolved.latitude,
          longitude: resolved.longitude,
          lastHeard: lastHeard,
          isSelf: isSelf,
          isFavourite: isFavourite,
          distanceMeters: liveNode?.distance,
          staleness: classifyStaleness(lastHeard, now: now),
          liveNode: liveNode,
        ),
      );
    }

    return NodeDexMapProjection(
      markers: markers,
      excludedNoPosition: excludedNoPosition,
    );
  }

  /// Applies a [NodeDexMapFilter] to a precomputed marker list.
  ///
  /// Self markers are always kept regardless of the time window —
  /// the user's own node is a navigational anchor, not a discovery.
  static List<NodeDexMapMarker> applyFilter({
    required List<NodeDexMapMarker> markers,
    required NodeDexMapFilter filter,
    required DateTime now,
  }) {
    final window = filter.timeWindow.duration;
    return markers
        .where((m) {
          if (m.isSelf) return true;
          if (filter.favouritesOnly && !m.isFavourite) return false;
          if (window != null) {
            final age = now.difference(m.lastHeard);
            if (age.isNegative) return true;
            if (age > window) return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Buckets a node's last-heard timestamp into a coarse staleness
  /// classification. Boundaries match PresenceThresholds (active = 30m,
  /// fading = 6h, stale = 60m beyond fading) but expressed independently
  /// so the map keeps working when no presence data is available.
  static NodeDexMapStaleness classifyStaleness(
    DateTime lastHeard, {
    required DateTime now,
  }) {
    final age = now.difference(lastHeard);
    if (age.isNegative) return NodeDexMapStaleness.recent;
    if (age <= const Duration(hours: 1)) return NodeDexMapStaleness.recent;
    if (age <= const Duration(hours: 24)) return NodeDexMapStaleness.fading;
    if (age <= const Duration(days: 7)) return NodeDexMapStaleness.stale;
    return NodeDexMapStaleness.unknown;
  }

  static _ResolvedPosition? _resolvePosition(
    NodeDexEntry entry,
    MeshNode? liveNode,
  ) {
    final livePoint = _liveNodePosition(liveNode);
    if (livePoint != null) return livePoint;
    return _latestEncounterPosition(entry);
  }

  static _ResolvedPosition? _liveNodePosition(MeshNode? node) {
    if (node == null) return null;
    final lat = node.latitude;
    final lon = node.longitude;
    if (!_isFiniteLatLon(lat, lon)) return null;
    final ts = node.positionTimestamp ?? node.lastHeard;
    if (ts == null) return null;
    return _ResolvedPosition(lat!, lon!, ts);
  }

  static _ResolvedPosition? _latestEncounterPosition(NodeDexEntry entry) {
    for (var i = entry.encounters.length - 1; i >= 0; i--) {
      final e = entry.encounters[i];
      if (_isFiniteLatLon(e.latitude, e.longitude)) {
        return _ResolvedPosition(e.latitude!, e.longitude!, e.timestamp);
      }
    }
    return null;
  }

  static bool _isFiniteLatLon(double? lat, double? lon) {
    if (lat == null || lon == null) return false;
    if (!lat.isFinite || !lon.isFinite) return false;
    if (lat == 0.0 && lon == 0.0) return false;
    if (lat.abs() > 90.0 || lon.abs() > 180.0) return false;
    return true;
  }
}

/// Adapter output bundle — markers plus exclusion count for logging.
class NodeDexMapProjection {
  final List<NodeDexMapMarker> markers;
  final int excludedNoPosition;

  const NodeDexMapProjection({
    required this.markers,
    required this.excludedNoPosition,
  });
}

class _ResolvedPosition {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const _ResolvedPosition(this.latitude, this.longitude, this.timestamp);
}
