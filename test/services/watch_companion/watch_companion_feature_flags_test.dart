// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/watch_companion/watch_companion_feature_flags.dart';

void main() {
  group('WatchCompanionFeatureFlags', () {
    tearDown(() {
      dotenv.clean();
    });

    test('disabled constant is fully off', () {
      const flags = WatchCompanionFeatureFlags.disabled;
      expect(flags.enabled, isFalse);
    });

    test('default constructor is enabled', () {
      const flags = WatchCompanionFeatureFlags();
      expect(flags.enabled, isTrue);
    });

    test(
      'fromEnv() defaults to enabled when WATCH_COMPANION_ENABLED is unset',
      () {
        dotenv.loadFromString(envString: 'TEST_MODE=true');
        final flags = WatchCompanionFeatureFlags.fromEnv();
        expect(
          flags.enabled,
          isTrue,
          reason:
              'Watch surface is opt-out, not opt-in. A fresh paired Watch '
              'must work without any env configuration.',
        );
      },
    );

    test('fromEnv() with WATCH_COMPANION_ENABLED=false disables', () {
      dotenv.loadFromString(
        envString: 'TEST_MODE=true\nWATCH_COMPANION_ENABLED=false',
      );
      final flags = WatchCompanionFeatureFlags.fromEnv();
      expect(flags.enabled, isFalse);
    });

    test('fromEnv() with WATCH_COMPANION_ENABLED=true stays enabled', () {
      dotenv.loadFromString(
        envString: 'TEST_MODE=true\nWATCH_COMPANION_ENABLED=true',
      );
      final flags = WatchCompanionFeatureFlags.fromEnv();
      expect(flags.enabled, isTrue);
    });

    test('case-insensitive false', () {
      dotenv.loadFromString(
        envString: 'TEST_MODE=true\nWATCH_COMPANION_ENABLED=FALSE',
      );
      final flags = WatchCompanionFeatureFlags.fromEnv();
      expect(flags.enabled, isFalse);
    });

    test('any non-"false" value keeps enabled (default-true bias)', () {
      // Mirrors the opt-out posture: unparseable values default to enabled.
      // Only the literal trimmed lowercase "false" turns the surface off.
      dotenv.loadFromString(
        envString: 'TEST_MODE=true\nWATCH_COMPANION_ENABLED=garbage',
      );
      final flags = WatchCompanionFeatureFlags.fromEnv();
      expect(flags.enabled, isTrue);
    });

    test('whitespace around value is trimmed', () {
      dotenv.loadFromString(
        envString: 'TEST_MODE=true\nWATCH_COMPANION_ENABLED=  false  ',
      );
      final flags = WatchCompanionFeatureFlags.fromEnv();
      expect(flags.enabled, isFalse);
    });

    test('fromEnv() does not throw when dotenv is not initialised', () {
      dotenv.clean();
      // dotenv.env access raises when uninitialised; the helper should
      // catch and fall back to the default-true value.
      expect(() => WatchCompanionFeatureFlags.fromEnv(), returnsNormally);
      final flags = WatchCompanionFeatureFlags.fromEnv();
      expect(flags.enabled, isTrue);
    });
  });
}
