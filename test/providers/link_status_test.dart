// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/providers/app_providers.dart';

void main() {
  group('LinkStatus', () {
    test('disconnected constant has correct values', () {
      const status = LinkStatus.disconnected;
      expect(status.protocol, LinkProtocol.unknown);
      expect(status.status, LinkConnectionStatus.disconnected);
      expect(status.deviceName, isNull);
      expect(status.deviceId, isNull);
    });

    test('isConnected returns true only when status is connected', () {
      const connected = LinkStatus(
        protocol: LinkProtocol.meshtastic,
        status: LinkConnectionStatus.connected,
      );
      const connecting = LinkStatus(
        protocol: LinkProtocol.meshtastic,
        status: LinkConnectionStatus.connecting,
      );
      const disconnected = LinkStatus(
        protocol: LinkProtocol.meshtastic,
        status: LinkConnectionStatus.disconnected,
      );

      expect(connected.isConnected, true);
      expect(connecting.isConnected, false);
      expect(disconnected.isConnected, false);
    });

    test('isConnecting returns true only when status is connecting', () {
      const connected = LinkStatus(
        protocol: LinkProtocol.meshtastic,
        status: LinkConnectionStatus.connected,
      );
      const connecting = LinkStatus(
        protocol: LinkProtocol.meshtastic,
        status: LinkConnectionStatus.connecting,
      );
      const disconnected = LinkStatus(
        protocol: LinkProtocol.meshtastic,
        status: LinkConnectionStatus.disconnected,
      );

      expect(connected.isConnecting, false);
      expect(connecting.isConnecting, true);
      expect(disconnected.isConnecting, false);
    });

    test('isDisconnected returns true only when status is disconnected', () {
      const connected = LinkStatus(
        protocol: LinkProtocol.meshtastic,
        status: LinkConnectionStatus.connected,
      );
      const connecting = LinkStatus(
        protocol: LinkProtocol.meshtastic,
        status: LinkConnectionStatus.connecting,
      );
      const disconnected = LinkStatus(
        protocol: LinkProtocol.meshtastic,
        status: LinkConnectionStatus.disconnected,
      );

      expect(connected.isDisconnected, false);
      expect(connecting.isDisconnected, false);
      expect(disconnected.isDisconnected, true);
    });

    test('isMeshCore returns true only for meshcore protocol', () {
      const meshcore = LinkStatus(
        protocol: LinkProtocol.meshcore,
        status: LinkConnectionStatus.connected,
      );
      const meshtastic = LinkStatus(
        protocol: LinkProtocol.meshtastic,
        status: LinkConnectionStatus.connected,
      );
      const unknown = LinkStatus(
        protocol: LinkProtocol.unknown,
        status: LinkConnectionStatus.disconnected,
      );

      expect(meshcore.isMeshCore, true);
      expect(meshtastic.isMeshCore, false);
      expect(unknown.isMeshCore, false);
    });

    test('isMeshtastic returns true only for meshtastic protocol', () {
      const meshcore = LinkStatus(
        protocol: LinkProtocol.meshcore,
        status: LinkConnectionStatus.connected,
      );
      const meshtastic = LinkStatus(
        protocol: LinkProtocol.meshtastic,
        status: LinkConnectionStatus.connected,
      );
      const unknown = LinkStatus(
        protocol: LinkProtocol.unknown,
        status: LinkConnectionStatus.disconnected,
      );

      expect(meshcore.isMeshtastic, false);
      expect(meshtastic.isMeshtastic, true);
      expect(unknown.isMeshtastic, false);
    });

    test('toString returns readable representation', () {
      const status = LinkStatus(
        protocol: LinkProtocol.meshtastic,
        status: LinkConnectionStatus.connected,
        deviceName: 'Test Device',
      );

      expect(
        status.toString(),
        'LinkStatus(protocol: LinkProtocol.meshtastic, status: LinkConnectionStatus.connected, device: Test Device)',
      );
    });
  });

  group('ProtocolCapabilities', () {
    test('meshtastic has full Meshtastic capabilities', () {
      const caps = ProtocolCapabilities.meshtastic;
      // Core Meshtastic features
      expect(caps.supportsNodes, true);
      expect(caps.supportsChannels, true);
      expect(caps.supportsMap, true);
      expect(caps.supportsMessaging, true);
      expect(caps.supportsTelemetry, true);
      expect(caps.supportsDeviceConfig, true);
      // MeshCore-specific features disabled
      expect(caps.supportsMeshCoreContacts, false);
      expect(caps.supportsMeshCoreChannels, false);
      expect(caps.supportsContactCodes, false);
      expect(caps.supportsContactDiscovery, false);
      expect(caps.supportsTracePath, false);
      expect(caps.supportsRxLog, false);
      expect(caps.supportsNoiseFloor, false);
      // Protocol detection helpers
      expect(caps.isMeshtastic, true);
      expect(caps.isMeshCore, false);
    });

    test('meshcore has MeshCore-specific capabilities', () {
      const caps = ProtocolCapabilities.meshcore;
      // MeshCore-specific features enabled
      expect(caps.supportsMeshCoreContacts, true);
      expect(caps.supportsMeshCoreChannels, true);
      expect(caps.supportsContactCodes, true);
      expect(caps.supportsContactDiscovery, true);
      expect(caps.supportsTracePath, true);
      expect(caps.supportsRxLog, true);
      expect(caps.supportsNoiseFloor, true);
      expect(caps.supportsNearbyNodeDiscovery, true);
      expect(caps.supportsAntennaCoverage, true);
      expect(caps.supportsLineOfSight, true);
      expect(caps.supportsMap, true);
      expect(caps.supportsMessaging, true);
      // Meshtastic-specific features disabled
      expect(caps.supportsNodes, false);
      expect(caps.supportsChannels, false);
      expect(caps.supportsTelemetry, false);
      expect(caps.supportsDeviceConfig, false);
      // Protocol detection helpers
      expect(caps.isMeshtastic, false);
      expect(caps.isMeshCore, true);
    });

    test('none has no capabilities', () {
      const caps = ProtocolCapabilities.none;
      expect(caps.supportsNodes, false);
      expect(caps.supportsChannels, false);
      expect(caps.supportsMap, false);
      expect(caps.supportsMeshCoreContacts, false);
      expect(caps.supportsMeshCoreChannels, false);
      expect(caps.supportsMessaging, false);
      expect(caps.supportsTelemetry, false);
      expect(caps.supportsDeviceConfig, false);
      expect(caps.supportsContactCodes, false);
      expect(caps.supportsContactDiscovery, false);
      expect(caps.supportsTracePath, false);
      expect(caps.supportsRxLog, false);
      expect(caps.supportsNoiseFloor, false);
      expect(caps.supportsNearbyNodeDiscovery, false);
      // Protocol detection helpers
      expect(caps.isMeshtastic, false);
      expect(caps.isMeshCore, false);
    });
  });

  group('LinkConnectionStatus', () {
    test('has all required values', () {
      expect(LinkConnectionStatus.values, [
        LinkConnectionStatus.disconnected,
        LinkConnectionStatus.connecting,
        LinkConnectionStatus.connected,
      ]);
    });
  });

  group('LinkProtocol', () {
    test('has all required values', () {
      expect(LinkProtocol.values, [
        LinkProtocol.unknown,
        LinkProtocol.meshtastic,
        LinkProtocol.meshcore,
      ]);
    });
  });

  group('ActiveProtocol', () {
    test('has all required values', () {
      expect(ActiveProtocol.values, [
        ActiveProtocol.none,
        ActiveProtocol.meshtastic,
        ActiveProtocol.meshcore,
      ]);
    });

    test('values map to shell routing decisions', () {
      // none -> MainShell (for scanner access)
      // meshtastic -> MainShell
      // meshcore -> MeshCoreShell
      expect(ActiveProtocol.none.name, 'none');
      expect(ActiveProtocol.meshtastic.name, 'meshtastic');
      expect(ActiveProtocol.meshcore.name, 'meshcore');
    });
  });
}
