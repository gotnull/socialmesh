// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetRepository — thin CRUD layer over pet.db for owner-side pet state
// and the remote pet cache.

import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../models/pet_public_state.dart';
import '../models/pet_state.dart';
import '../services/pet_public_state_codec.dart';
import '../storage/pet_database.dart';

/// One row of the remote pet cache: the decoded public state for a peer
/// node plus the wall-clock timestamp we observed it at.
class RemotePetObservation {
  final int nodeNum;
  final PetPublicState state;
  final DateTime observedAt;

  const RemotePetObservation({
    required this.nodeNum,
    required this.state,
    required this.observedAt,
  });

  Duration ageFrom(DateTime now) => now.difference(observedAt);
}

class PetRepository {
  final PetDatabase _db;

  PetRepository(this._db);

  Future<void> init() => _db.open().then((_) {});

  // ---- Own pet --------------------------------------------------------

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

  // ---- Remote pet cache ----------------------------------------------

  /// Load the most-recent cached public state for [nodeNum], or null if
  /// we've never observed that peer.
  Future<RemotePetObservation?> loadRemotePet(int nodeNum) async {
    final db = _db.database;
    final rows = await db.query(
      PetTables.remotePetCache,
      where: '${PetTables.colRemoteNodeNum} = ?',
      whereArgs: [nodeNum],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final blob = rows.first[PetTables.colPublicStateBlob] as List<int>?;
      final observedMs = rows.first[PetTables.colObservedAt] as int?;
      if (blob == null || observedMs == null) return null;
      final decoded = PetPublicStateCodec.tryDecode(Uint8List.fromList(blob));
      if (decoded == null) return null;
      return RemotePetObservation(
        nodeNum: nodeNum,
        state: decoded,
        observedAt: DateTime.fromMillisecondsSinceEpoch(
          observedMs,
          isUtc: true,
        ).toLocal(),
      );
    } catch (e) {
      AppLogging.pet('PetRepository: loadRemotePet decode failed: $e');
      return null;
    }
  }

  /// Persist a freshly-observed public state for a peer. Replaces the
  /// previous observation unconditionally.
  Future<void> saveRemotePet({
    required int nodeNum,
    required PetPublicState state,
    required DateTime observedAt,
  }) async {
    final db = _db.database;
    final bytes = PetPublicStateCodec.encode(state);
    await db.insert(PetTables.remotePetCache, {
      PetTables.colRemoteNodeNum: nodeNum,
      PetTables.colPublicStateBlob: bytes,
      PetTables.colObservedAt: observedAt.toUtc().millisecondsSinceEpoch,
      PetTables.colSourceFlags: 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Remove a peer's cached observation. Used when a peer's sigil is
  /// invalidated (re-sigil, reset) and we want to force a fresh fetch.
  Future<void> clearRemotePet(int nodeNum) async {
    final db = _db.database;
    await db.delete(
      PetTables.remotePetCache,
      where: '${PetTables.colRemoteNodeNum} = ?',
      whereArgs: [nodeNum],
    );
  }

  /// List all cached observations newer than [maxAge]. Useful for warming
  /// the NodeDex list. Returns observations ordered newest-first.
  Future<List<RemotePetObservation>> recentRemotePets({
    required Duration maxAge,
    int limit = 128,
  }) async {
    final db = _db.database;
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(maxAge)
        .millisecondsSinceEpoch;
    final rows = await db.query(
      PetTables.remotePetCache,
      where: '${PetTables.colObservedAt} >= ?',
      whereArgs: [cutoff],
      orderBy: '${PetTables.colObservedAt} DESC',
      limit: limit,
    );
    final out = <RemotePetObservation>[];
    for (final row in rows) {
      final n = row[PetTables.colRemoteNodeNum] as int?;
      final blob = row[PetTables.colPublicStateBlob] as List<int>?;
      final observedMs = row[PetTables.colObservedAt] as int?;
      if (n == null || blob == null || observedMs == null) continue;
      final decoded = PetPublicStateCodec.tryDecode(Uint8List.fromList(blob));
      if (decoded == null) continue;
      out.add(
        RemotePetObservation(
          nodeNum: n,
          state: decoded,
          observedAt: DateTime.fromMillisecondsSinceEpoch(
            observedMs,
            isUtc: true,
          ).toLocal(),
        ),
      );
    }
    return out;
  }

  Future<void> close() => _db.close();
}
