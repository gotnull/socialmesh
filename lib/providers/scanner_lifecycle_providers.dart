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
