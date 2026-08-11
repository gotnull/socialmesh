// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// MeshCore-specific lifecycle listener (D27).
//
// Closes the foreground/resume reconnect gap left by the Meshtastic-only
// auto-reconnect manager. That listener watches `connectionStateProvider`
// (Meshtastic transport state) and bails when `lastDeviceProtocol ==
// 'meshcore'` (app_providers.dart). Without this provider a MeshCore TCP
// peer that drops while the app is backgrounded by an OS permission
// dialog never gets a foreground recovery attempt.
//
// Two listeners live here:
//
// 1. App foreground -> if last protocol is MeshCore and we're not
//    connected/connecting/userDisconnected, dispatch a reconnect through
//    the protocol-aware helper.
//
// 2. MeshCore connection state stream -> on a transition into
//    `disconnected` while the MeshCore shell is active and the user did
//    not initiate it, dispatch a reconnect.
//
// Protocol Isolation: this provider never touches `transportProvider` or
// any Meshtastic transport. All reconnects route through
// `dispatchReconnectMeshCoreAware`, which routes MeshCore peers into
// `DeviceConnectionNotifier.startMeshCoreReconnect` and ConnectionCoordinator.

import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../models/mesh_device.dart' show MeshConnectionState;
import '../services/meshcore/connection_coordinator.dart';
import '../services/meshcore/meshcore_os_reconnect_armer.dart';
import '../services/transport/background_ble_service.dart';
import 'app_lifecycle_provider.dart';
import 'app_providers.dart';
import 'meshcore_providers.dart';

/// Outcome of evaluating the MeshCore reconnect gate.
///
/// `proceed` means the dispatcher should fire. `skipReason` carries the
/// reason for telemetry when `proceed` is false.
@visibleForTesting
class MeshCoreReconnectGateOutcome {
  final bool proceed;
  final String? skipReason;
  const MeshCoreReconnectGateOutcome._(this.proceed, this.skipReason);
  factory MeshCoreReconnectGateOutcome.proceed() =>
      const MeshCoreReconnectGateOutcome._(true, null);
  factory MeshCoreReconnectGateOutcome.skip(String reason) =>
      MeshCoreReconnectGateOutcome._(false, reason);
}

/// Pure predicate over the lifecycle gate inputs. Extracted so the gate
/// rules can be exercised in unit tests without a live `ProviderContainer`,
/// `SettingsService`, or `ConnectionCoordinator`.
///
/// All inputs are plain values — the live provider reads them inside
/// [meshCoreLifecycleProvider] and forwards them here. Order of checks
/// mirrors the live path so test cases pin which reason fires for a
/// given input combination.
@visibleForTesting
MeshCoreReconnectGateOutcome evaluateMeshCoreReconnectGate({
  required bool withinCooldown,
  required String? lastDeviceProtocol,
  required String? lastDeviceId,
  required bool autoReconnectEnabled,
  required bool userDisconnected,
  required bool coordinatorConnected,
  required bool coordinatorConnecting,
  required bool autoReconnectInProgress,
}) {
  if (withinCooldown) {
    return MeshCoreReconnectGateOutcome.skip('cooldown');
  }
  if (lastDeviceProtocol != 'meshcore') {
    return MeshCoreReconnectGateOutcome.skip('not_meshcore');
  }
  if (lastDeviceId == null) {
    return MeshCoreReconnectGateOutcome.skip('no_saved_device');
  }
  if (!autoReconnectEnabled) {
    return MeshCoreReconnectGateOutcome.skip('auto_reconnect_disabled');
  }
  if (userDisconnected) {
    return MeshCoreReconnectGateOutcome.skip('user_disconnected');
  }
  if (coordinatorConnected || coordinatorConnecting) {
    return MeshCoreReconnectGateOutcome.skip('already_active');
  }
  if (autoReconnectInProgress) {
    return MeshCoreReconnectGateOutcome.skip('already_reconnecting');
  }
  return MeshCoreReconnectGateOutcome.proceed();
}

/// `Provider<void>` wired into the app root via `ref.watch` so it survives
/// for the entire app lifetime regardless of which shell is mounted.
///
/// Watch from a long-lived widget (e.g., `_SocialMeshApp.build`) alongside
/// `autoReconnectManagerProvider`.
final meshCoreLifecycleProvider = Provider<void>((ref) {
  AppLogging.connection('🔄 meshCoreLifecycleProvider INITIALIZED');

  // iOS background recovery: at most one OS-level pending-reconnect
  // registration lives here. Armed instead of the immediate dispatch when
  // a BLE peer drops while the app is backgrounded; its callback routes
  // straight back into the canonical coordinator reconnect below.
  final osReconnectArmer = MeshCoreOsReconnectArmer();
  ref.onDispose(osReconnectArmer.dispose);

  // Tracks whether we recently fired a reconnect attempt so the foreground
  // and stream listeners can't double-arm in the same window.
  DateTime? lastDispatchAt;
  const dispatchCooldown = Duration(seconds: 5);

  bool isWithinCooldown() {
    final last = lastDispatchAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < dispatchCooldown;
  }

  Future<void> maybeReconnect(String trigger) async {
    final settings = await ref.read(settingsServiceProvider.future);
    final coordinator = ref.read(connectionCoordinatorProvider);
    final autoState = ref.read(autoReconnectStateProvider);

    final outcome = evaluateMeshCoreReconnectGate(
      withinCooldown: isWithinCooldown(),
      lastDeviceProtocol: settings.lastDeviceProtocol,
      lastDeviceId: settings.lastDeviceId,
      autoReconnectEnabled: settings.autoReconnect,
      userDisconnected: ref.read(userDisconnectedProvider),
      coordinatorConnected: coordinator.isConnected,
      coordinatorConnecting: coordinator.isConnecting,
      autoReconnectInProgress:
          autoState == AutoReconnectState.scanning ||
          autoState == AutoReconnectState.connecting,
    );

    if (!outcome.proceed) {
      AppLogging.meshcore(
        'event=reconnect.skipped reason=${outcome.skipReason} '
        'trigger=$trigger',
      );
      return;
    }

    final lastDeviceId = settings.lastDeviceId!;
    final isTcp = MeshCoreTcpDeviceId.tryParse(lastDeviceId) != null;

    // Background BLE drop on iOS: an immediate direct-connect attempt
    // would die with the suspend, so register an OS-level pending
    // reconnect instead. iOS re-establishes the link whenever the radio
    // reappears and wakes the app; the callback then dispatches the same
    // canonical reconnect path used everywhere else.
    final isForeground = ref.read(appLifecycleProvider);
    final backgroundBleEnabled = !isForeground && !isTcp
        ? await BackgroundBleService.isBackgroundBleEnabled()
        : false;
    if (!ref.mounted) return;
    if (shouldArmMeshCoreOsReconnect(
      platform: defaultTargetPlatform,
      isForeground: isForeground,
      isTcpDevice: isTcp,
      coordinatorConnected: coordinator.isConnected,
      coordinatorConnecting: coordinator.isConnecting,
      alreadyArmed: osReconnectArmer.isArmed,
      backgroundBleEnabled: backgroundBleEnabled,
    )) {
      lastDispatchAt = DateTime.now();
      AppLogging.meshcore(
        'event=reconnect.route route=os_pending_reconnect trigger=$trigger',
      );
      await osReconnectArmer.arm(
        deviceId: lastDeviceId,
        onLinkReestablished: (deviceId) async {
          if (!ref.mounted) return;
          lastDispatchAt = DateTime.now();
          AppLogging.meshcore(
            'event=reconnect.started trigger=os_pending_reconnect '
            'transport=ble',
          );
          ref
              .read(autoReconnectStateProvider.notifier)
              .setState(AutoReconnectState.scanning);
          dispatchReconnectMeshCoreAware(ref, deviceId);
        },
      );
      return;
    }

    lastDispatchAt = DateTime.now();
    AppLogging.meshcore(
      'event=reconnect.started trigger=$trigger '
      'transport=${isTcp ? "tcp" : "ble"}',
    );
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.scanning);
    dispatchReconnectMeshCoreAware(ref, lastDeviceId);
  }

  // Foreground transitions trigger a check.
  ref.listen<bool>(appLifecycleProvider, (previous, isForeground) {
    if (!isForeground) return;
    // Foreground recovery owns the flow from here: stop listening for the
    // OS-level link event so it can't double-dispatch. The registration
    // itself stays as a safety net; the next transport disconnect clears
    // it.
    if (osReconnectArmer.isArmed) {
      unawaited(osReconnectArmer.cancel(releaseRegistration: false));
    }
    // Wait a tick so platform channels (BT adapter state, etc.) settle
    // before we kick off a reconnect.
    Timer(const Duration(milliseconds: 250), () {
      if (!ref.mounted) return;
      maybeReconnect('foreground');
    });
  });

  // User-initiated disconnect: a peer armed for background recovery must
  // not resurrect behind the user's back, so drop the OS registration
  // along with the listener.
  ref.listen<bool>(userDisconnectedProvider, (previous, isUserDisconnected) {
    if (!isUserDisconnected) return;
    if (!osReconnectArmer.isArmed) return;
    AppLogging.meshcore(
      'event=os_reconnect.cancel.trigger reason=user_disconnect',
    );
    unawaited(osReconnectArmer.cancel(releaseRegistration: true));
  });

  // Mid-session disconnect: when the coordinator transitions into
  // `disconnected` while we have a saved MeshCore peer, attempt recovery.
  // Skips when the disconnect was user-initiated (handled by the cooldown
  // and userDisconnectedProvider check inside maybeReconnect).
  ref.listen<AsyncValue<MeshConnectionState>>(meshCoreConnectionStateProvider, (
    previous,
    next,
  ) {
    final state = next.asData?.value;
    if (state != MeshConnectionState.disconnected) return;
    final prevState = previous?.asData?.value;
    // Only fire on transition INTO disconnected, not when the stream
    // emits its initial seeded value.
    if (prevState == null || prevState == MeshConnectionState.disconnected) {
      return;
    }
    AppLogging.meshcore(
      'event=reconnect.trigger reason=coordinator_disconnect '
      'previous=${prevState.name}',
    );
    maybeReconnect('coordinator_disconnect');
  });
});
