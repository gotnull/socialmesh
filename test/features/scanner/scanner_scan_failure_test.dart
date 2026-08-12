// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/core/ble_system_devices.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/scanner/scanner_screen.dart';
import 'package:socialmesh/models/mesh_device.dart';
import 'package:socialmesh/services/meshcore/meshcore_detector.dart';

void main() {
  group('savedDeviceServiceUuid', () {
    test('bare BLE remote id resolves to the Meshtastic service UUID', () {
      expect(
        savedDeviceServiceUuid('AA:BB:CC:DD:EE:FF'),
        MeshtasticBleUuids.serviceUuid,
      );
    });

    test('meshcore-prefixed id resolves to the MeshCore service UUID', () {
      expect(
        savedDeviceServiceUuid('meshcore-ble:AA:BB:CC:DD:EE:FF'),
        MeshCoreBleUuids.serviceUuid,
      );
    });
  });

  group('saved-device placeholder protocol detection', () {
    // A node renamed away from the stock "Name XXXX" pattern matches no
    // name heuristic. Without a seeded service UUID the placeholder row
    // resolves to `unknown`, and unknown rows silently ignore taps -
    // the exact dead-tap a paired device must never exhibit.
    const renamedNodeName = 'BFG4_64cc';

    test('renamed node WITHOUT seeded UUID resolves to unknown', () {
      final placeholder = DeviceInfo(
        id: 'AA:BB:CC:DD:EE:FF',
        name: renamedNodeName,
        type: TransportType.ble,
      );
      expect(
        placeholder.detectProtocol().protocolType,
        MeshProtocolType.unknown,
      );
    });

    test('renamed node WITH seeded UUID resolves to meshtastic', () {
      final placeholder = DeviceInfo(
        id: 'AA:BB:CC:DD:EE:FF',
        name: renamedNodeName,
        type: TransportType.ble,
        serviceUuids: [savedDeviceServiceUuid('AA:BB:CC:DD:EE:FF')],
      );
      final detection = placeholder.detectProtocol();
      expect(detection.protocolType, MeshProtocolType.meshtastic);
      expect(detection.confidence, 1.0);
    });

    test('meshcore saved id WITH seeded UUID resolves to meshcore', () {
      const savedId = 'meshcore-ble:AA:BB:CC:DD:EE:FF';
      final placeholder = DeviceInfo(
        id: savedId,
        name: renamedNodeName,
        type: TransportType.ble,
        serviceUuids: [savedDeviceServiceUuid(savedId)],
      );
      expect(
        placeholder.detectProtocol().protocolType,
        MeshProtocolType.meshcore,
      );
    });
  });

  group('scannerRescanDelay', () {
    test('healthy scans rescan on the normal 3 second cadence', () {
      expect(scannerRescanDelay(0), const Duration(seconds: 3));
    });

    test('backoff doubles per consecutive failure and caps at 60 s', () {
      expect(scannerRescanDelay(1), const Duration(seconds: 5));
      expect(scannerRescanDelay(2), const Duration(seconds: 10));
      expect(scannerRescanDelay(3), const Duration(seconds: 20));
      expect(scannerRescanDelay(4), const Duration(seconds: 40));
      expect(scannerRescanDelay(5), const Duration(seconds: 60));
      expect(scannerRescanDelay(12), const Duration(seconds: 60));
    });

    test('failure cadence never exceeds the Android scan-start throttle', () {
      // Android throttles apps starting more than 5 scans in any
      // 30 second window. Simulate a persistent failure loop and
      // assert no window ever holds more than 4 starts (one slot is
      // left free for a user-initiated manual retry).
      final startTimes = <int>[];
      var elapsed = 0;
      for (var streak = 0; startTimes.length < 20; streak++) {
        startTimes.add(elapsed);
        elapsed += scannerRescanDelay(streak + 1).inSeconds;
      }
      for (final windowStart in startTimes) {
        final inWindow = startTimes
            .where((t) => t >= windowStart && t < windowStart + 30)
            .length;
        expect(inWindow, lessThanOrEqualTo(4));
      }
    });
  });
}
