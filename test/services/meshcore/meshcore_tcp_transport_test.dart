// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/services/meshcore/mesh_transport.dart';
import 'package:socialmesh/services/meshcore/meshcore_tcp_transport.dart';
import 'package:socialmesh/services/meshcore/meshcore_usb_framing.dart';

/// Build a synthetic DeviceInfo for the TCP transport's connect signature.
/// The id/name fields are unused by the transport itself (host/port come
/// from the constructor) — they exist only so the [MeshTransport.connect]
/// signature is satisfied.
DeviceInfo _synthDevice() => DeviceInfo(
  id: 'meshcore-tcp:test',
  name: 'MeshCore TCP test',
  type: TransportType.network,
);

void main() {
  group('MeshCoreTcpTransport', () {
    test('starts disconnected with TransportType.network', () {
      final t = MeshCoreTcpTransport(host: '127.0.0.1', port: 1);
      expect(t.connectionState, DeviceConnectionState.disconnected);
      expect(t.transportType, TransportType.network);
      expect(t.isConnected, isFalse);
    });

    test('connect succeeds against a local ServerSocket', () async {
      final server = await ServerSocket.bind('127.0.0.1', 0);
      addTearDown(server.close);
      // Accept and discard — we just need the listener to exist.
      server.listen((s) => s.destroy());

      final t = MeshCoreTcpTransport(host: '127.0.0.1', port: server.port);
      addTearDown(t.dispose);

      await t.connect(_synthDevice());
      expect(t.isConnected, isTrue);
      expect(t.connectionState, DeviceConnectionState.connected);
    });

    test('connect to a refused port surfaces an error', () async {
      // Bind a port and immediately close it so the OS can re-issue it but
      // nothing is listening — `connect` should throw.
      final probe = await ServerSocket.bind('127.0.0.1', 0);
      final closedPort = probe.port;
      await probe.close();

      final t = MeshCoreTcpTransport(
        host: '127.0.0.1',
        port: closedPort,
        connectTimeout: const Duration(seconds: 2),
      );
      addTearDown(t.dispose);

      await expectLater(
        t.connect(_synthDevice()),
        throwsA(isA<SocketException>()),
      );
      expect(t.connectionState, DeviceConnectionState.error);
    });

    test(
      'sendBytes wraps the payload in MeshCoreUsbEncoder framing on the wire',
      () async {
        final server = await ServerSocket.bind('127.0.0.1', 0);
        addTearDown(server.close);

        final receivedCompleter = Completer<List<int>>();
        server.listen((client) {
          final buffer = <int>[];
          client.listen((chunk) {
            buffer.addAll(chunk);
            // Expect 1 framed packet: 3-byte header + 2-byte payload.
            if (buffer.length >= 5 && !receivedCompleter.isCompleted) {
              receivedCompleter.complete(buffer);
            }
          });
        });

        final t = MeshCoreTcpTransport(host: '127.0.0.1', port: server.port);
        addTearDown(t.dispose);

        await t.connect(_synthDevice());
        // Smallest legal MeshCore command frame: cmd (1 byte) + 1 byte payload.
        await t.sendBytes(Uint8List.fromList([0x16, 0x03]));

        final received = await receivedCompleter.future.timeout(
          const Duration(seconds: 2),
        );
        // Header: '<' (0x3C), len_lo=2, len_hi=0; payload: 0x16 0x03.
        expect(received[0], MeshCoreUsbMarkers.appToRadio);
        expect(received[1], 2);
        expect(received[2], 0);
        expect(received[3], 0x16);
        expect(received[4], 0x03);
      },
    );

    test(
      'incoming frames from the radio are deframed and emitted on dataStream',
      () async {
        final server = await ServerSocket.bind('127.0.0.1', 0);
        addTearDown(server.close);

        final clientReady = Completer<Socket>();
        server.listen((s) {
          if (!clientReady.isCompleted) clientReady.complete(s);
        });

        final t = MeshCoreTcpTransport(host: '127.0.0.1', port: server.port);
        addTearDown(t.dispose);

        await t.connect(_synthDevice());
        final clientSocket = await clientReady.future;
        addTearDown(clientSocket.destroy);

        // Send a single radio→app frame: '>' header + 3-byte payload.
        // Payload [0x05, 0xAA, 0xBB] is shaped like a respSelfInfo prefix.
        const payload = [0x05, 0xAA, 0xBB];
        clientSocket.add([
          MeshCoreUsbMarkers.radioToApp,
          payload.length,
          0x00,
          ...payload,
        ]);
        await clientSocket.flush();

        final emitted = await t.dataStream.first.timeout(
          const Duration(seconds: 2),
        );
        // The transport should have stripped the USB header and emitted only
        // the payload — same shape as a BLE notification carries.
        expect(emitted, payload);
      },
    );

    test(
      'a frame split across two socket reads still produces one dataStream event',
      () async {
        final server = await ServerSocket.bind('127.0.0.1', 0);
        addTearDown(server.close);

        final clientReady = Completer<Socket>();
        server.listen((s) {
          if (!clientReady.isCompleted) clientReady.complete(s);
        });

        final t = MeshCoreTcpTransport(host: '127.0.0.1', port: server.port);
        addTearDown(t.dispose);

        await t.connect(_synthDevice());
        final clientSocket = await clientReady.future;
        addTearDown(clientSocket.destroy);

        // Pre-subscribe so the first emit is captured.
        final firstFrame = t.dataStream.first.timeout(
          const Duration(seconds: 2),
        );

        const payload = [0x05, 0x11, 0x22, 0x33];
        // Write the header alone first, then the payload separately. The
        // decoder must buffer across the gap and still emit a single
        // complete frame.
        clientSocket.add([MeshCoreUsbMarkers.radioToApp, payload.length, 0x00]);
        await clientSocket.flush();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        clientSocket.add(payload);
        await clientSocket.flush();

        final emitted = await firstFrame;
        expect(emitted, payload);
      },
    );

    test('sendBytes throws when not connected', () async {
      final t = MeshCoreTcpTransport(host: '127.0.0.1', port: 1);
      addTearDown(t.dispose);
      await expectLater(t.sendBytes([0x01]), throwsA(isA<StateError>()));
    });

    test(
      'disconnect transitions through disconnecting → disconnected',
      () async {
        final server = await ServerSocket.bind('127.0.0.1', 0);
        addTearDown(server.close);
        server.listen((s) {});

        final t = MeshCoreTcpTransport(host: '127.0.0.1', port: server.port);
        addTearDown(t.dispose);

        final states = <DeviceConnectionState>[];
        final sub = t.connectionStateStream.listen(states.add);
        addTearDown(sub.cancel);

        await t.connect(_synthDevice());
        await t.disconnect();
        // Broadcast stream events are delivered via microtasks; pump once
        // so the listener's `states` list reflects the disconnect events.
        await Future<void>.delayed(Duration.zero);

        expect(t.connectionState, DeviceConnectionState.disconnected);
        expect(states, contains(DeviceConnectionState.connected));
        expect(states, contains(DeviceConnectionState.disconnecting));
        expect(states.last, DeviceConnectionState.disconnected);
      },
    );

    test('peer-side close transitions transport to disconnected', () async {
      final server = await ServerSocket.bind('127.0.0.1', 0);
      addTearDown(server.close);

      final clientReady = Completer<Socket>();
      server.listen((s) {
        if (!clientReady.isCompleted) clientReady.complete(s);
      });

      final t = MeshCoreTcpTransport(host: '127.0.0.1', port: server.port);
      addTearDown(t.dispose);

      await t.connect(_synthDevice());
      final clientSocket = await clientReady.future;
      // Server-side close from the peer's POV.
      clientSocket.destroy();

      // Wait briefly for the onDone handler to fire.
      for (var i = 0; i < 20 && t.isConnected; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      expect(t.connectionState, DeviceConnectionState.disconnected);
    });

    test('dispose runs idempotently and cleanly', () async {
      final t = MeshCoreTcpTransport(host: '127.0.0.1', port: 1);
      await t.dispose();
      // Calling dispose() a second time must not throw, even though the
      // socket was never connected and the stream controllers are already
      // closed.
      await t.dispose();
    });
  });
}
