// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active manual scanner widget count.
///
/// Two scenarios produce a duplicate `ScannerScreen` mount and we want to
/// detect both:
///
///   1. **State-driven race after disconnect.** `device_sheet.dart` calls
///      `setNeedsScanner()` (which makes the existing `_AppRouter` rebuild
///      and return a `ScannerScreen`) AND `pushNamedAndRemoveUntil('/app',
///      …)` (which mounts a fresh `_AppRouter` that ALSO returns a
///      `ScannerScreen`). The two widgets race their BLE-cleanup phases.
///   2. **Double-tap / duplicate-push from any nav-button caller.** The
///      `Navigator.pushNamed('/scanner')` call sites should each consult
///      this counter before pushing.
///
/// `ScannerScreen.initState` calls [ScannerMountCountNotifier.register];
/// `dispose` calls [unregister]. Pushers and the declarative `_AppRouter`
/// both check the count and either suppress the new mount or render a
/// placeholder so only one widget runs the BLE machinery.
class ScannerMountCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void register() {
    state = state + 1;
  }

  void unregister() {
    if (state > 0) state = state - 1;
  }
}

final scannerMountCountProvider =
    NotifierProvider<ScannerMountCountNotifier, int>(
      ScannerMountCountNotifier.new,
    );

/// Whether a manual BLE scan is currently active (or imminently
/// starting) and auto-reconnect should be suppressed.
///
/// The Scanner sets this to `true` when it begins a scan and clears it on
/// dispose / scan completion / cancellation. Auto-reconnect logic checks
/// this flag and skips its background reconnect attempts so they don't
/// race the manual scan for the BLE adapter.
class ManualScanActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setActive(bool value) {
    state = value;
  }
}

final manualScanActiveProvider =
    NotifierProvider<ManualScanActiveNotifier, bool>(
      ManualScanActiveNotifier.new,
    );

/// Monotonic session token issued every time the Scanner starts a
/// manual connect attempt. Used to gate the
/// `autoReconnectState=manualConnecting` latch so a stale failed
/// attempt cannot clear (or be cleared by) a newer attempt.
///
/// Lifecycle (in `ScannerScreen._connect` → `_connectToDevice`):
///
/// 1. `beginSession()` increments the counter and returns the new id.
///    Caller stores it as `_activeManualSession` and sets
///    `autoReconnectStateProvider == manualConnecting`.
/// 2. On any terminal outcome — success / failure / disconnect /
///    timeout / scanner dispose — the caller invokes
///    `clearIfCurrent(myToken)` which only clears the latch when
///    `myToken == current`. If a newer `_connect` tap incremented
///    the counter mid-attempt, the stale clear is logged as
///    `MANUAL_CONNECT_CLEAR_SKIPPED_STALE_SESSION` and ignored.
///
/// This protects against the original B6 latch-survival bug: failed
/// manual connect would leave `manualConnecting` set indefinitely,
/// blocking `_initializeProtocolAfterAutoReconnect`,
/// `startBackgroundConnection`, and `APP RESUMED` recovery paths.
class ManualConnectSessionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Acquire a new monotonic session token. Returns the new id.
  int beginSession() {
    state = state + 1;
    return state;
  }
}

final manualConnectSessionProvider =
    NotifierProvider<ManualConnectSessionNotifier, int>(
      ManualConnectSessionNotifier.new,
    );
