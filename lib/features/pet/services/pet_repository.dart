// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetRepository — thin CRUD layer over pet.db for owner-side pet state.
//
// Owns the serialization boundary: provider layer works with PetState,
// storage layer works with JSON text. The repository also exposes a remote
// cache surface that later phases will fill; for v1 it's stub-safe and
// unused.

import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../models/pet_state.dart';
import '../storage/pet_database.dart';

class PetRepository {
  final PetDatabase _db;

  PetRepository(this._db);

  Future<void> init() => _db.open().then((_) {});

  Future<PetState?> loadOwnPet(int ownerNodeNum) async {
    final db = _db.database;
    final rows = await db.query(
      PetTables.ownPet,
      where: '${PetTables.colOwnerNodeNum} = ?',
      whereArgs: [ownerNodeNum],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final blob = rows.first[PetTables.colStateBlob] as String?;
      if (blob == null || blob.isEmpty) return null;
      return PetState.fromJsonString(blob);
    } catch (e, st) {
      AppLogging.pet('PetRepository: loadOwnPet decode failed: $e\n$st');
      return null;
    }
  }

  Future<void> saveOwnPet(PetState state) async {
    final db = _db.database;
    await db.insert(PetTables.ownPet, {
      PetTables.colOwnerNodeNum: state.ownerNodeNum,
      PetTables.colStateBlob: state.toJsonString(),
      PetTables.colSchemaVersion: petSchemaVersion,
      PetTables.colUpdatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearOwnPet(int ownerNodeNum) async {
    final db = _db.database;
    await db.delete(
      PetTables.ownPet,
      where: '${PetTables.colOwnerNodeNum} = ?',
      whereArgs: [ownerNodeNum],
    );
  }

  Future<void> close() => _db.close();
}
