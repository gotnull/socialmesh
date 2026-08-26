// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Behaviour tests for the fleet provider, driven through an injected
// stub repository and a real in-memory cache.
//
// The stub exists to control what the CLOUD returns; every assertion is
// about what the PROVIDER does with that - which snapshot it emits,
// whether it keeps or purges the offline copy, and whether it ever
// leaks one account's rows to another. No test asserts that the stub
// returns what the stub was told to return.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/license_org_fleet_device.dart';
import 'package:socialmesh/providers/auth_providers.dart';
import 'package:socialmesh/providers/license_org_fleet_providers.dart';
import 'package:socialmesh/services/cache/license_org_cache.dart';
import 'package:socialmesh/services/org/license_org_fleet_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _uidA = 'account-a-uid';
const String _uidB = 'account-b-uid';
const String _org = 'acme-team';

// Minimal User fake. Only [uid] and [isAnonymous] are read by the
// provider; any other call throws NoSuchMethodError, which surfaces
// loudly if the provider's contract ever expands.
class _FakeUser implements User {
  @override
  final String uid;
  @override
  final bool isAnonymous;

  _FakeUser({required this.uid, this.isAnonymous = false});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// A Firestore that throws on any use at all. If the empty-status guard
// ever stops short-circuiting, this fails loudly rather than letting an
// illegal `whereIn: []` query reach the SDK.
class _ExplodingFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Firestore must not be touched when the status set is empty',
  );
}

class _StubFleetRepository implements LicenseOrgFleetRepository {
  _StubFleetRepository(this.result);

  FleetRemoteResult result;
  int calls = 0;
  Set<FleetDeviceStatus>? lastStatuses;
  String? lastOrgId;

  @override
  Future<FleetRemoteResult> fetchFleet(
    String licenseOrgId, {
    Set<FleetDeviceStatus> statuses = const {FleetDeviceStatus.active},
  }) async {
    calls++;
    lastOrgId = licenseOrgId;
    lastStatuses = statuses;
    return result;
  }
}

LicenseOrgFleetDevice _device({
  String transportIdentity = 'mt-81c42d94',
  String label = 'North Gate',
}) {
  return LicenseOrgFleetDevice(
    id: fleetDeviceIdFor(
      licenseOrgId: _org,
      transportIdentity: transportIdentity,
    )!,
    licenseOrgId: _org,
    transport: FleetTransport.meshtastic,
    transportIdentity: transportIdentity,
    label: label,
    assignedUid: null,
    assignment: FleetAssignmentKind.unassigned,
    purpose: null,
    tags: const [],
    notes: null,
    lastKnownHardware: null,
    lastKnownFirmware: null,
    createdBy: 'admin-uid-1',
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 14),
    status: FleetDeviceStatus.active,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LicenseOrgCache cache;
  late _StubFleetRepository repository;
  late DateTime clock;

  setUp(() {
    cache = LicenseOrgCache(testDbPath: inMemoryDatabasePath);
    repository = _StubFleetRepository(const FleetRemoteData([]));
    clock = DateTime.utc(2026, 8, 15, 12);
  });

  tearDown(() async {
    await cache.close();
  });

  ProviderContainer makeContainer({bool enabled = true, User? user}) {
    final container = ProviderContainer(
      overrides: [
        licenseOrgFleetEnabledProvider.overrideWithValue(enabled),
        licenseOrgCacheProvider.overrideWithValue(cache),
        licenseOrgFleetRepositoryProvider.overrideWithValue(repository),
        fleetClockProvider.overrideWithValue(() => clock),
        currentUserProvider.overrideWithValue(user ?? _FakeUser(uid: _uidA)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Collects every snapshot until the stream settles (isRefreshing
  /// false), which is the provider's own definition of "done".
  Future<List<LicenseOrgFleetSnapshot>> drain(
    ProviderContainer container, [
    String orgId = _org,
  ]) async {
    final out = <LicenseOrgFleetSnapshot>[];
    final settled = Completer<void>();
    final sub = container.listen<AsyncValue<LicenseOrgFleetSnapshot>>(
      licenseOrgFleetProvider(orgId),
      (previous, next) {
        next.whenData((snapshot) {
          out.add(snapshot);
          if (!snapshot.isRefreshing && !settled.isCompleted) {
            settled.complete();
          }
        });
      },
      fireImmediately: true,
    );
    await settled.future.timeout(const Duration(seconds: 5));
    sub.close();
    return out;
  }

  group('fail closed', () {
    test('flag off yields empty and never touches the network', () async {
      final container = makeContainer(enabled: false);
      final snapshots = await drain(container);

      expect(snapshots, hasLength(1));
      expect(snapshots.single.devices, isEmpty);
      expect(snapshots.single.syncedAt, isNull);
      expect(
        repository.calls,
        0,
        reason: 'a disabled feature must not issue a billable read',
      );
    });

    test('anonymous user yields empty', () async {
      final container = makeContainer(
        user: _FakeUser(uid: 'anon-uid', isAnonymous: true),
      );
      final snapshots = await drain(container);

      expect(snapshots.single.devices, isEmpty);
      expect(repository.calls, 0);
    });

    test('signed out yields empty', () async {
      final container = ProviderContainer(
        overrides: [
          licenseOrgFleetEnabledProvider.overrideWithValue(true),
          licenseOrgCacheProvider.overrideWithValue(cache),
          licenseOrgFleetRepositoryProvider.overrideWithValue(repository),
          fleetClockProvider.overrideWithValue(() => clock),
          currentUserProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final snapshots = await drain(container);
      expect(snapshots.single.devices, isEmpty);
      expect(repository.calls, 0);
    });

    test('a malformed org id yields empty', () async {
      final container = makeContainer();
      final snapshots = await drain(container, 'Not_A_Slug');

      expect(snapshots.single.devices, isEmpty);
      expect(repository.calls, 0);
    });
  });

  group('cache-first then cloud', () {
    test('cold cache emits empty-refreshing then the cloud result', () async {
      repository.result = FleetRemoteData([_device()]);
      final container = makeContainer();

      final snapshots = await drain(container);

      expect(snapshots, hasLength(2));
      expect(snapshots.first.isRefreshing, isTrue);
      expect(snapshots.first.devices, isEmpty);

      final settled = snapshots.last;
      expect(settled.isRefreshing, isFalse);
      expect(settled.source, FleetSnapshotSource.cloud);
      expect(settled.devices, hasLength(1));
      expect(settled.isStale, isFalse);
      expect(settled.syncedAt, clock);
    });

    test('a successful read is written to the cache', () async {
      repository.result = FleetRemoteData([_device()]);
      final container = makeContainer();
      await drain(container);

      final cached = await cache.readOrgFleet(uid: _uidA, licenseOrgId: _org);
      expect(cached.authorised, isTrue);
      expect(cached.devices, hasLength(1));
      expect(cached.syncedAt, clock);
    });

    test('a warm cache is served first, marked refreshing', () async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _org,
        devices: [_device(label: 'from cache')],
        syncedAt: clock.subtract(const Duration(minutes: 5)),
      );
      repository.result = FleetRemoteData([_device(label: 'from cloud')]);
      final container = makeContainer();

      final snapshots = await drain(container);

      expect(snapshots.first.source, FleetSnapshotSource.cache);
      expect(snapshots.first.devices.single.label, 'from cache');
      expect(snapshots.first.isRefreshing, isTrue);
      expect(snapshots.first.isStale, isFalse);

      expect(snapshots.last.source, FleetSnapshotSource.cloud);
      expect(snapshots.last.devices.single.label, 'from cloud');
      expect(snapshots.last.isRefreshing, isFalse);
    });

    test('the query is scoped to the requested org', () async {
      final container = makeContainer();
      await drain(container);
      expect(repository.lastOrgId, _org);
      // The union, not just active: the cache replaces every row for the
      // org on write, so fetching one status would evict the other.
      expect(repository.lastStatuses, kFleetCachedStatuses);
    });

    test('the repository returns nothing for an empty status set', () async {
      // Cache and cloud must agree: "status in the empty set" matches
      // nothing on both sides. Firestore whereIn cannot execute against
      // an empty list, so the guard also keeps a malformed query from
      // ever leaving the device.
      final real = FirestoreLicenseOrgFleetRepository(
        firestore: _ExplodingFirestore(),
      );
      final result = await real.fetchFleet(
        _org,
        statuses: const <FleetDeviceStatus>{},
      );
      expect(result, isA<FleetRemoteData>());
      expect((result as FleetRemoteData).devices, isEmpty);
    });
  });

  group('transient unavailability', () {
    test('retains cached rows rather than blanking them', () async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _org,
        devices: [_device(label: 'still mine')],
        syncedAt: clock.subtract(const Duration(minutes: 5)),
      );
      repository.result = const FleetRemoteUnavailable('unavailable');
      final container = makeContainer();

      final snapshots = await drain(container);
      final settled = snapshots.last;

      expect(
        settled.devices,
        hasLength(1),
        reason: 'a network failure must never erase authorised cached data',
      );
      expect(settled.devices.single.label, 'still mine');
      expect(settled.source, FleetSnapshotSource.cache);
      expect(settled.isRefreshing, isFalse);
    });

    test('keeps the cache intact for the next read', () async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _org,
        devices: [_device()],
        syncedAt: clock,
      );
      repository.result = const FleetRemoteUnavailable('deadline-exceeded');
      final container = makeContainer();
      await drain(container);

      final cached = await cache.readOrgFleet(uid: _uidA, licenseOrgId: _org);
      expect(cached.authorised, isTrue);
      expect(cached.devices, hasLength(1));
    });

    test(
      'an unavailable read with no cache yields empty, not an error',
      () async {
        repository.result = const FleetRemoteUnavailable('internal');
        final container = makeContainer();

        final snapshots = await drain(container);
        expect(snapshots.last.devices, isEmpty);
        expect(snapshots.last.isRefreshing, isFalse);
      },
    );

    test('stale cached rows are still served, flagged stale', () async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _org,
        devices: [_device()],
        syncedAt: clock.subtract(const Duration(hours: 3)),
      );
      repository.result = const FleetRemoteUnavailable('unavailable');
      final container = makeContainer();

      final settled = (await drain(container)).last;
      expect(settled.devices, hasLength(1));
      expect(
        settled.isStale,
        isTrue,
        reason: 'staleness governs the badge, never visibility',
      );
    });
  });

  group('authoritative denial', () {
    test('yields empty and purges the offline copy', () async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _org,
        devices: [_device()],
        syncedAt: clock,
      );
      repository.result = const FleetAccessDenied();
      final container = makeContainer();

      final settled = (await drain(container)).last;
      expect(settled.devices, isEmpty);
      expect(settled.syncedAt, isNull);

      final cached = await cache.readOrgFleet(uid: _uidA, licenseOrgId: _org);
      expect(
        cached.authorised,
        isFalse,
        reason: 'the offline copy must not outlive an explicit denial',
      );
      expect(cached.devices, isEmpty);
    });
  });

  group('account isolation', () {
    test("account B never sees account A's cached fleet", () async {
      await cache.replaceOrgFleet(
        uid: _uidA,
        licenseOrgId: _org,
        devices: [_device(label: 'A private')],
        syncedAt: clock,
      );

      // B is offline: if the cache were not uid-scoped, B would be
      // served A's rows here.
      repository.result = const FleetRemoteUnavailable('unavailable');
      final container = makeContainer(user: _FakeUser(uid: _uidB));

      final settled = (await drain(container)).last;
      expect(settled.devices, isEmpty);
      expect(settled.syncedAt, isNull);
    });
  });

  group('isFleetSnapshotStale', () {
    final now = DateTime.utc(2026, 8, 15, 12);

    test('never synced is stale', () {
      expect(isFleetSnapshotStale(syncedAt: null, now: now), isTrue);
    });

    test('inside the TTL is fresh', () {
      expect(
        isFleetSnapshotStale(
          syncedAt: now.subtract(const Duration(minutes: 59)),
          now: now,
        ),
        isFalse,
      );
    });

    test('exactly at the TTL boundary is still fresh', () {
      expect(
        isFleetSnapshotStale(
          syncedAt: now.subtract(kLicenseOrgFleetCacheTtl),
          now: now,
        ),
        isFalse,
      );
    });

    test('one millisecond past the TTL is stale', () {
      expect(
        isFleetSnapshotStale(
          syncedAt: now.subtract(
            kLicenseOrgFleetCacheTtl + const Duration(milliseconds: 1),
          ),
          now: now,
        ),
        isTrue,
      );
    });

    test('a future timestamp is treated as fresh, not stale', () {
      // Clock skew must not present valid data as stale.
      expect(
        isFleetSnapshotStale(
          syncedAt: now.add(const Duration(minutes: 5)),
          now: now,
        ),
        isFalse,
      );
    });
  });
}
