// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_lifecycle_provider.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/live_activity/live_activity_service.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/storage_service.dart';
import 'package:socialmesh/features/settings/background_connection_screen.dart'
    show kLiveActivityEnabled;

class _ActivityService extends Fake implements LiveActivityService {
  bool running = false;
  int starts = 0;
  Completer<bool>? pendingStart;

  @override
  bool get isSupported => true;
  @override
  bool get isActive => running;
  @override
  Future<bool> hasRunningActivity() async => running;
  @override
  Future<void> endActivity() async => running = false;
  @override
  Future<void> endAllActivities() => endActivity();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #startMeshActivity) {
      starts++;
      return (pendingStart?.future ?? Future.value(true)).then((success) {
        running = success;
        return success;
      });
    }
    if (invocation.memberName == #updateActivity) return Future.value(true);
    return super.noSuchMethod(invocation);
  }
}

class _Protocol extends Mock implements ProtocolService {}

class _Nodes extends NodesNotifier {
  @override
  Map<int, MeshNode> build() => {};
}

class _NodeNum extends MyNodeNumNotifier {
  @override
  int? build() => null;
}

class _Device extends ConnectedDeviceNotifier {
  @override
  DeviceInfo? build() => null;
}

void main() {
  late ProviderContainer container;
  late _ActivityService service;
  late StreamController<DeviceConnectionState> connection;
  late SharedPreferences prefs;

  Future<void> setup() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final settings = SettingsService();
    await settings.init();
    service = _ActivityService();
    connection = StreamController<DeviceConnectionState>();
    final protocol = _Protocol();
    when(() => protocol.lastRssi).thenReturn(-60);
    when(() => protocol.lastSnr).thenReturn(5);
    when(() => protocol.rssiStream).thenAnswer((_) => const Stream.empty());
    when(() => protocol.snrStream).thenAnswer((_) => const Stream.empty());
    when(
      () => protocol.channelUtilStream,
    ).thenAnswer((_) => const Stream.empty());
    container = ProviderContainer(
      overrides: [
        liveActivityServiceProvider.overrideWithValue(service),
        settingsServiceProvider.overrideWithValue(AsyncData(settings)),
        connectionStateProvider.overrideWith((ref) => connection.stream),
        protocolServiceProvider.overrideWithValue(protocol),
        nodesProvider.overrideWith(_Nodes.new),
        myNodeNumProvider.overrideWith(_NodeNum.new),
        connectedDeviceProvider.overrideWith(_Device.new),
      ],
    );
  }

  tearDown(() async {
    await connection.close();
  });

  Future<void> connect(WidgetTester tester) async {
    container.listen(liveActivityManagerProvider, (previous, next) {});
    connection.add(DeviceConnectionState.connected);
    await tester.pump();
    expect(
      container.read(connectionStateProvider).value,
      DeviceConnectionState.connected,
    );
  }

  void lifecycle(AppLifecycleState state) => container
      .read(appLifecycleProvider.notifier)
      .didChangeAppLifecycleState(state);

  testWidgets('recovers an expired activity without reconnecting', (
    tester,
  ) async {
    await setup();
    await connect(tester);
    expect(service.starts, 1);
    service.running = false;
    await tester.pump(const Duration(seconds: 30));
    expect(service.starts, 2);
    expect(container.read(liveActivityManagerProvider), isTrue);
    await tester.pump(const Duration(seconds: 30));
    expect(service.starts, 2);
    container.dispose();
  });

  testWidgets('waits for foreground and recovers on resume', (tester) async {
    await setup();
    await connect(tester);
    lifecycle(AppLifecycleState.paused);
    service.running = false;
    await tester.pump(const Duration(seconds: 60));
    expect(service.starts, 1);
    lifecycle(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.starts, 2);
    container.dispose();
  });

  testWidgets('does not recover after disconnect or preference disable', (
    tester,
  ) async {
    await setup();
    await connect(tester);
    await prefs.setBool(kLiveActivityEnabled, false);
    await container
        .read(liveActivityManagerProvider.notifier)
        .endLiveActivity();
    await tester.pump(const Duration(seconds: 30));
    expect(service.starts, 1);
    await prefs.setBool(kLiveActivityEnabled, true);
    connection.add(DeviceConnectionState.disconnected);
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(service.starts, 1);
    container.dispose();
  });

  testWidgets('serializes recovery and ends a creation raced by disconnect', (
    tester,
  ) async {
    await setup();
    service.pendingStart = Completer<bool>();
    await connect(tester);
    lifecycle(AppLifecycleState.paused);
    lifecycle(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 30));
    expect(service.starts, 1);
    connection.add(DeviceConnectionState.disconnected);
    await tester.pump();
    service.pendingStart!.complete(true);
    await tester.pump();
    expect(service.running, isFalse);
    expect(container.read(liveActivityManagerProvider), isFalse);
    container.dispose();
  });

  testWidgets('retries a failed creation on the next foreground check', (
    tester,
  ) async {
    await setup();
    service.pendingStart = Completer<bool>()..complete(false);
    await connect(tester);
    expect(container.read(liveActivityManagerProvider), isFalse);
    service.pendingStart = null;
    await tester.pump(const Duration(seconds: 30));
    expect(service.starts, 2);
    expect(service.running, isTrue);
    container.dispose();
  });

  testWidgets('starts on resume after connecting in the background', (
    tester,
  ) async {
    await setup();
    lifecycle(AppLifecycleState.paused);
    await connect(tester);
    expect(service.starts, 0);
    lifecycle(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.starts, 1);
    expect(service.running, isTrue);
    container.dispose();
  });

  testWidgets('ends a late creation after the manager is disposed', (
    tester,
  ) async {
    await setup();
    service.pendingStart = Completer<bool>();
    await connect(tester);
    expect(service.starts, 1);
    container.dispose();
    service.pendingStart!.complete(true);
    await tester.pump();
    expect(service.running, isFalse);
  });
}
