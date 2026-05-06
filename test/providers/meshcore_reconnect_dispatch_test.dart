// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D27 - MeshCore reconnect dispatch routing tests.
//
// Pin the routing rule used by `dispatchReconnectMeshCoreAware` and
// `dispatchReconnectMeshCoreAwareForWidget`: when `lastDeviceProtocol`
// is `meshcore`, dispatch must short-circuit into the MeshCore-aware
// branch and never consult the Meshtastic `transportProvider`. For
// other protocols the dispatcher falls through to the existing
// transport-mode dispatcher.
//
// The router decides transport tag via `MeshCoreTcpDeviceId.tryParse`:
// `meshcore-tcp:host:port` -> `tcp`, anything else -> `ble`.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/providers/app_providers.dart';

void main() {
  group('routeMeshCoreReconnectForTest - protocol gating', () {
    test('routes MeshCore TCP id through MeshCore branch', () {
      final result = routeMeshCoreReconnectForTest(
        deviceId: 'meshcore-tcp:192.168.1.100:5000',
        lastProtocol: 'meshcore',
      );
      expect(result.routed, isTrue);
      expect(result.transportTag, 'tcp');
    });

    test('routes MeshCore BLE id through MeshCore branch with ble tag', () {
      final result = routeMeshCoreReconnectForTest(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        lastProtocol: 'meshcore',
      );
      expect(result.routed, isTrue);
      expect(result.transportTag, 'ble');
    });

    test('does NOT route Meshtastic peer through MeshCore branch', () {
      final result = routeMeshCoreReconnectForTest(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        lastProtocol: 'meshtastic',
      );
      expect(result.routed, isFalse);
      expect(result.transportTag, isNull);
    });

    test('does NOT route Meshtastic TCP peer through MeshCore branch', () {
      // Important: a `tcp:host:port` Meshtastic id MUST NOT be misrouted
      // even though the MeshCore TCP id format is similar.
      final result = routeMeshCoreReconnectForTest(
        deviceId: 'tcp:node.local:4403',
        lastProtocol: 'meshtastic',
      );
      expect(result.routed, isFalse);
      expect(result.transportTag, isNull);
    });

    test('does NOT route when lastProtocol is null', () {
      final result = routeMeshCoreReconnectForTest(
        deviceId: 'meshcore-tcp:192.168.1.100:5000',
        lastProtocol: null,
      );
      expect(result.routed, isFalse);
      expect(result.transportTag, isNull);
    });

    test('does NOT route when lastProtocol is unknown string', () {
      final result = routeMeshCoreReconnectForTest(
        deviceId: 'meshcore-tcp:192.168.1.100:5000',
        lastProtocol: 'reticulum',
      );
      expect(result.routed, isFalse);
      expect(result.transportTag, isNull);
    });
  });

  group('routeMeshCoreReconnectForTest - transport tag selection', () {
    test('IPv4 TCP id -> tcp', () {
      final result = routeMeshCoreReconnectForTest(
        deviceId: 'meshcore-tcp:192.168.1.100:5000',
        lastProtocol: 'meshcore',
      );
      expect(result.transportTag, 'tcp');
    });

    test('hostname TCP id -> tcp', () {
      final result = routeMeshCoreReconnectForTest(
        deviceId: 'meshcore-tcp:radio.local:5000',
        lastProtocol: 'meshcore',
      );
      expect(result.transportTag, 'tcp');
    });

    test('malformed TCP id (port 0) -> ble', () {
      // `MeshCoreTcpDeviceId.tryParse` rejects port=0, so the dispatch
      // layer treats it as a non-TCP MeshCore id (BLE branch). The
      // dispatcher's downstream `_startMeshCoreBackgroundConnection`
      // separately bails on a `meshcore-tcp:` prefix that fails to
      // parse — see connection_providers.dart:1249.
      final result = routeMeshCoreReconnectForTest(
        deviceId: 'meshcore-tcp:host:0',
        lastProtocol: 'meshcore',
      );
      expect(result.transportTag, 'ble');
    });

    test('BLE-style remoteId -> ble', () {
      final result = routeMeshCoreReconnectForTest(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        lastProtocol: 'meshcore',
      );
      expect(result.transportTag, 'ble');
    });

    test('empty deviceId still routes (transport tag falls back to ble)', () {
      // The router itself does not validate the deviceId beyond TCP
      // parsing; the downstream `_startMeshCoreBackgroundConnection`
      // owns the no-device guard. Route MUST still succeed so the
      // dispatcher emits its `event=reconnect.requested` log line.
      final result = routeMeshCoreReconnectForTest(
        deviceId: '',
        lastProtocol: 'meshcore',
      );
      expect(result.routed, isTrue);
      expect(result.transportTag, 'ble');
    });
  });

  group('routeMeshCoreReconnectForTest - regression boundaries', () {
    test('Meshtastic TCP id and Meshtastic protocol -> falls through', () {
      // The historic regression this rule guards against: a TCP-saved
      // peer must never get a BLE scan started for it. When the peer is
      // Meshtastic the dispatcher falls through to the Meshtastic
      // transport's own reconnect-mode dispatch (network vs scan), so
      // routing returns false here.
      final result = routeMeshCoreReconnectForTest(
        deviceId: 'tcp:10.0.0.5:4403',
        lastProtocol: 'meshtastic',
      );
      expect(result.routed, isFalse);
    });

    test('case-sensitive protocol match (Meshcore != meshcore)', () {
      // `lastDeviceProtocol` is persisted as the lowercase string
      // `meshcore`. A capitalisation change anywhere in the persistence
      // chain would silently disable the MeshCore branch — pin it.
      final result = routeMeshCoreReconnectForTest(
        deviceId: 'meshcore-tcp:host:5000',
        lastProtocol: 'Meshcore',
      );
      expect(result.routed, isFalse);
    });
  });
}
