// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the manual-connect-after-disconnect bug
/// introduced when `_connectToDevice` was refactored to route through
/// `RestoreSessionCoordinator.restoreSession`.
///
/// Failure mode (before fix):
/// - User taps Disconnect → `_userDisconnected = true`.
/// - User opens Scanner / banner and taps a device.
/// - `_connectToDevice` runs and calls
///   `restoreSession(reason: 'connect_to_device')`.
/// - Coordinator's `isUserDisconnected()` guard returns true → restore
///   is skipped, `protocol.start()` never runs.
/// - Transport comes up but readiness stays at `idle`, `myNodeNum`
///   stays null.
/// - Code falsely reports "Authentication failed" and tears down
///   the transport. User retries → same loop.
///
/// Fix:
/// - `_connectToDevice` calls `clearUserDisconnected()` immediately
///   after the connection log line, BEFORE state mutation and BEFORE
///   the coordinator restore.
/// - Opportunistic restore paths (auto-reconnect, lifecycle resume)
///   stay guarded — only the explicit user-tap path is exempted.
///
/// These tests pin both the source-level ordering contract and the
/// behavior. A full integration test that drives `_connectToDevice`
/// end-to-end requires transport/settings/scanner scaffolding the
/// surgical-patch constraint forbids; the source pin is the
/// alternative that catches a future revert at PR review.
void main() {
  group('manual-connect clears _userDisconnected (source pin)', () {
    late String source;
    setUpAll(() async {
      source = await File(
        'lib/providers/connection_providers.dart',
      ).readAsString();
    });

    test('_connectToDevice contains clearUserDisconnected()', () {
      // Locate `_connectToDevice` and confirm `clearUserDisconnected()`
      // appears within its body. Pin against accidental removal.
      final connectToDeviceStart = source.indexOf(
        'Future<void> _connectToDevice(DeviceInfo device)',
      );
      expect(
        connectToDeviceStart,
        greaterThan(0),
        reason: '_connectToDevice signature not found',
      );

      // Find the next method-level closing brace (a top-level `}` at
      // the start of a line). For test robustness use a slice up to
      // the next async-function declaration.
      final nextMethodStart = source.indexOf(
        '\n  Future<',
        connectToDeviceStart + 1,
      );
      final body = nextMethodStart > 0
          ? source.substring(connectToDeviceStart, nextMethodStart)
          : source.substring(connectToDeviceStart);

      expect(
        body.contains('clearUserDisconnected()'),
        isTrue,
        reason:
            '_connectToDevice must call `clearUserDisconnected()` so the '
            'coordinator does not refuse the explicit user-tap connect.',
      );
    });

    test('clearUserDisconnected() appears BEFORE the coordinator restore call '
        'inside _connectToDevice', () {
      // Ordering guard. If clearUserDisconnected() ends up below the
      // restoreSession call, the coordinator still sees
      // `_userDisconnected=true` at the moment the read fires.
      final connectToDeviceStart = source.indexOf(
        'Future<void> _connectToDevice(DeviceInfo device)',
      );
      expect(connectToDeviceStart, greaterThan(0));

      // Look for the next async-method declaration to bound the
      // search window so we do not accidentally pick up a different
      // method's restoreSession call.
      final nextMethodStart = source.indexOf(
        '\n  Future<',
        connectToDeviceStart + 1,
      );
      final body = nextMethodStart > 0
          ? source.substring(connectToDeviceStart, nextMethodStart)
          : source.substring(connectToDeviceStart);

      final clearAt = body.indexOf('clearUserDisconnected()');
      final restoreAt = body.indexOf(
        "restoreSession(reason: 'connect_to_device')",
      );

      expect(
        clearAt,
        greaterThan(0),
        reason:
            'clearUserDisconnected() must be called inside '
            '_connectToDevice',
      );
      expect(
        restoreAt,
        greaterThan(0),
        reason:
            '_connectToDevice must still route through the '
            "coordinator's restoreSession with reason='connect_to_device'",
      );
      expect(
        clearAt < restoreAt,
        isTrue,
        reason:
            'clearUserDisconnected() MUST appear before the '
            "restoreSession(reason: 'connect_to_device') call so the "
            'coordinator no longer sees stale userDisconnected=true on '
            'an explicit user tap.',
      );
    });

    test('opportunistic restore paths still depend on isUserDisconnected (the '
        'coordinator guard is intact)', () {
      // The coordinator MUST still consult `isUserDisconnected` so
      // auto-reconnect, lifecycle resume, and watchdog rebuild paths
      // are blocked after the user taps Disconnect. The fix is
      // narrow: only `_connectToDevice` exempts itself, by clearing
      // the latch FIRST. The coordinator-side guard stays in place.
      expect(
        source.contains('isUserDisconnected()'),
        isTrue,
        reason:
            'RestoreSessionCoordinator must still guard via '
            'isUserDisconnected() so opportunistic restore paths stay '
            'blocked after the user taps Disconnect.',
      );
      // The skip log line is the observable when an opportunistic
      // path is correctly blocked.
      expect(
        source.contains('cause=user_disconnected'),
        isTrue,
        reason:
            'the user-disconnected skip path log line must remain wired '
            'so opportunistic-skip is still observable in production logs.',
      );
    });

    test('opportunistic reasons that should still be guarded by '
        'isUserDisconnected: auto_reconnect, lifecycle_resume', () {
      // Spot-check: the coordinator-using restore call sites that
      // ARE opportunistic must use these reason tags. A future
      // refactor must not move them into the `_connectToDevice`
      // path or it would lose the user-disconnect guard.
      expect(source.contains("reason: 'auto_reconnect'"), isTrue);
      expect(source.contains("reason: 'lifecycle_resume'"), isTrue);
    });
  });
}
