// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/settings/mqtt_config_screen.dart';
import 'package:socialmesh/generated/meshtastic/module_config.pb.dart'
    as module_pb;
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/mqtt_client_proxy_providers.dart';
import 'package:socialmesh/services/mqtt/mqtt_client_proxy_service.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

final _l10n = AppLocalizationsEn();

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _FakeProtocolService extends ProtocolService {
  _FakeProtocolService({this.cachedConfig}) : super(_FakeTransport());

  module_pb.ModuleConfig_MQTTConfig? cachedConfig;
  final StreamController<module_pb.ModuleConfig_MQTTConfig> _ctrl =
      StreamController<module_pb.ModuleConfig_MQTTConfig>.broadcast();

  @override
  module_pb.ModuleConfig_MQTTConfig? get currentMqttConfig => cachedConfig;

  @override
  Stream<module_pb.ModuleConfig_MQTTConfig> get mqttConfigStream =>
      _ctrl.stream;

  @override
  bool get isConnected => false; // skip the get-config-from-device branch

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

class _RecordingProxyService extends MqttClientProxyService {
  @override
  bool get isConnected => false;
}

class _StaticDiagnosticsNotifier extends MqttProxyDiagnosticsNotifier {
  _StaticDiagnosticsNotifier(this._initial);
  final MqttProxyDiagnostics _initial;

  @override
  MqttProxyDiagnostics build() => _initial;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

module_pb.ModuleConfig_MQTTConfig _proxyEnabledConfig() {
  return module_pb.ModuleConfig_MQTTConfig()
    ..enabled = true
    ..proxyToClientEnabled = true
    ..address = 'broker.example:1883'
    ..root = 'msh';
}

module_pb.ModuleConfig_MQTTConfig _mqttEnabledNoProxyConfig() {
  return module_pb.ModuleConfig_MQTTConfig()
    ..enabled = true
    ..proxyToClientEnabled = false
    ..address = 'broker.example:1883'
    ..root = 'msh';
}

Widget _wrap({
  required _FakeProtocolService protocol,
  required MqttProxyDiagnostics initialDiagnostics,
  _RecordingProxyService? proxyService,
}) {
  return ProviderScope(
    overrides: [
      protocolServiceProvider.overrideWithValue(protocol),
      mqttClientProxyServiceProvider.overrideWithValue(
        proxyService ?? _RecordingProxyService(),
      ),
      mqttProxyDiagnosticsProvider.overrideWith(
        () => _StaticDiagnosticsNotifier(initialDiagnostics),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: const MqttConfigScreen(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  // Pump enough frames for the screen's async _loadCurrentConfig to settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'diagnostics panel renders without admin mode when proxy enabled',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final protocol = _FakeProtocolService(
        cachedConfig: _proxyEnabledConfig(),
      );
      addTearDown(protocol.closeStreams);

      await tester.pumpWidget(
        _wrap(
          protocol: protocol,
          initialDiagnostics: const MqttProxyDiagnostics(
            phase: MqttProxyConnectionPhase.connected,
            isConnected: true,
            brokerHost: 'broker.example',
            brokerPort: 1883,
          ),
        ),
      );
      await _settle(tester);

      // The diagnostics section header is visible without admin-mode gating.
      expect(find.text(_l10n.mqttProxySectionDiagnostics), findsOneWidget);
      // Status row shows the connected phase label.
      expect(find.text(_l10n.mqttProxyPhaseConnected), findsWidgets);
    },
  );

  testWidgets(
    'banner shows when proxy enabled and bridge disconnected with error',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final protocol = _FakeProtocolService(
        cachedConfig: _proxyEnabledConfig(),
      );
      addTearDown(protocol.closeStreams);

      await tester.pumpWidget(
        _wrap(
          protocol: protocol,
          initialDiagnostics: const MqttProxyDiagnostics(
            phase: MqttProxyConnectionPhase.failed,
            failureReason: MqttProxyFailureReason.tcpConnectionRefused,
            lastError: 'Connection refused',
          ),
        ),
      );
      await _settle(tester);

      expect(find.text(_l10n.mqttProxyBannerNotConnectedTitle), findsOneWidget);
      // The error itself is rendered both in the banner subtitle and the
      // diagnostics last-error row (two distinct text widgets).
      expect(find.text('Connection refused'), findsNWidgets(2));
    },
  );

  testWidgets('banner falls back to hint when no specific error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final protocol = _FakeProtocolService(cachedConfig: _proxyEnabledConfig());
    addTearDown(protocol.closeStreams);

    await tester.pumpWidget(
      _wrap(
        protocol: protocol,
        initialDiagnostics: const MqttProxyDiagnostics(
          // disconnected phase, no specific reason → fallback hint banner.
          phase: MqttProxyConnectionPhase.disconnected,
        ),
      ),
    );
    await _settle(tester);

    expect(find.text(_l10n.mqttProxyBannerNotConnectedTitle), findsOneWidget);
    expect(find.text(_l10n.mqttProxyBannerNotConnectedHint), findsOneWidget);
  });

  testWidgets('banner is absent when MQTT enabled but proxy disabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final protocol = _FakeProtocolService(
      cachedConfig: _mqttEnabledNoProxyConfig(),
    );
    addTearDown(protocol.closeStreams);

    await tester.pumpWidget(
      _wrap(
        protocol: protocol,
        initialDiagnostics: const MqttProxyDiagnostics(),
      ),
    );
    await _settle(tester);

    // The banner is gated on _proxyToClientEnabled; with proxy off it
    // must be absent — even though the diagnostics section may still
    // render because MQTT itself is enabled.
    expect(find.text(_l10n.mqttProxyBannerNotConnectedTitle), findsNothing);
  });

  testWidgets(
    'typing mqtt.meshtastic.org auto-fills meshdev / large4cats on a fresh '
    'install',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Fresh install: MQTT module enabled (so the form renders) but
      // no broker config saved yet — empty address, empty credentials.
      final cached = module_pb.ModuleConfig_MQTTConfig()
        ..enabled = true
        ..root = 'msh';
      final protocol = _FakeProtocolService(cachedConfig: cached);
      addTearDown(protocol.closeStreams);

      await tester.pumpWidget(
        _wrap(
          protocol: protocol,
          initialDiagnostics: const MqttProxyDiagnostics(),
        ),
      );
      await _settle(tester);

      final addressFinder = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == _l10n.mqttConfigServerAddressLabel,
      );
      expect(addressFinder, findsOneWidget);
      await tester.enterText(addressFinder, 'mqtt.meshtastic.org');
      await tester.pump();

      // The auth section is now hidden on the default broker (Gap 5
      // parity). Switch the address back to a custom host so the auth
      // fields re-render — at that point the controller values still
      // hold the autofilled public defaults.
      await tester.enterText(addressFinder, 'mqtt.example.com');
      await tester.pump();

      expect(find.text('meshdev'), findsOneWidget);
      // Password field is obscured, but the controller value is
      // observable through the rendered TextField widget.
      final passwordField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == _l10n.mqttConfigPasswordLabel,
        ),
      );
      expect(passwordField.controller?.text, 'large4cats');
    },
  );

  testWidgets(
    'switching to mqtt.meshtastic.org overwrites custom creds with public '
    'defaults AND hides the auth fields',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // User had previously saved a non-default broker with custom creds.
      final cached = module_pb.ModuleConfig_MQTTConfig()
        ..enabled = true
        ..address = 'mqtt.example.com'
        ..username = 'alice'
        ..password = 'sekret'
        ..root = 'msh';
      final protocol = _FakeProtocolService(cachedConfig: cached);
      addTearDown(protocol.closeStreams);

      await tester.pumpWidget(
        _wrap(
          protocol: protocol,
          initialDiagnostics: const MqttProxyDiagnostics(),
        ),
      );
      await _settle(tester);

      // The auth fields are visible while on the custom host…
      final usernameLabel = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == _l10n.mqttConfigUsernameLabel,
      );
      expect(usernameLabel, findsOneWidget);

      final addressFinder = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == _l10n.mqttConfigServerAddressLabel,
      );
      await tester.enterText(addressFinder, 'mqtt.meshtastic.org');
      await tester.pump();

      // …and disappear once the address resolves to the canonical
      // broker — the auth section is hidden because the public creds
      // are already auto-filled.
      expect(usernameLabel, findsNothing);

      // Switch back to a custom hostname so the auth fields re-render,
      // and inspect the controllers via the now-visible TextFields. If
      // the canonical-broker transition fired correctly, the creds are
      // now meshdev/large4cats — alice/sekret have been replaced.
      await tester.enterText(addressFinder, 'mqtt.example.com');
      await tester.pump();

      expect(find.text('meshdev'), findsOneWidget);
      final passwordField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == _l10n.mqttConfigPasswordLabel,
        ),
      );
      expect(passwordField.controller?.text, 'large4cats');
    },
  );
}
