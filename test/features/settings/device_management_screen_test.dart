// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/core/widgets/settings_primitives.dart';
import 'package:socialmesh/core/widgets/status_banner.dart';
import 'package:socialmesh/features/settings/device_management_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/radio_scope_providers.dart';
import 'package:socialmesh/services/protocol/admin_ack_tracker.dart';
import 'package:socialmesh/services/protocol/admin_target.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

// Remote reboot and shutdown are SET/ACTION admin commands. Without a session
// passkey the remote firmware drops them, so the screen must not send one and
// report success. With a session, it sends to the remote node and keeps the
// screen open, because the local link does not drop.

const _remoteNode = 0x2002;
const _remoteName = 'Hilltop';
const _localNode = 0x1001;

class _FakeProtocolService extends ProtocolService {
  _FakeProtocolService({
    required this.sessionReady,
    this.connected = true,
    this.radioNodeNums = const {},
  }) : super(_FakeTransport());

  bool sessionReady;
  final bool connected;
  final Set<int> radioNodeNums;
  final List<AdminTarget?> rebootTargets = [];
  final List<int> removedNodeNums = [];

  @override
  bool get isConnected => connected;

  @override
  int? get myNodeNum => _localNode;

  @override
  Map<int, MeshNode> get nodes => {
    for (final n in radioNodeNums) n: MeshNode(nodeNum: n),
  };

  @override
  Future<AdminAckResult?> removeNode(
    int nodeNum, {
    Duration? ackTimeout,
  }) async {
    removedNodeNums.add(nodeNum);
    return ackTimeout == null ? null : const AdminAckResult.acked();
  }

  @override
  bool remoteAdminSessionReady(int nodeNum) => sessionReady;

  @override
  Future<void> reboot({int delaySeconds = 2, AdminTarget? target}) async {
    rebootTargets.add(target);
  }
}

class _FakeNodes extends NodesNotifier {
  _FakeNodes(this.initial);
  final Map<int, MeshNode> initial;
  final List<Set<int>> removeCalls = [];

  @override
  Map<int, MeshNode> build() => initial;

  @override
  void removeNodes(Set<int> nodeNums) {
    removeCalls.add(nodeNums);
    state = Map.of(state)..removeWhere((k, _) => nodeNums.contains(k));
  }
}

class _RemoteTarget extends RemoteAdminNotifier {
  _RemoteTarget(this.initial);
  final RemoteAdminState initial;
  int setTargetCalls = 0;

  @override
  RemoteAdminState build() => initial;

  @override
  void setTarget(int nodeNum, String? nodeName) {
    setTargetCalls++;
    state = RemoteAdminState(targetNodeNum: nodeNum, targetNodeName: nodeName);
  }
}

class _FakeTransport extends DeviceTransport {
  final StreamController<DeviceConnectionState> _stateCtrl =
      StreamController<DeviceConnectionState>.broadcast();

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  @override
  DeviceConnectionState get state => DeviceConnectionState.connected;

  @override
  Stream<DeviceConnectionState> get stateStream => _stateCtrl.stream;

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
  Future<void> dispose() async {
    await _stateCtrl.close();
  }
}

Widget _wrap(
  _FakeProtocolService protocol,
  _RemoteTarget remote, {
  bool sharedScope = false,
  _FakeNodes? nodes,
}) {
  return ProviderScope(
    overrides: [
      protocolServiceProvider.overrideWithValue(protocol),
      remoteAdminProvider.overrideWith(() => remote),
      currentRadioScopeSharedProvider.overrideWith((ref) async => sharedScope),
      if (nodes != null) nodesProvider.overrideWith(() => nodes),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: const DeviceManagementScreen(),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(widget);
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('local target: no remote banner and Sync Time is offered', (
    tester,
  ) async {
    final protocol = _FakeProtocolService(sessionReady: true);
    await _pump(
      tester,
      _wrap(protocol, _RemoteTarget(const RemoteAdminState())),
    );

    expect(find.byType(StatusBanner), findsNothing);
    expect(find.text('Sync Time'), findsOneWidget);
  });

  testWidgets('disconnected: explains why and the actions do nothing', (
    tester,
  ) async {
    final protocol = _FakeProtocolService(sessionReady: true, connected: false);
    await _pump(
      tester,
      _wrap(protocol, _RemoteTarget(const RemoteAdminState())),
    );

    expect(
      find.text('Device not connected. Connect to a device to manage it.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reboot Device'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsNothing);
    expect(protocol.rebootTargets, isEmpty);
  });

  testWidgets('rows use the canonical settings primitives', (tester) async {
    final protocol = _FakeProtocolService(sessionReady: true);
    await _pump(
      tester,
      _wrap(protocol, _RemoteTarget(const RemoteAdminState())),
    );

    // Power, Time, Reset and Firmware sections; eight action rows.
    expect(find.byType(SettingsSectionHeader), findsNWidgets(4));
    expect(find.byType(SettingsTile), findsNWidgets(8));
  });

  group('Reset Node Database on a radio that shares data', () {
    const ownSubtitle = 'Clear all known nodes from device and app';
    const sharedSubtitle =
        'Clear known nodes from the radio, keep the shared list in the app';

    testWidgets('says the shared node list stays, on the tile and the '
        'confirmation', (tester) async {
      final protocol = _FakeProtocolService(sessionReady: true);
      await _pump(
        tester,
        _wrap(
          protocol,
          _RemoteTarget(const RemoteAdminState()),
          sharedScope: true,
        ),
      );

      expect(find.text(sharedSubtitle), findsOneWidget);
      expect(find.text(ownSubtitle), findsNothing);

      await tester.tap(find.text('Reset Node Database'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining("The app's node list is shared with your other"),
        findsOneWidget,
      );
    });

    testWidgets('a radio with its own data keeps the original wording', (
      tester,
    ) async {
      final protocol = _FakeProtocolService(sessionReady: true);
      await _pump(
        tester,
        _wrap(protocol, _RemoteTarget(const RemoteAdminState())),
      );

      expect(find.text(ownSubtitle), findsOneWidget);
      await tester.tap(find.text('Reset Node Database'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('clear all discovered nodes from the device'),
        findsOneWidget,
      );
    });

    testWidgets('a remote target never touches the app list, so the shared '
        'wording does not apply', (tester) async {
      final protocol = _FakeProtocolService(sessionReady: true);
      await _pump(
        tester,
        _wrap(
          protocol,
          _RemoteTarget(
            const RemoteAdminState(
              targetNodeNum: _remoteNode,
              targetNodeName: _remoteName,
            ),
          ),
          sharedScope: true,
        ),
      );

      expect(find.text(ownSubtitle), findsOneWidget);
      expect(find.text(sharedSubtitle), findsNothing);
    });
  });

  testWidgets('remote target: names the node and hides local-only Sync Time', (
    tester,
  ) async {
    final protocol = _FakeProtocolService(sessionReady: true);
    await _pump(
      tester,
      _wrap(
        protocol,
        _RemoteTarget(
          const RemoteAdminState(
            targetNodeNum: _remoteNode,
            targetNodeName: _remoteName,
          ),
        ),
      ),
    );

    expect(
      find.text(
        'Commands on this screen go to $_remoteName, not the radio you are '
        'connected to.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sync Time'), findsNothing);
  });

  testWidgets('remote reboot without a session is not sent and requests one', (
    tester,
  ) async {
    final protocol = _FakeProtocolService(sessionReady: false);
    final remote = _RemoteTarget(
      const RemoteAdminState(
        targetNodeNum: _remoteNode,
        targetNodeName: _remoteName,
      ),
    );
    await _pump(tester, _wrap(protocol, remote));

    await tester.tap(find.text('Reboot Device'));
    await tester.pump();

    expect(protocol.rebootTargets, isEmpty);
    expect(remote.setTargetCalls, 1);
    expect(find.text('Confirm'), findsNothing);
    expect(
      find.text(
        'No admin session with $_remoteName yet. Requesting one now; try '
        'again in a few seconds.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('remote reboot with a session goes to the remote node and '
      'keeps the screen open', (tester) async {
    final protocol = _FakeProtocolService(sessionReady: true);
    await _pump(
      tester,
      _wrap(
        protocol,
        _RemoteTarget(
          const RemoteAdminState(
            targetNodeNum: _remoteNode,
            targetNodeName: _remoteName,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Reboot Device'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '$_remoteName will reboot in 2 seconds. Your connection to your own '
        'radio is not affected.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(protocol.rebootTargets, hasLength(1));
    expect(protocol.rebootTargets.single?.resolve(1), _remoteNode);
    expect(find.text('Reboot Device command sent'), findsOneWidget);
    expect(find.text('Reboot Device'), findsOneWidget);
  });

  group('Remove Stale Nodes', () {
    MeshNode node(int nodeNum, {int? daysAgo, bool favourite = false}) =>
        MeshNode(
          nodeNum: nodeNum,
          lastHeard: daysAgo == null
              ? null
              : DateTime.now().subtract(Duration(days: daysAgo)),
          isFavorite: favourite,
        );

    // 0x10 is on the radio and stale, 0x11 is stale but app-only, 0x12 is
    // recent, 0x13 is a stale favourite, the local node is stale.
    Map<int, MeshNode> appNodes() => {
      for (final n in [
        node(0x10, daysAgo: 30),
        node(0x11, daysAgo: 30),
        node(0x12, daysAgo: 1),
        node(0x13, daysAgo: 30, favourite: true),
        node(_localNode, daysAgo: 30),
      ])
        n.nodeNum: n,
    };

    Future<void> runRemoval(WidgetTester tester) async {
      await tester.tap(find.text('Remove Stale Nodes'));
      await tester.pumpAndSettle();
      expect(find.text('Not heard for more than 7 days'), findsOneWidget);
      expect(find.text('2 nodes will be removed'), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Remove 2 nodes?'), findsOneWidget);

      await tester.tap(find.text('Remove'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('removes stale nodes from the radio and the app', (
      tester,
    ) async {
      final protocol = _FakeProtocolService(
        sessionReady: true,
        radioNodeNums: {0x10, 0x12},
      );
      final nodes = _FakeNodes(appNodes());
      await _pump(
        tester,
        _wrap(protocol, _RemoteTarget(const RemoteAdminState()), nodes: nodes),
      );

      expect(
        find.text(
          'Remove nodes not heard for a chosen number of days from the '
          'device and app',
        ),
        findsOneWidget,
      );
      await runRemoval(tester);

      // Only the node the radio reported needs a radio write.
      expect(protocol.removedNodeNums, [0x10]);
      expect(nodes.removeCalls, [
        {0x10, 0x11},
      ]);
      expect(find.text('Removed 2 nodes.'), findsOneWidget);
    });

    testWidgets('a shared node list is kept and only radio nodes are '
        'offered', (tester) async {
      final protocol = _FakeProtocolService(
        sessionReady: true,
        radioNodeNums: {0x10, 0x11, 0x12},
      );
      final nodes = _FakeNodes(appNodes());
      await _pump(
        tester,
        _wrap(
          protocol,
          _RemoteTarget(const RemoteAdminState()),
          sharedScope: true,
          nodes: nodes,
        ),
      );

      expect(
        find.text(
          'Remove nodes not heard for a chosen number of days from the '
          'radio, keep the shared list in the app',
        ),
        findsOneWidget,
      );
      await runRemoval(tester);

      expect(protocol.removedNodeNums, [0x10, 0x11]);
      expect(nodes.removeCalls, isEmpty);
    });

    testWidgets('is not offered while a remote node is targeted', (
      tester,
    ) async {
      final protocol = _FakeProtocolService(sessionReady: true);
      await _pump(
        tester,
        _wrap(
          protocol,
          _RemoteTarget(
            const RemoteAdminState(
              targetNodeNum: _remoteNode,
              targetNodeName: _remoteName,
            ),
          ),
        ),
      );

      expect(find.text('Remove Stale Nodes'), findsNothing);
    });
  });
}
