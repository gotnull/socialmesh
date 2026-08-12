// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
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
  });
}
