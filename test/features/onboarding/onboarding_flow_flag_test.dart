// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/onboarding/onboarding_flow_flag.dart';

/// Pins the [MeshtasticOnboardingFlowFlags] resolution policy:
///   - env override always wins
///   - missing/unparseable env + debug/profile build -> ON
///   - missing/unparseable env + release build -> OFF
///
/// `disabled` and `enabledForTests` constants exist for tests that
/// need a known-shape flag without dotenv.
void main() {
  group('MeshtasticOnboardingFlowFlags constants', () {
    test('disabled is enabled=false', () {
      expect(MeshtasticOnboardingFlowFlags.disabled.enabled, isFalse);
    });

    test('enabledForTests is enabled=true', () {
      expect(MeshtasticOnboardingFlowFlags.enabledForTests.enabled, isTrue);
    });
  });

  group('MeshtasticOnboardingFlowFlags.fromEnv()', () {
    setUp(() {
      // dotenv loadFromString rejects empty input. Seed with a
      // benign sentinel so tests that need an absent key reload
      // with this minimal env.
      dotenv.loadFromString(envString: 'OTHER_KEY=ignore');
    });

    test('env=true forces enabled regardless of build mode', () {
      dotenv.loadFromString(
        envString: 'MESHTASTIC_ONBOARDING_FLOW_ENABLED=true',
      );
      expect(MeshtasticOnboardingFlowFlags.fromEnv().enabled, isTrue);
    });

    test('env=false forces disabled regardless of build mode', () {
      dotenv.loadFromString(
        envString: 'MESHTASTIC_ONBOARDING_FLOW_ENABLED=false',
      );
      expect(MeshtasticOnboardingFlowFlags.fromEnv().enabled, isFalse);
    });

    test('missing env follows kDebugMode||kProfileMode default', () {
      dotenv.loadFromString(envString: 'OTHER_KEY=ignore');
      final defaultOn = kDebugMode || kProfileMode;
      expect(MeshtasticOnboardingFlowFlags.fromEnv().enabled, defaultOn);
    });

    test('unparseable env follows build-mode default', () {
      dotenv.loadFromString(
        envString: 'MESHTASTIC_ONBOARDING_FLOW_ENABLED=mango',
      );
      final defaultOn = kDebugMode || kProfileMode;
      expect(MeshtasticOnboardingFlowFlags.fromEnv().enabled, defaultOn);
    });

    test('whitespace and case are tolerated', () {
      dotenv.loadFromString(
        envString: 'MESHTASTIC_ONBOARDING_FLOW_ENABLED= TRUE ',
      );
      expect(MeshtasticOnboardingFlowFlags.fromEnv().enabled, isTrue);
      dotenv.loadFromString(
        envString: 'MESHTASTIC_ONBOARDING_FLOW_ENABLED=False',
      );
      expect(MeshtasticOnboardingFlowFlags.fromEnv().enabled, isFalse);
    });
  });
}
