import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/nodes/node_identity_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

class _FakeTransport implements DeviceTransport {
  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  DeviceConnectionState get state => DeviceConnectionState.disconnected;

  @override
  bool get isConnected => false;

  @override
  Stream<DeviceConnectionState> get stateStream => const Stream.empty();

  @override
  Stream<List<int>> get dataStream => const Stream.empty();

  @override
  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();

  @override
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  String? get bleModelNumber => null;

  @override
  String? get bleManufacturerName => null;

  @override
  Future<void> dispose() async {}
}

void main() {
  test(
    'nodesProvider merges cached identity when shortName is BLE default',
    () async {
      SharedPreferences.setMockInitialValues({});

      final storage = NodeStorageService();
      await storage.init();
      await storage.saveNode(
        MeshNode(nodeNum: 0x5ed6, shortName: 'Meshtastic_5ed6'),
      );

      final identityStore = NodeIdentityStore();
      await identityStore.init();

      final protocol = ProtocolService(_FakeTransport());

      final container = ProviderContainer(
        overrides: [
          protocolServiceProvider.overrideWithValue(protocol),
          nodeStorageProvider.overrideWith((ref) async => storage),
          deviceFavoritesProvider.overrideWith((ref) async {
            final service = DeviceFavoritesService();
            await service.init();
            return service;
          }),
          nodeIdentityStoreProvider.overrideWith((ref) async => identityStore),
        ],
      );
      addTearDown(container.dispose);

      await container.read(nodeStorageProvider.future);
      await container.read(deviceFavoritesProvider.future);
      await container.read(nodeIdentityStoreProvider.future);

      container.read(nodesProvider);
      await container
          .read(nodeIdentityProvider.notifier)
          .upsertIdentity(
            nodeNum: 0x5ed6,
            longName: 'Wismesh Relay',
            shortName: 'WISM',
            updatedAtMs: 1710000000000,
            lastSeenAtMs: 1710000001000,
          );
      await Future<void>.delayed(Duration.zero);

      final node = container.read(nodesProvider)[0x5ed6];
      expect(node, isNotNull);
      expect(node?.longName, 'Wismesh Relay');
      expect(node?.shortName, 'WISM');
      expect(node?.displayName, 'Wismesh Relay');
    },
  );

  test('nodesProvider strips BLE default names when identity missing', () async {
    SharedPreferences.setMockInitialValues({});

    final storage = NodeStorageService();
    await storage.init();
    await storage.saveNode(
      MeshNode(nodeNum: 0x5ed6, shortName: 'Meshtastic_5ed6'),
    );

    final identityStore = NodeIdentityStore();
    await identityStore.init();

    final protocol = ProtocolService(_FakeTransport());

    final container = ProviderContainer(
      overrides: [
        protocolServiceProvider.overrideWithValue(protocol),
        nodeStorageProvider.overrideWith((ref) async => storage),
        deviceFavoritesProvider.overrideWith((ref) async {
          final service = DeviceFavoritesService();
          await service.init();
          return service;
        }),
        nodeIdentityStoreProvider.overrideWith((ref) async => identityStore),
      ],
    );
    addTearDown(container.dispose);

    await container.read(nodeStorageProvider.future);
    await container.read(deviceFavoritesProvider.future);
    await container.read(nodeIdentityStoreProvider.future);

    container.read(nodesProvider);
    // Allow multiple event loop iterations for async _init to complete
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final node = container.read(nodesProvider)[0x5ed6];
    expect(node, isNotNull);
    // BLE default name should be stripped (null), falling back to friendly "Node X" format
    expect(node?.longName, isNull);
    expect(node?.shortName, isNull);
    expect(node?.displayName, 'Node ${0x5ed6}'); // "Node 24278"
  });
}
