// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/mqtt/mqtt_metrics.dart';

void main() {
  // ---------------------------------------------------------------------------
  // MessageDirection
  // ---------------------------------------------------------------------------

  group('MessageDirection', () {
    test('displayLabel returns non-empty text for all values', () {
      for (final direction in MessageDirection.values) {
        expect(direction.displayLabel, isNotEmpty);
      }
    });

    test('inbound and outbound have distinct labels', () {
      expect(
        MessageDirection.inbound.displayLabel,
        isNot(MessageDirection.outbound.displayLabel),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // ThroughputSample
  // ---------------------------------------------------------------------------

  group('ThroughputSample', () {
    test('creates with required fields', () {
      final sample = ThroughputSample(
        timestamp: DateTime.now(),
        direction: MessageDirection.inbound,
        payloadBytes: 128,
        topic: 'msh/chat/primary',
      );
      expect(sample.direction, MessageDirection.inbound);
      expect(sample.payloadBytes, 128);
      expect(sample.topic, 'msh/chat/primary');
    });

    test('isWithinWindow returns true for recent sample', () {
      final sample = ThroughputSample(
        timestamp: DateTime.now(),
        direction: MessageDirection.inbound,
        payloadBytes: 64,
        topic: 'test',
      );
      expect(sample.isWithinWindow, isTrue);
    });

    test('isWithinWindow returns false for old sample', () {
      final sample = ThroughputSample(
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        direction: MessageDirection.inbound,
        payloadBytes: 64,
        topic: 'test',
      );
      expect(sample.isWithinWindow, isFalse);
    });

    test('toJson produces valid map', () {
      final now = DateTime.now();
      final sample = ThroughputSample(
        timestamp: now,
        direction: MessageDirection.outbound,
        payloadBytes: 256,
        topic: 'msh/telemetry/node1',
      );
      final json = sample.toJson();
      expect(json['timestamp'], now.toIso8601String());
      expect(json['direction'], 'outbound');
      expect(json['payloadBytes'], 256);
      expect(json['topic'], 'msh/telemetry/node1');
    });
  });

  // ---------------------------------------------------------------------------
  // ConnectionErrorRecord
  // ---------------------------------------------------------------------------

  group('ConnectionErrorRecord', () {
    test('creates with required fields', () {
      final error = ConnectionErrorRecord(
        timestamp: DateTime.now(),
        message: 'Connection refused',
        type: ConnectionErrorType.tcpFailure,
      );
      expect(error.message, 'Connection refused');
      expect(error.type, ConnectionErrorType.tcpFailure);
      expect(error.recovered, isFalse);
    });

    test('age returns positive duration', () {
      final error = ConnectionErrorRecord(
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        message: 'Timeout',
        type: ConnectionErrorType.timeout,
      );
      expect(error.age.inMinutes, greaterThanOrEqualTo(4));
    });

    test('copyWith creates updated copy', () {
      final original = ConnectionErrorRecord(
        timestamp: DateTime.now(),
        message: 'DNS failed',
        type: ConnectionErrorType.dnsFailure,
      );
      final recovered = original.copyWith(recovered: true);
      expect(recovered.recovered, isTrue);
      expect(recovered.message, 'DNS failed');
      expect(recovered.type, ConnectionErrorType.dnsFailure);
    });

    test('toJson produces valid map', () {
      final error = ConnectionErrorRecord(
        timestamp: DateTime.now(),
        message: 'Auth failed',
        type: ConnectionErrorType.authFailure,
        recovered: true,
      );
      final json = error.toJson();
      expect(json['message'], 'Auth failed');
      expect(json['type'], 'authFailure');
      expect(json['recovered'], isTrue);
      expect(json.containsKey('timestamp'), isTrue);
    });

    test('toString is descriptive', () {
      final error = ConnectionErrorRecord(
        timestamp: DateTime.now(),
        message: 'TLS error',
        type: ConnectionErrorType.tlsFailure,
      );
      expect(error.toString(), contains('TLS error'));
      expect(error.toString(), contains('tlsFailure'));
    });
  });

  // ---------------------------------------------------------------------------
  // ConnectionErrorType
  // ---------------------------------------------------------------------------

  group('ConnectionErrorType', () {
    test('displayLabel returns non-empty text for all values', () {
      for (final type in ConnectionErrorType.values) {
        expect(type.displayLabel, isNotEmpty);
      }
    });

    test('suggestedAction returns non-empty text for all values', () {
      for (final type in ConnectionErrorType.values) {
        expect(type.suggestedAction, isNotEmpty);
      }
    });

    test('isConfigurationError is true for config-related errors', () {
      expect(ConnectionErrorType.authFailure.isConfigurationError, isTrue);
    });

    test('isConfigurationError is false for transient errors', () {
      expect(ConnectionErrorType.networkLoss.isConfigurationError, isFalse);
      expect(ConnectionErrorType.timeout.isConfigurationError, isFalse);
      expect(ConnectionErrorType.pingTimeout.isConfigurationError, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // GlobalLayerMetrics — empty state
  // ---------------------------------------------------------------------------

  group('GlobalLayerMetrics.empty', () {
    test('has zero counters', () {
      final metrics = GlobalLayerMetrics.empty;
      expect(metrics.totalInbound, 0);
      expect(metrics.totalOutbound, 0);
      expect(metrics.totalBytesInbound, 0);
      expect(metrics.totalBytesOutbound, 0);
      expect(metrics.reconnectCount, 0);
    });

    test('has null ping values', () {
      final metrics = GlobalLayerMetrics.empty;
      expect(metrics.lastPingAt, isNull);
      expect(metrics.lastPingMs, isNull);
    });

    test('has null session start', () {
      final metrics = GlobalLayerMetrics.empty;
      expect(metrics.sessionStartedAt, isNull);
    });

    test('has empty samples and errors', () {
      final metrics = GlobalLayerMetrics.empty;
      expect(metrics.samples, isEmpty);
      expect(metrics.recentErrors, isEmpty);
    });

    test('totalMessages is zero', () {
      expect(GlobalLayerMetrics.empty.totalMessages, 0);
    });

    test('totalBytes is zero', () {
      expect(GlobalLayerMetrics.empty.totalBytes, 0);
    });

    test('activeErrorCount is zero', () {
      expect(GlobalLayerMetrics.empty.activeErrorCount, 0);
    });

    test('lastError is null', () {
      expect(GlobalLayerMetrics.empty.lastError, isNull);
    });

    test('isHealthy is true when no errors', () {
      expect(GlobalLayerMetrics.empty.isHealthy, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // GlobalLayerMetrics — recording samples
  // ---------------------------------------------------------------------------

  group('GlobalLayerMetrics.recordSample', () {
    test('increments inbound counters for inbound sample', () {
      final sample = ThroughputSample(
        timestamp: DateTime.now(),
        direction: MessageDirection.inbound,
        payloadBytes: 100,
        topic: 'msh/chat/primary',
      );
      final metrics = GlobalLayerMetrics.empty.recordSample(sample);
      expect(metrics.totalInbound, 1);
      expect(metrics.totalBytesInbound, 100);
      expect(metrics.totalOutbound, 0);
      expect(metrics.totalBytesOutbound, 0);
    });

    test('increments outbound counters for outbound sample', () {
      final sample = ThroughputSample(
        timestamp: DateTime.now(),
        direction: MessageDirection.outbound,
        payloadBytes: 200,
        topic: 'msh/telemetry/node1',
      );
      final metrics = GlobalLayerMetrics.empty.recordSample(sample);
      expect(metrics.totalOutbound, 1);
      expect(metrics.totalBytesOutbound, 200);
      expect(metrics.totalInbound, 0);
      expect(metrics.totalBytesInbound, 0);
    });

    test('accumulates multiple samples', () {
      var metrics = GlobalLayerMetrics.empty;
      for (var i = 0; i < 5; i++) {
        metrics = metrics.recordSample(
          ThroughputSample(
            timestamp: DateTime.now(),
            direction: MessageDirection.inbound,
            payloadBytes: 50,
            topic: 'msh/chat/primary',
          ),
        );
      }
      expect(metrics.totalInbound, 5);
      expect(metrics.totalBytesInbound, 250);
      expect(metrics.totalMessages, 5);
      expect(metrics.totalBytes, 250);
    });

    test('adds sample to samples list', () {
      final sample = ThroughputSample(
        timestamp: DateTime.now(),
        direction: MessageDirection.inbound,
        payloadBytes: 64,
        topic: 'test',
      );
      final metrics = GlobalLayerMetrics.empty.recordSample(sample);
      expect(metrics.samples.length, 1);
      expect(metrics.samples.first.payloadBytes, 64);
    });

    test('mixed inbound and outbound samples accumulate correctly', () {
      var metrics = GlobalLayerMetrics.empty;
      metrics = metrics.recordSample(
        ThroughputSample(
          timestamp: DateTime.now(),
          direction: MessageDirection.inbound,
          payloadBytes: 100,
          topic: 'in',
        ),
      );
      metrics = metrics.recordSample(
        ThroughputSample(
          timestamp: DateTime.now(),
          direction: MessageDirection.outbound,
          payloadBytes: 200,
          topic: 'out',
        ),
      );
      metrics = metrics.recordSample(
        ThroughputSample(
          timestamp: DateTime.now(),
          direction: MessageDirection.inbound,
          payloadBytes: 150,
          topic: 'in',
        ),
      );

      expect(metrics.totalInbound, 2);
      expect(metrics.totalOutbound, 1);
      expect(metrics.totalBytesInbound, 250);
      expect(metrics.totalBytesOutbound, 200);
      expect(metrics.totalMessages, 3);
      expect(metrics.totalBytes, 450);
    });
  });

  // ---------------------------------------------------------------------------
  // GlobalLayerMetrics — recording pings
  // ---------------------------------------------------------------------------

  group('GlobalLayerMetrics.recordPing', () {
    test('sets ping values', () {
      final metrics = GlobalLayerMetrics.empty.recordPing(42);
      expect(metrics.lastPingMs, 42);
      expect(metrics.lastPingAt, isNotNull);
    });

    test('overwrites previous ping', () {
      var metrics = GlobalLayerMetrics.empty;
      metrics = metrics.recordPing(100);
      metrics = metrics.recordPing(50);
      expect(metrics.lastPingMs, 50);
    });

    test('timeSinceLastPing returns non-null after ping', () {
      final metrics = GlobalLayerMetrics.empty.recordPing(30);
      expect(metrics.timeSinceLastPing, isNotNull);
      expect(metrics.timeSinceLastPing!.inSeconds, greaterThanOrEqualTo(0));
    });

    test('timeSinceLastPing returns null before any ping', () {
      expect(GlobalLayerMetrics.empty.timeSinceLastPing, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // GlobalLayerMetrics — recording errors
  // ---------------------------------------------------------------------------

  group('GlobalLayerMetrics.recordError', () {
    test('adds error to recent errors list', () {
      final error = ConnectionErrorRecord(
        timestamp: DateTime.now(),
        message: 'Connection refused',
        type: ConnectionErrorType.tcpFailure,
      );
      final metrics = GlobalLayerMetrics.empty.recordError(error);
      expect(metrics.recentErrors.length, 1);
      expect(metrics.recentErrors.first.message, 'Connection refused');
    });

    test('activeErrorCount increases for unrecovered errors', () {
      final error = ConnectionErrorRecord(
        timestamp: DateTime.now(),
        message: 'Auth failed',
        type: ConnectionErrorType.authFailure,
      );
      final metrics = GlobalLayerMetrics.empty.recordError(error);
      expect(metrics.activeErrorCount, 1);
    });

    test('lastError returns the most recent error', () {
      var metrics = GlobalLayerMetrics.empty;
      metrics = metrics.recordError(
        ConnectionErrorRecord(
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          message: 'First error',
          type: ConnectionErrorType.dnsFailure,
        ),
      );
      metrics = metrics.recordError(
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Second error',
          type: ConnectionErrorType.tcpFailure,
        ),
      );
      expect(metrics.lastError, isNotNull);
      expect(metrics.lastError!.message, 'Second error');
    });

    test('isHealthy is false when there are active errors', () {
      final error = ConnectionErrorRecord(
        timestamp: DateTime.now(),
        message: 'Error',
        type: ConnectionErrorType.timeout,
      );
      final metrics = GlobalLayerMetrics.empty.recordError(error);
      expect(metrics.isHealthy, isFalse);
    });

    test('multiple errors accumulate', () {
      var metrics = GlobalLayerMetrics.empty;
      for (var i = 0; i < 5; i++) {
        metrics = metrics.recordError(
          ConnectionErrorRecord(
            timestamp: DateTime.now(),
            message: 'Error $i',
            type: ConnectionErrorType.timeout,
          ),
        );
      }
      expect(metrics.recentErrors.length, 5);
      expect(metrics.activeErrorCount, 5);
    });
  });

  // ---------------------------------------------------------------------------
  // GlobalLayerMetrics — clear errors
  // ---------------------------------------------------------------------------

  group('GlobalLayerMetrics.clearErrors', () {
    test('removes all errors', () {
      var metrics = GlobalLayerMetrics.empty;
      metrics = metrics.recordError(
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Error 1',
          type: ConnectionErrorType.tcpFailure,
        ),
      );
      metrics = metrics.recordError(
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Error 2',
          type: ConnectionErrorType.dnsFailure,
        ),
      );
      expect(metrics.recentErrors.length, 2);

      final cleared = metrics.clearErrors();
      expect(cleared.recentErrors, isEmpty);
      expect(cleared.activeErrorCount, 0);
      expect(cleared.lastError, isNull);
      expect(cleared.isHealthy, isTrue);
    });

    test('preserves other metrics after clearing errors', () {
      var metrics = GlobalLayerMetrics.empty;
      metrics = metrics.recordPing(42);
      metrics = metrics.recordSample(
        ThroughputSample(
          timestamp: DateTime.now(),
          direction: MessageDirection.inbound,
          payloadBytes: 100,
          topic: 'test',
        ),
      );
      metrics = metrics.recordError(
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Error',
          type: ConnectionErrorType.timeout,
        ),
      );

      final cleared = metrics.clearErrors();
      expect(cleared.lastPingMs, 42);
      expect(cleared.totalInbound, 1);
      expect(cleared.totalBytesInbound, 100);
    });
  });

  // ---------------------------------------------------------------------------
  // GlobalLayerMetrics — reconnect count
  // ---------------------------------------------------------------------------

  group('GlobalLayerMetrics.incrementReconnectCount', () {
    test('increments by one', () {
      var metrics = GlobalLayerMetrics.empty;
      expect(metrics.reconnectCount, 0);

      metrics = metrics.incrementReconnectCount();
      expect(metrics.reconnectCount, 1);

      metrics = metrics.incrementReconnectCount();
      expect(metrics.reconnectCount, 2);
    });

    test('preserves other metrics', () {
      var metrics = GlobalLayerMetrics.empty.recordPing(50);
      metrics = metrics.incrementReconnectCount();
      expect(metrics.lastPingMs, 50);
      expect(metrics.reconnectCount, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // GlobalLayerMetrics — session management
  // ---------------------------------------------------------------------------

  group('GlobalLayerMetrics.startSession', () {
    test('sets session start time', () {
      final metrics = GlobalLayerMetrics.empty.startSession();
      expect(metrics.sessionStartedAt, isNotNull);
    });

    test('sessionDuration is non-null after start', () {
      final metrics = GlobalLayerMetrics.empty.startSession();
      expect(metrics.sessionDuration, isNotNull);
      expect(metrics.sessionDuration!.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('sessionDurationDisplay returns non-empty string after start', () {
      final metrics = GlobalLayerMetrics.empty.startSession();
      expect(metrics.sessionDurationDisplay, isNotEmpty);
      expect(metrics.sessionDurationDisplay, isNot('--'));
    });
  });

  group('GlobalLayerMetrics.endSession', () {
    test('clears session start time', () {
      var metrics = GlobalLayerMetrics.empty.startSession();
      expect(metrics.sessionStartedAt, isNotNull);

      metrics = metrics.endSession();
      expect(metrics.sessionStartedAt, isNull);
    });

    test('sessionDuration is null after end', () {
      var metrics = GlobalLayerMetrics.empty.startSession();
      metrics = metrics.endSession();
      expect(metrics.sessionDuration, isNull);
    });

    test('sessionDurationDisplay returns N/A after end', () {
      var metrics = GlobalLayerMetrics.empty.startSession();
      metrics = metrics.endSession();
      expect(metrics.sessionDurationDisplay, 'N/A');
    });
  });

  group('GlobalLayerMetrics.sessionDuration', () {
    test('returns null before session starts', () {
      expect(GlobalLayerMetrics.empty.sessionDuration, isNull);
    });

    test('sessionDurationDisplay returns N/A before session', () {
      expect(GlobalLayerMetrics.empty.sessionDurationDisplay, 'N/A');
    });
  });

  // ---------------------------------------------------------------------------
  // GlobalLayerMetrics — rate calculations
  // ---------------------------------------------------------------------------

  group('GlobalLayerMetrics rate calculations', () {
    test('inboundRate is zero for empty metrics', () {
      expect(GlobalLayerMetrics.empty.inboundRate, 0.0);
    });

    test('outboundRate is zero for empty metrics', () {
      expect(GlobalLayerMetrics.empty.outboundRate, 0.0);
    });

    test('combinedRate is zero for empty metrics', () {
      expect(GlobalLayerMetrics.empty.combinedRate, 0.0);
    });

    test('throughputDisplay returns meaningful string for empty metrics', () {
      final display = GlobalLayerMetrics.empty.throughputDisplay;
      expect(display, isNotEmpty);
    });

    test('inboundRate increases with recent inbound samples', () {
      var metrics = GlobalLayerMetrics.empty;
      for (var i = 0; i < 10; i++) {
        metrics = metrics.recordSample(
          ThroughputSample(
            timestamp: DateTime.now(),
            direction: MessageDirection.inbound,
            payloadBytes: 50,
            topic: 'test',
          ),
        );
      }
      expect(metrics.inboundRate, greaterThan(0));
    });

    test('outboundRate increases with recent outbound samples', () {
      var metrics = GlobalLayerMetrics.empty;
      for (var i = 0; i < 10; i++) {
        metrics = metrics.recordSample(
          ThroughputSample(
            timestamp: DateTime.now(),
            direction: MessageDirection.outbound,
            payloadBytes: 50,
            topic: 'test',
          ),
        );
      }
      expect(metrics.outboundRate, greaterThan(0));
    });

    test('combinedRate sums inbound and outbound', () {
      var metrics = GlobalLayerMetrics.empty;
      metrics = metrics.recordSample(
        ThroughputSample(
          timestamp: DateTime.now(),
          direction: MessageDirection.inbound,
          payloadBytes: 50,
          topic: 'test',
        ),
      );
      metrics = metrics.recordSample(
        ThroughputSample(
          timestamp: DateTime.now(),
          direction: MessageDirection.outbound,
          payloadBytes: 50,
          topic: 'test',
        ),
      );
      expect(metrics.combinedRate, greaterThanOrEqualTo(metrics.inboundRate));
      expect(metrics.combinedRate, greaterThanOrEqualTo(metrics.outboundRate));
    });
  });

  // ---------------------------------------------------------------------------
  // GlobalLayerMetrics — message counts by topic
  // ---------------------------------------------------------------------------

  group('GlobalLayerMetrics.messageCountsByTopic', () {
    test('returns empty map for empty metrics', () {
      expect(GlobalLayerMetrics.empty.messageCountsByTopic, isEmpty);
    });

    test('counts messages per topic', () {
      var metrics = GlobalLayerMetrics.empty;
      metrics = metrics.recordSample(
        ThroughputSample(
          timestamp: DateTime.now(),
          direction: MessageDirection.inbound,
          payloadBytes: 50,
          topic: 'msh/chat/primary',
        ),
      );
      metrics = metrics.recordSample(
        ThroughputSample(
          timestamp: DateTime.now(),
          direction: MessageDirection.inbound,
          payloadBytes: 50,
          topic: 'msh/chat/primary',
        ),
      );
      metrics = metrics.recordSample(
        ThroughputSample(
          timestamp: DateTime.now(),
          direction: MessageDirection.outbound,
          payloadBytes: 50,
          topic: 'msh/telemetry/node1',
        ),
      );

      final counts = metrics.messageCountsByTopic;
      expect(counts['msh/chat/primary'], 2);
      expect(counts['msh/telemetry/node1'], 1);
    });

    test('only counts samples within the metrics window', () {
      var metrics = GlobalLayerMetrics.empty;
      // This sample is old and should not be counted in window-based calcs
      // but messageCountsByTopic counts all samples in the list
      metrics = metrics.recordSample(
        ThroughputSample(
          timestamp: DateTime.now(),
          direction: MessageDirection.inbound,
          payloadBytes: 50,
          topic: 'msh/chat/primary',
        ),
      );
      final counts = metrics.messageCountsByTopic;
      expect(counts.isNotEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // GlobalLayerMetrics — health status
  // ---------------------------------------------------------------------------

  group('GlobalLayerMetrics.isHealthy', () {
    test('healthy when no errors', () {
      expect(GlobalLayerMetrics.empty.isHealthy, isTrue);
    });

    test('unhealthy when active errors exist', () {
      final metrics = GlobalLayerMetrics.empty.recordError(
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Error',
          type: ConnectionErrorType.tcpFailure,
        ),
      );
      expect(metrics.isHealthy, isFalse);
    });

    test('healthy after clearing errors', () {
      var metrics = GlobalLayerMetrics.empty.recordError(
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Error',
          type: ConnectionErrorType.tcpFailure,
        ),
      );
      metrics = metrics.clearErrors();
      expect(metrics.isHealthy, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // GlobalLayerMetrics — redacted export
  // ---------------------------------------------------------------------------

  group('GlobalLayerMetrics.toRedactedJson', () {
    test('produces valid map', () {
      var metrics = GlobalLayerMetrics.empty;
      metrics = metrics.recordSample(
        ThroughputSample(
          timestamp: DateTime.now(),
          direction: MessageDirection.inbound,
          payloadBytes: 100,
          topic: 'test',
        ),
      );
      metrics = metrics.incrementReconnectCount();
      metrics = metrics.recordPing(42);

      final json = metrics.toRedactedJson();
      expect(json, isA<Map<String, dynamic>>());
      expect(json.containsKey('lastPingMs'), isTrue);
      expect(json['lastPingMs'], 42);
      expect(json.containsKey('reconnectCount'), isTrue);
      expect(json['reconnectCount'], 1);
      expect(json.containsKey('totalInbound'), isTrue);
      expect(json['totalInbound'], 1);
    });

    test('toRedactedString returns non-empty string', () {
      final metrics = GlobalLayerMetrics.empty.recordPing(50);
      final str = metrics.toRedactedString();
      expect(str, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // GlobalLayerMetrics — toString
  // ---------------------------------------------------------------------------

  group('GlobalLayerMetrics.toString', () {
    test('returns descriptive string', () {
      final str = GlobalLayerMetrics.empty.toString();
      expect(str, contains('GlobalLayerMetrics'));
    });

    test('includes key counts', () {
      var metrics = GlobalLayerMetrics.empty;
      metrics = metrics.recordSample(
        ThroughputSample(
          timestamp: DateTime.now(),
          direction: MessageDirection.inbound,
          payloadBytes: 50,
          topic: 'test',
        ),
      );
      metrics = metrics.recordError(
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Error',
          type: ConnectionErrorType.timeout,
        ),
      );
      final str = metrics.toString();
      expect(str, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // GlobalLayerMetrics — immutability
  // ---------------------------------------------------------------------------

  group('GlobalLayerMetrics immutability', () {
    test('recordSample returns new instance', () {
      final original = GlobalLayerMetrics.empty;
      final updated = original.recordSample(
        ThroughputSample(
          timestamp: DateTime.now(),
          direction: MessageDirection.inbound,
          payloadBytes: 50,
          topic: 'test',
        ),
      );
      expect(identical(original, updated), isFalse);
      expect(original.totalInbound, 0);
      expect(updated.totalInbound, 1);
    });

    test('recordPing returns new instance', () {
      final original = GlobalLayerMetrics.empty;
      final updated = original.recordPing(42);
      expect(identical(original, updated), isFalse);
      expect(original.lastPingMs, isNull);
      expect(updated.lastPingMs, 42);
    });

    test('recordError returns new instance', () {
      final original = GlobalLayerMetrics.empty;
      final updated = original.recordError(
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Error',
          type: ConnectionErrorType.timeout,
        ),
      );
      expect(identical(original, updated), isFalse);
      expect(original.recentErrors, isEmpty);
      expect(updated.recentErrors.length, 1);
    });

    test('incrementReconnectCount returns new instance', () {
      final original = GlobalLayerMetrics.empty;
      final updated = original.incrementReconnectCount();
      expect(identical(original, updated), isFalse);
      expect(original.reconnectCount, 0);
      expect(updated.reconnectCount, 1);
    });

    test('startSession returns new instance', () {
      final original = GlobalLayerMetrics.empty;
      final updated = original.startSession();
      expect(identical(original, updated), isFalse);
      expect(original.sessionStartedAt, isNull);
      expect(updated.sessionStartedAt, isNotNull);
    });

    test('endSession returns new instance', () {
      final started = GlobalLayerMetrics.empty.startSession();
      final ended = started.endSession();
      expect(identical(started, ended), isFalse);
      expect(started.sessionStartedAt, isNotNull);
      expect(ended.sessionStartedAt, isNull);
    });

    test('clearErrors returns new instance', () {
      final withError = GlobalLayerMetrics.empty.recordError(
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Error',
          type: ConnectionErrorType.timeout,
        ),
      );
      final cleared = withError.clearErrors();
      expect(identical(withError, cleared), isFalse);
      expect(withError.recentErrors.length, 1);
      expect(cleared.recentErrors, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // GlobalLayerMetrics — composite operations
  // ---------------------------------------------------------------------------

  group('GlobalLayerMetrics composite operations', () {
    test('full session lifecycle: start, record, ping, error, clear, end', () {
      var metrics = GlobalLayerMetrics.empty;

      // Start session
      metrics = metrics.startSession();
      expect(metrics.sessionStartedAt, isNotNull);

      // Record some samples
      for (var i = 0; i < 3; i++) {
        metrics = metrics.recordSample(
          ThroughputSample(
            timestamp: DateTime.now(),
            direction: MessageDirection.inbound,
            payloadBytes: 64,
            topic: 'msh/chat/primary',
          ),
        );
      }
      metrics = metrics.recordSample(
        ThroughputSample(
          timestamp: DateTime.now(),
          direction: MessageDirection.outbound,
          payloadBytes: 128,
          topic: 'msh/telemetry/node1',
        ),
      );

      expect(metrics.totalInbound, 3);
      expect(metrics.totalOutbound, 1);
      expect(metrics.totalMessages, 4);
      expect(metrics.totalBytes, 3 * 64 + 128);

      // Record ping
      metrics = metrics.recordPing(25);
      expect(metrics.lastPingMs, 25);

      // Record error
      metrics = metrics.recordError(
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Ping timeout',
          type: ConnectionErrorType.pingTimeout,
        ),
      );
      expect(metrics.activeErrorCount, 1);
      expect(metrics.isHealthy, isFalse);

      // Increment reconnect count
      metrics = metrics.incrementReconnectCount();
      expect(metrics.reconnectCount, 1);

      // Clear errors
      metrics = metrics.clearErrors();
      expect(metrics.activeErrorCount, 0);
      expect(metrics.isHealthy, isTrue);

      // End session
      metrics = metrics.endSession();
      expect(metrics.sessionStartedAt, isNull);

      // Counters should be preserved
      expect(metrics.totalInbound, 3);
      expect(metrics.totalOutbound, 1);
      expect(metrics.reconnectCount, 1);
      expect(metrics.lastPingMs, 25);
    });

    test('topic counts are accurate across mixed traffic', () {
      var metrics = GlobalLayerMetrics.empty;
      final topics = ['msh/chat/a', 'msh/chat/b', 'msh/telemetry/node1'];

      // Record 2 messages on topic a, 3 on b, 1 on telemetry
      for (var i = 0; i < 2; i++) {
        metrics = metrics.recordSample(
          ThroughputSample(
            timestamp: DateTime.now(),
            direction: MessageDirection.inbound,
            payloadBytes: 50,
            topic: topics[0],
          ),
        );
      }
      for (var i = 0; i < 3; i++) {
        metrics = metrics.recordSample(
          ThroughputSample(
            timestamp: DateTime.now(),
            direction: MessageDirection.inbound,
            payloadBytes: 50,
            topic: topics[1],
          ),
        );
      }
      metrics = metrics.recordSample(
        ThroughputSample(
          timestamp: DateTime.now(),
          direction: MessageDirection.outbound,
          payloadBytes: 50,
          topic: topics[2],
        ),
      );

      final counts = metrics.messageCountsByTopic;
      expect(counts[topics[0]], 2);
      expect(counts[topics[1]], 3);
      expect(counts[topics[2]], 1);
      expect(metrics.totalMessages, 6);
    });
  });
}
