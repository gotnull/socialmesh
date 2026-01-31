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
class MeshPacketDedupeStore {
  static const _tableName = 'mesh_seen_packets';
  static const _defaultTtl = Duration(minutes: 90);
  static const _cleanupInterval = Duration(minutes: 10);

  final String? _dbPathOverride;
  Future<void>? _initFuture;

  Database? _db;
  DateTime _lastCleanup = DateTime.fromMillisecondsSinceEpoch(0);

  MeshPacketDedupeStore({
    String? dbPathOverride,
  }) : _dbPathOverride = dbPathOverride;

  /// Initialize the underlying SQLite database.
  Future<void> init() {
    if (_initFuture != null) return _initFuture!;
    _initFuture = _openDatabase();
    return _initFuture!;
  }

  Future<void> _openDatabase() async {
    final path = _dbPathOverride ?? await _defaultDbPath();
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
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
      },
    );
  }

  Future<String> _defaultDbPath() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbDir = Directory(p.join(documentsDir.path, 'cache'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    return p.join(dbDir.path, 'mesh_seen_packets.db');
  }

  Future<Database> _ensureDb() async {
    if (_db != null) return _db!;
    await init();
    return _db!;
  }

  Future<void> dispose() async {
    await _db?.close();
    _db = null;
    _initFuture = null;
  }

  Future<bool> hasSeen(
    MeshPacketKey key, {
    Duration? ttl,
  }) async {
    final db = await _ensureDb();
    final effectiveTtl = ttl ?? _defaultTtl;
    final cutoff = DateTime.now().subtract(effectiveTtl).millisecondsSinceEpoch;

    final where = StringBuffer()
      ..write('packetType = ? AND senderNodeId = ? AND packetId = ? AND ')
      ..write(key.channelIndex == null
          ? 'channelIndex IS NULL'
          : 'channelIndex = ?')
      ..write(' AND receivedAt > ?');

    final args = <Object?>[
      key.packetType,
      key.senderNodeId,
      key.packetId,
    ];
    if (key.channelIndex != null) {
      args.add(key.channelIndex);
    }
    args.add(cutoff);

    final rows = await db.query(
      _tableName,
      columns: ['receivedAt'],
      where: where.toString(),
      whereArgs: args,
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<void> markSeen(
    MeshPacketKey key, {
    Duration? ttl,
  }) async {
    final db = await _ensureDb();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      _tableName,
      {
        'packetType': key.packetType,
        'senderNodeId': key.senderNodeId,
        'packetId': key.packetId,
        'channelIndex': key.channelIndex,
        'receivedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final effectiveTtl = ttl ?? _defaultTtl;
    await _maybeCleanup(effectiveTtl);
  }

  Future<void> cleanup({
    Duration? ttl,
  }) async {
    final db = await _ensureDb();
    final effectiveTtl = ttl ?? _defaultTtl;
    final cutoff = DateTime.now().subtract(effectiveTtl).millisecondsSinceEpoch;
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
