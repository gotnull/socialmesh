// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/world_mesh_node.dart';

/// Service for caching mesh nodes for offline access
class NodeCacheService {
  static const _cacheKey = 'cached_mesh_nodes';
  static const _cacheTimestampKey = 'cached_mesh_nodes_timestamp';
  static const _maxCacheAge = Duration(hours: 24);

  /// Checks if the cache is still valid (not expired)
  Future<bool> isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampStr = prefs.getString(_cacheTimestampKey);
    if (timestampStr == null) return false;

    final timestamp = DateTime.tryParse(timestampStr);
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < _maxCacheAge;
  }

  /// Saves nodes to the offline cache
  Future<void> cacheNodes(List<WorldMeshNode> nodes) async {
    final prefs = await SharedPreferences.getInstance();

    final nodesJson = nodes.map((node) => node.toJson()).toList();
    await prefs.setString(_cacheKey, jsonEncode(nodesJson));
    await prefs.setString(_cacheTimestampKey, DateTime.now().toIso8601String());
  }

  /// Retrieves cached nodes if available
  Future<List<WorldMeshNode>?> getCachedNodes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_cacheKey);
    if (jsonStr == null) return null;

    try {
      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      return jsonList.map((json) {
        final map = json as Map<String, dynamic>;
        final nodeNum = map['nodeNum'] as int;
        return WorldMeshNode.fromJson(nodeNum, map);
      }).toList();
    } catch (e) {
      // Cache is corrupted, clear it
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
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimestampKey);
  }

  /// Gets a summary of the cache status
  Future<CacheStatus> getCacheStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_cacheKey);
    final timestampStr = prefs.getString(_cacheTimestampKey);

    if (jsonStr == null || timestampStr == null) {
      return CacheStatus(
        hasCache: false,
        nodeCount: 0,
        timestamp: null,
        isExpired: true,
      );
    }

    final timestamp = DateTime.tryParse(timestampStr);
    int nodeCount = 0;

    try {
      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      nodeCount = jsonList.length;
    } catch (_) {
      // Ignore decode errors for count
    }

    return CacheStatus(
      hasCache: true,
      nodeCount: nodeCount,
      timestamp: timestamp,
      isExpired:
          timestamp == null ||
          DateTime.now().difference(timestamp) > _maxCacheAge,
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
