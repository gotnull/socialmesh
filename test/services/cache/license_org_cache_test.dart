// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Account isolation and authorisation-memory tests for the license-org
// cache.
//
// The load-bearing property is that one Firebase account can never read
// another's cached fleet on a shared device. The second is that the
// cache remembers a prior successful cloud read per (uid, orgId), which
// is what lets the provider serve stale data during a network failure
// without ever serving data no successful read backed.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/radio_scope.dart';
import 'package:socialmesh/models/license_org_fleet_device.dart';
import 'package:socialmesh/services/cache/license_org_cache.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _uidA = 'account-a-uid';
const String _uidB = 'account-b-uid';
const String _orgOne = 'acme-team';
const String _orgTwo = 'alpine-expedition';

LicenseOrgFleetDevice _device({
  String licenseOrgId = _orgOne,
  String transportIdentity = 'mt-81c42d94',
  FleetDeviceStatus status = FleetDeviceStatus.active,
  String label = 'North Gate',
  DateTime? updatedAt,
}) {
  final moment = updatedAt ?? DateTime.utc(2026, 8, 15, 2, 30);
  return LicenseOrgFleetDevice(
    id: fleetDeviceIdFor(
      licenseOrgId: licenseOrgId,
      transportIdentity: transportIdentity,
    )!,
    licenseOrgId: licenseOrgId,
    transport: FleetTransport.meshtastic,
    transportIdentity: transportIdentity,
    label: label,
    assignedUid: null,
    assignment: FleetAssignmentKind.unassigned,
    purpose: 'Gate Operations',
    tags: const ['gate', 'fixed'],
    notes: 'Roof mount.',
    lastKnownHardware: 'TRACKER_T1000_E',
    lastKnownFirmware: '2.7.19',
    createdBy: 'admin-uid-1',
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: moment,
    status: status,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LicenseOrgCache cache;

  setUp(() {
    cache = LicenseOrgCache(testDbPath: inMemoryDatabasePath);
  });

  tearDown(() async {
    await cache.close();
  });

  group('schema', () {
    test('a fresh install opens cleanly at v1', () async {
      final db = await cache.database;
      expect(await db.getVersion(), licenseOrgCacheSchemaVersion);
      expect(licenseOrgCacheSchemaVersion, 1);
    });

    test('both tables exist after create', () async {
      final db = await cache.database;
      final tables = await db.query(
        'sqlite_master',
        columns: ['name'],
        where: 'type = ?',
        whereArgs: ['table'],
      );
      final names = tables.map((r) => r['name'] as String).toSet();
      expect(names, contains(LicenseOrgCacheTables.fleetDevices));
      expect(names, contains(LicenseOrgCacheTables.fleetAuthorisations));
    });
  });

  group('radio scoping', () {
    test('is NOT a radio-scoped database', () {
      // Org data belongs to the user, not to a radio. Adding this file
      // to the scoped set would silo a team's fleet per connected
      // radio and lose it on a radio switch.
      final scopedNames = kRadioScopedDatabases.map((f) => f.fileName).toSet();
      expect(scopedNames, isNot(contains(licenseOrgCacheDbName)));
    });

    test('is registered for account-deletion wipe', () {
      // The wipe list is private, so this pins it by source text -
      // the established convention for this kind of registration
      // invariant in this repo.
      final src = File(
        'lib/services/local_data_wipe_service.dart',
      ).readAsStringSync();
      expect(
        src,
        contains("'$licenseOrgCacheDbName'"),
        reason: 'account deletion must remove the license-org cache file',
      );
    });
  });

  group('round trip', () {
    test('writes then reads back a fleet', () async {
      final syncedAt = DateTime.utc(2026, 8, 15, 3);
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
        devices: [_device()],
        syncedAt: syncedAt,
      );

      final result = await cache.readOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
      );

      expect(result.authorised, isTrue);
      expect(result.syncedAt, syncedAt);
      expect(result.devices, hasLength(1));
      final device = result.devices.single;
      expect(device.label, 'North Gate');
      expect(device.tags, ['gate', 'fixed']);
      expect(device.transport, FleetTransport.meshtastic);
      expect(device.createdAt, DateTime.utc(2026, 8, 1));
    });

    test(
      'replacing supersedes the previous rows rather than merging',
      () async {
        await cache.replaceOrgFleet(
          uid: _uidA,
          licenseOrgId: _orgOne,
          devices: [
            _device(transportIdentity: 'mt-00000001'),
            _device(transportIdentity: 'mt-00000002'),
          ],
          syncedAt: DateTime.utc(2026, 8, 15, 3),
        );
        await cache.replaceOrgFleet(
          uid: _uidA,
          licenseOrgId: _orgOne,
          devices: [_device(transportIdentity: 'mt-00000001')],
          syncedAt: DateTime.utc(2026, 8, 15, 4),
        );

        final result = await cache.readOrgFleet(
          uid: _uidA,
          licenseOrgId: _orgOne,
        );
        expect(result.devices, hasLength(1));
        expect(result.devices.single.transportIdentity, 'mt-00000001');
      },
    );

    test('orders newest first', () async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
        devices: [
          _device(
            transportIdentity: 'mt-00000001',
            label: 'older',
            updatedAt: DateTime.utc(2026, 8, 1),
          ),
          _device(
            transportIdentity: 'mt-00000002',
            label: 'newer',
            updatedAt: DateTime.utc(2026, 8, 14),
          ),
        ],
        syncedAt: DateTime.utc(2026, 8, 15),
      );

      final result = await cache.readOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
      );
      expect(result.devices.map((d) => d.label), ['newer', 'older']);
    });

    test('refuses to file a device under a mismatched org key', () async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
        devices: [_device(licenseOrgId: _orgTwo)],
        syncedAt: DateTime.utc(2026, 8, 15),
      );

      final one = await cache.readOrgFleet(uid: _uidA, licenseOrgId: _orgOne);
      final two = await cache.readOrgFleet(uid: _uidA, licenseOrgId: _orgTwo);
      expect(one.devices, isEmpty);
      expect(two.authorised, isFalse);
    });
  });

  group('account isolation', () {
    test("account B cannot read account A's cached fleet", () async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
        devices: [_device()],
        syncedAt: DateTime.utc(2026, 8, 15),
      );

      final asB = await cache.readOrgFleet(uid: _uidB, licenseOrgId: _orgOne);

      expect(asB.authorised, isFalse);
      expect(asB.devices, isEmpty);
      expect(asB.syncedAt, isNull);
    });

    test('the two accounts keep independent rows for the same org', () async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
        devices: [_device(label: 'A view')],
        syncedAt: DateTime.utc(2026, 8, 15),
      );
      await cache.replaceOrgFleet(
        uid: _uidB,
        licenseOrgId: _orgOne,
        devices: [_device(label: 'B view')],
        syncedAt: DateTime.utc(2026, 8, 15),
      );

      final a = await cache.readOrgFleet(uid: _uidA, licenseOrgId: _orgOne);
      final b = await cache.readOrgFleet(uid: _uidB, licenseOrgId: _orgOne);
      expect(a.devices.single.label, 'A view');
      expect(b.devices.single.label, 'B view');
    });

    test('purging the departing account leaves the other intact', () async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
        devices: [_device()],
        syncedAt: DateTime.utc(2026, 8, 15),
      );
      await cache.replaceOrgFleet(
        uid: _uidB,
        licenseOrgId: _orgOne,
        devices: [_device()],
        syncedAt: DateTime.utc(2026, 8, 15),
      );

      await cache.purgeUid(_uidA);

      final a = await cache.readOrgFleet(uid: _uidA, licenseOrgId: _orgOne);
      final b = await cache.readOrgFleet(uid: _uidB, licenseOrgId: _orgOne);
      expect(a.authorised, isFalse);
      expect(a.devices, isEmpty);
      expect(b.devices, hasLength(1));
    });

    test('a uid-preserving upgrade keeps the cache', () async {
      // linkWithCredential turns an anonymous account into a permanent
      // one WITHOUT changing the uid. Purging on that transition would
      // needlessly drop valid offline data, which is exactly why rows
      // are keyed by uid rather than cleared on any auth event.
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
        devices: [_device()],
        syncedAt: DateTime.utc(2026, 8, 15),
      );

      // No purge call: the uid did not change.
      final afterLink = await cache.readOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
      );
      expect(afterLink.authorised, isTrue);
      expect(afterLink.devices, hasLength(1));
    });

    test('purgeUid on an empty uid is a no-op', () async {
      expect(await cache.purgeUid(''), 0);
    });
  });

  group('authorisation memory', () {
    test('an unread org is unauthorised, not merely empty', () async {
      final result = await cache.readOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
      );
      expect(result.authorised, isFalse);
      expect(result.devices, isEmpty);
    });

    test('an authoritative denial purges rows and authorisation', () async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
        devices: [_device()],
        syncedAt: DateTime.utc(2026, 8, 15),
      );
      await cache.purgeOrg(uid: _uidA, licenseOrgId: _orgOne);

      final result = await cache.readOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
      );
      expect(result.authorised, isFalse);
      expect(result.devices, isEmpty);
    });

    test('denial for one org leaves the other org authorised', () async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
        devices: [_device()],
        syncedAt: DateTime.utc(2026, 8, 15),
      );
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgTwo,
        devices: [_device(licenseOrgId: _orgTwo)],
        syncedAt: DateTime.utc(2026, 8, 15),
      );

      await cache.purgeOrg(uid: _uidA, licenseOrgId: _orgOne);

      expect(
        (await cache.readOrgFleet(
          uid: _uidA,
          licenseOrgId: _orgOne,
        )).authorised,
        isFalse,
      );
      expect(
        (await cache.readOrgFleet(
          uid: _uidA,
          licenseOrgId: _orgTwo,
        )).authorised,
        isTrue,
      );
    });

    test(
      'an empty authorised fleet is distinguishable from unauthorised',
      () async {
        await cache.replaceOrgFleet(
          uid: _uidA,
          licenseOrgId: _orgOne,
          devices: const [],
          syncedAt: DateTime.utc(2026, 8, 15),
        );

        final result = await cache.readOrgFleet(
          uid: _uidA,
          licenseOrgId: _orgOne,
        );
        expect(result.authorised, isTrue);
        expect(result.devices, isEmpty);
        expect(result.syncedAt, isNotNull);
      },
    );
  });

  group('status filter', () {
    setUp(() async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
        devices: [
          _device(transportIdentity: 'mt-00000001', label: 'live'),
          _device(
            transportIdentity: 'mt-00000002',
            label: 'gone',
            status: FleetDeviceStatus.retired,
          ),
        ],
        syncedAt: DateTime.utc(2026, 8, 15),
      );
    });

    test('defaults to active only', () async {
      final result = await cache.readOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
      );
      expect(result.devices.map((d) => d.label), ['live']);
    });

    test('retired rows stay reachable when asked for', () async {
      // Soft-deleted records must not become permanently invisible.
      final result = await cache.readOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
        statuses: const {FleetDeviceStatus.active, FleetDeviceStatus.retired},
      );
      expect(result.devices.map((d) => d.label).toSet(), {'live', 'gone'});
    });

    test('retired only', () async {
      final result = await cache.readOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
        statuses: const {FleetDeviceStatus.retired},
      );
      expect(result.devices.map((d) => d.label), ['gone']);
    });

    test('an empty status set matches nothing, not everything', () async {
      // "status in the empty set" is mathematically empty. Dropping the
      // predicate instead would return every status - the opposite
      // answer - and would disagree with the repository, so the cache
      // would surface retired rows the cloud read excluded.
      final result = await cache.readOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
        statuses: const <FleetDeviceStatus>{},
      );
      expect(result.devices, isEmpty);
      // The authorisation still stands; only the filter matched nothing.
      expect(result.authorised, isTrue);
      expect(result.syncedAt, isNotNull);
    });
  });

  group('corrupt rows', () {
    test('one bad row is dropped, the rest survive', () async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
        devices: [_device(transportIdentity: 'mt-00000001', label: 'good')],
        syncedAt: DateTime.utc(2026, 8, 15),
      );

      // Inject a row with an unparseable transport directly, bypassing
      // the typed writer.
      final db = await cache.database;
      await db.insert(LicenseOrgCacheTables.fleetDevices, {
        LicenseOrgCacheTables.colUid: _uidA,
        LicenseOrgCacheTables.colDeviceId: '${_orgOne}__mt-00000009',
        LicenseOrgCacheTables.colLicenseOrgId: _orgOne,
        LicenseOrgCacheTables.colTransport: 'carrier-pigeon',
        LicenseOrgCacheTables.colTransportIdentity: 'mt-00000009',
        LicenseOrgCacheTables.colLabel: 'corrupt',
        LicenseOrgCacheTables.colAssignment: 'unassigned',
        LicenseOrgCacheTables.colTagsJson: '[]',
        LicenseOrgCacheTables.colCreatedBy: 'admin-uid-1',
        LicenseOrgCacheTables.colCreatedAtMs: 0,
        LicenseOrgCacheTables.colUpdatedAtMs: 0,
        LicenseOrgCacheTables.colStatus: 'active',
      });

      final result = await cache.readOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
      );
      expect(result.devices.map((d) => d.label), ['good']);
    });

    test('a corrupt tag blob costs the tags, not the device', () async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
        devices: [_device()],
        syncedAt: DateTime.utc(2026, 8, 15),
      );

      final db = await cache.database;
      await db.update(
        LicenseOrgCacheTables.fleetDevices,
        {LicenseOrgCacheTables.colTagsJson: 'not-json'},
        where: '${LicenseOrgCacheTables.colUid} = ?',
        whereArgs: [_uidA],
      );

      final result = await cache.readOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
      );
      expect(result.devices, hasLength(1));
      expect(result.devices.single.tags, isEmpty);
    });
  });

  group('purgeAll', () {
    test('clears every account', () async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _orgOne,
        devices: [_device()],
        syncedAt: DateTime.utc(2026, 8, 15),
      );
      await cache.replaceOrgFleet(
        uid: _uidB,
        licenseOrgId: _orgTwo,
        devices: [_device(licenseOrgId: _orgTwo)],
        syncedAt: DateTime.utc(2026, 8, 15),
      );

      await cache.purgeAll();

      expect(
        (await cache.readOrgFleet(
          uid: _uidA,
          licenseOrgId: _orgOne,
        )).authorised,
        isFalse,
      );
      expect(
        (await cache.readOrgFleet(
          uid: _uidB,
          licenseOrgId: _orgTwo,
        )).authorised,
        isFalse,
      );
    });
  });
}
