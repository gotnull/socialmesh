// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/logging.dart';

void main() {
  group('AppLogging.meshcore sink routing', () {
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

    test('info event routes to sink at level 1 with meshcore source', () {
      AppLogging.meshcore('event=connect.started transport=tcp');

      expect(captured, hasLength(1));
      expect(captured.first.$1, 1);
      expect(captured.first.$2, 'meshcore');
      expect(captured.first.$3, 'event=connect.started transport=tcp');
    });

    test('error event routes to sink at level 3', () {
      AppLogging.meshcore('event=connect.failed reason=timeout', error: true);

      expect(captured, hasLength(1));
      expect(captured.first.$1, 3);
      expect(captured.first.$2, 'meshcore');
    });

    test('multiple events arrive in order', () {
      AppLogging.meshcore('event=a');
      AppLogging.meshcore('event=b', error: true);
      AppLogging.meshcore('event=c');

      expect(captured.map((e) => e.$3).toList(), [
        'event=a',
        'event=b',
        'event=c',
      ]);
      expect(captured.map((e) => e.$1).toList(), [1, 3, 1]);
    });

    test('no crash when sink not set', () {
      AppLogging.reset();
      // Should not throw.
      AppLogging.meshcore('event=no_sink');
      AppLogging.meshcore('event=no_sink_err', error: true);
    });

    test('default flag is enabled in tests (kDebugMode)', () {
      // In test env dotenv is not loaded → falls through to kDebugMode true.
      expect(AppLogging.meshcoreLoggingEnabled, isTrue);
    });

    test('location flag defaults off', () {
      expect(AppLogging.meshcoreLoggingLocationEnabled, isFalse);
    });
  });
}
