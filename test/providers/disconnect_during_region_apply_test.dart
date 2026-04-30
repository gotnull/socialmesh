// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';

/// Regression coverage for the disconnect/scanner/region-apply
/// state-machine ownership work.
///
/// **Companion widget tests deferred (TODO):**
/// - T1: device sheet disconnect never exposes scan CTA mid-teardown.
///   Requires ProviderScope + Navigator + AppBottomSheet plumbing.
/// - T2: Scanner has no back arrow when `isOnboarding == false` and
///   `PopScope(canPop: false)` blocks system back. Requires building
///   the full Scanner widget which has many transport / settings /
///   BLE provider deps.
/// - T3: Region selection completion promotes to MainShell exactly
///   once. Requires driving the protocol-service and region-stream
///   pipeline through a full async flow.
///
/// All three are valuable but each requires substantial ProviderScope
/// + transport-fake scaffolding. Tracked for follow-up. The
/// state-machine gate (B3) — by far the most subtle regression — is
/// pinned by the test below at the provider layer using only the
/// public `debugHandleDisconnectForTest` seam.
///
/// Regression for B3: when a device disconnects during a region apply
/// (the device reboot is *expected*), `_handleDisconnect` must NOT
/// call `setNeedsScanner()`. Otherwise it stomps the
/// `RegionSelectionScreen.setInitialized()` write made by the scanner
/// post-region success path, leaving the user on the connecting splash.
///
/// The gate uses `regionConfigProvider.applyStatus == applying` as the
/// source of truth — no separate "in-flight" provider was introduced
/// because the existing status flag is already set/cleared by the
/// region apply lifecycle and survives the expected disconnect window.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'auth-fail disconnect during regionConfig.applying does NOT route '
    'to needsScanner — preserves the post-region MainShell promotion',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Seed: device connected, region apply in flight.
      container
          .read(deviceConnectionProvider.notifier)
          .setTestState(
            DeviceConnectionState2(
              state: DevicePairingState.connected,
              device: DeviceInfo(
                id: 'device-alpha',
                name: 'Region Device',
                type: TransportType.ble,
              ),
              connectionSessionId: 1,
              lastConnectedAt: DateTime.now(),
            ),
          );

      // Set the in-flight flag directly. Production sets this in
      // `RegionConfigNotifier.applyRegion` at the apply-start edge
      // and clears it in the `finally`. We use the leaf provider
      // because `_handleDisconnect` reads the same leaf to avoid a
      // circular dependency on `regionConfigProvider` (whose build
      // listens to `deviceConnectionProvider`).
      container.read(regionApplyInFlightProvider.notifier).setActive(true);
      expect(container.read(regionApplyInFlightProvider), isTrue);

      // App is currently `ready` (we're on MainShell mid-region-apply).
      // Production reaches `ready` via the AppInit init pipeline; we
      // set it directly here so the rest of the test can verify the
      // gate behaviour.
      container.read(appInitProvider.notifier).setReady();
      expect(container.read(appInitProvider), AppInitState.ready);

      // Drive `_handleDisconnect` with an auth-fail reason as if the
      // expected reboot tripped the auth path.
      container
          .read(deviceConnectionProvider.notifier)
          .debugHandleDisconnectForTest(DisconnectReason.authFailed);

      // The fix: while applyStatus == applying, the auth-fail branch
      // skips `setNeedsScanner()`. App stays at `ready`. The
      // RegionSelectionScreen's `setInitialized()` (already on `ready`)
      // is preserved. Reconnect after reboot promotes naturally.
      expect(
        container.read(appInitProvider),
        AppInitState.ready,
        reason:
            'Auth-fail disconnect during region apply must NOT stomp '
            'appInit to needsScanner. Stomping leaves the user on the '
            'connecting splash because `_AppRouter` reroutes to '
            'Scanner after the RegionSelectionScreen pop.',
      );
    },
  );

  test('auth-fail disconnect when region apply is NOT in flight DOES '
      'route to needsScanner — preserves the original auth-fail UX', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(deviceConnectionProvider.notifier)
        .setTestState(
          DeviceConnectionState2(
            state: DevicePairingState.connected,
            device: DeviceInfo(
              id: 'device-alpha',
              name: 'Plain Device',
              type: TransportType.ble,
            ),
            connectionSessionId: 1,
            lastConnectedAt: DateTime.now(),
          ),
        );

    // Region apply is NOT in flight.
    expect(
      container.read(regionConfigProvider).applyStatus,
      RegionApplyStatus.idle,
    );
    container.read(appInitProvider.notifier).setReady();
    expect(container.read(appInitProvider), AppInitState.ready);

    container
        .read(deviceConnectionProvider.notifier)
        .debugHandleDisconnectForTest(DisconnectReason.authFailed);

    expect(
      container.read(appInitProvider),
      AppInitState.needsScanner,
      reason:
          'Auth-fail outside the region-apply window must still route '
          'to Scanner so the user gets pairing-invalidation guidance.',
    );
  });
}
