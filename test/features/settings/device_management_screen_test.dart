// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/core/widgets/status_banner.dart';
import 'package:socialmesh/features/settings/device_management_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/protocol/admin_target.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

// Remote reboot and shutdown are SET/ACTION admin commands. Without a session
// passkey the remote firmware drops them, so the screen must not send one and
// report success. With a session, it sends to the remote node and keeps the
// screen open, because the local link does not drop.

const _remoteNode = 0x2002;
const _remoteName = 'Hilltop';

class _FakeProtocolService extends ProtocolService {
  _FakeProtocolService({required this.sessionReady}) : super(_FakeTransport());

  bool sessionReady;
  final List<AdminTarget?> rebootTargets = [];

  @override
  bool get isConnected => true;

  @override
  bool remoteAdminSessionReady(int nodeNum) => sessionReady;

  @override
  Future<void> reboot({int delaySeconds = 2, AdminTarget? target}) async {
    rebootTargets.add(target);
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

Widget _wrap(_FakeProtocolService protocol, _RemoteTarget remote) {
  return ProviderScope(
    overrides: [
      protocolServiceProvider.overrideWithValue(protocol),
      remoteAdminProvider.overrideWith(() => remote),
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
}
