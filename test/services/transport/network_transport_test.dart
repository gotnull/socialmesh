// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/services/transport/network_transport.dart';

void main() {
  group('NetworkTransport', () {
    test('type is TransportType.network', () {
      final transport = NetworkTransport(host: '127.0.0.1', port: 4403);
      expect(transport.type, TransportType.network);
    });

    test('requiresFraming is true (same as USB)', () {
      final transport = NetworkTransport(host: '127.0.0.1', port: 4403);
      expect(transport.requiresFraming, isTrue);
    });

    test('initial state is disconnected', () {
      final transport = NetworkTransport(host: '127.0.0.1', port: 4403);
      expect(transport.state, DeviceConnectionState.disconnected);
      expect(transport.isConnected, isFalse);
    });

    test('bleModelNumber returns null', () {
      final transport = NetworkTransport(host: '127.0.0.1', port: 4403);
      expect(transport.bleModelNumber, isNull);
    });

    test('bleManufacturerName returns null', () {
      final transport = NetworkTransport(host: '127.0.0.1', port: 4403);
      expect(transport.bleManufacturerName, isNull);
    });

    test('readRssi returns null', () async {
      final transport = NetworkTransport(host: '127.0.0.1', port: 4403);
      final rssi = await transport.readRssi();
      expect(rssi, isNull);
    });

    test('scan yields nothing (network does not scan)', () async {
      final transport = NetworkTransport(host: '127.0.0.1', port: 4403);
      final devices = await transport.scan().toList();
      expect(devices, isEmpty);
    });

    test('enableNotifications completes without error', () async {
      final transport = NetworkTransport(host: '127.0.0.1', port: 4403);
      await transport.enableNotifications();
    });

    test('pollOnce completes without error', () async {
      final transport = NetworkTransport(host: '127.0.0.1', port: 4403);
      await transport.pollOnce();
    });

    test('send throws StateError when not connected', () {
      final transport = NetworkTransport(host: '127.0.0.1', port: 4403);
      expect(() => transport.send([1, 2, 3]), throwsA(isA<StateError>()));
    });

    test('connect to unreachable host transitions to error', () async {
      final transport = NetworkTransport(host: '192.0.2.1', port: 4403);

      try {
        await transport.connect(
          DeviceInfo(id: 'test', name: 'Test', type: TransportType.network),
        );
        fail('Should have thrown');
      } catch (_) {
        // Expected
      }

      expect(transport.state, DeviceConnectionState.error);
      expect(transport.isConnected, isFalse);
    });

    test('disconnect from disconnected state is no-op', () async {
      final transport = NetworkTransport(host: '127.0.0.1', port: 4403);
      await transport.disconnect();
      expect(transport.state, DeviceConnectionState.disconnected);
    });

    test('dispose cleans up', () async {
      final transport = NetworkTransport(host: '127.0.0.1', port: 4403);
      await transport.dispose();
    });

    test('kMeshtasticDefaultPort is 4403', () {
      expect(kMeshtasticDefaultPort, 4403);
    });
  });

  group('TransportType', () {
    test('has network value', () {
      expect(TransportType.values, contains(TransportType.network));
    });

    test('has three values (ble, usb, network)', () {
      expect(TransportType.values.length, 3);
    });
  });
}
