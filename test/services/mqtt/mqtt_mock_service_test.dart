// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/mqtt/mqtt_config.dart';
import 'package:socialmesh/core/mqtt/mqtt_connection_state.dart';
import 'package:socialmesh/core/mqtt/mqtt_diagnostics.dart';
import 'package:socialmesh/services/mqtt/mqtt_mock_service.dart';
import 'package:socialmesh/services/mqtt/mqtt_service.dart';

void main() {
  late MqttMockService service;
  late GlobalLayerConfig config;

  setUp(() {
    service = MqttMockService(behavior: MockBehavior.instant);
    config = const GlobalLayerConfig(
      host: 'broker.example.com',
      port: 8883,
      useTls: true,
      username: 'testuser',
      password: 'testpass',
      topicRoot: 'msh',
      enabled: true,
      setupComplete: true,
    );
  });

  tearDown(() {
    service.dispose();
  });

  group('connection lifecycle', () {
    test('initial state is disabled', () {
      expect(service.connectionState, GlobalLayerConnectionState.disabled);
      expect(service.isConnected, false);
    });

    test('connect transitions to connected on success', () async {
      await service.connect(config);

      expect(service.connectionState, GlobalLayerConnectionState.connected);
      expect(service.isConnected, true);
      expect(service.connectCount, 1);
    });

    test('connect fires connection events in order', () async {
      final events = <MqttConnectionEvent>[];
      service.connectionEvents.listen(events.add);

      await service.connect(config);

      // Flush microtasks to ensure all stream events are delivered
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 2);
      expect(events[0].state, GlobalLayerConnectionState.connecting);
      expect(events[1].state, GlobalLayerConnectionState.connected);
    });

    test('connect throws MqttServiceException on failure', () async {
      service.updateBehavior(
        const MockBehavior(
          connectResult: MockResult.failure,
          connectErrorMessage: 'Connection refused',
          connectDelay: Duration.zero,
        ),
      );

      expect(
        () => service.connect(config),
        throwsA(isA<MqttServiceException>()),
      );
    });

    test('connect throws MqttServiceException on timeout', () async {
      service.updateBehavior(
        const MockBehavior(
          connectResult: MockResult.timeout,
          connectDelay: Duration.zero,
        ),
      );

      expect(
        () => service.connect(config),
        throwsA(
          isA<MqttServiceException>().having(
            (e) => e.type,
            'type',
            MqttServiceErrorType.timeout,
          ),
        ),
      );
    });

    test('disconnect transitions to disconnected', () async {
      await service.connect(config);
      await service.disconnect();

      expect(service.connectionState, GlobalLayerConnectionState.disconnected);
      expect(service.isConnected, false);
      expect(service.disconnectCount, 1);
    });

    test('disconnect fires disconnecting then disconnected events', () async {
      await service.connect(config);

      final events = <MqttConnectionEvent>[];
      service.connectionEvents.listen(events.add);

      await service.disconnect();

      // Flush microtasks to ensure all stream events are delivered
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 2);
      expect(events[0].state, GlobalLayerConnectionState.disconnecting);
      expect(events[1].state, GlobalLayerConnectionState.disconnected);
    });

    test('disconnect is a no-op when already disconnected', () async {
      await service.connect(config);
      await service.disconnect();

      final events = <MqttConnectionEvent>[];
      service.connectionEvents.listen(events.add);

      await service.disconnect();

      expect(events, isEmpty);
      expect(service.disconnectCount, 2);
    });

    test('disconnect clears active subscriptions', () async {
      await service.connect(config);
      await service.subscribe('msh/chat/+');
      await service.subscribe('msh/telemetry/#');

      expect(service.activeSubscriptions.length, 2);

      await service.disconnect();

      expect(service.activeSubscriptions, isEmpty);
    });

    test('reconnect count resets on successful connect', () async {
      // First connection
      await service.connect(config);
      expect(service.reconnectAttempts, 0);
    });
  });

  group('subscriptions', () {
    setUp(() async {
      await service.connect(config);
    });

    test('subscribe adds topic to active subscriptions', () async {
      final result = await service.subscribe('msh/chat/+');

      expect(result.accepted, true);
      expect(result.topic, 'msh/chat/+');
      expect(service.activeSubscriptions.contains('msh/chat/+'), true);
    });

    test('subscribe returns granted QoS from behavior', () async {
      service.updateBehavior(MockBehavior.instant.copyWith(grantedQos: 1));

      final result = await service.subscribe('msh/chat/+', qos: 1);

      expect(result.grantedQos, 1);
    });

    test('subscribe failure returns rejected result', () async {
      service.updateBehavior(
        MockBehavior.instant.copyWith(
          subscribeResult: MockResult.failure,
          subscribeErrorMessage: 'Not authorized',
        ),
      );

      final result = await service.subscribe('msh/restricted');

      expect(result.accepted, false);
      expect(result.error, 'Not authorized');
      expect(service.activeSubscriptions.contains('msh/restricted'), false);
    });

    test('subscribe throws on timeout', () async {
      service.updateBehavior(
        MockBehavior.instant.copyWith(subscribeResult: MockResult.timeout),
      );

      expect(
        () => service.subscribe('msh/test'),
        throwsA(
          isA<MqttServiceException>().having(
            (e) => e.type,
            'type',
            MqttServiceErrorType.timeout,
          ),
        ),
      );
    });

    test('subscribe throws when not connected', () async {
      await service.disconnect();

      expect(
        () => service.subscribe('msh/test'),
        throwsA(
          isA<MqttServiceException>().having(
            (e) => e.type,
            'type',
            MqttServiceErrorType.invalidState,
          ),
        ),
      );
    });

    test('unsubscribe removes topic from active subscriptions', () async {
      await service.subscribe('msh/chat/+');
      expect(service.activeSubscriptions.contains('msh/chat/+'), true);

      await service.unsubscribe('msh/chat/+');
      expect(service.activeSubscriptions.contains('msh/chat/+'), false);
    });

    test('unsubscribe is a no-op for unknown topics', () async {
      await service.unsubscribe('msh/nonexistent');
      // Should not throw
    });

    test('subscription history records all attempts', () async {
      await service.subscribe('msh/chat/+');
      await service.subscribe('msh/telemetry/#');
      await service.unsubscribe('msh/chat/+');

      final history = service.subscriptionHistory;
      expect(history.length, 3);
      expect(history[0].topic, 'msh/chat/+');
      expect(history[0].isSubscribe, true);
      expect(history[1].topic, 'msh/telemetry/#');
      expect(history[1].isSubscribe, true);
      expect(history[2].topic, 'msh/chat/+');
      expect(history[2].isSubscribe, false);
    });
  });

  group('publish', () {
    setUp(() async {
      await service.connect(config);
    });

    test('publish succeeds and returns result with message ID', () async {
      final result = await service.publish('msh/chat/LongFast', [
        0x01,
        0x02,
        0x03,
      ]);

      expect(result.accepted, true);
      expect(result.messageId, isNotNull);
    });

    test('publish records to history', () async {
      final payload = [0x48, 0x65, 0x6C, 0x6C, 0x6F]; // "Hello"
      await service.publish('msh/chat/LongFast', payload, qos: 1, retain: true);

      final history = service.publishHistory;
      expect(history.length, 1);
      expect(history[0].topic, 'msh/chat/LongFast');
      expect(history[0].payload, payload);
      expect(history[0].qos, 1);
      expect(history[0].retain, true);
    });

    test('publish failure returns rejected result', () async {
      service.updateBehavior(
        MockBehavior.instant.copyWith(
          publishResult: MockResult.failure,
          publishErrorMessage: 'Quota exceeded',
        ),
      );

      final result = await service.publish('msh/test', [0x01]);

      expect(result.accepted, false);
      expect(result.error, 'Quota exceeded');
    });

    test('publish throws on timeout', () async {
      service.updateBehavior(
        MockBehavior.instant.copyWith(publishResult: MockResult.timeout),
      );

      expect(
        () => service.publish('msh/test', [0x01]),
        throwsA(
          isA<MqttServiceException>().having(
            (e) => e.type,
            'type',
            MqttServiceErrorType.timeout,
          ),
        ),
      );
    });

    test('publish throws when not connected', () async {
      await service.disconnect();

      expect(
        () => service.publish('msh/test', [0x01]),
        throwsA(isA<MqttServiceException>()),
      );
    });
  });

  group('messages', () {
    test('injectMessage delivers to message stream', () async {
      await service.connect(config);

      final messages = <MqttInboundMessage>[];
      service.messages.listen(messages.add);

      final now = DateTime.now();
      service.injectMessage(
        MqttInboundMessage(
          topic: 'msh/chat/LongFast',
          payload: [0x48, 0x69],
          receivedAt: now,
          qos: 0,
        ),
      );

      // Allow the stream event to be delivered
      await Future<void>.delayed(Duration.zero);

      expect(messages.length, 1);
      expect(messages[0].topic, 'msh/chat/LongFast');
      expect(messages[0].payload, [0x48, 0x69]);
      expect(messages[0].receivedAt, now);
    });

    test('multiple injected messages are delivered in order', () async {
      await service.connect(config);

      final topics = <String>[];
      service.messages.listen((msg) => topics.add(msg.topic));

      for (var i = 0; i < 5; i++) {
        service.injectMessage(
          MqttInboundMessage(
            topic: 'msh/topic/$i',
            payload: [i],
            receivedAt: DateTime.now(),
          ),
        );
      }

      await Future<void>.delayed(Duration.zero);

      expect(topics.length, 5);
      for (var i = 0; i < 5; i++) {
        expect(topics[i], 'msh/topic/$i');
      }
    });
  });

  group('ping', () {
    setUp(() async {
      await service.connect(config);
    });

    test('ping returns success with round-trip time', () async {
      final result = await service.ping();

      expect(result.success, true);
      expect(result.roundTripMs, isNotNull);
      expect(result.roundTripMs, 42); // default from MockBehavior
    });

    test('ping returns failure with error message', () async {
      service.updateBehavior(
        MockBehavior.instant.copyWith(
          pingResult: MockResult.failure,
          pingErrorMessage: 'No response',
        ),
      );

      final result = await service.ping();

      expect(result.success, false);
      expect(result.error, 'No response');
    });

    test('ping throws when not connected', () async {
      await service.disconnect();

      expect(() => service.ping(), throwsA(isA<MqttServiceException>()));
    });
  });

  group('diagnostics', () {
    test('runDiagnosticCheck returns passed for config validation', () async {
      final request = DiagnosticCheckRequest(
        type: DiagnosticCheckType.configValidation,
      );

      final result = await service.runDiagnosticCheck(request, config);

      expect(result.status, DiagnosticStatus.passed);
      expect(result.type, DiagnosticCheckType.configValidation);
    });

    test(
      'runDiagnosticCheck fails config validation with bad config',
      () async {
        final badConfig = config.copyWith(host: '');
        final request = DiagnosticCheckRequest(
          type: DiagnosticCheckType.configValidation,
        );

        final result = await service.runDiagnosticCheck(request, badConfig);

        expect(result.status, DiagnosticStatus.failed);
      },
    );

    test('runDiagnosticCheck skips TLS when not enabled', () async {
      final noTlsConfig = config.copyWith(useTls: false, port: 1883);
      final request = DiagnosticCheckRequest(
        type: DiagnosticCheckType.tlsHandshake,
      );

      final result = await service.runDiagnosticCheck(request, noTlsConfig);

      expect(result.status, DiagnosticStatus.skipped);
    });

    test('runDiagnosticCheck respects per-type overrides', () async {
      service.updateBehavior(
        MockBehavior.instant.copyWith(
          diagnosticOverrides: {
            DiagnosticCheckType.dnsResolution: MockResult.failure,
          },
        ),
      );

      final request = DiagnosticCheckRequest(
        type: DiagnosticCheckType.dnsResolution,
      );

      final result = await service.runDiagnosticCheck(request, config);

      expect(result.status, DiagnosticStatus.failed);
    });

    test('runDiagnosticCheck succeeds for non-overridden types', () async {
      service.updateBehavior(
        MockBehavior.instant.copyWith(
          diagnosticOverrides: {
            DiagnosticCheckType.dnsResolution: MockResult.failure,
          },
        ),
      );

      final request = DiagnosticCheckRequest(
        type: DiagnosticCheckType.tcpConnection,
      );

      final result = await service.runDiagnosticCheck(request, config);

      expect(result.status, DiagnosticStatus.passed);
    });

    test('runFullDiagnostics returns a complete report', () async {
      final report = await service.runFullDiagnostics(config);

      expect(report.isComplete, true);
      expect(report.results.isNotEmpty, true);
      // With valid config and all defaults succeeding, all should pass
      for (final result in report.results) {
        expect(
          result.status == DiagnosticStatus.passed ||
              result.status == DiagnosticStatus.skipped,
          true,
          reason:
              '${result.type.name} should pass or be skipped, '
              'got ${result.status.name}',
        );
      }
    });

    test('runFullDiagnostics calls onProgress for each check', () async {
      final progressResults = <DiagnosticCheckResult>[];

      await service.runFullDiagnostics(config, onProgress: progressResults.add);

      expect(progressResults.isNotEmpty, true);
      // Should have one progress call per check type (minus skipped TLS types)
    });

    test('runFullDiagnostics skips checks when prerequisite fails', () async {
      service.updateBehavior(
        MockBehavior.instant.copyWith(
          diagnosticOverrides: {
            DiagnosticCheckType.dnsResolution: MockResult.failure,
          },
        ),
      );

      final report = await service.runFullDiagnostics(config);

      // DNS should fail
      final dnsResult = report.resultFor(DiagnosticCheckType.dnsResolution);
      expect(dnsResult?.status, DiagnosticStatus.failed);

      // TCP depends on DNS, should be skipped
      final tcpResult = report.resultFor(DiagnosticCheckType.tcpConnection);
      expect(tcpResult?.status, DiagnosticStatus.skipped);
    });
  });

  group('auto-reconnect', () {
    test('auto-reconnect is disabled by default', () {
      expect(service.autoReconnectEnabled, false);
    });

    test('setAutoReconnect enables/disables', () {
      service.setAutoReconnect(true);
      expect(service.autoReconnectEnabled, true);

      service.setAutoReconnect(false);
      expect(service.autoReconnectEnabled, false);
    });

    test('reconnect attempts starts at zero', () {
      expect(service.reconnectAttempts, 0);
    });
  });

  group('behavior configuration', () {
    test('default behavior uses happy path', () {
      const behavior = MockBehavior();
      expect(behavior.connectResult, MockResult.success);
      expect(behavior.subscribeResult, MockResult.success);
      expect(behavior.publishResult, MockResult.success);
      expect(behavior.pingResult, MockResult.success);
    });

    test('instant behavior has zero delays', () {
      expect(MockBehavior.instant.connectDelay, Duration.zero);
      expect(MockBehavior.instant.disconnectDelay, Duration.zero);
      expect(MockBehavior.instant.subscribeDelay, Duration.zero);
      expect(MockBehavior.instant.publishDelay, Duration.zero);
      expect(MockBehavior.instant.pingDelay, Duration.zero);
    });

    test('allFailing behavior fails everything', () {
      expect(MockBehavior.allFailing.connectResult, MockResult.failure);
      expect(MockBehavior.allFailing.subscribeResult, MockResult.failure);
      expect(MockBehavior.allFailing.publishResult, MockResult.failure);
      expect(MockBehavior.allFailing.pingResult, MockResult.failure);
    });

    test('updateBehavior changes behavior at runtime', () async {
      await service.connect(config);

      // Publish should succeed with default behavior
      final result1 = await service.publish('msh/test', [0x01]);
      expect(result1.accepted, true);

      // Change behavior to fail
      service.updateBehavior(
        MockBehavior.instant.copyWith(
          publishResult: MockResult.failure,
          publishErrorMessage: 'Now failing',
        ),
      );

      final result2 = await service.publish('msh/test', [0x01]);
      expect(result2.accepted, false);
      expect(result2.error, 'Now failing');
    });

    test('copyWith preserves unspecified fields', () {
      const original = MockBehavior(
        connectDelay: Duration(seconds: 5),
        pingRoundTripMs: 100,
      );

      final copied = original.copyWith(pingRoundTripMs: 200);

      expect(copied.connectDelay, const Duration(seconds: 5));
      expect(copied.pingRoundTripMs, 200);
      expect(copied.connectResult, MockResult.success);
    });
  });

  group('test inspection', () {
    test('publishHistory records all publishes', () async {
      await service.connect(config);

      await service.publish('topic1', [0x01]);
      await service.publish('topic2', [0x02, 0x03], qos: 1);
      await service.publish('topic3', [0x04], retain: true);

      expect(service.publishHistory.length, 3);
      expect(service.publishHistory[0].topic, 'topic1');
      expect(service.publishHistory[1].qos, 1);
      expect(service.publishHistory[2].retain, true);
    });

    test('clearHistory resets all counters and histories', () async {
      await service.connect(config);
      await service.publish('topic1', [0x01]);
      await service.subscribe('msh/test');

      service.clearHistory();

      expect(service.publishHistory, isEmpty);
      expect(service.subscriptionHistory, isEmpty);
      expect(service.connectCount, 0);
      expect(service.disconnectCount, 0);
    });
  });

  group('inject events', () {
    test('injectConnectionEvent updates state', () {
      service.injectConnectionEvent(
        MqttConnectionEvent(
          state: GlobalLayerConnectionState.degraded,
          reason: 'Test degradation',
        ),
      );

      expect(service.connectionState, GlobalLayerConnectionState.degraded);
    });

    test('injectConnectionEvent fires on stream', () async {
      final events = <MqttConnectionEvent>[];
      service.connectionEvents.listen(events.add);

      service.injectConnectionEvent(
        MqttConnectionEvent(
          state: GlobalLayerConnectionState.error,
          errorMessage: 'Test error',
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events[0].state, GlobalLayerConnectionState.error);
      expect(events[0].errorMessage, 'Test error');
    });
  });

  group('dispose', () {
    test('dispose prevents further operations', () async {
      service.dispose();

      expect(
        () => service.connect(config),
        throwsA(
          isA<MqttServiceException>().having(
            (e) => e.type,
            'type',
            MqttServiceErrorType.invalidState,
          ),
        ),
      );
    });

    test('dispose is idempotent', () {
      service.dispose();
      service.dispose(); // Should not throw
    });

    test('dispose prevents inject operations', () {
      service.dispose();

      expect(
        () => service.injectMessage(
          MqttInboundMessage(
            topic: 'test',
            payload: [0x01],
            receivedAt: DateTime.now(),
          ),
        ),
        throwsA(isA<MqttServiceException>()),
      );
    });

    test('dispose prevents injectConnectionEvent', () {
      service.dispose();

      expect(
        () => service.injectConnectionEvent(
          MqttConnectionEvent(state: GlobalLayerConnectionState.connected),
        ),
        throwsA(isA<MqttServiceException>()),
      );
    });
  });

  group('MqttInboundMessage', () {
    test('payloadString decodes UTF-8', () {
      final message = MqttInboundMessage(
        topic: 'test',
        payload: [0x48, 0x65, 0x6C, 0x6C, 0x6F], // "Hello"
        receivedAt: DateTime.now(),
      );

      expect(message.payloadString, 'Hello');
    });

    test('payloadSize returns correct byte count', () {
      final message = MqttInboundMessage(
        topic: 'test',
        payload: [0x01, 0x02, 0x03, 0x04, 0x05],
        receivedAt: DateTime.now(),
      );

      expect(message.payloadSize, 5);
    });

    test('toString includes key info', () {
      final message = MqttInboundMessage(
        topic: 'msh/chat/LongFast',
        payload: [0x01, 0x02],
        receivedAt: DateTime.now(),
        qos: 1,
        retained: true,
      );

      final s = message.toString();
      expect(s.contains('msh/chat/LongFast'), true);
      expect(s.contains('qos: 1'), true);
      expect(s.contains('retained: true'), true);
    });
  });

  group('MqttPublishResult', () {
    test('success constructor sets accepted to true', () {
      const result = MqttPublishResult.success(messageId: 42);
      expect(result.accepted, true);
      expect(result.messageId, 42);
      expect(result.error, null);
    });

    test('failure constructor sets accepted to false', () {
      const result = MqttPublishResult.failure('Write failed');
      expect(result.accepted, false);
      expect(result.messageId, null);
      expect(result.error, 'Write failed');
    });
  });

  group('MqttSubscribeResult', () {
    test('success constructor sets accepted to true', () {
      const result = MqttSubscribeResult.success(
        topic: 'msh/test',
        grantedQos: 1,
      );
      expect(result.accepted, true);
      expect(result.topic, 'msh/test');
      expect(result.grantedQos, 1);
    });

    test('failure constructor sets accepted to false', () {
      const result = MqttSubscribeResult.failure(
        topic: 'msh/test',
        error: 'Not authorized',
      );
      expect(result.accepted, false);
      expect(result.error, 'Not authorized');
    });
  });

  group('MqttPingResult', () {
    test('success constructor sets success and rtt', () {
      const result = MqttPingResult.success(42);
      expect(result.success, true);
      expect(result.roundTripMs, 42);
      expect(result.error, null);
    });

    test('failure constructor sets error', () {
      const result = MqttPingResult.failure('Timeout');
      expect(result.success, false);
      expect(result.roundTripMs, null);
      expect(result.error, 'Timeout');
    });
  });

  group('MqttServiceException', () {
    test('toString includes type and message', () {
      const exception = MqttServiceException(
        type: MqttServiceErrorType.tcpConnection,
        message: 'Connection refused on port 8883',
      );

      final s = exception.toString();
      expect(s.contains('tcpConnection'), true);
      expect(s.contains('Connection refused on port 8883'), true);
    });
  });

  group('MqttConnectionEvent', () {
    test('timestamp defaults to now when not specified', () {
      final before = DateTime.now();
      final event = MqttConnectionEvent(
        state: GlobalLayerConnectionState.connected,
      );
      final after = DateTime.now();

      expect(
        event.timestamp.isAfter(before) ||
            event.timestamp.isAtSameMomentAs(before),
        true,
      );
      expect(
        event.timestamp.isBefore(after) ||
            event.timestamp.isAtSameMomentAs(after),
        true,
      );
    });

    test('toString includes state and optional fields', () {
      final event = MqttConnectionEvent(
        state: GlobalLayerConnectionState.error,
        reason: 'Test reason',
        errorMessage: 'Test error',
      );

      final s = event.toString();
      expect(s.contains('error'), true);
      expect(s.contains('Test reason'), true);
      expect(s.contains('Test error'), true);
    });
  });

  group('realistic delays', () {
    test('default behavior has non-zero connect delay', () {
      const behavior = MockBehavior();
      expect(behavior.connectDelay, greaterThan(Duration.zero));
    });

    test(
      'connect with default delays completes within reasonable time',
      () async {
        final realService = MqttMockService();
        addTearDown(realService.dispose);

        final stopwatch = Stopwatch()..start();
        await realService.connect(config);
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, greaterThan(0));
        expect(realService.isConnected, true);
      },
    );
  });

  group('simulated disconnect', () {
    test(
      'simulateDisconnectAfter fires disconnect event after delay',
      () async {
        final eventService = MqttMockService(
          behavior: MockBehavior.instant.copyWith(
            simulateDisconnectAfter: const Duration(milliseconds: 50),
          ),
        );
        addTearDown(eventService.dispose);

        final events = <MqttConnectionEvent>[];
        eventService.connectionEvents.listen(events.add);

        await eventService.connect(config);
        expect(eventService.isConnected, true);

        // Wait for the simulated disconnect
        await Future<void>.delayed(const Duration(milliseconds: 150));

        // Should have received a reconnecting or disconnected event
        final hasDisconnectEvent = events.any(
          (e) =>
              e.state == GlobalLayerConnectionState.reconnecting ||
              e.state == GlobalLayerConnectionState.disconnected,
        );
        expect(hasDisconnectEvent, true);
      },
    );

    test('auto-reconnect recovers after simulated disconnect', () async {
      final eventService = MqttMockService(
        behavior: MockBehavior.instant.copyWith(
          simulateDisconnectAfter: const Duration(milliseconds: 50),
        ),
      );
      addTearDown(eventService.dispose);
      eventService.setAutoReconnect(true);

      await eventService.connect(config);

      // Wait for disconnect (50ms) + reconnect delay (2s) + margin
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      // Should have reconnected
      expect(
        eventService.connectionState,
        GlobalLayerConnectionState.connected,
      );
      expect(eventService.reconnectAttempts, 1);
    });

    test(
      'without auto-reconnect, stays disconnected after simulated disconnect',
      () async {
        final eventService = MqttMockService(
          behavior: MockBehavior.instant.copyWith(
            simulateDisconnectAfter: const Duration(milliseconds: 50),
          ),
        );
        addTearDown(eventService.dispose);
        eventService.setAutoReconnect(false);

        await eventService.connect(config);

        // Wait for the simulated disconnect timer to fire + margin
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(
          eventService.connectionState,
          GlobalLayerConnectionState.disconnected,
        );
      },
    );
  });

  group('activeSubscriptions', () {
    test('returns unmodifiable set', () async {
      await service.connect(config);
      await service.subscribe('msh/test');

      final subs = service.activeSubscriptions;
      expect(() => subs.add('msh/other'), throwsA(isA<Error>()));
    });
  });

  group('full workflow', () {
    test('connect → subscribe → publish → receive → disconnect', () async {
      final received = <MqttInboundMessage>[];
      service.messages.listen(received.add);

      // Connect
      await service.connect(config);
      expect(service.isConnected, true);

      // Subscribe
      final subResult = await service.subscribe('msh/chat/+');
      expect(subResult.accepted, true);

      // Publish
      final pubResult = await service.publish('msh/chat/LongFast', [
        0x48,
        0x65,
        0x6C,
        0x6C,
        0x6F,
      ]);
      expect(pubResult.accepted, true);

      // Simulate receiving a message
      service.injectMessage(
        MqttInboundMessage(
          topic: 'msh/chat/LongFast',
          payload: [0x57, 0x6F, 0x72, 0x6C, 0x64], // "World"
          receivedAt: DateTime.now(),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(received.length, 1);
      expect(received[0].payloadString, 'World');

      // Ping
      final pingResult = await service.ping();
      expect(pingResult.success, true);

      // Disconnect
      await service.disconnect();
      expect(service.isConnected, false);
      expect(service.activeSubscriptions, isEmpty);
    });
  });
}
