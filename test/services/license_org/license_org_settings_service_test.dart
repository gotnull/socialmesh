// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Unit tests for [LicenseOrgSettingsService]. Uses a fake invoker so
// the tests do not need the Firebase Functions emulator. Pins the
// success / no-change / validation / error mapping so the screen
// branches stay stable across future backend tweaks.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/license_org/license_org_invite_service.dart'
    show InviteCallableInvoker;
import 'package:socialmesh/services/license_org/license_org_settings_service.dart';

class _FakeInvoker implements InviteCallableInvoker {
  _FakeInvoker(this._impl);
  final Future<Map<String, dynamic>> Function(
    String name,
    Map<String, dynamic> data,
  )
  _impl;

  String? lastName;
  Map<String, dynamic>? lastData;
  int callCount = 0;

  @override
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data) {
    callCount += 1;
    lastName = name;
    lastData = data;
    return _impl(name, data);
  }
}

void main() {
  group('LicenseOrgSettingsService.updateName — validation', () {
    test('rejects empty name without hitting the network', () async {
      final invoker = _FakeInvoker(
        (_, _) async => throw StateError('should not be called'),
      );
      final svc = LicenseOrgSettingsService(invoker: invoker);
      final result = await svc.updateName(licenseOrgId: 'acme', name: '   ');
      expect(result, isA<UpdateLicenseOrgNameFailure>());
      expect(
        (result as UpdateLicenseOrgNameFailure).reason,
        equals(UpdateLicenseOrgNameReason.invalidArgument),
      );
      expect(invoker.callCount, equals(0));
    });

    test('rejects name over the cap without hitting the network', () async {
      final invoker = _FakeInvoker(
        (_, _) async => throw StateError('should not be called'),
      );
      final svc = LicenseOrgSettingsService(invoker: invoker);
      final tooLong = 'x' * (licenseOrgNameMaxLength + 1);
      final result = await svc.updateName(licenseOrgId: 'acme', name: tooLong);
      expect(
        (result as UpdateLicenseOrgNameFailure).reason,
        equals(UpdateLicenseOrgNameReason.invalidArgument),
      );
      expect(invoker.callCount, equals(0));
    });

    test('accepts exactly $licenseOrgNameMaxLength chars', () async {
      final invoker = _FakeInvoker(
        (_, _) async => {
          'licenseOrgId': 'acme',
          'name': 'x' * licenseOrgNameMaxLength,
          'previousName': '',
        },
      );
      final svc = LicenseOrgSettingsService(invoker: invoker);
      final result = await svc.updateName(
        licenseOrgId: 'acme',
        name: 'x' * licenseOrgNameMaxLength,
      );
      expect(result, isA<UpdateLicenseOrgNameSuccess>());
    });

    test('trims whitespace before submitting', () async {
      final invoker = _FakeInvoker(
        (_, _) async => {
          'licenseOrgId': 'acme',
          'name': 'Acme Eng',
          'previousName': '',
        },
      );
      final svc = LicenseOrgSettingsService(invoker: invoker);
      await svc.updateName(licenseOrgId: 'acme', name: '  Acme Eng  ');
      expect(invoker.lastData!['name'], equals('Acme Eng'));
    });
  });

  group('LicenseOrgSettingsService.updateName — success branches', () {
    test('reports noChange=false when stored name differs', () async {
      final invoker = _FakeInvoker(
        (_, _) async => {
          'licenseOrgId': 'acme',
          'name': 'Acme Eng',
          'previousName': '',
        },
      );
      final svc = LicenseOrgSettingsService(invoker: invoker);
      final result = await svc.updateName(
        licenseOrgId: 'acme',
        name: 'Acme Eng',
      );
      final success = result as UpdateLicenseOrgNameSuccess;
      expect(success.noChange, isFalse);
      expect(success.name, equals('Acme Eng'));
      expect(success.previousName, equals(''));
    });

    test('reports noChange=true on idempotent replay', () async {
      final invoker = _FakeInvoker(
        (_, _) async => {
          'licenseOrgId': 'acme',
          'name': 'Acme Eng',
          'previousName': 'Acme Eng',
        },
      );
      final svc = LicenseOrgSettingsService(invoker: invoker);
      final result = await svc.updateName(
        licenseOrgId: 'acme',
        name: 'Acme Eng',
      );
      expect((result as UpdateLicenseOrgNameSuccess).noChange, isTrue);
    });
  });

  group('LicenseOrgSettingsService.updateName — error mapping', () {
    test(
      'permission-denied -> permissionDenied (admins are rejected)',
      () async {
        final invoker = _FakeInvoker(
          (_, _) async => throw FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'caller is not the owner',
          ),
        );
        final svc = LicenseOrgSettingsService(invoker: invoker);
        final result = await svc.updateName(
          licenseOrgId: 'acme',
          name: 'Acme Eng',
        );
        expect(
          (result as UpdateLicenseOrgNameFailure).reason,
          equals(UpdateLicenseOrgNameReason.permissionDenied),
        );
      },
    );

    test('not-found -> notFound (org doc gone)', () async {
      final invoker = _FakeInvoker(
        (_, _) async => throw FirebaseFunctionsException(
          code: 'not-found',
          message: 'license org not found',
        ),
      );
      final svc = LicenseOrgSettingsService(invoker: invoker);
      final result = await svc.updateName(
        licenseOrgId: 'gone',
        name: 'Acme Eng',
      );
      expect(
        (result as UpdateLicenseOrgNameFailure).reason,
        equals(UpdateLicenseOrgNameReason.notFound),
      );
    });

    test('invalid-argument server side -> invalidArgument', () async {
      final invoker = _FakeInvoker(
        (_, _) async => throw FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'name cannot be empty after trim',
        ),
      );
      final svc = LicenseOrgSettingsService(invoker: invoker);
      // Pass a non-empty name so the client-side preflight passes
      // and the server-side validation gets to fire.
      final result = await svc.updateName(
        licenseOrgId: 'acme',
        name: 'Acme Eng',
      );
      expect(
        (result as UpdateLicenseOrgNameFailure).reason,
        equals(UpdateLicenseOrgNameReason.invalidArgument),
      );
    });

    test('unknown code -> generic', () async {
      final invoker = _FakeInvoker(
        (_, _) async => throw FirebaseFunctionsException(
          code: 'unavailable',
          message: 'transient',
        ),
      );
      final svc = LicenseOrgSettingsService(invoker: invoker);
      final result = await svc.updateName(
        licenseOrgId: 'acme',
        name: 'Acme Eng',
      );
      expect(
        (result as UpdateLicenseOrgNameFailure).reason,
        equals(UpdateLicenseOrgNameReason.generic),
      );
    });

    test('non-Firebase throw maps to generic without rethrowing', () async {
      final invoker = _FakeInvoker((_, _) async => throw StateError('boom'));
      final svc = LicenseOrgSettingsService(invoker: invoker);
      final result = await svc.updateName(
        licenseOrgId: 'acme',
        name: 'Acme Eng',
      );
      expect(
        (result as UpdateLicenseOrgNameFailure).reason,
        equals(UpdateLicenseOrgNameReason.generic),
      );
    });
  });

  test('licenseOrgNameMaxLength pins the backend NAME_MAX_LEN', () {
    // Backend lives in license_org_settings.ts. Both sides must agree
    // or the client preflight accepts a string the server rejects
    // (or vice versa). Update both in lockstep.
    expect(licenseOrgNameMaxLength, equals(50));
  });
}
