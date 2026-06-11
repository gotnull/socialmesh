// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the site-keyed report throttle: a persistent failure firing on a
// per-event hot path must collapse to one Crashlytics report per window,
// while distinct call sites report independently.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/safety/error_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(AppErrorHandler.resetThrottleStateForTest);

  bool report(String key, {Duration? window}) {
    return AppErrorHandler.reportErrorThrottled(
      StateError('db write failed'),
      StackTrace.current,
      key: key,
      context: 'throttle test',
      window: window ?? const Duration(minutes: 5),
    );
  }

  test('same key inside the window collapses to one admitted report', () {
    expect(report('site_a'), isTrue);
    expect(report('site_a'), isFalse);
    expect(report('site_a'), isFalse);
  });

  test('distinct keys report independently', () {
    expect(report('site_a'), isTrue);
    expect(report('site_b'), isTrue);
    expect(report('site_a'), isFalse);
    expect(report('site_b'), isFalse);
  });

  test('an expired window re-admits the next report', () {
    expect(report('site_a', window: Duration.zero), isTrue);
    expect(report('site_a', window: Duration.zero), isTrue);
  });

  test('resetThrottleStateForTest re-arms a suppressed key', () {
    expect(report('site_a'), isTrue);
    expect(report('site_a'), isFalse);
    AppErrorHandler.resetThrottleStateForTest();
    expect(report('site_a'), isTrue);
  });
}
