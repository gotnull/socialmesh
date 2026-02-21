// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/route.dart';

/// Storage service for GPS routes using SQLite
class RouteStorageService {
  static const _dbName = 'routes.db';
  static const _routesTable = 'routes';
  static const _activeRouteKey = 'active_route';

  Database? _db;
  final String? _testDbPath;

  /// Constructor with optional test database path
  RouteStorageService({String? testDbPath}) : _testDbPath = testDbPath;

  /// Initialize the SQLite database
  Future<void> init() async {
    if (_db != null) return;

    final String dbPath;
    if (_testDbPath != null) {
      dbPath = _testDbPath;
    } else {
      final documentsDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(documentsDir.path, _dbName);
    }

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    // Routes table
    await db.execute('''
      CREATE TABLE $_routesTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        notes TEXT,
        created_at INTEGER NOT NULL,
        ended_at INTEGER,
        locations TEXT NOT NULL
      )
    ''');

    // Active route table (single row)
    await db.execute('''
      CREATE TABLE $_activeRouteKey (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        route_data TEXT
      )
    ''');
  }

  /// Get all saved routes
  Future<List<Route>> getRoutes() async {
    if (_db == null) await init();

    final List<Map<String, dynamic>> maps = await _db!.query(
      _routesTable,
      orderBy: 'created_at DESC',
    );

    return maps.map((map) {
      return Route(
        id: map['id'] as String,
        name: map['name'] as String,
        notes: map['notes'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['created_at'] as int,
        ),
        endedAt: map['ended_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['ended_at'] as int)
            : null,
        locations: (jsonDecode(map['locations'] as String) as List)
            .map((loc) => RouteLocation.fromJson(loc))
            .toList(),
      );
    }).toList();
  }

  /// Save a route
  Future<void> saveRoute(Route route) async {
    if (_db == null) await init();

    await _db!.insert(_routesTable, {
      'id': route.id,
      'name': route.name,
      'notes': route.notes,
      'created_at': route.createdAt.millisecondsSinceEpoch,
      'ended_at': route.endedAt?.millisecondsSinceEpoch,
      'locations': jsonEncode(route.locations.map((l) => l.toJson()).toList()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Delete a route
  Future<void> deleteRoute(String routeId) async {
    if (_db == null) await init();

    await _db!.delete(_routesTable, where: 'id = ?', whereArgs: [routeId]);
  }

  /// Clear all routes
  Future<void> clearAllRoutes() async {
    if (_db == null) await init();

    await _db!.delete(_routesTable);
    await _db!.delete(_activeRouteKey);
  }

  /// Auto-prune routes older than 365 days. Call on app launch.
  static const _retentionDays = 365;

  Future<int> pruneExpiredRoutes() async {
    if (_db == null) await init();

    final cutoff = DateTime.now()
        .subtract(const Duration(days: _retentionDays))
        .millisecondsSinceEpoch;

    return _db!.delete(
      _routesTable,
      where: 'created_at < ?',
      whereArgs: [cutoff],
    );
  }

  /// Get the currently active route being recorded
  Future<Route?> getActiveRoute() async {
    if (_db == null) await init();

    final List<Map<String, dynamic>> maps = await _db!.query(
      _activeRouteKey,
      where: 'id = ?',
      whereArgs: [1],
    );

    if (maps.isEmpty || maps.first['route_data'] == null) return null;

    return Route.fromJson(jsonDecode(maps.first['route_data'] as String));
  }

  /// Set the active route being recorded
  Future<void> setActiveRoute(Route? route) async {
    if (_db == null) await init();

    if (route == null) {
      await _db!.delete(_activeRouteKey, where: 'id = ?', whereArgs: [1]);
    } else {
      await _db!.insert(_activeRouteKey, {
        'id': 1,
        'route_data': jsonEncode(route.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Close the database connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
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
    buffer.writeln('<gpx version="1.1" creator="Socialmesh">');
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
