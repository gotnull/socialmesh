// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/core/widgets/info_table.dart';
import 'package:socialmesh/features/device/device_config_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _FakeTransport extends DeviceTransport {
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
  Future<void> dispose() async {}
}

class _TestProtocolService extends ProtocolService {
  _TestProtocolService() : super(_FakeTransport());
}

class _TestNodesNotifier extends NodesNotifier {
  _TestNodesNotifier(this._nodes);

  final Map<int, MeshNode> _nodes;

  @override
  Map<int, MeshNode> build() => _nodes;
}

class _TestMyNodeNumNotifier extends MyNodeNumNotifier {
  _TestMyNodeNumNotifier(this._nodeNum);

  final int? _nodeNum;

  @override
  int? build() => _nodeNum;
}

class _TestConnectedDeviceNotifier extends ConnectedDeviceNotifier {
  _TestConnectedDeviceNotifier(this._device);

  final DeviceInfo? _device;

  @override
  DeviceInfo? build() => _device;
}

class _TestRemoteAdminNotifier extends RemoteAdminNotifier {
  _TestRemoteAdminNotifier(this._state);

  final RemoteAdminState _state;

  @override
  RemoteAdminState build() => _state;
}

ProviderContainer _createContainer({
  required Map<int, MeshNode> nodes,
  required int? myNodeNum,
  required DeviceInfo? connectedDevice,
  RemoteAdminState remoteState = const RemoteAdminState(),
}) {
  return ProviderContainer(
    overrides: [
      nodesProvider.overrideWith(() => _TestNodesNotifier(nodes)),
      myNodeNumProvider.overrideWith(() => _TestMyNodeNumNotifier(myNodeNum)),
      connectedDeviceProvider.overrideWith(
        () => _TestConnectedDeviceNotifier(connectedDevice),
      ),
      remoteAdminProvider.overrideWith(
        () => _TestRemoteAdminNotifier(remoteState),
      ),
      protocolServiceProvider.overrideWithValue(_TestProtocolService()),
    ],
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DeviceConfigScreen(),
      ),
    ),
  );

  await tester.pump();
  await tester.pump();
}

Future<void> _scrollToDeviceInfo(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Device Info'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

Finder _deviceInfoTable() => find.byType(InfoTable);

Finder _valueInDeviceInfo(String value) {
  return find.descendant(of: _deviceInfoTable(), matching: find.text(value));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('remote config shows selected remote identity', (tester) async {
    final localDevice = DeviceInfo(
      id: 'local-alpha',
      name: 'LOCAL-BLE-ALPHA',
      type: TransportType.ble,
    );
    final localNode = MeshNode(
      nodeNum: 111111,
      longName: 'Local Control Node',
      shortName: 'LCN1',
      userId: '!local1111',
      hardwareModel: 'LOCAL-HARDWARE',
    );
    final remoteNode = MeshNode(
      nodeNum: 424242,
      longName: 'Remote Relay Node',
      shortName: 'RRN1',
      userId: '!remote4242',
      hardwareModel: 'REMOTE-HARDWARE',
    );

    final container = _createContainer(
      nodes: {localNode.nodeNum: localNode, remoteNode.nodeNum: remoteNode},
      myNodeNum: localNode.nodeNum,
      connectedDevice: localDevice,
      remoteState: RemoteAdminState(
        targetNodeNum: remoteNode.nodeNum,
        targetNodeName: remoteNode.displayName,
      ),
    );
    addTearDown(container.dispose);

    await _pumpScreen(tester, container);
    await _scrollToDeviceInfo(tester);

    expect(find.text('Device Config (Remote)'), findsOneWidget);
    expect(_deviceInfoTable(), findsOneWidget);
    expect(_valueInDeviceInfo('REMOTE-HARDWARE'), findsOneWidget);
    expect(_valueInDeviceInfo('!remote4242'), findsOneWidget);
    expect(_valueInDeviceInfo('424242'), findsOneWidget);
    expect(_valueInDeviceInfo('Unknown'), findsOneWidget);
    expect(_valueInDeviceInfo('LOCAL-BLE-ALPHA'), findsNothing);
  });

  testWidgets('local config still shows local identity', (tester) async {
    final localDevice = DeviceInfo(
      id: 'local-bravo',
      name: 'LOCAL-BLE-BRAVO',
      type: TransportType.ble,
    );
    final localNode = MeshNode(
      nodeNum: 515151,
      longName: 'Local Bravo Node',
      shortName: 'LBN1',
      userId: '!local5151',
      hardwareModel: 'LOCAL-BRAVO-HW',
    );

    final container = _createContainer(
      nodes: {localNode.nodeNum: localNode},
      myNodeNum: localNode.nodeNum,
      connectedDevice: localDevice,
    );
    addTearDown(container.dispose);

    await _pumpScreen(tester, container);
    await _scrollToDeviceInfo(tester);

    expect(find.text('Device Config'), findsOneWidget);
    expect(_deviceInfoTable(), findsOneWidget);
    expect(_valueInDeviceInfo('LOCAL-BLE-BRAVO'), findsOneWidget);
    expect(_valueInDeviceInfo('LOCAL-BRAVO-HW'), findsOneWidget);
    expect(_valueInDeviceInfo('!local5151'), findsOneWidget);
    expect(_valueInDeviceInfo('515151'), findsOneWidget);
  });

  testWidgets('remote config deterministically prefers remote over local', (
    tester,
  ) async {
    final localDevice = DeviceInfo(
      id: 'local-charlie',
      name: 'LOCAL-BLE-CHARLIE',
      type: TransportType.ble,
    );
    final localNode = MeshNode(
      nodeNum: 616161,
      longName: 'Local Charlie Node',
      shortName: 'LCN2',
      userId: '!local6161',
      hardwareModel: 'LOCAL-CHARLIE-HW',
    );
    final remoteNode = MeshNode(
      nodeNum: 717171,
      longName: 'Remote Charlie Node',
      shortName: 'RCN2',
      userId: '!remote7171',
      hardwareModel: 'REMOTE-CHARLIE-HW',
    );

    final container = _createContainer(
      nodes: {localNode.nodeNum: localNode, remoteNode.nodeNum: remoteNode},
      myNodeNum: localNode.nodeNum,
      connectedDevice: localDevice,
      remoteState: RemoteAdminState(
        targetNodeNum: remoteNode.nodeNum,
        targetNodeName: remoteNode.displayName,
      ),
    );
    addTearDown(container.dispose);

    await _pumpScreen(tester, container);
    await _scrollToDeviceInfo(tester);

    expect(_valueInDeviceInfo('REMOTE-CHARLIE-HW'), findsOneWidget);
    expect(_valueInDeviceInfo('!remote7171'), findsOneWidget);
    expect(_valueInDeviceInfo('717171'), findsOneWidget);
    expect(_valueInDeviceInfo('LOCAL-BLE-CHARLIE'), findsNothing);
    expect(_valueInDeviceInfo('LOCAL-CHARLIE-HW'), findsNothing);
    expect(_valueInDeviceInfo('!local6161'), findsNothing);
    expect(_valueInDeviceInfo('616161'), findsNothing);
  });

  testWidgets('remote config keeps missing remote fields explicit', (
    tester,
  ) async {
    final localDevice = DeviceInfo(
      id: 'local-delta',
      name: 'LOCAL-BLE-DELTA',
      type: TransportType.ble,
    );
    final localNode = MeshNode(
      nodeNum: 818181,
      longName: 'Local Delta Node',
      shortName: 'LDN1',
      userId: '!local8181',
      hardwareModel: 'LOCAL-DELTA-HW',
    );
    final remoteNode = MeshNode(
      nodeNum: 919191,
      longName: 'Remote Delta Node',
      shortName: 'RDN1',
    );

    final container = _createContainer(
      nodes: {localNode.nodeNum: localNode, remoteNode.nodeNum: remoteNode},
      myNodeNum: localNode.nodeNum,
      connectedDevice: localDevice,
      remoteState: RemoteAdminState(
        targetNodeNum: remoteNode.nodeNum,
        targetNodeName: remoteNode.displayName,
      ),
    );
    addTearDown(container.dispose);

    await _pumpScreen(tester, container);
    await _scrollToDeviceInfo(tester);

    expect(_valueInDeviceInfo('919191'), findsOneWidget);
    expect(_valueInDeviceInfo('LOCAL-BLE-DELTA'), findsNothing);
    expect(_valueInDeviceInfo('LOCAL-DELTA-HW'), findsNothing);
    expect(_valueInDeviceInfo('!local8181'), findsNothing);
    expect(
      find.descendant(of: _deviceInfoTable(), matching: find.text('Unknown')),
      findsNWidgets(3),
    );
  });
}
