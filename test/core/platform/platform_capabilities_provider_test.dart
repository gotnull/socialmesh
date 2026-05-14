// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/platform/platform_capabilities.dart';
import 'package:socialmesh/core/platform/platform_capabilities_provider.dart';

void main() {
  group('platformCapabilitiesProvider', () {
    test('yields the overridden value verbatim', () {
      final desktop = PlatformCapabilities.forTesting(
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

      final container = ProviderContainer(
        overrides: [platformCapabilitiesProvider.overrideWithValue(desktop)],
      );
      addTearDown(container.dispose);

      expect(container.read(platformCapabilitiesProvider), same(desktop));
    });

    test('is stable for the container lifetime', () {
      final web = PlatformCapabilities.forTesting(
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

      final container = ProviderContainer(
        overrides: [platformCapabilitiesProvider.overrideWithValue(web)],
      );
      addTearDown(container.dispose);

      final first = container.read(platformCapabilitiesProvider);
      final second = container.read(platformCapabilitiesProvider);
      expect(identical(first, second), isTrue);
    });
  });
}
