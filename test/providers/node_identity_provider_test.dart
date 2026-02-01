import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/storage_service.dart';
import 'package:socialmesh/services/nodes/node_identity_store.dart';

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
  test('nodesProvider applies identity updates from store', () async {
    SharedPreferences.setMockInitialValues({});

    final protocol = ProtocolService(_FakeTransport());

    final container = ProviderContainer(
      overrides: [
        protocolServiceProvider.overrideWithValue(protocol),
        nodeStorageProvider.overrideWith((ref) async {
          final service = NodeStorageService();
          await service.init();
          return service;
        }),
        deviceFavoritesProvider.overrideWith((ref) async {
          final service = DeviceFavoritesService();
          await service.init();
          return service;
        }),
        nodeIdentityStoreProvider.overrideWith((ref) async {
          final store = NodeIdentityStore();
          await store.init();
          return store;
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(nodeStorageProvider.future);
    await container.read(deviceFavoritesProvider.future);
    await container.read(nodeIdentityStoreProvider.future);

    final nodesNotifier = container.read(nodesProvider.notifier);
    nodesNotifier.addOrUpdateNode(MeshNode(nodeNum: 0x5ed6));

    final before = container.read(nodesProvider)[0x5ed6]!;
    expect(before.displayName, isNot('Wismesh'));

    await container
        .read(nodeIdentityProvider.notifier)
        .upsertIdentity(
          nodeNum: 0x5ed6,
          longName: 'Wismesh',
          shortName: '5ed6',
          updatedAtMs: DateTime(2026, 1, 1).millisecondsSinceEpoch,
        );

    await Future<void>.delayed(Duration.zero);

    final after = container.read(nodesProvider)[0x5ed6]!;
    expect(after.longName, 'Wismesh');
    expect(after.displayName, 'Wismesh');
  });
}
