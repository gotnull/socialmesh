// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Transport capability matrix — pins the answers to the three questions
// the protocol layer has to ask about a transport: does it need framing,
// does it need a serial-UART wake preamble before wantConfigId, and is
// reconnect scan-based or endpoint-based. See issue #102 for why
// collapsing wake-vs-framing was wrong.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/services/transport/ble_transport.dart';
import 'package:socialmesh/services/transport/network_transport.dart';
import 'package:socialmesh/services/transport/usb_transport.dart';

void main() {
  group('Transport capability matrix', () {
    test('BLE: no framing, no wake sequence, scan-based reconnect', () {
      final t = BleTransport();
      expect(t.type, TransportType.ble);
      expect(t.requiresFraming, isFalse);
      expect(t.requiresWakeSequence, isFalse);
      expect(t.reconnectMode, TransportReconnectMode.scanBased);
    });

    test('USB: framing, wake sequence, scan-based reconnect', () {
      final t = UsbTransport();
      expect(t.type, TransportType.usb);
      expect(t.requiresFraming, isTrue);
      expect(t.requiresWakeSequence, isTrue);
      expect(t.reconnectMode, TransportReconnectMode.scanBased);
    });

    test('Network: framing, NO wake sequence, direct-endpoint reconnect', () {
      final t = NetworkTransport(host: '127.0.0.1', port: 4403);
      expect(t.type, TransportType.network);
      expect(t.requiresFraming, isTrue);
      expect(
        t.requiresWakeSequence,
        isFalse,
        reason:
            'TCP must NOT receive the 32x0xC3 wake preamble — that is a '
            'serial-UART quirk. The firmware PhoneAPI parses those bytes '
            'as a malformed framed packet.',
      );
      expect(t.reconnectMode, TransportReconnectMode.directEndpoint);
    });
  });
}
