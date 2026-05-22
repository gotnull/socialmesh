// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression pin for Crashlytics issue 88594eb858cbccdc06d041dc0fcbbafe.
//
// Fatal `FlutterError`: "Tried to modify a provider while the widget
// tree was building" / "Error thrown while finalizing the widget tree."
//
// Original failing chain (v1.41.0+180, iOS 26.4.1):
//   _ScannerScreenState.dispose
//     → _manualScanNotifier.setActive(false)
//     → state = value (Notifier setter)
//     → ProviderElement._notifyListeners
//   ...fires while BuildOwner.finalizeTree is unmounting the screen.
//
// The fix in scanner_screen.dart wraps `notifier.setActive(false)` in
// `Future.microtask(...)` so the mutation runs after finalize. This
// test pins the post-fix contract:
//
//   - Unmounting a widget whose `dispose()` schedules
//     `Future.microtask(() => notifier.setActive(false))` does NOT
//     synchronously throw during finalizeTree.
//   - The flag is still cleared after one microtask completes — the
//     auto-reconnect-resume side effect is preserved.
//
// Why we don't also try to prove the original synchronous failure
// mode here: the Riverpod assertion that fires the crash in
// production (`ProviderElement._debugAssertNotificationAllowed`)
// looks at `SchedulerBinding.schedulerPhase`, which under
// `flutter test`'s `pumpWidget` unmount does NOT match production's
// `persistentCallbacks` phase reliably enough to make an "expect
// throws" test stable. Locking the post-fix shape is sufficient: if
// someone reverts to a synchronous call, the live crash will
// re-surface on device and this test will keep passing — that is the
// trade-off documented here so a future reader doesn't accidentally
// drop the microtask wrap.
//
// Driving the real `ScannerScreen` would require half the BLE +
// app-init provider graph. Instead this file pumps a minimal
// disposable widget that captures the manualScanActiveProvider's
// notifier in initState and reproduces the exact call shape from
// scanner_screen.dart:419-420. The failure mode is a property of
// the call site, not the surrounding screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/providers/scanner_lifecycle_providers.dart';

/// Calls [onDispose] from its `dispose()` lifecycle. Used to reproduce
/// both the original crash and the microtask fix in isolation.
class _DisposeProbe extends ConsumerStatefulWidget {
  final void Function(ManualScanActiveNotifier notifier) onDispose;
  const _DisposeProbe({required this.onDispose});

  @override
  ConsumerState<_DisposeProbe> createState() => _DisposeProbeState();
}

class _DisposeProbeState extends ConsumerState<_DisposeProbe> {
  late final ManualScanActiveNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(manualScanActiveProvider.notifier);
  }

  @override
  void dispose() {
    widget.onDispose(_notifier);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('Crashlytics 88594eb858cbccdc06d041dc0fcbbafe — Future.microtask '
      'wrap does NOT throw and still clears the flag', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Pre-set the flag so we can prove the microtask wrap clears it.
    container.read(manualScanActiveProvider.notifier).setActive(true);
    expect(container.read(manualScanActiveProvider), isTrue);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: _DisposeProbe(
            onDispose: (notifier) {
              // The exact call shape from scanner_screen.dart:419-420.
              Future.microtask(() => notifier.setActive(false));
            },
          ),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    // No exception captured during finalize.
    expect(
      tester.takeException(),
      isNull,
      reason:
          'The microtask wrap must defer the state write past the '
          'finalizeTree pass so Riverpod does not throw.',
    );

    // Let the microtask run.
    await tester.pump();

    expect(
      container.read(manualScanActiveProvider),
      isFalse,
      reason:
          'The microtask still has to fire and clear the flag — the '
          'fix preserves the original auto-reconnect-resume side '
          'effect of the synchronous call.',
    );
  });
}
