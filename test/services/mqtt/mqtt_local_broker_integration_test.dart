// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Integration test that drives the real MqttClientProxyService against a live
// local EMQX broker (see tools/local_emqx/). It validates the two behaviours
// unit mocks cannot: that mqtt_client's `published` stream fires on a real
// QoS1 PUBACK (so the confirmed-publish counter reflects delivery), and that
// the liveness watchdog force-reconnects a frozen (half-open) socket.
//
// Skipped by default so CI and the normal suite never touch the network.
// Run it explicitly against a running broker:
//
//   RUN_MQTT_BROKER_IT=1 MQTT_IT_USER=gotnull MQTT_IT_PASS='...' \
//     flutter test test/services/mqtt/mqtt_local_broker_integration_test.dart
//
// The watchdog test controls the broker with `docker pause` / `docker unpause`
// on the `socialmesh-emqx` container.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/mqtt/mqtt_client_proxy_service.dart';

void main() {
  final enabled = Platform.environment['RUN_MQTT_BROKER_IT'] == '1';
  final Object skip = enabled
      ? false
      : 'set RUN_MQTT_BROKER_IT=1 (and a running local EMQX broker) to run';

  const address = 'localhost:1883';
  const topicPrefix = 'msh/2/e';
  const topic = 'msh/2/e/LongFast/!c1a0de01';
  const container = 'socialmesh-emqx';
  final user = Platform.environment['MQTT_IT_USER'] ?? 'gotnull';
  final pass = Platform.environment['MQTT_IT_PASS'] ?? '';

  Future<void> connect(MqttClientProxyService service) => service.connect(
    address: address,
    tlsEnabled: false,
    username: user,
    password: pass,
    topicPrefix: topicPrefix,
    nodeUserId: '!c1a0de01',
    shouldSubscribe: false,
  );

  group('MqttClientProxyService against local EMQX', () {
    test(
      'confirmed-publish counter advances only on a real PUBACK',
      () async {
        final service = MqttClientProxyService();
        addTearDown(service.dispose);

        await connect(service);
        expect(
          service.phase,
          MqttProxyConnectionPhase.connected,
          reason: 'should connect to the local broker at $address',
        );
        expect(service.diagnostics.messagesPublished, 0);

        service.handleDevicePublish(topic: topic, data: [1, 2, 3]);

        // The count must advance only when the QoS1 PUBACK completes the publish
        // protocol on client.published — the behaviour mocks cannot prove.
        await _pollUntil(() => service.diagnostics.messagesPublished == 1);
        expect(
          service.diagnostics.messagesPublished,
          1,
          reason: 'the broker PUBACK should have advanced the confirmed count',
        );
      },
      timeout: const Timeout(Duration(seconds: 40)),
    );

    test(
      'watchdog force-reconnects a frozen (half-open) broker',
      () async {
        final service = MqttClientProxyService();
        addTearDown(service.dispose);
        // Safety net: unpause if the test bailed out while frozen. Tolerant of
        // "already unpaused" since the happy path unpauses in-body.
        addTearDown(() => _unpauseQuietly(container));

        // Wire the reconnect handler the way the provider does.
        var reconnectRequests = 0;
        service.setOnReconnectNeeded(() {
          reconnectRequests++;
          unawaited(connect(service));
        });

        await connect(service);
        expect(service.phase, MqttProxyConnectionPhase.connected);

        // Freeze the broker: the TCP socket stays open with no FIN, so the
        // package's own keep-alive/auto-reconnect stays blind to the drop.
        await _docker(['pause', container]);

        // Represent the stale threshold elapsing, then run one watchdog tick.
        service.debugSetProofOfLifeStale();
        service.debugTickLivenessWatchdog();

        expect(
          reconnectRequests,
          1,
          reason: 'the watchdog should force a reconnect on the frozen socket',
        );
        expect(service.phase, MqttProxyConnectionPhase.connecting);

        // Thaw the broker so the forced reconnect can complete.
        await _docker(['unpause', container]);
        await _pollUntil(
          () => service.phase == MqttProxyConnectionPhase.connected,
        );
        expect(
          service.phase,
          MqttProxyConnectionPhase.connected,
          reason: 'the proxy should recover once the broker thaws',
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  }, skip: skip);
}

Future<void> _pollUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

// Best-effort unpause that ignores an "already unpaused" container, for use as
// a tearDown safety net alongside the happy-path in-body unpause.
Future<void> _unpauseQuietly(String container) async {
  await Process.run('docker', ['unpause', container]);
}

Future<void> _docker(List<String> args) async {
  final result = await Process.run('docker', args);
  if (result.exitCode != 0) {
    throw StateError(
      'docker ${args.join(' ')} failed (${result.exitCode}): ${result.stderr}',
    );
  }
}
