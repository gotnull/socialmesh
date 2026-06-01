// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Pins RemoteFlagOverridesService.effectiveBoolFor — the resolver the
// admin sheet uses to render each flag's switch. It must agree with the
// AppFeatureFlags / AppLogging getter semantics for both opt-in
// (default-false) and opt-out (default-true) keys, so an unset opt-out
// flag (e.g. STRIPE_PURCHASES_ENABLED) shows ON, not OFF.

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/config/remote_flag_overrides_service.dart';

void main() {
  final service = RemoteFlagOverridesService.instance;

  setUpAll(() {
    dotenv.loadFromString(envString: '_EFFECTIVE_BOOL_TEST_INIT=1');
  });

  setUp(() {
    dotenv.env.remove('STRIPE_PURCHASES_ENABLED');
    dotenv.env.remove('MESHCORE_ENABLED');
  });

  group('opt-out key (STRIPE_PURCHASES_ENABLED)', () {
    test('unset resolves to true (default-on)', () {
      expect(service.effectiveBoolFor('STRIPE_PURCHASES_ENABLED'), isTrue);
    });

    test('"false" resolves to false', () {
      dotenv.env['STRIPE_PURCHASES_ENABLED'] = 'false';
      expect(service.effectiveBoolFor('STRIPE_PURCHASES_ENABLED'), isFalse);
    });

    test('"true" resolves to true', () {
      dotenv.env['STRIPE_PURCHASES_ENABLED'] = 'true';
      expect(service.effectiveBoolFor('STRIPE_PURCHASES_ENABLED'), isTrue);
    });

    test('unparseable value resolves to true (only "false" disables)', () {
      dotenv.env['STRIPE_PURCHASES_ENABLED'] = 'garbage';
      expect(service.effectiveBoolFor('STRIPE_PURCHASES_ENABLED'), isTrue);
    });

    test('is in the allowlist and the default-true set', () {
      expect(
        RemoteFlagOverridesService.allowedKeys,
        contains('STRIPE_PURCHASES_ENABLED'),
      );
      expect(
        RemoteFlagOverridesService.defaultTrueKeys,
        contains('STRIPE_PURCHASES_ENABLED'),
      );
    });
  });

  group('opt-in key (MESHCORE_ENABLED)', () {
    test('unset resolves to false (default-off)', () {
      expect(service.effectiveBoolFor('MESHCORE_ENABLED'), isFalse);
    });

    test('"true" resolves to true', () {
      dotenv.env['MESHCORE_ENABLED'] = 'true';
      expect(service.effectiveBoolFor('MESHCORE_ENABLED'), isTrue);
    });

    test('"1" resolves to true', () {
      dotenv.env['MESHCORE_ENABLED'] = '1';
      expect(service.effectiveBoolFor('MESHCORE_ENABLED'), isTrue);
    });

    test('unparseable value resolves to false (fail-safe)', () {
      dotenv.env['MESHCORE_ENABLED'] = 'garbage';
      expect(service.effectiveBoolFor('MESHCORE_ENABLED'), isFalse);
    });

    test('is not in the default-true set', () {
      expect(
        RemoteFlagOverridesService.defaultTrueKeys,
        isNot(contains('MESHCORE_ENABLED')),
      );
    });
  });
}
