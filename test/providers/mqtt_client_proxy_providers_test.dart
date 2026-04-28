// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/module_config.pb.dart'
    as module_pb;
import 'package:socialmesh/models/mesh_models.dart' show ChannelConfig;
import 'package:socialmesh/providers/app_lifecycle_provider.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/mqtt_client_proxy_providers.dart';
import 'package:socialmesh/services/mqtt/mqtt_client_proxy_service.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

// ---------------------------------------------------------------------------
// Recording proxy service — captures connect/disconnect calls
// ---------------------------------------------------------------------------

class _RecordingProxyService extends MqttClientProxyService {
  final List<_ConnectCall> connectCalls = [];
  int disconnectCalls = 0;
  bool _fakeConnected = false;

  @override
  bool get isConnected => _fakeConnected;

  @override
  Future<void> connect({
    required String address,
    required bool tlsEnabled,
    required String username,
    required String password,
    required String topicPrefix,
    String? nodeUserId,
    bool shouldSubscribe = false,
  }) async {
    connectCalls.add(
      _ConnectCall(
        address: address,
        tlsEnabled: tlsEnabled,
        username: username,
        topicPrefix: topicPrefix,
        shouldSubscribe: shouldSubscribe,
      ),
    );
    _fakeConnected = true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    _fakeConnected = false;
  }

  void simulateDisconnected() {
    _fakeConnected = false;
  }
}

class _ConnectCall {
  _ConnectCall({
    required this.address,
    required this.tlsEnabled,
    required this.username,
    required this.topicPrefix,
    required this.shouldSubscribe,
  });

  final String address;
  final bool tlsEnabled;
  final String username;
  final String topicPrefix;
  final bool shouldSubscribe;
}

// ---------------------------------------------------------------------------
// Fake protocol service — settable currentMqttConfig + controlled stream
// ---------------------------------------------------------------------------

class _FakeProtocolService extends ProtocolService {
  _FakeProtocolService() : super(_FakeTransport());

  final StreamController<module_pb.ModuleConfig_MQTTConfig> _mqttCtrl =
      StreamController<module_pb.ModuleConfig_MQTTConfig>.broadcast();

  module_pb.ModuleConfig_MQTTConfig? _testCurrentMqttConfig;
  int? _testMyNodeNum;

  @override
  module_pb.ModuleConfig_MQTTConfig? get currentMqttConfig =>
      _testCurrentMqttConfig;

  @override
  Stream<module_pb.ModuleConfig_MQTTConfig> get mqttConfigStream =>
      _mqttCtrl.stream;

  @override
  int? get myNodeNum => _testMyNodeNum;

  void setCurrentMqttConfig(module_pb.ModuleConfig_MQTTConfig? cfg) {
    _testCurrentMqttConfig = cfg;
  }

  void emitMqttConfig(module_pb.ModuleConfig_MQTTConfig cfg) {
    _testCurrentMqttConfig = cfg;
    _mqttCtrl.add(cfg);
  }

  void setMyNodeNum(int? n) {
    _testMyNodeNum = n;
  }

  Future<void> closeStreams() async {
    await _mqttCtrl.close();
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

// ---------------------------------------------------------------------------
// Test-only providers used to drive isLinkConnectedProvider override
// ---------------------------------------------------------------------------

class _TestBoolNotifier extends Notifier<bool> {
  _TestBoolNotifier(this._initial);
  final bool _initial;

  @override
  bool build() => _initial;

  set value(bool v) => state = v;
}

final _testLinkProvider = NotifierProvider<_TestBoolNotifier, bool>(
  () => _TestBoolNotifier(false),
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

module_pb.ModuleConfig_MQTTConfig _proxyEnabledConfig({
  String address = 'broker.example:1883',
  bool tlsEnabled = false,
  String username = 'u',
  String password = 'p',
  String root = 'msh',
}) {
  return module_pb.ModuleConfig_MQTTConfig()
    ..enabled = true
    ..proxyToClientEnabled = true
    ..address = address
    ..username = username
    ..password = password
    ..tlsEnabled = tlsEnabled
    ..root = root;
}

module_pb.ModuleConfig_MQTTConfig _proxyDisabledConfig() {
  return module_pb.ModuleConfig_MQTTConfig()
    ..enabled = true
    ..proxyToClientEnabled = false
    ..address = 'broker.example:1883'
    ..root = 'msh';
}

ChannelConfig _channel({required int index, required bool downlink}) {
  return ChannelConfig(
    index: index,
    name: 'ch$index',
    psk: const <int>[],
    role: 'SECONDARY',
    uplink: true,
    downlink: downlink,
  );
}

ProviderContainer _makeContainer({
  required _FakeProtocolService protocol,
  required _RecordingProxyService proxyService,
  bool initialLinkConnected = true,
  bool initialAppForeground = true,
}) {
  final container = ProviderContainer(
    overrides: [
      protocolServiceProvider.overrideWithValue(protocol),
      mqttClientProxyServiceProvider.overrideWithValue(proxyService),
      _testLinkProvider.overrideWith(
        () => _TestBoolNotifier(initialLinkConnected),
      ),
      isLinkConnectedProvider.overrideWith(
        (ref) => ref.watch(_testLinkProvider),
      ),
    ],
  );

  if (!initialAppForeground) {
    container
        .read(appLifecycleProvider.notifier)
        .didChangeAppLifecycleState(AppLifecycleState.paused);
  }

  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mqttClientProxyAutoConnectProvider', () {
    late _FakeProtocolService protocol;
    late _RecordingProxyService proxyService;
    late ProviderContainer container;

    setUp(() {
      protocol = _FakeProtocolService();
      protocol.setMyNodeNum(0xDEADBEEF);
      proxyService = _RecordingProxyService();
    });

    tearDown(() async {
      container.dispose();
      await protocol.closeStreams();
    });

    test('cold start with cached proxy-enabled config triggers connect', () {
      protocol.setCurrentMqttConfig(_proxyEnabledConfig());
      container = _makeContainer(
        protocol: protocol,
        proxyService: proxyService,
      );

      // Mount the provider — the synchronous `initial-build` evaluation
      // should fire connect from the cached config.
      container.read(mqttClientProxyAutoConnectProvider);

      expect(proxyService.connectCalls, hasLength(1));
      expect(proxyService.connectCalls.first.address, 'broker.example:1883');
      expect(proxyService.connectCalls.first.shouldSubscribe, false);
    });

    test('cold start with no cached config does nothing', () {
      protocol.setCurrentMqttConfig(null);
      container = _makeContainer(
        protocol: protocol,
        proxyService: proxyService,
      );

      container.read(mqttClientProxyAutoConnectProvider);

      expect(proxyService.connectCalls, isEmpty);
      expect(proxyService.disconnectCalls, 0);
    });

    test('config stream emit triggers connect after mount', () async {
      // No cached config at mount → no connect.
      container = _makeContainer(
        protocol: protocol,
        proxyService: proxyService,
      );
      container.read(mqttClientProxyAutoConnectProvider);
      expect(proxyService.connectCalls, isEmpty);

      // Device emits a config — auto-connect must react.
      protocol.emitMqttConfig(_proxyEnabledConfig());
      // Stream delivery happens in the microtask queue.
      await Future<void>.delayed(Duration.zero);
      expect(proxyService.connectCalls, hasLength(1));
    });

    test(
      'config stream emit with proxy disabled triggers disconnect',
      () async {
        // Pre-condition: provider is mounted and currently connected.
        protocol.setCurrentMqttConfig(_proxyEnabledConfig());
        container = _makeContainer(
          protocol: protocol,
          proxyService: proxyService,
        );
        container.read(mqttClientProxyAutoConnectProvider);
        expect(proxyService.connectCalls, hasLength(1));

        // Device emits a config with proxy disabled.
        protocol.emitMqttConfig(_proxyDisabledConfig());
        await Future<void>.delayed(Duration.zero);

        expect(proxyService.disconnectCalls, 1);
      },
    );

    test('link transition false→true triggers re-evaluate', () async {
      protocol.setCurrentMqttConfig(_proxyEnabledConfig());
      container = _makeContainer(
        protocol: protocol,
        proxyService: proxyService,
        initialLinkConnected: false,
      );
      container.read(mqttClientProxyAutoConnectProvider);
      // Sanity: initial overridden value should be `false`.
      expect(container.read(isLinkConnectedProvider), false);
      // Mount evaluated once already.
      expect(proxyService.connectCalls, hasLength(1));

      // Flip link to connected → evaluator must run again.
      container.read(_testLinkProvider.notifier).value = true;
      // Verify propagation to the overridden Provider<bool>.
      expect(container.read(isLinkConnectedProvider), true);
      await pumpEventQueue();

      expect(proxyService.connectCalls, hasLength(2));
    });

    test('app foreground resume triggers re-evaluate', () async {
      protocol.setCurrentMqttConfig(_proxyEnabledConfig());
      container = _makeContainer(
        protocol: protocol,
        proxyService: proxyService,
      );
      container.read(mqttClientProxyAutoConnectProvider);
      expect(proxyService.connectCalls, hasLength(1));

      // Background → foreground transition.
      final lifecycle = container.read(appLifecycleProvider.notifier);
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(proxyService.connectCalls, hasLength(2));
    });

    test(
      'channel update without downlink-coverage change does NOT reconnect',
      () async {
        protocol.setCurrentMqttConfig(_proxyEnabledConfig());
        container = _makeContainer(
          protocol: protocol,
          proxyService: proxyService,
        );
        // Seed channels with one downlink-disabled channel.
        container
            .read(channelsProvider.notifier)
            .setChannel(_channel(index: 0, downlink: false));
        container.read(mqttClientProxyAutoConnectProvider);
        await Future<void>.delayed(Duration.zero);
        final baseline = proxyService.connectCalls.length;

        // Add another channel, also downlink-disabled — coverage unchanged.
        container
            .read(channelsProvider.notifier)
            .setChannel(_channel(index: 1, downlink: false));
        await Future<void>.delayed(Duration.zero);

        expect(
          proxyService.connectCalls.length,
          baseline,
          reason: 'unrelated channel edit must not trigger reconnect',
        );
      },
    );

    test(
      'channel downlink-coverage transition triggers reconnect with subscribe',
      () async {
        protocol.setCurrentMqttConfig(_proxyEnabledConfig());
        container = _makeContainer(
          protocol: protocol,
          proxyService: proxyService,
        );
        container
            .read(channelsProvider.notifier)
            .setChannel(_channel(index: 0, downlink: false));
        container.read(mqttClientProxyAutoConnectProvider);
        await Future<void>.delayed(Duration.zero);
        expect(proxyService.connectCalls.last.shouldSubscribe, false);

        // Enable downlink on a channel — coverage flips false → true.
        container
            .read(channelsProvider.notifier)
            .setChannel(_channel(index: 0, downlink: true));
        await Future<void>.delayed(Duration.zero);

        expect(
          proxyService.connectCalls.last.shouldSubscribe,
          true,
          reason: 'downlink-flag flip must update shouldSubscribe',
        );
      },
    );
  });

  group('MqttClientProxyController', () {
    late _FakeProtocolService protocol;
    late _RecordingProxyService proxyService;
    late ProviderContainer container;

    setUp(() {
      protocol = _FakeProtocolService();
      protocol.setMyNodeNum(1);
      proxyService = _RecordingProxyService();
    });

    tearDown(() async {
      container.dispose();
      await protocol.closeStreams();
    });

    test('refresh() with cached proxy-enabled config calls connect', () async {
      protocol.setCurrentMqttConfig(_proxyEnabledConfig());
      container = _makeContainer(
        protocol: protocol,
        proxyService: proxyService,
      );

      final controller = container.read(mqttClientProxyControllerProvider);
      await controller.refresh(reason: 'unit-test');

      expect(proxyService.connectCalls, hasLength(1));
    });

    test('refresh() with no cached config is a no-op', () async {
      protocol.setCurrentMqttConfig(null);
      container = _makeContainer(
        protocol: protocol,
        proxyService: proxyService,
      );

      final controller = container.read(mqttClientProxyControllerProvider);
      await controller.refresh(reason: 'unit-test');

      expect(proxyService.connectCalls, isEmpty);
      expect(proxyService.disconnectCalls, 0);
    });

    test('refresh() with proxy-disabled cached config disconnects when '
        'service is connected', () async {
      protocol.setCurrentMqttConfig(_proxyDisabledConfig());
      container = _makeContainer(
        protocol: protocol,
        proxyService: proxyService,
      );
      // Seed the recording service into "connected" state.
      await proxyService.connect(
        address: 'foo',
        tlsEnabled: false,
        username: '',
        password: '',
        topicPrefix: 'msh/2/e',
      );

      final controller = container.read(mqttClientProxyControllerProvider);
      await controller.refresh(reason: 'unit-test');

      expect(proxyService.disconnectCalls, 1);
    });
  });
}
