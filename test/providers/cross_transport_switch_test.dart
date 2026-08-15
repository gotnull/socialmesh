// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Integration pins for RC-CROSS-TRANSPORT: end-to-end behaviour of
// [prepareForDeviceTransitionRef] for every row of the preserve /
// clear / rehydrate matrix. The classifier already has unit tests in
// device_transition_classifier_test.dart — this file verifies that
// the helper actually writes through the correct side effects
// (settings.lastDevice, nodes state, nodes storage, transportType).
//
// Scenarios covered (specifically requested in the fix brief):
//   * TCP node A → disconnect → BLE node A (same logical radio,
//     different transport): preserve persisted cache, no destructive
//     clear, but force fresh hydration + transport family flip.
//   * TCP node A → disconnect → BLE node B (different logical
//     radio): destructive clear, no stale nodes carried over.
//   * Same-device reconnect is a no-op.
//   * NodesNotifier._init hydration race: a destructive clearNodes()
//     fired during an in-flight `_storage.loadNodes()` await must not
//     resurrect stale nodes when the await resolves.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/radio_scope.dart';
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

MeshNode _node(int nodeNum) => MeshNode(
  nodeNum: nodeNum,
  longName: 'Node_${nodeNum.toRadixString(16)}',
  lastHeard: DateTime.now(),
);

// Adapter to let the test invoke prepareForDeviceTransitionRef with a
// real Riverpod Ref. Runs in notifier method scope (post-build) so it
// is permitted to mutate other providers.
class _PrepareRunner extends Notifier<void> {
  @override
  void build() {}
  Future<ActiveDeviceTransition> run(DeviceInfo device) =>
      prepareForDeviceTransitionRef(
        ref,
        device: device,
        deviceProtocol: 'meshtastic',
      );
}

final _prepareRunnerProvider = NotifierProvider<_PrepareRunner, void>(
  _PrepareRunner.new,
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

Future<_Harness> _makeHarness({
  String? lastDeviceId,
  String? lastDeviceType,
  String? lastDeviceName,
  int? lastMyNodeNum,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService();
  await settings.init();
  if (lastDeviceId != null && lastDeviceType != null) {
    await settings.setLastDevice(
      lastDeviceId,
      lastDeviceType,
      deviceName: lastDeviceName,
      protocol: 'meshtastic',
    );
  }
  if (lastMyNodeNum != null) {
    await settings.setLastMyNodeNum(lastMyNodeNum);
  }

  // Boot the storage scope the way `main()` does, so the persisted node
  // cache these tests write lands in the scope of the radio the harness
  // says we were last connected to.
  final scopeRoot = await Directory.systemTemp.createTemp('cross_transport_');
  addTearDown(() async {
    RadioScope.instance.debugSetRoot(null);
    try {
      await scopeRoot.delete(recursive: true);
    } on FileSystemException {
      // Already gone.
    }
  });
  RadioScope.instance.debugSetRoot(scopeRoot);
  await RadioScope.instance.init();

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

  group('prepareForDeviceTransitionRef — cross-transport matrix', () {
    test(
      'TCP A → BLE A (same logical radio, cross-transport) preserves cache, '
      'forces fresh hydrate, flips transport type, persists new id',
      () async {
        final h = await _makeHarness(
          lastDeviceId: 'tcp:meshtastic_abcd.local:4403',
          lastDeviceType: 'network',
          lastDeviceName: 'Meshtastic_abcd',
          lastMyNodeNum: 0x1234abcd,
        );
        addTearDown(h.container.dispose);

        await h.nodeStorage.saveNodes([_node(1), _node(2), _node(3)]);
        h.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(h.container.read(nodesProvider).length, 3);

        final newDevice = DeviceInfo(
          id: 'AA:BB:CC:DD:EE:01',
          name: 'Meshtastic_abcd',
          type: TransportType.ble,
        );
        final transition = await h.container
            .read(_prepareRunnerProvider.notifier)
            .run(newDevice);

        expect(transition.kind, DeviceTransitionKind.sameRadioCrossTransport);
        expect(transition.clearNodes, isFalse);
        expect(transition.forceFreshHydration, isTrue);
        expect(transition.transportFamilyChanged, isTrue);

        // Persisted NodeDB is preserved — this is the key invariant
        // from the revised scenario D ruling.
        final stored = await h.nodeStorage.loadNodes();
        expect(
          stored,
          hasLength(3),
          reason:
              'Same-radio cross-transport must preserve the persisted NodeDB',
        );

        // New device identity is written so the next transition is
        // classified against the new baseline.
        expect(h.settings.lastDeviceId, 'AA:BB:CC:DD:EE:01');
        expect(h.settings.lastDeviceType, 'ble');

        // Transport family flipped to BLE so subsequent transportProvider
        // reads return a BleTransport.
        expect(
          h.container.read(transportTypeProvider),
          TransportType.ble,
          reason: 'transportTypeProvider must flip on family change',
        );
      },
    );

    test('TCP A → BLE B (different logical radio) is destructive — nodes and '
        'storage wiped, transport flipped, new id persisted', () async {
      final h = await _makeHarness(
        lastDeviceId: 'tcp:meshtastic_abcd.local:4403',
        lastDeviceType: 'network',
        lastDeviceName: 'Meshtastic_abcd',
        lastMyNodeNum: 0x1234abcd,
      );
      addTearDown(h.container.dispose);

      await h.nodeStorage.saveNodes([_node(1), _node(2), _node(3)]);
      h.container.read(nodesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(h.container.read(nodesProvider).length, 3);

      final newDevice = DeviceInfo(
        id: 'AA:BB:CC:DD:EE:99',
        name: 'Meshtastic_9999',
        type: TransportType.ble,
      );
      final transition = await h.container
          .read(_prepareRunnerProvider.notifier)
          .run(newDevice);

      expect(transition.kind, DeviceTransitionKind.deviceSwitch);
      expect(transition.clearNodes, isTrue);
      expect(transition.transportFamilyChanged, isTrue);

      expect(
        h.container.read(nodesProvider).length,
        0,
        reason:
            'Cross-transport device switch must wipe in-memory nodes so '
            'radio A stale cache does not leak into radio B session',
      );
      final stored = await h.nodeStorage.loadNodes();
      expect(stored, hasLength(0));

      expect(h.settings.lastDeviceId, 'AA:BB:CC:DD:EE:99');
      expect(h.settings.lastDeviceType, 'ble');
      expect(h.container.read(transportTypeProvider), TransportType.ble);
    });

    test(
      'BLE A → TCP B (different radio, cross-transport) is destructive',
      () async {
        final h = await _makeHarness(
          lastDeviceId: 'AA:BB:CC:DD:EE:01',
          lastDeviceType: 'ble',
          lastDeviceName: 'Meshtastic_abcd',
          lastMyNodeNum: 0x1234abcd,
        );
        addTearDown(h.container.dispose);

        await h.nodeStorage.saveNodes([_node(1), _node(2), _node(3)]);
        h.container.read(nodesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(h.container.read(nodesProvider).length, 3);

        final newDevice = DeviceInfo(
          id: 'tcp:10.0.0.42:4403',
          name: '10.0.0.42',
          type: TransportType.network,
        );
        final transition = await h.container
            .read(_prepareRunnerProvider.notifier)
            .run(newDevice);

        expect(transition.kind, DeviceTransitionKind.deviceSwitch);
        expect(transition.clearNodes, isTrue);
        expect(h.container.read(nodesProvider).length, 0);
        expect(await h.nodeStorage.loadNodes(), hasLength(0));
        expect(h.container.read(transportTypeProvider), TransportType.network);

        // Network host/port seeded so transportProvider rebuilds with the
        // right endpoint.
        expect(h.container.read(networkTransportHostProvider), '10.0.0.42');
        expect(h.container.read(networkTransportPortProvider), 4403);
      },
    );

    test('BLE A → BLE A (sameDevice) is a no-op — no clear, no persist churn, '
        'no transport flip', () async {
      final h = await _makeHarness(
        lastDeviceId: 'AA:BB:CC:DD:EE:01',
        lastDeviceType: 'ble',
        lastDeviceName: 'Meshtastic_abcd',
        lastMyNodeNum: 0x1234abcd,
      );
      addTearDown(h.container.dispose);

      await h.nodeStorage.saveNodes([_node(1), _node(2), _node(3)]);
      h.container.read(nodesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final newDevice = DeviceInfo(
        id: 'AA:BB:CC:DD:EE:01',
        name: 'Meshtastic_abcd',
        type: TransportType.ble,
      );
      final transition = await h.container
          .read(_prepareRunnerProvider.notifier)
          .run(newDevice);

      expect(transition.kind, DeviceTransitionKind.sameDevice);
      expect(transition.clearNodes, isFalse);
      expect(transition.transportFamilyChanged, isFalse);

      expect(h.container.read(nodesProvider).length, 3);
      expect(await h.nodeStorage.loadNodes(), hasLength(3));
    });

    test('transportRebind (BLE UUID rotated, same family) preserves cache and '
        'updates lastDeviceId to new UUID', () async {
      final h = await _makeHarness(
        lastDeviceId: 'AA:BB:CC:DD:EE:01',
        lastDeviceType: 'ble',
        lastDeviceName: 'Meshtastic_abcd',
        lastMyNodeNum: 0x1234abcd,
      );
      addTearDown(h.container.dispose);

      await h.nodeStorage.saveNodes([_node(1), _node(2), _node(3)]);
      h.container.read(nodesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final newDevice = DeviceInfo(
        id: 'AA:BB:CC:DD:EE:02',
        name: 'Meshtastic_abcd',
        type: TransportType.ble,
      );
      final transition = await h.container
          .read(_prepareRunnerProvider.notifier)
          .run(newDevice);

      expect(transition.kind, DeviceTransitionKind.transportRebind);
      expect(transition.clearNodes, isFalse);
      expect(transition.forceFreshHydration, isFalse);
      expect(transition.transportFamilyChanged, isFalse);

      expect(h.container.read(nodesProvider).length, 3);
      expect(await h.nodeStorage.loadNodes(), hasLength(3));
      expect(h.settings.lastDeviceId, 'AA:BB:CC:DD:EE:02');
    });

    test('firstEver connect: no clear, persisted id is new device', () async {
      final h = await _makeHarness();
      addTearDown(h.container.dispose);

      final newDevice = DeviceInfo(
        id: 'AA:BB:CC:DD:EE:01',
        name: 'Meshtastic_abcd',
        type: TransportType.ble,
      );
      final transition = await h.container
          .read(_prepareRunnerProvider.notifier)
          .run(newDevice);

      expect(transition.kind, DeviceTransitionKind.firstEver);
      expect(transition.clearNodes, isFalse);
      expect(h.settings.lastDeviceId, 'AA:BB:CC:DD:EE:01');
    });
  });

  group('NodesNotifier._init hydration race', () {
    test('destructive clearNodes() during an in-flight loadNodes() await does '
        'NOT resurrect stale nodes when the await resolves', () async {
      // This pins the bug where NodesNotifier._init captures the
      // stored node list BEFORE clearNodes fires, then resumes
      // AFTER and writes `state = nodeMap(oldNodes)` — resurrecting
      // the very nodes we just cleared. The `_clearEpoch` guard
      // must detect the clear and abandon the stale writeback.
      final h = await _makeHarness(
        lastDeviceId: 'AA:BB:CC:DD:EE:01',
        lastDeviceType: 'ble',
        lastDeviceName: 'Meshtastic_old',
        lastMyNodeNum: 0xdead,
      );
      addTearDown(h.container.dispose);

      // Seed storage with old nodes.
      await h.nodeStorage.saveNodes([
        _node(0x1001),
        _node(0x1002),
        _node(0x1003),
      ]);

      // Trigger NodesNotifier.build() — kicks off the async _init
      // load from storage.
      h.container.read(nodesProvider);

      // Immediately fire a destructive device transition (BLE A →
      // BLE B, different radio). This calls clearNodes() while
      // _init is still awaiting loadNodes().
      final newDevice = DeviceInfo(
        id: 'AA:BB:CC:DD:EE:99',
        name: 'Meshtastic_9999',
        type: TransportType.ble,
      );
      final transition = await h.container
          .read(_prepareRunnerProvider.notifier)
          .run(newDevice);
      expect(transition.kind, DeviceTransitionKind.deviceSwitch);

      // Let _init's awaited loadNodes resolve. With the epoch
      // guard, its `state = nodeMap(stale)` branch is skipped.
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(
        h.container.read(nodesProvider).length,
        0,
        reason:
            'Stale _init loadNodes writeback must be abandoned when a '
            'destructive clear fires during its await',
      );
      expect(await h.nodeStorage.loadNodes(), hasLength(0));
    });
  });
}
