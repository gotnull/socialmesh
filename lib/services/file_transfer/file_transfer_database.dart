// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/logging.dart';
import '../protocol/socialmesh/sm_file_transfer.dart';
import 'file_transfer_engine.dart';

/// Persistent storage for file transfer state and chunk data.
///
/// Uses a dedicated SQLite database (file_transfers.db) following the
/// existing Socialmesh database patterns.
class FileTransferDatabase {
  static const _dbName = 'file_transfers.db';
  static const _dbVersion = 3;

  static const _transfersTable = 'transfers';
  static const _chunksTable = 'chunks';

  Database? _db;
  final Completer<void> _initCompleter = Completer<void>();
  bool _initStarted = false;

  /// Initialize the database.
  Future<void> init() async {
    if (_initStarted) {
      await _initCompleter.future;
      return;
    }
    _initStarted = true;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dir.path, _dbName);

      _db = await openDatabase(
        dbPath,
        version: _dbVersion,
        onConfigure: (db) async {
          final walResult = await db.rawQuery('PRAGMA journal_mode=WAL');
          // WAL assertion skipped — WAL is requested but only verified
          // for on-disk databases. Log instead of asserting to avoid
          // crashing in edge cases where the journal mode differs.
          if (walResult.isEmpty || walResult.first['journal_mode'] != 'wal') {
            AppLogging.fileTransfer(
              'FileTransferDatabase: WAL mode not active, got: $walResult',
            ); // lint-allow: hardcoded-string
          }
        },
        onCreate: (db, version) async {
          AppLogging.fileTransfer('DB: creating tables (v$version)');
          await _createTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          AppLogging.fileTransfer('DB: upgrading v$oldVersion → v$newVersion');
          if (oldVersion < 2) {
            // v2: added offerPending state (shifts enum indexes). Drop and
            // re-create while the feature is pre-release.
            await db.execute('DROP TABLE IF EXISTS $_chunksTable');
            await db.execute('DROP TABLE IF EXISTS $_transfersTable');
            await _createTables(db);
          }
          if (oldVersion < 3) {
            // v3: added savedFilePath for automatic disk persistence.
            // Safe nullable column addition — no data loss.
            await db.execute(
              'ALTER TABLE $_transfersTable ADD COLUMN savedFilePath TEXT',
            );
          }
        },
      );

      AppLogging.fileTransfer('DB: opened at $dbPath');

      _initCompleter.complete();
    } catch (e) {
      AppLogging.fileTransfer('DB: init failed: $e');
      _initCompleter.completeError(e);
      rethrow;
    }
  }

  Future<void> _createTables(Database db) async {
    final batch = db.batch();

    // Transfer metadata table.
    batch.execute('''
      CREATE TABLE $_transfersTable (
        fileIdHex TEXT PRIMARY KEY,
        fileId BLOB NOT NULL,
        direction INTEGER NOT NULL,
        state INTEGER NOT NULL,
        filename TEXT NOT NULL,
        mimeType TEXT NOT NULL,
        totalBytes INTEGER NOT NULL,
        chunkSize INTEGER NOT NULL,
        chunkCount INTEGER NOT NULL,
        sha256Hash BLOB NOT NULL,
        targetNodeNum INTEGER,
        sourceNodeNum INTEGER,
        completedChunks TEXT NOT NULL DEFAULT '',
        nackRounds INTEGER NOT NULL DEFAULT 0,
        failReason INTEGER,
        createdAt INTEGER NOT NULL,
        expiresAt INTEGER NOT NULL,
        completedAt INTEGER,
        transportMode INTEGER NOT NULL DEFAULT 0,
        fetchHint TEXT NOT NULL DEFAULT '',
        savedFilePath TEXT
      )
    ''');

    batch.execute('''
      CREATE INDEX idx_transfers_state ON $_transfersTable (state)
    ''');

    batch.execute('''
      CREATE INDEX idx_transfers_expiresAt ON $_transfersTable (expiresAt)
    ''');

    // Chunk data table for inbound partial transfers.
    batch.execute('''
      CREATE TABLE $_chunksTable (
        fileIdHex TEXT NOT NULL,
        chunkIndex INTEGER NOT NULL,
        payload BLOB NOT NULL,
        PRIMARY KEY (fileIdHex, chunkIndex),
        FOREIGN KEY (fileIdHex) REFERENCES $_transfersTable(fileIdHex) ON DELETE CASCADE
      )
    ''');

    await batch.commit(noResult: true);
  }

  /// Save or update a transfer state.
  Future<void> saveTransfer(FileTransferState transfer) async {
    final db = _db;
    if (db == null) return;

    AppLogging.fileTransfer(
      'DB: saveTransfer ${transfer.fileIdHex} '
      'state=${transfer.state.name}, '
      '${transfer.completedChunks.length}/${transfer.chunkCount} chunks',
    );

    await db.insert(_transfersTable, {
      'fileIdHex': transfer.fileIdHex,
      'fileId': transfer.fileId,
      'direction': transfer.direction.index,
      'state': transfer.state.index,
      'filename': transfer.filename,
      'mimeType': transfer.mimeType,
      'totalBytes': transfer.totalBytes,
      'chunkSize': transfer.chunkSize,
      'chunkCount': transfer.chunkCount,
      'sha256Hash': transfer.sha256Hash,
      'targetNodeNum': transfer.targetNodeNum,
      'sourceNodeNum': transfer.sourceNodeNum,
      'completedChunks': transfer.completedChunks.join(','),
      'nackRounds': transfer.nackRounds,
      'failReason': transfer.failReason?.index,
      'createdAt': transfer.createdAt.millisecondsSinceEpoch,
      'expiresAt': transfer.expiresAt.millisecondsSinceEpoch,
      'completedAt': transfer.completedAt?.millisecondsSinceEpoch,
      'transportMode': transfer.transportMode.index,
      'fetchHint': transfer.fetchHint,
      'savedFilePath': transfer.savedFilePath,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update only the savedFilePath column for a completed transfer.
  ///
  /// Pass [path] as `null` to clear a stale path (e.g. after an iOS
  /// container UUID rotation invalidates a previously stored absolute path).
  /// More efficient than re-writing the full row when only the path changed.
  Future<void> updateSavedPath(String fileIdHex, String? path) async {
    final db = _db;
    if (db == null) return;

    await db.update(
      _transfersTable,
      {'savedFilePath': path},
      where: 'fileIdHex = ?',
      whereArgs: [fileIdHex],
    );

    AppLogging.fileTransfer('DB: updateSavedPath $fileIdHex → $path');
  }

  /// Save a received chunk.
  Future<void> saveChunk(
    String fileIdHex,
    int chunkIndex,
    Uint8List payload,
  ) async {
    final db = _db;
    if (db == null) return;

    AppLogging.fileTransfer(
      'DB: saveChunk $fileIdHex [$chunkIndex] ${payload.length} bytes',
    );

    await db.insert(_chunksTable, {
      'fileIdHex': fileIdHex,
      'chunkIndex': chunkIndex,
      'payload': payload,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Load all active (non-terminal) transfers.
  Future<List<FileTransferState>> loadActiveTransfers() async {
    final db = _db;
    if (db == null) return [];

    final rows = await db.query(
      _transfersTable,
      where: 'state < ?',
      whereArgs: [TransferState.complete.index],
    );

    final transfers = rows
        .map(_rowToTransfer)
        .whereType<FileTransferState>()
        .toList();

    AppLogging.fileTransfer(
      'DB: loadActiveTransfers found ${transfers.length} transfers '
      '(${rows.length - transfers.length} skipped)',
    );

    return transfers;
  }

  /// Load all transfers (for history/display).
  Future<List<FileTransferState>> loadAllTransfers({int limit = 50}) async {
    final db = _db;
    if (db == null) return [];

    final rows = await db.query(
      _transfersTable,
      orderBy: 'createdAt DESC',
      limit: limit,
    );

    final transfers = rows
        .map(_rowToTransfer)
        .whereType<FileTransferState>()
        .toList();

    AppLogging.fileTransfer(
      'DB: loadAllTransfers found ${transfers.length} transfers '
      '(limit=$limit, ${rows.length - transfers.length} skipped)',
    );

    return transfers;
  }

  /// Load transfers for a specific node.
  Future<List<FileTransferState>> loadTransfersForNode(int nodeNum) async {
    final db = _db;
    if (db == null) return [];

    final rows = await db.query(
      _transfersTable,
      where: 'targetNodeNum = ? OR sourceNodeNum = ?',
      whereArgs: [nodeNum, nodeNum],
      orderBy: 'createdAt DESC',
    );

    final transfers = rows
        .map(_rowToTransfer)
        .whereType<FileTransferState>()
        .toList();

    AppLogging.fileTransfer(
      'DB: loadTransfersForNode '
      '${nodeNum.toRadixString(16)} found ${transfers.length} '
      '(${rows.length - transfers.length} skipped)',
    );

    return transfers;
  }

  /// Load stored chunks for a transfer (for resumption).
  Future<Map<int, Uint8List>> loadChunks(String fileIdHex) async {
    final db = _db;
    if (db == null) return {};

    final rows = await db.query(
      _chunksTable,
      where: 'fileIdHex = ?',
      whereArgs: [fileIdHex],
    );

    final chunks = <int, Uint8List>{};
    for (final row in rows) {
      final index = row['chunkIndex'] as int;
      final payload = row['payload'] as Uint8List;
      chunks[index] = payload;
    }
    return chunks;
  }

  /// Delete a transfer and its chunks.
  Future<void> deleteTransfer(String fileIdHex) async {
    final db = _db;
    if (db == null) return;

    AppLogging.fileTransfer('DB: deleteTransfer $fileIdHex');

    await db.delete(
      _chunksTable,
      where: 'fileIdHex = ?',
      whereArgs: [fileIdHex],
    );
    await db.delete(
      _transfersTable,
      where: 'fileIdHex = ?',
      whereArgs: [fileIdHex],
    );
  }

  /// Delete only chunks for a transfer (keeps transfer metadata).
  ///
  /// Called when a transfer reaches a terminal state (complete, failed,
  /// cancelled) to free chunk storage while preserving history.
  Future<void> deleteChunks(String fileIdHex) async {
    final db = _db;
    if (db == null) return;

    final count = await db.delete(
      _chunksTable,
      where: 'fileIdHex = ?',
      whereArgs: [fileIdHex],
    );

    if (count > 0) {
      AppLogging.fileTransfer(
        'DB: deleteChunks $fileIdHex removed $count rows',
      );
    }
  }

  /// Purge expired transfers and their chunks.
  Future<int> purgeExpired() async {
    final db = _db;
    if (db == null) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Find expired transfer IDs.
    final rows = await db.query(
      _transfersTable,
      columns: ['fileIdHex'],
      where: 'expiresAt < ? AND state < ?',
      whereArgs: [now, TransferState.complete.index],
    );

    var count = 0;
    for (final row in rows) {
      final id = row['fileIdHex'] as String;
      await deleteTransfer(id);
      count++;
    }

    if (count > 0) {
      AppLogging.fileTransfer('DB: purgeExpired removed $count transfers');
    }

    return count;
  }

  /// Close the database.
  Future<void> close() async {
    AppLogging.fileTransfer('DB: closing');
    await _db?.close();
    _db = null;
  }

  /// Parse a single DB row into [FileTransferState].
  ///
  /// Returns `null` if the row is malformed (invalid enum index, corrupt
  /// data, etc.). Callers must skip null results so one bad row does not
  /// crash recovery for all other transfers.
  FileTransferState? _rowToTransfer(Map<String, Object?> row) {
    try {
      final completedStr = row['completedChunks'] as String? ?? '';
      final completedChunks = completedStr.isEmpty
          ? <int>{}
          : completedStr.split(',').map(int.parse).toSet();

      final directionIdx = row['direction'] as int;
      final stateIdx = row['state'] as int;
      final transportModeIdx = row['transportMode'] as int;
      final failReasonIdx = row['failReason'] as int?;
      final completedAtMs = row['completedAt'] as int?;

      // Bounds-check enum indexes to prevent RangeError.
      if (directionIdx < 0 || directionIdx >= TransferDirection.values.length) {
        throw RangeError('direction index $directionIdx out of range');
      }
      if (stateIdx < 0 || stateIdx >= TransferState.values.length) {
        throw RangeError('state index $stateIdx out of range');
      }
      if (transportModeIdx < 0 ||
          transportModeIdx >= FileTransportMode.values.length) {
        throw RangeError('transportMode index $transportModeIdx out of range');
      }
      if (failReasonIdx != null &&
          (failReasonIdx < 0 ||
              failReasonIdx >= TransferFailReason.values.length)) {
        throw RangeError('failReason index $failReasonIdx out of range');
      }

      return FileTransferState(
        fileIdHex: row['fileIdHex'] as String,
        fileId: row['fileId'] as Uint8List,
        direction: TransferDirection.values[directionIdx],
        state: TransferState.values[stateIdx],
        filename: row['filename'] as String,
        mimeType: row['mimeType'] as String,
        totalBytes: row['totalBytes'] as int,
        chunkSize: row['chunkSize'] as int,
        chunkCount: row['chunkCount'] as int,
        sha256Hash: row['sha256Hash'] as Uint8List,
        targetNodeNum: row['targetNodeNum'] as int?,
        sourceNodeNum: row['sourceNodeNum'] as int?,
        completedChunks: completedChunks,
        nackRounds: row['nackRounds'] as int,
        failReason: failReasonIdx != null
            ? TransferFailReason.values[failReasonIdx]
            : null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(row['expiresAt'] as int),
        completedAt: completedAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(completedAtMs)
            : null,
        transportMode: FileTransportMode.values[transportModeIdx],
        fetchHint: row['fetchHint'] as String? ?? '',
        savedFilePath: row['savedFilePath'] as String?,
      );
    } catch (e) {
      final id = row['fileIdHex'] ?? 'unknown';
      AppLogging.fileTransfer('DB: skipping malformed transfer row $id: $e');
      return null;
    }
  }
}
