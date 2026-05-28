// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Unit tests for [LicenseOrgSeatService]. Uses a fake invoker so the
// tests do not need the Firebase Functions emulator. Pins the
// success / replay / error mapping so the screen branches stay
// stable across future backend tweaks.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/license_org/license_org_invite_service.dart'
    show InviteCallableInvoker;
import 'package:socialmesh/services/license_org/license_org_seat_service.dart';

class _FakeInvoker implements InviteCallableInvoker {
  _FakeInvoker(this._impl);
  final Future<Map<String, dynamic>> Function(
    String name,
    Map<String, dynamic> data,
  )
  _impl;

  String? lastName;
  Map<String, dynamic>? lastData;

  @override
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data) {
    lastName = name;
    lastData = data;
    return _impl(name, data);
  }
}

void main() {
  group('seatAllocationDocId', () {
    test('formats as orgId__uid__productId', () {
      expect(
        seatAllocationDocId(
          licenseOrgId: 'acme',
          uid: 'u1',
          productId: 'complete_pack',
        ),
        equals('acme__u1__complete_pack'),
      );
    });

    test('communityPackSeatProductId pins the canonical product', () {
      // Backend keys every Community Pack 10/20 seat by complete_pack.
      // Drift would break revoke (allocationId lookup would 404) so
      // pin the constant explicitly. Update both sides when this
      // changes.
      expect(communityPackSeatProductId, equals('complete_pack'));
    });
  });

  group('LicenseOrgSeatService.revokeSeat', () {
    test(
      'returns success with alreadyRevoked: false on a fresh revoke',
      () async {
        final invoker = _FakeInvoker(
          (_, _) async => {
            'allocationId': 'acme__u1__complete_pack',
            'status': 'revoked',
            'alreadyRevoked': false,
          },
        );
        final svc = LicenseOrgSeatService(invoker: invoker);
        final result = await svc.revokeSeat(
          licenseOrgId: 'acme',
          allocationId: 'acme__u1__complete_pack',
        );
        expect(result, isA<RevokeSeatSuccess>());
        final success = result as RevokeSeatSuccess;
        expect(success.allocationId, equals('acme__u1__complete_pack'));
        expect(success.alreadyRevoked, isFalse);
        expect(invoker.lastName, equals('revokeLicenseSeat'));
        expect(invoker.lastData!['licenseOrgId'], equals('acme'));
        expect(
          invoker.lastData!['allocationId'],
          equals('acme__u1__complete_pack'),
        );
      },
    );

    test(
      'returns success with alreadyRevoked: true on an idempotent replay',
      () async {
        final invoker = _FakeInvoker(
          (_, _) async => {
            'allocationId': 'acme__u1__complete_pack',
            'status': 'revoked',
            'alreadyRevoked': true,
          },
        );
        final svc = LicenseOrgSeatService(invoker: invoker);
        final result = await svc.revokeSeat(
          licenseOrgId: 'acme',
          allocationId: 'acme__u1__complete_pack',
        );
        expect(result, isA<RevokeSeatSuccess>());
        expect((result as RevokeSeatSuccess).alreadyRevoked, isTrue);
      },
    );

    test('includes reason in payload only when non-empty', () async {
      final invoker = _FakeInvoker(
        (_, _) async => {
          'allocationId': 'acme__u1__complete_pack',
          'status': 'revoked',
          'alreadyRevoked': false,
        },
      );
      final svc = LicenseOrgSeatService(invoker: invoker);
      await svc.revokeSeat(
        licenseOrgId: 'acme',
        allocationId: 'acme__u1__complete_pack',
        reason: '   ',
      );
      expect(
        invoker.lastData!.containsKey('reason'),
        isFalse,
        reason: 'whitespace-only reason must be dropped before transit',
      );
      await svc.revokeSeat(
        licenseOrgId: 'acme',
        allocationId: 'acme__u1__complete_pack',
        reason: 'spam account',
      );
      expect(invoker.lastData!['reason'], equals('spam account'));
    });

    test(
      'maps permission-denied to RevokeSeatReason.permissionDenied',
      () async {
        final invoker = _FakeInvoker(
          (_, _) async => throw FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'caller is not owner or admin',
          ),
        );
        final svc = LicenseOrgSeatService(invoker: invoker);
        final result = await svc.revokeSeat(
          licenseOrgId: 'acme',
          allocationId: 'acme__u1__complete_pack',
        );
        expect(result, isA<RevokeSeatFailure>());
        expect(
          (result as RevokeSeatFailure).reason,
          equals(RevokeSeatReason.permissionDenied),
        );
      },
    );

    test('maps resource-exhausted to RevokeSeatReason.rateLimited', () async {
      final invoker = _FakeInvoker(
        (_, _) async => throw FirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'too_many_revokes',
        ),
      );
      final svc = LicenseOrgSeatService(invoker: invoker);
      final result = await svc.revokeSeat(
        licenseOrgId: 'acme',
        allocationId: 'acme__u1__complete_pack',
      );
      expect(
        (result as RevokeSeatFailure).reason,
        equals(RevokeSeatReason.rateLimited),
      );
    });

    test('falls back to generic for unknown error codes', () async {
      final invoker = _FakeInvoker(
        (_, _) async => throw FirebaseFunctionsException(
          code: 'unavailable',
          message: 'transient',
        ),
      );
      final svc = LicenseOrgSeatService(invoker: invoker);
      final result = await svc.revokeSeat(
        licenseOrgId: 'acme',
        allocationId: 'acme__u1__complete_pack',
      );
      expect(
        (result as RevokeSeatFailure).reason,
        equals(RevokeSeatReason.generic),
      );
    });

    test('non-Firebase throw maps to generic without rethrowing', () async {
      final invoker = _FakeInvoker((_, _) async => throw StateError('boom'));
      final svc = LicenseOrgSeatService(invoker: invoker);
      final result = await svc.revokeSeat(
        licenseOrgId: 'acme',
        allocationId: 'acme__u1__complete_pack',
      );
      expect(
        (result as RevokeSeatFailure).reason,
        equals(RevokeSeatReason.generic),
      );
    });
  });

  group('LicenseOrgSeatService.reinstateSeat', () {
    test(
      'returns success with alreadyActive: false on a fresh reinstate',
      () async {
        final invoker = _FakeInvoker(
          (_, _) async => {
            'allocationId': 'acme__u1__complete_pack',
            'status': 'active',
            'alreadyActive': false,
          },
        );
        final svc = LicenseOrgSeatService(invoker: invoker);
        final result = await svc.reinstateSeat(
          licenseOrgId: 'acme',
          allocationId: 'acme__u1__complete_pack',
        );
        expect(result, isA<ReinstateSeatSuccess>());
        final success = result as ReinstateSeatSuccess;
        expect(success.allocationId, equals('acme__u1__complete_pack'));
        expect(success.alreadyActive, isFalse);
        expect(invoker.lastName, equals('reinstateLicenseSeat'));
        expect(invoker.lastData!['licenseOrgId'], equals('acme'));
      },
    );

    test(
      'returns success with alreadyActive: true on idempotent replay',
      () async {
        final invoker = _FakeInvoker(
          (_, _) async => {
            'allocationId': 'acme__u1__complete_pack',
            'status': 'active',
            'alreadyActive': true,
          },
        );
        final svc = LicenseOrgSeatService(invoker: invoker);
        final result = await svc.reinstateSeat(
          licenseOrgId: 'acme',
          allocationId: 'acme__u1__complete_pack',
        );
        expect((result as ReinstateSeatSuccess).alreadyActive, isTrue);
      },
    );

    test('permission-denied -> permissionDenied', () async {
      final invoker = _FakeInvoker(
        (_, _) async => throw FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'caller is not owner or admin',
        ),
      );
      final svc = LicenseOrgSeatService(invoker: invoker);
      final result = await svc.reinstateSeat(
        licenseOrgId: 'acme',
        allocationId: 'acme__u1__complete_pack',
      );
      expect(
        (result as ReinstateSeatFailure).reason,
        equals(ReinstateSeatReason.permissionDenied),
      );
    });

    test('failed-precondition with "seat capacity" -> overCapacity', () async {
      // Backend uses failed-precondition for both org-suspended and
      // over-capacity. Discriminate by the message substring.
      final invoker = _FakeInvoker(
        (_, _) async => throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'cannot reinstate: org is at seat capacity (10)',
        ),
      );
      final svc = LicenseOrgSeatService(invoker: invoker);
      final result = await svc.reinstateSeat(
        licenseOrgId: 'acme',
        allocationId: 'acme__u1__complete_pack',
      );
      expect(
        (result as ReinstateSeatFailure).reason,
        equals(ReinstateSeatReason.overCapacity),
      );
    });

    test(
      'failed-precondition without seat-capacity hint -> orgSuspended',
      () async {
        final invoker = _FakeInvoker(
          (_, _) async => throw FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'License org is not active',
          ),
        );
        final svc = LicenseOrgSeatService(invoker: invoker);
        final result = await svc.reinstateSeat(
          licenseOrgId: 'acme',
          allocationId: 'acme__u1__complete_pack',
        );
        expect(
          (result as ReinstateSeatFailure).reason,
          equals(ReinstateSeatReason.orgSuspended),
        );
      },
    );

    test('resource-exhausted -> rateLimited', () async {
      final invoker = _FakeInvoker(
        (_, _) async => throw FirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'too_many_reinstates',
        ),
      );
      final svc = LicenseOrgSeatService(invoker: invoker);
      final result = await svc.reinstateSeat(
        licenseOrgId: 'acme',
        allocationId: 'acme__u1__complete_pack',
      );
      expect(
        (result as ReinstateSeatFailure).reason,
        equals(ReinstateSeatReason.rateLimited),
      );
    });

    test('unknown code -> generic', () async {
      final invoker = _FakeInvoker(
        (_, _) async => throw FirebaseFunctionsException(
          code: 'unavailable',
          message: 'transient',
        ),
      );
      final svc = LicenseOrgSeatService(invoker: invoker);
      final result = await svc.reinstateSeat(
        licenseOrgId: 'acme',
        allocationId: 'acme__u1__complete_pack',
      );
      expect(
        (result as ReinstateSeatFailure).reason,
        equals(ReinstateSeatReason.generic),
      );
    });
  });
}
