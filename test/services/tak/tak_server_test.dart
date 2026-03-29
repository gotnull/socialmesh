// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/tak/tak_client_session.dart';
import 'package:socialmesh/services/tak/tak_server.dart';

void main() {
  group('TakServer', () {
    // Note: Full TLS server tests require actual certificates and sockets.
    // These tests verify the public API surface and types.

    test('TakServerEvent sealed class hierarchy', () {
      const event1 = TakServerError('test');
      expect(event1.message, 'test');
      expect(event1, isA<TakServerEvent>());
    });

    test('TakServer constants', () {
      expect(TakServer.defaultPort, 8089);
      expect(TakServer.maxClients, 5);
      expect(TakServer.inactivityTimeout, const Duration(seconds: 120));
    });

    test('TakSessionState enum values', () {
      expect(TakSessionState.values, hasLength(3));
      expect(TakSessionState.pendingNegotiation, isNotNull);
      expect(TakSessionState.authenticated, isNotNull);
      expect(TakSessionState.closed, isNotNull);
    });

    test('TakSessionEvent enum values', () {
      expect(TakSessionEvent.values, hasLength(2));
      expect(TakSessionEvent.authenticated, isNotNull);
      expect(TakSessionEvent.disconnected, isNotNull);
    });

    test('TakServerEvent subclasses are sealed', () {
      const connected = TakServerError('port in use');
      expect(connected, isA<TakServerEvent>());
      expect(connected.message, 'port in use');
    });
  });
}
