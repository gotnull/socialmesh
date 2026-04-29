// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/services/transport/ble_transport.dart';

/// BLE-transport diagnostic-surface contract tests. The deep refresh-
/// concurrency and failure-mode semantics are exercised at the protocol
/// layer via a fake transport (see protocol_receive_stall_test.dart),
/// because BleTransport tightly couples to flutter_blue_plus and cannot
/// be exercised end-to-end without a real Bluetooth stack.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BleTransport diagnostic surface', () {
    test('counters default to zero on a fresh transport', () {
      final transport = BleTransport();
      addTearDown(transport.dispose);

      expect(transport.fromNumNotificationCount, 0);
      expect(transport.rxBytesReadCount, 0);
      expect(transport.rxReadFailureCount, 0);
      expect(transport.refreshNotificationsCount, 0);
      expect(transport.refreshNotificationsFailureCount, 0);
      expect(transport.lastNotificationAt, isNull);
    });

    test(
      'refreshNotifications is a safe no-op when transport is not connected',
      () async {
        final transport = BleTransport();
        addTearDown(transport.dispose);

        expect(transport.state, DeviceConnectionState.disconnected);

        await transport.refreshNotifications();
        await transport.refreshNotifications();

        // Early returns must not bump the accepted-call counter when
        // there is no characteristic / not connected — otherwise idle
        // periodic checks would produce false telemetry.
        expect(transport.refreshNotificationsCount, 0);
        expect(transport.refreshNotificationsFailureCount, 0);
      },
    );

    test(
      'dispose is idempotent and leaves diagnostic counters readable',
      () async {
        final transport = BleTransport();

        await transport.dispose();
        await transport.dispose();

        // Counters remain readable after dispose — the diagnostics
        // provider may snapshot a torn-down transport during teardown.
        expect(transport.fromNumNotificationCount, 0);
        expect(transport.refreshNotificationsCount, 0);
        expect(transport.refreshNotificationsFailureCount, 0);
      },
    );

    test('exposes the ReceiveDiagnosticsSupport capability', () {
      final transport = BleTransport();
      addTearDown(transport.dispose);

      // Diagnostics are an optional capability. ProtocolService casts
      // the transport to `ReceiveDiagnosticsSupport` and falls back to
      // safe defaults when the cast fails (USB / TCP / test fakes).
      // BleTransport must implement the capability so the snapshot
      // surfaces real counters, not zeros.
      expect(transport, isA<ReceiveDiagnosticsSupport>());
      final diag = transport as ReceiveDiagnosticsSupport;
      expect(diag.fromNumNotificationCount, 0);
      expect(diag.rxBytesReadCount, 0);
      expect(diag.rxReadFailureCount, 0);
      expect(diag.refreshNotificationsCount, 0);
      expect(diag.refreshNotificationsFailureCount, 0);
      expect(diag.lastNotificationAt, isNull);
    });
  });
}
