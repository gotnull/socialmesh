// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map_config.dart';
import '../../../core/theme.dart';
import '../data/airports.dart';
import '../models/aether_flight.dart';

/// A dark-themed route map showing the flight path from departure to arrival
/// with a great-circle arc, airport markers, and optional live plane position.
///
/// Uses the same CartoDB dark tile layer as the mesh map screens.
/// Non-interactive by default (read-only visualization).
class FlightRouteMap extends StatelessWidget {
  /// Departure airport code (IATA or ICAO).
  final String departure;

  /// Arrival airport code (IATA or ICAO).
  final String arrival;

  /// Optional live position of the aircraft.
  final FlightPosition? livePosition;

  /// Whether the flight is currently in the air.
  final bool isActive;

  /// Height of the map widget.
  final double height;

  const FlightRouteMap({
    super.key,
    required this.departure,
    required this.arrival,
    this.livePosition,
    this.isActive = false,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final depAirport = lookupAirport(departure);
    final arrAirport = lookupAirport(arrival);

    // Need both airports with coordinates to render the map
    if (depAirport == null || arrAirport == null) {
      return const SizedBox.shrink();
    }

    final depLatLng = LatLng(depAirport.latitude, depAirport.longitude);
    final arrLatLng = LatLng(arrAirport.latitude, arrAirport.longitude);

    // Compute the great-circle arc points
    final arcPoints = _greatCircleArc(depLatLng, arrLatLng, segments: 64);

    // Compute bounds to fit the route with padding
    final bounds = _computeBounds(depLatLng, arrLatLng, livePosition);

    // Distance for label
    final distKm = depAirport.distanceToKm(arrAirport);

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.card,
        border: Border.symmetric(horizontal: BorderSide(color: context.border)),
      ),
      child: Stack(
        children: [
          // The map
          FlutterMap(
            options: MapOptions(
              initialCenter: bounds.center,
              initialZoom: _fitZoom(bounds, height),
              minZoom: 1.0,
              maxZoom: 12.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
              backgroundColor: const Color(0xFF1F2633),
            ),
            children: [
              // Dark tile layer (same as mesh map)
              TileLayer(
                urlTemplate: MapTileStyle.dark.url,
                subdomains: MapTileStyle.dark.subdomains,
                userAgentPackageName: MapConfig.userAgentPackageName,
                evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
              ),

              // Route arc line
              PolylineLayer(
                polylines: [
                  // Faint glow line (wider, low opacity)
                  Polyline(
                    points: arcPoints,
                    strokeWidth: 5.0,
                    color:
                        (isActive ? context.accentColor : context.textTertiary)
                            .withValues(alpha: 0.15),
                  ),
                  // Main route line (dashed)
                  Polyline(
                    points: arcPoints,
                    strokeWidth: 2.5,
                    color: isActive
                        ? context.accentColor
                        : context.textTertiary.withValues(alpha: 0.6),
                    pattern: const StrokePattern.dotted(spacingFactor: 1.5),
                  ),
                ],
              ),

              // Airport markers and optional live plane
              MarkerLayer(
                markers: [
                  // Departure airport marker
                  _airportMarker(
                    context,
                    depLatLng,
                    departure,
                    depAirport.city,
                    isActive: isActive,
                    isDeparture: true,
                  ),

                  // Arrival airport marker
                  _airportMarker(
                    context,
                    arrLatLng,
                    arrival,
                    arrAirport.city,
                    isActive: isActive,
                    isDeparture: false,
                  ),

                  // Live plane position
                  if (livePosition != null)
                    _planeMarker(context, livePosition!),
                ],
              ),
            ],
          ),

          // Distance badge (bottom-right corner)
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xCC1F2633),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.border.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                _formatDistance(distKm),
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 11,
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Markers
  // ---------------------------------------------------------------------------

  Marker _airportMarker(
    BuildContext context,
    LatLng point,
    String code,
    String city, {
    required bool isActive,
    required bool isDeparture,
  }) {
    final color = isActive ? context.accentColor : context.textTertiary;

    return Marker(
      point: point,
      width: 80,
      height: 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Airport code label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xE61F2633),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
            ),
            child: Text(
              code,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: AppTheme.fontFamily,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1F2633), width: 1.5),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Marker _planeMarker(BuildContext context, FlightPosition position) {
    final color = context.accentColor;
    // Heading in degrees, 0 = north. Rotate the plane icon accordingly.
    // The flight icon points right by default, so subtract 90.
    final rotationDeg = position.heading - 90;

    return Marker(
      point: LatLng(position.latitude, position.longitude),
      width: 32,
      height: 32,
      child: Transform.rotate(
        angle: rotationDeg * math.pi / 180,
        child: Icon(
          Icons.flight,
          color: color,
          size: 22,
          shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 8)],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Great-circle arc
  // ---------------------------------------------------------------------------

  /// Generate points along the great-circle path between two coordinates.
  /// This gives the natural curved route on a Mercator-projected map.
  static List<LatLng> _greatCircleArc(
    LatLng from,
    LatLng to, {
    int segments = 64,
  }) {
    final lat1 = from.latitudeInRad;
    final lon1 = from.longitudeInRad;
    final lat2 = to.latitudeInRad;
    final lon2 = to.longitudeInRad;

    // Angular distance
    final d = math.acos(
      (math.sin(lat1) * math.sin(lat2) +
              math.cos(lat1) * math.cos(lat2) * math.cos(lon2 - lon1))
          .clamp(-1.0, 1.0),
    );

    if (d < 1e-10) {
      return [from, to];
    }

    final points = <LatLng>[];
    for (var i = 0; i <= segments; i++) {
      final f = i / segments;
      final a = math.sin((1 - f) * d) / math.sin(d);
      final b = math.sin(f * d) / math.sin(d);

      final x =
          a * math.cos(lat1) * math.cos(lon1) +
          b * math.cos(lat2) * math.cos(lon2);
      final y =
          a * math.cos(lat1) * math.sin(lon1) +
          b * math.cos(lat2) * math.sin(lon2);
      final z = a * math.sin(lat1) + b * math.sin(lat2);

      final lat = math.atan2(z, math.sqrt(x * x + y * y));
      final lon = math.atan2(y, x);

      points.add(LatLng(lat * 180 / math.pi, lon * 180 / math.pi));
    }

    return points;
  }

  // ---------------------------------------------------------------------------
  // Bounds and zoom
  // ---------------------------------------------------------------------------

  static LatLngBounds _computeBounds(
    LatLng dep,
    LatLng arr,
    FlightPosition? live,
  ) {
    var minLat = math.min(dep.latitude, arr.latitude);
    var maxLat = math.max(dep.latitude, arr.latitude);
    var minLon = math.min(dep.longitude, arr.longitude);
    var maxLon = math.max(dep.longitude, arr.longitude);

    if (live != null) {
      minLat = math.min(minLat, live.latitude);
      maxLat = math.max(maxLat, live.latitude);
      minLon = math.min(minLon, live.longitude);
      maxLon = math.max(maxLon, live.longitude);
    }

    // Add padding (10% of range, minimum 0.5 degrees)
    final latPad = math.max((maxLat - minLat) * 0.15, 0.5);
    final lonPad = math.max((maxLon - minLon) * 0.15, 0.5);

    return LatLngBounds(
      LatLng(minLat - latPad, minLon - lonPad),
      LatLng(maxLat + latPad, maxLon + lonPad),
    );
  }

  /// Estimate a zoom level that fits the bounds within the given pixel height.
  /// Uses a simple heuristic based on the latitude span.
  static double _fitZoom(LatLngBounds bounds, double viewHeight) {
    final latSpan = bounds.north - bounds.south;
    final lonSpan = bounds.east - bounds.west;
    final span = math.max(latSpan, lonSpan);

    // Rough mapping: 360 degrees = zoom 0, halving span = +1 zoom
    if (span <= 0) return 10.0;
    final zoom = math.log(360.0 / span) / math.ln2;
    // Subtract a bit for padding and aspect ratio
    return (zoom - 0.5).clamp(1.0, 12.0);
  }

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  static String _formatDistance(double km) {
    if (km >= 1000) {
      return '${(km / 1000).toStringAsFixed(1)}k km';
    }
    return '${km.round()} km';
  }
}
