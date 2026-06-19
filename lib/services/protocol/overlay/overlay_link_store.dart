// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SQLite persistence for [OverlayLinkEngine].
///
/// Database: `links.db`
/// Schema version: 1
///
/// Single table `overlay_links` keyed by the 4-byte `link_id`. Every
/// column is anchored to `docs/sip/OVERLAY_V0_2.md` §13.1. Link keys
/// (tx/rx AEAD keys for §12 secure mode) are NEVER stored here; they
/// live only in `FlutterSecureStorage`.
library;

import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import 'overlay_link_models.dart';
import 'overlay_types.dart';

/// Schema version of `links.db`.
const int overlayLinkStoreSchemaVersion = 1;

/// SQLite-backed store for overlay link records.
///
/// Thread safety: every mutating method serialises internally via
/// sqflite's connection lock; callers that require stronger ordering
/// (for read-modify-write flows) must hold [OverlayLinkEngine]'s
/// mutation lock instead.
class OverlayLinkStore {
  static const _dbName = 'links.db';
  static const _tableName = 'overlay_links';
  static const _dbVersion = 1;

  Database? _db;
  final String? _testDbPath;

  /// True when the underlying SQLite handle is open.
  bool get isOpen => _db != null && _db!.isOpen;

  /// Construct a new store. [_testDbPath] overrides the on-disk
  /// location (use `':memory:'` for in-memory SQLite in tests).
  OverlayLinkStore({this._testDbPath});

  /// Open the database, creating tables on first run.
  Future<void> init() async {
    if (_db != null) return;

    final String dbPath;
    if (_testDbPath != null) {
      dbPath = _testDbPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      dbPath = p.join(dir.path, _dbName);
    }

    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: (db) async {
        if (_testDbPath == null) {
          await db.rawQuery('PRAGMA journal_mode=WAL');
        }
      },
      onCreate: (db, version) async {
        AppLogging.storage('Creating links.db v$version');
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        AppLogging.storage('Upgrading links.db v$oldVersion -> v$newVersion');
        // No migrations yet — schema v1 is the baseline.
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        link_id              INTEGER PRIMARY KEY,
        peer_persona_hint    BLOB NOT NULL,
        peer_node_num        INTEGER NOT NULL,
        state                INTEGER NOT NULL,
        is_initiator         INTEGER NOT NULL,
        supported_features   INTEGER NOT NULL DEFAULT 0,
        max_chunk_bytes      INTEGER,
        max_resource_bytes   INTEGER,
        opened_at_ms         INTEGER NOT NULL,
        last_activity_ms     INTEGER NOT NULL,
        expires_at_ms        INTEGER NOT NULL,
        tx_next_seq          INTEGER NOT NULL DEFAULT 0,
        tx_ack_hi            INTEGER NOT NULL DEFAULT 0,
        rx_expected_seq      INTEGER NOT NULL DEFAULT 0,
        retry_count          INTEGER NOT NULL DEFAULT 0,
        close_reason         INTEGER,
        closed_at_ms         INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_overlay_links_peer '
      'ON $_tableName(peer_persona_hint, state)',
    );
    await db.execute(
      'CREATE INDEX idx_overlay_links_expires '
      'ON $_tableName(expires_at_ms)',
    );
    await db.execute(
      'CREATE INDEX idx_overlay_links_state_closed '
      'ON $_tableName(state, closed_at_ms)',
    );
  }

  Database get _database {
    final db = _db;
    if (db == null || !db.isOpen) {
      throw StateError('OverlayLinkStore not initialized — call init() first');
    }
    return db;
  }

  /// Close the database. Idempotent.
  Future<void> close() async {
    final db = _db;
    if (db == null) return;
    if (db.isOpen) await db.close();
    _db = null;
  }

  /// Insert-or-replace a record.
  Future<void> upsert(OverlayLinkRecord record) async {
    await _database.insert(
      _tableName,
      _rowFromRecord(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Load a record by its 4-byte link id, or null if none.
  Future<OverlayLinkRecord?> getByLinkId(int linkId) async {
    final rows = await _database.query(
      _tableName,
      where: 'link_id = ?',
      whereArgs: [linkId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _recordFromRow(rows.first);
  }

  /// Load the most recently opened non-terminal record for the given
  /// peer persona, or null if none. Used by the engine when applying
  /// the "one active link per peer" rule.
  Future<OverlayLinkRecord?> getActiveForPeer(Uint8List peerPersonaHint) async {
    final rows = await _database.query(
      _tableName,
      where: 'peer_persona_hint = ? AND state IN (?, ?, ?, ?)',
      whereArgs: [
        peerPersonaHint,
        OverlayLinkState.opening.code,
        OverlayLinkState.active.code,
        OverlayLinkState.stale.code,
        OverlayLinkState.draining.code,
      ],
      orderBy: 'opened_at_ms DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _recordFromRow(rows.first);
  }

  /// Load every non-terminal record for a given peer node num, in
  /// `link_id` ascending order. Used for simultaneous-open tie-break:
  /// at auto-open time we only know the peer's SIP node num, not the
  /// real persona hint (that arrives inside the signed LINK_OPEN body),
  /// so [getActiveForPeer] can't match across synthetic vs real hints.
  /// Looking up by `peer_node_num` bridges the two views so both
  /// initiator and responder records converge on one canonical link.
  Future<List<OverlayLinkRecord>> getNonTerminalForPeerNode(
    int peerNodeNum,
  ) async {
    final rows = await _database.query(
      _tableName,
      where: 'peer_node_num = ? AND state IN (?, ?, ?, ?)',
      whereArgs: [
        peerNodeNum,
        OverlayLinkState.opening.code,
        OverlayLinkState.active.code,
        OverlayLinkState.stale.code,
        OverlayLinkState.draining.code,
      ],
      orderBy: 'link_id ASC',
    );
    return rows.map(_recordFromRow).toList(growable: false);
  }

  /// Load every record regardless of state. Used on engine startup for
  /// [OverlayLinkEngine.restore].
  Future<List<OverlayLinkRecord>> loadAll() async {
    final rows = await _database.query(_tableName);
    return rows.map(_recordFromRow).toList(growable: false);
  }

  /// Load every non-terminal record (active/stale/opening/draining).
  Future<List<OverlayLinkRecord>> loadNonTerminal() async {
    final rows = await _database.query(
      _tableName,
      where: 'state IN (?, ?, ?, ?)',
      whereArgs: [
        OverlayLinkState.opening.code,
        OverlayLinkState.active.code,
        OverlayLinkState.stale.code,
        OverlayLinkState.draining.code,
      ],
    );
    return rows.map(_recordFromRow).toList(growable: false);
  }

  /// Delete a link row. Only callers that have already persisted the
  /// final terminal state should invoke this (e.g., GC of closed rows
  /// past their retention window).
  Future<void> delete(int linkId) async {
    await _database.delete(
      _tableName,
      where: 'link_id = ?',
      whereArgs: [linkId],
    );
  }

  /// Delete every `closed`/`failed` row whose `closed_at_ms` is older
  /// than [cutoffMs]. Returns the number of rows deleted.
  Future<int> pruneClosedOlderThan(int cutoffMs) async {
    return _database.delete(
      _tableName,
      where:
          'state IN (?, ?) AND closed_at_ms IS NOT NULL '
          'AND closed_at_ms < ?',
      whereArgs: [
        OverlayLinkState.closed.code,
        OverlayLinkState.failed.code,
        cutoffMs,
      ],
    );
  }

  /// Count rows (diagnostics only).
  Future<int> count() async {
    final result = await _database.rawQuery(
      'SELECT COUNT(*) AS c FROM $_tableName',
    );
    return (result.first['c'] as int?) ?? 0;
  }

  // ---------------------------------------------------------------
  // Row <-> record mapping
  // ---------------------------------------------------------------

  Map<String, Object?> _rowFromRecord(OverlayLinkRecord r) => {
    'link_id': r.linkId,
    'peer_persona_hint': r.peerPersonaHint,
    'peer_node_num': r.peerNodeNum,
    'state': r.state.code,
    'is_initiator': r.isInitiator ? 1 : 0,
    'supported_features': r.capabilities.supportedFeatures,
    'max_chunk_bytes': r.capabilities.maxChunkBytes,
    'max_resource_bytes': r.capabilities.maxResourceBytes,
    'opened_at_ms': r.openedAtMs,
    'last_activity_ms': r.lastActivityMs,
    'expires_at_ms': r.expiresAtMs,
    'tx_next_seq': r.txNextSeq,
    'tx_ack_hi': r.txAckHi,
    'rx_expected_seq': r.rxExpectedSeq,
    'retry_count': r.retryCount,
    'close_reason': r.closeReason?.code,
    'closed_at_ms': r.closedAtMs,
  };

  OverlayLinkRecord _recordFromRow(Map<String, Object?> row) {
    final stateCode = row['state']! as int;
    final state =
        OverlayLinkState.fromCode(stateCode) ?? OverlayLinkState.failed;
    final reasonCode = row['close_reason'] as int?;
    final reason = reasonCode == null
        ? null
        : OverlayLinkCloseReason.fromCode(reasonCode);
    final hint = row['peer_persona_hint'];
    final hintBytes = hint is Uint8List
        ? Uint8List.fromList(hint)
        : Uint8List.fromList((hint as List<Object?>).cast<int>());
    return OverlayLinkRecord(
      linkId: row['link_id']! as int,
      peerPersonaHint: hintBytes,
      peerNodeNum: row['peer_node_num']! as int,
      state: state,
      isInitiator: (row['is_initiator']! as int) != 0,
      capabilities: OverlayLinkCapabilities(
        supportedFeatures: (row['supported_features'] as int?) ?? 0,
        maxChunkBytes: row['max_chunk_bytes'] as int?,
        maxResourceBytes: row['max_resource_bytes'] as int?,
      ),
      openedAtMs: row['opened_at_ms']! as int,
      lastActivityMs: row['last_activity_ms']! as int,
      expiresAtMs: row['expires_at_ms']! as int,
      txNextSeq: (row['tx_next_seq'] as int?) ?? 0,
      txAckHi: (row['tx_ack_hi'] as int?) ?? 0,
      rxExpectedSeq: (row['rx_expected_seq'] as int?) ?? 0,
      retryCount: (row['retry_count'] as int?) ?? 0,
      closeReason: reason,
      closedAtMs: row['closed_at_ms'] as int?,
    );
  }
}
