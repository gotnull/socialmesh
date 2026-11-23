// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/settings/range_test/range_test_models.dart';
import 'package:socialmesh/features/settings/range_test/range_test_providers.dart';
import 'package:socialmesh/features/settings/range_test_screen.dart';
import 'package:socialmesh/generated/meshtastic/admin.pb.dart' as admin;
import 'package:socialmesh/generated/meshtastic/module_config.pb.dart'
    as module_pb;
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/protocol/admin_target.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

final _l10n = AppLocalizationsEn();

class _FakeProtocolService extends ProtocolService {
  _FakeProtocolService(this.cachedConfig) : super(_FakeTransport());

  final module_pb.ModuleConfig_RangeTestConfig cachedConfig;
  final StreamController<module_pb.ModuleConfig_RangeTestConfig> _configCtrl =
      StreamController<module_pb.ModuleConfig_RangeTestConfig>.broadcast();
  final List<module_pb.ModuleConfig> savedConfigs = [];

  @override
  module_pb.ModuleConfig_RangeTestConfig? get currentRangeTestConfig =>
      cachedConfig;

  @override
  Stream<module_pb.ModuleConfig_RangeTestConfig> get rangeTestConfigStream =>
      _configCtrl.stream;

  @override
  bool get isConnected => false;

  @override
  Future<void> getModuleConfig(
    admin.AdminMessage_ModuleConfigType moduleType, {
    AdminTarget? target,
  }) async {}

  @override
  Future<void> setModuleConfig(
    module_pb.ModuleConfig moduleConfig, {
    AdminTarget? target,
  }) async {
    savedConfigs.add(moduleConfig);
  }

  Future<void> closeStreams() => _configCtrl.close();
}

class _FakeTransport extends DeviceTransport {
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

class _FakeRangeTest extends RangeTestNotifier {
  _FakeRangeTest(this.initial);
  final RangeTestState initial;

  @override
  Future<RangeTestState> build() async => initial;
}

class _Channels extends ChannelsNotifier {
  _Channels(this.channels);
  final List<ChannelConfig> channels;

  @override
  List<ChannelConfig> build() => channels;
}

final _privatePrimary = ChannelConfig(
  index: 0,
  name: 'ops',
  psk: List<int>.generate(16, (i) => i + 40),
  role: 'PRIMARY',
);

final _publicPrimary = ChannelConfig(
  index: 0,
  name: '',
  psk: const [1],
  role: 'PRIMARY',
);

Future<_FakeProtocolService> _pump(
  WidgetTester tester, {
  required module_pb.ModuleConfig_RangeTestConfig config,
  ChannelConfig? primary,
  RangeTestState state = const RangeTestState(sessions: []),
}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  final protocol = _FakeProtocolService(config);
  addTearDown(protocol.closeStreams);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        protocolServiceProvider.overrideWithValue(protocol),
        channelsProvider.overrideWith(
          () => _Channels([primary ?? _privatePrimary]),
        ),
        rangeTestProvider.overrideWith(() => _FakeRangeTest(state)),
        isLinkConnectedProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: const RangeTestScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return protocol;
}

TextButton _saveButton(WidgetTester tester) => tester.widget<TextButton>(
  find.ancestor(
    of: find.text(_l10n.rangeTestSave),
    matching: find.byType(TextButton),
  ),
);

void main() {
  testWidgets('a receiver config saves with sender interval 0', (tester) async {
    final protocol = await _pump(
      tester,
      config: module_pb.ModuleConfig_RangeTestConfig(enabled: true, sender: 0),
    );

    expect(find.text(_l10n.rangeTestIntervalOff), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);

    await tester.tap(find.text('30s'));
    await tester.pump();
    await tester.tap(find.text(_l10n.rangeTestIntervalOff));
    await tester.pump();
    await tester.tap(find.text(_l10n.rangeTestSave));
    await tester.pump();

    expect(protocol.savedConfigs.single.rangeTest.sender, 0);
    expect(protocol.savedConfigs.single.rangeTest.enabled, isTrue);
  });

  testWidgets('a public primary channel blocks saving a sender', (
    tester,
  ) async {
    await _pump(
      tester,
      config: module_pb.ModuleConfig_RangeTestConfig(enabled: true, sender: 0),
      primary: _publicPrimary,
    );

    expect(find.text(_l10n.rangeTestPublicChannelWarning), findsOneWidget);

    await tester.tap(find.text('30s'));
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNull);

    await tester.tap(find.text(_l10n.rangeTestIntervalOff));
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('no recorded tests shows how the test works', (tester) async {
    await _pump(
      tester,
      config: module_pb.ModuleConfig_RangeTestConfig(enabled: true),
    );

    expect(find.text(_l10n.rangeTestRecordingIdle), findsOneWidget);
    expect(find.text(_l10n.rangeTestStart), findsOneWidget);
    expect(find.text(_l10n.rangeTestHowItWorks), findsOneWidget);
    expect(find.text(_l10n.rangeTestSectionHistory), findsNothing);
  });

  testWidgets('recorded tests are listed and an active one shows live', (
    tester,
  ) async {
    await _pump(
      tester,
      config: module_pb.ModuleConfig_RangeTestConfig(enabled: true),
      state: RangeTestState(
        sessions: [
          RangeTestSession(
            id: 2,
            startedAt: DateTime(2026, 11, 24, 10),
            endedAt: null,
            readingCount: 3,
          ),
          RangeTestSession(
            id: 1,
            startedAt: DateTime(2026, 11, 23, 9),
            endedAt: DateTime(2026, 11, 23, 9, 30),
            readingCount: 37,
          ),
        ],
        activeSessionId: 2,
      ),
    );

    expect(find.text(_l10n.rangeTestPacketsHeard(3)), findsOneWidget);
    expect(find.text(_l10n.rangeTestStop), findsOneWidget);
    expect(find.text(_l10n.rangeTestSectionHistory), findsOneWidget);
    expect(
      find.text(
        _l10n.rangeTestSessionSubtitle(_l10n.rangeTestPacketCount(37), '30m'),
      ),
      findsOneWidget,
    );
    expect(find.text(_l10n.rangeTestHowItWorks), findsNothing);
  });
}
