// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_device.dart';
import 'package:socialmesh/services/meshcore/meshcore_ble_transport.dart';

/// Fake BLE service for testing MeshCore transport.
class FakeBleService {
  final String uuid;
  final List<FakeBleCharacteristic> characteristics;

  FakeBleService(this.uuid, this.characteristics);
}

/// Fake BLE characteristic for testing.
class FakeBleCharacteristic {
  final String uuid;
  final bool canWrite;
  final bool canNotify;
  bool notificationsEnabled = false;

  FakeBleCharacteristic(
    this.uuid, {
    this.canWrite = false,
    this.canNotify = false,
  });
}

void main() {
  group('MeshCore BLE Transport', () {
    group('Nordic UART UUIDs', () {
      test('service UUID is correct', () {
        expect(
          MeshCoreBleUuids.serviceUuid.toLowerCase(),
          equals('6e400001-b5a3-f393-e0a9-e50e24dcca9e'),
        );
      });

      test('TX characteristic UUID is correct (write to device)', () {
        expect(
          MeshCoreBleUuids.writeCharacteristicUuid.toLowerCase(),
          equals('6e400002-b5a3-f393-e0a9-e50e24dcca9e'),
        );
      });

      test('RX characteristic UUID is correct (notify from device)', () {
        expect(
          MeshCoreBleUuids.notifyCharacteristicUuid.toLowerCase(),
          equals('6e400003-b5a3-f393-e0a9-e50e24dcca9e'),
        );
      });
    });

    group('MeshCoreServiceNotFoundException', () {
      test('creates exception with message', () {
        const exception = MeshCoreServiceNotFoundException(
          'Nordic UART service not found',
        );

        expect(exception.message, contains('Nordic UART'));
        expect(
          exception.toString(),
          contains('MeshCoreServiceNotFoundException'),
        );
      });
    });

    group('MeshCoreCharacteristicNotFoundException', () {
      test('creates exception with message and error', () {
        const exception = MeshCoreCharacteristicNotFoundException(
          'TX characteristic not found',
          MeshProtocolError.unsupportedDevice,
        );

        expect(exception.message, contains('TX characteristic'));
        expect(exception.error, equals(MeshProtocolError.unsupportedDevice));
        expect(
          exception.toString(),
          contains('MeshCoreCharacteristicNotFoundException'),
        );
      });
    });

    group('MeshCoreBleTransport initialization', () {
      test('starts in disconnected state', () {
        final transport = MeshCoreBleTransport();

        expect(
          transport.connectionState,
          equals(DeviceConnectionState.disconnected),
        );
        expect(transport.isConnected, isFalse);
        expect(transport.transportType, equals(TransportType.ble));
      });

      test('exposes rawRxStream for debugging', () {
        final transport = MeshCoreBleTransport();

        expect(transport.rawRxStream, isA<Stream<Uint8List>>());
      });

      test('exposes dataStream for protocol data', () {
        final transport = MeshCoreBleTransport();

        expect(transport.dataStream, isA<Stream<List<int>>>());
      });
    });

    group('Service Discovery Requirements', () {
      test('does NOT require Device Information Service (0x180A)', () {
        // MeshCore should work without DIS - it only needs Nordic UART
        // This is a key difference from Meshtastic which reads model info from DIS

        // The service discovery logic should:
        // 1. Look for Nordic UART service (6e400001)
        // 2. Find TX char (6e400002) and RX char (6e400003)
        // 3. NOT fail if 0x180A is missing

        // Verify the UUIDs don't include 0x180A
        expect(MeshCoreBleUuids.scanFilterUuids, isNot(contains('180a')));
        expect(
          MeshCoreBleUuids.scanFilterUuids,
          isNot(contains('0000180a-0000-1000-8000-00805f9b34fb')),
        );
      });

      test('only requires Nordic UART service', () {
        expect(
          MeshCoreBleUuids.scanFilterUuids,
          contains(MeshCoreBleUuids.serviceUuid),
        );
        expect(MeshCoreBleUuids.scanFilterUuids.length, equals(1));
      });
    });

    group('Protocol Error Types', () {
      test('unsupportedDevice error has correct message', () {
        expect(
          MeshProtocolError.unsupportedDevice.userMessage,
          contains('missing required BLE characteristics'),
        );
      });

      test('unsupportedDevice error has correct title', () {
        expect(
          MeshProtocolError.unsupportedDevice.title,
          equals('Unsupported Device'),
        );
      });
    });

    group('Connection State Transitions', () {
      late MeshCoreBleTransport transport;
      late List<DeviceConnectionState> stateChanges;
      late StreamSubscription<DeviceConnectionState> subscription;

      setUp(() {
        transport = MeshCoreBleTransport();
        stateChanges = [];
        subscription = transport.connectionStateStream.listen(stateChanges.add);
      });

      tearDown(() async {
        await subscription.cancel();
        await transport.dispose();
      });

      test('initial state is disconnected', () {
        expect(
          transport.connectionState,
          equals(DeviceConnectionState.disconnected),
        );
      });

      test('connectionStateStream emits state changes', () async {
        // The transport exposes a state stream for UI updates
        expect(transport.connectionStateStream, isA<Stream>());
      });
    });
  });

  group('MeshCore vs Meshtastic Isolation', () {
    test('MeshCore UUIDs are different from Meshtastic', () {
      // Meshtastic service UUID
      const meshtasticService = '6ba1b218-15a8-461f-9fa8-5dcae273eafd';

      // MeshCore uses different UUIDs - verify isolation
      expect(
        MeshCoreBleUuids.serviceUuid.toLowerCase(),
        isNot(equals(meshtasticService.toLowerCase())),
      );
    });

    test('MeshCore transport type is BLE', () {
      final transport = MeshCoreBleTransport();
      expect(transport.transportType, equals(TransportType.ble));
    });
  });

  group('Raw Debug Stream', () {
    test('rawRxStream is broadcast stream', () async {
      final transport = MeshCoreBleTransport();

      // Should be able to listen multiple times
      final sub1 = transport.rawRxStream.listen((_) {});
      final sub2 = transport.rawRxStream.listen((_) {});

      await sub1.cancel();
      await sub2.cancel();
      await transport.dispose();
    });

    test('dataStream is broadcast stream', () async {
      final transport = MeshCoreBleTransport();

      // Should be able to listen multiple times
      final sub1 = transport.dataStream.listen((_) {});
      final sub2 = transport.dataStream.listen((_) {});

      await sub1.cancel();
      await sub2.cancel();
      await transport.dispose();
    });
  });
}
