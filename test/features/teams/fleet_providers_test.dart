// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Fleet views + mutation controller.
//
// Two properties are load-bearing:
//
//   1. active and retired are DERIVATIONS of one snapshot, so they can
//      never disagree about a device the way two independent queries
//      could.
//   2. a mutation invalidates the fleet ONLY on success. Re-fetching
//      after a refusal spends a query to redraw an identical list, and
//      after a transient failure it would swap a good snapshot for
//      whatever the retry happens to return.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/teams/application/fleet_providers.dart';
import 'package:socialmesh/models/license_org_fleet_device.dart';
import 'package:socialmesh/models/license_org_membership.dart';
import 'package:socialmesh/providers/connectivity_providers.dart';
import 'package:socialmesh/providers/license_org_fleet_providers.dart';
import 'package:socialmesh/providers/license_org_overview_providers.dart';
import 'package:socialmesh/services/license_org/license_org_fleet_service.dart';

const _org = 'acme-team';

LicenseOrgFleetDevice _device({
  required String identity,
  FleetDeviceStatus status = FleetDeviceStatus.active,
  String label = 'Radio',
}) {
  return LicenseOrgFleetDevice(
    id: fleetDeviceIdFor(licenseOrgId: _org, transportIdentity: identity)!,
    licenseOrgId: _org,
    transport: FleetTransport.meshtastic,
    transportIdentity: identity,
    label: label,
    assignedUid: null,
    assignment: FleetAssignmentKind.unassigned,
    purpose: null,
    tags: const [],
    notes: null,
    lastKnownHardware: null,
    lastKnownFirmware: null,
    createdBy: 'admin-1',
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 14),
    status: status,
  );
}

LicenseOrgFleetSnapshot _snapshot(
  List<LicenseOrgFleetDevice> devices, {
  bool loadFailed = false,
}) {
  return LicenseOrgFleetSnapshot(
    devices: devices,
    source: FleetSnapshotSource.cloud,
    syncedAt: DateTime.utc(2026, 8, 15),
    isStale: false,
    isRefreshing: false,
    loadFailed: loadFailed,
  );
}

class _StubService implements LicenseOrgFleetService {
  FleetMutationResult result;
  int calls = 0;

  _StubService(this.result);

  @override
  Future<FleetMutationResult> enroll({
    required String licenseOrgId,
    required FleetTransport transport,
    required String rawIdentity,
    String? label,
    String? purpose,
    List<String>? tags,
    String? notes,
    String? lastKnownHardware,
    String? lastKnownFirmware,
  }) async {
    calls++;
    return result;
  }

  @override
  Future<FleetMutationResult> update({
    required String licenseOrgId,
    required FleetTransport transport,
    required String rawIdentity,
    String? label,
    String? purpose,
    List<String>? tags,
    String? notes,
  }) async {
    calls++;
    return result;
  }

  @override
  Future<FleetMutationResult> assign({
    required String licenseOrgId,
    required FleetTransport transport,
    required String rawIdentity,
    required FleetAssignmentKind assignment,
    String? assignedUid,
  }) async {
    calls++;
    return result;
  }

  @override
  Future<FleetMutationResult> retire({
    required String licenseOrgId,
    required FleetTransport transport,
    required String rawIdentity,
  }) async {
    calls++;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  _loadFailedIsNotEmpty();

  group('active and retired are derivations of one snapshot', () {
    ProviderContainer withDevices(List<LicenseOrgFleetDevice> devices) {
      final container = ProviderContainer(
        overrides: [
          licenseOrgFleetProvider(
            _org,
          ).overrideWith((ref) => Stream.value(_snapshot(devices))),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> settle(ProviderContainer c) async {
      final sub = c.listen(licenseOrgFleetProvider(_org), (_, _) {});
      addTearDown(sub.close);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('splits by status without re-querying', () async {
      final c = withDevices([
        _device(identity: 'mt-00000001', label: 'live-a'),
        _device(
          identity: 'mt-00000002',
          label: 'gone',
          status: FleetDeviceStatus.retired,
        ),
        _device(identity: 'mt-00000003', label: 'live-b'),
      ]);
      await settle(c);

      expect(c.read(activeFleetProvider(_org)).map((d) => d.label), [
        'live-a',
        'live-b',
      ]);
      expect(c.read(retiredFleetProvider(_org)).map((d) => d.label), ['gone']);
    });

    test('a device is never in both views', () async {
      final c = withDevices([
        _device(identity: 'mt-00000001'),
        _device(identity: 'mt-00000002', status: FleetDeviceStatus.retired),
      ]);
      await settle(c);

      final activeIds = c.read(activeFleetProvider(_org)).map((d) => d.id);
      final retiredIds = c.read(retiredFleetProvider(_org)).map((d) => d.id);
      expect(activeIds.toSet().intersection(retiredIds.toSet()), isEmpty);
    });

    test('an unknown status appears in neither view', () async {
      // Fail closed: a status this build does not understand must not be
      // silently presented as in-service hardware.
      final c = withDevices([
        _device(identity: 'mt-00000009', status: FleetDeviceStatus.unknown),
      ]);
      await settle(c);

      expect(c.read(activeFleetProvider(_org)), isEmpty);
      expect(c.read(retiredFleetProvider(_org)), isEmpty);
    });

    test('lookup by id reads the same snapshot as the lists', () async {
      final wanted = _device(identity: 'mt-0000000a', label: 'wanted');
      final c = withDevices([wanted, _device(identity: 'mt-0000000b')]);
      await settle(c);

      final found = c.read(
        fleetDeviceByIdProvider((licenseOrgId: _org, fleetDeviceId: wanted.id)),
      );
      expect(found?.label, 'wanted');
      expect(
        c.read(
          fleetDeviceByIdProvider((
            licenseOrgId: _org,
            fleetDeviceId: 'no-such-id',
          )),
        ),
        isNull,
      );
    });
  });

  test('the authority fetches the active+retired union', () {
    // A status-filtered fetch would make the active and retired caches
    // wipe each other, because replaceOrgFleet deletes every row for the
    // org before inserting. One union fetch keeps them coherent.
    expect(kFleetCachedStatuses, {
      FleetDeviceStatus.active,
      FleetDeviceStatus.retired,
    });
  });

  group('mutations invalidate only on success', () {
    ProviderContainer withService(FleetMutationResult result) {
      final container = ProviderContainer(
        overrides: [
          licenseOrgFleetServiceProvider.overrideWithValue(
            _StubService(result),
          ),
          licenseOrgFleetProvider(
            _org,
          ).overrideWith((ref) => Stream.value(_snapshot(const []))),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('a successful mutation reports success', () async {
      final c = withService(
        const FleetMutationSuccess(fleetDeviceId: 'x', created: true),
      );
      final result = await c
          .read(fleetMutationControllerProvider(_org).notifier)
          .retire(
            transport: FleetTransport.meshtastic,
            rawIdentity: '81c42d94',
          );

      expect(result, isA<FleetMutationSuccess>());
      expect(c.read(fleetMutationControllerProvider(_org)).hasError, isFalse);
    });

    test('a refusal surfaces the typed failure as the error', () async {
      const failure = FleetMutationFailure(
        reason: FleetMutationReason.deviceRetired,
        message: 'device is retired',
      );
      final c = withService(failure);

      final result = await c
          .read(fleetMutationControllerProvider(_org).notifier)
          .enroll(
            transport: FleetTransport.meshtastic,
            rawIdentity: '81c42d94',
          );

      expect(result, isA<FleetMutationFailure>());
      final state = c.read(fleetMutationControllerProvider(_org));
      expect(state.hasError, isTrue);
      // The UI switches on the reason to pick copy, so the error must be
      // the typed result rather than a stringified message.
      expect(state.error, isA<FleetMutationFailure>());
      expect(
        (state.error as FleetMutationFailure).reason,
        FleetMutationReason.deviceRetired,
      );
    });

    test('every refusal reason is preserved end to end', () async {
      for (final reason in FleetMutationReason.values) {
        final c = withService(
          FleetMutationFailure(reason: reason, message: 'x'),
        );
        final result =
            await c
                    .read(fleetMutationControllerProvider(_org).notifier)
                    .assign(
                      transport: FleetTransport.meshtastic,
                      rawIdentity: '81c42d94',
                      assignment: FleetAssignmentKind.unassigned,
                    )
                as FleetMutationFailure;
        expect(result.reason, reason);
      }
    });

    test('a failure leaves the controller recoverable', () async {
      // After a refusal the admin must be able to correct the input and
      // try again without rebuilding the screen.
      final service = _StubService(
        const FleetMutationFailure(
          reason: FleetMutationReason.unavailable,
          message: 'offline',
        ),
      );
      final c = ProviderContainer(
        overrides: [
          licenseOrgFleetServiceProvider.overrideWithValue(service),
          licenseOrgFleetProvider(
            _org,
          ).overrideWith((ref) => Stream.value(_snapshot(const []))),
        ],
      );
      addTearDown(c.dispose);

      final notifier = c.read(fleetMutationControllerProvider(_org).notifier);
      await notifier.retire(
        transport: FleetTransport.meshtastic,
        rawIdentity: '81c42d94',
      );
      expect(c.read(fleetMutationControllerProvider(_org)).hasError, isTrue);

      service.result = const FleetMutationSuccess(fleetDeviceId: 'x');
      await notifier.retire(
        transport: FleetTransport.meshtastic,
        rawIdentity: '81c42d94',
      );
      expect(c.read(fleetMutationControllerProvider(_org)).hasError, isFalse);
      expect(service.calls, 2);
    });
  });

  group('write capability is separate from read visibility', () {
    ProviderContainer withRole(
      LicenseOrgMemberRole role, {
      bool online = true,
    }) {
      final container = ProviderContainer(
        overrides: [
          licenseOrgRoleProvider(_org).overrideWithValue(role),
          isOnlineProvider.overrideWithValue(online),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('an online owner or admin may write', () {
      for (final role in [
        LicenseOrgMemberRole.owner,
        LicenseOrgMemberRole.admin,
      ]) {
        expect(
          withRole(role).read(fleetWriteBlockProvider(_org)),
          FleetWriteBlock.none,
        );
      }
    });

    test('offline blocks writes even for an owner', () {
      // Fleet mutations are online-only. Offering the action and failing
      // on tap would be worse than saying so up front.
      expect(
        withRole(
          LicenseOrgMemberRole.owner,
          online: false,
        ).read(fleetWriteBlockProvider(_org)),
        FleetWriteBlock.offline,
      );
    });

    test('a plain member is blocked by role, online or not', () {
      for (final online in [true, false]) {
        expect(
          withRole(
            LicenseOrgMemberRole.member,
            online: online,
          ).read(fleetWriteBlockProvider(_org)),
          FleetWriteBlock.notAdmin,
          reason: 'role outranks connectivity - it is the durable reason',
        );
      }
    });

    test('an unknown role is blocked', () {
      expect(
        withRole(
          LicenseOrgMemberRole.unknown,
        ).read(fleetWriteBlockProvider(_org)),
        FleetWriteBlock.notAdmin,
      );
    });

    test('write capability says nothing about reading', () async {
      // The point of the split: a blocked writer still gets whatever the
      // fleet snapshot holds, including stale cached rows.
      final c = ProviderContainer(
        overrides: [
          licenseOrgRoleProvider(
            _org,
          ).overrideWithValue(LicenseOrgMemberRole.member),
          isOnlineProvider.overrideWithValue(false),
          licenseOrgFleetProvider(_org).overrideWith(
            (ref) => Stream.value(
              LicenseOrgFleetSnapshot(
                devices: [_device(identity: 'mt-00000001', label: 'visible')],
                source: FleetSnapshotSource.cache,
                syncedAt: DateTime.utc(2026, 8, 15, 10),
                isStale: true,
                isRefreshing: false,
              ),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(licenseOrgFleetProvider(_org), (_, _) {});
      addTearDown(sub.close);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(c.read(fleetWriteBlockProvider(_org)), FleetWriteBlock.notAdmin);
      expect(c.read(activeFleetProvider(_org)).map((d) => d.label), [
        'visible',
      ]);
    });
  });
}

// A failed authoritative read is not an empty fleet. Without this
// distinction the Fleet screen states "no radios yet" about an org whose
// radios it merely failed to fetch - which a missing composite index
// causes permanently, not transiently.
void _loadFailedIsNotEmpty() {
  group('a failed read is distinguishable from an empty fleet', () {
    test('resolved-empty does not report a failed load', () {
      expect(_snapshot(const []).loadFailed, isFalse);
    });

    test('a failed load carries the flag even with no devices', () {
      final s = _snapshot(const [], loadFailed: true);
      expect(s.devices, isEmpty);
      expect(s.loadFailed, isTrue);
    });

    test('copyWith preserves the flag', () {
      final s = _snapshot(
        const [],
        loadFailed: true,
      ).copyWith(isRefreshing: true);
      expect(s.loadFailed, isTrue);
      expect(s.isRefreshing, isTrue);
    });

    test('the shared empty sentinel is a resolved answer, not a failure', () {
      expect(LicenseOrgFleetSnapshot.empty.loadFailed, isFalse);
    });
  });
}
