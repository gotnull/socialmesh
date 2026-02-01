// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_device.dart';
import 'package:socialmesh/services/meshcore/meshcore_detector.dart';

/// Tests for scanner connection routing logic.
///
/// These tests verify that protocol detection correctly identifies device types
/// so the scanner can route connections appropriately:
/// - Meshtastic -> Meshtastic BLE connect path
/// - MeshCore -> MeshCore BLE connect path (Nordic UART service)
/// - Unknown -> warning dialog, no automatic connect
void main() {
  group('Scanner Connection Routing Logic', () {
    DeviceInfo createDevice(
      String name, {
      List<String>? serviceUuids,
      Map<int, List<int>>? manufacturerData,
    }) {
      return DeviceInfo(
        id: 'test-id-${name.hashCode}',
        name: name,
        type: TransportType.ble,
        serviceUuids: serviceUuids ?? [],
        manufacturerData: manufacturerData ?? {},
      );
    }

    group('Protocol Detection for Routing', () {
      test(
        'Meshtastic device with service UUID routes to Meshtastic connect',
        () {
          // Meshtastic service UUID: 6ba1b218-15a8-461f-9fa8-5dcae273eafd
          final device = createDevice(
            'Meshtastic f4a8',
            serviceUuids: ['6ba1b218-15a8-461f-9fa8-5dcae273eafd'],
          );

          final detection = device.detectProtocol();

          expect(detection.protocolType, equals(MeshProtocolType.meshtastic));
          expect(detection.confidence, equals(1.0));
          // Scanner should call Meshtastic connect, not MeshCore or warning
        },
      );

      test(
        'Meshtastic device detected by name routes to Meshtastic connect',
        () {
          final device = createDevice('Meshtastic Device');

          final detection = device.detectProtocol();

          expect(detection.protocolType, equals(MeshProtocolType.meshtastic));
          expect(detection.confidence, greaterThan(0.5));
          // Scanner should call Meshtastic connect
        },
      );

      test(
        'MeshCore device with Nordic UART UUID routes to MeshCore connect',
        () {
          // MeshCore uses Nordic UART Service: 6e400001-b5a3-f393-e0a9-e50e24dcca9e
          final device = createDevice(
            'MeshCore Device',
            serviceUuids: [MeshCoreBleUuids.serviceUuid],
          );

          final detection = device.detectProtocol();

          expect(detection.protocolType, equals(MeshProtocolType.meshcore));
          expect(detection.confidence, equals(1.0));
          // Scanner should call MeshCore connect, NOT Meshtastic connect
        },
      );

      test('MeshCore device detected by name routes to MeshCore connect', () {
        final device = createDevice('MeshCore Unit');

        final detection = device.detectProtocol();

        expect(detection.protocolType, equals(MeshProtocolType.meshcore));
        expect(detection.confidence, greaterThan(0.5));
        // Scanner should call MeshCore connect, NOT Meshtastic connect
      });

      test('MeshCore device with MC- prefix routes to MeshCore connect', () {
        final device = createDevice('MC-1234');

        final detection = device.detectProtocol();

        expect(detection.protocolType, equals(MeshProtocolType.meshcore));
        // Scanner should call MeshCore connect, NOT Meshtastic connect
      });

      test(
        'Unknown device routes to warning dialog, not Meshtastic connect',
        () {
          final device = createDevice('Random BLE Device');

          final detection = device.detectProtocol();

          expect(detection.protocolType, equals(MeshProtocolType.unknown));
          expect(detection.confidence, equals(0.0));
          // Scanner should show warning dialog, NOT call Meshtastic connect
        },
      );

      test(
        'Unknown device with unrelated service UUID does not route to Meshtastic',
        () {
          final device = createDevice(
            'Heart Rate Monitor',
            serviceUuids: [
              '0000180d-0000-1000-8000-00805f9b34fb',
            ], // Heart Rate
          );

          final detection = device.detectProtocol();

          expect(detection.protocolType, equals(MeshProtocolType.unknown));
          // Scanner should NOT call Meshtastic connect for non-mesh devices
        },
      );
    });

    group('MeshCore Nordic UART UUIDs', () {
      test('MeshCore service UUID is Nordic UART Service', () {
        expect(
          MeshCoreBleUuids.serviceUuid.toLowerCase(),
          equals('6e400001-b5a3-f393-e0a9-e50e24dcca9e'),
        );
      });

      test('MeshCore write characteristic is Nordic UART RX', () {
        expect(
          MeshCoreBleUuids.writeCharacteristicUuid.toLowerCase(),
          equals('6e400002-b5a3-f393-e0a9-e50e24dcca9e'),
        );
      });

      test('MeshCore notify characteristic is Nordic UART TX', () {
        expect(
          MeshCoreBleUuids.notifyCharacteristicUuid.toLowerCase(),
          equals('6e400003-b5a3-f393-e0a9-e50e24dcca9e'),
        );
      });
    });

    group('DeviceInfo.detectProtocol() extension', () {
      test('uses embedded serviceUuids for detection', () {
        final device = DeviceInfo(
          id: 'test-id',
          name: 'Unknown Device',
          type: TransportType.ble,
          serviceUuids: [MeshCoreBleUuids.serviceUuid],
        );

        final result = device.detectProtocol();

        expect(result.protocolType, equals(MeshProtocolType.meshcore));
        expect(result.confidence, equals(1.0));
      });

      test('uses embedded manufacturerData for detection', () {
        final device = DeviceInfo(
          id: 'test-id',
          name: 'Unknown Device',
          type: TransportType.ble,
          serviceUuids: [],
          manufacturerData: {
            0x1234: [1, 2, 3],
          },
        );

        // Should check manufacturer data (currently returns unknown if no match)
        final result = device.detectProtocol();
        expect(result, isNotNull);
      });

      test('prefers service UUID over name matching', () {
        // Device named "MeshCore" but advertising Meshtastic service
        final device = DeviceInfo(
          id: 'test-id',
          name: 'MeshCore Device',
          type: TransportType.ble,
          serviceUuids: ['6ba1b218-15a8-461f-9fa8-5dcae273eafd'],
        );

        final result = device.detectProtocol();

        // Service UUID should take precedence over name
        expect(result.protocolType, equals(MeshProtocolType.meshtastic));
        expect(result.confidence, equals(1.0));
      });
    });

    group('Protocol-based Routing Decisions', () {
      test('Meshtastic protocol should use Meshtastic BLE transport', () {
        final device = createDevice(
          'Meshtastic Node',
          serviceUuids: ['6ba1b218-15a8-461f-9fa8-5dcae273eafd'],
        );
        final detection = device.detectProtocol();

        // Verify the decision criteria used by scanner
        final shouldUseMeshtastic =
            detection.protocolType == MeshProtocolType.meshtastic;
        final shouldUseMeshCore =
            detection.protocolType == MeshProtocolType.meshcore;
        final shouldShowWarning =
            detection.protocolType == MeshProtocolType.unknown;

        expect(shouldUseMeshtastic, isTrue);
        expect(shouldUseMeshCore, isFalse);
        expect(shouldShowWarning, isFalse);
      });

      test('MeshCore protocol should NOT use Meshtastic BLE transport', () {
        final device = createDevice(
          'MeshCore Node',
          serviceUuids: [MeshCoreBleUuids.serviceUuid],
        );
        final detection = device.detectProtocol();

        final shouldUseMeshtastic =
            detection.protocolType == MeshProtocolType.meshtastic;
        final shouldUseMeshCore =
            detection.protocolType == MeshProtocolType.meshcore;
        final shouldShowWarning =
            detection.protocolType == MeshProtocolType.unknown;

        expect(shouldUseMeshtastic, isFalse);
        expect(shouldUseMeshCore, isTrue);
        expect(shouldShowWarning, isFalse);
      });

      test('Unknown protocol should NOT attempt any automatic connection', () {
        final device = createDevice('Random BLE Device');
        final detection = device.detectProtocol();

        final shouldUseMeshtastic =
            detection.protocolType == MeshProtocolType.meshtastic;
        final shouldUseMeshCore =
            detection.protocolType == MeshProtocolType.meshcore;
        final shouldShowWarning =
            detection.protocolType == MeshProtocolType.unknown;

        expect(shouldUseMeshtastic, isFalse);
        expect(shouldUseMeshCore, isFalse);
        expect(shouldShowWarning, isTrue);
      });
    });
  });
}
