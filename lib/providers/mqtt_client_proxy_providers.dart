// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Riverpod providers for the MQTT Client Proxy feature.
///
/// These providers wire the [MqttClientProxyService] to the
/// [ProtocolService] so that client proxy MQTT works automatically
/// when the device has `proxyToClientEnabled = true`.
///
/// The proxy is lazily initialized: it only starts when the device
/// sends its MQTT config with proxy mode enabled.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../generated/meshtastic/mesh.pb.dart' as pb;
import '../services/mqtt/mqtt_client_proxy_service.dart';
import 'app_providers.dart';

// ---------------------------------------------------------------------------
// Proxy service singleton
// ---------------------------------------------------------------------------

/// Provides the singleton [MqttClientProxyService] instance.
///
/// The service is created once and shared for the lifetime of the app.
/// It is disposed when the provider container shuts down.
final mqttClientProxyServiceProvider = Provider<MqttClientProxyService>((ref) {
  final service = MqttClientProxyService();

  // Wire the broker→device callback: messages received from the MQTT
  // broker need to be forwarded to the device via ProtocolService.
  final protocol = ref.watch(protocolServiceProvider);
  service.setOnBrokerMessage((topic, data, retained) async {
    if (protocol.isConnected) {
      final proxyMsg = pb.MqttClientProxyMessage()
        ..topic = topic
        ..data = data
        ..retained = retained;
      await protocol.sendMqttClientProxyMessage(proxyMsg);
    }
  });

  ref.onDispose(() {
    service.dispose();
    AppLogging.mqttProxy('MqttClientProxyService provider disposed');
  });

  return service;
});

// ---------------------------------------------------------------------------
// Proxy message forwarder (device → broker)
// ---------------------------------------------------------------------------

/// Bridges `FromRadio.mqttClientProxyMessage` events from the device
/// to the [MqttClientProxyService] for publishing to the MQTT broker.
///
/// This is a fire-and-forget provider: reading it once starts the
/// forwarding. The subscription is cancelled on provider dispose.
final mqttClientProxyForwarderProvider = Provider<void>((ref) {
  final protocol = ref.watch(protocolServiceProvider);
  final proxyService = ref.watch(mqttClientProxyServiceProvider);

  StreamSubscription<dynamic>? subscription;

  // Forward outbound proxy messages from device to broker
  subscription = protocol.mqttClientProxyMessageStream.listen((proxyMsg) {
    // Extract fields from protobuf before passing to service
    final hasData =
        proxyMsg.whichPayloadVariant() ==
        pb.MqttClientProxyMessage_PayloadVariant.data;
    final hasText =
        proxyMsg.whichPayloadVariant() ==
        pb.MqttClientProxyMessage_PayloadVariant.text;

    proxyService.handleDevicePublish(
      topic: proxyMsg.topic,
      data: hasData ? proxyMsg.data : null,
      text: hasText ? proxyMsg.text : null,
      retained: proxyMsg.retained,
    );
  });

  ref.onDispose(() {
    subscription?.cancel();
    AppLogging.mqttProxy('Proxy message forwarder disposed');
  });
});

// ---------------------------------------------------------------------------
// Proxy auto-connect (starts proxy when device MQTT config is received)
// ---------------------------------------------------------------------------

/// Watches the device's MQTT config stream and automatically connects
/// the proxy when `proxyToClientEnabled` is true.
///
/// This provider handles the lifecycle:
/// - Connect when config arrives with proxy enabled
/// - Disconnect when config arrives with proxy disabled
/// - Reconnect when config changes (different broker, etc.)
///
/// Per the official Meshtastic iOS app, the proxy only subscribes
/// (receives inbound MQTT messages) when at least one channel has
/// `downlinkEnabled = true`. Without this gate, messages are relayed
/// from the MQTT broker to the device even when the user only intended
/// to uplink, causing 0-hop MQTT delivery to appear as the primary
/// transport path.
final mqttClientProxyAutoConnectProvider = Provider<void>((ref) {
  final protocol = ref.watch(protocolServiceProvider);
  final proxyService = ref.watch(mqttClientProxyServiceProvider);
  final channels = ref.watch(channelsProvider);

  StreamSubscription<dynamic>? subscription;

  subscription = protocol.mqttConfigStream.listen((mqttConfig) {
    final root = mqttConfig.root.isNotEmpty ? mqttConfig.root : 'msh';
    final topicPrefix = '$root/2/e'; // lint-allow: hardcoded-string

    if (mqttConfig.enabled && mqttConfig.proxyToClientEnabled) {
      // Match the official Meshtastic iOS app: only subscribe (downlink)
      // when at least one channel has downlinkEnabled == true.
      final hasAnyDownlinkEnabled = channels.any((ch) => ch.downlink);

      AppLogging.mqttProxy(
        'Device MQTT config received: proxy enabled, '
        'connecting to broker '
        '(subscribe: $hasAnyDownlinkEnabled)',
      );

      // Determine node user ID for client identification
      final myNodeNum = protocol.myNodeNum;
      final nodeUserId = myNodeNum != null
          ? '!${myNodeNum.toRadixString(16).padLeft(8, '0')}' // lint-allow: hardcoded-string
          : null;

      proxyService.connect(
        address: mqttConfig.address,
        tlsEnabled: mqttConfig.tlsEnabled,
        username: mqttConfig.username,
        password: mqttConfig.password,
        topicPrefix: topicPrefix,
        nodeUserId: nodeUserId,
        shouldSubscribe: hasAnyDownlinkEnabled,
      );
    } else if (proxyService.isConnected) {
      AppLogging.mqttProxy(
        'Device MQTT config received: proxy disabled, '
        'disconnecting from broker',
      );
      proxyService.disconnect();
    }
  });

  ref.onDispose(() {
    subscription?.cancel();
    AppLogging.mqttProxy('Proxy auto-connect provider disposed');
  });
});

// ---------------------------------------------------------------------------
// Diagnostics provider
// ---------------------------------------------------------------------------

/// Provides latest [MqttProxyDiagnostics] for the diagnostics UI.
class MqttProxyDiagnosticsNotifier extends Notifier<MqttProxyDiagnostics> {
  StreamSubscription<MqttProxyDiagnostics>? _subscription;

  @override
  MqttProxyDiagnostics build() {
    final proxyService = ref.watch(mqttClientProxyServiceProvider);

    _subscription?.cancel();
    _subscription = proxyService.diagnosticsStream.listen((diag) {
      state = diag;
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return proxyService.diagnostics;
  }
}

final mqttProxyDiagnosticsProvider =
    NotifierProvider<MqttProxyDiagnosticsNotifier, MqttProxyDiagnostics>(
      MqttProxyDiagnosticsNotifier.new,
    );
