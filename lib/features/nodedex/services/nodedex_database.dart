// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeDex Database — SQLite schema and lifecycle management.
//
// This file defines the database schema for NodeDex persistence.
// All tables, indices, and migration logic live here.
//
// Database: nodedex.db
// Schema version: 1

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';

/// Schema version for the NodeDex SQLite database.
///
/// Bump this when adding tables, columns, or indices.
/// Migration logic runs in [_onUpgrade].
const int nodedexSchemaVersion = 9;

/// Table and column name constants for NodeDex SQLite schema.
abstract final class NodeDexTables {
  // -- nodedex_entries --
  static const entries = 'nodedex_entries';
  static const colNodeNum = 'node_num';
  static const colFirstSeenMs = 'first_seen_ms';
  static const colLastSeenMs = 'last_seen_ms';
  static const colEncounterCount = 'encounter_count';
  static const colMaxDistance = 'max_distance';
  static const colBestSnr = 'best_snr';
  static const colBestRssi = 'best_rssi';
  static const colMessageCount = 'message_count';
  static const colSocialTag = 'social_tag';
  static const colSocialTagUpdatedAtMs = 'social_tag_updated_at_ms';
  static const colUserNote = 'user_note';
  static const colUserNoteUpdatedAtMs = 'user_note_updated_at_ms';
  static const colLocalNickname = 'local_nickname';
  static const colLocalNicknameUpdatedAtMs = 'local_nickname_updated_at_ms';
  static const colSigilJson = 'sigil_json';
  static const colLastKnownName = 'last_known_name';
  static const colLastKnownHardware = 'last_known_hardware';
  static const colLastKnownRole = 'last_known_role';
  static const colLastKnownFirmware = 'last_known_firmware';
  static const colSchemaVersion = 'schema_version';
  static const colUpdatedAtMs = 'updated_at_ms';
  static const colDeleted = 'deleted';

  // -- SIP identity columns (v7) --
  static const colSipCapable = 'sip_capable';
  static const colSipPubkey = 'sip_pubkey';
  static const colSipPersonaId = 'sip_persona_id';
  static const colSipIdentityState = 'sip_identity_state';
  static const colSipDisplayName = 'sip_display_name';

  // -- MRRP service columns (v8) --
  static const colMrrpServiceIds = 'mrrp_service_ids';

  // -- Radio preset observation columns (v9) --
  static const colLastObservedOnPreset = 'last_observed_on_preset';
  static const colEncObservedOnPreset = 'observed_on_preset';

  // -- nodedex_encounters --
  static const encounters = 'nodedex_encounters';
  static const colEncId = 'id';
  static const colEncTsMs = 'ts_ms';
  static const colEncDistance = 'distance_m';
  static const colEncSnr = 'snr';
  static const colEncRssi = 'rssi';
  static const colEncLat = 'lat';
  static const colEncLon = 'lon';
  static const colEncSessionId = 'session_id';
  static const colEncCreatedAtMs = 'created_at_ms';

  // -- nodedex_seen_regions --
  static const seenRegions = 'nodedex_seen_regions';
  static const colRegionKey = 'region_key';
  static const colRegionLabel = 'label';
  static const colRegionFirstSeenMs = 'first_seen_ms';
  static const colRegionLastSeenMs = 'last_seen_ms';
  static const colRegionCount = 'count';

  // -- nodedex_coseen_edges --
  static const coSeenEdges = 'nodedex_coseen_edges';
  static const colEdgeA = 'a_node_num';
  static const colEdgeB = 'b_node_num';
  static const colEdgeFirstSeenMs = 'first_seen_ms';
  static const colEdgeLastSeenMs = 'last_seen_ms';
  static const colEdgeCount = 'count';
  static const colEdgeMessageCount = 'message_count';

  // -- presence_transitions --
  static const presenceTransitions = 'presence_transitions';
  static const colPtId = 'id';
  static const colPtNodeNum = 'node_num';
  static const colPtFromState = 'from_state';
  static const colPtToState = 'to_state';
  static const colPtTsMs = 'ts_ms';

  // -- sync_state --
  static const syncState = 'sync_state';
  static const colSyncKey = 'key';
  static const colSyncValue = 'value';

  // -- sync_outbox --
  static const syncOutbox = 'sync_outbox';
  static const colOutboxId = 'id';
  static const colOutboxEntityType = 'entity_type';
  static const colOutboxEntityId = 'entity_id';
  static const colOutboxOp = 'op';
  static const colOutboxPayloadJson = 'payload_json';
  static const colOutboxUpdatedAtMs = 'updated_at_ms';
  static const colOutboxAttemptCount = 'attempt_count';
  static const colOutboxLastError = 'last_error';
}

/// Manages the NodeDex SQLite database lifecycle.
///
/// Handles opening, creating, upgrading, and corruption recovery.
/// Follows the same resilient pattern used by MeshPacketDedupeStore.
class NodeDexDatabase {
  static const String _dbFileName = 'nodedex.db';

  final String? _dbPathOverride;
  Database? _db;
  Completer<Database?>? _initCompleter;
  bool _initFailed = false;

  NodeDexDatabase({String? dbPathOverride}) : _dbPathOverride = dbPathOverride;

  /// The open database instance. Throws if not initialized.
  Database get database {
    if (_db == null || !_db!.isOpen) {
      throw StateError('NodeDexDatabase not initialized. Call open() first.');
    }
    return _db!;
  }

  /// Whether the database is open and ready.
  bool get isOpen => _db != null && _db!.isOpen;

  /// Open the database, creating tables if needed.
  ///
  /// Safe to call multiple times. Uses a completer to prevent
  /// concurrent initialization.
  Future<Database> open() async {
    if (_db != null && _db!.isOpen) return _db!;
    if (_initFailed) {
      throw StateError('NodeDexDatabase init failed permanently.');
    }

    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      final result = await _initCompleter!.future;
      if (result == null) {
        throw StateError('NodeDexDatabase init failed.');
      }
      return result;
    }

    _initCompleter = Completer<Database?>();

    try {
      await _openSafe();
      _initCompleter!.complete(_db);
      return _db!;
    } catch (e) {
      _initCompleter!.complete(null);
      _initFailed = true;
      rethrow;
    }
  }

  Future<void> _openSafe() async {
    final path = _dbPathOverride ?? await _defaultPath();

    try {
      _db = await _attemptOpen(path);
    } catch (e) {
      AppLogging.storage('NodeDexDatabase: First open failed: $e');
      if (!await _attemptRecovery(path)) {
        AppLogging.storage('NodeDexDatabase: Recovery failed');
        rethrow;
      }
    }
  }

  Future<Database> _attemptOpen(String path) async {
    return openDatabase(
      path,
      version: nodedexSchemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    final walResult = await db.rawQuery('PRAGMA journal_mode=WAL');
    // Only enforce WAL for on-disk databases. In-memory databases
    // (used in tests via _dbPathOverride) do not support WAL mode.
    if (_dbPathOverride == null) {
      assert(
        walResult.isNotEmpty && walResult.first['journal_mode'] == 'wal',
        'WAL mode not active',
      ); // lint-allow: hardcoded-string
    }
  }

  /// Create all tables and indices for a fresh database.
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // -- nodedex_entries --
    batch.execute('''
      CREATE TABLE ${NodeDexTables.entries} (
        ${NodeDexTables.colNodeNum} INTEGER PRIMARY KEY,
        ${NodeDexTables.colFirstSeenMs} INTEGER NOT NULL,
        ${NodeDexTables.colLastSeenMs} INTEGER NOT NULL,
        ${NodeDexTables.colEncounterCount} INTEGER NOT NULL DEFAULT 1,
        ${NodeDexTables.colMaxDistance} REAL,
        ${NodeDexTables.colBestSnr} INTEGER,
        ${NodeDexTables.colBestRssi} INTEGER,
        ${NodeDexTables.colMessageCount} INTEGER NOT NULL DEFAULT 0,
        ${NodeDexTables.colSocialTag} INTEGER,
        ${NodeDexTables.colSocialTagUpdatedAtMs} INTEGER,
        ${NodeDexTables.colUserNote} TEXT,
        ${NodeDexTables.colUserNoteUpdatedAtMs} INTEGER,
        ${NodeDexTables.colLocalNickname} TEXT,
        ${NodeDexTables.colLocalNicknameUpdatedAtMs} INTEGER,
        ${NodeDexTables.colSigilJson} TEXT NOT NULL,
        ${NodeDexTables.colLastKnownName} TEXT,
        ${NodeDexTables.colLastKnownHardware} TEXT,
        ${NodeDexTables.colLastKnownRole} TEXT,
        ${NodeDexTables.colLastKnownFirmware} TEXT,
        ${NodeDexTables.colSchemaVersion} INTEGER NOT NULL DEFAULT 1,
        ${NodeDexTables.colUpdatedAtMs} INTEGER NOT NULL,
        ${NodeDexTables.colDeleted} INTEGER NOT NULL DEFAULT 0,
        ${NodeDexTables.colSipCapable} INTEGER,
        ${NodeDexTables.colSipPubkey} BLOB,
        ${NodeDexTables.colSipPersonaId} BLOB,
        ${NodeDexTables.colSipIdentityState} TEXT,
        ${NodeDexTables.colSipDisplayName} TEXT,
        ${NodeDexTables.colMrrpServiceIds} TEXT,
        ${NodeDexTables.colLastObservedOnPreset} INTEGER              -- v9
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_entries_last_seen ' // lint-allow: hardcoded-string
      'ON ${NodeDexTables.entries}(${NodeDexTables.colLastSeenMs})', // lint-allow: hardcoded-string
    );
    batch.execute(
      'CREATE INDEX idx_entries_deleted ' // lint-allow: hardcoded-string
      'ON ${NodeDexTables.entries}(${NodeDexTables.colDeleted})', // lint-allow: hardcoded-string
    );

    // -- nodedex_encounters --
    batch.execute('''
      CREATE TABLE ${NodeDexTables.encounters} (
        ${NodeDexTables.colEncId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${NodeDexTables.colNodeNum} INTEGER NOT NULL
          REFERENCES ${NodeDexTables.entries}(${NodeDexTables.colNodeNum})
          ON DELETE CASCADE,
        ${NodeDexTables.colEncTsMs} INTEGER NOT NULL,
        ${NodeDexTables.colEncDistance} REAL,
        ${NodeDexTables.colEncSnr} REAL,
        ${NodeDexTables.colEncRssi} REAL,
        ${NodeDexTables.colEncLat} REAL,
        ${NodeDexTables.colEncLon} REAL,
        ${NodeDexTables.colEncSessionId} TEXT,
        ${NodeDexTables.colEncCreatedAtMs} INTEGER NOT NULL,
        ${NodeDexTables.colEncObservedOnPreset} INTEGER               -- v9
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_encounters_node_ts ' // lint-allow: hardcoded-string
      'ON ${NodeDexTables.encounters}' // lint-allow: hardcoded-string
      '(${NodeDexTables.colNodeNum}, ${NodeDexTables.colEncTsMs})',
    );

    // -- nodedex_seen_regions --
    batch.execute('''
      CREATE TABLE ${NodeDexTables.seenRegions} (
        ${NodeDexTables.colNodeNum} INTEGER NOT NULL
          REFERENCES ${NodeDexTables.entries}(${NodeDexTables.colNodeNum})
          ON DELETE CASCADE,
        ${NodeDexTables.colRegionKey} TEXT NOT NULL,
        ${NodeDexTables.colRegionLabel} TEXT,
        ${NodeDexTables.colRegionFirstSeenMs} INTEGER NOT NULL,
        ${NodeDexTables.colRegionLastSeenMs} INTEGER NOT NULL,
        ${NodeDexTables.colRegionCount} INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (${NodeDexTables.colNodeNum}, ${NodeDexTables.colRegionKey})
      )
    ''');

    // -- nodedex_coseen_edges --
    batch.execute('''
      CREATE TABLE ${NodeDexTables.coSeenEdges} (
        ${NodeDexTables.colEdgeA} INTEGER NOT NULL,
        ${NodeDexTables.colEdgeB} INTEGER NOT NULL,
        ${NodeDexTables.colEdgeFirstSeenMs} INTEGER NOT NULL,
        ${NodeDexTables.colEdgeLastSeenMs} INTEGER NOT NULL,
        ${NodeDexTables.colEdgeCount} INTEGER NOT NULL DEFAULT 1,
        ${NodeDexTables.colEdgeMessageCount} INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (${NodeDexTables.colEdgeA}, ${NodeDexTables.colEdgeB}),
        CHECK (${NodeDexTables.colEdgeA} < ${NodeDexTables.colEdgeB})
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_edges_b ' // lint-allow: hardcoded-string
      'ON ${NodeDexTables.coSeenEdges}(${NodeDexTables.colEdgeB})', // lint-allow: hardcoded-string
    );

    // -- presence_transitions --
    batch.execute('''
      CREATE TABLE ${NodeDexTables.presenceTransitions} (
        ${NodeDexTables.colPtId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${NodeDexTables.colPtNodeNum} INTEGER NOT NULL,
        ${NodeDexTables.colPtFromState} TEXT NOT NULL,
        ${NodeDexTables.colPtToState} TEXT NOT NULL,
        ${NodeDexTables.colPtTsMs} INTEGER NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_presence_transitions_node_ts ' // lint-allow: hardcoded-string
      'ON ${NodeDexTables.presenceTransitions}' // lint-allow: hardcoded-string
      '(${NodeDexTables.colPtNodeNum}, ${NodeDexTables.colPtTsMs})',
    );

    // -- sync_state --
    batch.execute('''
      CREATE TABLE ${NodeDexTables.syncState} (
        ${NodeDexTables.colSyncKey} TEXT PRIMARY KEY,
        ${NodeDexTables.colSyncValue} TEXT NOT NULL
      )
    ''');

    // -- sync_outbox --
    batch.execute('''
      CREATE TABLE ${NodeDexTables.syncOutbox} (
        ${NodeDexTables.colOutboxId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${NodeDexTables.colOutboxEntityType} TEXT NOT NULL,
        ${NodeDexTables.colOutboxEntityId} TEXT NOT NULL,
        ${NodeDexTables.colOutboxOp} TEXT NOT NULL,
        ${NodeDexTables.colOutboxPayloadJson} TEXT NOT NULL,
        ${NodeDexTables.colOutboxUpdatedAtMs} INTEGER NOT NULL,
        ${NodeDexTables.colOutboxAttemptCount} INTEGER NOT NULL DEFAULT 0,
        ${NodeDexTables.colOutboxLastError} TEXT
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_outbox_entity ' // lint-allow: hardcoded-string
      'ON ${NodeDexTables.syncOutbox}' // lint-allow: hardcoded-string
      '(${NodeDexTables.colOutboxEntityType}, ${NodeDexTables.colOutboxEntityId})',
    );

    await batch.commit(noResult: true);

    AppLogging.storage(
      'NodeDexDatabase: Created schema v$version '
      '(${_tableNames().length} tables)',
    );
  }

  /// Handle schema upgrades.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.storage(
      'NodeDexDatabase: Upgrading v$oldVersion -> v$newVersion',
    );

    if (oldVersion < 2) {
      // v2: Add per-field timestamps for socialTag and userNote to support
      // last-write-wins conflict resolution during Cloud Sync.
      await db.execute(
        'ALTER TABLE ${NodeDexTables.entries} ' // lint-allow: hardcoded-string
        'ADD COLUMN ${NodeDexTables.colSocialTagUpdatedAtMs} INTEGER', // lint-allow: hardcoded-string
      );
      await db.execute(
        'ALTER TABLE ${NodeDexTables.entries} ' // lint-allow: hardcoded-string
        'ADD COLUMN ${NodeDexTables.colUserNoteUpdatedAtMs} INTEGER', // lint-allow: hardcoded-string
      );
      AppLogging.storage(
        'NodeDexDatabase: v2 migration — added socialTag/userNote timestamps',
      );
    }
    if (oldVersion < 3) {
      // v3: Cache node display names so NodeDex can show meaningful names
      // even after reconnecting to a different device (when the original
      // nodes are no longer in the live nodesProvider).
      await db.execute(
        'ALTER TABLE ${NodeDexTables.entries} ' // lint-allow: hardcoded-string
        'ADD COLUMN ${NodeDexTables.colLastKnownName} TEXT', // lint-allow: hardcoded-string
      );
      AppLogging.storage(
        'NodeDexDatabase: v3 migration — added last_known_name column',
      );
    }
    if (oldVersion < 4) {
      // v4: Cache device info (hardware model, role, firmware version) so
      // SigilCards display this data even when the node is offline.
      await db.execute(
        'ALTER TABLE ${NodeDexTables.entries} ' // lint-allow: hardcoded-string
        'ADD COLUMN ${NodeDexTables.colLastKnownHardware} TEXT', // lint-allow: hardcoded-string
      );
      await db.execute(
        'ALTER TABLE ${NodeDexTables.entries} ' // lint-allow: hardcoded-string
        'ADD COLUMN ${NodeDexTables.colLastKnownRole} TEXT', // lint-allow: hardcoded-string
      );
      await db.execute(
        'ALTER TABLE ${NodeDexTables.entries} ' // lint-allow: hardcoded-string
        'ADD COLUMN ${NodeDexTables.colLastKnownFirmware} TEXT', // lint-allow: hardcoded-string
      );
      AppLogging.storage(
        'NodeDexDatabase: v4 migration — added hardware/role/firmware columns',
      );
    }
    if (oldVersion < 5) {
      // v5: Add presence_transitions table to persist presence state
      // changes for the node activity timeline.
      await db.execute('''
        CREATE TABLE ${NodeDexTables.presenceTransitions} (
          ${NodeDexTables.colPtId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${NodeDexTables.colPtNodeNum} INTEGER NOT NULL,
          ${NodeDexTables.colPtFromState} TEXT NOT NULL,
          ${NodeDexTables.colPtToState} TEXT NOT NULL,
          ${NodeDexTables.colPtTsMs} INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_presence_transitions_node_ts ' // lint-allow: hardcoded-string
        'ON ${NodeDexTables.presenceTransitions}' // lint-allow: hardcoded-string
        '(${NodeDexTables.colPtNodeNum}, ${NodeDexTables.colPtTsMs})',
      );
      AppLogging.storage(
        'NodeDexDatabase: v5 migration — added presence_transitions table',
      );
    }
    if (oldVersion < 6) {
      // v6: Add local_nickname for user-assigned nicknames that override
      // all other name resolution sources. Per-field timestamp supports
      // last-write-wins conflict resolution during Cloud Sync.
      await db.execute(
        'ALTER TABLE ${NodeDexTables.entries} ' // lint-allow: hardcoded-string
        'ADD COLUMN ${NodeDexTables.colLocalNickname} TEXT', // lint-allow: hardcoded-string
      );
      await db.execute(
        'ALTER TABLE ${NodeDexTables.entries} ' // lint-allow: hardcoded-string
        'ADD COLUMN ${NodeDexTables.colLocalNicknameUpdatedAtMs} INTEGER', // lint-allow: hardcoded-string
      );
      AppLogging.storage(
        'NodeDexDatabase: v6 migration — added local_nickname columns',
      );
    }
    if (oldVersion < 7) {
      // v7: Add SIP identity columns for Socialmesh Interop Profile peers.
      // All nullable — existing entries are non-SIP by default.
      await db.execute(
        'ALTER TABLE ${NodeDexTables.entries} ' // lint-allow: hardcoded-string
        'ADD COLUMN ${NodeDexTables.colSipCapable} INTEGER', // lint-allow: hardcoded-string
      );
      await db.execute(
        'ALTER TABLE ${NodeDexTables.entries} ' // lint-allow: hardcoded-string
        'ADD COLUMN ${NodeDexTables.colSipPubkey} BLOB', // lint-allow: hardcoded-string
      );
      await db.execute(
        'ALTER TABLE ${NodeDexTables.entries} ' // lint-allow: hardcoded-string
        'ADD COLUMN ${NodeDexTables.colSipPersonaId} BLOB', // lint-allow: hardcoded-string
      );
      await db.execute(
        'ALTER TABLE ${NodeDexTables.entries} ' // lint-allow: hardcoded-string
        'ADD COLUMN ${NodeDexTables.colSipIdentityState} TEXT', // lint-allow: hardcoded-string
      );
      await db.execute(
        'ALTER TABLE ${NodeDexTables.entries} ' // lint-allow: hardcoded-string
        'ADD COLUMN ${NodeDexTables.colSipDisplayName} TEXT', // lint-allow: hardcoded-string
      );
      AppLogging.storage(
        'NodeDexDatabase: v7 migration — added SIP identity columns',
      );
    }
    if (oldVersion < 8) {
      // v8: Add MRRP service IDs column so NodeDex can display what
      // MRRP services a peer advertises via SERVICE_ADVERT frames.
      await db.execute(
        'ALTER TABLE ${NodeDexTables.entries} ' // lint-allow: hardcoded-string
        'ADD COLUMN ${NodeDexTables.colMrrpServiceIds} TEXT', // lint-allow: hardcoded-string
      );
      AppLogging.storage(
        'NodeDexDatabase: v8 migration — added mrrp_service_ids column',
      );
    }
    if (oldVersion < 9) {
      // v9: Track the modem preset of the local radio when a node was
      // observed. Stored as the protobuf Config_LoRaConfig_ModemPreset
      // integer value (0–9). Nullable for legacy entries where the
      // preset was not recorded.
      await db.execute(
        'ALTER TABLE ${NodeDexTables.entries} ' // lint-allow: hardcoded-string
        'ADD COLUMN ${NodeDexTables.colLastObservedOnPreset} INTEGER', // lint-allow: hardcoded-string
      );
      await db.execute(
        'ALTER TABLE ${NodeDexTables.encounters} ' // lint-allow: hardcoded-string
        'ADD COLUMN ${NodeDexTables.colEncObservedOnPreset} INTEGER', // lint-allow: hardcoded-string
      );
      AppLogging.storage(
        'NodeDexDatabase: v9 migration — added radio preset observation columns',
      );
    }
  }

  /// Handle downgrades by recreating.
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.storage(
      'NodeDexDatabase: Downgrading v$oldVersion -> v$newVersion — '
      'recreating tables',
    );
    for (final table in _tableNames()) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
    await _onCreate(db, newVersion);
  }

  /// Attempt corruption recovery by deleting and recreating.
  Future<bool> _attemptRecovery(String path) async {
    AppLogging.storage('NodeDexDatabase: Attempting recovery...');
    try {
      await _db?.close();
      _db = null;

      final dbFile = File(path);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      for (final suffix in ['-journal', '-wal', '-shm']) {
        final f = File('$path$suffix');
        if (await f.exists()) await f.delete();
      }

      _db = await _attemptOpen(path);
      AppLogging.storage('NodeDexDatabase: Recovery succeeded');
      return true;
    } catch (e) {
      AppLogging.storage('NodeDexDatabase: Recovery failed: $e');
      return false;
    }
  }

  /// Close the database.
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initCompleter = null;
    _initFailed = false;
  }

  Future<String> _defaultPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbFileName);
  }

  List<String> _tableNames() => [
    NodeDexTables.entries,
    NodeDexTables.encounters,
    NodeDexTables.seenRegions,
    NodeDexTables.coSeenEdges,
    NodeDexTables.presenceTransitions,
    NodeDexTables.syncState,
    NodeDexTables.syncOutbox,
  ];
}
