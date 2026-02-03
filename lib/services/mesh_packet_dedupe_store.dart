// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/logging.dart';

/// Metadata key for a mesh packet dedupe entry.
class MeshPacketKey {
  const MeshPacketKey({
    required this.packetType,
    required this.senderNodeId,
    required this.packetId,
    this.channelIndex,
  });

  final String packetType;
  final int senderNodeId;
  final int packetId;
  final int? channelIndex;
}

/// Persisted store for tracking mesh packets that were already processed.
///
/// This is a non-critical cache that can be safely recreated if corrupted.
/// The store is designed to be:
/// - Singleton: Only one database connection allowed
/// - Corruption-resilient: Auto-recovers by deleting and recreating
/// - Non-blocking: Failures don't crash the app
/// - Concurrent-safe: Uses a Completer to prevent race conditions
class MeshPacketDedupeStore {
  static const _tableName = 'mesh_seen_packets';
  static const _defaultTtl = Duration(minutes: 90);
  static const _cleanupInterval = Duration(minutes: 10);
  static const _dbVersion = 1;

  final String? _dbPathOverride;

  /// Completer to track in-progress initialization.
  /// Prevents concurrent openDatabase calls.
  Completer<Database?>? _initCompleter;

  /// Cached database instance.
  Database? _db;

  /// Whether initialization has failed permanently for this session.
  bool _initFailed = false;

  DateTime _lastCleanup = DateTime.fromMillisecondsSinceEpoch(0);

  MeshPacketDedupeStore({String? dbPathOverride})
    : _dbPathOverride = dbPathOverride;

  /// Initialize the underlying SQLite database.
  ///
  /// Safe to call multiple times - uses a completer to prevent
  /// concurrent initialization attempts.
  Future<void> init() async {
    // If already initialized, return immediately
    if (_db != null && _db!.isOpen) return;

    // If init already failed this session, don't retry
    if (_initFailed) {
      AppLogging.protocol('MeshPacketDedupeStore: Skipping init (failed)');
      return;
    }

    // If initialization is in progress, wait for it
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      await _initCompleter!.future;
      return;
    }

    // Start new initialization
    _initCompleter = Completer<Database?>();

    try {
      await _openDatabaseSafe();
      _initCompleter!.complete(_db);
    } catch (e) {
      _initCompleter!.complete(null);
      rethrow;
    }
  }

  /// Open the database with corruption recovery.
  Future<void> _openDatabaseSafe() async {
    final path = _dbPathOverride ?? await _defaultDbPath();

    try {
      _db = await _attemptOpen(path);
    } catch (e) {
      AppLogging.protocol(
        'MeshPacketDedupeStore: First open attempt failed: $e',
      );

      // Attempt recovery by deleting the corrupted database
      if (!await _attemptRecovery(path)) {
        _initFailed = true;
        AppLogging.protocol(
          'MeshPacketDedupeStore: Recovery failed, operating without DB',
        );
      }
    }
  }

  /// Attempt to open the database at the given path.
  Future<Database> _attemptOpen(String path) async {
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
    );
  }

  /// Create the database schema.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        packetType TEXT NOT NULL,
        senderNodeId INTEGER NOT NULL,
        packetId INTEGER NOT NULL,
        channelIndex INTEGER,
        receivedAt INTEGER NOT NULL,
        PRIMARY KEY (packetType, senderNodeId, packetId, channelIndex)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${_tableName}_receivedAt '
      'ON $_tableName(receivedAt)',
    );
  }

  /// Handle database upgrades.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // For a dedupe cache, it's safe to just recreate the table
    // No user data is lost since this is just a performance cache
    AppLogging.protocol(
      'MeshPacketDedupeStore: Upgrading from v$oldVersion to v$newVersion',
    );
    await db.execute('DROP TABLE IF EXISTS $_tableName');
    await _onCreate(db, newVersion);
  }

  /// Handle database downgrades (e.g., app downgrade).
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    // Safe to recreate - this is just a cache
    AppLogging.protocol(
      'MeshPacketDedupeStore: Downgrading from v$oldVersion to v$newVersion',
    );
    await db.execute('DROP TABLE IF EXISTS $_tableName');
    await _onCreate(db, newVersion);
  }

  /// Attempt to recover from database corruption.
  Future<bool> _attemptRecovery(String path) async {
    AppLogging.protocol('MeshPacketDedupeStore: Attempting recovery...');

    try {
      // Close any existing connection
      await _db?.close();
      _db = null;

      // Delete the corrupted database file
      final dbFile = File(path);
      if (await dbFile.exists()) {
        await dbFile.delete();
        AppLogging.protocol('MeshPacketDedupeStore: Deleted corrupted DB');
      }

      // Also delete journal/wal files if they exist
      await _deleteIfExists('$path-journal');
      await _deleteIfExists('$path-wal');
      await _deleteIfExists('$path-shm');

      // Try opening fresh
      _db = await _attemptOpen(path);
      AppLogging.protocol('MeshPacketDedupeStore: Recovery successful');
      return true;
    } catch (e) {
      AppLogging.protocol('MeshPacketDedupeStore: Recovery failed: $e');
      return false;
    }
  }

  /// Delete a file if it exists.
  Future<void> _deleteIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore errors deleting auxiliary files
    }
  }

  Future<String> _defaultDbPath() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbDir = Directory(p.join(documentsDir.path, 'cache'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    return p.join(dbDir.path, 'mesh_seen_packets.db');
  }

  /// Get the database, initializing if needed.
  ///
  /// Returns null if the database cannot be opened (app continues without it).
  Future<Database?> _ensureDb() async {
    if (_db != null && _db!.isOpen) return _db;

    if (_initFailed) return null;

    try {
      await init();
      return _db;
    } catch (e) {
      AppLogging.protocol('MeshPacketDedupeStore: _ensureDb failed: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    try {
      await _db?.close();
    } catch (e) {
      AppLogging.protocol('MeshPacketDedupeStore: dispose error: $e');
    }
    _db = null;
    _initCompleter = null;
    _initFailed = false;
  }

  /// Check if a packet has been seen recently.
  ///
  /// Returns false if the database is unavailable (fail-open for dedupe).
  Future<bool> hasSeen(MeshPacketKey key, {Duration? ttl}) async {
    final db = await _ensureDb();

    // If DB unavailable, fail-open (assume not seen to allow processing)
    if (db == null) return false;

    final effectiveTtl = ttl ?? _defaultTtl;
    final cutoff = DateTime.now().subtract(effectiveTtl).millisecondsSinceEpoch;

    final where = StringBuffer()
      ..write('packetType = ? AND senderNodeId = ? AND packetId = ? AND ')
      ..write(
        key.channelIndex == null ? 'channelIndex IS NULL' : 'channelIndex = ?',
      )
      ..write(' AND receivedAt > ?');

    final args = <Object?>[key.packetType, key.senderNodeId, key.packetId];
    if (key.channelIndex != null) {
      args.add(key.channelIndex);
    }
    args.add(cutoff);

    try {
      final rows = await db.query(
        _tableName,
        columns: ['receivedAt'],
        where: where.toString(),
        whereArgs: args,
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (e) {
      AppLogging.protocol('MeshPacketDedupeStore: hasSeen error: $e');
      return false;
    }
  }

  /// Mark a packet as seen.
  ///
  /// Silently fails if the database is unavailable.
  Future<void> markSeen(MeshPacketKey key, {Duration? ttl}) async {
    final db = await _ensureDb();

    // If DB unavailable, skip marking (non-critical)
    if (db == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await db.insert(_tableName, {
        'packetType': key.packetType,
        'senderNodeId': key.senderNodeId,
        'packetId': key.packetId,
        'channelIndex': key.channelIndex,
        'receivedAt': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final effectiveTtl = ttl ?? _defaultTtl;
      await _maybeCleanup(effectiveTtl);
    } catch (e) {
      AppLogging.protocol('MeshPacketDedupeStore: markSeen error: $e');
    }
  }

  /// Clean up old entries from the database.
  ///
  /// Silently fails if the database is unavailable.
  Future<void> cleanup({Duration? ttl}) async {
    final db = await _ensureDb();

    // If DB unavailable, skip cleanup
    if (db == null) return;

    final effectiveTtl = ttl ?? _defaultTtl;
    final cutoff = DateTime.now().subtract(effectiveTtl).millisecondsSinceEpoch;

    try {
      final deleted = await db.delete(
        _tableName,
        where: 'receivedAt < ?',
        whereArgs: [cutoff],
      );

      if (deleted > 0) {
        AppLogging.protocol(
          'MeshPacketDedupeStore cleaned $deleted entries older than ${effectiveTtl.inMinutes}m',
        );
      }

      _lastCleanup = DateTime.now();
    } catch (e) {
      AppLogging.protocol('MeshPacketDedupeStore: cleanup error: $e');
    }
  }

  Future<void> _maybeCleanup(Duration ttl) async {
    if (_lastCleanup.add(_cleanupInterval).isAfter(DateTime.now())) {
      return;
    }
    try {
      await cleanup(ttl: ttl);
    } catch (e) {
      AppLogging.protocol('MeshPacketDedupeStore cleanup failed: $e');
    }
  }
}
