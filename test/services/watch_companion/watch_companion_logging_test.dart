// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/logging.dart';

void main() {
  group('AppLogging.watchCompanion env gating', () {
    tearDown(() {
      AppLogging.reset();
      dotenv.clean();
    });

    test(
      'defaults to kDebugMode when WATCH_COMPANION_LOGGING_ENABLED is unset',
      () {
        dotenv.loadFromString(envString: 'TEST_MODE=true');
        AppLogging.reset();
        // The default-on-in-debug pattern mirrors AppLogging.meshcoreLoggingEnabled.
        // Unit tests run in debug mode, so this should be true here, but the
        // assertion is phrased against kDebugMode so the test stays correct
        // regardless of how the test harness is invoked.
        expect(AppLogging.watchCompanionLoggingEnabled, equals(kDebugMode));
      },
    );

    test('explicit WATCH_COMPANION_LOGGING_ENABLED=true forces on', () {
      dotenv.loadFromString(
        envString: 'TEST_MODE=true\nWATCH_COMPANION_LOGGING_ENABLED=true',
      );
      AppLogging.reset();
      expect(AppLogging.watchCompanionLoggingEnabled, isTrue);
    });

    test('explicit WATCH_COMPANION_LOGGING_ENABLED=false forces off, '
        'even in debug mode', () {
      dotenv.loadFromString(
        envString: 'TEST_MODE=true\nWATCH_COMPANION_LOGGING_ENABLED=false',
      );
      AppLogging.reset();
      expect(AppLogging.watchCompanionLoggingEnabled, isFalse);
    });

    test('case-insensitive parsing of true/false', () {
      dotenv.loadFromString(
        envString: 'TEST_MODE=true\nWATCH_COMPANION_LOGGING_ENABLED=FALSE',
      );
      AppLogging.reset();
      expect(AppLogging.watchCompanionLoggingEnabled, isFalse);

      dotenv.clean();
      dotenv.loadFromString(
        envString: 'TEST_MODE=true\nWATCH_COMPANION_LOGGING_ENABLED=True',
      );
      AppLogging.reset();
      expect(AppLogging.watchCompanionLoggingEnabled, isTrue);
    });

    test('invalidateCaches() re-reads the env var on next access', () {
      dotenv.loadFromString(
        envString: 'TEST_MODE=true\nWATCH_COMPANION_LOGGING_ENABLED=true',
      );
      AppLogging.reset();
      expect(AppLogging.watchCompanionLoggingEnabled, isTrue);

      dotenv.clean();
      dotenv.loadFromString(
        envString: 'TEST_MODE=true\nWATCH_COMPANION_LOGGING_ENABLED=false',
      );
      AppLogging.invalidateCaches();
      expect(AppLogging.watchCompanionLoggingEnabled, isFalse);
    });

    test('watchCompanion(...) is a no-op when the gate is off', () {
      dotenv.loadFromString(
        envString: 'TEST_MODE=true\nWATCH_COMPANION_LOGGING_ENABLED=false',
      );
      AppLogging.reset();

      // We can't intercept debugPrint cleanly without monkey-patching the
      // global debugPrint hook, so the contract test here is the simpler:
      // the method exists, accepts a String, and returns void without
      // throwing when the gate is closed. A future change that accidentally
      // makes watchCompanion(...) crash on a closed gate will fail this.
      expect(
        () => AppLogging.watchCompanion('disabled-path smoke test'),
        returnsNormally,
      );
    });
  });
}
