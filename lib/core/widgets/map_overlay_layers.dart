// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../node_color.dart';
import '../theme.dart';
import '../../models/telemetry_log.dart';
import 'mesh_map_widget.dart';

// Shared builders for the passive map overlay layers (range circles,
// connection lines, distance labels, position-history trails). The main map
// screen and the route detail screen both render these on top of the same
// tile + node-marker base, so the geometry lives here once and each screen
// keeps only its own caching / settings wiring. Every function is pure: it
// reads node geometry from [MeshNodeMarkerData] and theme colours from the
// passed [BuildContext], and returns a fresh layer-content list.

/// Conservative spherical (haversine) distance in km.
///
/// Top-level so tests can pin the prefilter's correctness contract without
/// spinning up the full map.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  const degToRad = math.pi / 180.0;
  final dLat = (lat2 - lat1) * degToRad;
  final dLng = (lng2 - lng1) * degToRad;
  final sinHalfLat = math.sin(dLat / 2);
  final sinHalfLng = math.sin(dLng / 2);
  final a =
      sinHalfLat * sinHalfLat +
      math.cos(lat1 * degToRad) *
          math.cos(lat2 * degToRad) *
          sinHalfLng *
          sinHalfLng;
  return 2 * earthRadiusKm * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Cheap conservative screen for the connection-lines pair loop.
///
/// Returns false ONLY when the production decision function provably rejects
/// the pair. That decision is `Distance().as(Kilometer, ...)`, which ROUNDS to
/// whole kilometers, so a pair up to maxDistanceKm + 0.5 of true distance still
/// renders a line. The screen therefore widens the threshold by the rounding
/// half-step plus a 1% margin for the haversine-vs-Vincenty (Earth flattening)
/// difference; the latitude screen uses the same widened bound (one degree of
/// latitude is never less than ~110.567 km).
bool connectionPrefilterMayBeWithin(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
  double maxDistanceKm,
) {
  const minKmPerDegLat = 110.567;
  final screenKm = (maxDistanceKm + 0.5) * 1.01;
  if ((lat2 - lat1).abs() * minKmPerDegLat > screenKm) return false;
  return haversineKm(lat1, lng1, lat2, lng2) <= screenKm;
}

// Vincenty distance in km, matching the map's pairwise decision function.
// latlong2's Distance() rounds to whole kilometers, which is the value the
// connection-line threshold compares against. Throws on identical /
// near-antipodal points, so guard both.
double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
  if (lat1 == lat2 && lng1 == lng2) return 0.0;
  try {
    return const Distance().as(
      LengthUnit.Kilometer,
      LatLng(lat1, lng1),
      LatLng(lat2, lng2),
    );
  } catch (_) {
    return 0.0;
  }
}

// Reduce a list of points to at most [maxPoints] by evenly sampling, always
// keeping the first and last point for continuity.
List<LatLng> _downsamplePoints(List<LatLng> points, {int maxPoints = 200}) {
  if (points.length <= maxPoints) return points;
  final result = <LatLng>[points.first];
  final step = (points.length - 1) / (maxPoints - 1);
  for (int i = 1; i < maxPoints - 1; i++) {
    result.add(points[(i * step).round()]);
  }
  result.add(points.last);
  return result;
}

/// Theoretical 5km coverage circles, one per node. Own node uses the app
/// accent; peers use the nodeNum-derived identity colour (no avatar override,
/// so the result is a pure function of geometry + accent).
List<CircleMarker> rangeCircleMarkers(
  BuildContext context, {
  required List<MeshNodeMarkerData> nodes,
  int? myNodeNum,
}) {
  final accent = context.accentColor;
  return nodes
      .where((n) => n.latitude.isFinite && n.longitude.isFinite)
      .map((n) {
        final isMyNode = n.node.nodeNum == myNodeNum;
        final circleColor = isMyNode ? accent : nodeColorFromId(n.node.nodeNum);
        return CircleMarker(
          point: LatLng(n.latitude, n.longitude),
          radius: 5000,
          useRadiusInMeter: true,
          color: circleColor.withValues(alpha: 0.08),
          borderColor: circleColor.withValues(alpha: 0.2),
          borderStrokeWidth: 1,
        );
      })
      .toList(growable: false);
}

/// Connection lines between nodes within [maxDistanceKm]. Lines touching the
/// own node use the accent; peer-to-peer links use purple. Stale endpoints fade
/// the line and widen the dot spacing.
List<Polyline> connectionLinePolylines(
  BuildContext context, {
  required List<MeshNodeMarkerData> nodes,
  int? myNodeNum,
  required double maxDistanceKm,
}) {
  final accent = context.accentColor;
  final lines = <Polyline>[];

  for (int i = 0; i < nodes.length; i++) {
    for (int j = i + 1; j < nodes.length; j++) {
      final node1 = nodes[i];
      final node2 = nodes[j];

      // Cheap conservative prefilter; Vincenty stays the sole decision
      // function for pairs that pass, so the emitted line set is identical to
      // the unfiltered loop.
      if (!connectionPrefilterMayBeWithin(
        node1.latitude,
        node1.longitude,
        node2.latitude,
        node2.longitude,
        maxDistanceKm,
      )) {
        continue;
      }

      final distance = _distanceKm(
        node1.latitude,
        node1.longitude,
        node2.latitude,
        node2.longitude,
      );
      if (distance > maxDistanceKm) continue;

      final isMyConnection =
          node1.node.nodeNum == myNodeNum || node2.node.nodeNum == myNodeNum;
      final hasStaleNode = node1.isStale || node2.isStale;
      final pattern = hasStaleNode
          ? const StrokePattern.dotted(spacingFactor: 3.0)
          : const StrokePattern.dotted(spacingFactor: 1.5);

      lines.add(
        Polyline(
          points: [
            LatLng(node1.latitude, node1.longitude),
            LatLng(node2.latitude, node2.longitude),
          ],
          color: isMyConnection
              ? accent.withValues(alpha: hasStaleNode ? 0.25 : 0.5)
              : AppTheme.primaryPurple.withValues(
                  alpha: hasStaleNode ? 0.2 : 0.35,
                ),
          strokeWidth: isMyConnection ? 2.0 : 1.5,
          pattern: pattern,
        ),
      );
    }
  }

  return lines;
}

/// Distance-label pills at the midpoint between the own node and each peer
/// within 15km. Empty unless the own node is present and the map is zoomed in
/// ([zoomedIn], the `currentZoom >= 10` gate). [formatDistance] supplies the
/// caller's unit-aware text so this stays free of units / l10n.
List<Marker> distanceLabelMarkers(
  BuildContext context, {
  required List<MeshNodeMarkerData> nodes,
  int? myNodeNum,
  required bool zoomedIn,
  required String Function(double km) formatDistance,
}) {
  if (myNodeNum == null || !zoomedIn) return [];

  final myNode = nodes.where((n) => n.node.nodeNum == myNodeNum).firstOrNull;
  if (myNode == null) return [];

  final accent = context.accentColor;
  final cardColor = context.card;
  final labels = <Marker>[];
  const maxDistanceKm = 15.0;

  for (final node in nodes) {
    if (node.node.nodeNum == myNodeNum) continue;

    final distance = _distanceKm(
      myNode.latitude,
      myNode.longitude,
      node.latitude,
      node.longitude,
    );
    if (distance > maxDistanceKm) continue;

    final midLat = (myNode.latitude + node.latitude) / 2;
    final midLng = (myNode.longitude + node.longitude) / 2;

    labels.add(
      Marker(
        point: LatLng(midLat, midLng),
        width: 60,
        height: 20,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: cardColor.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppTheme.radius10),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Text(
            formatDistance(distance),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  return labels;
}

/// Movement trails built from persisted [positionLogs], one dotted polyline per
/// node with at least two logged positions. Own node uses the accent; peers use
/// their identity colour (avatar override wins). Long histories are downsampled
/// to keep the dotted pattern from stuttering the GPU.
List<Polyline> positionHistoryTrailPolylines(
  BuildContext context, {
  required List<MeshNodeMarkerData> nodes,
  int? myNodeNum,
  required List<PositionLog> positionLogs,
}) {
  if (positionLogs.isEmpty) return const [];

  final accent = context.accentColor;
  final trails = <Polyline>[];

  final logsByNode = <int, List<PositionLog>>{};
  for (final log in positionLogs) {
    logsByNode.putIfAbsent(log.nodeNum, () => []).add(log);
  }

  for (final entry in logsByNode.entries) {
    final nodeNum = entry.key;
    final logs = entry.value;
    if (logs.length < 2) continue;

    logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final points = _downsamplePoints(
      logs.map((l) => LatLng(l.latitude, l.longitude)).toList(),
      maxPoints: 200,
    );
    if (points.length < 2) continue;

    final matchingNode = nodes
        .where((n) => n.node.nodeNum == nodeNum)
        .firstOrNull;
    final isMyNode = nodeNum == myNodeNum;
    final color = isMyNode
        ? accent
        : resolveNodeColor(
            nodeNum: nodeNum,
            avatarColor: matchingNode?.node.avatarColor,
          );

    trails.add(
      Polyline(
        points: points,
        color: color.withValues(alpha: 0.6),
        strokeWidth: 3,
        pattern: const StrokePattern.dotted(spacingFactor: 1.5),
      ),
    );
  }

  return trails;
}
