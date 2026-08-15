// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SQLite persistence for the mesh feed — canonical replicated post store.
///
/// Database: `mesh_feed.db`
/// Schema version: 1
///
/// Tables:
///   - `mesh_posts` — canonical post objects with deterministic IDs
///   - `mesh_post_receipts` — transport receipt metadata per post
///   - `mesh_sync_peers` — peer sync session metadata
library;

import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/logging.dart';
import '../../core/radio_scope.dart';
import 'mesh_post.dart';

/// Schema version for mesh_feed.db.
const int meshFeedSchemaVersion = 3;

/// Persistence layer for [MeshPost] objects and sync metadata.
class MeshFeedDatabase {
  MeshFeedDatabase({this._dbPathOverride});

  final String? _dbPathOverride;
  Database? _db;
  Completer<Database?>? _initCompleter;

  /// Whether the database is open and ready.
  bool get isOpen => _db != null;

  /// Open the database, creating tables if needed.
  Future<void> open() async {
    if (_db != null) return;
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }
    _initCompleter = Completer<Database?>();
    try {
      final path = _dbPathOverride ?? await _defaultPath();
      _db = await openDatabase(
        path,
        version: meshFeedSchemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: (db) async {
          final walResult = await db.rawQuery('PRAGMA journal_mode=WAL');
          // Only enforce WAL for on-disk databases. In-memory databases
          // (used in tests via _dbPathOverride) do not support WAL mode.
          if (_dbPathOverride == null) {
            assert(
              walResult.isNotEmpty && walResult.first['journal_mode'] == 'wal',
              'WAL mode not active',
            ); // lint-allow: hardcoded-string
          }
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );
      AppLogging.meshFeed('database opened (v$meshFeedSchemaVersion)');
      _initCompleter!.complete(_db);
    } catch (e) {
      AppLogging.meshFeed('database open FAILED: $e');
      _initCompleter!.complete(null);
    }
  }

  Future<String> _defaultPath() =>
      RadioScope.instance.databasePath('mesh_feed.db');

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE mesh_posts (
        id TEXT PRIMARY KEY,
        author_node_num INTEGER NOT NULL,
        created_at_ms INTEGER NOT NULL,
        content TEXT NOT NULL,
        ttl_class INTEGER NOT NULL DEFAULT 2,
        propagation_class INTEGER NOT NULL DEFAULT 0,
        schema_version INTEGER NOT NULL DEFAULT 1,
        expires_at_ms INTEGER,
        first_seen_at_ms INTEGER NOT NULL,
        last_seen_at_ms INTEGER NOT NULL,
        seen_via_transports TEXT NOT NULL DEFAULT '[]',
        hop_count INTEGER,
        is_local INTEGER NOT NULL DEFAULT 0,
        trust_score REAL,
        sync_state INTEGER NOT NULL DEFAULT 0,
        local_seq INTEGER,        sync_seq INTEGER,        lora_rebroadcast_at_ms INTEGER,
        updated_at_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_mesh_posts_expires
        ON mesh_posts(expires_at_ms)
    ''');
    await db.execute('''
      CREATE INDEX idx_mesh_posts_created
        ON mesh_posts(created_at_ms DESC)
    ''');
    await db.execute('''
      CREATE INDEX idx_mesh_posts_author
        ON mesh_posts(author_node_num)
    ''');
    await db.execute('''
      CREATE INDEX idx_mesh_posts_sync
        ON mesh_posts(sync_state)
    ''');
    await db.execute('''
      CREATE INDEX idx_mesh_posts_local_seq
        ON mesh_posts(local_seq)
    ''');
    await db.execute('''
      CREATE INDEX idx_mesh_posts_sync_seq
        ON mesh_posts(sync_seq)
    ''');
    await db.execute('''
      CREATE INDEX idx_mesh_posts_updated
        ON mesh_posts(updated_at_ms)
    ''');
    await db.execute('''
      CREATE INDEX idx_mesh_posts_lora_rebroadcast
        ON mesh_posts(lora_rebroadcast_at_ms)
    ''');

    await db.execute('''
      CREATE TABLE mesh_post_receipts (
        post_id TEXT NOT NULL
          REFERENCES mesh_posts(id) ON DELETE CASCADE,
        transport TEXT NOT NULL,
        peer_id TEXT,
        received_at_ms INTEGER NOT NULL,
        hop_count INTEGER,
        PRIMARY KEY (post_id, transport, received_at_ms)
      )
    ''');

    await db.execute('''
      CREATE TABLE mesh_sync_peers (
        peer_id TEXT PRIMARY KEY,
        display_name TEXT,
        last_seen_at_ms INTEGER NOT NULL,
        last_sync_at_ms INTEGER,
        sync_cursor_ms INTEGER,
        sync_cursor_seq INTEGER,
        transport TEXT NOT NULL,
        capabilities TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_sync_peers_last_seen
        ON mesh_sync_peers(last_seen_at_ms)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.meshFeed('migrating schema v$oldVersion → v$newVersion');
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE mesh_posts ADD COLUMN local_seq INTEGER');
      await db.execute(
        'ALTER TABLE mesh_posts ADD COLUMN lora_rebroadcast_at_ms INTEGER',
      );
      await db.execute(
        'ALTER TABLE mesh_posts '
        'ADD COLUMN updated_at_ms INTEGER NOT NULL DEFAULT 0',
      );
      // Backfill updated_at_ms from last_seen_at_ms for existing rows.
      await db.execute(
        'UPDATE mesh_posts SET updated_at_ms = last_seen_at_ms '
        'WHERE updated_at_ms = 0',
      );
      // Backfill local_seq from rowid for existing rows.
      await db.execute(
        'UPDATE mesh_posts SET local_seq = rowid WHERE local_seq IS NULL',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_mesh_posts_local_seq
          ON mesh_posts(local_seq)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_mesh_posts_updated
          ON mesh_posts(updated_at_ms)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_mesh_posts_lora_rebroadcast
          ON mesh_posts(lora_rebroadcast_at_ms)
      ''');
      await db.execute(
        'ALTER TABLE mesh_sync_peers ADD COLUMN sync_cursor_seq INTEGER',
      );
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE mesh_posts ADD COLUMN sync_seq INTEGER');
      // Backfill sync_seq from local_seq for existing rows (all are
      // already-replicated content — safe to expose to outbound sync).
      await db.execute(
        'UPDATE mesh_posts SET sync_seq = local_seq WHERE sync_seq IS NULL',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_mesh_posts_sync_seq
          ON mesh_posts(sync_seq)
      ''');
    }
  }

  Future<Database> _ensureDb() async {
    if (_db != null) return _db!;
    await open();
    if (_db == null) throw StateError('MeshFeedDatabase: failed to open');
    return _db!;
  }

  /// Close the database.
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initCompleter = null;
  }

  // ---------------------------------------------------------------------------
  // Posts CRUD
  // ---------------------------------------------------------------------------

  /// Insert or update a post. Returns true if a new row was created.
  ///
  /// On conflict (same deterministic ID), merges transport metadata and
  /// updates last_seen_at_ms. Content is NOT overwritten — canonical material
  /// is immutable. Assigns monotonic [local_seq] on every mutation.
  /// [sync_seq] is only assigned on INSERT (new content) — metadata-only
  /// merges do NOT bump sync_seq, preventing outbound churn loops.
  Future<bool> upsertPost(MeshPost post) async {
    final db = await _ensureDb();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final existing = await db.query(
      'mesh_posts',
      where: 'id = ?',
      whereArgs: [post.id],
      limit: 1,
    );

    // Get next monotonic sequence value.
    final seqResult = await db.rawQuery(
      'SELECT COALESCE(MAX(local_seq), 0) + 1 AS next_seq FROM mesh_posts',
    );
    final nextSeq = Sqflite.firstIntValue(seqResult) ?? 1;

    if (existing.isEmpty) {
      // Also compute sync_seq for new posts — may differ from local_seq
      // if a prior mutation bumped local_seq without inserting new content.
      final syncSeqResult = await db.rawQuery(
        'SELECT COALESCE(MAX(sync_seq), 0) + 1 AS next FROM mesh_posts',
      );
      final nextSyncSeq = Sqflite.firstIntValue(syncSeqResult) ?? 1;

      final row = post.toRow();
      row['local_seq'] = nextSeq;
      row['sync_seq'] = nextSyncSeq;
      row['updated_at_ms'] = nowMs;
      await db.insert('mesh_posts', row);
      AppLogging.meshFeed(
        'INSERT post=${post.id.substring(0, 8)}… '
        'seq=$nextSeq syncSeq=$nextSyncSeq author=${post.authorNodeNum}',
      );
      return true;
    }

    // Merge: update metadata only — canonical identity material is immutable.
    // Do NOT bump sync_seq — metadata merges are not outbound-sync-eligible.
    final existingPost = MeshPost.fromRow(existing.first);
    final mergedTransports = {
      ...existingPost.seenViaTransports,
      ...post.seenViaTransports,
    };

    await db.update(
      'mesh_posts',
      {
        'last_seen_at_ms': post.lastSeenAt.millisecondsSinceEpoch,
        'seen_via_transports':
            '[${mergedTransports.map((t) => '"${t.name}"').join(',')}]',
        if (post.hopCount != null &&
            (existingPost.hopCount == null ||
                post.hopCount! < existingPost.hopCount!))
          'hop_count': post.hopCount,
        if (post.trustScore != null) 'trust_score': post.trustScore,
        'local_seq': nextSeq,
        'updated_at_ms': nowMs,
      },
      where: 'id = ?',
      whereArgs: [post.id],
    );
    AppLogging.meshFeed(
      'MERGE post=${post.id.substring(0, 8)}… '
      'seq=$nextSeq transports=${mergedTransports.map((t) => t.name).join(",")}',
    );
    return false;
  }

  /// Add a transport receipt for an existing post.
  Future<void> addReceipt({
    required String postId,
    required MeshTransportType transport,
    String? peerId,
    int? hopCount,
  }) async {
    final db = await _ensureDb();
    await db.insert('mesh_post_receipts', {
      'post_id': postId,
      'transport': transport.name,
      'peer_id': peerId,
      'received_at_ms': DateTime.now().millisecondsSinceEpoch,
      'hop_count': hopCount,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Get all non-expired posts ordered by creation time descending.
  Future<List<MeshPost>> getActivePosts({int limit = 200}) async {
    final db = await _ensureDb();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'mesh_posts',
      where: 'expires_at_ms > ?',
      whereArgs: [nowMs],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(MeshPost.fromRow).toList();
  }

  /// Get posts eligible for sync (not expired, pending state).
  Future<List<MeshPost>> getSyncEligiblePosts({
    int? afterMs,
    int limit = 100,
  }) async {
    final db = await _ensureDb();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final where = StringBuffer('expires_at_ms > ? AND sync_state = 0');
    final args = <dynamic>[nowMs];
    if (afterMs != null) {
      where.write(' AND created_at_ms > ?');
      args.add(afterMs);
    }
    final rows = await db.query(
      'mesh_posts',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'created_at_ms ASC',
      limit: limit,
    );
    return rows.map(MeshPost.fromRow).toList();
  }

  /// Get a single post by ID.
  Future<MeshPost?> getPost(String id) async {
    final db = await _ensureDb();
    final rows = await db.query(
      'mesh_posts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MeshPost.fromRow(rows.first);
  }

  /// Delete expired posts and their receipts (cascade).
  Future<int> cleanupExpired() async {
    final db = await _ensureDb();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return db.delete(
      'mesh_posts',
      where: 'expires_at_ms <= ?',
      whereArgs: [nowMs],
    );
  }

  /// Count active (non-expired) posts.
  Future<int> countActivePosts() async {
    final db = await _ensureDb();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM mesh_posts WHERE expires_at_ms > ?',
      [nowMs],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Sync peers
  // ---------------------------------------------------------------------------

  /// Upsert a sync peer.
  Future<void> upsertSyncPeer({
    required String peerId,
    String? displayName,
    required MeshTransportType transport,
    int? syncCursorMs,
  }) async {
    final db = await _ensureDb();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // Use INSERT ... ON CONFLICT to preserve existing cursor columns.
    // ConflictAlgorithm.replace would DELETE the row and re-insert,
    // nuking sync_cursor_seq back to NULL — destroying cursor state.
    await db.rawInsert(
      '''
      INSERT INTO mesh_sync_peers
        (peer_id, display_name, last_seen_at_ms, last_sync_at_ms,
         sync_cursor_ms, transport)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(peer_id) DO UPDATE SET
        display_name = excluded.display_name,
        last_seen_at_ms = excluded.last_seen_at_ms,
        transport = excluded.transport
    ''',
      [
        peerId,
        displayName,
        nowMs,
        syncCursorMs != null ? nowMs : null,
        syncCursorMs,
        transport.name,
      ],
    );
  }

  /// Get the sync cursor for a peer (last synced timestamp).
  Future<int?> getSyncCursor(String peerId) async {
    final db = await _ensureDb();
    final rows = await db.query(
      'mesh_sync_peers',
      columns: ['sync_cursor_ms'],
      where: 'peer_id = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['sync_cursor_ms'] as int?;
  }

  /// Update sync cursor after successful sync.
  Future<void> updateSyncCursor(String peerId, int cursorMs) async {
    final db = await _ensureDb();
    await db.update(
      'mesh_sync_peers',
      {
        'sync_cursor_ms': cursorMs,
        'last_sync_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'peer_id = ?',
      whereArgs: [peerId],
    );
  }

  // ---------------------------------------------------------------------------
  // Cursor-based sync (local_seq ordering)
  // ---------------------------------------------------------------------------

  /// Get the local_seq-based sync cursor for a peer.
  Future<int?> getSyncCursorSeq(String peerId) async {
    final db = await _ensureDb();
    final rows = await db.query(
      'mesh_sync_peers',
      columns: ['sync_cursor_seq'],
      where: 'peer_id = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['sync_cursor_seq'] as int?;
  }

  /// Update the local_seq-based sync cursor after successful batch ack.
  Future<void> updateSyncCursorSeq(String peerId, int cursorSeq) async {
    final db = await _ensureDb();
    await db.update(
      'mesh_sync_peers',
      {
        'sync_cursor_seq': cursorSeq,
        'last_sync_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'peer_id = ?',
      whereArgs: [peerId],
    );
    AppLogging.meshFeed('sync cursor advanced: peer=$peerId seq=$cursorSeq');
  }

  /// Get posts after a sync_seq cursor, ordered deterministically.
  ///
  /// Uses `sync_seq` — only bumped on INSERT (new content), not on
  /// metadata-only merges. This prevents provenance updates from making
  /// already-synced posts re-eligible for outbound sync.
  ///
  /// Ordering: `sync_seq ASC, id ASC` — monotonic sequence with
  /// deterministic tiebreak on canonical ID for same-seq ties.
  Future<List<MeshPost>> getPostsAfterSeq({
    int? afterSeq,
    int limit = 50,
  }) async {
    final db = await _ensureDb();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final where = StringBuffer('expires_at_ms > ? AND sync_seq IS NOT NULL');
    final args = <dynamic>[nowMs];
    if (afterSeq != null) {
      where.write(' AND sync_seq > ?');
      args.add(afterSeq);
    }
    final rows = await db.query(
      'mesh_posts',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'sync_seq ASC, id ASC',
      limit: limit,
    );
    return rows.map(MeshPost.fromRow).toList();
  }

  // ---------------------------------------------------------------------------
  // Propagation tracking
  // ---------------------------------------------------------------------------

  /// Mark a post as rebroadcast over LoRa from this device.
  Future<void> markLoraRebroadcast(String postId) async {
    final db = await _ensureDb();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'mesh_posts',
      {'lora_rebroadcast_at_ms': nowMs},
      where: 'id = ?',
      whereArgs: [postId],
    );
    AppLogging.meshFeed(
      'LoRa rebroadcast marked: post=${postId.substring(0, 8)}…',
    );
  }

  /// Get posts eligible for LoRa propagation:
  /// not expired, not already rebroadcast, not localOnly propagation,
  /// ordered by created_at_ms DESC.
  Future<List<MeshPost>> getLoraEligiblePosts({int limit = 20}) async {
    final db = await _ensureDb();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'mesh_posts',
      where:
          'expires_at_ms > ? '
          'AND lora_rebroadcast_at_ms IS NULL '
          'AND propagation_class != ?',
      whereArgs: [nowMs, MeshPostPropagation.localOnly.wireIndex],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(MeshPost.fromRow).toList();
  }

  /// Check if a post exists (for replay guard fast-path).
  Future<bool> postExists(String id) async {
    final db = await _ensureDb();
    final result = await db.rawQuery(
      'SELECT 1 FROM mesh_posts WHERE id = ? LIMIT 1',
      [id],
    );
    return result.isNotEmpty;
  }

  /// Get the transport set for an existing post (for replay provenance check).
  Future<Set<MeshTransportType>?> getPostTransports(String id) async {
    final db = await _ensureDb();
    final rows = await db.query(
      'mesh_posts',
      columns: ['seen_via_transports'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final transportJson = rows.first['seen_via_transports'] as String? ?? '[]';
    final transports = <MeshTransportType>{};
    for (final t in (json.decode(transportJson) as List)) {
      final name = t as String;
      for (final mt in MeshTransportType.values) {
        if (mt.name == name) transports.add(mt);
      }
    }
    return transports;
  }
}
