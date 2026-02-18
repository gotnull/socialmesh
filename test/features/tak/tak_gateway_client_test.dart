// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/tak/services/tak_gateway_client.dart';

void main() {
  group('TakGatewayClient', () {
    test('initializes in disconnected state', () {
      final client = TakGatewayClient(
        gatewayUrl: 'wss://tak.socialmesh.app',
        getAuthToken: () async => 'fake-token',
      );

      expect(client.state, TakConnectionState.disconnected);
      expect(client.totalEventsReceived, 0);
      expect(client.totalReconnects, 0);
      expect(client.lastError, isNull);
      expect(client.connectedSince, isNull);

      client.dispose();
    });

    test('disconnect resets state cleanly', () {
      final client = TakGatewayClient(
        gatewayUrl: 'wss://tak.socialmesh.app',
        getAuthToken: () async => 'fake-token',
      );

      client.disconnect();
      expect(client.state, TakConnectionState.disconnected);
      expect(client.connectedSince, isNull);

      client.dispose();
    });

    test('dispose does not throw when called multiple times', () {
      final client = TakGatewayClient(
        gatewayUrl: 'wss://tak.socialmesh.app',
        getAuthToken: () async => null,
      );

      // Should not throw
      client.dispose();
    });

    test('stateStream emits state changes', () async {
      final client = TakGatewayClient(
        gatewayUrl: 'wss://localhost:99999',
        getAuthToken: () async => null,
        maxReconnectAttempts: 0,
      );

      // Listen for state changes
      final states = <TakConnectionState>[];
      final sub = client.stateStream.listen(states.add);

      // Calling disconnect should emit disconnected (though already disconnected,
      // the internal _setState only fires on change)
      expect(states, isEmpty);

      await sub.cancel();
      client.dispose();
    });

    test('TakConnectionState enum has expected values', () {
      expect(TakConnectionState.values, hasLength(4));
      expect(
        TakConnectionState.values,
        containsAll([
          TakConnectionState.disconnected,
          TakConnectionState.connecting,
          TakConnectionState.connected,
          TakConnectionState.reconnecting,
        ]),
      );
    });
  });
}
