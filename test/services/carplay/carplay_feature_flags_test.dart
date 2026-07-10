// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/carplay/carplay_feature_flags.dart';

void main() {
  group('CarPlayFeatureFlags', () {
    tearDown(() {
      dotenv.clean();
      debugDefaultTargetPlatformOverride = null;
    });

    test('default constructor is fully off (opt-in)', () {
      const flags = CarPlayFeatureFlags();
      expect(flags.enabled, isFalse);
      expect(flags.suppressStandardNotification, isFalse);
    });

    test('disabled constant is fully off', () {
      const flags = CarPlayFeatureFlags.disabled;
      expect(flags.enabled, isFalse);
      expect(flags.suppressStandardNotification, isFalse);
    });

    test('fromEnv() defaults both flags off when env is unset', () {
      dotenv.loadFromString(envString: 'TEST_MODE=true');
      final flags = CarPlayFeatureFlags.fromEnv();
      expect(flags.enabled, isFalse);
      expect(flags.suppressStandardNotification, isFalse);
    });

    test('fromEnv() reads both flags independently', () {
      dotenv.loadFromString(
        envString:
            'TEST_MODE=true\n'
            'CARPLAY_COMMUNICATION_ENABLED=true\n'
            'CARPLAY_SUPPRESS_STANDARD_NOTIFICATION=true',
      );
      final flags = CarPlayFeatureFlags.fromEnv();
      expect(flags.enabled, isTrue);
      expect(flags.suppressStandardNotification, isTrue);
    });

    test('fromEnv() does not throw when dotenv is not initialised', () {
      dotenv.clean();
      expect(() => CarPlayFeatureFlags.fromEnv(), returnsNormally);
      final flags = CarPlayFeatureFlags.fromEnv();
      expect(flags.enabled, isFalse);
      expect(flags.suppressStandardNotification, isFalse);
    });

    // -------------------------------------------------------------------------
    // suppressesStandardNotification - the gate that regressed. Enabling the
    // writer alone must never silence message notifications; suppression needs
    // the explicit second opt-in AND an iOS platform (the only one with a
    // native communication banner).
    // -------------------------------------------------------------------------

    test('never suppresses by default', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const flags = CarPlayFeatureFlags();
      expect(flags.suppressesStandardNotification, isFalse);
    });

    test(
      'writer enabled alone does not suppress (the reported regression)',
      () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        const flags = CarPlayFeatureFlags(enabled: true);
        expect(
          flags.suppressesStandardNotification,
          isFalse,
          reason:
              'Turning the CarPlay writer on must not suppress the standard '
              'notification; that is what dropped every message banner.',
        );
      },
    );

    test('both flags on iOS suppresses', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const flags = CarPlayFeatureFlags(
        enabled: true,
        suppressStandardNotification: true,
      );
      expect(flags.suppressesStandardNotification, isTrue);
    });

    test('never suppresses on Android even with both flags on', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const flags = CarPlayFeatureFlags(
        enabled: true,
        suppressStandardNotification: true,
      );
      expect(
        flags.suppressesStandardNotification,
        isFalse,
        reason:
            'Android has no native communication handler, so suppressing there '
            'would drop the notification with nothing to replace it.',
      );
    });

    test('suppress opt-in without the writer does not suppress', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const flags = CarPlayFeatureFlags(suppressStandardNotification: true);
      expect(flags.suppressesStandardNotification, isFalse);
    });
  });
}
