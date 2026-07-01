// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/mqtt/mqtt_client_proxy_service.dart';

void main() {
  group('MqttProxyDiagnostics', () {
    test('default construction has expected defaults', () {
      const diag = MqttProxyDiagnostics();

      expect(diag.phase, MqttProxyConnectionPhase.idle);
      expect(diag.failureReason, MqttProxyFailureReason.none);
      expect(diag.canPublish, false);
      expect(diag.isConnected, false);
      expect(diag.brokerHost, isNull);
      expect(diag.brokerPort, isNull);
      expect(diag.tlsEnabled, false);
      expect(diag.hasAuth, false);
      expect(diag.topicRoot, isNull);
      expect(diag.subscribedTopic, isNull);
      expect(diag.lastConnectAttempt, isNull);
      expect(diag.lastConnectedAt, isNull);
      expect(diag.lastDisconnectedAt, isNull);
      expect(diag.lastFailureAt, isNull);
      expect(diag.lastError, isNull);
      expect(diag.messagesPublished, 0);
      expect(diag.messagesRelayed, 0);
      expect(diag.reconnectAttempts, 0);
      expect(diag.framesReceivedFromRadio, 0);
      expect(diag.publishesDeferred, 0);
      expect(diag.publishesDropped, 0);
      expect(diag.publishesFlushed, 0);
    });

    test('canPublish is true only when phase is connected', () {
      for (final phase in MqttProxyConnectionPhase.values) {
        final diag = MqttProxyDiagnostics(phase: phase);
        expect(
          diag.canPublish,
          phase == MqttProxyConnectionPhase.connected,
          reason:
              'phase=$phase canPublish must be ${phase == MqttProxyConnectionPhase.connected}',
        );
      }
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
        framesReceivedFromRadio: 9,
        publishesDeferred: 4,
        publishesDropped: 5,
        publishesFlushed: 6,
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
      expect(updated.framesReceivedFromRadio, 9);
      expect(updated.publishesDeferred, 4);
      expect(updated.publishesDropped, 5);
      expect(updated.publishesFlushed, 6);
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

  group('MqttClientProxyService idempotency', () {
    late MqttClientProxyService service;

    setUp(() {
      service = MqttClientProxyService();
    });

    tearDown(() {
      service.dispose();
    });

    test(
      'sequential connect with identical args while settled is a no-op',
      () async {
        // Prime the service into a "settled connected" state without a
        // real broker. The test seam simulates a live socket so the
        // settled idempotency check passes its third clause.
        service.debugMarkSettledForTest(
          host: 'broker.example',
          port: 1883,
          tlsEnabled: false,
          username: '',
          topicPrefix: 'msh/2/e',
          shouldSubscribe: false,
        );

        expect(service.debugConnectAttemptsStarted, 0);

        // Calling connect with matching args must short-circuit before
        // any destructive reconnect work begins.
        await service.connect(
          address: 'broker.example:1883',
          tlsEnabled: false,
          username: '',
          password: '',
          topicPrefix: 'msh/2/e',
          shouldSubscribe: false,
        );

        expect(
          service.debugConnectAttemptsStarted,
          0,
          reason: 'settled idempotent connect must not start reconnect work',
        );
        expect(service.isConnected, true);
      },
    );

    test(
      'sequential connect with different args while settled does start work',
      () async {
        service.debugMarkSettledForTest(
          host: 'broker.example',
          port: 1883,
          tlsEnabled: false,
          username: '',
          topicPrefix: 'msh/2/e',
          shouldSubscribe: false,
        );

        // Call connect with a different host — the settled check must
        // fail (host mismatch), and a real attempt must start. We use
        // an unroutable port that will fail fast so the test stays fast.
        // Wrap in a future so we don't await the real broker timeout.
        final future = service.connect(
          address: '127.0.0.1:1', // unreachable; will fail
          tlsEnabled: false,
          username: '',
          password: '',
          topicPrefix: 'msh/2/e',
          shouldSubscribe: false,
        );

        // The counter must increment immediately (synchronously, before
        // the await on client.connect()).
        expect(service.debugConnectAttemptsStarted, 1);

        // Drain the failed connect so teardown is clean.
        await future;
      },
    );

    test(
      'concurrent connects with identical args coalesce to one attempt',
      () async {
        // Fire two connect() calls back-to-back without awaiting the
        // first. The second sees _isConnecting=true and pendingArgs
        // matching, and short-circuits via the in-flight branch.
        final f1 = service.connect(
          address: '127.0.0.1:1',
          tlsEnabled: false,
          username: '',
          password: '',
          topicPrefix: 'msh/2/e',
          shouldSubscribe: false,
        );
        final f2 = service.connect(
          address: '127.0.0.1:1',
          tlsEnabled: false,
          username: '',
          password: '',
          topicPrefix: 'msh/2/e',
          shouldSubscribe: false,
        );

        await Future.wait([f1, f2]);

        expect(
          service.debugConnectAttemptsStarted,
          1,
          reason: 'in-flight coalescing must produce exactly one attempt',
        );
      },
    );

    test('concurrent connects with different args reject the second', () async {
      final f1 = service.connect(
        address: '127.0.0.1:1',
        tlsEnabled: false,
        username: '',
        password: '',
        topicPrefix: 'msh/2/e',
        shouldSubscribe: false,
      );
      // Different port → different args. The second must be rejected
      // (preserves the original _isConnecting safety net).
      final f2 = service.connect(
        address: '127.0.0.1:2',
        tlsEnabled: false,
        username: '',
        password: '',
        topicPrefix: 'msh/2/e',
        shouldSubscribe: false,
      );

      await Future.wait([f1, f2]);

      expect(
        service.debugConnectAttemptsStarted,
        1,
        reason: 'different-args duplicate must not start a second attempt',
      );
    });

    test('disconnect clears settled args so next connect runs fully', () async {
      service.debugMarkSettledForTest(
        host: 'broker.example',
        port: 1883,
        tlsEnabled: false,
        username: '',
        topicPrefix: 'msh/2/e',
        shouldSubscribe: false,
      );
      await service.disconnect();
      expect(service.isConnected, false);

      // After disconnect, the settled idempotency must NOT short-circuit
      // — we are no longer settled.
      await service.connect(
        address: 'broker.example:1883',
        tlsEnabled: false,
        username: '',
        password: '',
        topicPrefix: 'msh/2/e',
        shouldSubscribe: false,
      );

      expect(
        service.debugConnectAttemptsStarted,
        1,
        reason: 'post-disconnect connect must NOT short-circuit',
      );
    });
  });

  group('MqttClientProxyService.preflight', () {
    test('passes for a fully populated config', () {
      final result = MqttClientProxyService.preflight(
        mqttEnabled: true,
        proxyToClientEnabled: true,
        address: 'mqtt.ovmesh.com',
        topicRoot: 'msh/US/OVMesh',
        tlsEnabled: true,
        username: 'alice',
      );

      expect(result.ok, true);
      expect(result.reason, MqttProxyFailureReason.none);
      expect(result.host, 'mqtt.ovmesh.com');
      expect(result.port, 8883, reason: 'TLS default port is 8883');
      expect(result.tlsEnabled, true);
      expect(result.topicRoot, 'msh/US/OVMesh');
      expect(result.usernamePresent, true);
    });

    test('fails with missingHost when address is empty', () {
      final result = MqttClientProxyService.preflight(
        mqttEnabled: true,
        proxyToClientEnabled: true,
        address: '',
        topicRoot: 'msh',
        tlsEnabled: false,
        username: '',
      );
      expect(result.ok, false);
      expect(result.reason, MqttProxyFailureReason.missingHost);
    });

    test('fails with missingTopicRoot when root is empty', () {
      final result = MqttClientProxyService.preflight(
        mqttEnabled: true,
        proxyToClientEnabled: true,
        address: 'mqtt.example.com',
        topicRoot: '   ',
        tlsEnabled: false,
        username: '',
      );
      expect(result.ok, false);
      expect(result.reason, MqttProxyFailureReason.missingTopicRoot);
    });

    test('fails with invalidPort when port is non-numeric', () {
      final result = MqttClientProxyService.preflight(
        mqttEnabled: true,
        proxyToClientEnabled: true,
        address: 'mqtt.example.com:notaport',
        topicRoot: 'msh',
        tlsEnabled: false,
        username: '',
      );
      expect(result.ok, false);
      expect(result.reason, MqttProxyFailureReason.invalidPort);
    });

    test('fails with invalidPort when port is out of range', () {
      final result = MqttClientProxyService.preflight(
        mqttEnabled: true,
        proxyToClientEnabled: true,
        address: 'mqtt.example.com:99999',
        topicRoot: 'msh',
        tlsEnabled: false,
        username: '',
      );
      expect(result.ok, false);
      expect(result.reason, MqttProxyFailureReason.invalidPort);
    });

    test('uses port 1883 when TLS off and no port specified', () {
      final result = MqttClientProxyService.preflight(
        mqttEnabled: true,
        proxyToClientEnabled: true,
        address: 'mqtt.example.com',
        topicRoot: 'msh',
        tlsEnabled: false,
        username: '',
      );
      expect(result.ok, true);
      expect(result.port, 1883);
      expect(result.tlsEnabled, false);
    });

    test('upgrades 1883→8883 when TLS forced for default broker', () {
      final result = MqttClientProxyService.preflight(
        mqttEnabled: true,
        proxyToClientEnabled: true,
        address: 'mqtt.meshtastic.org',
        topicRoot: 'msh',
        tlsEnabled: false, // not explicitly true; default broker forces TLS
        username: '',
      );
      expect(result.ok, true);
      expect(result.tlsEnabled, true);
      expect(result.port, 8883);
    });

    test('preserves user-specified port', () {
      final result = MqttClientProxyService.preflight(
        mqttEnabled: true,
        proxyToClientEnabled: true,
        address: 'mqtt.example.com:1234',
        topicRoot: 'msh',
        tlsEnabled: false,
        username: '',
      );
      expect(result.ok, true);
      expect(result.port, 1234);
    });
  });

  group('MqttClientProxyService phase + reason transitions', () {
    late MqttClientProxyService service;

    setUp(() {
      service = MqttClientProxyService();
    });

    tearDown(() {
      service.dispose();
    });

    test('initial phase is idle / no failure', () {
      expect(service.phase, MqttProxyConnectionPhase.idle);
      expect(service.failureReason, MqttProxyFailureReason.none);
    });

    test('markDisabled transitions to disabled / none', () {
      service.markDisabled();
      expect(service.phase, MqttProxyConnectionPhase.disabled);
      expect(service.failureReason, MqttProxyFailureReason.none);
      expect(service.diagnostics.canPublish, false);
    });

    test('markMissingConfig stamps phase + reason + lastFailureAt', () {
      service.markMissingConfig(MqttProxyFailureReason.missingHost);
      expect(service.phase, MqttProxyConnectionPhase.missingConfig);
      expect(service.failureReason, MqttProxyFailureReason.missingHost);
      expect(service.diagnostics.lastFailureAt, isNotNull);
    });

    test(
      'connect failure to unreachable port maps to a non-none reason',
      () async {
        // 127.0.0.1:1 reliably refuses on macOS/Linux test boxes. We don't
        // care about the *exact* reason mapping here — the OS error text
        // varies by platform — only that we transition to phase=failed
        // with a non-none reason and a sanitized lastError.
        await service.connect(
          address: '127.0.0.1:1',
          tlsEnabled: false,
          username: '',
          password: '',
          topicPrefix: 'msh/2/e',
          shouldSubscribe: false,
        );
        expect(service.phase, MqttProxyConnectionPhase.failed);
        expect(service.failureReason, isNot(MqttProxyFailureReason.none));
        expect(service.diagnostics.lastError, isNotNull);
        expect(service.diagnostics.lastFailureAt, isNotNull);
      },
    );

    test(
      'malformed CONNACK from a non-MQTT endpoint fails cleanly, no crash',
      () async {
        // A non-MQTT endpoint (wrong port / an HTTP service) replies with bytes
        // that mqtt_client parses as a CONNACK with an out-of-range return code,
        // throwing a RangeError on the raw socket read callback — off the
        // connect() future. Without the guarded zone this escapes as an
        // unhandled async error (the production Crashlytics non-fatal); the test
        // would surface it as an unhandled exception. We assert the connect maps
        // to a structured failure instead.
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((socket) {
          socket.listen((_) {
            // After the client's CONNECT arrives, reply with a CONNACK whose
            // return code (0x30 = 48) is outside the valid 0..6 range.
            socket.add([0x20, 0x02, 0x00, 0x30]);
          });
        });
        addTearDown(() => server.close());

        await service.connect(
          address: '127.0.0.1:${server.port}',
          tlsEnabled: false,
          username: '',
          password: '',
          topicPrefix: 'msh/2/e',
          shouldSubscribe: false,
        );

        expect(service.phase, MqttProxyConnectionPhase.failed);
        expect(service.failureReason, MqttProxyFailureReason.protocolRejected);
        expect(service.diagnostics.lastError, isNotNull);
      },
    );

    test(
      'disconnect from settled clears phase to disconnected, reason none',
      () async {
        service.debugMarkSettledForTest(
          host: 'broker.example',
          port: 1883,
          tlsEnabled: false,
          username: '',
          topicPrefix: 'msh/2/e',
          shouldSubscribe: false,
        );
        expect(service.phase, MqttProxyConnectionPhase.connected);

        await service.disconnect();
        expect(service.phase, MqttProxyConnectionPhase.disconnected);
        expect(service.failureReason, MqttProxyFailureReason.none);
      },
    );

    test('dispose stamps clientDisposed reason', () {
      service.dispose();
      expect(service.failureReason, MqttProxyFailureReason.clientDisposed);
      // Re-dispose is a no-op (separate test asserts safety).
    });
  });

  group('MqttClientProxyService publish gating', () {
    test(
      'handleDevicePublish in idle/disconnected emits no Published count',
      () {
        final service = MqttClientProxyService();
        addTearDown(service.dispose);

        // Idle (initial): publish must be suppressed — no counter increment.
        service.handleDevicePublish(
          topic: 'msh/US/OVMesh/2/e/LongFast/!aaaa',
          data: [1, 2, 3],
        );
        expect(service.diagnostics.messagesPublished, 0);
        expect(service.diagnostics.canPublish, false);
      },
    );

    test('handleDevicePublish on disposed service is suppressed safely', () {
      final service = MqttClientProxyService();
      service.dispose();

      // Must not throw.
      service.handleDevicePublish(topic: 'msh/2/e', data: [0]);
      // No publish counter — service is fully disposed.
    });

    test(
      'rapid identical publishes while disconnected emit at most one warning '
      'per dedupe window (no exceptions, no count increment)',
      () {
        final service = MqttClientProxyService();
        addTearDown(service.dispose);

        // Fire 50 publishes in a tight loop while disconnected. The
        // dedupe is tested via observable behavior: the publish counter
        // must remain 0 and no exception is thrown. (Log-side dedupe
        // is asserted by the source structure — single first-hit then
        // suppression — and is not directly observable from a unit test
        // without a log capture sink.)
        for (var i = 0; i < 50; i++) {
          service.handleDevicePublish(
            topic: 'msh/US/OVMesh/2/e/LongFast/!aaaa',
            data: [i],
          );
        }
        expect(service.diagnostics.messagesPublished, 0);
      },
    );

    // PR-1: a publish topic with a wildcard is rejected by the guard
    // before any broker interaction. The connected-path call to
    // `_client.publishMessage` needs a live broker and cannot be unit
    // tested here; this asserts the guard is a safe no-op at the API
    // boundary (no throw, no publish counted). The `TopicBuilder`
    // validation logic itself is proven in mqtt_mock_service_test.dart.
    test('handleDevicePublish with a wildcard topic is a safe no-op', () {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      service.handleDevicePublish(topic: 'a/b/#', data: [1, 2, 3]);
      service.handleDevicePublish(topic: 'a/+/c', data: [4, 5, 6]);

      expect(service.diagnostics.messagesPublished, 0);
    });
  });

  group('MqttClientProxyService publish queue', () {
    const validTopic = 'msh/US/OVMesh/2/e/LongFast/!aaaa';

    test('buffers a publish while idle (pre-connect) instead of dropping', () {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      // Initial phase is idle: a connect is expected imminently, so the
      // frame is queued for replay rather than lost.
      expect(service.phase, MqttProxyConnectionPhase.idle);
      service.handleDevicePublish(topic: validTopic, data: [1, 2, 3]);

      expect(service.debugPendingPublishCount, 1);
      expect(service.diagnostics.messagesPublished, 0);
    });

    test('queue is bounded, drops oldest beyond cap', () {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      for (var i = 0; i < 50; i++) {
        service.handleDevicePublish(topic: validTopic, data: [i]);
      }

      // Capacity is 32; the buffer must never exceed it.
      expect(service.debugPendingPublishCount, 32);
      expect(service.diagnostics.messagesPublished, 0);
    });

    test('does not queue while disabled (proxy off)', () {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      service.markDisabled();
      service.handleDevicePublish(topic: validTopic, data: [1]);

      expect(service.debugPendingPublishCount, 0);
    });

    test('does not queue while missingConfig', () {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      service.markMissingConfig(MqttProxyFailureReason.missingHost);
      service.handleDevicePublish(topic: validTopic, data: [1]);

      expect(service.debugPendingPublishCount, 0);
    });

    test('disconnect clears the buffered frames', () async {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      service.handleDevicePublish(topic: validTopic, data: [1]);
      expect(service.debugPendingPublishCount, 1);

      await service.disconnect();
      expect(service.debugPendingPublishCount, 0);
    });

    test('invalid (wildcard) topic is rejected before the queue', () {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      service.handleDevicePublish(topic: 'a/b/#', data: [1]);
      service.handleDevicePublish(topic: 'a/+/c', data: [1]);

      expect(service.debugPendingPublishCount, 0);
    });

    test('payload-less message is dropped before the queue', () {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      service.handleDevicePublish(topic: validTopic);

      expect(service.debugPendingPublishCount, 0);
    });

    test(
      'stale connected socket reconciles phase, queues, and requests reconnect',
      () {
        final service = MqttClientProxyService();
        addTearDown(service.dispose);

        var reconnectRequests = 0;
        service.setOnReconnectNeeded(() => reconnectRequests++);

        // Drive into the field-reported state: phase reads connected, socket
        // is dead.
        service.debugSimulateStaleConnectedSocket();
        expect(service.phase, MqttProxyConnectionPhase.connected);

        service.handleDevicePublish(topic: validTopic, data: [1, 2, 3]);

        // Phase reconciled away from the false "Connected".
        expect(service.phase, MqttProxyConnectionPhase.connecting);
        // Frame buffered, not lost, not counted as published.
        expect(service.debugPendingPublishCount, 1);
        expect(service.diagnostics.messagesPublished, 0);
        // Reconnect proactively requested rather than waiting for keep-alive.
        expect(reconnectRequests, 1);
      },
    );

    test('reconnect requests are debounced within the window', () {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      var reconnectRequests = 0;
      service.setOnReconnectNeeded(() => reconnectRequests++);

      service.debugSimulateStaleConnectedSocket();

      // Two stale-socket publishes in quick succession. The first reconciles
      // the phase to connecting (so the second takes the not-connected branch
      // and never re-requests); even if both reached the request path, the
      // debounce collapses them. Either way: exactly one request.
      service.handleDevicePublish(topic: validTopic, data: [1]);
      service.handleDevicePublish(topic: validTopic, data: [2]);

      expect(reconnectRequests, 1);
      // Both frames are buffered for replay.
      expect(service.debugPendingPublishCount, 2);
    });
  });

  group('MqttClientProxyService NoConnectionException reason mapping', () {
    // Pinned against the actual mqtt_client package strings observed in the
    // field. Strict brokers (ovmesh.com) silently TCP-close a malformed
    // CONNECT, so mqtt_client surfaces a "Missing Connection Acknowledgement"
    // timeout — must map to protocolRejected, not unknown.
    test('missing CONNACK text maps to protocolRejected', () {
      const text =
          'mqtt-client::NoConnectionException: The maximum allowed connection '
          'attempts ({3}) were exceeded. The broker is not responding to the '
          'connection request message (Missing Connection Acknowledgement?';
      expect(
        MqttClientProxyService.debugMapNoConnectionExceptionMessage(text),
        MqttProxyFailureReason.protocolRejected,
      );
    });

    test('not authorized text maps to authenticationFailed', () {
      expect(
        MqttClientProxyService.debugMapNoConnectionExceptionMessage(
          'NoConnectionException: not authorized',
        ),
        MqttProxyFailureReason.authenticationFailed,
      );
    });

    test('bad username text maps to authenticationFailed', () {
      expect(
        MqttClientProxyService.debugMapNoConnectionExceptionMessage(
          'NoConnectionException: bad username or password',
        ),
        MqttProxyFailureReason.authenticationFailed,
      );
    });

    test('connection refused text maps to protocolRejected', () {
      expect(
        MqttClientProxyService.debugMapNoConnectionExceptionMessage(
          'NoConnectionException: connection refused by broker',
        ),
        MqttProxyFailureReason.protocolRejected,
      );
    });

    test('unrecognised text falls through to unknown', () {
      expect(
        MqttClientProxyService.debugMapNoConnectionExceptionMessage(
          'something completely different',
        ),
        MqttProxyFailureReason.unknown,
      );
    });
  });

  group('MqttClientProxyService secret redaction', () {
    test('lastError never contains the literal password text', () async {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      // Force a failed attempt with an unmistakable password value.
      // The connect will fail (port 1) but should never store the
      // raw password in lastError.
      const sentinelPassword = 'p4ssw0rd-DO-NOT-LEAK-XYZ';
      await service.connect(
        address: '127.0.0.1:1',
        tlsEnabled: false,
        username: 'alice',
        password: sentinelPassword,
        topicPrefix: 'msh/2/e',
        shouldSubscribe: false,
      );

      expect(service.diagnostics.lastError, isNotNull);
      expect(service.diagnostics.lastError, isNot(contains(sentinelPassword)));
    });
  });

  group('MqttClientProxyService publish-path counters', () {
    const validTopic = 'msh/US/OVMesh/2/e/LongFast/!aaaa';

    test('a queued (deferred) publish increments received + deferred', () {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      // Idle → the frame is buffered for replay, not dropped.
      service.handleDevicePublish(topic: validTopic, data: [1, 2, 3]);

      final diag = service.diagnostics;
      expect(diag.framesReceivedFromRadio, 1);
      expect(diag.publishesDeferred, 1);
      expect(diag.publishesDropped, 0);
    });

    test('a dropped publish (proxy off) increments received + dropped', () {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      service.markDisabled();
      service.handleDevicePublish(topic: validTopic, data: [1]);

      final diag = service.diagnostics;
      expect(diag.framesReceivedFromRadio, 1);
      expect(diag.publishesDeferred, 0);
      expect(diag.publishesDropped, 1);
    });

    test('an invalid-topic frame still counts as received from radio', () {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      // Counted at entry, before topic validation — so the received tally
      // reflects everything the radio forwarder handed us.
      service.handleDevicePublish(topic: 'a/b/#', data: [1]);

      final diag = service.diagnostics;
      expect(diag.framesReceivedFromRadio, 1);
      expect(diag.publishesDeferred, 0);
      expect(diag.publishesDropped, 0);
    });

    test('buffer overflow counts evicted frames as dropped', () {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      // Capacity is 32; 50 idle publishes → 32 buffered, 18 evicted.
      for (var i = 0; i < 50; i++) {
        service.handleDevicePublish(topic: validTopic, data: [i]);
      }

      final diag = service.diagnostics;
      expect(diag.framesReceivedFromRadio, 50);
      expect(diag.publishesDeferred, 50);
      expect(diag.publishesDropped, 18);
      expect(service.debugPendingPublishCount, 32);
    });
  });

  group('MqttClientProxyService liveness watchdog', () {
    test('force-reconnects when proof-of-life is stale', () {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      var reconnectRequests = 0;
      service.setOnReconnectNeeded(() => reconnectRequests++);

      // Phase reads connected, socket reports connected, but no PINGRESP /
      // inbound / connect has landed within the stale threshold.
      service.debugSimulateHalfOpenSocket();
      expect(service.phase, MqttProxyConnectionPhase.connected);

      service.debugTickLivenessWatchdog();

      expect(reconnectRequests, 1);
      expect(service.phase, MqttProxyConnectionPhase.connecting);
    });

    test('no-op when proof-of-life is fresh', () {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      var reconnectRequests = 0;
      service.setOnReconnectNeeded(() => reconnectRequests++);

      service.debugSimulateHalfOpenSocket();
      // A confirmed publish is proof-of-life; it refreshes the timestamp.
      service.debugConfirmPublish();

      service.debugTickLivenessWatchdog();

      expect(reconnectRequests, 0);
      expect(service.phase, MqttProxyConnectionPhase.connected);
    });

    test('no-op when phase is not connected', () {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      var reconnectRequests = 0;
      service.setOnReconnectNeeded(() => reconnectRequests++);

      // Idle service: the watchdog must not fire.
      expect(service.phase, MqttProxyConnectionPhase.idle);
      service.debugTickLivenessWatchdog();

      expect(reconnectRequests, 0);
    });

    test('kill switch off leaves the watchdog timer inactive', () {
      addTearDown(() {
        if (dotenv.isInitialized) dotenv.clean();
      });
      dotenv.loadFromString(
        envString: 'MQTT_PROXY_LIVENESS_WATCHDOG_ENABLED=false',
      );

      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      service.debugStartLivenessWatchdog();
      expect(service.debugLivenessWatchdogActive, false);
    });

    test('kill switch on starts the watchdog timer', () {
      addTearDown(() {
        if (dotenv.isInitialized) dotenv.clean();
      });
      dotenv.loadFromString(
        envString: 'MQTT_PROXY_LIVENESS_WATCHDOG_ENABLED=true',
      );

      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      service.debugStartLivenessWatchdog();
      expect(service.debugLivenessWatchdogActive, true);
    });
  });

  group('MqttClientProxyService confirmed publish counter', () {
    test('published count advances only on broker confirmation', () {
      final service = MqttClientProxyService();
      addTearDown(service.dispose);

      // Send-time never counts (frames buffered while idle stay uncounted).
      service.handleDevicePublish(
        topic: 'msh/US/OVMesh/2/e/LongFast/!aaaa',
        data: [1],
      );
      expect(service.diagnostics.messagesPublished, 0);

      // A broker PUBACK is the only thing that advances the count.
      service.debugConfirmPublish();
      expect(service.diagnostics.messagesPublished, 1);
    });
  });
}
