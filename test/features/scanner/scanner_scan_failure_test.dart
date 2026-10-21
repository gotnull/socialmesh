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

  group('scannerShowsBleSearchBanner', () {
    bool shows({
      bool scanning = false,
      bool supportsBle = true,
      bool hasListedRadios = false,
      bool scanRefused = false,
    }) => scannerShowsBleSearchBanner(
      scanning: scanning,
      supportsBle: supportsBle,
      hasListedRadios: hasListedRadios,
      scanRefused: scanRefused,
    );

    test('shows while a scan is running, whatever else is on screen', () {
      expect(shows(scanning: true), isTrue);
      expect(shows(scanning: true, hasListedRadios: true), isTrue);
      expect(shows(scanning: true, scanRefused: true), isTrue);
    });

    test('stays up between scan cycles while no radio is listed', () {
      // The gap between cycles used to render no Bluetooth UI at all.
      expect(shows(), isTrue);
    });

    test('hides between cycles once radios are listed', () {
      // The "Available devices" header with Retry owns that state.
      expect(shows(hasListedRadios: true), isFalse);
    });

    test('hides between cycles when the scan was refused', () {
      // The failure card or error banner explains the refusal; a
      // "scanning" banner beside it would contradict it.
      expect(shows(scanRefused: true), isFalse);
    });

    test('never claims to search on a platform without BLE', () {
      expect(shows(supportsBle: false), isFalse);
    });
  });

  group('scannerSearchSubtitle', () {
    test('says looking until a full scan cycle completes', () {
      expect(
        scannerSearchSubtitle(deviceCount: 0, hasCompletedScan: false),
        ScannerSearchSubtitle.looking,
      );
    });

    test('switches to the nothing-found checklist after a completed scan', () {
      expect(
        scannerSearchSubtitle(deviceCount: 0, hasCompletedScan: true),
        ScannerSearchSubtitle.nothingFoundYet,
      );
    });

    test('shows the device count once anything was found', () {
      expect(
        scannerSearchSubtitle(deviceCount: 2, hasCompletedScan: false),
        ScannerSearchSubtitle.devicesFound,
      );
      expect(
        scannerSearchSubtitle(deviceCount: 1, hasCompletedScan: true),
        ScannerSearchSubtitle.devicesFound,
      );
    });
  });

  group('pruneUnseenScannerDevices', () {
    DeviceInfo radio(String id) =>
        DeviceInfo(id: id, name: id, type: TransportType.ble);

    test('keeps a radio missed in one cycle', () {
      final a = radio('a');
      final devices = [a];
      final seen = {a: 4};

      pruneUnseenScannerDevices(devices, seen, 5);

      expect(devices, [a]);
      expect(seen, {a: 4});
    });

    test('drops a radio missed in two cycles in a row', () {
      final a = radio('a');
      final b = radio('b');
      final devices = [a, b];
      final seen = {a: 4, b: 6};

      pruneUnseenScannerDevices(devices, seen, 6);

      expect(devices, [b]);
      expect(seen, {b: 6}, reason: 'the dropped radio loses its record');
    });

    test('a radio seen again in time stays listed', () {
      final a = radio('a');
      final devices = [a];
      final seen = {a: 4};

      pruneUnseenScannerDevices(devices, seen, 5);
      seen[a] = 6;
      pruneUnseenScannerDevices(devices, seen, 6);
      pruneUnseenScannerDevices(devices, seen, 7);

      expect(devices, [a]);
    });

    test('a listed radio with no sighting record is dropped', () {
      final a = radio('a');
      final devices = [a];

      pruneUnseenScannerDevices(devices, {}, 1);

      expect(devices, isEmpty);
    });
  });
}
