// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the contract that Scanner's `_connecting=true` overlay
/// auto-resets when the transport-state listener path delivers a
/// pairing invalidation.
///
/// Background: the manual-connect path on Scanner sets `_connecting=true`
/// and intentionally leaves it true on success so Navigator transitions
/// can replace the screen. Failures are caught by Scanner's own
/// `_connectToDevice` catch — except apple-code 14, which surfaces
/// asynchronously through the transport state stream while the catch
/// has already been left. Without the safety net, `_connecting` stays
/// true forever and the user sees the spinner indefinitely even after
/// state transitions to `pairedDeviceInvalidated`.
///
/// End-to-end widget testing of this path requires the full provider
/// graph + a real BLE transport simulation, which is out of scope for
/// a surgical patch test. These pins enforce the wire-up.
void main() {
  late String source;
  setUpAll(() async {
    source = await File(
      'lib/features/scanner/scanner_screen.dart',
    ).readAsString();
  });

  group('Scanner pairing-invalidation safety reset', () {
    test('declares a dedicated subscription field for the safety net', () {
      // Reusing an existing subscription would couple unrelated
      // lifecycles. The field is its own slot so dispose() can release
      // it independently.
      expect(
        source.contains('_pairingInvalidationSafetySub'),
        isTrue,
        reason:
            'safety net must be its own subscription so it has a clear '
            'install/release lifecycle — and so the contract is '
            'visible at the field declaration.',
      );
      expect(
        source.contains('ProviderSubscription<conn.DeviceConnectionState2>?'),
        isTrue,
      );
    });

    test(
      'attaches a listenManual on deviceConnectionProvider during initState',
      () {
        // The listener has to be installed before the manual-connect
        // path can start. Using listenManual (not ref.listen) is
        // mandatory in initState. Whitespace-tolerant match to survive
        // dart-format wrapping the chained call.
        final collapsed = source.replaceAll(RegExp(r'\s+'), ' ');
        expect(
          collapsed.contains(
                '_pairingInvalidationSafetySub = ref '
                '.listenManual<conn.DeviceConnectionState2>(',
              ) ||
              collapsed.contains(
                '_pairingInvalidationSafetySub = '
                'ref.listenManual<conn.DeviceConnectionState2>(',
              ),
          isTrue,
          reason:
              'the safety listener must be installed in initState '
              'via listenManual so it lives for the whole Scanner '
              'instance and can be released in dispose.',
        );
      },
    );

    test('only resets when the previous state was NOT already invalidated', () {
      // Without the previous-state guard, the listener would re-fire
      // setState every rebuild while pairedDeviceInvalidated remains
      // the steady state, churning the widget tree unnecessarily.
      // Whitespace-collapsed match so dart-format line wrapping
      // cannot mask the regression.
      final collapsed = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        collapsed.contains(
          'next.isTerminalInvalidated && '
          '(previous == null || !previous.isTerminalInvalidated)',
        ),
        isTrue,
        reason:
            'safety reset must only fire on the rising edge of '
            'isTerminalInvalidated; otherwise it churns setState '
            'on every rebuild while the state is steady.',
      );
    });

    test('only fires while _connecting is true', () {
      // The whole point is to defend against the stranded overlay.
      // If we touch state when the overlay isn\'t up, we risk
      // unexpected setState during normal screens.
      expect(
        source.contains('if (!_connecting) return;'),
        isTrue,
        reason:
            'the safety net must early-return when the connecting '
            'overlay is not up; otherwise it can cause spurious '
            'rebuilds of the device-list screen.',
      );
    });

    test('logs SCANNER_CONNECTING_RESET reason=pairing_invalidated', () {
      // The exact log line is what the user-facing patch description
      // promised; field-debug grep recipes depend on this prefix.
      expect(
        source.contains('SCANNER_CONNECTING_RESET reason=pairing_invalidated'),
        isTrue,
      );
    });

    test('clears _connecting AND _autoReconnecting AND surfaces the '
        'pairing-invalidation hint', () {
      // _connecting alone is not enough — the autoReconnecting flag
      // also drives the overlay copy. And the user needs to see the
      // re-pair guidance card, so _showPairingInvalidationHint must
      // be set in the same setState. Whitespace-collapsed match so
      // dart-format wrapping cannot mask the regression.
      final collapsed = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        collapsed.contains('safeSetState(() { _connecting = false;'),
        isTrue,
        reason:
            'reset must use safeSetState (LifecycleSafeMixin) and '
            'clear _connecting first; safeSetState is the only way '
            'to mutate state from a listener callback without risking '
            'a setState-during-build assertion.',
      );
      expect(source.contains('_autoReconnecting = false;'), isTrue);
      expect(source.contains('_showPairingInvalidationHint = true;'), isTrue);
    });

    test('subscription is closed in dispose', () {
      // Without the close, the listener leaks a Riverpod subscription
      // every time Scanner is unmounted (manual disconnect, factory
      // reset cascade, etc.).
      expect(
        source.contains('_pairingInvalidationSafetySub?.close();'),
        isTrue,
        reason: 'subscription must be released in dispose to avoid leak.',
      );
    });
  });
}
