// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The first connect to a radio opens a provisional scope, then promotes it
// to the radio's own scope once the radio identifies. Promotion closes every
// open store. The node list the radio sends after that must still land in
// the radio's node store.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/radio_scope.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

class _SilentTransport extends DeviceTransport {
  @override
  TransportType get type => TransportType.network;
  @override
  bool get requiresFraming => false;
  @override
  bool get requiresWakeSequence => false;
  @override
  TransportReconnectMode get reconnectMode =>
      TransportReconnectMode.directEndpoint;
  @override
  DeviceConnectionState get state => DeviceConnectionState.connected;
  @override
  bool get isConnected => true;
  @override
  Stream<DeviceConnectionState> get stateStream => const Stream.empty();
  @override
  Stream<List<int>> get dataStream => const Stream.empty();
  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();
  @override
  Future<void> connect(DeviceInfo device) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> enableNotifications() async {}
  @override
  Future<void> pollOnce() async {}
  @override
  Future<void> send(List<int> data) async {}
  @override
  Future<int?> readRssi() async => null;
  @override
  Future<void> dispose() async {}
}

const _radio = 0xabcd2005;
const _endpoint = 'tcp:192.0.2.10:4403';

Future<(ProviderContainer, ProtocolService)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final root = await Directory.systemTemp.createTemp('first_connect_');
  addTearDown(() async {
    RadioScope.instance.debugSetRoot(null);
    await root.delete(recursive: true);
  });
  RadioScope.instance.debugSetRoot(root);
  await RadioScope.instance.init();

  final settings = SettingsService();
  await settings.init();
  final protocol = ProtocolService(_SilentTransport());
  final container = ProviderContainer(
    overrides: [
      protocolServiceProvider.overrideWithValue(protocol),
      settingsServiceProvider.overrideWithValue(AsyncValue.data(settings)),
      deviceFavoritesProvider.overrideWith((ref) async {
        final service = DeviceFavoritesService();
        await service.init();
        return service;
      }),
    ],
  );
  addTearDown(container.dispose);
  container.listen(nodesProvider, (_, _) {});
  return (container, protocol);
}

Future<void> _identify(ProtocolService protocol, int nodeNum) =>
    protocol.handleIncomingPacket(
      pb.FromRadio(myInfo: pb.MyNodeInfo(myNodeNum: nodeNum)).writeToBuffer(),
    );

Future<void> _nodeInfo(ProtocolService protocol, int nodeNum) =>
    protocol.handleIncomingPacket(
      pb.FromRadio(
        nodeInfo: pb.NodeInfo(
          num: nodeNum,
          user: pb.User(
            id: '!${nodeNum.toRadixString(16)}',
            longName: 'Load Node $nodeNum',
            shortName: 'L${nodeNum % 1000}',
          ),
        ),
      ).writeToBuffer(),
    );

Future<List<MeshNode>> _storedInCurrentScope() async {
  final store = NodeStorageService();
  await store.init();
  final nodes = await store.loadNodes();
  await store.close();
  return nodes;
}

// Past the node save debounce.
const _afterSave = Duration(seconds: 3);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nodes sent while a first connect promotes the provisional scope '
      "are saved in the radio's scope", () async {
    final (container, protocol) = await _boot();

    // Connect path: a provisional scope for an endpoint never seen before.
    await RadioScope.instance.useDevice(deviceId: _endpoint);
    expect(isProvisionalRadioScopeKey(RadioScope.instance.currentKey), isTrue);
    await container.read(nodeStorageProvider.future);

    // The radio identifies and its node database replay follows straight
    // away, while the provisional scope is still being promoted.
    await _identify(protocol, _radio);
    final promotion = RadioScope.instance.useNodeNum(
      _radio,
      deviceId: _endpoint,
    );
    const count = 300;
    for (var i = 1; i <= count; i++) {
      if (i == count ~/ 2) await promotion;
      await _nodeInfo(protocol, 0x10000 + i);
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(container.read(nodesProvider), hasLength(count));

    await Future<void>.delayed(_afterSave);
    expect(RadioScope.instance.currentKey, radioScopeKeyForNodeNum(_radio));
    expect(await _storedInCurrentScope(), hasLength(count));
  });

  test("another radio's nodes still held by the protocol are not saved "
      'into the scope the session moved to', () async {
    final (container, protocol) = await _boot();
    const other = 0xabcd2006;

    await RadioScope.instance.useNodeNum(_radio);
    await container.read(nodeStorageProvider.future);
    await _identify(protocol, _radio);
    for (var i = 1; i <= 20; i++) {
      await _nodeInfo(protocol, 0x20000 + i);
    }
    await Future<void>.delayed(_afterSave);

    // The session binds to a different radio before the protocol has
    // started its connection, so it still holds the first radio's nodes.
    await RadioScope.instance.useNodeNum(other);
    await container.read(nodeStorageProvider.future);
    await Future<void>.delayed(_afterSave);

    expect(RadioScope.instance.currentKey, radioScopeKeyForNodeNum(other));
    expect(await _storedInCurrentScope(), isEmpty);
  });
}
