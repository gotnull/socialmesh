// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/platform/noop_device_transport.dart';
import 'package:socialmesh/core/platform/platform_capabilities.dart';
import 'package:socialmesh/core/platform/platform_capabilities_provider.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/providers/app_providers.dart';

PlatformCapabilities _webBundle() => PlatformCapabilities.forTesting(
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

PlatformCapabilities _desktopBundle() => PlatformCapabilities.forTesting(
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

void main() {
  group('bleScanTransportProvider', () {
    test('returns NoopDeviceTransport when BLE is unsupported', () {
      final container = ProviderContainer(
        overrides: [
          platformCapabilitiesProvider.overrideWithValue(_webBundle()),
        ],
      );
      addTearDown(container.dispose);

      final transport = container.read(bleScanTransportProvider);
      expect(transport, isA<NoopDeviceTransport>());
      expect(transport.type, TransportType.ble);
      expect(transport.state, DeviceConnectionState.disconnected);
    });
  });

  group('transportProvider', () {
    test(
      'falls back to network when requested BLE is unsupported on desktop',
      () {
        final container = ProviderContainer(
          overrides: [
            platformCapabilitiesProvider.overrideWithValue(_desktopBundle()),
            transportTypeProvider.overrideWith(
              () => _StubTransportType(TransportType.ble),
            ),
          ],
        );
        addTearDown(container.dispose);

        final transport = container.read(transportProvider);
        // Desktop supports TCP, so the network transport should be picked.
        expect(transport.type, TransportType.network);
      },
    );

    test('returns NoopDeviceTransport when no transport is supported', () {
      final container = ProviderContainer(
        overrides: [
          platformCapabilitiesProvider.overrideWithValue(_webBundle()),
          transportTypeProvider.overrideWith(
            () => _StubTransportType(TransportType.ble),
          ),
        ],
      );
      addTearDown(container.dispose);

      final transport = container.read(transportProvider);
      expect(transport, isA<NoopDeviceTransport>());
      // The Noop preserves the originally-requested type for logging
      // visibility.
      expect(transport.type, TransportType.ble);
    });
  });
}

/// Minimal stub Notifier so test setups can pin a specific TransportType
/// through the same override mechanism the real provider uses, without
/// dragging in shared_preferences. Extends [TransportTypeNotifier] so its
/// type signature matches what `transportTypeProvider.overrideWith`
/// expects.
class _StubTransportType extends TransportTypeNotifier {
  _StubTransportType(this._initial);
  final TransportType _initial;

  @override
  TransportType build() => _initial;
}
