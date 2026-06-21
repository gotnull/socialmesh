// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Node Groups state — reactive layer over NodeGroupsStore (nodedex.db).
//
// Exposes the list of user-defined groups plus the node->group membership
// map, and mutation methods (create / update / delete / assign). Mirrors the
// AsyncNotifier-with-persistence pattern used by nodeFavoritesProvider.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../models/node_group.dart';
import '../services/nodedex_groups_store.dart';
import 'nodedex_providers.dart';

/// Immutable snapshot of all groups and current membership.
class NodeGroupsState {
  final List<NodeGroup> groups;

  /// nodeNum -> set of groupIds the node belongs to.
  final Map<int, Set<String>> membership;

  const NodeGroupsState({this.groups = const [], this.membership = const {}});

  /// The set of group ids a given node belongs to (never null).
  Set<String> groupsForNode(int nodeNum) =>
      membership[nodeNum] ?? const <String>{};

  /// How many nodes are assigned to [groupId].
  int nodeCount(String groupId) =>
      membership.values.where((ids) => ids.contains(groupId)).length;

  /// The node numbers assigned to [groupId].
  List<int> nodesInGroup(String groupId) => [
    for (final entry in membership.entries)
      if (entry.value.contains(groupId)) entry.key,
  ];

  /// Whether any group has been created.
  bool get isEmpty => groups.isEmpty;
}

/// Builds a [NodeGroupsStore] over the shared NodeDex database, ensuring the
/// database is initialized first (via [nodeDexStoreProvider]).
final nodeGroupsStoreProvider = FutureProvider<NodeGroupsStore>((ref) async {
  // Awaiting the entry store guarantees the shared NodeDexDatabase is open.
  await ref.watch(nodeDexStoreProvider.future);
  final db = ref.watch(nodeDexDatabaseProvider);
  return NodeGroupsStore(db);
});

/// Reactive node-groups state with mutation methods.
class NodeGroupsNotifier extends AsyncNotifier<NodeGroupsState> {
  Future<NodeGroupsStore> get _storeFuture =>
      ref.read(nodeGroupsStoreProvider.future);

  @override
  Future<NodeGroupsState> build() async {
    final store = await ref.watch(nodeGroupsStoreProvider.future);
    return _load(store);
  }

  Future<NodeGroupsState> _load(NodeGroupsStore store) async {
    final groups = await store.loadGroups();
    final membership = await store.loadMembership();
    return NodeGroupsState(groups: groups, membership: membership);
  }

  Future<void> _reload() async {
    final store = await _storeFuture;
    state = await AsyncValue.guard(() => _load(store));
  }

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;

  /// Generate a collision-resistant local id for a new group.
  String _newGroupId() =>
      'g${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  /// Create a new group; returns the created group.
  Future<NodeGroup> createGroup({
    required String name,
    required int colorValue,
    required String iconKey,
  }) async {
    final store = await _storeFuture;
    final now = _nowMs;
    final existing = state.asData?.value.groups ?? const <NodeGroup>[];
    final group = NodeGroup(
      id: _newGroupId(),
      name: name.trim(),
      colorValue: colorValue,
      iconKey: iconKey,
      sortOrder: existing.length,
      createdAtMs: now,
      updatedAtMs: now,
    );
    await store.upsertGroup(group);
    await _reload();
    AppLogging.nodes('[NodeGroups] created group ${group.id} "${group.name}"');
    return group;
  }

  /// Update an existing group (name / colour / icon / sort order). The
  /// updated timestamp is refreshed automatically.
  Future<void> updateGroup(NodeGroup group) async {
    final store = await _storeFuture;
    await store.upsertGroup(group.copyWith(updatedAtMs: _nowMs));
    await _reload();
  }

  /// Delete a group and clear all of its membership.
  Future<void> deleteGroup(String groupId) async {
    final store = await _storeFuture;
    await store.deleteGroup(groupId);
    await _reload();
  }

  /// Persist reordered groups (assigns sortOrder by list position).
  Future<void> reorderGroups(List<NodeGroup> ordered) async {
    final store = await _storeFuture;
    final now = _nowMs;
    for (var i = 0; i < ordered.length; i++) {
      await store.upsertGroup(
        ordered[i].copyWith(sortOrder: i, updatedAtMs: now),
      );
    }
    await _reload();
  }

  /// Replace the full set of groups a node belongs to.
  Future<void> setNodeGroups(int nodeNum, Set<String> groupIds) async {
    final store = await _storeFuture;
    await store.setNodeGroups(nodeNum, groupIds, nowMs: _nowMs);
    await _reload();
  }

  /// Add one node to one group.
  Future<void> addNodeToGroup(int nodeNum, String groupId) async {
    final store = await _storeFuture;
    await store.addNodeToGroup(nodeNum, groupId, nowMs: _nowMs);
    await _reload();
  }

  /// Remove one node from one group.
  Future<void> removeNodeFromGroup(int nodeNum, String groupId) async {
    final store = await _storeFuture;
    await store.removeNodeFromGroup(nodeNum, groupId);
    await _reload();
  }

  /// Remove multiple nodes from one group.
  Future<void> removeNodesFromGroup(Set<int> nodeNums, String groupId) async {
    if (nodeNums.isEmpty) return;
    final store = await _storeFuture;
    await store.removeNodesFromGroup(nodeNums, groupId);
    await _reload();
  }
}

final nodeGroupsProvider =
    AsyncNotifierProvider<NodeGroupsNotifier, NodeGroupsState>(
      NodeGroupsNotifier.new,
    );
