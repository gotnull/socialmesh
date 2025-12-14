import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/world_mesh_node.dart';

/// Service for persisting historical node data snapshots.
/// Stores time-series data to track node behavior over time.
class NodeHistoryService {
  static const _historyKeyPrefix = 'mesh_node_history_';
  static const _maxEntriesPerNode = 100;

  /// Get history for a specific node
  Future<List<NodeHistoryEntry>> getHistory(String nodeId) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('$_historyKeyPrefix$nodeId') ?? [];

    return historyJson
        .map((json) {
          try {
            return NodeHistoryEntry.fromJson(
              jsonDecode(json) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<NodeHistoryEntry>()
        .toList();
  }

  /// Record a snapshot of the node's current state
  Future<void> recordSnapshot(String nodeId, NodeHistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('$_historyKeyPrefix$nodeId') ?? [];

    // Add new entry
    historyJson.add(jsonEncode(entry.toJson()));

    // Trim to max entries (keep most recent)
    while (historyJson.length > _maxEntriesPerNode) {
      historyJson.removeAt(0);
    }

    await prefs.setStringList('$_historyKeyPrefix$nodeId', historyJson);
  }

  /// Get statistics for a node's history
  Future<NodeHistoryStats?> getStats(String nodeId) async {
    final history = await getHistory(nodeId);
    if (history.isEmpty) return null;

    // Calculate battery stats
    final batteries = history
        .where((e) => e.batteryLevel != null)
        .map((e) => e.batteryLevel!)
        .toList();

    double? avgBattery;
    int? minBattery;
    int? maxBattery;
    if (batteries.isNotEmpty) {
      avgBattery = batteries.reduce((a, b) => a + b) / batteries.length;
      minBattery = batteries.reduce((a, b) => a < b ? a : b);
      maxBattery = batteries.reduce((a, b) => a > b ? a : b);
    }

    // Calculate uptime stats
    final onlineCount = history.where((e) => e.isOnline).length;
    final uptimePercent = history.isNotEmpty
        ? (onlineCount / history.length) * 100
        : 0.0;

    // Calculate average channel utilization
    final channelUtils = history
        .where((e) => e.channelUtil != null)
        .map((e) => e.channelUtil!)
        .toList();
    double? avgChannelUtil;
    if (channelUtils.isNotEmpty) {
      avgChannelUtil =
          channelUtils.reduce((a, b) => a + b) / channelUtils.length;
    }

    return NodeHistoryStats(
      totalRecords: history.length,
      firstSeen: history.first.timestamp,
      lastSeen: history.last.timestamp,
      avgBattery: avgBattery,
      minBattery: minBattery,
      maxBattery: maxBattery,
      uptimePercent: uptimePercent,
      avgChannelUtil: avgChannelUtil,
    );
  }

  /// Clear history for a specific node
  Future<void> clearHistory(String nodeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_historyKeyPrefix$nodeId');
  }

  /// Get all node IDs that have history
  Future<List<String>> getNodesWithHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    return keys
        .where((k) => k.startsWith(_historyKeyPrefix))
        .map((k) => k.replaceFirst(_historyKeyPrefix, ''))
        .toList();
  }
}

/// A snapshot of node state at a point in time
class NodeHistoryEntry {
  final DateTime timestamp;
  final int? batteryLevel;
  final double? voltage;
  final double? channelUtil;
  final double? airUtilTx;
  final bool isOnline;
  final int neighborCount;
  final int gatewayCount;
  final double? latitude;
  final double? longitude;

  NodeHistoryEntry({
    required this.timestamp,
    this.batteryLevel,
    this.voltage,
    this.channelUtil,
    this.airUtilTx,
    required this.isOnline,
    required this.neighborCount,
    required this.gatewayCount,
    this.latitude,
    this.longitude,
  });

  /// Create from a WorldMeshNode
  factory NodeHistoryEntry.fromNode(WorldMeshNode node) {
    return NodeHistoryEntry(
      timestamp: DateTime.now(),
      batteryLevel: node.batteryLevel,
      voltage: node.voltage,
      channelUtil: node.chUtil,
      airUtilTx: node.airUtilTx,
      isOnline: node.isOnline,
      neighborCount: node.neighbors?.length ?? 0,
      gatewayCount: node.seenBy.length,
      latitude: node.latitudeDecimal,
      longitude: node.longitudeDecimal,
    );
  }

  factory NodeHistoryEntry.fromJson(Map<String, dynamic> json) {
    return NodeHistoryEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      batteryLevel: json['batteryLevel'] as int?,
      voltage: (json['voltage'] as num?)?.toDouble(),
      channelUtil: (json['channelUtil'] as num?)?.toDouble(),
      airUtilTx: (json['airUtilTx'] as num?)?.toDouble(),
      isOnline: json['isOnline'] as bool? ?? false,
      neighborCount: json['neighborCount'] as int? ?? 0,
      gatewayCount: json['gatewayCount'] as int? ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'batteryLevel': batteryLevel,
    'voltage': voltage,
    'channelUtil': channelUtil,
    'airUtilTx': airUtilTx,
    'isOnline': isOnline,
    'neighborCount': neighborCount,
    'gatewayCount': gatewayCount,
    'latitude': latitude,
    'longitude': longitude,
  };
}

/// Aggregated statistics for a node's history
class NodeHistoryStats {
  final int totalRecords;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final double? avgBattery;
  final int? minBattery;
  final int? maxBattery;
  final double uptimePercent;
  final double? avgChannelUtil;

  NodeHistoryStats({
    required this.totalRecords,
    required this.firstSeen,
    required this.lastSeen,
    this.avgBattery,
    this.minBattery,
    this.maxBattery,
    required this.uptimePercent,
    this.avgChannelUtil,
  });
}
