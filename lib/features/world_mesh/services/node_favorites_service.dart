import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/world_mesh_node.dart';

/// Service for persisting and retrieving favorite nodes.
/// Stores minimal metadata for favorites to allow offline access.
class NodeFavoritesService {
  static const _favoritesKey = 'mesh_node_favorites';

  /// Get all favorite node IDs
  Future<List<String>> getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? [];
  }

  /// Get all favorite nodes with their metadata
  Future<List<FavoriteNodeMetadata>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_favoritesKey) ?? [];
    final favorites = <FavoriteNodeMetadata>[];

    for (final id in ids) {
      final metadataJson = prefs.getString('${_favoritesKey}_meta_$id');
      if (metadataJson != null) {
        try {
          final meta = FavoriteNodeMetadata.fromJson(
            jsonDecode(metadataJson) as Map<String, dynamic>,
          );
          favorites.add(meta);
        } catch (_) {
          // Skip corrupted entries
        }
      }
    }

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
    final nodeId = node.nodeNum.toRadixString(16).toUpperCase();
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
    final nodeId = node.nodeNum.toRadixString(16).toUpperCase();
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
