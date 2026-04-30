// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';

/// Regression coverage for the reconnect-banner Cancel authoritative-stop
/// fix. Pre-fix, `cancelAutoReconnect` set `autoReconnectState=failed`
/// but did NOT set `userDisconnected=true`, so the connectivity-restored
/// listener and other re-arm paths could legitimately re-trigger a
/// reconnect cycle moments after the user cancelled. The user could
/// also visually flicker through the failed "Device not found" banner
/// state for a frame before the Scanner mounted.
///
/// `userCancelAutoReconnect`:
/// 1. Sets `userDisconnected=true` (via the global provider) so re-arm
///    is blocked until an explicit user-initiated connect from Scanner.
/// 2. Drives `autoReconnectState` to `idle` (not `failed`) — Scanner is
///    the next surface the user sees.
/// 3. Cancels the retry timer / scan guards.
/// 4. Best-effort transport disconnect.
/// 5. Sets pairing state to disconnected/userDisconnected.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('userCancelAutoReconnect (banner authoritative cancel)', () {
    test(
      'sets userDisconnectedProvider=true so re-arm paths are blocked',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Pre-cancel: simulate an active reconnect cycle.
        container
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.connecting);
        expect(container.read(userDisconnectedProvider), isFalse);
        expect(
          container.read(autoReconnectStateProvider),
          AutoReconnectState.connecting,
        );

        await container
            .read(deviceConnectionProvider.notifier)
            .userCancelAutoReconnect();

        expect(
          container.read(userDisconnectedProvider),
          isTrue,
          reason:
              'Authoritative cancel must set userDisconnected=true so '
              'the connectivity-restored listener and app-resume '
              'recovery paths cannot legitimately re-arm.',
        );
      },
    );

    test('drives autoReconnectState to idle (not failed) so Scanner is the '
        'next surface — no Device-not-found flicker', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.scanning);

      await container
          .read(deviceConnectionProvider.notifier)
          .userCancelAutoReconnect();

      expect(
        container.read(autoReconnectStateProvider),
        AutoReconnectState.idle,
        reason:
            'Banner shows actionable Retry/Connect on `failed`; the '
            'authoritative cancel routes the user to Scanner instead, '
            'so it must clear to `idle`.',
      );
    });

    test('sets pairing state to disconnected/userDisconnected', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.connecting);

      await container
          .read(deviceConnectionProvider.notifier)
          .userCancelAutoReconnect();

      final s = container.read(deviceConnectionProvider);
      expect(s.state, DevicePairingState.disconnected);
      expect(
        s.reason,
        DisconnectReason.userDisconnected,
        reason:
            'Distinguishable from `deviceNotFound` (watchdog cancel) so '
            'the rest of the system can branch on user-initiated cancel.',
      );
    });

    test(
      'idempotent: second call after first does not flip state back',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.connecting);

        final notifier = container.read(deviceConnectionProvider.notifier);
        await notifier.userCancelAutoReconnect();
        await notifier.userCancelAutoReconnect();

        expect(container.read(userDisconnectedProvider), isTrue);
        expect(
          container.read(autoReconnectStateProvider),
          AutoReconnectState.idle,
        );
        expect(
          container.read(deviceConnectionProvider).reason,
          DisconnectReason.userDisconnected,
        );
      },
    );
  });

  group('showReconnectionBanner stability formula', () {
    // Mirrors `lib/features/navigation/main_shell.dart`'s post-fix
    // computation:
    //
    //   final userDisconnected = ref.watch(userDisconnectedProvider);
    //   final isFullyConnected = isConnected && !isReconnecting;
    //   final showReconnectionBanner =
    //       hasEverPaired && !isFullyConnected && !userDisconnected;
    //
    // Test the formula directly to pin two invariants:
    //
    //   1. Transient transport-state==connected during a TCP retry
    //      cycle (`isConnected==true` && `isReconnecting==true`) MUST
    //      keep the banner visible — otherwise the SizeTransition flips
    //      and the Nodes screen bops vertically.
    //   2. After user cancel / manual disconnect (`userDisconnected ==
    //      true` && `autoReconnectState == idle` && device disconnected),
    //      the banner MUST be hidden — never a stale "Disconnected"
    //      banner with a Connect button on a route the user is
    //      actively leaving.
    bool showBanner({
      required bool isConnected,
      required bool isReconnecting,
      required bool hasEverPaired,
      bool userDisconnected = false,
    }) {
      final isFullyConnected = isConnected && !isReconnecting;
      return hasEverPaired && !isFullyConnected && !userDisconnected;
    }

    test('truly connected (no reconnect cycle) → banner hidden', () {
      expect(
        showBanner(
          isConnected: true,
          isReconnecting: false,
          hasEverPaired: true,
        ),
        isFalse,
      );
    });

    test('transient transport==connected mid-reconnect-cycle → banner STAYS '
        'visible (the fix)', () {
      // This is the TCP-conflict case from logs.txt: TCP socket comes
      // up briefly, then protocol.start times out. Pre-fix the banner
      // would animate out then back in each cycle.
      expect(
        showBanner(
          isConnected: true,
          isReconnecting: true,
          hasEverPaired: true,
        ),
        isTrue,
        reason:
            'Pre-fix, `!isConnected && hasEverPaired` flipped to false '
            'here, dragging the banner out. Post-fix, `isReconnecting` '
            'keeps `isFullyConnected` false and the banner stays.',
      );
    });

    test('disconnected during reconnect cycle → banner visible', () {
      expect(
        showBanner(
          isConnected: false,
          isReconnecting: true,
          hasEverPaired: true,
        ),
        isTrue,
      );
    });

    test(
      'disconnected and reconnect failed/idle → banner visible (failure UX)',
      () {
        expect(
          showBanner(
            isConnected: false,
            isReconnecting: false,
            hasEverPaired: true,
          ),
          isTrue,
        );
      },
    );

    test('never paired → banner hidden regardless of state', () {
      expect(
        showBanner(
          isConnected: false,
          isReconnecting: true,
          hasEverPaired: false,
        ),
        isFalse,
      );
    });

    test('user-disconnected idle (post-cancel / post-manual-disconnect) → '
        'banner hidden', () {
      // The exact case the reviewer flagged: `userDisconnected=true`,
      // `autoReconnectState=idle` (so isReconnecting=false), transport
      // disconnected (so isConnected=false), `hasEverPaired=true`. In
      // production the route-replace unmounts MainShell entirely; this
      // test pins the formula so any future code path that leaves the
      // user on MainShell in this state still hides the banner.
      expect(
        showBanner(
          isConnected: false,
          isReconnecting: false,
          hasEverPaired: true,
          userDisconnected: true,
        ),
        isFalse,
        reason:
            'Manual-disconnect / authoritative-cancel must not '
            'resurrect the banner. Without the userDisconnected gate, '
            'the formula would say show=true and a "Disconnected" '
            'banner with a Connect button would persist on whatever '
            'route still has MainShell mounted.',
      );
    });

    test(
      'user-disconnected during a transient mid-cycle state → still hidden',
      () {
        // Defense-in-depth: even if for any reason `isReconnecting` or
        // `isConnected` are momentarily true while userDisconnected is
        // also set, the user's intent wins.
        for (final flags in [
          (isConnected: true, isReconnecting: false),
          (isConnected: false, isReconnecting: true),
          (isConnected: true, isReconnecting: true),
        ]) {
          expect(
            showBanner(
              isConnected: flags.isConnected,
              isReconnecting: flags.isReconnecting,
              hasEverPaired: true,
              userDisconnected: true,
            ),
            isFalse,
            reason:
                'userDisconnected=true must dominate every other '
                'state combination. Failing combo: $flags',
          );
        }
      },
    );

    test('clearUserDisconnected (user retaps Connect) → banner returns to '
        'state-driven visibility', () {
      // After the user navigates to Scanner and re-initiates connect,
      // `clearUserDisconnected` flips the flag. The banner formula
      // must once again reflect connection state without the gate.
      expect(
        showBanner(
          isConnected: false,
          isReconnecting: true,
          hasEverPaired: true,
          // userDisconnected: false (default)
        ),
        isTrue,
        reason:
            'Once userDisconnected is cleared, the banner returns '
            'to the standard state-driven visibility.',
      );
    });

    test('TCP-conflict cycle: oscillating isConnected with stable '
        'isReconnecting=true keeps banner visible across all flips', () {
      // Replays the cycle observed in logs.txt lines 88–161:
      // disconnected → connecting → connected → disconnected → ...
      // with autoReconnectState (and therefore isReconnecting) stable.
      const cycle = [false, true, false, true, false, true, false, true];
      final results = cycle
          .map(
            (connected) => showBanner(
              isConnected: connected,
              isReconnecting: true,
              hasEverPaired: true,
            ),
          )
          .toList();

      expect(
        results.every((shown) => shown),
        isTrue,
        reason:
            'Every state during the TCP retry cycle must yield '
            'banner=visible. Any false flip drives the SizeTransition '
            'and bops the Nodes screen vertically.',
      );
    });
  });
}
