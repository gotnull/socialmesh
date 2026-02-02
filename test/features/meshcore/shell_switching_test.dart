// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/models/mesh_device.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/connection_coordinator.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Shell switching via LinkStatus', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('disconnected state defaults to unknown protocol', () async {
      final s = SettingsService();
      await s.init();

      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWithValue(AsyncValue.data(s)),
        ],
      );
      addTearDown(container.dispose);

      final linkStatus = container.read(linkStatusProvider);
      expect(linkStatus.status, equals(LinkConnectionStatus.disconnected));
    });

    test('saved device protocol affects disconnected state', () async {
      SharedPreferences.setMockInitialValues({
        'last_device_id': 'device-123',
        'last_device_name': 'TestMeshCore',
        'last_device_protocol': 'meshcore',
      });

      final s = SettingsService();
      await s.init();

      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWithValue(AsyncValue.data(s)),
        ],
      );
      addTearDown(container.dispose);

      final linkStatus = container.read(linkStatusProvider);
      expect(linkStatus.protocol, equals(LinkProtocol.meshcore));
      expect(linkStatus.status, equals(LinkConnectionStatus.disconnected));
      expect(linkStatus.deviceName, equals('TestMeshCore'));
    });

    test('MeshCore coordinator connected sets MeshCore protocol', () async {
      final s = SettingsService();
      await s.init();

      // Create a coordinator that reports connected
      final coordinator = _MockConnectedCoordinator();

      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWithValue(AsyncValue.data(s)),
          connectionCoordinatorProvider.overrideWithValue(coordinator),
        ],
      );
      addTearDown(container.dispose);

      final linkStatus = container.read(linkStatusProvider);
      expect(linkStatus.protocol, equals(LinkProtocol.meshcore));
      expect(linkStatus.status, equals(LinkConnectionStatus.connected));
      expect(linkStatus.isMeshCore, isTrue);
      expect(linkStatus.isMeshtastic, isFalse);
    });

    test('LinkStatus helper properties work correctly', () async {
      SharedPreferences.setMockInitialValues({
        'last_device_id': 'meshtastic-node',
        'last_device_protocol': 'meshtastic',
      });

      final s = SettingsService();
      await s.init();

      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWithValue(AsyncValue.data(s)),
        ],
      );
      addTearDown(container.dispose);

      final linkStatus = container.read(linkStatusProvider);
      expect(linkStatus.isMeshtastic, isTrue);
      expect(linkStatus.isMeshCore, isFalse);
      expect(linkStatus.isDisconnected, isTrue);
      expect(linkStatus.isConnected, isFalse);
      expect(linkStatus.isConnecting, isFalse);
    });
  });

  group('MeshCore protocol detection', () {
    test('meshProtocolTypeProvider returns unknown when disconnected', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final protocolType = container.read(meshProtocolTypeProvider);
      expect(protocolType, equals(MeshProtocolType.unknown));
    });

    test('meshDeviceInfoProvider returns null when disconnected', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final deviceInfo = container.read(meshDeviceInfoProvider);
      expect(deviceInfo, isNull);
    });

    test('meshCoreAdapterProvider returns null when disconnected', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final adapter = container.read(meshCoreAdapterProvider);
      expect(adapter, isNull);
    });

    test('meshCoreSessionProvider returns null when disconnected', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final session = container.read(meshCoreSessionProvider);
      expect(session, isNull);
    });
  });

  group('Device persistence', () {
    test('SettingsService persists device info', () async {
      SharedPreferences.setMockInitialValues({});
      final s = SettingsService();
      await s.init();

      await s.setLastDevice(
        'meshcore-device-1',
        'ble',
        deviceName: 'MyCoreNode',
        protocol: 'meshcore',
      );

      expect(s.lastDeviceId, equals('meshcore-device-1'));
      expect(s.lastDeviceName, equals('MyCoreNode'));
      expect(s.lastDeviceType, equals('ble'));
      expect(s.lastDeviceProtocol, equals('meshcore'));
    });

    test('SettingsService clears device info', () async {
      SharedPreferences.setMockInitialValues({
        'last_device_id': 'existing-device',
        'last_device_name': 'ExistingNode',
        'last_device_type': 'ble',
        'last_device_protocol': 'meshcore',
      });
      final s = SettingsService();
      await s.init();

      await s.clearLastDevice();

      expect(s.lastDeviceId, isNull);
      expect(s.lastDeviceName, isNull);
      expect(s.lastDeviceType, isNull);
      expect(s.lastDeviceProtocol, isNull);
    });

    test('SettingsService loads persisted device on init', () async {
      SharedPreferences.setMockInitialValues({
        'last_device_id': 'persisted-device',
        'last_device_name': 'PersistedNode',
        'last_device_type': 'usb',
        'last_device_protocol': 'meshtastic',
      });
      final s = SettingsService();
      await s.init();

      expect(s.lastDeviceId, equals('persisted-device'));
      expect(s.lastDeviceName, equals('PersistedNode'));
      expect(s.lastDeviceType, equals('usb'));
      expect(s.lastDeviceProtocol, equals('meshtastic'));
    });
  });
}

/// Mock coordinator that simulates connected state.
class _MockConnectedCoordinator implements ConnectionCoordinator {
  @override
  bool get isConnected => true;

  @override
  bool get isConnecting => false;

  @override
  MeshDeviceInfo? get deviceInfo => MeshDeviceInfo(
    protocolType: MeshProtocolType.meshcore,
    displayName: 'MockMeshCore',
    nodeId: 'DEADBEEF',
    firmwareVersion: '1.0.0',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
