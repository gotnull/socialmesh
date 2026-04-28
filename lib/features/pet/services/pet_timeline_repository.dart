// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetTimelineRepository — CRUD over the `pet_timeline_events` table.
//
// Responsibilities:
//   * Insert new records (idempotent via the dedupe unique index)
//   * Read ordered records for an owner
//   * Importance-aware cap enforcement: when the row count exceeds
//     [kPetTimelineMaxRowsPerOwner] the oldest MINOR rows are
//     evicted; majors + importants are immune.
//
// The recorder (`pet_timeline_recorder.dart`) is the only layer that
// writes through during normal operation. The repository is pure DB
// glue — no state diffing, no domain logic.

import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../models/pet_enums.dart';
import '../models/pet_timeline_view.dart';
import '../storage/pet_database.dart';
import 'pet_timeline_projector.dart';

class PetTimelineRepository {
  final PetDatabase _db;

  PetTimelineRepository(this._db);

  Future<void> init() => _db.open().then((_) {});

  /// Insert [records] for a single owner. Uses the dedupe unique
  /// index (owner, at_ms, kind, IFNULL(detail, '')) via
  /// `ConflictAlgorithm.ignore` so the same event written twice is a
  /// no-op — the recorder can safely re-ingest the whole
  /// `recentEvents` ring buffer on every controller emission.
  ///
  /// After insertion, enforces the per-owner cap by evicting the
  /// oldest minor rows.
  Future<void> insertAll({
    required int ownerNodeNum,
    required List<PetTimelineRecord> records,
  }) async {
    if (records.isEmpty) return;
    final db = _db.database;
    final recordedAt = DateTime.now().toUtc().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final r in records) {
        batch.insert(
          PetTables.petTimelineEvents,
          _recordToMap(r, recordedAt: recordedAt),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
      await _enforceCap(txn, ownerNodeNum);
    });

    AppLogging.pet(
      'PetTimelineRepository: ingested ${records.length} records '
      'for owner=$ownerNodeNum',
    );
  }

  /// Read every record for an owner, chronological (oldest first).
  /// The projector expects this ordering.
  Future<List<PetTimelineRecord>> loadForOwner(int ownerNodeNum) async {
    final db = _db.database;
    final rows = await db.query(
      PetTables.petTimelineEvents,
      where: '${PetTables.colTimelineOwnerNodeNum} = ?',
      whereArgs: [ownerNodeNum],
      orderBy: '${PetTables.colTimelineAtMs} ASC',
    );
    return rows.map(_mapToRecord).toList(growable: false);
  }

  /// Drop every record for an owner. Called when the user re-sigils:
  /// a new egg means a new story; the old timeline belongs to the
  /// retired creature.
  Future<void> clearForOwner(int ownerNodeNum) async {
    final db = _db.database;
    await db.delete(
      PetTables.petTimelineEvents,
      where: '${PetTables.colTimelineOwnerNodeNum} = ?',
      whereArgs: [ownerNodeNum],
    );
    AppLogging.pet(
      'PetTimelineRepository: cleared timeline for owner=$ownerNodeNum',
    );
  }

  /// Importance-aware cap enforcement. SQLite can't express the
  /// "prefer minor" rule in a single DELETE, so we read the minors
  /// beyond the cap and issue a bulk delete by id.
  Future<void> _enforceCap(Transaction txn, int ownerNodeNum) async {
    final countRow = await txn.rawQuery(
      'SELECT COUNT(*) AS c FROM ${PetTables.petTimelineEvents} ' // lint-allow: hardcoded-string
      'WHERE ${PetTables.colTimelineOwnerNodeNum} = ?', // lint-allow: hardcoded-string
      [ownerNodeNum],
    );
    final total = (countRow.first['c'] as int?) ?? 0;
    if (total <= kPetTimelineMaxRowsPerOwner) return;

    final overflow = total - kPetTimelineMaxRowsPerOwner;
    // Pick oldest minors. Importance stored as int (0=minor,
    // 1=important, 2=major).
    final toDelete = await txn.query(
      PetTables.petTimelineEvents,
      columns: [PetTables.colTimelineId],
      where:
          '${PetTables.colTimelineOwnerNodeNum} = ? AND '
          '${PetTables.colTimelineImportance} = 0',
      whereArgs: [ownerNodeNum],
      orderBy: '${PetTables.colTimelineAtMs} ASC',
      limit: overflow,
    );
    if (toDelete.isEmpty) return; // only majors + importants present
    final ids = toDelete.map((r) => r[PetTables.colTimelineId] as int).toList();
    final placeholders = List.filled(ids.length, '?').join(', ');
    await txn.delete(
      PetTables.petTimelineEvents,
      where: '${PetTables.colTimelineId} IN ($placeholders)',
      whereArgs: ids,
    );
    AppLogging.pet(
      'PetTimelineRepository: evicted ${ids.length} minor rows to enforce '
      'cap=$kPetTimelineMaxRowsPerOwner for owner=$ownerNodeNum',
    );
  }

  Map<String, Object?> _recordToMap(
    PetTimelineRecord r, {
    required int recordedAt,
  }) {
    return {
      PetTables.colTimelineOwnerNodeNum: r.ownerNodeNum,
      PetTables.colTimelineAtMs: r.at.toUtc().millisecondsSinceEpoch,
      PetTables.colTimelineKind: r.kind.name,
      PetTables.colTimelineDetail: r.detail,
      PetTables.colTimelineStage: r.stageAtEvent.name,
      PetTables.colTimelineBranch: r.branchAtEvent.name,
      PetTables.colTimelineImportance: _importanceToInt(r.importance),
      PetTables.colTimelineRecordedAtMs: recordedAt,
    };
  }

  PetTimelineRecord _mapToRecord(Map<String, Object?> row) {
    final kindName = row[PetTables.colTimelineKind] as String;
    final stageName = row[PetTables.colTimelineStage] as String;
    final branchName = row[PetTables.colTimelineBranch] as String;
    return PetTimelineRecord(
      ownerNodeNum: row[PetTables.colTimelineOwnerNodeNum] as int,
      at: DateTime.fromMillisecondsSinceEpoch(
        row[PetTables.colTimelineAtMs] as int,
        isUtc: true,
      ).toLocal(),
      kind: CareEventKind.values.firstWhere(
        (k) => k.name == kindName,
        orElse: () => CareEventKind.inspected,
      ),
      detail: row[PetTables.colTimelineDetail] as String?,
      stageAtEvent: PetStage.values.firstWhere(
        (s) => s.name == stageName,
        orElse: () => PetStage.juvenile,
      ),
      branchAtEvent: PetBranch.values.firstWhere(
        (b) => b.name == branchName,
        orElse: () => PetBranch.steady,
      ),
      importance: _importanceFromInt(
        row[PetTables.colTimelineImportance] as int,
      ),
    );
  }

  static int _importanceToInt(PetTimelineImportance i) {
    switch (i) {
      case PetTimelineImportance.minor:
        return 0;
      case PetTimelineImportance.important:
        return 1;
      case PetTimelineImportance.major:
        return 2;
    }
  }

  static PetTimelineImportance _importanceFromInt(int v) {
    switch (v) {
      case 2:
        return PetTimelineImportance.major;
      case 1:
        return PetTimelineImportance.important;
      default:
        return PetTimelineImportance.minor;
    }
  }
}
