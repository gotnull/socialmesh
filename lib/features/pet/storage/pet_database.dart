// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pet Database — SQLite schema for the owner-side pet state and remote cache.
//
// Database: pet.db
// Schema version: 1
//
// Tables:
//   - own_pet           : single-row-per-owner JSON blob of the full PetState
//   - remote_pet_cache  : compact PetPublicState observations of other nodes
//
// Keyed strictly by `ownerNodeNum`. When the user connects a different
// device, a new ownerNodeNum lands and a fresh pet is hatched. Cross-device
// migration is a v2 concern.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';

const int petSchemaVersion = 1;

abstract final class PetTables {
  static const ownPet = 'own_pet';
  static const colOwnerNodeNum = 'owner_node_num';
  static const colStateBlob = 'state_blob';
  static const colSchemaVersion = 'schema_version';
  static const colUpdatedAt = 'updated_at';

  static const remotePetCache = 'remote_pet_cache';
  static const colRemoteNodeNum = 'node_num';
  static const colPublicStateBlob = 'public_state_blob';
  static const colObservedAt = 'observed_at';
  static const colSourceFlags = 'source_flags';
}

/// Lifecycle manager for pet.db. Follows the TracerouteDatabase pattern:
/// WAL journal mode, completer-gated initialization, safe reopen on error.
class PetDatabase {
  static const String _dbFileName = 'pet.db';

  final String? _dbPathOverride;
  Database? _db;
  Completer<Database?>? _initCompleter;
  bool _initFailed = false;

  PetDatabase({String? dbPathOverride}) : _dbPathOverride = dbPathOverride;

  Database get database {
    if (_db == null || !_db!.isOpen) {
      throw StateError('PetDatabase not initialized. Call open() first.');
    }
    return _db!;
  }

  bool get isOpen => _db != null && _db!.isOpen;

  Future<Database> open() async {
    if (_db != null && _db!.isOpen) return _db!;
    if (_initFailed) {
      throw StateError('PetDatabase init failed permanently.');
    }
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      final result = await _initCompleter!.future;
      if (result == null) {
        throw StateError('PetDatabase init failed.');
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
      AppLogging.storage('PetDatabase: first open failed: $e');
      if (!await _attemptRecovery(path)) {
        AppLogging.storage('PetDatabase: recovery failed');
        rethrow;
      }
    }
  }

  Future<Database> _attemptOpen(String path) {
    return openDatabase(
      path,
      version: petSchemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    final walResult = await db.rawQuery('PRAGMA journal_mode=WAL');
    if (_dbPathOverride == null) {
      assert(
        walResult.isNotEmpty && walResult.first['journal_mode'] == 'wal',
        'WAL mode not active',
      ); // lint-allow: hardcoded-string
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE ${PetTables.ownPet} (
        ${PetTables.colOwnerNodeNum} INTEGER PRIMARY KEY,
        ${PetTables.colStateBlob} TEXT NOT NULL,
        ${PetTables.colSchemaVersion} INTEGER NOT NULL,
        ${PetTables.colUpdatedAt} INTEGER NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE ${PetTables.remotePetCache} (
        ${PetTables.colRemoteNodeNum} INTEGER PRIMARY KEY,
        ${PetTables.colPublicStateBlob} BLOB NOT NULL,
        ${PetTables.colObservedAt} INTEGER NOT NULL,
        ${PetTables.colSourceFlags} INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute(
      'CREATE INDEX idx_remote_pet_observed_at ' // lint-allow: hardcoded-string
      'ON ${PetTables.remotePetCache}(${PetTables.colObservedAt})', // lint-allow: hardcoded-string
    );

    await batch.commit(noResult: true);

    AppLogging.storage('PetDatabase: created schema v$version');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.storage('PetDatabase: upgrading v$oldVersion -> v$newVersion');
    // No migrations yet — v1 is the initial schema.
  }

  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.storage(
      'PetDatabase: downgrade requested v$oldVersion -> v$newVersion '
      '(ignored)',
    );
  }

  Future<bool> _attemptRecovery(String path) async {
    try {
      if (await File(path).exists()) {
        await File(path).delete();
        AppLogging.storage('PetDatabase: deleted corrupted file at $path');
      }
      _db = await _attemptOpen(path);
      return true;
    } catch (e) {
      AppLogging.storage('PetDatabase: recovery open failed: $e');
      return false;
    }
  }

  Future<String> _defaultPath() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, _dbFileName);
  }

  Future<void> close() async {
    try {
      await _db?.close();
    } catch (_) {
      // no-op
    }
    _db = null;
    _initCompleter = null;
  }
}
