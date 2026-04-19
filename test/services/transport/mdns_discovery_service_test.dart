// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/services/transport/mdns_discovery_service.dart';
import 'package:socialmesh/services/transport/network_transport.dart';

void main() {
  group('MdnsDeviceInfo', () {
    test('displayName uses shortname_nodeIdSuffix format', () {
      final device = MdnsDeviceInfo(
        host: '192.168.1.100',
        port: 4403,
        serviceName: 'Meshtastic_abcd',
        shortName: '0864',
        nodeId: '08640864',
      );
      expect(device.displayName, '0864_0864');
    });

    test('displayName with shortName only', () {
      final device = MdnsDeviceInfo(
        host: '192.168.1.100',
        port: 4403,
        serviceName: 'Meshtastic_abcd',
        shortName: 'ABCD',
      );
      expect(device.displayName, 'ABCD');
    });

    test('displayName falls back to serviceName (host) when no TXT fields', () {
      final device = MdnsDeviceInfo(
        host: '192.168.1.100',
        port: 4403,
        serviceName: 'Meshtastic_abcd',
      );
      expect(device.displayName, 'Meshtastic_abcd (192.168.1.100)');
    });

    test('displayName with short nodeId (< 4 chars) omits suffix', () {
      final device = MdnsDeviceInfo(
        host: '10.0.0.1',
        port: 4403,
        serviceName: 'Mesh',
        shortName: 'ABC',
        nodeId: '12',
      );
      expect(device.displayName, 'ABC');
    });

    test('displayName with empty shortName and valid nodeId', () {
      final device = MdnsDeviceInfo(
        host: '10.0.0.1',
        port: 4403,
        serviceName: 'Mesh',
        shortName: '',
        nodeId: 'deadbeef',
      );
      expect(device.displayName, 'beef');
    });

    test('toDeviceInfo creates correct DeviceInfo', () {
      final device = MdnsDeviceInfo(
        host: '192.168.1.42',
        port: 4403,
        serviceName: 'Meshtastic_test',
        shortName: '0864',
        nodeId: '08640864',
      );

      final info = device.toDeviceInfo();
      expect(info.id, 'tcp:192.168.1.42:4403');
      expect(info.name, '0864_0864');
      expect(info.type, TransportType.network);
      expect(info.address, '192.168.1.42:4403');
    });

    test('toDeviceInfo uses default port when port is 0', () {
      final device = MdnsDeviceInfo(
        host: '192.168.1.42',
        port: kMeshtasticDefaultPort,
        serviceName: 'Meshtastic_test',
      );

      final info = device.toDeviceInfo();
      expect(info.address, '192.168.1.42:$kMeshtasticDefaultPort');
    });

    test('equality is based on host and port', () {
      final a = MdnsDeviceInfo(
        host: '192.168.1.100',
        port: 4403,
        serviceName: 'Service_A',
        shortName: 'A',
      );
      final b = MdnsDeviceInfo(
        host: '192.168.1.100',
        port: 4403,
        serviceName: 'Service_B',
        shortName: 'B',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality with different host', () {
      final a = MdnsDeviceInfo(
        host: '192.168.1.100',
        port: 4403,
        serviceName: 'Test',
      );
      final b = MdnsDeviceInfo(
        host: '192.168.1.101',
        port: 4403,
        serviceName: 'Test',
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality with different port', () {
      final a = MdnsDeviceInfo(
        host: '192.168.1.100',
        port: 4403,
        serviceName: 'Test',
      );
      final b = MdnsDeviceInfo(
        host: '192.168.1.100',
        port: 4404,
        serviceName: 'Test',
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('MeshtasticMdnsDiscovery', () {
    test('initial state is not discovering', () {
      final discovery = MeshtasticMdnsDiscovery();
      expect(discovery.isDiscovering, isFalse);
      expect(discovery.currentDevices, isEmpty);
    });
  });
}
