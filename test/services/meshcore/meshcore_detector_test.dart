// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_device.dart';
import 'package:socialmesh/services/meshcore/meshcore_detector.dart';

void main() {
  group('MeshProtocolDetector', () {
    DeviceInfo createDevice(String name, {List<String>? serviceUuids}) {
      return DeviceInfo(
        id: 'test-id',
        name: name,
        type: TransportType.ble,
        serviceUuids: serviceUuids ?? [],
      );
    }

    group('detect() from service UUIDs', () {
      test('detects Meshtastic from service UUID', () {
        final result = MeshProtocolDetector.detect(
          device: createDevice('Unknown'),
          advertisedServiceUuids: ['6ba1b218-15a8-461f-9fa8-5dcae273eafd'],
        );

        expect(result.protocolType, equals(MeshProtocolType.meshtastic));
        expect(result.confidence, equals(1.0));
        expect(result.reason, contains('Meshtastic service UUID'));
      });

      test('detects Meshtastic from uppercase service UUID', () {
        final result = MeshProtocolDetector.detect(
          device: createDevice('Unknown'),
          advertisedServiceUuids: ['6BA1B218-15A8-461F-9FA8-5DCAE273EAFD'],
        );

        expect(result.protocolType, equals(MeshProtocolType.meshtastic));
        expect(result.confidence, equals(1.0));
      });

      test('detects MeshCore from service UUID', () {
        final result = MeshProtocolDetector.detect(
          device: createDevice('Unknown'),
          advertisedServiceUuids: [MeshCoreBleUuids.serviceUuid],
        );

        expect(result.protocolType, equals(MeshProtocolType.meshcore));
        expect(result.confidence, equals(1.0));
        expect(result.reason, contains('MeshCore service UUID'));
      });
    });

    group('detect() from device name', () {
      test('detects MeshCore from "MeshCore" name', () {
        final result = MeshProtocolDetector.detect(
          device: createDevice('MeshCore Device'),
        );

        expect(result.protocolType, equals(MeshProtocolType.meshcore));
        expect(result.confidence, equals(0.8));
        expect(result.reason, contains('MeshCore pattern'));
      });

      test('detects MeshCore from "meshcore" name (case-insensitive)', () {
        final result = MeshProtocolDetector.detect(
          device: createDevice('meshcore-test'),
        );

        expect(result.protocolType, equals(MeshProtocolType.meshcore));
        expect(result.confidence, equals(0.8));
      });

      test('detects MeshCore from "MESHCORE" name (case-insensitive)', () {
        final result = MeshProtocolDetector.detect(
          device: createDevice('MESHCORE_UNIT'),
        );

        expect(result.protocolType, equals(MeshProtocolType.meshcore));
        expect(result.confidence, equals(0.8));
      });

      test('detects MeshCore from MC- prefix', () {
        final result = MeshProtocolDetector.detect(
          device: createDevice('MC-1234'),
        );

        expect(result.protocolType, equals(MeshProtocolType.meshcore));
        expect(result.confidence, equals(0.8));
      });

      test('detects MeshCore from mc- prefix (case-insensitive)', () {
        final result = MeshProtocolDetector.detect(
          device: createDevice('mc-5678'),
        );

        expect(result.protocolType, equals(MeshProtocolType.meshcore));
        expect(result.confidence, equals(0.8));
      });

      test('detects Meshtastic from "meshtastic" name', () {
        final result = MeshProtocolDetector.detect(
          device: createDevice('Meshtastic f4a8'),
        );

        expect(result.protocolType, equals(MeshProtocolType.meshtastic));
        expect(result.confidence, equals(0.7));
        expect(result.reason, contains('Meshtastic pattern'));
      });

      test('detects Meshtastic from "Mesh-" prefix', () {
        final result = MeshProtocolDetector.detect(
          device: createDevice('Mesh-1234'),
        );

        expect(result.protocolType, equals(MeshProtocolType.meshtastic));
        expect(result.confidence, equals(0.7));
      });

      test('returns unknown for unrecognized device', () {
        final result = MeshProtocolDetector.detect(
          device: createDevice('Random BLE Device'),
        );

        expect(result.protocolType, equals(MeshProtocolType.unknown));
        expect(result.confidence, equals(0.0));
        expect(result.reason, contains('No matching'));
      });
    });

    group('detectProtocol() extension', () {
      test('uses device serviceUuids and manufacturerData', () {
        final device = DeviceInfo(
          id: 'test',
          name: 'Unknown',
          type: TransportType.ble,
          serviceUuids: ['6ba1b218-15a8-461f-9fa8-5dcae273eafd'],
          manufacturerData: {
            0x1234: [1, 2, 3],
          },
        );

        final result = device.detectProtocol();

        expect(result.protocolType, equals(MeshProtocolType.meshtastic));
        expect(result.confidence, equals(1.0));
      });
    });

    group('isMeshCore() convenience method', () {
      test('returns true for MeshCore device', () {
        expect(
          MeshProtocolDetector.isMeshCore(
            device: createDevice('MeshCore Test'),
          ),
          isTrue,
        );
      });

      test('returns false for Meshtastic device', () {
        expect(
          MeshProtocolDetector.isMeshCore(
            device: createDevice('Meshtastic Test'),
          ),
          isFalse,
        );
      });
    });

    group('isMeshtastic() convenience method', () {
      test('returns true for Meshtastic device', () {
        expect(
          MeshProtocolDetector.isMeshtastic(
            device: createDevice('Meshtastic Test'),
          ),
          isTrue,
        );
      });

      test('returns false for MeshCore device', () {
        expect(
          MeshProtocolDetector.isMeshtastic(
            device: createDevice('MeshCore Test'),
          ),
          isFalse,
        );
      });
    });
  });

  group('MeshCoreDevicePatterns', () {
    group('matchesDeviceName()', () {
      test('returns true for "MeshCore" prefix', () {
        expect(MeshCoreDevicePatterns.matchesDeviceName('MeshCore'), isTrue);
        expect(
          MeshCoreDevicePatterns.matchesDeviceName('MeshCore Device'),
          isTrue,
        );
      });

      test('returns true for "meshcore" prefix (case-insensitive)', () {
        expect(MeshCoreDevicePatterns.matchesDeviceName('meshcore'), isTrue);
        expect(
          MeshCoreDevicePatterns.matchesDeviceName('meshcore_test'),
          isTrue,
        );
      });

      test('returns true for "MESHCORE" (case-insensitive)', () {
        expect(MeshCoreDevicePatterns.matchesDeviceName('MESHCORE'), isTrue);
        expect(MeshCoreDevicePatterns.matchesDeviceName('MESHCORE123'), isTrue);
      });

      test('returns true for "MeShCoRe" (mixed case)', () {
        expect(MeshCoreDevicePatterns.matchesDeviceName('MeShCoRe'), isTrue);
      });

      test('returns true for "mc-" prefix (case-insensitive)', () {
        expect(MeshCoreDevicePatterns.matchesDeviceName('mc-1234'), isTrue);
        expect(MeshCoreDevicePatterns.matchesDeviceName('MC-5678'), isTrue);
      });

      test('returns true for names containing "meshcore"', () {
        expect(
          MeshCoreDevicePatterns.matchesDeviceName('My MeshCore Device'),
          isTrue,
        );
        expect(
          MeshCoreDevicePatterns.matchesDeviceName('test_meshcore_unit'),
          isTrue,
        );
      });

      test('returns false for unrelated names', () {
        expect(MeshCoreDevicePatterns.matchesDeviceName('Meshtastic'), isFalse);
        expect(
          MeshCoreDevicePatterns.matchesDeviceName('Random Device'),
          isFalse,
        );
        expect(MeshCoreDevicePatterns.matchesDeviceName('BLE Sensor'), isFalse);
      });

      test('returns false for null or empty names', () {
        expect(MeshCoreDevicePatterns.matchesDeviceName(null), isFalse);
        expect(MeshCoreDevicePatterns.matchesDeviceName(''), isFalse);
      });
    });
  });
}
