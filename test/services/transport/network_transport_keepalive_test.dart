// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/services/transport/network_transport.dart';

// Tuned TCP keepalive on the Meshtastic network transport. A powered-off
// radio cannot ACK the kernel's keepalive probes, so the OS resets the
// connection ~50s after the last exchange instead of waiting minutes for
// a write to fail - while a quiet-but-alive radio's kernel answers the
// probes, so a silent mesh never trips a false disconnect. The abrupt
// power-off itself cannot be simulated on loopback (no FIN suppression),
// so these tests pin the option application and the graceful-close path;
// the real power-off timing is validated on hardware.
void main() {
  DeviceInfo deviceFor(ServerSocket server) => DeviceInfo(
    id: 'tcp:127.0.0.1:${server.port}',
    name: 'Loopback',
    type: TransportType.network,
  );

  test('connect applies tuned keepalive on supported platforms', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final transport = NetworkTransport(host: '127.0.0.1', port: server.port);

    await transport.connect(deviceFor(server));

    expect(transport.state, DeviceConnectionState.connected);
    expect(
      transport.keepaliveEnabled,
      Platform.isMacOS ||
          Platform.isIOS ||
          Platform.isAndroid ||
          Platform.isLinux,
      reason:
          'On Darwin/Linux hosts the tuned keepalive options must apply; '
          'a silent failure would leave dead-link detection on the slow '
          'OS defaults.',
    );

    await transport.dispose();
    await server.close();
  });

  test('graceful server close flips state to disconnected promptly', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = Completer<Socket>();
    server.listen(accepted.complete);

    final transport = NetworkTransport(host: '127.0.0.1', port: server.port);
    await transport.connect(deviceFor(server));
    expect(transport.state, DeviceConnectionState.connected);

    final disconnected = transport.stateStream.firstWhere(
      (s) => s == DeviceConnectionState.disconnected,
    );
    (await accepted.future).destroy();

    await disconnected.timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail(
        'Transport must observe the peer FIN/RST via the read stream and '
        'flip to disconnected without waiting on timers.',
      ),
    );
    expect(transport.state, DeviceConnectionState.disconnected);
    expect(
      transport.keepaliveEnabled,
      isFalse,
      reason: 'The diagnostic flag must reset with the socket.',
    );

    await transport.dispose();
    await server.close();
  });

  test('data still flows after keepalive options are applied', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = Completer<Socket>();
    server.listen(accepted.complete);

    final transport = NetworkTransport(host: '127.0.0.1', port: server.port);
    await transport.connect(deviceFor(server));

    final received = transport.dataStream.first;
    (await accepted.future).add(const [0x94, 0xC3, 0x00, 0x01, 0x42]);

    expect(await received.timeout(const Duration(seconds: 5)), const [
      0x94,
      0xC3,
      0x00,
      0x01,
      0x42,
    ]);

    await transport.dispose();
    await server.close();
  });
}
