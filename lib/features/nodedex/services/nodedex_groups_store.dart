// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeDex Groups Store — local persistence for user-defined node groups.
//
// Shares the nodedex.db database handle (NodeDexDatabase) with
// NodeDexSqliteStore. Groups and their membership are a local organisation
// concept; this store reads/writes the nodedex_groups and nodedex_node_groups
// tables added in schema v15.

import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../models/node_group.dart';
import 'nodedex_database.dart';

/// SQLite-backed store for node groups and node->group membership.
class NodeGroupsStore {
  final NodeDexDatabase _database;

  NodeGroupsStore(this._database);

  Database get _db => _database.database;

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Load all groups (excluding any future soft-deleted rows), ordered by the
  /// user's sort order then name.
  Future<List<NodeGroup>> loadGroups() async {
    final rows = await _db.query(
      NodeDexTables.groups,
      where: '${NodeDexTables.colGroupDeletedAtMs} IS NULL',
      orderBy:
          '${NodeDexTables.colGroupSortOrder} ASC, '
          '${NodeDexTables.colGroupName} COLLATE NOCASE ASC',
    );
    return rows.map(_groupFromRow).toList();
  }

  /// Load membership as a map of nodeNum -> set of groupIds.
  Future<Map<int, Set<String>>> loadMembership() async {
    final rows = await _db.query(NodeDexTables.nodeGroups);
    final result = <int, Set<String>>{};
    for (final row in rows) {
      final nodeNum = row[NodeDexTables.colNodeNum] as int;
      final groupId = row[NodeDexTables.colNgGroupId] as String;
      (result[nodeNum] ??= <String>{}).add(groupId);
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Group CRUD
  // ---------------------------------------------------------------------------

  /// Insert or replace a group definition.
  Future<void> upsertGroup(NodeGroup group) async {
    await _db.insert(
      NodeDexTables.groups,
      _groupToRow(group),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    AppLogging.storage('NodeGroupsStore: upserted group ${group.id}');
  }

  /// Hard-delete a group and all of its membership rows.
  ///
  /// Foreign keys are not enabled on this database, so the membership rows are
  /// removed explicitly rather than relying on ON DELETE CASCADE.
  Future<void> deleteGroup(String groupId) async {
    await _db.transaction((txn) async {
      await txn.delete(
        NodeDexTables.nodeGroups,
        where: '${NodeDexTables.colNgGroupId} = ?',
        whereArgs: [groupId],
      );
      await txn.delete(
        NodeDexTables.groups,
        where: '${NodeDexTables.colGroupId} = ?',
        whereArgs: [groupId],
      );
    });
    AppLogging.storage('NodeGroupsStore: deleted group $groupId');
  }

  // ---------------------------------------------------------------------------
  // Membership
  // ---------------------------------------------------------------------------

  /// Replace the full set of groups a node belongs to.
  Future<void> setNodeGroups(
    int nodeNum,
    Set<String> groupIds, {
    required int nowMs,
  }) async {
    await _db.transaction((txn) async {
      await txn.delete(
        NodeDexTables.nodeGroups,
        where: '${NodeDexTables.colNodeNum} = ?',
        whereArgs: [nodeNum],
      );
      for (final groupId in groupIds) {
        await txn.insert(NodeDexTables.nodeGroups, {
          NodeDexTables.colNodeNum: nodeNum,
          NodeDexTables.colNgGroupId: groupId,
          NodeDexTables.colNgAssignedAtMs: nowMs,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Add a single node to a single group (idempotent).
  Future<void> addNodeToGroup(
    int nodeNum,
    String groupId, {
    required int nowMs,
  }) async {
    await _db.insert(NodeDexTables.nodeGroups, {
      NodeDexTables.colNodeNum: nodeNum,
      NodeDexTables.colNgGroupId: groupId,
      NodeDexTables.colNgAssignedAtMs: nowMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Remove a single node from a single group.
  Future<void> removeNodeFromGroup(int nodeNum, String groupId) async {
    await _db.delete(
      NodeDexTables.nodeGroups,
      where:
          '${NodeDexTables.colNodeNum} = ? AND ${NodeDexTables.colNgGroupId} = ?',
      whereArgs: [nodeNum, groupId],
    );
  }

  /// Remove multiple nodes from a single group in one statement.
  Future<void> removeNodesFromGroup(Set<int> nodeNums, String groupId) async {
    if (nodeNums.isEmpty) return;
    final placeholders = List.filled(nodeNums.length, '?').join(', ');
    await _db.delete(
      NodeDexTables.nodeGroups,
      where:
          '${NodeDexTables.colNgGroupId} = ? AND '
          '${NodeDexTables.colNodeNum} IN ($placeholders)',
      whereArgs: [groupId, ...nodeNums],
    );
  }

  // ---------------------------------------------------------------------------
  // Row mapping
  // ---------------------------------------------------------------------------

  NodeGroup _groupFromRow(Map<String, Object?> row) {
    return NodeGroup(
      id: row[NodeDexTables.colGroupId] as String,
      name: row[NodeDexTables.colGroupName] as String,
      colorValue: row[NodeDexTables.colGroupColor] as int,
      iconKey: row[NodeDexTables.colGroupIconKey] as String,
      sortOrder: (row[NodeDexTables.colGroupSortOrder] as int?) ?? 0,
      createdAtMs: row[NodeDexTables.colGroupCreatedAtMs] as int,
      updatedAtMs: row[NodeDexTables.colGroupUpdatedAtMs] as int,
    );
  }

  Map<String, Object?> _groupToRow(NodeGroup group) {
    return {
      NodeDexTables.colGroupId: group.id,
      NodeDexTables.colGroupName: group.name,
      NodeDexTables.colGroupColor: group.colorValue,
      NodeDexTables.colGroupIconKey: group.iconKey,
      NodeDexTables.colGroupSortOrder: group.sortOrder,
      NodeDexTables.colGroupCreatedAtMs: group.createdAtMs,
      NodeDexTables.colGroupUpdatedAtMs: group.updatedAtMs,
      NodeDexTables.colGroupDeletedAtMs: null,
    };
  }
}
