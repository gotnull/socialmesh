import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
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
  Stream<DeviceInfo> scan({Duration? timeout}) => const Stream.empty();

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
  test('FromRadio nodeInfo updates nodesProvider and identity store', () async {
    SharedPreferences.setMockInitialValues({});

    final storage = NodeStorageService();
    await storage.init();

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
    protocol.onIdentityUpdate =
        ({
          required int nodeNum,
          String? longName,
          String? shortName,
          int? lastSeenAtMs,
        }) {
          container
              .read(nodeIdentityProvider.notifier)
              .upsertIdentity(
                nodeNum: nodeNum,
                longName: longName,
                shortName: shortName,
                updatedAtMs: DateTime.now().millisecondsSinceEpoch,
                lastSeenAtMs: lastSeenAtMs,
              );
        };
    await Future<void>.delayed(Duration.zero);

    final fromRadio = pb.FromRadio(
      nodeInfo: pb.NodeInfo(
        num: 0x5ed6,
        user: pb.User()
          ..longName = 'Wismesh'
          ..shortName = '5ed6',
      ),
    );

    await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
    await Future<void>.delayed(Duration.zero);

    final node = container.read(nodesProvider)[0x5ed6];
    expect(node, isNotNull);
    expect(node?.displayName, 'Wismesh');

    final identities = await identityStore.getAllIdentities();
    expect(identities[0x5ed6]?.longName, 'Wismesh');
  });
}
