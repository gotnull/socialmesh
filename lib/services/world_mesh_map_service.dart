import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/world_mesh_node.dart';

/// Service to fetch global mesh node data from meshmap.net
class WorldMeshMapService {
  static const String _nodesUrl = 'https://meshmap.net/nodes.json';
  static const Duration _timeout = Duration(seconds: 30);

  final http.Client _client;

  WorldMeshMapService({http.Client? client})
    : _client = client ?? http.Client();

  /// Fetch all nodes from meshmap.net
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

      debugPrint('Fetched ${nodes.length} nodes from meshmap.net');
      return nodes;
    } on http.ClientException catch (e) {
      throw WorldMeshMapException('Network error: $e');
    } catch (e) {
      if (e is WorldMeshMapException) rethrow;
      throw WorldMeshMapException('Failed to fetch nodes: $e');
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
