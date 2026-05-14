// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/foundation.dart';

import '../logging.dart';
import 'host_os_stub.dart' if (dart.library.io) 'host_os_io.dart';

/// Coarse grouping of the host platform. Drives the broad feature posture
/// (radio-attached mobile vs network-only desktop vs read-only web).
enum PlatformFamily { mobile, desktop, web }

/// Immutable snapshot of which platform-bound capabilities are available
/// in the current build.
///
/// Capabilities are resolved once at boot via [PlatformCapabilities.detect]
/// and handed to Riverpod through `platformCapabilitiesProvider`. Anything
/// downstream that needs to gate a feature, pick a transport, or render a
/// disabled state reads the resolved bundle through Riverpod rather than
/// calling `Platform.is*` directly. Centralisation is the point: each new
/// capability fans out as one boolean here, not as a fresh `Platform.is*`
/// branch in a screen.
@immutable
class PlatformCapabilities {
  final PlatformFamily platformFamily;

  /// BLE radio is reachable (mobile only today). Web has Web Bluetooth but
  /// flutter_blue_plus does not adapt to it; treat as unsupported.
  final bool supportsBle;

  /// Raw TCP sockets are available. False in browsers (no `dart:io` Socket).
  final bool supportsTcp;

  /// MQTT broker connections are available. False on web in this pass
  /// because MQTT-over-WebSocket is deferred; raw-TCP MQTT cannot work in
  /// a browser tab.
  final bool supportsMqtt;

  /// USB / Serial port access is available. Only Android today; desktop
  /// libserialport wiring is deferred.
  final bool supportsSerial;

  /// Local / push notifications are routable. Desktop notification wiring
  /// is deferred from this foundation pass.
  final bool supportsNotifications;

  /// Background location updates are honoured by the host OS. Desktop and
  /// web cannot deliver mesh-radio-grade background GPS.
  final bool supportsBackgroundLocation;

  /// File export (share sheet on mobile, Save dialog on desktop, browser
  /// Blob download on web) is reachable.
  final bool supportsFileExport;

  /// A secure-storage backend (Keychain / Keystore / system Keyring) is
  /// available. Web is excluded here because the browser equivalents are
  /// not strong enough for the channel keys we hold.
  final bool supportsSecureStorage;

  /// A persistent local SQL database (sqflite native, sqflite_common_ffi
  /// on desktop) is available. Web requires sqflite_ffi_web which is
  /// deferred.
  final bool supportsLocalDatabase;

  /// A web-bridge transport (browser to SocialMesh backend WebSocket that
  /// fronts a real radio) is wired. Reserved flag; not implemented in this
  /// pass. Present so future work does not need to repaint the matrix.
  final bool supportsWebBridge;

  const PlatformCapabilities({
    required this.platformFamily,
    required this.supportsBle,
    required this.supportsTcp,
    required this.supportsMqtt,
    required this.supportsSerial,
    required this.supportsNotifications,
    required this.supportsBackgroundLocation,
    required this.supportsFileExport,
    required this.supportsSecureStorage,
    required this.supportsLocalDatabase,
    required this.supportsWebBridge,
  });

  /// Resolve the capability bundle for the current build.
  ///
  /// Resolution order:
  ///  1. `kIsWeb` first - the only reliable answer in a browser tab; any
  ///     `Platform.is*` access on web throws.
  ///  2. Then `defaultTargetPlatform` from `package:flutter/foundation.dart`.
  ///     `defaultTargetPlatform` is intentionally overridable in tests via
  ///     `debugDefaultTargetPlatformOverride`, which is what test groups
  ///     rely on.
  ///  3. Production cross-check: when `!kIsWeb`, also read
  ///     `Platform.operatingSystem` and prefer its answer if it disagrees
  ///     with `defaultTargetPlatform`. This guards against a test override
  ///     accidentally leaking into a release binary.
  factory PlatformCapabilities.detect() {
    if (kIsWeb) {
      AppLogging.platform('detect: kIsWeb=true -> web bundle');
      return _webBundle;
    }

    final flutterTarget = defaultTargetPlatform;
    final hostOs = hostOperatingSystem();
    final hostTarget = _targetForHostOs(hostOs);

    // Production cross-check: only override defaultTargetPlatform when
    // we are in a release build. Test code legitimately uses
    // `debugDefaultTargetPlatformOverride` to exercise the iOS / Android
    // / desktop branches from a single host; honouring host OS in that
    // mode would defeat the test matrix. In release mode the override
    // hook is a no-op anyway, so the cross-check there is pure safety.
    final crossCheckActive = kReleaseMode && hostTarget != flutterTarget;
    final resolved = crossCheckActive ? hostTarget : flutterTarget;
    if (crossCheckActive) {
      AppLogging.platform(
        'detect: defaultTargetPlatform=$flutterTarget disagrees with '
        'Platform.operatingSystem=$hostOs - preferring host (release cross-check)',
      );
    }

    final bundle = _bundleFor(resolved);
    AppLogging.platform(
      'detect: target=$resolved family=${bundle.platformFamily.name} '
      'ble=${bundle.supportsBle} tcp=${bundle.supportsTcp} '
      'mqtt=${bundle.supportsMqtt} serial=${bundle.supportsSerial} '
      'notif=${bundle.supportsNotifications} bgLoc=${bundle.supportsBackgroundLocation} '
      'fileExport=${bundle.supportsFileExport} secStore=${bundle.supportsSecureStorage} '
      'localDb=${bundle.supportsLocalDatabase} webBridge=${bundle.supportsWebBridge}',
    );
    return bundle;
  }

  /// Build a synthetic capability bundle for tests. Every field is named
  /// and required so the test author makes an explicit choice per axis -
  /// no silent defaults that hide a regression.
  factory PlatformCapabilities.forTesting({
    required PlatformFamily platformFamily,
    required bool supportsBle,
    required bool supportsTcp,
    required bool supportsMqtt,
    required bool supportsSerial,
    required bool supportsNotifications,
    required bool supportsBackgroundLocation,
    required bool supportsFileExport,
    required bool supportsSecureStorage,
    required bool supportsLocalDatabase,
    required bool supportsWebBridge,
  }) {
    return PlatformCapabilities(
      platformFamily: platformFamily,
      supportsBle: supportsBle,
      supportsTcp: supportsTcp,
      supportsMqtt: supportsMqtt,
      supportsSerial: supportsSerial,
      supportsNotifications: supportsNotifications,
      supportsBackgroundLocation: supportsBackgroundLocation,
      supportsFileExport: supportsFileExport,
      supportsSecureStorage: supportsSecureStorage,
      supportsLocalDatabase: supportsLocalDatabase,
      supportsWebBridge: supportsWebBridge,
    );
  }

  static TargetPlatform _targetForHostOs(String hostOs) {
    switch (hostOs) {
      case 'ios':
        return TargetPlatform.iOS;
      case 'android':
        return TargetPlatform.android;
      case 'macos':
        return TargetPlatform.macOS;
      case 'windows':
        return TargetPlatform.windows;
      case 'linux':
        return TargetPlatform.linux;
      case 'fuchsia':
        return TargetPlatform.fuchsia;
    }
    return defaultTargetPlatform;
  }

  static PlatformCapabilities _bundleFor(TargetPlatform target) {
    switch (target) {
      case TargetPlatform.iOS:
        return _iosBundle;
      case TargetPlatform.android:
        return _androidBundle;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return _desktopBundle;
      case TargetPlatform.fuchsia:
        return _desktopBundle;
    }
  }

  static const PlatformCapabilities _iosBundle = PlatformCapabilities(
    platformFamily: PlatformFamily.mobile,
    supportsBle: true,
    supportsTcp: true,
    supportsMqtt: true,
    supportsSerial: false,
    supportsNotifications: true,
    supportsBackgroundLocation: true,
    supportsFileExport: true,
    supportsSecureStorage: true,
    supportsLocalDatabase: true,
    supportsWebBridge: false,
  );

  static const PlatformCapabilities _androidBundle = PlatformCapabilities(
    platformFamily: PlatformFamily.mobile,
    supportsBle: true,
    supportsTcp: true,
    supportsMqtt: true,
    supportsSerial: true,
    supportsNotifications: true,
    supportsBackgroundLocation: true,
    supportsFileExport: true,
    supportsSecureStorage: true,
    supportsLocalDatabase: true,
    supportsWebBridge: false,
  );

  static const PlatformCapabilities _desktopBundle = PlatformCapabilities(
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

  static const PlatformCapabilities _webBundle = PlatformCapabilities(
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlatformCapabilities &&
          runtimeType == other.runtimeType &&
          platformFamily == other.platformFamily &&
          supportsBle == other.supportsBle &&
          supportsTcp == other.supportsTcp &&
          supportsMqtt == other.supportsMqtt &&
          supportsSerial == other.supportsSerial &&
          supportsNotifications == other.supportsNotifications &&
          supportsBackgroundLocation == other.supportsBackgroundLocation &&
          supportsFileExport == other.supportsFileExport &&
          supportsSecureStorage == other.supportsSecureStorage &&
          supportsLocalDatabase == other.supportsLocalDatabase &&
          supportsWebBridge == other.supportsWebBridge;

  @override
  int get hashCode => Object.hash(
    platformFamily,
    supportsBle,
    supportsTcp,
    supportsMqtt,
    supportsSerial,
    supportsNotifications,
    supportsBackgroundLocation,
    supportsFileExport,
    supportsSecureStorage,
    supportsLocalDatabase,
    supportsWebBridge,
  );

  @override
  String toString() =>
      'PlatformCapabilities(family: ${platformFamily.name}, '
      'ble: $supportsBle, tcp: $supportsTcp, mqtt: $supportsMqtt, '
      'serial: $supportsSerial, notif: $supportsNotifications, '
      'bgLoc: $supportsBackgroundLocation, fileExport: $supportsFileExport, '
      'secStore: $supportsSecureStorage, localDb: $supportsLocalDatabase, '
      'webBridge: $supportsWebBridge)';
}
