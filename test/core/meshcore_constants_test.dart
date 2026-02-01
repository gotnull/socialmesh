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
}
