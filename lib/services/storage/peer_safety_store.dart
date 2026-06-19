// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SQLite persistence for the local-only Trust + Safety layer.
///
/// Database: `peer_safety.db`
/// Schema version: 1
///
/// Single table `peer_safety` keyed by Meshtastic node id. Holds:
/// - Per-peer safety state (`trusted | neutral | muted | blocked | unsafe`)
/// - First-handshake-accepted marker (the timestamp of the user's
///   first explicit Accept on a HS_HELLO from this peer; used to gate
///   the first-contact warning UX)
/// - Optional reason code, freeform notes, blocked/muted timestamps.
///
/// HARD RULES:
/// - Local-only. Never transmitted on the wire. No bytes from this
///   table travel through any SIP / overlay / MRRP frame ever.
/// - Never synced to a server. Never sent through Firestore, Cloud
///   Functions, or any backend.
/// - Schema is independent of all other live user tables
///   (messages.db, signals.db, packet_dedupe.db, routes.db,
///   nodedex.db, traceroute.db). Adding T+S does NOT mutate them.
library;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/logging.dart';

/// Local-only safety state for a peer.
///
/// `unsafe` and `trusted` are reserved for v2+ — schema columns are
/// present so a future user-facing UI can surface them without a
/// migration.
enum NodeSafetyState {
  trusted('trusted'),
  neutral('neutral'),
  muted('muted'),
  blocked('blocked'),
  unsafe('unsafe');

  final String code;
  const NodeSafetyState(this.code);

  static NodeSafetyState fromCode(String? code) {
    if (code == null) return neutral;
    for (final s in values) {
      if (s.code == code) return s;
    }
    return neutral;
  }
}

/// Immutable record of a peer's local safety metadata.
class PeerSafetyRecord {
  /// Meshtastic node id (peer being tracked).
  final int peerNodeId;

  /// Current safety state for the peer.
  final NodeSafetyState state;

  /// Wall-clock ms of the first Accept the local user has issued on a
  /// HS_HELLO from this peer. Null when no Accept has ever fired —
  /// used to gate the first-contact warning UX.
  final int? firstHandshakeMs;

  /// Wall-clock ms when the peer was blocked. Null when not blocked.
  final int? blockedAtMs;

  /// Wall-clock ms when the peer was muted. Null when not muted.
  final int? mutedAtMs;

  /// Optional short reason code. Local-only; never transmitted.
  /// Examples: `unsolicited_dm`, `spam`, `harassment`.
  final String? reasonCode;

  /// Optional freeform notes. Local-only; never transmitted.
  final String? notes;

  /// Wall-clock ms of the most recent state change. Set on every
  /// upsert that touches `state`.
  final int lastStateChangeMs;

  const PeerSafetyRecord({
    required this.peerNodeId,
    required this.state,
    required this.lastStateChangeMs,
    this.firstHandshakeMs,
    this.blockedAtMs,
    this.mutedAtMs,
    this.reasonCode,
    this.notes,
  });

  PeerSafetyRecord copyWith({
    int? peerNodeId,
    NodeSafetyState? state,
    int? firstHandshakeMs,
    int? blockedAtMs,
    int? mutedAtMs,
    String? reasonCode,
    String? notes,
    int? lastStateChangeMs,
    // Explicit clear flags. Dart's `field: null` collides with the
    // `??` keep-existing pattern, so we surface a separate boolean
    // for every nullable field that ever needs to be set back to
    // null (e.g. `blockedAtMs` on unblock).
    bool clearFirstHandshakeMs = false,
    bool clearBlockedAtMs = false,
    bool clearMutedAtMs = false,
    bool clearReasonCode = false,
    bool clearNotes = false,
  }) {
    return PeerSafetyRecord(
      peerNodeId: peerNodeId ?? this.peerNodeId,
      state: state ?? this.state,
      firstHandshakeMs: clearFirstHandshakeMs
          ? null
          : (firstHandshakeMs ?? this.firstHandshakeMs),
      blockedAtMs: clearBlockedAtMs ? null : (blockedAtMs ?? this.blockedAtMs),
      mutedAtMs: clearMutedAtMs ? null : (mutedAtMs ?? this.mutedAtMs),
      reasonCode: clearReasonCode ? null : (reasonCode ?? this.reasonCode),
      notes: clearNotes ? null : (notes ?? this.notes),
      lastStateChangeMs: lastStateChangeMs ?? this.lastStateChangeMs,
    );
  }
}

/// Schema version of `peer_safety.db`.
const int peerSafetyStoreSchemaVersion = 1;

/// SQLite-backed local-only store for [PeerSafetyRecord]s.
class PeerSafetyStore {
  static const _dbName = 'peer_safety.db';
  static const _tableName = 'peer_safety';
  static const _dbVersion = peerSafetyStoreSchemaVersion;

  Database? _db;
  final String? _testDbPath;

  /// Construct a new store. Pass [_testDbPath] (e.g. an in-memory or
  /// tempfile path) for tests; production opens
  /// `getApplicationDocumentsDirectory()/peer_safety.db`.
  PeerSafetyStore({this._testDbPath});

  /// True when the underlying SQLite handle is open.
  bool get isOpen => _db != null && _db!.isOpen;

  /// Open the database, creating tables on first run. Idempotent.
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
        AppLogging.storage('Creating peer_safety.db v$version');
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        AppLogging.storage(
          'Upgrading peer_safety.db v$oldVersion -> v$newVersion',
        );
        // No migrations yet — schema v1 is the baseline.
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        peer_node_id           INTEGER PRIMARY KEY,
        safety_state           TEXT NOT NULL DEFAULT 'neutral',
        first_handshake_ms     INTEGER,
        blocked_at_ms          INTEGER,
        muted_at_ms            INTEGER,
        reason_code            TEXT,
        notes                  TEXT,
        last_state_change_ms   INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_peer_safety_state ON $_tableName(safety_state)',
    );
    await db.execute(
      'CREATE INDEX idx_peer_safety_handshake '
      'ON $_tableName(first_handshake_ms)',
    );
  }

  Database get _database {
    final db = _db;
    if (db == null || !db.isOpen) {
      throw StateError('PeerSafetyStore not initialized — call init() first');
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

  /// Insert or replace [record]. The full row is rewritten — callers
  /// should fetch the current record and use [PeerSafetyRecord.copyWith]
  /// to mutate fields rather than passing partial data.
  Future<void> upsert(PeerSafetyRecord record) async {
    await _database.insert(
      _tableName,
      _rowFromRecord(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Look up a record by node id, or null if absent.
  Future<PeerSafetyRecord?> getByPeerNodeId(int peerNodeId) async {
    final rows = await _database.query(
      _tableName,
      where: 'peer_node_id = ?',
      whereArgs: [peerNodeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _recordFromRow(rows.first);
  }

  /// All records currently in [state].
  Future<List<PeerSafetyRecord>> getByState(NodeSafetyState state) async {
    final rows = await _database.query(
      _tableName,
      where: 'safety_state = ?',
      whereArgs: [state.code],
    );
    return rows.map(_recordFromRow).toList(growable: false);
  }

  /// All node ids currently in `blocked` state.
  Future<List<int>> getBlockedPeerNodeIds() async {
    final rows = await _database.query(
      _tableName,
      columns: ['peer_node_id'],
      where: 'safety_state = ?',
      whereArgs: [NodeSafetyState.blocked.code],
    );
    return rows.map((r) => r['peer_node_id']! as int).toList(growable: false);
  }

  /// All node ids currently in `muted` state.
  Future<List<int>> getMutedPeerNodeIds() async {
    final rows = await _database.query(
      _tableName,
      columns: ['peer_node_id'],
      where: 'safety_state = ?',
      whereArgs: [NodeSafetyState.muted.code],
    );
    return rows.map((r) => r['peer_node_id']! as int).toList(growable: false);
  }

  /// All node ids that the local user has ever Accept-ed on a HS_HELLO
  /// from. Used by the first-contact-warning gate (no record / null
  /// `first_handshake_ms` ⇒ "first private contact").
  Future<List<int>> getHandshakenPeerNodeIds() async {
    final rows = await _database.query(
      _tableName,
      columns: ['peer_node_id'],
      where: 'first_handshake_ms IS NOT NULL',
    );
    return rows.map((r) => r['peer_node_id']! as int).toList(growable: false);
  }

  /// Drop the row for [peerNodeId]. Idempotent — no-op when absent.
  Future<int> delete(int peerNodeId) async {
    return _database.delete(
      _tableName,
      where: 'peer_node_id = ?',
      whereArgs: [peerNodeId],
    );
  }

  /// Diagnostics — total row count.
  Future<int> count() async {
    final rows = await _database.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $_tableName',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // -----------------------------------------------------------------
  // Row codec
  // -----------------------------------------------------------------

  Map<String, Object?> _rowFromRecord(PeerSafetyRecord r) {
    return {
      'peer_node_id': r.peerNodeId,
      'safety_state': r.state.code,
      'first_handshake_ms': r.firstHandshakeMs,
      'blocked_at_ms': r.blockedAtMs,
      'muted_at_ms': r.mutedAtMs,
      'reason_code': r.reasonCode,
      'notes': r.notes,
      'last_state_change_ms': r.lastStateChangeMs,
    };
  }

  PeerSafetyRecord _recordFromRow(Map<String, Object?> row) {
    return PeerSafetyRecord(
      peerNodeId: row['peer_node_id']! as int,
      state: NodeSafetyState.fromCode(row['safety_state'] as String?),
      firstHandshakeMs: row['first_handshake_ms'] as int?,
      blockedAtMs: row['blocked_at_ms'] as int?,
      mutedAtMs: row['muted_at_ms'] as int?,
      reasonCode: row['reason_code'] as String?,
      notes: row['notes'] as String?,
      lastStateChangeMs: row['last_state_change_ms']! as int,
    );
  }
}
