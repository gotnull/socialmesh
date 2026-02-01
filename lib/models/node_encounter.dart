// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Local-only encounter history for a mesh node.
/// Tracks how often and when we've seen a node to make the mesh feel socially alive.
@immutable
class NodeEncounter {
  final int nodeId;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final int encounterCount;
  final int uniqueDaysSeen;

  const NodeEncounter({
    required this.nodeId,
    required this.firstSeen,
    required this.lastSeen,
    required this.encounterCount,
    required this.uniqueDaysSeen,
  });

  /// Create a new encounter for a node seen for the first time.
  factory NodeEncounter.firstEncounter(int nodeId, DateTime now) {
    return NodeEncounter(
      nodeId: nodeId,
      firstSeen: now,
      lastSeen: now,
      encounterCount: 1,
      uniqueDaysSeen: 1,
    );
  }

  /// Whether this node is familiar (seen multiple times).
  bool get isFamiliar => encounterCount > 5;

  /// Whether this node was seen recently (within 24 hours).
  bool seenRecently(DateTime now) => now.difference(lastSeen).inHours < 24;

  /// Whether this node reappeared after >48h absence (retention cue).
  /// Only meaningful if called with previousLastSeen from before current session.
  bool wasAbsentLong(DateTime previousLastSeen, DateTime now) =>
      now.difference(previousLastSeen).inHours > 48;

  /// How many days since we first saw this node.
  int relationshipAgeDays(DateTime now) => now.difference(firstSeen).inDays;

  /// Human-friendly encounter summary.
  String get encounterSummary {
    if (encounterCount == 1) return 'First encounter';
    return 'Seen $encounterCount times';
  }

  /// Human-friendly relationship age text.
  String relationshipAgeText(DateTime now) {
    final days = relationshipAgeDays(now);
    if (days == 0) return 'First seen today';
    if (days == 1) return 'First seen yesterday';
    if (days < 7) return 'First seen $days days ago';
    if (days < 14) return 'First seen 1 week ago';
    if (days < 30) return 'First seen ${days ~/ 7} weeks ago';
    if (days < 60) return 'First seen 1 month ago';
    return 'First seen ${days ~/ 30} months ago';
  }

  /// Record a new encounter, updating counts appropriately.
  NodeEncounter recordEncounter(DateTime now) {
    final isNewDay = !_isSameDay(lastSeen, now);
    return NodeEncounter(
      nodeId: nodeId,
      firstSeen: firstSeen,
      lastSeen: now,
      encounterCount: encounterCount + 1,
      uniqueDaysSeen: isNewDay ? uniqueDaysSeen + 1 : uniqueDaysSeen,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Map<String, dynamic> toJson() => {
    'n': nodeId,
    'f': firstSeen.millisecondsSinceEpoch,
    'l': lastSeen.millisecondsSinceEpoch,
    'c': encounterCount,
    'd': uniqueDaysSeen,
  };

  factory NodeEncounter.fromJson(Map<String, dynamic> json) {
    return NodeEncounter(
      nodeId: json['n'] as int,
      firstSeen: DateTime.fromMillisecondsSinceEpoch(json['f'] as int),
      lastSeen: DateTime.fromMillisecondsSinceEpoch(json['l'] as int),
      encounterCount: json['c'] as int? ?? 1,
      uniqueDaysSeen: json['d'] as int? ?? 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeEncounter &&
          nodeId == other.nodeId &&
          firstSeen == other.firstSeen &&
          lastSeen == other.lastSeen &&
          encounterCount == other.encounterCount &&
          uniqueDaysSeen == other.uniqueDaysSeen;

  @override
  int get hashCode =>
      Object.hash(nodeId, firstSeen, lastSeen, encounterCount, uniqueDaysSeen);
}

/// Service for managing local node encounter history.
class NodeEncounterService {
  static const String _prefsKey = 'node_encounters_v1';
  static const int _maxStoredNodes = 500;

  final Future<String?> Function(String key) _read;
  final Future<bool> Function(String key, String value) _write;

  Map<int, NodeEncounter>? _cache;
  bool _dirty = false;

  NodeEncounterService({
    required Future<String?> Function(String key) read,
    required Future<bool> Function(String key, String value) write,
  }) : _read = read,
       _write = write;

  /// Load encounters from storage into cache.
  Future<void> init() async {
    if (_cache != null) return;
    _cache = {};
    try {
      final data = await _read(_prefsKey);
      if (data != null && data.isNotEmpty) {
        final list = jsonDecode(data) as List<dynamic>;
        for (final item in list) {
          final encounter = NodeEncounter.fromJson(
            item as Map<String, dynamic>,
          );
          _cache![encounter.nodeId] = encounter;
        }
      }
    } catch (_) {
      _cache = {};
    }
  }

  /// Get encounter history for a specific node.
  NodeEncounter? getEncounter(int nodeId) => _cache?[nodeId];

  /// Get all encounter records.
  List<NodeEncounter> getAllEncounters() => _cache?.values.toList() ?? [];

  /// Get frequent nodes sorted by encounter count (desc), then lastSeen (desc).
  List<NodeEncounter> getFrequentNodes({int limit = 20}) {
    if (_cache == null || _cache!.isEmpty) return [];
    final sorted = _cache!.values.toList()
      ..sort((a, b) {
        final countCompare = b.encounterCount.compareTo(a.encounterCount);
        if (countCompare != 0) return countCompare;
        return b.lastSeen.compareTo(a.lastSeen);
      });
    return sorted.take(limit).toList();
  }

  /// Record that we observed a node. Call this whenever a node is seen.
  Future<NodeEncounter> recordObservation(int nodeId, {DateTime? now}) async {
    await init();
    final timestamp = now ?? DateTime.now();

    final existing = _cache![nodeId];
    final encounter = existing != null
        ? existing.recordEncounter(timestamp)
        : NodeEncounter.firstEncounter(nodeId, timestamp);

    _cache![nodeId] = encounter;
    _dirty = true;

    // Debounced save - don't write on every observation
    _scheduleSave();

    return encounter;
  }

  DateTime? _lastSaveScheduled;

  void _scheduleSave() {
    final now = DateTime.now();
    if (_lastSaveScheduled != null &&
        now.difference(_lastSaveScheduled!).inSeconds < 30) {
      return;
    }
    _lastSaveScheduled = now;
    Future.delayed(const Duration(seconds: 30), _saveIfDirty);
  }

  Future<void> _saveIfDirty() async {
    if (!_dirty || _cache == null) return;
    await save();
  }

  /// Persist encounters to storage.
  Future<void> save() async {
    if (_cache == null) return;

    // Prune old entries if over limit
    if (_cache!.length > _maxStoredNodes) {
      final sorted = _cache!.values.toList()
        ..sort((a, b) => a.lastSeen.compareTo(b.lastSeen));
      final toRemove = sorted.take(_cache!.length - _maxStoredNodes);
      for (final e in toRemove) {
        _cache!.remove(e.nodeId);
      }
    }

    final list = _cache!.values.map((e) => e.toJson()).toList();
    await _write(_prefsKey, jsonEncode(list));
    _dirty = false;
  }

  /// Force immediate save (call on app lifecycle events).
  Future<void> flush() async {
    if (_dirty) await save();
  }
}
