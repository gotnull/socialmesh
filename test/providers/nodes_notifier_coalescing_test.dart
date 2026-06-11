// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the flag-gated node-emission coalescing contract:
// - structural events (new node, position change) flush synchronously,
// - pure telemetry/lastHeard churn coalesces into one emission per
//   window, merging consecutive packets against the freshest pending
//   value,
// - side effects stay per-event and never depend on the flush,
// - clearNodes kills pending writes so a later flush cannot resurrect
//   cleared nodes,
// - with the flag off, every event commits synchronously (the
//   pre-coalescing behavior verbatim).

import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/automations/automation_engine.dart';
import 'package:socialmesh/features/automations/automation_providers.dart';
import 'package:socialmesh/features/automations/automation_repository.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/generated/meshtastic/telemetry.pb.dart' as telemetry;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/models/trigger_protocol.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/ifttt/ifttt_service.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _SilentFakeTransport extends DeviceTransport {
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();

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
  Stream<DeviceConnectionState> get stateStream =>
      const Stream<DeviceConnectionState>.empty();

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream<DeviceInfo>.empty();

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
  Future<void> dispose() async {
    await _dataController.close();
  }
}

class _CountingAutomationEngine extends AutomationEngine {
  int nodeUpdates = 0;

  _CountingAutomationEngine()
    : super(repository: AutomationRepository(), iftttService: IftttService());

  @override
  Future<void> processNodeUpdate(
    MeshNode node, {
    MeshNode? previousNode,
    TriggerProtocol protocol = TriggerProtocol.meshtastic,
  }) async {
    nodeUpdates++;
  }
}

const _peer = 0x2222;
var _packetId = 500;

class _Harness {
  final ProviderContainer container;
  final ProtocolService protocol;
  final _SilentFakeTransport transport;
  final _CountingAutomationEngine engine;
  int emissions = 0;

  _Harness._(this.container, this.protocol, this.transport, this.engine);

  static Future<_Harness> create() async {
    final transport = _SilentFakeTransport();
    final protocol = ProtocolService(transport);
    final engine = _CountingAutomationEngine();
    final container = ProviderContainer(
      overrides: [
        protocolServiceProvider.overrideWithValue(protocol),
        iftttServiceProvider.overrideWithValue(IftttService()),
        automationEngineProvider.overrideWithValue(engine),
        nodeStorageProvider.overrideWith(
          (ref) => throw StateError('test: no storage'),
        ),
        deviceFavoritesProvider.overrideWith(
          (ref) => throw StateError('test: no favorites'),
        ),
      ],
    );
    final harness = _Harness._(container, protocol, transport, engine);
    // Activate the notifier (registers the nodeStream listener) and
    // count its emissions.
    container.listen<Map<int, MeshNode>>(
      nodesProvider,
      (_, _) => harness.emissions++,
    );
    return harness;
  }

  NodesNotifier get notifier => container.read(nodesProvider.notifier);

  Map<int, MeshNode> get nodes => container.read(nodesProvider);

  Future<void> _inject(pb.FromRadio fromRadio) async {
    await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
    // Packet processing continues past handleIncomingPacket's return;
    // give the node emission a moment to reach the listener.
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }

  Future<void> injectNodeInfo(
    int nodeNum, {
    double? latitude,
    double? longitude,
  }) async {
    final nodeInfo = pb.NodeInfo(
      num: nodeNum,
      user: pb.User(
        id: '!${nodeNum.toRadixString(16)}',
        longName: 'Node $nodeNum',
        shortName: 'N$nodeNum',
      ),
    );
    if (latitude != null && longitude != null) {
      nodeInfo.position = pb.Position(
        latitudeI: (latitude * 1e7).round(),
        longitudeI: (longitude * 1e7).round(),
      );
    }
    await _inject(pb.FromRadio(nodeInfo: nodeInfo));
  }

  Future<void> injectDeviceTelemetry(int nodeNum, {required int battery}) {
    return _inject(
      pb.FromRadio(
        packet: pb.MeshPacket(
          from: nodeNum,
          to: 0xFFFFFFFF,
          id: _packetId++,
          decoded: pb.Data(
            portnum: pn.PortNum.TELEMETRY_APP,
            payload: telemetry.Telemetry(
              deviceMetrics: telemetry.DeviceMetrics(batteryLevel: battery),
            ).writeToBuffer(),
          ),
        ),
      ),
    );
  }

  Future<void> dispose() async {
    container.dispose();
    protocol.stop();
    await transport.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Default: coalescing enabled (the getter defaults to true when the
    // key is absent).
    dotenv.loadFromString(envString: 'TEST_MODE=true');
  });

  test('a new node flushes synchronously; telemetry churn coalesces and '
      'merges against the freshest pending value', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);

    await h.injectNodeInfo(_peer);
    expect(
      h.nodes[_peer],
      isNotNull,
      reason: 'New-node discovery must commit synchronously.',
    );
    final emissionsAfterDiscovery = h.emissions;

    // Telemetry churn: multiple packets inside one coalesce window.
    await h.injectDeviceTelemetry(_peer, battery: 10);
    await h.injectDeviceTelemetry(_peer, battery: 20);
    await h.injectDeviceTelemetry(_peer, battery: 30);
    expect(
      h.nodes[_peer]!.batteryLevel,
      isNot(30),
      reason: 'Telemetry-only updates must pend, not commit per event.',
    );
    expect(h.emissions, emissionsAfterDiscovery);

    h.notifier.flushPendingNodeWrites();
    expect(
      h.nodes[_peer]!.batteryLevel,
      30,
      reason:
          'The flush must carry the newest pending merge, proving '
          'consecutive packets merged against the pending value.',
    );
    expect(h.emissions, emissionsAfterDiscovery + 1);
  });

  test(
    'the coalesce window flushes on its own without a manual flush',
    () async {
      final h = await _Harness.create();
      addTearDown(h.dispose);

      await h.injectNodeInfo(_peer);
      await h.injectDeviceTelemetry(_peer, battery: 42);
      expect(h.nodes[_peer]!.batteryLevel, isNot(42));

      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(
        h.nodes[_peer]!.batteryLevel,
        42,
        reason: 'The window timer must commit pending writes by itself.',
      );
    },
  );

  test('a position change flushes synchronously', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);

    await h.injectNodeInfo(_peer);
    await h.injectNodeInfo(_peer, latitude: -37.81, longitude: 144.96);
    expect(
      h.nodes[_peer]!.latitude,
      closeTo(-37.81, 0.0001),
      reason: 'Position updates must keep today\'s map latency.',
    );
  });

  test('side effects stay per-event regardless of flush count', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);

    await h.injectNodeInfo(_peer);
    final updatesAfterDiscovery = h.engine.nodeUpdates;
    // Each telemetry MeshPacket produces TWO nodeStream events (the
    // lastHeard/RF-metadata update and the telemetry merge), and side
    // effects fire once per stream event — with or without coalescing.
    await h.injectDeviceTelemetry(_peer, battery: 10);
    await h.injectDeviceTelemetry(_peer, battery: 20);
    await h.injectDeviceTelemetry(_peer, battery: 30);
    expect(
      h.engine.nodeUpdates,
      updatesAfterDiscovery + 6,
      reason:
          'Automation processing must fire once per stream event even '
          'while the state emissions coalesce.',
    );
  });

  test('clearNodes kills pending writes; the flush cannot resurrect '
      'cleared nodes', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);

    await h.injectNodeInfo(_peer);
    await h.injectDeviceTelemetry(_peer, battery: 55);

    h.notifier.clearNodes();
    expect(h.nodes, isEmpty);

    h.notifier.flushPendingNodeWrites();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(
      h.nodes,
      isEmpty,
      reason: 'Pending writes predate the clear and must die with it.',
    );
  });

  test('with the flag off every event commits synchronously', () async {
    dotenv.loadFromString(envString: 'NODE_EMISSION_COALESCING_ENABLED=false');
    final h = await _Harness.create();
    addTearDown(h.dispose);

    await h.injectNodeInfo(_peer);
    final emissionsAfterDiscovery = h.emissions;

    await h.injectDeviceTelemetry(_peer, battery: 10);
    expect(h.nodes[_peer]!.batteryLevel, 10);
    await h.injectDeviceTelemetry(_peer, battery: 20);
    expect(h.nodes[_peer]!.batteryLevel, 20);
    expect(
      h.emissions,
      greaterThanOrEqualTo(emissionsAfterDiscovery + 2),
      reason: 'Flag off must restore per-event emission verbatim.',
    );
  });
}
