// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';

void main() {
  group('MeshCoreBleUuids', () {
    group('Nordic UART Service UUIDs', () {
      test('serviceUuid is correct Nordic UART Service UUID', () {
        // Standard Nordic UART Service UUID
        expect(
          MeshCoreBleUuids.serviceUuid.toLowerCase(),
          equals('6e400001-b5a3-f393-e0a9-e50e24dcca9e'),
        );
      });

      test('writeCharacteristicUuid is correct Nordic UART RX UUID', () {
        // NUS RX characteristic (write to device)
        expect(
          MeshCoreBleUuids.writeCharacteristicUuid.toLowerCase(),
          equals('6e400002-b5a3-f393-e0a9-e50e24dcca9e'),
        );
      });

      test('notifyCharacteristicUuid is correct Nordic UART TX UUID', () {
        // NUS TX characteristic (notify from device)
        expect(
          MeshCoreBleUuids.notifyCharacteristicUuid.toLowerCase(),
          equals('6e400003-b5a3-f393-e0a9-e50e24dcca9e'),
        );
      });

      test('scanFilterUuids contains serviceUuid', () {
        expect(
          MeshCoreBleUuids.scanFilterUuids,
          contains(MeshCoreBleUuids.serviceUuid),
        );
      });

      test('all UUIDs have consistent base format', () {
        // All Nordic UART UUIDs share the same base: -b5a3-f393-e0a9-e50e24dcca9e
        const uuidBase = 'b5a3-f393-e0a9-e50e24dcca9e';
        expect(MeshCoreBleUuids.serviceUuid.toLowerCase(), endsWith(uuidBase));
        expect(
          MeshCoreBleUuids.writeCharacteristicUuid.toLowerCase(),
          endsWith(uuidBase),
        );
        expect(
          MeshCoreBleUuids.notifyCharacteristicUuid.toLowerCase(),
          endsWith(uuidBase),
        );
      });
    });

    group('UUID uniqueness', () {
      test('service and characteristic UUIDs are all different', () {
        final uuids = {
          MeshCoreBleUuids.serviceUuid,
          MeshCoreBleUuids.writeCharacteristicUuid,
          MeshCoreBleUuids.notifyCharacteristicUuid,
        };
        expect(uuids.length, equals(3), reason: 'All UUIDs should be unique');
      });
    });
  });

  group('MeshCoreFramingConstants', () {
    test('USB direction markers are correct', () {
      expect(MeshCoreFramingConstants.usbAppToRadioMarker, equals(0x3C)); // '<'
      expect(MeshCoreFramingConstants.usbRadioToAppMarker, equals(0x3E)); // '>'
    });

    test('USB header size is marker + 2-byte length', () {
      expect(MeshCoreFramingConstants.usbHeaderSize, equals(3));
    });

    test('maxPayloadSize is reasonable', () {
      expect(MeshCoreFramingConstants.maxPayloadSize, equals(250));
    });
  });

  group('MeshCoreTimeouts', () {
    test('connection timeout is reasonable', () {
      expect(
        MeshCoreTimeouts.connection.inSeconds,
        greaterThanOrEqualTo(10),
        reason: 'Connection timeout should be at least 10 seconds',
      );
      expect(
        MeshCoreTimeouts.connection.inSeconds,
        lessThanOrEqualTo(60),
        reason: 'Connection timeout should not exceed 60 seconds',
      );
    });
  });

  group('MeshCoreCodeClassification', () {
    group('isResponseCode', () {
      test('returns true for response codes (0x00-0x7F)', () {
        expect(MeshCoreCodeClassification.isResponseCode(0x00), isTrue);
        expect(MeshCoreCodeClassification.isResponseCode(0x05), isTrue);
        expect(MeshCoreCodeClassification.isResponseCode(0x0C), isTrue);
        expect(MeshCoreCodeClassification.isResponseCode(0x7F), isTrue);
      });

      test('returns false for push codes (0x80+)', () {
        expect(MeshCoreCodeClassification.isResponseCode(0x80), isFalse);
        expect(MeshCoreCodeClassification.isResponseCode(0x85), isFalse);
        expect(MeshCoreCodeClassification.isResponseCode(0xFF), isFalse);
      });

      test('boundary value at 0x80', () {
        expect(MeshCoreCodeClassification.isResponseCode(0x7F), isTrue);
        expect(MeshCoreCodeClassification.isResponseCode(0x80), isFalse);
      });
    });

    group('isPushCode', () {
      test('returns true for push codes (0x80+)', () {
        expect(MeshCoreCodeClassification.isPushCode(0x80), isTrue);
        expect(MeshCoreCodeClassification.isPushCode(0x85), isTrue);
        expect(MeshCoreCodeClassification.isPushCode(0x8C), isTrue);
        expect(MeshCoreCodeClassification.isPushCode(0xFF), isTrue);
      });

      test('returns false for response codes (0x00-0x7F)', () {
        expect(MeshCoreCodeClassification.isPushCode(0x00), isFalse);
        expect(MeshCoreCodeClassification.isPushCode(0x05), isFalse);
        expect(MeshCoreCodeClassification.isPushCode(0x7F), isFalse);
      });

      test('boundary value at 0x80', () {
        expect(MeshCoreCodeClassification.isPushCode(0x7F), isFalse);
        expect(MeshCoreCodeClassification.isPushCode(0x80), isTrue);
      });
    });

    group('isCommandCode', () {
      test('returns true for valid commands (0x01-0x39)', () {
        expect(MeshCoreCodeClassification.isCommandCode(0x01), isTrue);
        expect(MeshCoreCodeClassification.isCommandCode(0x14), isTrue);
        expect(MeshCoreCodeClassification.isCommandCode(0x16), isTrue);
        expect(
          MeshCoreCodeClassification.isCommandCode(
            MeshCoreCommands.getRadioSettings,
          ),
          isTrue,
        );
      });

      test('returns false for 0x00 (OK response)', () {
        expect(MeshCoreCodeClassification.isCommandCode(0x00), isFalse);
      });

      test('returns false for codes above command range', () {
        expect(
          MeshCoreCodeClassification.isCommandCode(
            MeshCoreCommands.getRadioSettings + 1,
          ),
          isFalse,
        );
        expect(MeshCoreCodeClassification.isCommandCode(0x80), isFalse);
      });
    });

    group('known code constants validation', () {
      test('MeshCoreResponses are response codes', () {
        expect(
          MeshCoreCodeClassification.isResponseCode(MeshCoreResponses.ok),
          isTrue,
        );
        expect(
          MeshCoreCodeClassification.isResponseCode(MeshCoreResponses.selfInfo),
          isTrue,
        );
        expect(
          MeshCoreCodeClassification.isResponseCode(
            MeshCoreResponses.battAndStorage,
          ),
          isTrue,
        );
      });

      test('MeshCorePushCodes are push codes', () {
        expect(
          MeshCoreCodeClassification.isPushCode(MeshCorePushCodes.advert),
          isTrue,
        );
        expect(
          MeshCoreCodeClassification.isPushCode(MeshCorePushCodes.pathUpdated),
          isTrue,
        );
        expect(
          MeshCoreCodeClassification.isPushCode(
            MeshCorePushCodes.sendConfirmed,
          ),
          isTrue,
        );
        expect(
          MeshCoreCodeClassification.isPushCode(MeshCorePushCodes.newAdvert),
          isTrue,
        );
      });

      test('MeshCoreCommands are command codes', () {
        expect(
          MeshCoreCodeClassification.isCommandCode(MeshCoreCommands.appStart),
          isTrue,
        );
        expect(
          MeshCoreCodeClassification.isCommandCode(
            MeshCoreCommands.getBattAndStorage,
          ),
          isTrue,
        );
        expect(
          MeshCoreCodeClassification.isCommandCode(
            MeshCoreCommands.deviceQuery,
          ),
          isTrue,
        );
      });
    });
  });
}
