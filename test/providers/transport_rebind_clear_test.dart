// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression test for RC-TRANSPORT-REBIND: when an ESP32 / nRF Meshtastic
// radio rotates its BLE peripheral UUID between sessions, the app must
// NOT wipe the cached NodeDB. The previous implementation compared only
// raw BLE UUIDs and forced `clearNodeData = true` on any mismatch,
// destroying the user's own-node metadata (long name / short name)
// whenever the UUID changed — even though the physical radio was the
// same.
//
// The fix adds an `isTransportRebind` signal to both
// `clearDeviceDataBeforeConnect` and `clearDeviceDataBeforeConnectRef`
// that suppresses the auto-clear when the caller has confirmed
// (via `isLogicalTransportRebind`) that the new BLE UUID belongs to the
// same physical radio.
//
// These tests pin the suppression behaviour end-to-end: given a rebind,
// the in-memory NodesNotifier must retain its existing nodes.
//
// Since storage became radio-scoped, the connect path no longer deletes
// persisted stores at all — a true switch resets the in-memory view and
// leaves the previous radio's cache in its own scope. The persisted
// assertions here pin that: preserved on rebind AND on switch, for
// different reasons.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/telemetry_providers.dart';
import 'package:socialmesh/services/nodes/node_identity_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/route_storage_service.dart';
import 'package:socialmesh/services/storage/storage_service.dart';
import 'package:socialmesh/services/storage/telemetry_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _dbSeq = 0;
final int _testPid = pid;

String _tempPath(String label) {
  final dir = Directory.systemTemp.path;
  return p.join(dir, '${label}_${_testPid}_${_dbSeq++}.db');
}

class _FakeTransport implements DeviceTransport {
  @override
  TransportType get type => TransportType.ble;
  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;
  @override
  DeviceConnectionState get state => DeviceConnectionState.disconnected;
  @override
  bool get isConnected => false;
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
  Future<void> send(List<int> data) async {}
  @override
  Future<void> refreshNotifications() async {}
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

MeshNode _node(int nodeNum, {String? longName}) {
  return MeshNode(
    nodeNum: nodeNum,
    longName: longName ?? 'Node_${nodeNum.toRadixString(16)}',
    lastHeard: DateTime.now(),
  );
}

typedef _ClearArgs = ({
  String? prev,
  String? next,
  bool rebind,
  bool clearNode,
});

// Thin adapter so the test can invoke [clearDeviceDataBeforeConnectRef]
// with a real Riverpod [Ref]. A Notifier.method call runs AFTER build(),
// so modifying other providers (which clearDeviceDataBeforeConnectRef
// does via channelsProvider / nodesProvider) is permitted — unlike a
// FutureProvider body, whose async work still counts as initialization.
class _ClearRunner extends Notifier<void> {
  @override
  void build() {}

  Future<void> run(_ClearArgs a) => clearDeviceDataBeforeConnectRef(
    ref,
    clearNodeData: a.clearNode,
    previousDeviceId: a.prev,
    newDeviceId: a.next,
    isTransportRebind: a.rebind,
  );
}

final _clearRunnerProvider = NotifierProvider<_ClearRunner, void>(
  _ClearRunner.new,
);

class _Harness {
  _Harness({
    required this.container,
    required this.nodeStorage,
    required this.settings,
  });

  final ProviderContainer container;
  final NodeStorageService nodeStorage;
  final SettingsService settings;
}

Future<_Harness> _makeHarness({int? lastMyNodeNum}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService();
  await settings.init();
  if (lastMyNodeNum != null) {
    await settings.setLastMyNodeNum(lastMyNodeNum);
  }

  final nodeStorage = NodeStorageService();
  await nodeStorage.init();

  final telemetryStorage = TelemetryDatabase(testDbPath: _tempPath('telem'));
  await telemetryStorage.init();

  final routeStorage = RouteStorageService(testDbPath: inMemoryDatabasePath);
  await routeStorage.init();

  final identityStore = NodeIdentityStore();
  await identityStore.init();

  final container = ProviderContainer(
    overrides: [
      protocolServiceProvider.overrideWithValue(
        ProtocolService(_FakeTransport()),
      ),
      settingsServiceProvider.overrideWithValue(AsyncValue.data(settings)),
      nodeStorageProvider.overrideWith((ref) async => nodeStorage),
      telemetryStorageProvider.overrideWith((ref) async => telemetryStorage),
      routeStorageProvider.overrideWith((ref) async => routeStorage),
      nodeIdentityStoreProvider.overrideWith((ref) async => identityStore),
      deviceFavoritesProvider.overrideWith((ref) async {
        final service = DeviceFavoritesService();
        await service.init();
        return service;
      }),
    ],
  );
  await container.read(nodeStorageProvider.future);
  await container.read(telemetryStorageProvider.future);
  await container.read(routeStorageProvider.future);
  await container.read(nodeIdentityStoreProvider.future);
  await container.read(deviceFavoritesProvider.future);

  return _Harness(
    container: container,
    nodeStorage: nodeStorage,
    settings: settings,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('clearDeviceDataBeforeConnectRef — transport rebind suppression', () {
    test(
      'rebind: isTransportRebind=true preserves cached nodes even when UUIDs differ',
      () async {
        final h = await _makeHarness(lastMyNodeNum: 0x1234abcd);
        addTearDown(h.container.dispose);

        await h.nodeStorage.saveNodes([_node(1), _node(2), _node(3)]);
        // Warm the in-memory NodesNotifier from storage.
        h.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(h.container.read(nodesProvider).length, 3);

        // BLE UUID rotated from ...:01 to ...:02, same physical radio.
        await h.container.read(_clearRunnerProvider.notifier).run((
          prev: 'AA:BB:CC:DD:EE:01',
          next: 'AA:BB:CC:DD:EE:02',
          rebind: true,
          clearNode: false,
        ));

        expect(
          h.container.read(nodesProvider).length,
          3,
          reason: 'Transport rebind must preserve in-memory nodes',
        );
        final stored = await h.nodeStorage.loadNodes();
        expect(
          stored,
          hasLength(3),
          reason: 'Transport rebind must preserve persisted nodes',
        );
      },
    );

    test(
      'true switch: UUIDs differ + isTransportRebind=false resets the '
      'in-memory view and leaves the previous radio\'s cache in its scope',
      () async {
        final h = await _makeHarness(lastMyNodeNum: 0x1234abcd);
        addTearDown(h.container.dispose);

        await h.nodeStorage.saveNodes([_node(1), _node(2), _node(3)]);
        h.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(h.container.read(nodesProvider).length, 3);

        await h.container.read(_clearRunnerProvider.notifier).run((
          prev: 'AA:BB:CC:DD:EE:01',
          next: 'AA:BB:CC:DD:EE:99', // truly different radio
          rebind: false,
          clearNode: false,
        ));

        expect(
          h.container.read(nodesProvider).length,
          0,
          reason: 'True device switch must reset the in-memory node map',
        );
        final stored = await h.nodeStorage.loadNodes();
        expect(
          stored,
          hasLength(3),
          reason:
              'The persisted cache belongs to the previous radio and stays in '
              'its own storage scope — the switch swaps datasets rather than '
              'deleting one',
        );
      },
    );

    test(
      'same UUID reconnect preserves nodes (no switch, no rebind)',
      () async {
        final h = await _makeHarness();
        addTearDown(h.container.dispose);

        await h.nodeStorage.saveNodes([_node(1), _node(2), _node(3)]);
        h.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(h.container.read(nodesProvider).length, 3);

        await h.container.read(_clearRunnerProvider.notifier).run((
          prev: 'AA:BB:CC:DD:EE:01',
          next: 'AA:BB:CC:DD:EE:01',
          rebind: false,
          clearNode: false,
        ));

        expect(h.container.read(nodesProvider).length, 3);
        expect(await h.nodeStorage.loadNodes(), hasLength(3));
      },
    );

    test(
      'repeated rebind cycles never wipe (protects against thrashing UUIDs)',
      () async {
        final h = await _makeHarness(lastMyNodeNum: 0x1234abcd);
        addTearDown(h.container.dispose);

        await h.nodeStorage.saveNodes([_node(1), _node(2), _node(3)]);
        h.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(h.container.read(nodesProvider).length, 3);

        for (final (prev, next) in [
          ('AA:BB:CC:DD:EE:01', 'AA:BB:CC:DD:EE:02'),
          ('AA:BB:CC:DD:EE:02', 'AA:BB:CC:DD:EE:03'),
          ('AA:BB:CC:DD:EE:03', 'AA:BB:CC:DD:EE:04'),
        ]) {
          await h.container.read(_clearRunnerProvider.notifier).run((
            prev: prev,
            next: next,
            rebind: true,
            clearNode: false,
          ));
        }

        expect(
          h.container.read(nodesProvider).length,
          3,
          reason: 'Successive rebinds must never wipe nodes',
        );
        expect(await h.nodeStorage.loadNodes(), hasLength(3));
      },
    );
  });
}
