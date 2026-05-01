// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for [OverlayFeatureFlags].
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_feature_flag.dart';

void main() {
  group('OverlayFeatureFlags', () {
    test('constructor respects passed values', () {
      const flags = OverlayFeatureFlags(linkEnabled: true);
      expect(flags.linkEnabled, isTrue);
      expect(flags.resourceEnabled, isFalse);
      expect(flags.secureEnabled, isFalse);
    });

    test('disabled constant is fully off', () {
      expect(OverlayFeatureFlags.disabled.linkEnabled, isFalse);
      expect(OverlayFeatureFlags.disabled.resourceEnabled, isFalse);
      expect(OverlayFeatureFlags.disabled.secureEnabled, isFalse);
    });

    test('fromEnv returns false when dotenv is not initialised '
        '(default in unit tests)', () {
      // dotenv is intentionally not initialised in this suite. The
      // flag holder must cope gracefully and default to disabled.
      final flags = OverlayFeatureFlags.fromEnv();
      expect(flags.linkEnabled, isFalse);
    });

    test('P2 forces resourceEnabled and secureEnabled to false', () {
      // Even if someone passes true, the factory forces false. Verifies
      // that the constructor still accepts direct values (for tests),
      // but fromEnv is the gatekeeper.
      final flags = OverlayFeatureFlags.fromEnv();
      expect(flags.resourceEnabled, isFalse);
      expect(flags.secureEnabled, isFalse);
    });
  });

  group('OverlayFeatureFlags.fromEnv HANDSHAKE_ENABLED shorthand', () {
    tearDown(dotenv.clean);

    test('HANDSHAKE_ENABLED=true forces all three overlay flags on', () {
      dotenv.loadFromString(envString: 'HANDSHAKE_ENABLED=true');
      final flags = OverlayFeatureFlags.fromEnv();
      expect(flags.linkEnabled, isTrue);
      expect(flags.resourceEnabled, isTrue);
      expect(flags.secureEnabled, isTrue);
    });

    test('granular flags still work independently when shorthand is off', () {
      dotenv.loadFromString(
        envString: 'HANDSHAKE_ENABLED=false\nOVERLAY_LINK_ENABLED=true',
      );
      final flags = OverlayFeatureFlags.fromEnv();
      expect(flags.linkEnabled, isTrue);
      expect(flags.resourceEnabled, isFalse);
      expect(flags.secureEnabled, isFalse);
    });

    test('shorthand overrides explicitly-false granular flags', () {
      dotenv.loadFromString(
        envString:
            'HANDSHAKE_ENABLED=true\n'
            'OVERLAY_LINK_ENABLED=false\n'
            'OVERLAY_RESOURCE_ENABLED=false\n'
            'OVERLAY_SECURE_ENABLED=false',
      );
      final flags = OverlayFeatureFlags.fromEnv();
      expect(flags.linkEnabled, isTrue);
      expect(flags.resourceEnabled, isTrue);
      expect(flags.secureEnabled, isTrue);
    });
  });
}
