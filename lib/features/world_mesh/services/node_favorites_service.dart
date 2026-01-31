// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging.dart';
import '../../../models/world_mesh_node.dart';

/// Service for persisting and retrieving favorite nodes.
/// Stores minimal metadata for favorites to allow offline access.
class NodeFavoritesService {
  static const _favoritesKey = 'mesh_node_favorites';

  /// Get all favorite node IDs (normalized to 8-char padded hex)
  Future<List<String>> getFavoriteIds() async {
    AppLogging.nodes('[NodeFavoritesService] getFavoriteIds() called');
    final prefs = await SharedPreferences.getInstance();
    final rawIds = prefs.getStringList(_favoritesKey) ?? [];

    // Normalize all IDs to 8-char padded uppercase hex for consistency
    final normalizedIds = rawIds.map((id) {
      final trimmed = id.toUpperCase().replaceFirst(RegExp('^0+'), '');
      if (trimmed.isEmpty) return '00000000';
      return trimmed.padLeft(8, '0');
    }).toList();

    AppLogging.nodes(
      '[NodeFavoritesService] Found ${normalizedIds.length} IDs: $normalizedIds',
    );
    return normalizedIds;
  }

  /// Get all favorite nodes with their metadata
  Future<List<FavoriteNodeMetadata>> getFavorites() async {
    AppLogging.nodes('[NodeFavoritesService] getFavorites() called');
    final prefs = await SharedPreferences.getInstance();
    final rawIds = prefs.getStringList(_favoritesKey) ?? [];
    AppLogging.nodes(
      '[NodeFavoritesService] Loading metadata for ${rawIds.length} IDs',
    );
    final favorites = <FavoriteNodeMetadata>[];

    for (final rawId in rawIds) {
      // Normalize ID to 8-char padded
      final trimmed = rawId.toUpperCase().replaceFirst(RegExp('^0+'), '');
      final normalizedId = trimmed.isEmpty
          ? '00000000'
          : trimmed.padLeft(8, '0');

      // Try to find metadata with raw ID first (old data), then normalized ID
      String? metadataJson = prefs.getString('${_favoritesKey}_meta_$rawId');
      metadataJson ??= prefs.getString('${_favoritesKey}_meta_$normalizedId');

      AppLogging.nodes(
        '[NodeFavoritesService] Checking metadata for $rawId (normalized: $normalizedId): ${metadataJson != null ? "found" : "NOT FOUND"}',
      );
      if (metadataJson != null) {
        try {
          final meta = FavoriteNodeMetadata.fromJson(
            jsonDecode(metadataJson) as Map<String, dynamic>,
          );
          // Return with normalized nodeId
          favorites.add(
            FavoriteNodeMetadata(
              nodeId: normalizedId,
              longName: meta.longName,
              shortName: meta.shortName,
              role: meta.role,
              addedAt: meta.addedAt,
              lastSeen: meta.lastSeen,
              latitude: meta.latitude,
              longitude: meta.longitude,
            ),
          );
          AppLogging.nodes(
            '[NodeFavoritesService] Parsed metadata for $normalizedId: ${meta.longName}',
          );
        } catch (e) {
          AppLogging.nodes(
            '[NodeFavoritesService] ERROR parsing metadata for $normalizedId: $e',
          );
        }
      }
    }

    AppLogging.nodes(
      '[NodeFavoritesService] Returning ${favorites.length} favorites',
    );
    return favorites;
  }

  /// Check if a node is favorited
  Future<bool> isFavorite(String nodeId) async {
    final ids = await getFavoriteIds();
    return ids.contains(nodeId);
  }

  /// Add a node to favorites
  Future<void> addFavorite(WorldMeshNode node) async {
    final prefs = await SharedPreferences.getInstance();
    // Use padded 8-char hex for consistency
    final nodeId = node.nodeNum.toRadixString(16).padLeft(8, '0').toUpperCase();
    final ids = prefs.getStringList(_favoritesKey) ?? [];

    if (!ids.contains(nodeId)) {
      ids.add(nodeId);
      await prefs.setStringList(_favoritesKey, ids);
    }

    // Store metadata
    final metadata = FavoriteNodeMetadata(
      nodeId: nodeId,
      longName: node.longName,
      shortName: node.shortName,
      role: node.role,
      addedAt: DateTime.now(),
      lastSeen: node.lastSeen ?? DateTime.now(),
      latitude: node.latitudeDecimal,
      longitude: node.longitudeDecimal,
    );

    await prefs.setString(
      '${_favoritesKey}_meta_$nodeId',
      jsonEncode(metadata.toJson()),
    );
  }

  /// Remove a node from favorites
  Future<void> removeFavorite(String nodeId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_favoritesKey) ?? [];

    ids.remove(nodeId);
    await prefs.setStringList(_favoritesKey, ids);
    await prefs.remove('${_favoritesKey}_meta_$nodeId');
  }

  /// Update metadata for a favorite node (e.g., when viewing it again)
  Future<void> updateFavoriteMetadata(WorldMeshNode node) async {
    final prefs = await SharedPreferences.getInstance();
    // Use padded 8-char hex for consistency
    final nodeId = node.nodeNum.toRadixString(16).padLeft(8, '0').toUpperCase();
    final ids = prefs.getStringList(_favoritesKey) ?? [];

    if (!ids.contains(nodeId)) return;

    // Get existing metadata for addedAt date
    final existingJson = prefs.getString('${_favoritesKey}_meta_$nodeId');
    DateTime? addedAt;
    if (existingJson != null) {
      try {
        final existing = FavoriteNodeMetadata.fromJson(
          jsonDecode(existingJson) as Map<String, dynamic>,
        );
        addedAt = existing.addedAt;
      } catch (_) {
        // Ignore
      }
    }

    final metadata = FavoriteNodeMetadata(
      nodeId: nodeId,
      longName: node.longName,
      shortName: node.shortName,
      role: node.role,
      addedAt: addedAt ?? DateTime.now(),
      lastSeen: node.lastSeen ?? DateTime.now(),
      latitude: node.latitudeDecimal,
      longitude: node.longitudeDecimal,
    );

    await prefs.setString(
      '${_favoritesKey}_meta_$nodeId',
      jsonEncode(metadata.toJson()),
    );
  }
}

/// Metadata stored for each favorite node
class FavoriteNodeMetadata {
  final String nodeId;
  final String longName;
  final String shortName;
  final String role;
  final DateTime addedAt;
  final DateTime lastSeen;
  final double? latitude;
  final double? longitude;

  FavoriteNodeMetadata({
    required this.nodeId,
    required this.longName,
    required this.shortName,
    required this.role,
    required this.addedAt,
    required this.lastSeen,
    this.latitude,
    this.longitude,
  });

  factory FavoriteNodeMetadata.fromJson(Map<String, dynamic> json) {
    return FavoriteNodeMetadata(
      nodeId: json['nodeId'] as String,
      longName: json['longName'] as String? ?? '',
      shortName: json['shortName'] as String? ?? '',
      role: json['role'] as String? ?? '',
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'nodeId': nodeId,
    'longName': longName,
    'shortName': shortName,
    'role': role,
    'addedAt': addedAt.toIso8601String(),
    'lastSeen': lastSeen.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
  };
}
