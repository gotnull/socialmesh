// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/logging.dart';

// Boot timeline, readiness and handshake lines are the ones a user is asked
// to export from Settings > Tools > App Log when a launch or connection is
// slow. A store build ships with every console logging flag off, so these
// must reach the in-app sink regardless of any flag.
void main() {
  group('AppLogging session diagnostics sink bridge', () {
    late List<(int level, String source, String message)> captured;

    setUp(() {
      AppLogging.reset();
      captured = [];
      AppLogging.setAppLogSink((level, source, message) {
        captured.add((level, source, message));
      });
    });

    tearDown(AppLogging.reset);

    test('boot forwards info-level lines under the boot source', () {
      AppLogging.boot('BOOT_TIMELINE at=runApp total=1200ms dotenv=3ms');

      expect(captured, hasLength(1));
      expect(captured.first.$1, 1);
      expect(captured.first.$2, 'boot');
      expect(
        captured.first.$3,
        'BOOT_TIMELINE at=runApp total=1200ms dotenv=3ms',
      );
    });

    test('session forwards info-level lines under the session source', () {
      AppLogging.session('READINESS: connecting -> ready (phase2_complete)');

      expect(captured, hasLength(1));
      expect(captured.first.$1, 1);
      expect(captured.first.$2, 'session');
      expect(
        captured.first.$3,
        'READINESS: connecting -> ready (phase2_complete)',
      );
    });

    test('per-area loggers still do not feed the sink', () {
      // connection() and protocol() are console-only; the diagnostics must
      // not be reachable through them or a store build loses them again.
      AppLogging.connection('console only');
      AppLogging.protocol('console only');

      expect(captured, isEmpty);
    });

    test('no crash when sink is not set', () {
      AppLogging.reset();

      AppLogging.boot('no sink');
      AppLogging.session('no sink');
    });
  });
}
