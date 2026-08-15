// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeDex Database — SQLite schema and lifecycle management.
//
// This file defines the database schema for NodeDex persistence.
// All tables, indices, and migration logic live here.
//
// Database: nodedex.db
// Schema version: 15

import 'dart:async';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../../../core/radio_scope.dart';
import '../../../services/storage/encrypted_database.dart';

import '../../../core/logging.dart';

/// Schema version for the NodeDex SQLite database.
///
/// Bump this when adding tables, columns, or indices.
/// Migration logic runs in [_onUpgrade].
///
/// Migrations must remain additive (new nullable columns or new tables
/// only) and idempotent. Downgrades retain the newest on-disk schema so
/// older binaries can keep reading it, and sqflite stamps user_version
/// down after a downgrade, so a later re-upgrade re-runs migration
/// blocks against the full schema.
const int nodedexSchemaVersion = 15;

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

  // -- Frequency offset observation columns (v10) --
  static const colLastObservedFreqOffset = 'last_observed_freq_offset';
  static const colEncFreqOffset = 'enc_freq_offset';

  // -- Connection-identity columns (v11) --
  // Stamped from myNodeNumProvider emissions only — never from packet ingest.
  static const colFirstUsedAtMs = 'first_used_at_ms';
  static const colLastUsedAtMs = 'last_used_at_ms';

  // -- Observation context columns (v12) --
  // Stamped at ingest from MeshPacket.via_mqtt + MeshNode.hopsAway. Both
  // nullable. The radio compatibility helper falls back to live MeshNode
  // metadata when these are NULL on legacy entries.
  static const colLastObservationSource = 'last_observation_source';
  static const colLastHopsAway = 'last_hops_away';

  // -- Identity tracking columns (v13) --
  // Track the Meshtastic User.public_key per entry so a firmware reset
  // / factory wipe (which preserves node_num but re-derives pubkey from
  // device entropy) is detectable. The pubkey change is recorded as an
  // event in nodedex_identity_changes; the entry's stats (encounters,
  // regions, max range, etc.) are NOT reset: the physical device is
  // continuous across rotation, so observation history stays accurate.
  // Distinct from sip_pubkey (SIP-layer only).
  static const colIdentityPubkey = 'identity_pubkey';
  static const colIdentityObservedAtMs = 'identity_observed_at_ms';
  static const colIdentityChangeCount = 'identity_change_count';
  static const colLastIdentityChangeAtMs = 'last_identity_change_at_ms';

  // -- nodedex_identity_changes (v13) --
  // One row per detected pubkey rotation per node_num. The pair
  // (previous_pubkey, new_pubkey) lets the activity timeline render
  // "Identity changed on {date}" entries with the old/new fingerprints.
  // No archived stats: the entry's own row continues to carry the
  // accumulated observation history because rotation does not change
  // the physical device's antenna, location, or range.
  static const identityChanges = 'nodedex_identity_changes';
  static const colIcId = 'id';
  static const colIcPreviousPubkey = 'previous_pubkey';
  static const colIcNewPubkey = 'new_pubkey';
  static const colIcTsMs = 'ts_ms';

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
  // Broadcast regions: derived from the remote node's own broadcast
  // position (MeshNode.latitude/longitude).
  static const seenRegions = 'nodedex_seen_regions';
  static const colRegionKey = 'region_key';
  static const colRegionLabel = 'label';
  static const colRegionFirstSeenMs = 'first_seen_ms';
  static const colRegionLastSeenMs = 'last_seen_ms';
  static const colRegionCount = 'count';

  // -- nodedex_observed_from_regions (v14) --
  // Observed-from regions: where the local radio was when the remote
  // node was encountered (derived from the user's own MeshNode lat/lon).
  // Mirrors the seenRegions schema so the same column constants are reused.
  static const observedFromRegions = 'nodedex_observed_from_regions';

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

  // -- nodedex_groups (v15) --
  // User-defined node groups. A purely local organisation concept with no
  // Meshtastic radio equivalent. deleted_at_ms is reserved for future
  // Cloud Sync tombstones; v1 hard-deletes and leaves it NULL.
  static const groups = 'nodedex_groups';
  static const colGroupId = 'id';
  static const colGroupName = 'name';
  static const colGroupColor = 'color';
  static const colGroupIconKey = 'icon_key';
  static const colGroupSortOrder = 'sort_order';
  static const colGroupCreatedAtMs = 'created_at_ms';
  static const colGroupUpdatedAtMs = 'updated_at_ms';
  static const colGroupDeletedAtMs = 'deleted_at_ms';

  // -- nodedex_node_groups (v15) --
  // Many-to-many membership join. node_num is intentionally NOT foreign-keyed
  // to nodedex_entries: a node can be grouped before it has earned a journal
  // entry. group_id references nodedex_groups; membership is cleared
  // explicitly on group delete (foreign keys are not enabled on this DB).
  static const nodeGroups = 'nodedex_node_groups';
  static const colNgGroupId = 'group_id';
  static const colNgAssignedAtMs = 'assigned_at_ms';
}

/// Manages the NodeDex SQLite database lifecycle.
///
/// Handles opening, creating, upgrading, and corruption recovery.
/// Follows the same resilient pattern used by MeshPacketDedupeStore.
class NodeDexDatabase {
  static const String _dbFileName = 'nodedex.db';

  final String? _dbPathOverride;
  final int _schemaVersion;
  Database? _db;
  Completer<Database?>? _initCompleter;
  bool _initFailed = false;

  /// [schemaVersionOverride] is a test-only affordance for opening the
  /// database as an older binary would, so downgrade handling can be
  /// exercised against the production callbacks.
  NodeDexDatabase({this._dbPathOverride, int? schemaVersionOverride})
    : _schemaVersion = schemaVersionOverride ?? nodedexSchemaVersion;

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
    return openEncryptedDatabase(
      path,
      version: _schemaVersion,
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
        ${NodeDexTables.colLastObservedOnPreset} INTEGER,             -- v9
        ${NodeDexTables.colLastObservedFreqOffset} REAL,              -- v10
        ${NodeDexTables.colFirstUsedAtMs} INTEGER,                    -- v11
        ${NodeDexTables.colLastUsedAtMs} INTEGER,                     -- v11
        ${NodeDexTables.colLastObservationSource} TEXT,               -- v12
        ${NodeDexTables.colLastHopsAway} INTEGER,                     -- v12
        ${NodeDexTables.colIdentityPubkey} BLOB,                      -- v13
        ${NodeDexTables.colIdentityObservedAtMs} INTEGER,             -- v13
        ${NodeDexTables.colIdentityChangeCount} INTEGER NOT NULL DEFAULT 0,  -- v13
        ${NodeDexTables.colLastIdentityChangeAtMs} INTEGER            -- v13
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
        ${NodeDexTables.colEncObservedOnPreset} INTEGER,              -- v9
        ${NodeDexTables.colEncFreqOffset} REAL                        -- v10
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

    // -- nodedex_observed_from_regions (v14) --
    batch.execute('''
      CREATE TABLE ${NodeDexTables.observedFromRegions} (
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

    // -- nodedex_identity_changes (v13) --
    batch.execute('''
      CREATE TABLE ${NodeDexTables.identityChanges} (
        ${NodeDexTables.colIcId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${NodeDexTables.colNodeNum} INTEGER NOT NULL,
        ${NodeDexTables.colIcPreviousPubkey} BLOB,
        ${NodeDexTables.colIcNewPubkey} BLOB NOT NULL,
        ${NodeDexTables.colIcTsMs} INTEGER NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_identity_changes_node ' // lint-allow: hardcoded-string
      'ON ${NodeDexTables.identityChanges}' // lint-allow: hardcoded-string
      '(${NodeDexTables.colNodeNum}, ${NodeDexTables.colIcTsMs} DESC)',
    );

    // -- nodedex_groups (v15) --
    batch.execute('''
      CREATE TABLE ${NodeDexTables.groups} (
        ${NodeDexTables.colGroupId} TEXT PRIMARY KEY,
        ${NodeDexTables.colGroupName} TEXT NOT NULL,
        ${NodeDexTables.colGroupColor} INTEGER NOT NULL,
        ${NodeDexTables.colGroupIconKey} TEXT NOT NULL,
        ${NodeDexTables.colGroupSortOrder} INTEGER NOT NULL DEFAULT 0,
        ${NodeDexTables.colGroupCreatedAtMs} INTEGER NOT NULL,
        ${NodeDexTables.colGroupUpdatedAtMs} INTEGER NOT NULL,
        ${NodeDexTables.colGroupDeletedAtMs} INTEGER
      )
    ''');

    // -- nodedex_node_groups (v15) --
    batch.execute('''
      CREATE TABLE ${NodeDexTables.nodeGroups} (
        ${NodeDexTables.colNodeNum} INTEGER NOT NULL,
        ${NodeDexTables.colNgGroupId} TEXT NOT NULL
          REFERENCES ${NodeDexTables.groups}(${NodeDexTables.colGroupId})
          ON DELETE CASCADE,
        ${NodeDexTables.colNgAssignedAtMs} INTEGER NOT NULL,
        PRIMARY KEY (${NodeDexTables.colNodeNum}, ${NodeDexTables.colNgGroupId})
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_node_groups_group ' // lint-allow: hardcoded-string
      'ON ${NodeDexTables.nodeGroups}(${NodeDexTables.colNgGroupId})', // lint-allow: hardcoded-string
    );

    await batch.commit(noResult: true);

    AppLogging.storage(
      'NodeDexDatabase: Created schema v$version '
      '(${_tableNames().length} tables)',
    );
  }

  /// Handle schema upgrades.
  ///
  /// Every block must be idempotent: after a downgrade the on-disk schema
  /// is newer than user_version, so re-upgrading re-runs blocks whose
  /// columns and tables already exist. A throw here fails the open and
  /// routes into [_attemptRecovery], which deletes the database file.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.storage(
      'NodeDexDatabase: Upgrading v$oldVersion -> v$newVersion',
    );

    // Re-runs are no-ops: the guard skips columns that already exist.
    final columnsByTable = <String, Set<String>>{};
    Future<void> addColumnIfMissing(
      String table,
      String column,
      String definition,
    ) async {
      final existing = columnsByTable[table] ??= (await db.rawQuery(
        'PRAGMA table_info($table)', // lint-allow: hardcoded-string
      )).map((row) => row['name'] as String).toSet();
      if (existing.contains(column)) return;
      await db.execute(
        'ALTER TABLE $table ADD COLUMN $column $definition', // lint-allow: hardcoded-string
      );
      existing.add(column);
    }

    if (oldVersion < 2) {
      // v2: Add per-field timestamps for socialTag and userNote to support
      // last-write-wins conflict resolution during Cloud Sync.
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colSocialTagUpdatedAtMs,
        'INTEGER',
      );
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colUserNoteUpdatedAtMs,
        'INTEGER',
      );
      AppLogging.storage(
        'NodeDexDatabase: v2 migration — added socialTag/userNote timestamps',
      );
    }
    if (oldVersion < 3) {
      // v3: Cache node display names so NodeDex can show meaningful names
      // even after reconnecting to a different device (when the original
      // nodes are no longer in the live nodesProvider).
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colLastKnownName,
        'TEXT',
      );
      AppLogging.storage(
        'NodeDexDatabase: v3 migration — added last_known_name column',
      );
    }
    if (oldVersion < 4) {
      // v4: Cache device info (hardware model, role, firmware version) so
      // SigilCards display this data even when the node is offline.
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colLastKnownHardware,
        'TEXT',
      );
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colLastKnownRole,
        'TEXT',
      );
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colLastKnownFirmware,
        'TEXT',
      );
      AppLogging.storage(
        'NodeDexDatabase: v4 migration — added hardware/role/firmware columns',
      );
    }
    if (oldVersion < 5) {
      // v5: Add presence_transitions table to persist presence state
      // changes for the node activity timeline.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${NodeDexTables.presenceTransitions} (
          ${NodeDexTables.colPtId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${NodeDexTables.colPtNodeNum} INTEGER NOT NULL,
          ${NodeDexTables.colPtFromState} TEXT NOT NULL,
          ${NodeDexTables.colPtToState} TEXT NOT NULL,
          ${NodeDexTables.colPtTsMs} INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_presence_transitions_node_ts ' // lint-allow: hardcoded-string
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
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colLocalNickname,
        'TEXT',
      );
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colLocalNicknameUpdatedAtMs,
        'INTEGER',
      );
      AppLogging.storage(
        'NodeDexDatabase: v6 migration — added local_nickname columns',
      );
    }
    if (oldVersion < 7) {
      // v7: Add SIP identity columns for SocialMesh Interop Profile peers.
      // All nullable — existing entries are non-SIP by default.
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colSipCapable,
        'INTEGER',
      );
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colSipPubkey,
        'BLOB',
      );
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colSipPersonaId,
        'BLOB',
      );
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colSipIdentityState,
        'TEXT',
      );
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colSipDisplayName,
        'TEXT',
      );
      AppLogging.storage(
        'NodeDexDatabase: v7 migration — added SIP identity columns',
      );
    }
    if (oldVersion < 8) {
      // v8: Add MRRP service IDs column so NodeDex can display what
      // MRRP services a peer advertises via SERVICE_ADVERT frames.
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colMrrpServiceIds,
        'TEXT',
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
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colLastObservedOnPreset,
        'INTEGER',
      );
      await addColumnIfMissing(
        NodeDexTables.encounters,
        NodeDexTables.colEncObservedOnPreset,
        'INTEGER',
      );
      AppLogging.storage(
        'NodeDexDatabase: v9 migration — added radio preset observation columns',
      );
    }
    if (oldVersion < 10) {
      // v10: Track the frequency offset of the local radio when a node
      // was observed. Stored as a float (Hz). Nullable — zero offset
      // is omitted entirely and legacy entries won't have this field.
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colLastObservedFreqOffset,
        'REAL',
      );
      await addColumnIfMissing(
        NodeDexTables.encounters,
        NodeDexTables.colEncFreqOffset,
        'REAL',
      );
      AppLogging.storage(
        'NodeDexDatabase: v10 migration — added frequency offset columns',
      );
    }
    if (oldVersion < 11) {
      // v11: Connection-identity timestamps. Stamped from
      // myNodeNumProvider emissions only — never from packet ingest. Both
      // nullable; existing entries leave them NULL forever (remote nodes)
      // or until the next time the user connects to that nodeNum (self).
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colFirstUsedAtMs,
        'INTEGER',
      );
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colLastUsedAtMs,
        'INTEGER',
      );
      AppLogging.storage(
        'NodeDexDatabase: v11 migration — added connection-identity columns',
      );
    }
    if (oldVersion < 12) {
      // v12: Observation context. Track the transport classification
      // (direct_rf / mqtt / indirect_rf / node_db / unknown) and hop
      // count of the latest observation, so reachability comparisons
      // survive reconnect. Both nullable; legacy entries leave them
      // NULL forever and the radio compatibility helper falls back to
      // the live MeshNode metadata at display time.
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colLastObservationSource,
        'TEXT',
      );
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colLastHopsAway,
        'INTEGER',
      );
      AppLogging.storage(
        'NodeDexDatabase: v12 migration — added observation context columns',
      );
    }
    if (oldVersion < 13) {
      // v13: Identity tracking. Track the Meshtastic User.public_key per
      // entry so a firmware reset (which preserves node_num but
      // re-derives pubkey) is detectable. On rotation the pubkey column
      // is updated, a change counter bumps, and a row is logged to
      // nodedex_identity_changes so the activity timeline surfaces it.
      // Stats are NOT reset: the physical device is continuous across
      // rotation, so encounters / regions / range stay accurate.
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colIdentityPubkey,
        'BLOB',
      );
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colIdentityObservedAtMs,
        'INTEGER',
      );
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colIdentityChangeCount,
        'INTEGER NOT NULL DEFAULT 0', // lint-allow: hardcoded-string
      );
      await addColumnIfMissing(
        NodeDexTables.entries,
        NodeDexTables.colLastIdentityChangeAtMs,
        'INTEGER',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${NodeDexTables.identityChanges} (
          ${NodeDexTables.colIcId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${NodeDexTables.colNodeNum} INTEGER NOT NULL,
          ${NodeDexTables.colIcPreviousPubkey} BLOB,
          ${NodeDexTables.colIcNewPubkey} BLOB NOT NULL,
          ${NodeDexTables.colIcTsMs} INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_identity_changes_node ' // lint-allow: hardcoded-string
        'ON ${NodeDexTables.identityChanges}' // lint-allow: hardcoded-string
        '(${NodeDexTables.colNodeNum}, ${NodeDexTables.colIcTsMs} DESC)',
      );
      AppLogging.storage(
        'NodeDexDatabase: v13 migration — added identity tracking columns + identity changes log',
      );
    }
    if (oldVersion < 14) {
      // v14: Observed-from regions. Records the local radio's coarse
      // region (~1°x1° geohash cell) at the time the remote node was
      // encountered. Distinct from seen_regions, which records the
      // remote node's own broadcast position. Both are nullable —
      // observed_from only gets a row when the local radio has GPS.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${NodeDexTables.observedFromRegions} (
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
      AppLogging.storage(
        'NodeDexDatabase: v14 migration — added observed_from_regions table',
      );
    }
    if (oldVersion < 15) {
      // v15: User-defined node groups (name + colour + icon) and a
      // many-to-many membership join. Local organisation concept with no
      // radio equivalent. Timestamps + deleted_at_ms make the schema
      // sync-ready; the outbox wiring is deferred to a later release.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${NodeDexTables.groups} (
          ${NodeDexTables.colGroupId} TEXT PRIMARY KEY,
          ${NodeDexTables.colGroupName} TEXT NOT NULL,
          ${NodeDexTables.colGroupColor} INTEGER NOT NULL,
          ${NodeDexTables.colGroupIconKey} TEXT NOT NULL,
          ${NodeDexTables.colGroupSortOrder} INTEGER NOT NULL DEFAULT 0,
          ${NodeDexTables.colGroupCreatedAtMs} INTEGER NOT NULL,
          ${NodeDexTables.colGroupUpdatedAtMs} INTEGER NOT NULL,
          ${NodeDexTables.colGroupDeletedAtMs} INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${NodeDexTables.nodeGroups} (
          ${NodeDexTables.colNodeNum} INTEGER NOT NULL,
          ${NodeDexTables.colNgGroupId} TEXT NOT NULL
            REFERENCES ${NodeDexTables.groups}(${NodeDexTables.colGroupId})
            ON DELETE CASCADE,
          ${NodeDexTables.colNgAssignedAtMs} INTEGER NOT NULL,
          PRIMARY KEY (${NodeDexTables.colNodeNum}, ${NodeDexTables.colNgGroupId})
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_node_groups_group ' // lint-allow: hardcoded-string
        'ON ${NodeDexTables.nodeGroups}(${NodeDexTables.colNgGroupId})', // lint-allow: hardcoded-string
      );
      AppLogging.storage(
        'NodeDexDatabase: v15 migration — added node groups + membership tables',
      );
    }
  }

  /// Downgrades retain the on-disk schema unchanged.
  ///
  /// Every shipped schema is a strict superset of older versions (columns
  /// and tables are only ever added), so an older binary reads the newer
  /// schema safely. These tables hold observation history that cannot be
  /// rebuilt, so dropping them is never acceptable. sqflite stamps
  /// user_version down after this callback returns, which is why every
  /// block in [_onUpgrade] is idempotent.
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.storage(
      'NodeDexDatabase: Downgrade requested v$oldVersion -> v$newVersion '
      '(schema retained)',
    );
  }

  /// Attempt corruption recovery by deleting and recreating.
  ///
  /// Recovery deletes the database file, so it must never be reachable
  /// from version-change handling: [_onDowngrade] is a no-op and
  /// [_onUpgrade] is idempotent for that reason.
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

  Future<String> _defaultPath() =>
      RadioScope.instance.databasePath(_dbFileName);

  List<String> _tableNames() => [
    NodeDexTables.entries,
    NodeDexTables.encounters,
    NodeDexTables.seenRegions,
    NodeDexTables.observedFromRegions,
    NodeDexTables.coSeenEdges,
    NodeDexTables.presenceTransitions,
    NodeDexTables.syncState,
    NodeDexTables.syncOutbox,
    NodeDexTables.identityChanges,
    NodeDexTables.groups,
    NodeDexTables.nodeGroups,
  ];
}
