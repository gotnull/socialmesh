// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SQLite persistence for [OverlayEndpointRecord] rows.
///
/// Database: `endpoints.db`
/// Schema version: 1
///
/// Single table `overlay_endpoints` keyed on the 8-byte derived
/// `endpoint_id`. Secondary indexes on `persona_hint` and
/// `peer_node_num_hint` support the deterministic tie-break rules
/// documented in `docs/sip/OVERLAY_V0_2.md` §24.1.4.
///
/// **No key material is ever persisted here** — private keys live in
/// [FlutterSecureStorage] only. `persona_pub_ed` is the peer's public
/// key and may safely be stored.
library;

import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import 'overlay_endpoint_record.dart';

/// Schema version of `endpoints.db`.
const int overlayEndpointStoreSchemaVersion = 1;

/// SQLite-backed store for overlay endpoint records.
class OverlayEndpointStore {
  static const _dbName = 'endpoints.db';
  static const _tableName = 'overlay_endpoints';
  static const _dbVersion = 1;

  Database? _db;
  final String? _testDbPath;

  /// True if the underlying handle is open.
  bool get isOpen => _db != null && _db!.isOpen;

  /// Construct a store. [_testDbPath] overrides the on-disk location;
  /// tests typically supply a tempfile path so the suite stays
  /// isolated.
  OverlayEndpointStore({this._testDbPath});

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
      },
      onCreate: (db, version) async {
        AppLogging.storage('Creating endpoints.db v$version');
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        AppLogging.storage(
          'Upgrading endpoints.db v$oldVersion -> v$newVersion',
        );
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        endpoint_id           BLOB PRIMARY KEY,
        persona_pub_ed        BLOB NOT NULL,
        persona_hint          BLOB NOT NULL,
        service_id            INTEGER NOT NULL DEFAULT 0,
        peer_node_num_hint    INTEGER,
        supported_features    INTEGER NOT NULL DEFAULT 0,
        max_chunk_bytes       INTEGER,
        max_resource_bytes    INTEGER,
        first_seen_ms         INTEGER NOT NULL,
        last_seen_ms          INTEGER NOT NULL,
        trust_level           INTEGER NOT NULL DEFAULT 0,
        source                TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_overlay_endpoints_persona_hint '
      'ON $_tableName(persona_hint)',
    );
    await db.execute(
      'CREATE INDEX idx_overlay_endpoints_node_num '
      'ON $_tableName(peer_node_num_hint)',
    );
    await db.execute(
      'CREATE INDEX idx_overlay_endpoints_trust '
      'ON $_tableName(trust_level, last_seen_ms)',
    );
  }

  Database get _database {
    final db = _db;
    if (db == null || !db.isOpen) {
      throw StateError(
        'OverlayEndpointStore not initialized — call init() first',
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

  /// Insert-or-replace an endpoint row.
  Future<void> upsert(OverlayEndpointRecord r) async {
    await _database.insert(
      _tableName,
      _rowFromRecord(r),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Primary lookup by endpoint ID.
  Future<OverlayEndpointRecord?> getByEndpointId(Uint8List endpointId) async {
    final rows = await _database.query(
      _tableName,
      where: 'endpoint_id = ?',
      whereArgs: [endpointId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _recordFromRow(rows.first);
  }

  /// Secondary lookup by persona hint. May return multiple rows if
  /// the same persona exposes multiple services.
  Future<List<OverlayEndpointRecord>> getByPersonaHint(
    Uint8List personaHint,
  ) async {
    final rows = await _database.query(
      _tableName,
      where: 'persona_hint = ?',
      whereArgs: [personaHint],
      orderBy: 'last_seen_ms DESC',
    );
    return rows.map(_recordFromRow).toList(growable: false);
  }

  /// Secondary lookup by peer node num.
  Future<List<OverlayEndpointRecord>> getByPeerNodeNum(int nodeNum) async {
    final rows = await _database.query(
      _tableName,
      where: 'peer_node_num_hint = ?',
      whereArgs: [nodeNum],
      orderBy: 'trust_level DESC, last_seen_ms DESC',
    );
    return rows.map(_recordFromRow).toList(growable: false);
  }

  /// Load every endpoint row.
  Future<List<OverlayEndpointRecord>> loadAll() async {
    final rows = await _database.query(_tableName);
    return rows.map(_recordFromRow).toList(growable: false);
  }

  /// Diagnostic row count.
  Future<int> count() async {
    final r = await _database.rawQuery('SELECT COUNT(*) AS c FROM $_tableName');
    return (r.first['c'] as int?) ?? 0;
  }

  /// Delete a specific endpoint row.
  Future<void> delete(Uint8List endpointId) async {
    await _database.delete(
      _tableName,
      where: 'endpoint_id = ?',
      whereArgs: [endpointId],
    );
  }

  Map<String, Object?> _rowFromRecord(OverlayEndpointRecord r) => {
    'endpoint_id': r.endpointId,
    'persona_pub_ed': r.personaPubEd,
    'persona_hint': r.personaHint,
    'service_id': r.serviceId,
    'peer_node_num_hint': r.peerNodeNumHint,
    'supported_features': r.supportedFeatures,
    'max_chunk_bytes': r.maxChunkBytes,
    'max_resource_bytes': r.maxResourceBytes,
    'first_seen_ms': r.firstSeenMs,
    'last_seen_ms': r.lastSeenMs,
    'trust_level': r.trustLevel.code,
    'source': r.source,
  };

  OverlayEndpointRecord _recordFromRow(Map<String, Object?> row) {
    final trustCode = row['trust_level'] as int? ?? 0;
    final trust =
        OverlayEndpointTrustLevel.fromCode(trustCode) ??
        OverlayEndpointTrustLevel.observed;
    return OverlayEndpointRecord(
      endpointId: _asBytes(row['endpoint_id']),
      personaPubEd: _asBytes(row['persona_pub_ed']),
      personaHint: _asBytes(row['persona_hint']),
      serviceId: row['service_id']! as int,
      peerNodeNumHint: row['peer_node_num_hint'] as int?,
      supportedFeatures: row['supported_features']! as int,
      maxChunkBytes: row['max_chunk_bytes'] as int?,
      maxResourceBytes: row['max_resource_bytes'] as int?,
      firstSeenMs: row['first_seen_ms']! as int,
      lastSeenMs: row['last_seen_ms']! as int,
      trustLevel: trust,
      source: row['source']! as String,
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
