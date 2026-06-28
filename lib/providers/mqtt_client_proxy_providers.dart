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
import '../core/mqtt/mqtt_preferences.dart';
import '../generated/meshtastic/mesh.pb.dart' as pb;
import '../models/mesh_models.dart' show ChannelConfig;
import '../services/mqtt/mqtt_client_proxy_service.dart';
import 'app_lifecycle_provider.dart';
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

  // When a publish detects a dead socket behind a stale `connected` phase,
  // rebuild the connection from the cached config (the service cannot do this
  // itself, as it deliberately never retains the password). Reuses the same
  // idempotent evaluator the auto-connect triggers use.
  service.setOnReconnectNeeded(() {
    unawaited(_evaluateProxyState(ref, 'publish-stale-socket'));
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

/// Evaluates the proxy state from cached MQTT config and current channel
/// downlink coverage, then either calls `connect` or `disconnect` on the
/// service. Idempotent — safe to call from multiple triggers.
///
/// Reasons used in logs (kept short, structured): `initial-build`,
/// `config-stream-emit`, `link-connected`, `app-resumed`,
/// `downlink-flag-changed`, `manual` (controller), `save-flow` (UI).
Future<void> _evaluateProxyState(Ref ref, String reason) async {
  final protocol = ref.read(protocolServiceProvider);
  final proxyService = ref.read(mqttClientProxyServiceProvider);
  final cfg = protocol.currentMqttConfig;

  if (cfg == null) {
    AppLogging.mqttProxy('evaluate($reason): no cached MQTT config; skipping');
    return;
  }

  final root = cfg.root.isNotEmpty ? cfg.root : 'msh';
  final topicPrefix = '$root/2/e'; // lint-allow: hardcoded-string

  if (cfg.enabled && cfg.proxyToClientEnabled) {
    // Map-reporting consent gate: if the radio has map-reporting on but
    // the user has NOT opted-in to the privacy disclaimer in the MQTT
    // config screen, refuse to bring the app-side proxy up. The radio's
    // MQTT module can still publish via its own onboard WiFi (if
    // present); the phone-proxy bridge stays disconnected until consent
    // is recorded. This is the runtime backstop for the same gate that
    // also runs at config-save time (`shouldReportLocation` field).
    if (cfg.mapReportingEnabled) {
      final optIn = await MqttPreferences.getMapReportingOptIn();
      if (!optIn) {
        AppLogging.mqttProxyWarning(
          'evaluate($reason): map-reporting on but consent missing — '
          'refusing to connect',
        );
        proxyService.markMissingConfig(
          MqttProxyFailureReason.mapReportingConsentRequired,
        );
        return;
      }
    }
    // Preflight gate: validate the config before attempting any connect.
    // Distinguishes missingHost / missingTopicRoot / invalidPort so the UI
    // can surface a structured reason instead of a bare "not connected".
    final preflightResult = MqttClientProxyService.preflight(
      mqttEnabled: cfg.enabled,
      proxyToClientEnabled: cfg.proxyToClientEnabled,
      address: cfg.address,
      topicRoot: root,
      tlsEnabled: cfg.tlsEnabled,
      username: cfg.username,
    );
    if (!preflightResult.ok) {
      AppLogging.mqttProxyWarning(
        'evaluate($reason): config preflight failed '
        'reason=${preflightResult.reason.name}',
      );
      proxyService.markMissingConfig(preflightResult.reason);
      return;
    }
    AppLogging.mqttProxy(
      'evaluate($reason): config preflight passed '
      'host=${preflightResult.host} port=${preflightResult.port} '
      'tls=${preflightResult.tlsEnabled} topicRoot=${preflightResult.topicRoot} '
      'usernamePresent=${preflightResult.usernamePresent}',
    );

    final channels = ref.read(channelsProvider);
    final hasAnyDownlinkEnabled = channels.any((ch) => ch.downlink);

    final myNodeNum = protocol.myNodeNum;
    final nodeUserId = myNodeNum != null
        ? '!${myNodeNum.toRadixString(16).padLeft(8, '0')}' // lint-allow: hardcoded-string
        : null;

    AppLogging.mqttProxy(
      'evaluate($reason): proxy enabled — connect '
      '(subscribe: $hasAnyDownlinkEnabled)',
    );

    proxyService.connect(
      address: cfg.address,
      tlsEnabled: cfg.tlsEnabled,
      username: cfg.username,
      password: cfg.password,
      topicPrefix: topicPrefix,
      nodeUserId: nodeUserId,
      shouldSubscribe: hasAnyDownlinkEnabled,
    );
  } else {
    // Proxy off — mark disabled so the UI distinguishes "off" from "failed".
    // Disconnect a live socket if one was previously settled.
    if (proxyService.isConnected) {
      AppLogging.mqttProxy('evaluate($reason): proxy disabled — disconnect');
      proxyService.disconnect();
    }
    proxyService.markDisabled();
  }
}

/// Watches the device's MQTT config stream, BLE link state, app
/// foreground state, and channel downlink coverage; triggers proxy
/// reconnects via the shared evaluator.
///
/// Per the official Meshtastic iOS app, the proxy only subscribes
/// (receives inbound MQTT messages) when at least one channel has
/// `downlinkEnabled = true`. Without this gate, messages are relayed
/// from the MQTT broker to the device even when the user only intended
/// to uplink, causing 0-hop MQTT delivery to appear as the primary
/// transport path.
///
/// The evaluator is idempotent — `MqttClientProxyService.connect` short-
/// circuits when the live socket already matches the requested args, so
/// firing it from many triggers (cold start, save, link-connected,
/// app-resumed, downlink-toggle, config emission) is safe.
final mqttClientProxyAutoConnectProvider = Provider<void>((ref) {
  // Watch only the stable singletons so the provider does not rebuild
  // on every channel/config change. Channels and config are read inside
  // the evaluator on demand.
  final protocol = ref.watch(protocolServiceProvider);

  // Cold-start seed: the broadcast `mqttConfigStream` does not replay,
  // so a config that arrived before this provider mounted would be lost.
  // Reading `currentMqttConfig` synchronously closes that race.
  unawaited(_evaluateProxyState(ref, 'initial-build'));

  final subscription = protocol.mqttConfigStream.listen((_) {
    unawaited(_evaluateProxyState(ref, 'config-stream-emit'));
  });

  // BLE link transitions to connected → re-evaluate (covers radio
  // reboot / BLE drop without a follow-up config emission).
  ref.listen<bool>(isLinkConnectedProvider, (previous, isConnected) {
    if (isConnected && previous != true) {
      unawaited(_evaluateProxyState(ref, 'link-connected'));
    }
  });

  // App resumes to foreground → re-evaluate (covers iOS background
  // socket teardown).
  ref.listen<bool>(appLifecycleProvider, (previous, isForeground) {
    if (isForeground && previous != true) {
      unawaited(_evaluateProxyState(ref, 'app-resumed'));
    }
  });

  // Channel downlink coverage transitions → re-evaluate. We deliberately
  // ignore unrelated channel edits (name, PSK, uplink-only flag) so a
  // routine channel rename does not trigger a destructive reconnect.
  ref.listen<List<ChannelConfig>>(channelsProvider, (previous, next) {
    final prevHas = previous?.any((c) => c.downlink) ?? false;
    final nextHas = next.any((c) => c.downlink);
    if (prevHas != nextHas) {
      unawaited(_evaluateProxyState(ref, 'downlink-flag-changed'));
    }
  });

  ref.onDispose(() {
    subscription.cancel();
    AppLogging.mqttProxy('Proxy auto-connect provider disposed');
  });
});

// ---------------------------------------------------------------------------
// Controller — entry point for callers (e.g. settings screen save flow)
// ---------------------------------------------------------------------------

/// Façade exposing a one-line refresh entry point that shares the same
/// evaluator path as the auto-connect provider. Use this when a UI
/// action (e.g. saving MQTT settings) needs to belt-and-suspender the
/// proxy state without depending on stream-replay timing.
class MqttClientProxyController {
  MqttClientProxyController(this._ref);
  final Ref _ref;

  /// Triggers an immediate evaluation of the proxy state from the
  /// current cached MQTT config. Safe to call repeatedly — the
  /// underlying connect/disconnect is idempotent.
  Future<void> refresh({String reason = 'manual'}) async {
    await _evaluateProxyState(_ref, reason);
  }
}

final mqttClientProxyControllerProvider = Provider<MqttClientProxyController>(
  MqttClientProxyController.new,
);

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
