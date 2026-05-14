// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/platform/platform_capabilities.dart';

void main() {
  group('PlatformCapabilities.detect', () {
    // The mobile bundles are regression pins: any drift here means
    // a multi-platform pass accidentally changed iOS/Android behaviour.
    // Treat failures here as critical.

    test('iOS bundle is the mobile baseline', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final caps = PlatformCapabilities.detect();

      expect(caps.platformFamily, PlatformFamily.mobile);
      expect(caps.supportsBle, isTrue);
      expect(caps.supportsTcp, isTrue);
      expect(caps.supportsMqtt, isTrue);
      expect(
        caps.supportsSerial,
        isFalse,
        reason: 'iOS does not expose USB serial',
      );
      expect(caps.supportsNotifications, isTrue);
      expect(caps.supportsBackgroundLocation, isTrue);
      expect(caps.supportsFileExport, isTrue);
      expect(caps.supportsSecureStorage, isTrue);
      expect(caps.supportsLocalDatabase, isTrue);
      expect(caps.supportsWebBridge, isFalse);
    });

    test('Android bundle adds USB serial to the mobile baseline', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final caps = PlatformCapabilities.detect();

      expect(caps.platformFamily, PlatformFamily.mobile);
      expect(caps.supportsBle, isTrue);
      expect(caps.supportsTcp, isTrue);
      expect(caps.supportsMqtt, isTrue);
      expect(caps.supportsSerial, isTrue, reason: 'Android exposes USB serial');
      expect(caps.supportsNotifications, isTrue);
      expect(caps.supportsBackgroundLocation, isTrue);
      expect(caps.supportsFileExport, isTrue);
      expect(caps.supportsSecureStorage, isTrue);
      expect(caps.supportsLocalDatabase, isTrue);
      expect(caps.supportsWebBridge, isFalse);
    });

    test(
      'macOS bundle is the desktop baseline (TCP + MQTT, no BLE/serial)',
      () {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final caps = PlatformCapabilities.detect();

        expect(caps.platformFamily, PlatformFamily.desktop);
        expect(caps.supportsBle, isFalse);
        expect(caps.supportsTcp, isTrue);
        expect(caps.supportsMqtt, isTrue);
        expect(
          caps.supportsSerial,
          isFalse,
          reason: 'foundation pass defers desktop USB serial',
        );
        expect(
          caps.supportsNotifications,
          isFalse,
          reason: 'foundation pass defers desktop notification wiring',
        );
        expect(caps.supportsBackgroundLocation, isFalse);
        expect(caps.supportsFileExport, isTrue);
        expect(caps.supportsSecureStorage, isTrue);
        expect(caps.supportsLocalDatabase, isTrue);
        expect(caps.supportsWebBridge, isFalse);
      },
    );

    test('Windows bundle matches the desktop baseline', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final caps = PlatformCapabilities.detect();

      expect(caps.platformFamily, PlatformFamily.desktop);
      expect(caps.supportsTcp, isTrue);
      expect(caps.supportsMqtt, isTrue);
      expect(caps.supportsBle, isFalse);
      expect(caps.supportsSerial, isFalse);
    });

    test('Linux bundle matches the desktop baseline', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final caps = PlatformCapabilities.detect();

      expect(caps.platformFamily, PlatformFamily.desktop);
      expect(caps.supportsTcp, isTrue);
      expect(caps.supportsMqtt, isTrue);
      expect(caps.supportsBle, isFalse);
      expect(caps.supportsSerial, isFalse);
    });
  });

  group('PlatformCapabilities.forTesting', () {
    test('returns the exact bundle the test author specified', () {
      final caps = PlatformCapabilities.forTesting(
        platformFamily: PlatformFamily.web,
        supportsBle: false,
        supportsTcp: false,
        supportsMqtt: false,
        supportsSerial: false,
        supportsNotifications: false,
        supportsBackgroundLocation: false,
        supportsFileExport: true,
        supportsSecureStorage: false,
        supportsLocalDatabase: false,
        supportsWebBridge: false,
      );

      expect(caps.platformFamily, PlatformFamily.web);
      expect(caps.supportsBle, isFalse);
      expect(caps.supportsTcp, isFalse);
      expect(caps.supportsFileExport, isTrue);
    });

    test('two bundles with identical fields are equal', () {
      final a = PlatformCapabilities.forTesting(
        platformFamily: PlatformFamily.desktop,
        supportsBle: false,
        supportsTcp: true,
        supportsMqtt: true,
        supportsSerial: false,
        supportsNotifications: false,
        supportsBackgroundLocation: false,
        supportsFileExport: true,
        supportsSecureStorage: true,
        supportsLocalDatabase: true,
        supportsWebBridge: false,
      );
      final b = PlatformCapabilities.forTesting(
        platformFamily: PlatformFamily.desktop,
        supportsBle: false,
        supportsTcp: true,
        supportsMqtt: true,
        supportsSerial: false,
        supportsNotifications: false,
        supportsBackgroundLocation: false,
        supportsFileExport: true,
        supportsSecureStorage: true,
        supportsLocalDatabase: true,
        supportsWebBridge: false,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
