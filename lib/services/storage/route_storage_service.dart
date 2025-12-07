import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/route.dart';

/// Storage service for GPS routes
class RouteStorageService {
  static const _routesKey = 'routes';
  static const _activeRouteKey = 'active_route';

  final SharedPreferences _prefs;

  RouteStorageService(this._prefs);

  /// Get all saved routes
  Future<List<Route>> getRoutes() async {
    final jsonList = _prefs.getStringList(_routesKey) ?? [];
    return jsonList.map((json) => Route.fromJson(jsonDecode(json))).toList();
  }

  /// Save a route
  Future<void> saveRoute(Route route) async {
    final routes = await getRoutes();
    final existingIndex = routes.indexWhere((r) => r.id == route.id);
    if (existingIndex >= 0) {
      routes[existingIndex] = route;
    } else {
      routes.add(route);
    }
    await _saveRoutes(routes);
  }

  /// Delete a route
  Future<void> deleteRoute(String routeId) async {
    final routes = await getRoutes();
    routes.removeWhere((r) => r.id == routeId);
    await _saveRoutes(routes);
  }

  Future<void> _saveRoutes(List<Route> routes) async {
    await _prefs.setStringList(
      _routesKey,
      routes.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  /// Get the currently active route being recorded
  Future<Route?> getActiveRoute() async {
    final json = _prefs.getString(_activeRouteKey);
    if (json == null) return null;
    return Route.fromJson(jsonDecode(json));
  }

  /// Set the active route being recorded
  Future<void> setActiveRoute(Route? route) async {
    if (route == null) {
      await _prefs.remove(_activeRouteKey);
    } else {
      await _prefs.setString(_activeRouteKey, jsonEncode(route.toJson()));
    }
  }

  /// Add a location point to the active route
  Future<Route?> addLocationToActiveRoute(RouteLocation location) async {
    final route = await getActiveRoute();
    if (route == null) return null;

    final updatedRoute = route.copyWith(
      locations: [...route.locations, location],
    );
    await setActiveRoute(updatedRoute);
    return updatedRoute;
  }

  /// Export routes as GPX format
  String exportRouteAsGpx(Route route) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="Protofluff">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>${_escapeXml(route.name)}</name>');
    if (route.notes != null) {
      buffer.writeln('    <desc>${_escapeXml(route.notes!)}</desc>');
    }
    buffer.writeln('    <time>${route.createdAt.toIso8601String()}</time>');
    buffer.writeln('  </metadata>');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>${_escapeXml(route.name)}</name>');
    buffer.writeln('    <trkseg>');
    for (final loc in route.locations) {
      buffer.write('      <trkpt lat="${loc.latitude}" lon="${loc.longitude}"');
      if (loc.altitude != null) {
        buffer.write('>');
        buffer.writeln();
        buffer.writeln('        <ele>${loc.altitude}</ele>');
        buffer.writeln(
          '        <time>${loc.timestamp.toIso8601String()}</time>',
        );
        buffer.writeln('      </trkpt>');
      } else {
        buffer.writeln(' />');
      }
    }
    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');
    return buffer.toString();
  }

  /// Import a route from GPX format
  Route? importRouteFromGpx(String gpx) {
    try {
      String? name;
      String? desc;
      final locations = <RouteLocation>[];

      // Parse name from metadata or track
      final nameMatch = RegExp(r'<name>([^<]+)</name>').firstMatch(gpx);
      if (nameMatch != null) {
        name = nameMatch.group(1);
      }

      // Parse description
      final descMatch = RegExp(r'<desc>([^<]+)</desc>').firstMatch(gpx);
      if (descMatch != null) {
        desc = descMatch.group(1);
      }

      // Parse trackpoints - handle both self-closing and full tags
      // Pattern 1: Full tags with children: <trkpt lat="..." lon="...">...</trkpt>
      final fullTrkptRegex = RegExp(
        r'<trkpt\s+lat="([^"]+)"\s+lon="([^"]+)"[^>]*>(.*?)</trkpt>',
        dotAll: true,
      );

      for (final match in fullTrkptRegex.allMatches(gpx)) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lon = double.tryParse(match.group(2) ?? '');
        final content = match.group(3) ?? '';

        // Parse elevation
        final eleMatch = RegExp(r'<ele>([^<]+)</ele>').firstMatch(content);
        final ele = eleMatch != null
            ? double.tryParse(eleMatch.group(1) ?? '')?.toInt()
            : null;

        // Parse time
        final timeMatch = RegExp(r'<time>([^<]+)</time>').firstMatch(content);
        final time = timeMatch?.group(1);

        if (lat != null && lon != null) {
          locations.add(
            RouteLocation(
              latitude: lat,
              longitude: lon,
              altitude: ele,
              timestamp: time != null ? DateTime.tryParse(time) : null,
            ),
          );
        }
      }

      // Pattern 2: Self-closing tags: <trkpt lat="..." lon="..." />
      final selfClosingRegex = RegExp(
        r'<trkpt\s+lat="([^"]+)"\s+lon="([^"]+)"[^/]*/\s*>',
      );

      for (final match in selfClosingRegex.allMatches(gpx)) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lon = double.tryParse(match.group(2) ?? '');

        if (lat != null && lon != null) {
          // Check if this point was already added by full tag regex
          final exists = locations.any(
            (l) => l.latitude == lat && l.longitude == lon,
          );
          if (!exists) {
            locations.add(RouteLocation(latitude: lat, longitude: lon));
          }
        }
      }

      // Also try waypoints (wpt) if no trackpoints found
      if (locations.isEmpty) {
        final wptRegex = RegExp(
          r'<wpt\s+lat="([^"]+)"\s+lon="([^"]+)"[^>]*>(.*?)</wpt>',
          dotAll: true,
        );

        for (final match in wptRegex.allMatches(gpx)) {
          final lat = double.tryParse(match.group(1) ?? '');
          final lon = double.tryParse(match.group(2) ?? '');
          final content = match.group(3) ?? '';

          final eleMatch = RegExp(r'<ele>([^<]+)</ele>').firstMatch(content);
          final ele = eleMatch != null
              ? double.tryParse(eleMatch.group(1) ?? '')?.toInt()
              : null;

          final timeMatch = RegExp(r'<time>([^<]+)</time>').firstMatch(content);
          final time = timeMatch?.group(1);

          if (lat != null && lon != null) {
            locations.add(
              RouteLocation(
                latitude: lat,
                longitude: lon,
                altitude: ele,
                timestamp: time != null ? DateTime.tryParse(time) : null,
              ),
            );
          }
        }
      }

      if (locations.isEmpty) return null;

      return Route(
        name: name ?? 'Imported Route',
        notes: desc,
        locations: locations,
        createdAt: locations.first.timestamp,
        endedAt: locations.last.timestamp,
      );
    } catch (e) {
      return null;
    }
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
