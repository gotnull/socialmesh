// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/services/transport/ble_transport.dart';

void main() {
  group('MeshtasticServiceNotFoundException', () {
    test('creates exception with message', () {
      const message = 'Service not found';
      final exception = MeshtasticServiceNotFoundException(message);

      expect(exception.message, equals(message));
    });

    test('toString includes exception type and message', () {
      const message = 'Meshtastic service UUID not found on device';
      final exception = MeshtasticServiceNotFoundException(message);

      expect(
        exception.toString(),
        equals('MeshtasticServiceNotFoundException: $message'),
      );
    });

    test('can be thrown and caught', () {
      expect(
        () => throw const MeshtasticServiceNotFoundException(
          'Device may be running MeshCore',
        ),
        throwsA(isA<MeshtasticServiceNotFoundException>()),
      );
    });

    test('provides helpful error message for MeshCore devices', () {
      const message =
          'Meshtastic BLE service not found. This device may be '
          'running a different protocol (e.g., MeshCore) or is not a mesh radio.';
      final exception = MeshtasticServiceNotFoundException(message);

      expect(exception.message, contains('MeshCore'));
      expect(exception.message, contains('different protocol'));
    });

    test('is an Exception', () {
      final exception = MeshtasticServiceNotFoundException('test');
      expect(exception, isA<Exception>());
    });
  });

  group('BleTransport.classifyAndroidScanFailure', () {
    FlutterBluePlusException scanException(
      int? code, {
      ErrorPlatform platform = ErrorPlatform.android,
      String function = 'scan',
    }) => FlutterBluePlusException(platform, function, code, 'SCAN_FAILED');

    test(
      'maps SCAN_FAILED_APPLICATION_REGISTRATION_FAILED (2) to stackFailure',
      () {
        final failure = BleTransport.classifyAndroidScanFailure(
          scanException(2),
        );
        expect(failure, isNotNull);
        expect(failure!.kind, BleScanFailureKind.stackFailure);
        expect(failure.platformCode, 2);
      },
    );

    test('maps SCAN_FAILED_INTERNAL_ERROR (3) to stackFailure', () {
      final failure = BleTransport.classifyAndroidScanFailure(scanException(3));
      expect(failure!.kind, BleScanFailureKind.stackFailure);
    });

    test('maps SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES (5) to stackFailure', () {
      final failure = BleTransport.classifyAndroidScanFailure(scanException(5));
      expect(failure!.kind, BleScanFailureKind.stackFailure);
    });

    test('maps SCAN_FAILED_SCANNING_TOO_FREQUENTLY (6) to throttled', () {
      final failure = BleTransport.classifyAndroidScanFailure(scanException(6));
      expect(failure!.kind, BleScanFailureKind.throttled);
      expect(failure.platformCode, 6);
    });

    test('classifies startScan-function exceptions too', () {
      final failure = BleTransport.classifyAndroidScanFailure(
        scanException(2, function: 'startScan'),
      );
      expect(failure, isNotNull);
    });

    test('ignores unrelated android scan codes', () {
      expect(BleTransport.classifyAndroidScanFailure(scanException(1)), isNull);
      expect(BleTransport.classifyAndroidScanFailure(scanException(4)), isNull);
      expect(
        BleTransport.classifyAndroidScanFailure(scanException(133)),
        isNull,
      );
      expect(
        BleTransport.classifyAndroidScanFailure(scanException(null)),
        isNull,
      );
    });

    test('ignores connect-path exceptions with overlapping codes', () {
      // android-code 5 means GATT_INSUFFICIENT_AUTHENTICATION on the
      // connect path - it must not be reinterpreted as a scan failure.
      expect(
        BleTransport.classifyAndroidScanFailure(
          scanException(5, function: 'connect'),
        ),
        isNull,
      );
    });

    test('ignores apple-platform exceptions', () {
      expect(
        BleTransport.classifyAndroidScanFailure(
          scanException(2, platform: ErrorPlatform.apple),
        ),
        isNull,
      );
    });

    test('ignores non-FlutterBluePlusException errors', () {
      expect(
        BleTransport.classifyAndroidScanFailure(Exception('SCAN_FAILED')),
        isNull,
      );
    });
  });

  // The Android plugin refuses startScan preconditions with a bare
  // PlatformException; the messages below are the plugin's exact text
  // (flutter_blue_plus_android FlutterBluePlusPlugin.startScan).
  group('BleTransport.classifyAndroidScanFailure startScan preconditions', () {
    PlatformException startScanError(
      String message, {
      String code = 'startScan',
    }) => PlatformException(code: code, message: message);

    test('maps Location services off to locationServicesOff', () {
      final failure = BleTransport.classifyAndroidScanFailure(
        startScanError('Location services are required for Bluetooth scan'),
      );
      expect(failure, isNotNull);
      expect(failure!.kind, BleScanFailureKind.locationServicesOff);
      expect(failure.platformCode, isNull);
    });

    test('maps a missing BLUETOOTH_SCAN grant to permissionDenied', () {
      final failure = BleTransport.classifyAndroidScanFailure(
        startScanError(
          'Permission android.permission.BLUETOOTH_SCAN required to scan devices',
        ),
      );
      expect(failure!.kind, BleScanFailureKind.permissionDenied);
    });

    test('maps a missing ACCESS_FINE_LOCATION grant to permissionDenied', () {
      final failure = BleTransport.classifyAndroidScanFailure(
        startScanError(
          'Permission android.permission.ACCESS_FINE_LOCATION required to scan devices',
        ),
      );
      expect(failure!.kind, BleScanFailureKind.permissionDenied);
    });

    test(
      'leaves adapter-off and scanner-null refusals to existing handling',
      () {
        expect(
          BleTransport.classifyAndroidScanFailure(
            startScanError('Bluetooth must be turned on'),
          ),
          isNull,
        );
        expect(
          BleTransport.classifyAndroidScanFailure(
            startScanError(
              'getBluetoothLeScanner() is null. Is the Adapter on?',
            ),
          ),
          isNull,
        );
      },
    );

    test('ignores the same text from a non-startScan method', () {
      expect(
        BleTransport.classifyAndroidScanFailure(
          startScanError(
            'Location services are required for Bluetooth scan',
            code: 'connect',
          ),
        ),
        isNull,
      );
    });

    test('ignores a startScan PlatformException with no message', () {
      expect(
        BleTransport.classifyAndroidScanFailure(
          PlatformException(code: 'startScan'),
        ),
        isNull,
      );
    });
  });

  group('BleTransport.scanRequiresLocationServices', () {
    test('keeps the check up to Android 11 (API 30)', () {
      for (final sdk in [23, 26, 28, 29, 30]) {
        expect(
          BleTransport.scanRequiresLocationServices(sdk),
          isTrue,
          reason: 'API $sdk returns no scan results with Location off',
        );
      }
    });

    test('drops the check from Android 12 (API 31) with neverForLocation', () {
      for (final sdk in [31, 32, 33, 34, 35, 36]) {
        expect(BleTransport.scanRequiresLocationServices(sdk), isFalse);
      }
    });

    test('keeps the check when the SDK level is unknown', () {
      expect(BleTransport.scanRequiresLocationServices(null), isTrue);
    });
  });

  group('BleScanFailureKind.isScannerRejection', () {
    test('only OS scanner refusals feed the rescan backoff', () {
      expect(BleScanFailureKind.stackFailure.isScannerRejection, isTrue);
      expect(BleScanFailureKind.throttled.isScannerRejection, isTrue);
      expect(
        BleScanFailureKind.locationServicesOff.isScannerRejection,
        isFalse,
      );
      expect(BleScanFailureKind.permissionDenied.isScannerRejection, isFalse);
    });
  });

  group('BleScanFailure', () {
    test('toString carries kind and platform code for diagnosability', () {
      const failure = BleScanFailure(
        kind: BleScanFailureKind.stackFailure,
        platformCode: 2,
      );
      expect(failure.toString(), contains('stackFailure'));
      expect(failure.toString(), contains('2'));
    });

    test('is an Exception', () {
      const failure = BleScanFailure(
        kind: BleScanFailureKind.throttled,
        platformCode: 6,
      );
      expect(failure, isA<Exception>());
    });

    test('precondition failures carry no platform code', () {
      const failure = BleScanFailure(
        kind: BleScanFailureKind.locationServicesOff,
      );
      expect(failure.platformCode, isNull);
      expect(failure.toString(), contains('locationServicesOff'));
    });
  });
}
