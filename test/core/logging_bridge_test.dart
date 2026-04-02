// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/logging.dart';

void main() {
  group('AppLogging MQTT proxy sink bridge', () {
    late List<(int level, String source, String message)> captured;

    setUp(() {
      AppLogging.reset();
      captured = [];
      AppLogging.setAppLogSink((level, source, message) {
        captured.add((level, source, message));
      });
    });

    tearDown(() {
      AppLogging.reset();
    });

    test('mqttProxy forwards info-level events to sink', () {
      AppLogging.mqttProxy('connected to broker');

      expect(captured, hasLength(1));
      expect(captured.first.$1, 1); // info
      expect(captured.first.$2, 'mqtt_proxy');
      expect(captured.first.$3, 'connected to broker');
    });

    test('mqttProxyError forwards error-level events to sink', () {
      AppLogging.mqttProxyError('connection refused');

      expect(captured, hasLength(1));
      expect(captured.first.$1, 3); // error
      expect(captured.first.$2, 'mqtt_proxy');
      expect(captured.first.$3, 'connection refused');
    });

    test('mqttProxyWarning forwards warning-level events to sink', () {
      AppLogging.mqttProxyWarning('publish while disconnected');

      expect(captured, hasLength(1));
      expect(captured.first.$1, 2); // warning
      expect(captured.first.$2, 'mqtt_proxy');
      expect(captured.first.$3, 'publish while disconnected');
    });

    test('sink receives events even when console logging is disabled', () {
      // MQTT_PROXY_LOGGING_ENABLED defaults to false in test env
      // (dotenv not loaded), but in-app sink should still fire.
      AppLogging.mqttProxy('should reach sink');
      AppLogging.mqttProxyError('error should reach sink');
      AppLogging.mqttProxyWarning('warning should reach sink');

      expect(captured, hasLength(3));
      expect(captured[0].$1, 1);
      expect(captured[1].$1, 3);
      expect(captured[2].$1, 2);
    });

    test('no crash when sink is not set', () {
      AppLogging.reset(); // clear the sink

      // Should not throw
      AppLogging.mqttProxy('no sink');
      AppLogging.mqttProxyError('no sink');
      AppLogging.mqttProxyWarning('no sink');
    });

    test('reset clears the sink', () {
      AppLogging.mqttProxy('before reset');
      expect(captured, hasLength(1));

      AppLogging.reset();

      AppLogging.mqttProxy('after reset');
      // No new events captured because sink was cleared
      expect(captured, hasLength(1));
    });

    test('source is always mqtt_proxy', () {
      AppLogging.mqttProxy('msg1');
      AppLogging.mqttProxyError('msg2');
      AppLogging.mqttProxyWarning('msg3');

      for (final event in captured) {
        expect(event.$2, 'mqtt_proxy');
      }
    });

    test('multiple events are captured in order', () {
      AppLogging.mqttProxy('first');
      AppLogging.mqttProxyError('second');
      AppLogging.mqttProxy('third');
      AppLogging.mqttProxyWarning('fourth');

      expect(captured, hasLength(4));
      expect(captured.map((e) => e.$3).toList(), [
        'first',
        'second',
        'third',
        'fourth',
      ]);
      expect(captured.map((e) => e.$1).toList(), [1, 3, 1, 2]);
    });
  });
}
