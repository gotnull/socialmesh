// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SQLite persistence for SPP v0.2 resource transfers (P4).
///
/// Database: `overlay_transfers.db`
/// Schema version: 1
///
/// Two tables:
///   - `overlay_transfers` — one row per transfer, composite PK
///     `(peer_endpoint_hint, resource_id)`.
///   - `overlay_transfer_chunks` — per-chunk payload bytes for the
///     receiver. Sender-side records do not store chunk bytes here
///     (the sender already owns the source data).
///
/// This database is deliberately **separate** from the legacy
/// `file_transfers.db` (schema v3) used by `SM_FILE_TRANSFER` v1.
/// Keeping them apart preserves the locked "overlay cannot perturb
/// legacy product traffic" rule and removes any migration risk on
/// live user data.
library;

import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import 'overlay_resource_models.dart';
import 'overlay_types.dart';

/// Schema version of `overlay_transfers.db`.
const int overlayResourceStoreSchemaVersion = 1;

/// SQLite-backed store for overlay transfer records + receiver chunks.
class OverlayResourceStore {
  static const _dbName = 'overlay_transfers.db';
  static const _transfersTable = 'overlay_transfers';
  static const _chunksTable = 'overlay_transfer_chunks';
  static const _dbVersion = 1;

  Database? _db;
  final String? _testDbPath;

  /// True when the underlying handle is open.
  bool get isOpen => _db != null && _db!.isOpen;

  /// Construct a new store. [testDbPath] overrides the on-disk
  /// location; tests use a tempfile.
  OverlayResourceStore({String? testDbPath}) : _testDbPath = testDbPath;

  /// Open the database, creating tables on first run.
  Future<void> init() async {
    if (_db != null) return;
    final String path;
    if (_testDbPath != null) {
      path = _testDbPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = p.join(dir.path, _dbName);
    }
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        if (_testDbPath == null) {
          await db.rawQuery('PRAGMA journal_mode=WAL');
        }
        await db.rawQuery('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        AppLogging.storage('Creating overlay_transfers.db v$version');
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        AppLogging.storage(
          'Upgrading overlay_transfers.db v$oldVersion -> v$newVersion',
        );
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $_transfersTable (
        peer_endpoint_hint  BLOB NOT NULL,
        resource_id         INTEGER NOT NULL,
        peer_node_num       INTEGER NOT NULL,
        link_id             INTEGER,
        role                INTEGER NOT NULL,
        state               INTEGER NOT NULL,
        total_bytes         INTEGER NOT NULL,
        chunk_size          INTEGER NOT NULL,
        chunk_count         INTEGER NOT NULL,
        sha256              BLOB,
        mime_type           TEXT,
        filename            TEXT,
        bitmap              BLOB NOT NULL,
        created_at_ms       INTEGER NOT NULL,
        last_activity_ms    INTEGER NOT NULL,
        expires_at_ms       INTEGER NOT NULL,
        retry_count         INTEGER NOT NULL DEFAULT 0,
        close_reason        INTEGER,
        closed_at_ms        INTEGER,
        PRIMARY KEY (peer_endpoint_hint, resource_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $_chunksTable (
        peer_endpoint_hint  BLOB NOT NULL,
        resource_id         INTEGER NOT NULL,
        chunk_index         INTEGER NOT NULL,
        data                BLOB NOT NULL,
        PRIMARY KEY (peer_endpoint_hint, resource_id, chunk_index)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_overlay_transfers_state '
      'ON $_transfersTable(state, expires_at_ms)',
    );
    await db.execute(
      'CREATE INDEX idx_overlay_transfers_peer '
      'ON $_transfersTable(peer_endpoint_hint, state)',
    );
  }

  Database get _database {
    final db = _db;
    if (db == null || !db.isOpen) {
      throw StateError(
        'OverlayResourceStore not initialized — call init() first',
      );
    }
    return db;
  }

  /// Close the database handle. Idempotent.
  Future<void> close() async {
    final db = _db;
    if (db == null) return;
    if (db.isOpen) await db.close();
    _db = null;
  }

  // ---------------------------------------------------------------
  // Transfer CRUD.
  // ---------------------------------------------------------------

  /// Insert-or-replace a transfer row.
  Future<void> upsertTransfer(OverlayResourceRecord r) async {
    await _database.insert(
      _transfersTable,
      _rowFromRecord(r),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Primary lookup.
  Future<OverlayResourceRecord?> getTransfer(
    Uint8List peerEndpointHint,
    int resourceId,
  ) async {
    final rows = await _database.query(
      _transfersTable,
      where: 'peer_endpoint_hint = ? AND resource_id = ?',
      whereArgs: [peerEndpointHint, resourceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _recordFromRow(rows.first);
  }

  /// Load every transfer row regardless of state.
  Future<List<OverlayResourceRecord>> loadAll() async {
    final rows = await _database.query(_transfersTable);
    return rows.map(_recordFromRow).toList(growable: false);
  }

  /// Load every resumable transfer: sender rows in `transferring`,
  /// receiver rows in `receiving`. Used by
  /// `OverlayResourceEngine.restore`.
  Future<List<OverlayResourceRecord>> loadResumable() async {
    final rows = await _database.query(
      _transfersTable,
      where: 'state IN (?, ?)',
      whereArgs: [
        OverlayResourceState.transferring.code,
        OverlayResourceState.receiving.code,
      ],
    );
    return rows.map(_recordFromRow).toList(growable: false);
  }

  /// Load non-terminal rows for tick-driven expiry checks.
  Future<List<OverlayResourceRecord>> loadNonTerminal() async {
    final rows = await _database.query(
      _transfersTable,
      where: 'state NOT IN (?, ?, ?, ?, ?)',
      whereArgs: [
        OverlayResourceState.complete.code,
        OverlayResourceState.failed.code,
        OverlayResourceState.cancelled.code,
        OverlayResourceState.declined.code,
        OverlayResourceState.corrupt.code,
      ],
    );
    return rows.map(_recordFromRow).toList(growable: false);
  }

  /// Delete every terminal transfer + its chunks whose `closed_at_ms`
  /// is older than [cutoffMs]. Returns the number of transfer rows
  /// removed.
  Future<int> pruneTerminalOlderThan(int cutoffMs) async {
    final batch = _database.batch();
    final targets = await _database.query(
      _transfersTable,
      columns: ['peer_endpoint_hint', 'resource_id'],
      where:
          'state IN (?, ?, ?, ?, ?) AND closed_at_ms IS NOT NULL '
          'AND closed_at_ms < ?',
      whereArgs: [
        OverlayResourceState.complete.code,
        OverlayResourceState.failed.code,
        OverlayResourceState.cancelled.code,
        OverlayResourceState.declined.code,
        OverlayResourceState.corrupt.code,
        cutoffMs,
      ],
    );
    for (final row in targets) {
      final hint = _asBytes(row['peer_endpoint_hint']);
      final rid = row['resource_id']! as int;
      batch.delete(
        _chunksTable,
        where: 'peer_endpoint_hint = ? AND resource_id = ?',
        whereArgs: [hint, rid],
      );
      batch.delete(
        _transfersTable,
        where: 'peer_endpoint_hint = ? AND resource_id = ?',
        whereArgs: [hint, rid],
      );
    }
    await batch.commit(noResult: true);
    return targets.length;
  }

  /// Delete a specific transfer and all its chunks.
  Future<void> deleteTransfer(
    Uint8List peerEndpointHint,
    int resourceId,
  ) async {
    final batch = _database.batch();
    batch.delete(
      _chunksTable,
      where: 'peer_endpoint_hint = ? AND resource_id = ?',
      whereArgs: [peerEndpointHint, resourceId],
    );
    batch.delete(
      _transfersTable,
      where: 'peer_endpoint_hint = ? AND resource_id = ?',
      whereArgs: [peerEndpointHint, resourceId],
    );
    await batch.commit(noResult: true);
  }

  /// Count transfer rows (diagnostics).
  Future<int> transferCount() async {
    final r = await _database.rawQuery(
      'SELECT COUNT(*) AS c FROM $_transfersTable',
    );
    return (r.first['c'] as int?) ?? 0;
  }

  // ---------------------------------------------------------------
  // Chunk CRUD (receiver-side).
  // ---------------------------------------------------------------

  /// Insert-or-replace a chunk payload.
  Future<void> putChunk({
    required Uint8List peerEndpointHint,
    required int resourceId,
    required int chunkIndex,
    required Uint8List data,
  }) async {
    await _database.insert(_chunksTable, {
      'peer_endpoint_hint': peerEndpointHint,
      'resource_id': resourceId,
      'chunk_index': chunkIndex,
      'data': data,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Read a single chunk, or null if missing.
  Future<Uint8List?> getChunk({
    required Uint8List peerEndpointHint,
    required int resourceId,
    required int chunkIndex,
  }) async {
    final rows = await _database.query(
      _chunksTable,
      where: 'peer_endpoint_hint = ? AND resource_id = ? AND chunk_index = ?',
      whereArgs: [peerEndpointHint, resourceId, chunkIndex],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _asBytes(rows.first['data']);
  }

  /// Diagnostic chunk-row count for a transfer.
  Future<int> chunkCount({
    required Uint8List peerEndpointHint,
    required int resourceId,
  }) async {
    final r = await _database.rawQuery(
      'SELECT COUNT(*) AS c FROM $_chunksTable '
      'WHERE peer_endpoint_hint = ? AND resource_id = ?',
      [peerEndpointHint, resourceId],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  /// Assemble the full resource payload by concatenating chunks in
  /// index order. Returns null if any chunk is missing. Intended
  /// for integrity verification at completion time.
  Future<Uint8List?> assembleResource({
    required Uint8List peerEndpointHint,
    required int resourceId,
    required int chunkCount,
  }) async {
    if (chunkCount == 0) return Uint8List(0);
    final rows = await _database.query(
      _chunksTable,
      where: 'peer_endpoint_hint = ? AND resource_id = ?',
      whereArgs: [peerEndpointHint, resourceId],
      orderBy: 'chunk_index ASC',
    );
    if (rows.length != chunkCount) return null;
    final builder = BytesBuilder(copy: false);
    for (var i = 0; i < chunkCount; i++) {
      final row = rows[i];
      final idx = row['chunk_index']! as int;
      if (idx != i) return null;
      builder.add(_asBytes(row['data']));
    }
    return builder.toBytes();
  }

  // ---------------------------------------------------------------
  // Row <-> record mapping.
  // ---------------------------------------------------------------

  Map<String, Object?> _rowFromRecord(OverlayResourceRecord r) => {
    'peer_endpoint_hint': r.peerEndpointHint,
    'resource_id': r.resourceId,
    'peer_node_num': r.peerNodeNum,
    'link_id': r.linkId,
    'role': r.role.code,
    'state': r.state.code,
    'total_bytes': r.totalBytes,
    'chunk_size': r.chunkSize,
    'chunk_count': r.chunkCount,
    'sha256': r.sha256,
    'mime_type': r.mimeType,
    'filename': r.filename,
    'bitmap': r.bitmap,
    'created_at_ms': r.createdAtMs,
    'last_activity_ms': r.lastActivityMs,
    'expires_at_ms': r.expiresAtMs,
    'retry_count': r.retryCount,
    'close_reason': r.closeReason?.code,
    'closed_at_ms': r.closedAtMs,
  };

  OverlayResourceRecord _recordFromRow(Map<String, Object?> row) {
    final roleCode = row['role']! as int;
    final role =
        OverlayResourceRole.fromCode(roleCode) ?? OverlayResourceRole.sender;
    final stateCode = row['state']! as int;
    final state =
        OverlayResourceState.fromCode(stateCode) ?? OverlayResourceState.failed;
    final reasonCode = row['close_reason'] as int?;
    final reason = reasonCode == null
        ? null
        : OverlayLinkCloseReason.fromCode(reasonCode);
    return OverlayResourceRecord(
      resourceId: row['resource_id']! as int,
      peerEndpointHint: _asBytes(row['peer_endpoint_hint']),
      peerNodeNum: row['peer_node_num']! as int,
      linkId: row['link_id'] as int?,
      role: role,
      state: state,
      totalBytes: row['total_bytes']! as int,
      chunkSize: row['chunk_size']! as int,
      chunkCount: row['chunk_count']! as int,
      sha256: row['sha256'] == null ? null : _asBytes(row['sha256']),
      mimeType: row['mime_type'] as String?,
      filename: row['filename'] as String?,
      bitmap: _asBytes(row['bitmap']),
      createdAtMs: row['created_at_ms']! as int,
      lastActivityMs: row['last_activity_ms']! as int,
      expiresAtMs: row['expires_at_ms']! as int,
      retryCount: row['retry_count']! as int,
      closeReason: reason,
      closedAtMs: row['closed_at_ms'] as int?,
    );
  }

  Uint8List _asBytes(Object? raw) {
    if (raw is Uint8List) return Uint8List.fromList(raw);
    if (raw is List<Object?>) {
      return Uint8List.fromList(raw.cast<int>());
    }
    throw StateError('expected BLOB column, got ${raw?.runtimeType}');
  }
}
