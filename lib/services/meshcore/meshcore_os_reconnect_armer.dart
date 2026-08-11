// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// OS-level pending-reconnect armer for MeshCore BLE peers (iOS).
//
// iOS freezes Dart timers while the app is suspended, so the scan-based
// foreground reconnect pipeline cannot recover a MeshCore BLE link that
// drops in the background. Core Bluetooth, however, honours a pending
// connect indefinitely at the OS level: register one with
// `autoConnect: true` and iOS re-establishes the link whenever the radio
// advertises again, waking the app (`bluetooth-central` background mode)
// long enough to rebuild the session and deliver notifications.
//
// This class owns exactly that registration for the MeshCore side. It is
// Riverpod-free and transport-free: the caller (the MeshCore lifecycle
// provider) decides WHEN to arm via [shouldArmMeshCoreOsReconnect] and
// what to do when the link returns via the [onLinkReestablished]
// callback, which dispatches the canonical coordinator reconnect path so
// the session is rebuilt exactly like any other reconnect.
//
// The registration is cleared by any `disconnect()` on the same
// peripheral (flutter_blue_plus keys devices by remote id), so the
// normal transport teardown path releases it without knowing this class
// exists. [cancel] with `releaseRegistration: true` clears it eagerly
// for user-initiated disconnects.

import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, visibleForTesting;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/logging.dart';
import 'diagnostics/meshcore_ble_debug_log_store.dart';

/// Pure gate deciding whether a background MeshCore disconnect should arm
/// an OS-level pending reconnect instead of the immediate direct-connect
/// dispatch. Extracted so the rule matrix is unit-testable without the
/// Bluetooth stack.
///
/// - iOS only: Android keeps the Dart isolate alive, so the immediate
///   dispatch path works there.
/// - Background only: in the foreground the existing direct-connect and
///   scan strategies own recovery, with UI feedback.
/// - BLE only: TCP peers have no OS-level pending connect; they recover
///   on the next foreground transition.
/// - Skipped while the coordinator is connected or connecting, or when a
///   registration is already armed.
bool shouldArmMeshCoreOsReconnect({
  required TargetPlatform platform,
  required bool isForeground,
  required bool isTcpDevice,
  required bool coordinatorConnected,
  required bool coordinatorConnecting,
  required bool alreadyArmed,
  required bool backgroundBleEnabled,
}) {
  if (platform != TargetPlatform.iOS) return false;
  if (isForeground) return false;
  if (isTcpDevice) return false;
  if (coordinatorConnected || coordinatorConnecting) return false;
  if (alreadyArmed) return false;
  return backgroundBleEnabled;
}

/// Owns at most one OS-level pending-reconnect registration for a
/// MeshCore BLE peer, and invokes a callback when iOS re-establishes the
/// link.
class MeshCoreOsReconnectArmer {
  BluetoothDevice? _device;
  StreamSubscription<BluetoothConnectionState>? _stateSubscription;
  String? _armedDeviceId;

  /// Factory seam so tests can substitute a fake device without touching
  /// the platform channel.
  @visibleForTesting
  BluetoothDevice Function(String deviceId) deviceFactory = (deviceId) =>
      BluetoothDevice.fromId(deviceId);

  /// Whether a registration is currently armed.
  bool get isArmed => _armedDeviceId != null;

  /// Remote id of the armed peer, null when idle.
  String? get armedDeviceId => _armedDeviceId;

  /// Register an OS-level pending connect for [deviceId] and invoke
  /// [onLinkReestablished] once iOS brings the link back up.
  ///
  /// Idempotent: a second call while armed is a no-op. The callback fires
  /// at most once per arm; the armer disarms itself (keeping the OS
  /// registration, which the subsequent session bring-up now owns) before
  /// invoking it.
  Future<void> arm({
    required String deviceId,
    required Future<void> Function(String deviceId) onLinkReestablished,
  }) async {
    if (_armedDeviceId != null) {
      AppLogging.meshcore(
        'event=os_reconnect.arm.skipped reason=already_armed',
      );
      return;
    }
    _armedDeviceId = deviceId;

    final device = deviceFactory(deviceId);
    _device = device;

    _stateSubscription = device.connectionState.listen((state) {
      if (state != BluetoothConnectionState.connected) return;
      AppLogging.meshcore('event=os_reconnect.link_reestablished');
      MeshCoreBleDebugLogStore.instance.append(
        severity: MeshCoreBleDebugLogSeverity.info,
        category: MeshCoreBleDebugLogCategory.connect,
        message:
            'OS pending reconnect completed, dispatching session rebuild', // lint-allow: hardcoded-string
      );
      final armedId = _armedDeviceId;
      // Disarm before dispatching so the coordinator's bring-up sees a
      // quiet armer. The OS registration itself stays: the transport's
      // eventual disconnect() clears it.
      _disarm();
      if (armedId != null) {
        unawaited(onLinkReestablished(armedId));
      }
    });

    try {
      // Returns as soon as the request is registered; the connection
      // itself completes whenever the radio reappears, even days later.
      await device.connect(license: License.free, autoConnect: true, mtu: null);
      AppLogging.meshcore('event=os_reconnect.armed');
      MeshCoreBleDebugLogStore.instance.append(
        severity: MeshCoreBleDebugLogSeverity.info,
        category: MeshCoreBleDebugLogCategory.connect,
        message:
            'OS pending reconnect armed for background recovery', // lint-allow: hardcoded-string
      );
    } catch (e) {
      AppLogging.meshcore(
        'event=os_reconnect.arm.failed reason=${e.runtimeType}',
        error: true,
      );
      _disarm();
    }
  }

  /// Cancel the armed registration.
  ///
  /// With [releaseRegistration] the OS-level pending connect is dropped
  /// too (user-initiated disconnect: the peer must not resurrect behind
  /// the user's back). Without it only the listener is torn down and the
  /// registration stays as a safety net until the next transport
  /// disconnect clears it (foreground path taking over ownership).
  Future<void> cancel({required bool releaseRegistration}) async {
    if (_armedDeviceId == null) return;
    final device = _device;
    _disarm();
    AppLogging.meshcore(
      'event=os_reconnect.cancelled release=$releaseRegistration',
    );
    if (releaseRegistration && device != null) {
      try {
        await device.disconnect();
      } catch (e) {
        AppLogging.meshcore(
          'event=os_reconnect.release.failed reason=${e.runtimeType}',
          error: true,
        );
      }
    }
  }

  void _disarm() {
    _stateSubscription?.cancel();
    _stateSubscription = null;
    _device = null;
    _armedDeviceId = null;
  }

  /// Tear down listeners. Keeps any OS registration (app teardown must
  /// not drop a link the user expects to survive in the background).
  void dispose() {
    _disarm();
  }
}
