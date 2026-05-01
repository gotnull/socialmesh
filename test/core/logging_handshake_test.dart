// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/logging.dart';

void main() {
  group('AppLogging HANDSHAKE_LOGGING_ENABLED shorthand', () {
    tearDown(() {
      AppLogging.reset();
      dotenv.clean();
    });

    test('defaults to false when nothing is set', () {
      dotenv.loadFromString(envString: 'TEST_MODE=true');
      AppLogging.reset();
      expect(AppLogging.handshakeLoggingEnabled, isFalse);
      expect(AppLogging.sipLoggingEnabled, isFalse);
      expect(AppLogging.sipInkLoggingEnabled, isFalse);
      expect(AppLogging.sipPlayLoggingEnabled, isFalse);
      expect(AppLogging.sipSignalLoggingEnabled, isFalse);
      expect(AppLogging.overlayLoggingEnabled, isFalse);
      expect(AppLogging.mrrpDebugEnabled, isFalse);
    });

    test('HANDSHAKE_LOGGING_ENABLED=true forces all six handshake logs on', () {
      dotenv.loadFromString(
        envString: 'TEST_MODE=true\nHANDSHAKE_LOGGING_ENABLED=true',
      );
      AppLogging.reset();
      expect(AppLogging.handshakeLoggingEnabled, isTrue);
      expect(AppLogging.sipLoggingEnabled, isTrue);
      expect(AppLogging.sipInkLoggingEnabled, isTrue);
      expect(AppLogging.sipPlayLoggingEnabled, isTrue);
      expect(AppLogging.sipSignalLoggingEnabled, isTrue);
      expect(AppLogging.overlayLoggingEnabled, isTrue);
      expect(AppLogging.mrrpDebugEnabled, isTrue);
    });

    test('granular flags still work independently when shorthand is off', () {
      dotenv.loadFromString(
        envString:
            'TEST_MODE=true\n'
            'HANDSHAKE_LOGGING_ENABLED=false\n'
            'SIP_LOGGING_ENABLED=true\n'
            'OVERLAY_LOGGING_ENABLED=true',
      );
      AppLogging.reset();
      expect(AppLogging.handshakeLoggingEnabled, isFalse);
      expect(AppLogging.sipLoggingEnabled, isTrue);
      expect(AppLogging.sipInkLoggingEnabled, isFalse);
      expect(AppLogging.overlayLoggingEnabled, isTrue);
      expect(AppLogging.mrrpDebugEnabled, isFalse);
    });

    test('shorthand overrides explicitly-false granular flags', () {
      dotenv.loadFromString(
        envString:
            'TEST_MODE=true\n'
            'HANDSHAKE_LOGGING_ENABLED=true\n'
            'SIP_LOGGING_ENABLED=false\n'
            'OVERLAY_LOGGING_ENABLED=false\n'
            'MRRP_DEBUG=false',
      );
      AppLogging.reset();
      expect(AppLogging.sipLoggingEnabled, isTrue);
      expect(AppLogging.overlayLoggingEnabled, isTrue);
      expect(AppLogging.mrrpDebugEnabled, isTrue);
    });
  });
}
