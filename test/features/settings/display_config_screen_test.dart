// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/core/widgets/animations.dart';
import 'package:socialmesh/core/widgets/settings_primitives.dart';
import 'package:socialmesh/features/settings/display_config_screen.dart';
import 'package:socialmesh/generated/meshtastic/admin.pb.dart' as admin;
import 'package:socialmesh/generated/meshtastic/config.pb.dart' as config_pb;
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/protocol/admin_target.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

final _l10n = AppLocalizationsEn();

class _FakeProtocolService extends ProtocolService {
  _FakeProtocolService({this.cachedConfig}) : super(_FakeTransport());

  config_pb.Config_DisplayConfig? cachedConfig;
  final StreamController<config_pb.Config_DisplayConfig> _ctrl =
      StreamController<config_pb.Config_DisplayConfig>.broadcast();

  @override
  config_pb.Config_DisplayConfig? get currentDisplayConfig => cachedConfig;

  @override
  Stream<config_pb.Config_DisplayConfig> get displayConfigStream =>
      _ctrl.stream;

  @override
  bool get isConnected => false; // skip the get-config-from-device branch

  @override
  Future<void> getConfig(
    admin.AdminMessage_ConfigType configType, {
    AdminTarget? target,
  }) async {}

  Future<void> closeStreams() async {
    await _ctrl.close();
  }
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
  final StreamController<DeviceConnectionState> _stateCtrl =
      StreamController<DeviceConnectionState>.broadcast();
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

Widget _wrap({required _FakeProtocolService protocol}) {
  return ProviderScope(
    overrides: [protocolServiceProvider.overrideWithValue(protocol)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: const DisplayConfigScreen(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

/// The radio indicator in the option row whose title is [title].
Finder _indicatorFor(String title, IconData icon) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(InkWell)),
  matching: find.byIcon(icon),
);

void main() {
  Future<_FakeProtocolService> pumpScreen(
    WidgetTester tester,
    config_pb.Config_DisplayConfig config,
  ) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final protocol = _FakeProtocolService(cachedConfig: config);
    addTearDown(protocol.closeStreams);
    await tester.pumpWidget(_wrap(protocol: protocol));
    await _settle(tester);
    return protocol;
  }

  testWidgets('renders every section with the shared settings primitives', (
    tester,
  ) async {
    await pumpScreen(tester, config_pb.Config_DisplayConfig());

    expect(find.byType(SettingsSectionHeader), findsNWidgets(5));
    expect(find.text(_l10n.displayConfigSectionScreen), findsOneWidget);
    expect(find.text(_l10n.displayConfigSectionTimeCompass), findsOneWidget);
    expect(find.text(_l10n.displayConfigSectionOledType), findsOneWidget);
    expect(find.text(_l10n.displayConfigSectionUnitsFormat), findsOneWidget);
    expect(find.text(_l10n.displayConfigSectionDisplayMode), findsOneWidget);
    // Seven toggles, each in its own tile.
    expect(find.byType(SettingsTile), findsNWidgets(7));
    expect(find.byType(ThemedSwitch), findsNWidgets(7));
  });

  testWidgets('cached config drives the selected options and switches', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      config_pb.Config_DisplayConfig()
        ..units = config_pb.Config_DisplayConfig_DisplayUnits.IMPERIAL
        ..displaymode = config_pb.Config_DisplayConfig_DisplayMode.INVERTED
        ..oled = config_pb.Config_DisplayConfig_OledType.OLED_SH1106
        ..flipScreen = true,
    );

    expect(
      _indicatorFor(_l10n.displayConfigImperial, Icons.radio_button_checked),
      findsOneWidget,
    );
    expect(
      _indicatorFor(_l10n.displayConfigMetric, Icons.radio_button_unchecked),
      findsOneWidget,
    );
    expect(
      _indicatorFor(
        _l10n.displayConfigModeInverted,
        Icons.radio_button_checked,
      ),
      findsOneWidget,
    );
    expect(_indicatorFor('SH1106', Icons.radio_button_checked), findsOneWidget);

    final flip = tester.widget<ThemedSwitch>(
      find.descendant(
        of: find.ancestor(
          of: find.text(_l10n.displayConfigFlipScreen),
          matching: find.byType(SettingsTile),
        ),
        matching: find.byType(ThemedSwitch),
      ),
    );
    expect(flip.value, isTrue);
  });

  testWidgets('unset units and mode show the values save would send', (
    tester,
  ) async {
    // Save falls back to METRIC and DEFAULT when the radio reports nothing,
    // so the screen marks those options rather than showing no selection.
    final config = config_pb.Config_DisplayConfig()
      ..clearUnits()
      ..clearDisplaymode();
    await pumpScreen(tester, config);

    expect(
      _indicatorFor(_l10n.displayConfigMetric, Icons.radio_button_checked),
      findsOneWidget,
    );
    expect(
      _indicatorFor(_l10n.displayConfigModeDefault, Icons.radio_button_checked),
      findsOneWidget,
    );
  });

  testWidgets('tapping an option row moves the selection', (tester) async {
    await pumpScreen(
      tester,
      config_pb.Config_DisplayConfig()
        ..units = config_pb.Config_DisplayConfig_DisplayUnits.METRIC,
    );

    await tester.tap(find.text(_l10n.displayConfigImperial));
    await tester.pump();

    expect(
      _indicatorFor(_l10n.displayConfigImperial, Icons.radio_button_checked),
      findsOneWidget,
    );
    expect(
      _indicatorFor(_l10n.displayConfigMetric, Icons.radio_button_unchecked),
      findsOneWidget,
    );
  });
}
