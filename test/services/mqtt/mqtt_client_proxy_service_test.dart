// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/mqtt/mqtt_client_proxy_service.dart';

void main() {
  group('MqttProxyDiagnostics', () {
    test('default construction has expected defaults', () {
      const diag = MqttProxyDiagnostics();

      expect(diag.isConnected, false);
      expect(diag.brokerHost, isNull);
      expect(diag.brokerPort, isNull);
      expect(diag.tlsEnabled, false);
      expect(diag.hasAuth, false);
      expect(diag.subscribedTopic, isNull);
      expect(diag.lastConnectAttempt, isNull);
      expect(diag.lastConnectedAt, isNull);
      expect(diag.lastDisconnectedAt, isNull);
      expect(diag.lastError, isNull);
      expect(diag.messagesPublished, 0);
      expect(diag.messagesRelayed, 0);
      expect(diag.reconnectAttempts, 0);
    });

    test('construction with custom values', () {
      final now = DateTime.now();
      final diag = MqttProxyDiagnostics(
        isConnected: true,
        brokerHost: 'mqtt.example.com',
        brokerPort: 8883,
        tlsEnabled: true,
        hasAuth: true,
        subscribedTopic: 'msh/2/e/#',
        lastConnectAttempt: now,
        lastConnectedAt: now,
        lastDisconnectedAt: now,
        lastError: 'test error',
        messagesPublished: 42,
        messagesRelayed: 17,
        reconnectAttempts: 3,
      );

      expect(diag.isConnected, true);
      expect(diag.brokerHost, 'mqtt.example.com');
      expect(diag.brokerPort, 8883);
      expect(diag.tlsEnabled, true);
      expect(diag.hasAuth, true);
      expect(diag.subscribedTopic, 'msh/2/e/#');
      expect(diag.lastConnectAttempt, now);
      expect(diag.lastConnectedAt, now);
      expect(diag.lastDisconnectedAt, now);
      expect(diag.lastError, 'test error');
      expect(diag.messagesPublished, 42);
      expect(diag.messagesRelayed, 17);
      expect(diag.reconnectAttempts, 3);
    });

    test('copyWith preserves unspecified fields', () {
      final original = MqttProxyDiagnostics(
        isConnected: true,
        brokerHost: 'mqtt.example.com',
        brokerPort: 8883,
        tlsEnabled: true,
        hasAuth: true,
        messagesPublished: 10,
        messagesRelayed: 5,
      );

      final updated = original.copyWith(isConnected: false, lastError: 'lost');

      expect(updated.isConnected, false);
      expect(updated.lastError, 'lost');
      // Preserved from original
      expect(updated.brokerHost, 'mqtt.example.com');
      expect(updated.brokerPort, 8883);
      expect(updated.tlsEnabled, true);
      expect(updated.hasAuth, true);
      expect(updated.messagesPublished, 10);
      expect(updated.messagesRelayed, 5);
    });

    test('copyWith overrides all fields', () {
      const original = MqttProxyDiagnostics();
      final now = DateTime.now();

      final updated = original.copyWith(
        isConnected: true,
        brokerHost: 'host',
        brokerPort: 1883,
        tlsEnabled: true,
        hasAuth: true,
        subscribedTopic: 'test/#',
        lastConnectAttempt: now,
        lastConnectedAt: now,
        lastDisconnectedAt: now,
        lastError: 'err',
        messagesPublished: 1,
        messagesRelayed: 2,
        reconnectAttempts: 3,
      );

      expect(updated.isConnected, true);
      expect(updated.brokerHost, 'host');
      expect(updated.brokerPort, 1883);
      expect(updated.tlsEnabled, true);
      expect(updated.hasAuth, true);
      expect(updated.subscribedTopic, 'test/#');
      expect(updated.lastConnectAttempt, now);
      expect(updated.lastConnectedAt, now);
      expect(updated.lastDisconnectedAt, now);
      expect(updated.lastError, 'err');
      expect(updated.messagesPublished, 1);
      expect(updated.messagesRelayed, 2);
      expect(updated.reconnectAttempts, 3);
    });
  });

  group('MqttClientProxyService', () {
    late MqttClientProxyService service;

    setUp(() {
      service = MqttClientProxyService();
    });

    tearDown(() {
      service.dispose();
    });

    test('initial state is disconnected', () {
      expect(service.isConnected, false);
      expect(service.diagnostics.isConnected, false);
      expect(service.diagnostics.brokerHost, isNull);
      expect(service.diagnostics.messagesPublished, 0);
      expect(service.diagnostics.messagesRelayed, 0);
    });

    test('diagnosticsStream emits initial state', () async {
      // The diagnostics stream should be a broadcast stream
      expect(service.diagnosticsStream, isA<Stream<MqttProxyDiagnostics>>());
    });

    test('setOnBrokerMessage accepts callback', () {
      // Should not throw
      service.setOnBrokerMessage((topic, data, retained) async {});
    });

    test('handleDevicePublish does nothing when not connected', () {
      // Should not throw when called while disconnected
      service.handleDevicePublish(topic: 'test/topic', data: [1, 2, 3]);

      expect(service.diagnostics.messagesPublished, 0);
    });

    test('disconnect from initial state does not throw', () async {
      // Should be safe to call even when never connected
      await service.disconnect();
      expect(service.isConnected, false);
    });

    test('dispose prevents further operations', () {
      service.dispose();

      // Double dispose should be safe
      service.dispose();
    });

    test('diagnostics stream closes after dispose', () async {
      final stream = service.diagnosticsStream;
      service.dispose();

      // Stream should complete after dispose
      await expectLater(stream, emitsDone);
    });
  });
}
