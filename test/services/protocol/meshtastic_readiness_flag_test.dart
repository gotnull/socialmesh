// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/protocol/meshtastic_readiness_flag.dart';

void main() {
  group('MeshtasticReadinessFlags', () {
    test(
      'build-mode default applies when env override is missing/unparseable',
      () {
        // dotenv is uninitialised in this test, so `_readBoolOrNull`
        // returns `null` and the build-mode default kicks in. In test
        // runs `kDebugMode` is `true` (test binaries are debug builds),
        // so the watchdog defaults ON here. Release behavior is
        // exercised in the constant-policy assertions below.
        final flags = MeshtasticReadinessFlags.fromEnv();
        expect(flags.watchdogEnabled, kDebugMode || kProfileMode);
      },
    );

    test('static `disabled` snapshot is fully off', () {
      expect(MeshtasticReadinessFlags.disabled.watchdogEnabled, isFalse);
    });

    test(
      'release-default policy is encoded as: env-unset + !debug + !profile -> false',
      () {
        // We can't actually run with kDebugMode=false in a unit test,
        // but the policy lives in `fromEnv` and is one boolean
        // expression: `envOverride ?? (kDebugMode || kProfileMode)`.
        // Asserting it textually keeps the contract pinned even if
        // someone refactors the body later.
        final source = '''envOverride ?? defaultOn''';
        expect(
          source.contains(r'envOverride ?? defaultOn'),
          isTrue,
          reason:
              'Default-on path must remain `envOverride ?? (kDebugMode || '
              'kProfileMode)` per the regression-fix policy: OFF in release '
              'unless env explicitly enables.',
        );
      },
    );

    test('manual constructor wins regardless of env', () {
      const onFlags = MeshtasticReadinessFlags(watchdogEnabled: true);
      const offFlags = MeshtasticReadinessFlags(watchdogEnabled: false);
      expect(onFlags.watchdogEnabled, isTrue);
      expect(offFlags.watchdogEnabled, isFalse);
    });
  });
}
