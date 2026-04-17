// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// SQLite cache for NodeBoard data — stale-while-revalidate pattern.

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../models/nodeboard_summary.dart';
import '../models/nodeboard_thread.dart';

class NodeBoardCacheService {
  Database? _db;
  final String? dbPathOverride;

  NodeBoardCacheService({this.dbPathOverride});

  Future<void> init() async {
    if (_db != null) return;

    final String dbPath;
    if (dbPathOverride != null) {
      dbPath = dbPathOverride!;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      dbPath = p.join(dir.path, 'nodeboard_cache.db');
    }

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE board_summaries (
            slug TEXT PRIMARY KEY,
            json_data TEXT NOT NULL,
            cached_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE threads (
            id TEXT PRIMARY KEY,
            section_id TEXT NOT NULL,
            board_id TEXT NOT NULL,
            json_data TEXT NOT NULL,
            cached_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_threads_section ON threads(section_id, cached_at)
        ''');
      },
    );

    // Enable WAL mode
    await _db!.rawQuery('PRAGMA journal_mode=WAL');
    AppLogging.nodeBoard('Cache: init complete (WAL mode)');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    AppLogging.nodeBoard('Cache: closed');
  }

  // -------------------------------------------------------------------------
  // Board summaries
  // -------------------------------------------------------------------------

  Future<void> cacheBoardSummary(NodeBoardSummary summary) async {
    final db = _db;
    if (db == null) return;

    AppLogging.nodeBoard('Cache: saving board summary slug=${summary.slug}');
    await db.insert('board_summaries', {
      'slug': summary.slug,
      'json_data': jsonEncode(summary.toJson()),
      'cached_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> cacheBoardSummaries(List<NodeBoardSummary> summaries) async {
    final db = _db;
    if (db == null) return;

    AppLogging.nodeBoard('Cache: saving ${summaries.length} board summaries');
    final batch = db.batch();
    for (final summary in summaries) {
      batch.insert('board_summaries', {
        'slug': summary.slug,
        'json_data': jsonEncode(summary.toJson()),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<NodeBoardSummary?> getCachedBoardSummary(String slug) async {
    final db = _db;
    if (db == null) return null;

    final rows = await db.query(
      'board_summaries',
      where: 'slug = ?',
      whereArgs: [slug],
    );
    if (rows.isEmpty) {
      AppLogging.nodeBoard('Cache: miss for board slug=$slug');
      return null;
    }

    AppLogging.nodeBoard('Cache: hit for board slug=$slug');
    return NodeBoardSummary.fromJson(
      jsonDecode(rows.first['json_data'] as String) as Map<String, dynamic>,
    );
  }

  Future<List<NodeBoardSummary>> getCachedBoardSummaries() async {
    final db = _db;
    if (db == null) return [];

    final rows = await db.query(
      'board_summaries',
      orderBy: 'cached_at DESC',
      limit: 50,
    );

    AppLogging.nodeBoard('Cache: ${rows.length} cached board summaries');
    return rows
        .map(
          (r) => NodeBoardSummary.fromJson(
            jsonDecode(r['json_data'] as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  // -------------------------------------------------------------------------
  // Threads
  // -------------------------------------------------------------------------

  Future<void> cacheThreads(
    String boardId,
    String sectionId,
    List<NodeBoardThread> threads,
  ) async {
    final db = _db;
    if (db == null) return;

    AppLogging.nodeBoard(
      'Cache: saving ${threads.length} threads for section=$sectionId',
    );
    final batch = db.batch();
    for (final thread in threads) {
      batch.insert('threads', {
        'id': thread.id,
        'section_id': sectionId,
        'board_id': boardId,
        'json_data': jsonEncode(thread.toJson()),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<NodeBoardThread>> getCachedThreads(String sectionId) async {
    final db = _db;
    if (db == null) return [];

    final rows = await db.query(
      'threads',
      where: 'section_id = ?',
      whereArgs: [sectionId],
      orderBy: 'cached_at DESC',
      limit: 50,
    );

    AppLogging.nodeBoard(
      'Cache: ${rows.length} cached threads for section=$sectionId',
    );
    return rows
        .map(
          (r) => NodeBoardThread.fromJson(
            jsonDecode(r['json_data'] as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  // -------------------------------------------------------------------------
  // Staleness check
  // -------------------------------------------------------------------------

  bool isStale(int cachedAtMs, {int maxAgeSeconds = 120}) {
    final age = DateTime.now().millisecondsSinceEpoch - cachedAtMs;
    return age > maxAgeSeconds * 1000;
  }
}
