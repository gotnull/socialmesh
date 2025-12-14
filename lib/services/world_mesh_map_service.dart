import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/world_mesh_node.dart';

/// Service to fetch global mesh node data from mesh-observer
class WorldMeshMapService {
  /// Get the base URL based on environment
  static String get _defaultApiUrl {
    // TODO: Change to api.socialmesh.app when deployed to production
    // For now, use local network IP for development/testing
    const useLocalServer = true; // Set to false when production server is ready

    if (useLocalServer) {
      // Local development server
      if (kIsWeb) {
        return 'http://localhost:3001';
      } else if (!kIsWeb && Platform.isAndroid) {
        return 'http://192.168.5.77:3001';
      } else {
        return 'http://192.168.5.77:3001';
      }
    }

    // Production - use the Socialmesh API
    return 'https://api.socialmesh.app';
  }

  /// Default API endpoint
  static String defaultApiUrl = _defaultApiUrl;

  /// Current API base URL (can be changed for self-hosted)
  static String _apiBaseUrl = defaultApiUrl;

  static const Duration _timeout = Duration(seconds: 30);

  final http.Client _client;

  WorldMeshMapService({http.Client? client})
    : _client = client ?? http.Client();

  /// Configure the API base URL for self-hosted mesh observer
  /// Example: 'http://localhost:3001' or 'https://your-server.com'
  static void setApiBaseUrl(String url) {
    _apiBaseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    debugPrint('WorldMeshMapService: API URL set to $_apiBaseUrl');
  }

  /// Reset to default public API
  static void resetToDefault() {
    _apiBaseUrl = defaultApiUrl;
    debugPrint('WorldMeshMapService: Reset to default API');
  }

  /// Get current API base URL
  static String get currentApiUrl => _apiBaseUrl;

  /// Check if using self-hosted server
  static bool get isSelfHosted => _apiBaseUrl != defaultApiUrl;

  /// Get the nodes.json URL
  String get _nodesUrl => '$_apiBaseUrl/nodes.json';

  /// Fetch all nodes from API
  /// Returns a map of nodeNum -> WorldMeshNode
  Future<Map<int, WorldMeshNode>> fetchNodes() async {
    try {
      final response = await _client
          .get(Uri.parse(_nodesUrl))
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw WorldMeshMapException(
          'Failed to fetch nodes: HTTP ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final nodes = <int, WorldMeshNode>{};

      for (final entry in json.entries) {
        try {
          final nodeNum = int.parse(entry.key);
          final nodeData = entry.value as Map<String, dynamic>;
          nodes[nodeNum] = WorldMeshNode.fromJson(nodeNum, nodeData);
        } catch (e) {
          // Skip invalid nodes
          debugPrint('Failed to parse node ${entry.key}: $e');
        }
      }

      debugPrint('Fetched ${nodes.length} nodes from $_apiBaseUrl');
      return nodes;
    } on http.ClientException catch (e) {
      throw WorldMeshMapException('Network error: $e');
    } catch (e) {
      if (e is WorldMeshMapException) rethrow;
      throw WorldMeshMapException('Failed to fetch nodes: $e');
    }
  }

  /// Fetch a single node by nodeNum
  /// Returns null if node not found
  Future<WorldMeshNode?> fetchNode(int nodeNum) async {
    try {
      final nodes = await fetchNodes();
      return nodes[nodeNum];
    } catch (e) {
      debugPrint('Failed to fetch node $nodeNum: $e');
      return null;
    }
  }

  /// Fetch stats from the API (only works with self-hosted mesh-observer)
  Future<Map<String, dynamic>?> fetchStats() async {
    if (!isSelfHosted) return null;

    try {
      final response = await _client
          .get(Uri.parse('$_apiBaseUrl/stats'))
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Failed to fetch stats: $e');
      return null;
    }
  }

  /// Check health of self-hosted server
  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('$_apiBaseUrl/health'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Exception for WorldMeshMap service errors
class WorldMeshMapException implements Exception {
  final String message;
  WorldMeshMapException(this.message);

  @override
  String toString() => 'WorldMeshMapException: $message';
}
