// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/transport.dart';

// BleDisconnectDetail formatting.
//
// The detail is the structured answer to "who ended the BLE link" -
// emitted as a BLE_DISCONNECT log line, stamped into the connection
// state, and embedded in in-app bug reports. Testers report the ~1h
// disconnect symptom; these strings are what future reports carry, so
// their shape is pinned.
void main() {
  final at = DateTime.utc(2026, 7, 7, 10, 30);

  test('full detail renders every field in the log payload', () {
    final detail = BleDisconnectDetail(
      origin: 'os_state_change',
      at: at,
      platformCode: 6,
      platformDescription: 'connection timeout',
      uptime: const Duration(minutes: 59, seconds: 30),
      lastNotificationAge: const Duration(seconds: 12),
      appCause: 'data_health_force_disconnect',
    );

    expect(
      detail.toLogPayload(),
      'origin=os_state_change code=6 desc="connection timeout" '
      'uptimeS=3570 lastNotifAgoS=12 cause=data_health_force_disconnect',
    );
  });

  test('minimal detail omits absent fields instead of printing null', () {
    final detail = BleDisconnectDetail(origin: 'notify_stream_closed', at: at);

    expect(detail.toLogPayload(), 'origin=notify_stream_closed');
    expect(detail.toCompactString(), 'notify_stream_closed');
    expect(detail.toLogPayload(), isNot(contains('null')));
  });

  test('empty platform description is treated as absent', () {
    final detail = BleDisconnectDetail(
      origin: 'os_state_change',
      at: at,
      platformCode: 7,
      platformDescription: '',
    );

    expect(detail.toLogPayload(), 'origin=os_state_change code=7');
    expect(detail.toCompactString(), 'os_state_change code=7');
  });

  test('compact string carries uptime and notification age in seconds', () {
    final detail = BleDisconnectDetail(
      origin: 'app_requested',
      at: at,
      uptime: const Duration(hours: 1),
      lastNotificationAge: const Duration(minutes: 3),
      appCause: 'rx_stall_hard_reconnect',
    );

    expect(
      detail.toCompactString(),
      'app_requested up=3600s notif=180s cause=rx_stall_hard_reconnect',
    );
  });
}
