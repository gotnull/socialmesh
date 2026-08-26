// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Fleet callable wrapper: payload shape and error classification.
//
// The classification tests matter more than they look. Each reason maps
// to different user-facing copy, and collapsing them would leave an
// admin re-tapping Enrol forever on a retired device because the app
// only said "something went wrong".

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/license_org_fleet_device.dart';
import 'package:socialmesh/services/license_org/license_org_fleet_service.dart';

class _RecordingInvoker implements FleetCallableInvoker {
  final Map<String, dynamic> response;
  final Object? throwThis;

  String? lastName;
  Map<String, dynamic>? lastData;

  _RecordingInvoker({this.response = const {}, this.throwThis});

  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    lastName = name;
    lastData = data;
    final err = throwThis;
    if (err != null) throw err;
    return response;
  }
}

FirebaseFunctionsException _fnError(String code, {String message = ''}) =>
    FirebaseFunctionsException(code: code, message: message);

void main() {
  group('payload shape', () {
    test('enroll sends the canonical transport wire value', () async {
      final invoker = _RecordingInvoker(
        response: {'fleetDeviceId': 'acme__mt-81c42d94', 'created': true},
      );
      final service = LicenseOrgFleetService(invoker: invoker);

      final result = await service.enroll(
        licenseOrgId: 'acme',
        transport: FleetTransport.meshtastic,
        rawIdentity: '81c42d94',
        label: 'North Gate',
      );

      expect(invoker.lastName, 'enrollFleetDevice');
      expect(invoker.lastData!['transport'], 'meshtastic');
      expect(invoker.lastData!['rawIdentity'], '81c42d94');
      expect(invoker.lastData!['label'], 'North Gate');
      expect(result, isA<FleetMutationSuccess>());
      expect((result as FleetMutationSuccess).created, isTrue);
    });

    test('meshcore uses its own wire value', () async {
      final invoker = _RecordingInvoker(response: {'fleetDeviceId': 'x'});
      await LicenseOrgFleetService(invoker: invoker).enroll(
        licenseOrgId: 'acme',
        transport: FleetTransport.meshCore,
        rawIdentity: 'ab' * 32,
      );
      expect(invoker.lastData!['transport'], 'meshcore');
    });

    test('omitted optional metadata is absent, not null', () async {
      // Sending explicit nulls would trip the server's strict schema.
      final invoker = _RecordingInvoker(response: {'fleetDeviceId': 'x'});
      await LicenseOrgFleetService(invoker: invoker).enroll(
        licenseOrgId: 'acme',
        transport: FleetTransport.meshtastic,
        rawIdentity: '81c42d94',
      );
      expect(invoker.lastData!.containsKey('label'), isFalse);
      expect(invoker.lastData!.containsKey('notes'), isFalse);
      expect(invoker.lastData!.containsKey('tags'), isFalse);
    });

    test('update never sends identity, custody or status keys', () async {
      // Those are immutable server-side and rejected as unknown keys;
      // the client must not even try.
      final invoker = _RecordingInvoker(response: {'fleetDeviceId': 'x'});
      await LicenseOrgFleetService(invoker: invoker).update(
        licenseOrgId: 'acme',
        transport: FleetTransport.meshtastic,
        rawIdentity: '81c42d94',
        label: 'renamed',
      );
      for (final forbidden in [
        'assignment',
        'assignedUid',
        'status',
        'createdBy',
        'createdAt',
        'id',
      ]) {
        expect(invoker.lastData!.containsKey(forbidden), isFalse);
      }
    });

    test('assign to a member carries the uid', () async {
      final invoker = _RecordingInvoker(response: {'fleetDeviceId': 'x'});
      await LicenseOrgFleetService(invoker: invoker).assign(
        licenseOrgId: 'acme',
        transport: FleetTransport.meshtastic,
        rawIdentity: '81c42d94',
        assignment: FleetAssignmentKind.member,
        assignedUid: 'member-1',
      );
      expect(invoker.lastData!['assignment'], 'member');
      expect(invoker.lastData!['assignedUid'], 'member-1');
    });

    test('non-member assignment forces assignedUid to null', () async {
      // The client mirrors the server invariant rather than trusting the
      // caller to clear the uid when switching to org pool.
      for (final kind in [
        FleetAssignmentKind.orgPool,
        FleetAssignmentKind.unassigned,
      ]) {
        final invoker = _RecordingInvoker(response: {'fleetDeviceId': 'x'});
        await LicenseOrgFleetService(invoker: invoker).assign(
          licenseOrgId: 'acme',
          transport: FleetTransport.meshtastic,
          rawIdentity: '81c42d94',
          assignment: kind,
          assignedUid: 'stale-uid',
        );
        expect(invoker.lastData!['assignedUid'], isNull);
        expect(invoker.lastData!['assignment'], kind.toWire());
      }
    });

    test('org_pool uses the snake_case wire value', () async {
      final invoker = _RecordingInvoker(response: {'fleetDeviceId': 'x'});
      await LicenseOrgFleetService(invoker: invoker).assign(
        licenseOrgId: 'acme',
        transport: FleetTransport.meshtastic,
        rawIdentity: '81c42d94',
        assignment: FleetAssignmentKind.orgPool,
      );
      expect(invoker.lastData!['assignment'], 'org_pool');
    });
  });

  group('error classification drives distinct copy', () {
    Future<FleetMutationReason> reasonFor(Object error) async {
      final service = LicenseOrgFleetService(
        invoker: _RecordingInvoker(throwThis: error),
      );
      final result = await service.retire(
        licenseOrgId: 'acme',
        transport: FleetTransport.meshtastic,
        rawIdentity: '81c42d94',
      );
      return (result as FleetMutationFailure).reason;
    }

    test('a retired device is its own reason, not generic', () async {
      // Without this the admin re-taps Enrol forever.
      expect(
        await reasonFor(
          _fnError(
            'failed-precondition',
            message: 'device is retired; reactivation is a separate action',
          ),
        ),
        FleetMutationReason.deviceRetired,
      );
    });

    // Both a role refusal and a missing fleet capability arrive as
    // permission-denied, but only one is fixable by the admin in front
    // of the screen, so they must not share copy. The next two tests
    // pin that split.
    test(
      'permission-denied without a fleet mention is a role refusal',
      () async {
        expect(
          await reasonFor(
            _fnError(
              'permission-denied',
              message:
                  'caller is not an owner or admin of the target license org',
            ),
          ),
          FleetMutationReason.permissionDenied,
        );
      },
    );

    test(
      'permission-denied mentioning fleet access is org ineligibility',
      () async {
        expect(
          await reasonFor(
            _fnError(
              'permission-denied',
              message: 'license org does not have fleet access',
            ),
          ),
          FleetMutationReason.orgNotEligible,
        );
      },
    );

    test('a suspended org is org ineligibility', () async {
      expect(
        await reasonFor(
          _fnError('failed-precondition', message: 'license org is not active'),
        ),
        FleetMutationReason.orgNotEligible,
      );
    });

    test('a non-member assignee is its own reason', () async {
      expect(
        await reasonFor(
          _fnError(
            'failed-precondition',
            message: 'assignee is not an active member of this license org',
          ),
        ),
        FleetMutationReason.assigneeNotActiveMember,
      );
    });

    test('validation failures are invalidInput', () async {
      expect(
        await reasonFor(_fnError('invalid-argument', message: 'bad shape')),
        FleetMutationReason.invalidInput,
      );
    });

    test('unauthenticated and not-found map through', () async {
      expect(
        await reasonFor(_fnError('unauthenticated')),
        FleetMutationReason.unauthenticated,
      );
      expect(
        await reasonFor(_fnError('not-found')),
        FleetMutationReason.notFound,
      );
    });

    test('transport failures are retryable, not fatal', () async {
      for (final code in ['unavailable', 'deadline-exceeded', 'internal']) {
        expect(
          await reasonFor(_fnError(code)),
          FleetMutationReason.unavailable,
          reason: '$code should invite a retry',
        );
      }
    });

    test(
      'a non-Firebase throw degrades to unavailable, never success',
      () async {
        expect(
          await reasonFor(StateError('socket died')),
          FleetMutationReason.unavailable,
        );
      },
    );

    test('an unrecognised code is generic rather than mis-labelled', () async {
      expect(
        await reasonFor(_fnError('some-future-code')),
        FleetMutationReason.generic,
      );
    });
  });
}
