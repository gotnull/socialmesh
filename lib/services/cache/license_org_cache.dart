// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Offline cache for license-org data. Backing file: `license_org_cache.db`.
//
// Two properties this file exists to guarantee:
//
//  1. ACCOUNT ISOLATION. Every row carries the authenticated uid that
//     fetched it and every read filters on the current uid, so one
//     account can never see another's cached fleet on a shared device.
//     `linkWithCredential` preserves the uid, so the anonymous ->
//     linked upgrade correctly keeps its rows; only a real uid change
//     purges.
//
//  2. AUTHORISATION MEMORY. `currentUserLicenseOrgIdsProvider` yields
//     an empty set both before its first Firestore snapshot AND on
//     stream error, so it cannot distinguish "offline" from "not a
//     member" and is unusable as an offline gate. Instead this cache
//     records, per (uid, orgId), that a read once succeeded. Offline
//     reads are gated on that stored authorisation.
//
// Radio scoping: this database is deliberately NOT in
// `kRadioScopedDatabases`. Org data belongs to the user, not to a
// radio, exactly like `incidents.db` and `tasks.db`.
//
// Schema rules (lib/services/storage/CLAUDE.md): never alter an existing
// column on a live build, new columns are nullable, bump the version and
// add an onUpgrade migration.
//
// See docs/teams/PHASE-1-DESIGN.md.

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/logging.dart';
import '../../models/license_org_fleet_device.dart';
import '../storage/encrypted_database.dart';

abstract final class LicenseOrgCacheTables {
  static const fleetDevices = 'license_org_fleet_devices';
  static const fleetAuthorisations = 'license_org_fleet_authorisations';

  static const colUid = 'uid';
  static const colDeviceId = 'device_id';
  static const colLicenseOrgId = 'license_org_id';
  static const colTransport = 'transport';
  static const colTransportIdentity = 'transport_identity';
  static const colLabel = 'label';
  static const colAssignedUid = 'assigned_uid';
  static const colAssignment = 'assignment';
  static const colPurpose = 'purpose';
  static const colTagsJson = 'tags_json';
  static const colNotes = 'notes';
  static const colLastKnownHardware = 'last_known_hardware';
  static const colLastKnownFirmware = 'last_known_firmware';
  static const colCreatedBy = 'created_by';
  static const colCreatedAtMs = 'created_at_ms';
  static const colUpdatedAtMs = 'updated_at_ms';
  static const colStatus = 'status';
  static const colSyncedAtMs = 'synced_at_ms';
}

/// Schema version. Bump when adding columns; add the matching migration
/// in `_onUpgrade`.
const int licenseOrgCacheSchemaVersion = 1;

/// Backing filename. Registered in `LocalDataWipeService` so account
/// deletion removes it, and deliberately absent from
/// `kRadioScopedDatabases`.
const String licenseOrgCacheDbName = 'license_org_cache.db';

/// Result of a cache read for one `(uid, orgId)` pair.
class CachedFleet {
  /// Devices matching the requested statuses, newest first.
  final List<LicenseOrgFleetDevice> devices;

  /// When this org's rows were last authoritative, or null if never.
  final DateTime? syncedAt;

  /// True when a prior successful cloud read authorised this
  /// `(uid, orgId)` pair. False means the cache must not be served,
  /// even if rows somehow exist.
  final bool authorised;

  const CachedFleet({
    required this.devices,
    required this.syncedAt,
    required this.authorised,
  });

  static const CachedFleet none = CachedFleet(
    devices: <LicenseOrgFleetDevice>[],
    syncedAt: null,
    authorised: false,
  );
}

/// SQLite-backed cache for license-org fleet data.
class LicenseOrgCache {
  /// Optional override path used in tests (in-memory or temp dir).
  final String? testDbPath;

  Database? _db;
  Future<Database>? _opening;

  LicenseOrgCache({this.testDbPath});

  /// Returns the opened database, opening it on first call.
  Future<Database> get database async {
    if (_db != null) return _db!;
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    try {
      final path = testDbPath ?? await _resolveDefaultPath();
      final db = await openEncryptedDatabase(
        path,
        version: licenseOrgCacheSchemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onDowngrade: _onDowngrade,
      );
      _db = db;
      return db;
    } catch (e) {
      AppLogging.groupLicensing(
        '[LicenseOrgCache] open failed (error class: ${e.runtimeType})',
      );
      _opening = null;
      rethrow;
    }
  }

  Future<String> _resolveDefaultPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, licenseOrgCacheDbName);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${LicenseOrgCacheTables.fleetDevices} (
        ${LicenseOrgCacheTables.colUid} TEXT NOT NULL,
        ${LicenseOrgCacheTables.colDeviceId} TEXT NOT NULL,
        ${LicenseOrgCacheTables.colLicenseOrgId} TEXT NOT NULL,
        ${LicenseOrgCacheTables.colTransport} TEXT NOT NULL,
        ${LicenseOrgCacheTables.colTransportIdentity} TEXT NOT NULL,
        ${LicenseOrgCacheTables.colLabel} TEXT NOT NULL,
        ${LicenseOrgCacheTables.colAssignedUid} TEXT,
        ${LicenseOrgCacheTables.colAssignment} TEXT NOT NULL,
        ${LicenseOrgCacheTables.colPurpose} TEXT,
        ${LicenseOrgCacheTables.colTagsJson} TEXT NOT NULL,
        ${LicenseOrgCacheTables.colNotes} TEXT,
        ${LicenseOrgCacheTables.colLastKnownHardware} TEXT,
        ${LicenseOrgCacheTables.colLastKnownFirmware} TEXT,
        ${LicenseOrgCacheTables.colCreatedBy} TEXT NOT NULL,
        ${LicenseOrgCacheTables.colCreatedAtMs} INTEGER NOT NULL,
        ${LicenseOrgCacheTables.colUpdatedAtMs} INTEGER NOT NULL,
        ${LicenseOrgCacheTables.colStatus} TEXT NOT NULL,
        PRIMARY KEY (
          ${LicenseOrgCacheTables.colUid},
          ${LicenseOrgCacheTables.colDeviceId}
        )
      )
    ''');

    // Every read filters by uid first; the org and status narrow it.
    await db.execute('''
      CREATE INDEX idx_fleet_devices_uid_org_status
      ON ${LicenseOrgCacheTables.fleetDevices} (
        ${LicenseOrgCacheTables.colUid},
        ${LicenseOrgCacheTables.colLicenseOrgId},
        ${LicenseOrgCacheTables.colStatus}
      )
    ''');

    await db.execute('''
      CREATE TABLE ${LicenseOrgCacheTables.fleetAuthorisations} (
        ${LicenseOrgCacheTables.colUid} TEXT NOT NULL,
        ${LicenseOrgCacheTables.colLicenseOrgId} TEXT NOT NULL,
        ${LicenseOrgCacheTables.colSyncedAtMs} INTEGER NOT NULL,
        PRIMARY KEY (
          ${LicenseOrgCacheTables.colUid},
          ${LicenseOrgCacheTables.colLicenseOrgId}
        )
      )
    ''');
  }

  // No migrations yet. Version 1 is the initial schema; future versions
  // add nullable columns here and never alter existing ones.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.groupLicensing(
      '[LicenseOrgCache] upgrade $oldVersion -> $newVersion (no-op at v1)',
    );
  }

  // A downgrade means the user moved to an older build. The newest
  // on-disk schema is retained; this cache is disposable, so the safe
  // move is to drop its contents rather than risk reading columns the
  // older code does not understand.
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    AppLogging.groupLicensing(
      '[LicenseOrgCache] downgrade $oldVersion -> $newVersion - clearing',
    );
    await db.delete(LicenseOrgCacheTables.fleetDevices);
    await db.delete(LicenseOrgCacheTables.fleetAuthorisations);
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    _opening = null;
    await db?.close();
  }

  /// Replace this `(uid, orgId)` pair's cached fleet with [devices] and
  /// record the pair as authorised at [syncedAt].
  ///
  /// Called only after an authoritative cloud read, which is what makes
  /// the authorisation row meaningful.
  Future<void> replaceOrgFleet({
    required String uid,
    required String licenseOrgId,
    required List<LicenseOrgFleetDevice> devices,
    required DateTime syncedAt,
  }) async {
    if (uid.isEmpty || licenseOrgId.isEmpty) return;
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        LicenseOrgCacheTables.fleetDevices,
        where:
            '${LicenseOrgCacheTables.colUid} = ? AND '
            '${LicenseOrgCacheTables.colLicenseOrgId} = ?',
        whereArgs: [uid, licenseOrgId],
      );

      for (final device in devices) {
        // Defence in depth: never let one org's rows be written under
        // another org's key.
        if (device.licenseOrgId != licenseOrgId) continue;
        await txn.insert(
          LicenseOrgCacheTables.fleetDevices,
          _toRow(uid, device),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await txn.insert(
        LicenseOrgCacheTables.fleetAuthorisations,
        <String, Object?>{
          LicenseOrgCacheTables.colUid: uid,
          LicenseOrgCacheTables.colLicenseOrgId: licenseOrgId,
          LicenseOrgCacheTables.colSyncedAtMs: syncedAt
              .toUtc()
              .millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    AppLogging.groupLicensing(
      '[LicenseOrgCache] cached fleet (devices=${devices.length})',
    );
  }

  /// Read this `(uid, orgId)` pair's cached fleet.
  ///
  /// Returns [CachedFleet.none] when the pair was never authorised, so
  /// a caller cannot accidentally serve rows that no successful read
  /// ever backed.
  Future<CachedFleet> readOrgFleet({
    required String uid,
    required String licenseOrgId,
    Set<FleetDeviceStatus> statuses = const {FleetDeviceStatus.active},
  }) async {
    if (uid.isEmpty || licenseOrgId.isEmpty) return CachedFleet.none;
    final db = await database;

    final authRows = await db.query(
      LicenseOrgCacheTables.fleetAuthorisations,
      where:
          '${LicenseOrgCacheTables.colUid} = ? AND '
          '${LicenseOrgCacheTables.colLicenseOrgId} = ?',
      whereArgs: [uid, licenseOrgId],
      limit: 1,
    );
    if (authRows.isEmpty) return CachedFleet.none;

    final syncedAtMs =
        authRows.first[LicenseOrgCacheTables.colSyncedAtMs] as int?;
    final syncedAt = syncedAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(syncedAtMs, isUtc: true);

    // "status in the empty set" matches nothing, so return nothing.
    // Dropping the predicate instead would return EVERY status, which
    // is the opposite answer and would disagree with the repository -
    // the cache would surface retired rows the cloud read excluded.
    // The authorisation still stands, so this is an empty authorised
    // result rather than CachedFleet.none.
    if (statuses.isEmpty) {
      return CachedFleet(
        devices: const <LicenseOrgFleetDevice>[],
        syncedAt: syncedAt,
        authorised: true,
      );
    }

    final wireStatuses = statuses.map((s) => s.toWire()).toList();
    final placeholders = List.filled(wireStatuses.length, '?').join(', ');
    final rows = await db.query(
      LicenseOrgCacheTables.fleetDevices,
      where:
          '${LicenseOrgCacheTables.colUid} = ? AND '
          '${LicenseOrgCacheTables.colLicenseOrgId} = ? AND '
          '${LicenseOrgCacheTables.colStatus} IN ($placeholders)',
      whereArgs: [uid, licenseOrgId, ...wireStatuses],
      orderBy: '${LicenseOrgCacheTables.colUpdatedAtMs} DESC',
    );

    final devices = <LicenseOrgFleetDevice>[];
    for (final row in rows) {
      final device = _fromRow(row);
      // A row that no longer parses is dropped rather than failing the
      // whole read - one corrupt cache entry must not blank the fleet.
      if (device != null) devices.add(device);
    }

    return CachedFleet(
      devices: List<LicenseOrgFleetDevice>.unmodifiable(devices),
      syncedAt: syncedAt,
      authorised: true,
    );
  }

  /// Drop one org's rows and its authorisation for [uid].
  ///
  /// Called on an authoritative access denial - the server said no, so
  /// the offline copy must not outlive that answer.
  Future<void> purgeOrg({
    required String uid,
    required String licenseOrgId,
  }) async {
    if (uid.isEmpty || licenseOrgId.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        LicenseOrgCacheTables.fleetDevices,
        where:
            '${LicenseOrgCacheTables.colUid} = ? AND '
            '${LicenseOrgCacheTables.colLicenseOrgId} = ?',
        whereArgs: [uid, licenseOrgId],
      );
      await txn.delete(
        LicenseOrgCacheTables.fleetAuthorisations,
        where:
            '${LicenseOrgCacheTables.colUid} = ? AND '
            '${LicenseOrgCacheTables.colLicenseOrgId} = ?',
        whereArgs: [uid, licenseOrgId],
      );
    });
    AppLogging.groupLicensing('[LicenseOrgCache] purged org rows after denial');
  }

  /// Drop every row belonging to [uid].
  ///
  /// Called on a real account transition. Rows are uid-keyed so a
  /// different account could not read them anyway; purging is defence
  /// in depth and keeps a departed account's data off the device.
  Future<int> purgeUid(String uid) async {
    if (uid.isEmpty) return 0;
    final db = await database;
    var deleted = 0;
    await db.transaction((txn) async {
      deleted += await txn.delete(
        LicenseOrgCacheTables.fleetDevices,
        where: '${LicenseOrgCacheTables.colUid} = ?',
        whereArgs: [uid],
      );
      await txn.delete(
        LicenseOrgCacheTables.fleetAuthorisations,
        where: '${LicenseOrgCacheTables.colUid} = ?',
        whereArgs: [uid],
      );
    });
    AppLogging.groupLicensing(
      '[LicenseOrgCache] purged rows for departing account (rows=$deleted)',
    );
    return deleted;
  }

  /// Drop everything. Used by the local-data wipe path.
  Future<void> purgeAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(LicenseOrgCacheTables.fleetDevices);
      await txn.delete(LicenseOrgCacheTables.fleetAuthorisations);
    });
  }

  static Map<String, Object?> _toRow(String uid, LicenseOrgFleetDevice d) {
    return <String, Object?>{
      LicenseOrgCacheTables.colUid: uid,
      LicenseOrgCacheTables.colDeviceId: d.id,
      LicenseOrgCacheTables.colLicenseOrgId: d.licenseOrgId,
      LicenseOrgCacheTables.colTransport: d.transport.toWire(),
      LicenseOrgCacheTables.colTransportIdentity: d.transportIdentity,
      LicenseOrgCacheTables.colLabel: d.label,
      LicenseOrgCacheTables.colAssignedUid: d.assignedUid,
      LicenseOrgCacheTables.colAssignment: d.assignment.toWire(),
      LicenseOrgCacheTables.colPurpose: d.purpose,
      LicenseOrgCacheTables.colTagsJson: jsonEncode(d.tags),
      LicenseOrgCacheTables.colNotes: d.notes,
      LicenseOrgCacheTables.colLastKnownHardware: d.lastKnownHardware,
      LicenseOrgCacheTables.colLastKnownFirmware: d.lastKnownFirmware,
      LicenseOrgCacheTables.colCreatedBy: d.createdBy,
      LicenseOrgCacheTables.colCreatedAtMs: d.createdAt
          .toUtc()
          .millisecondsSinceEpoch,
      LicenseOrgCacheTables.colUpdatedAtMs: d.updatedAt
          .toUtc()
          .millisecondsSinceEpoch,
      LicenseOrgCacheTables.colStatus: d.status.toWire(),
    };
  }

  static LicenseOrgFleetDevice? _fromRow(Map<String, Object?> row) {
    final id = row[LicenseOrgCacheTables.colDeviceId];
    final licenseOrgId = row[LicenseOrgCacheTables.colLicenseOrgId];
    final transportIdentity = row[LicenseOrgCacheTables.colTransportIdentity];
    final createdBy = row[LicenseOrgCacheTables.colCreatedBy];
    final createdAtMs = row[LicenseOrgCacheTables.colCreatedAtMs];
    final updatedAtMs = row[LicenseOrgCacheTables.colUpdatedAtMs];

    if (id is! String ||
        licenseOrgId is! String ||
        transportIdentity is! String ||
        createdBy is! String ||
        createdAtMs is! int ||
        updatedAtMs is! int) {
      return null;
    }

    final transport = FleetTransport.fromWire(
      row[LicenseOrgCacheTables.colTransport] as String?,
    );
    if (transport == FleetTransport.unknown) return null;

    final tags = <String>[];
    final tagsJson = row[LicenseOrgCacheTables.colTagsJson];
    if (tagsJson is String && tagsJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(tagsJson);
        if (decoded is List) {
          for (final tag in decoded) {
            if (tag is String && tag.isNotEmpty) tags.add(tag);
          }
        }
      } catch (_) {
        // A corrupt tag blob costs the tags, not the device.
      }
    }

    return LicenseOrgFleetDevice(
      id: id,
      licenseOrgId: licenseOrgId,
      transport: transport,
      transportIdentity: transportIdentity,
      label: (row[LicenseOrgCacheTables.colLabel] as String?) ?? '',
      assignedUid: row[LicenseOrgCacheTables.colAssignedUid] as String?,
      assignment: FleetAssignmentKind.fromWire(
        row[LicenseOrgCacheTables.colAssignment] as String?,
      ),
      purpose: row[LicenseOrgCacheTables.colPurpose] as String?,
      tags: List<String>.unmodifiable(tags),
      notes: row[LicenseOrgCacheTables.colNotes] as String?,
      lastKnownHardware:
          row[LicenseOrgCacheTables.colLastKnownHardware] as String?,
      lastKnownFirmware:
          row[LicenseOrgCacheTables.colLastKnownFirmware] as String?,
      createdBy: createdBy,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs, isUtc: true),
      status: FleetDeviceStatus.fromWire(
        row[LicenseOrgCacheTables.colStatus] as String?,
      ),
    );
  }
}
