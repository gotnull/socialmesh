// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/scanner_lifecycle_providers.dart';

/// Regression coverage for the `autoReconnectState=manualConnecting`
/// latch-survival bug. Pre-fix, a failed manual scanner connection
/// left the latch set indefinitely, blocking
/// `_initializeProtocolAfterAutoReconnect`,
/// `startBackgroundConnection`, and `APP RESUMED` recovery paths.
///
/// The fix introduces a monotonic `manualConnectSessionProvider`
/// session token. Each `_connect` tap acquires a new id; the terminal
/// outcome (success / failure / disconnect / dispose / timeout)
/// clears the latch only if the session matches. A stale older
/// session can no longer unlatch a newer in-flight attempt.
///
/// These tests exercise the session-token state machine directly.
/// The full Scanner widget integration is covered by manual / log
/// validation since a widget test would require ProviderScope +
/// Navigator + transport-fake scaffolding outside the surgical-diff
/// constraint.

/// Mirrors the production `_clearManualConnectIfCurrent` semantics
/// without pulling the Scanner widget into the test harness.
void clearIfCurrent(ProviderContainer container, int session) {
  final current = container.read(manualConnectSessionProvider);
  if (session != current) return; // stale clear, ignored
  final autoState = container.read(autoReconnectStateProvider);
  if (autoState == AutoReconnectState.manualConnecting) {
    container
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.idle);
  }
}

void main() {
  group('manualConnectSessionProvider', () {
    test('beginSession returns monotonic increasing tokens', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(manualConnectSessionProvider.notifier);
      final s1 = notifier.beginSession();
      final s2 = notifier.beginSession();
      final s3 = notifier.beginSession();

      expect(s1, 1);
      expect(s2, 2);
      expect(s3, 3);
      expect(container.read(manualConnectSessionProvider), 3);
    });
  });

  group('manual connect lifecycle (latch + session token)', () {
    test('T1: failed connect (throws before transport ready) → '
        'autoReconnectState clears to idle via session-aware helper', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Begin session, set latch (mirrors `_connect` entry).
      final session = container
          .read(manualConnectSessionProvider.notifier)
          .beginSession();
      container
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.manualConnecting);
      expect(
        container.read(autoReconnectStateProvider),
        AutoReconnectState.manualConnecting,
      );

      // Simulated `_connectToDevice` throws → catch path runs
      // `_clearManualConnectIfCurrent`.
      clearIfCurrent(container, session);

      expect(
        container.read(autoReconnectStateProvider),
        AutoReconnectState.idle,
        reason:
            'Failed manual connect must release the latch — leaving '
            'it set blocks _initializeProtocolAfterAutoReconnect, '
            'startBackgroundConnection, and APP RESUMED recovery.',
      );
    });

    test('T2: connected then errors mid-config → latch clears via failure '
        'path (same code path as T1, distinct timing)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final session = container
          .read(manualConnectSessionProvider.notifier)
          .beginSession();
      container
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.manualConnecting);

      // Connected → error during protocol.start(). Same terminal
      // outcome from the latch's perspective: helper fires.
      clearIfCurrent(container, session);

      expect(
        container.read(autoReconnectStateProvider),
        AutoReconnectState.idle,
      );
    });

    test('T3: connected then disconnects before ready → latch clears', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final session = container
          .read(manualConnectSessionProvider.notifier)
          .beginSession();
      container
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.manualConnecting);

      // Transport reached connected then dropped before protocol
      // ready → throws "Transport disconnected during configuration"
      // which the catch path handles same as T1/T2.
      clearIfCurrent(container, session);

      expect(
        container.read(autoReconnectStateProvider),
        AutoReconnectState.idle,
      );
    });

    test('T4: stale session cannot clear a newer manualConnecting session — '
        '_handleDisconnect-style stale clear is rejected', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Session 1 starts. Latch on.
      final s1 = container
          .read(manualConnectSessionProvider.notifier)
          .beginSession();
      container
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.manualConnecting);
      expect(s1, 1);

      // User taps another device — session 2 starts. Latch is
      // re-asserted (still manualConnecting) but with a NEW token.
      final s2 = container
          .read(manualConnectSessionProvider.notifier)
          .beginSession();
      // (Production sets it again here; we leave it — it's
      // idempotent for the test's purpose.)
      expect(s2, 2);

      // Now session 1's stale catch path fires (an orphaned future
      // resolved late). It must NOT clear the latch — session 2
      // still owns it.
      clearIfCurrent(container, s1);

      expect(
        container.read(autoReconnectStateProvider),
        AutoReconnectState.manualConnecting,
        reason:
            'Stale session (s1) must not unlatch a newer in-flight '
            'session (s2). The mismatch is logged as '
            'MANUAL_CONNECT_CLEAR_SKIPPED_STALE_SESSION.',
      );

      // Session 2's own terminal outcome clears it.
      clearIfCurrent(container, s2);
      expect(
        container.read(autoReconnectStateProvider),
        AutoReconnectState.idle,
      );
    });

    test('T5: successful connect → latch clears (success path uses the '
        'same session-aware helper)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final session = container
          .read(manualConnectSessionProvider.notifier)
          .beginSession();
      container
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.manualConnecting);

      // Production's success branch (post-MainShell promotion) calls
      // the same helper with reason='success'.
      clearIfCurrent(container, session);

      expect(
        container.read(autoReconnectStateProvider),
        AutoReconnectState.idle,
        reason:
            'Success must release the latch so the auto-reconnect '
            'manager and APP RESUMED recovery are no longer blocked.',
      );
    });
  });

  group('Scanner.dispose latch clear', () {
    test('dispose with matching active session clears the latch (orphaned-'
        'future safety net)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final session = container
          .read(manualConnectSessionProvider.notifier)
          .beginSession();
      container
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.manualConnecting);

      // Scanner widget disposes mid-connect (e.g., user backgrounds
      // the app, route swap). Production calls
      // `_clearManualConnectIfCurrent(_activeManualSession,
      // reason: 'dispose')` from dispose.
      clearIfCurrent(container, session);

      expect(
        container.read(autoReconnectStateProvider),
        AutoReconnectState.idle,
      );
    });

    test('dispose with stale session does not clear a newer attempt', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final s1 = container
          .read(manualConnectSessionProvider.notifier)
          .beginSession();
      container
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.manualConnecting);
      // Newer session immediately supersedes.
      container.read(manualConnectSessionProvider.notifier).beginSession();

      clearIfCurrent(container, s1);

      expect(
        container.read(autoReconnectStateProvider),
        AutoReconnectState.manualConnecting,
      );
    });
  });
}
