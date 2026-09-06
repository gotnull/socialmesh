// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/dev/demo/demo_config.dart';

void main() {
  group('DemoConfig.parseFlag', () {
    test('accepts the documented =1 spelling', () {
      expect(DemoConfig.parseFlag('1'), isTrue);
    });

    test('accepts =true', () {
      expect(DemoConfig.parseFlag('true'), isTrue);
    });

    test('rejects unset, off and unrelated values', () {
      for (final raw in ['', '0', 'false', 'yes', 'TRUE', ' 1']) {
        expect(DemoConfig.parseFlag(raw), isFalse, reason: 'raw="$raw"');
      }
    });
  });

  group('DemoConfig.isEnabled', () {
    test('mirrors parseFlag over the raw define, gated on debug mode', () {
      const raw = String.fromEnvironment('SOCIALMESH_DEMO');
      expect(DemoConfig.isEnabled, kDebugMode && DemoConfig.parseFlag(raw));
    });

    test('modeLabel follows isEnabled', () {
      expect(DemoConfig.modeLabel, DemoConfig.isEnabled ? '[DEMO]' : '');
    });
  });
}
