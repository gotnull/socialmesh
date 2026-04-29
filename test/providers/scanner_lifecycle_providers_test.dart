// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/providers/scanner_lifecycle_providers.dart';

/// Regression coverage for the manual-scan lifecycle providers.
///
/// `logs.txt` evidence (hashCodes 701430859 + 445134485 racing through
/// BLE cleanup, both disposed during the 2000ms wait, no
/// `transport.scan()` ever opening) drove the addition of:
/// - [scannerMountCountProvider] for nav-guard + lone-survivor activation
/// - [manualScanActiveProvider] for auto-reconnect suppression
///
/// These tests pin the invariants at the provider layer; the widget
/// integration is verified end-to-end via the next deploy.

void main() {
  group('scannerMountCountProvider', () {
    test('starts at 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(scannerMountCountProvider), 0);
    });

    test('register increments, unregister decrements', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(scannerMountCountProvider.notifier);

      notifier.register();
      expect(container.read(scannerMountCountProvider), 1);

      notifier.register();
      expect(container.read(scannerMountCountProvider), 2);

      notifier.unregister();
      expect(container.read(scannerMountCountProvider), 1);

      notifier.unregister();
      expect(container.read(scannerMountCountProvider), 0);
    });

    test('unregister never goes below zero (defensive)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(scannerMountCountProvider.notifier);

      notifier.unregister();
      notifier.unregister();
      expect(container.read(scannerMountCountProvider), 0);
    });

    test(
      'count drop to 1 is observable to a listener — unblocks the lone-'
      'survivor activation pattern that promotes the surviving scanner',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(scannerMountCountProvider.notifier);

        // Two scanners mount.
        notifier.register();
        notifier.register();
        expect(container.read(scannerMountCountProvider), 2);

        final transitions = <int>[];
        final sub = container.listen<int>(
          scannerMountCountProvider,
          (_, next) => transitions.add(next),
        );
        addTearDown(sub.close);

        // Doomed scanner disposes.
        notifier.unregister();
        expect(transitions, [1]);
      },
    );
  });

  group('manualScanActiveProvider', () {
    test('starts false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(manualScanActiveProvider), isFalse);
    });

    test('setActive(true)/setActive(false) toggles state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(manualScanActiveProvider.notifier);

      notifier.setActive(true);
      expect(container.read(manualScanActiveProvider), isTrue);

      notifier.setActive(false);
      expect(container.read(manualScanActiveProvider), isFalse);
    });

    test(
      'listeners observe the toggle (used by startBackgroundConnection)',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(manualScanActiveProvider.notifier);

        final transitions = <bool>[];
        final sub = container.listen<bool>(
          manualScanActiveProvider,
          (_, next) => transitions.add(next),
        );
        addTearDown(sub.close);

        notifier.setActive(true);
        notifier.setActive(false);
        expect(transitions, [true, false]);
      },
    );
  });

  group('lone-survivor invariant (lifecycle counter regression)', () {
    test('when two scanners mount and the doomed one disposes first, '
        'a listener fires with count=1 — this is what promotes the '
        'surviving Scanner to active in the production widget', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(scannerMountCountProvider.notifier);

      // Step 1: scanner #1 mounts (state-driven _AppRouter rebuild).
      notifier.register();
      expect(container.read(scannerMountCountProvider), 1);

      // Step 2: scanner #2 mounts (pushNamedAndRemoveUntil → fresh
      // _AppRouter mount). Both are now alive.
      notifier.register();
      expect(container.read(scannerMountCountProvider), 2);

      var loneSurvivorEvents = 0;
      final sub = container.listen<int>(scannerMountCountProvider, (_, next) {
        if (next == 1) loneSurvivorEvents++;
      });
      addTearDown(sub.close);

      // Step 3: the doomed scanner (in the old route) disposes.
      notifier.unregister();
      expect(container.read(scannerMountCountProvider), 1);
      expect(
        loneSurvivorEvents,
        1,
        reason:
            'The surviving Scanner observes count==1 and promotes '
            'itself via _maybeStartScanWork. Without this transition, '
            'both scanners would stay passive forever (the bug from '
            'logs.txt).',
      );
    });

    test('auto-reconnect suppression is independently toggleable from the '
        'mount counter — Scanner #1 disposing must not flip suppression '
        'off if Scanner #2 is still driving the scan', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final mountNotifier = container.read(scannerMountCountProvider.notifier);
      final manualNotifier = container.read(manualScanActiveProvider.notifier);

      mountNotifier.register();
      mountNotifier.register();
      manualNotifier.setActive(true);
      expect(container.read(manualScanActiveProvider), isTrue);

      // Doomed scanner disposes.
      mountNotifier.unregister();
      // Suppression is intentionally NOT auto-cleared by the count
      // change — only the active scanner's dispose should clear it.
      expect(container.read(manualScanActiveProvider), isTrue);

      // Active scanner explicitly clears on dispose.
      manualNotifier.setActive(false);
      expect(container.read(manualScanActiveProvider), isFalse);
    });
  });
}
