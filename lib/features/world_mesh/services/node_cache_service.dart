// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging.dart';
import '../../../models/world_mesh_node.dart';

/// Service for caching mesh nodes for offline access.
///
/// The node list (tens of thousands of entries) lives in a file in the
/// app's cache directory. Only the timestamp is a preference: the platform
/// loads the whole preferences store into memory at launch, so a
/// multi-megabyte value there slows every start.
class NodeCacheService {
  NodeCacheService({Future<Directory> Function()? cacheDirectory})
    : _cacheDirectory = cacheDirectory ?? getApplicationCacheDirectory;

  final Future<Directory> Function() _cacheDirectory;

  static const _cacheFileName = 'world_mesh_nodes.json';
  static const _cacheTimestampKey = 'cached_mesh_nodes_timestamp';
  // Earlier builds kept the node list itself in preferences.
  static const _legacyCacheKey = 'cached_mesh_nodes';
  static const _maxCacheAge = Duration(hours: 24);

  Future<File> _cacheFile() async =>
      File(p.join((await _cacheDirectory()).path, _cacheFileName));

  static Future<void> _dropLegacyCache(SharedPreferences prefs) async {
    if (prefs.containsKey(_legacyCacheKey)) {
      await prefs.remove(_legacyCacheKey);
    }
  }

  /// Removes the node list an earlier build stored in preferences. Run at
  /// launch so the store shrinks even if the World Map is never reopened.
  static Future<void> dropLegacyPrefsCache() async =>
      _dropLegacyCache(await SharedPreferences.getInstance());

  /// Checks if the cache is still valid (not expired)
  Future<bool> isCacheValid() async {
    final timestamp = await getCacheTimestamp();
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _maxCacheAge;
  }

  /// Saves nodes to the offline cache
  Future<void> cacheNodes(List<WorldMeshNode> nodes) async {
    final prefs = await SharedPreferences.getInstance();
    final nodesJson = nodes.map((node) => node.toJson()).toList();
    final file = await _cacheFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(nodesJson), flush: true);
    await prefs.setString(_cacheTimestampKey, DateTime.now().toIso8601String());
    await _dropLegacyCache(prefs);
  }

  /// Retrieves cached nodes if available
  Future<List<WorldMeshNode>?> getCachedNodes() async {
    final prefs = await SharedPreferences.getInstance();
    await _dropLegacyCache(prefs);
    final jsonList = await _readCachedJson();
    if (jsonList == null) return null;

    try {
      return jsonList.map((json) {
        final map = json as Map<String, dynamic>;
        final nodeNum = map['nodeNum'] as int;
        return WorldMeshNode.fromJson(nodeNum, map);
      }).toList();
    } catch (e) {
      AppLogging.maps('World mesh node cache unreadable, clearing: $e');
      await clearCache();
      return null;
    }
  }

  Future<List<dynamic>?> _readCachedJson() async {
    final file = await _cacheFile();
    if (!await file.exists()) return null;
    try {
      return jsonDecode(await file.readAsString()) as List<dynamic>;
    } catch (e) {
      AppLogging.maps('World mesh node cache unreadable, clearing: $e');
      await clearCache();
      return null;
    }
  }

  /// Gets the timestamp of when the cache was last updated
  Future<DateTime?> getCacheTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampStr = prefs.getString(_cacheTimestampKey);
    if (timestampStr == null) return null;
    return DateTime.tryParse(timestampStr);
  }

  /// Clears the offline cache
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final file = await _cacheFile();
    if (await file.exists()) await file.delete();
    await prefs.remove(_cacheTimestampKey);
    await _dropLegacyCache(prefs);
  }

  /// Gets a summary of the cache status
  Future<CacheStatus> getCacheStatus() async {
    final timestamp = await getCacheTimestamp();
    final jsonList = await _readCachedJson();

    if (jsonList == null || timestamp == null) {
      return CacheStatus(
        hasCache: false,
        nodeCount: 0,
        timestamp: null,
        isExpired: true,
      );
    }

    return CacheStatus(
      hasCache: true,
      nodeCount: jsonList.length,
      timestamp: timestamp,
      isExpired: DateTime.now().difference(timestamp) > _maxCacheAge,
    );
  }
}

/// Status information about the offline cache
class CacheStatus {
  final bool hasCache;
  final int nodeCount;
  final DateTime? timestamp;
  final bool isExpired;

  CacheStatus({
    required this.hasCache,
    required this.nodeCount,
    required this.timestamp,
    required this.isExpired,
  });
}
