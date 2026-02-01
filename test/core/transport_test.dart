// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';

void main() {
  group('DeviceInfo', () {
    test('creates BLE device with basic info', () {
      final device = DeviceInfo(
        id: 'AA:BB:CC:DD:EE:FF',
        name: 'Test Device',
        type: TransportType.ble,
        rssi: -70,
      );

      expect(device.id, equals('AA:BB:CC:DD:EE:FF'));
      expect(device.name, equals('Test Device'));
      expect(device.type, equals(TransportType.ble));
      expect(device.rssi, equals(-70));
      expect(device.serviceUuids, isEmpty);
      expect(device.manufacturerData, isEmpty);
    });

    test('creates BLE device with advertisement data', () {
      final device = DeviceInfo(
        id: 'AA:BB:CC:DD:EE:FF',
        name: 'Meshtastic Device',
        type: TransportType.ble,
        rssi: -65,
        serviceUuids: [
          '6ba1b218-15a8-461f-9fa8-5dcae273eafd',
          '0000180a-0000-1000-8000-00805f9b34fb',
        ],
        manufacturerData: {
          0x0123: [0x01, 0x02, 0x03],
          0x0456: [0x04, 0x05],
        },
      );

      expect(device.serviceUuids, hasLength(2));
      expect(
        device.serviceUuids[0],
        equals('6ba1b218-15a8-461f-9fa8-5dcae273eafd'),
      );
      expect(device.manufacturerData, hasLength(2));
      expect(device.manufacturerData[0x0123], equals([0x01, 0x02, 0x03]));
    });

    test('creates USB device without advertisement data', () {
      final device = DeviceInfo(
        id: '1234:5678:1',
        name: 'USB Serial Device',
        type: TransportType.usb,
        address: '/dev/ttyUSB0',
      );

      expect(device.type, equals(TransportType.usb));
      expect(device.address, equals('/dev/ttyUSB0'));
      expect(device.rssi, isNull);
      expect(device.serviceUuids, isEmpty);
      expect(device.manufacturerData, isEmpty);
    });

    group('equality', () {
      test('two devices with same id and type are equal', () {
        final device1 = DeviceInfo(
          id: 'AA:BB:CC:DD:EE:FF',
          name: 'Device 1',
          type: TransportType.ble,
        );
        final device2 = DeviceInfo(
          id: 'AA:BB:CC:DD:EE:FF',
          name: 'Device 2', // Different name
          type: TransportType.ble,
        );

        expect(device1, equals(device2));
        expect(device1.hashCode, equals(device2.hashCode));
      });

      test('devices with different ids are not equal', () {
        final device1 = DeviceInfo(
          id: 'AA:BB:CC:DD:EE:FF',
          name: 'Device',
          type: TransportType.ble,
        );
        final device2 = DeviceInfo(
          id: '11:22:33:44:55:66',
          name: 'Device',
          type: TransportType.ble,
        );

        expect(device1, isNot(equals(device2)));
      });

      test('devices with different types are not equal', () {
        final device1 = DeviceInfo(
          id: 'test-id',
          name: 'Device',
          type: TransportType.ble,
        );
        final device2 = DeviceInfo(
          id: 'test-id',
          name: 'Device',
          type: TransportType.usb,
        );

        expect(device1, isNot(equals(device2)));
      });
    });

    test('toString() includes name, type, and rssi', () {
      final device = DeviceInfo(
        id: 'test-id',
        name: 'Test Device',
        type: TransportType.ble,
        rssi: -70,
      );

      final str = device.toString();
      expect(str, contains('Test Device'));
      expect(str, contains('ble'));
      expect(str, contains('-70'));
    });
  });
}
