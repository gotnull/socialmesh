// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tracks which mesh nodes support the SocialMesh binary protocol.
///
/// When we receive a packet on portnum 260/261/262 from a node, we mark
/// that node as binary-capable so node-profile UI can surface protocol
/// capability.
///
/// Persistence uses an abstract [SmCapabilityPersistence] interface
/// for testability (production impl uses SharedPreferences).
library;

import 'dart:convert';

/// Clock function type for injectable time source.
typedef SmClock = DateTime Function();

/// Abstract persistence interface for testability.
abstract class SmCapabilityPersistence {
  /// Load all persisted capability entries.
  Future<Map<int, int>> load();

  /// Save all capability entries (nodeNum -> millisSinceEpoch).
  Future<void> save(Map<int, int> data);
}

/// In-memory + optionally persisted capability store.
///
/// Keyed by nodeNum. Stores the last time we received a binary SM
/// packet from each node.
class SmCapabilityStore {
  final Map<int, DateTime> _nodes = {};
  final SmCapabilityPersistence? _persistence;
  final SmClock _clock;

  SmCapabilityStore({SmCapabilityPersistence? persistence, SmClock? clock})
    : _persistence = persistence,
      _clock = clock ?? DateTime.now;

  /// Load persisted state. Call once at startup.
  Future<void> init() async {
    if (_persistence == null) return;
    final loaded = await _persistence.load();
    for (final entry in loaded.entries) {
      _nodes[entry.key] = DateTime.fromMillisecondsSinceEpoch(entry.value);
    }
  }

  /// Mark a node as supporting SM binary protocol.
  Future<void> markNodeSupported(int nodeNum) async {
    _nodes[nodeNum] = _clock();
    await _persist();
  }

  /// Whether we have ever received binary packets from this node.
  bool isNodeSupported(int nodeNum) => _nodes.containsKey(nodeNum);

  /// When this node was last seen sending binary packets.
  DateTime? lastSeenBinary(int nodeNum) => _nodes[nodeNum];

  /// Number of nodes known to support binary.
  int get supportedNodeCount => _nodes.length;

  /// All known binary-capable node numbers.
  Set<int> get supportedNodes => Set.unmodifiable(_nodes.keys.toSet());

  /// Clear all capability data.
  Future<void> clear() async {
    _nodes.clear();
    await _persist();
  }

  Future<void> _persist() async {
    if (_persistence == null) return;
    final data = _nodes.map((k, v) => MapEntry(k, v.millisecondsSinceEpoch));
    await _persistence.save(data);
  }
}

/// JSON-string–based persistence suitable for SharedPreferences.
///
/// Serializes the capability map as `{"nodeNum": epochMs, ...}`.
class JsonStringCapabilityPersistence implements SmCapabilityPersistence {
  final Future<String?> Function() _loadFn;
  final Future<void> Function(String) _saveFn;

  JsonStringCapabilityPersistence({
    required Future<String?> Function() load,
    required Future<void> Function(String) save,
  }) : _loadFn = load,
       _saveFn = save;

  @override
  Future<Map<int, int>> load() async {
    final raw = await _loadFn();
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> save(Map<int, int> data) async {
    final json = data.map((k, v) => MapEntry(k.toString(), v));
    await _saveFn(jsonEncode(json));
  }
}
