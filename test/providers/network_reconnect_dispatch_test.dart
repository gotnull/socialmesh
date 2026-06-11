// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Endpoint-parsing and dispatch behavior for network reconnect.
// Network reconnect must not route through BLE scan logic — see
// issue #102 for the failure mode this guards against.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/network_endpoint.dart';
import 'package:socialmesh/providers/app_providers.dart';

void main() {
  group('parseNetworkEndpointIdForTest', () {
    test('parses tcp:host:port', () {
      final parsed = parseNetworkEndpointIdForTest('tcp:10.0.0.5:4403');
      expect(parsed, isNotNull);
      expect(parsed!.host, '10.0.0.5');
      expect(parsed.port, 4403);
    });

    test('id built from a storage-normalized endpoint round-trips to the '
        'identical host and port', () {
      // Storage-time normalization (NetworkEndpoint.create) and the
      // reconnect parser must agree on the canonical form, so a saved
      // endpoint's tcp id always parses back to itself.
      final endpoint = NetworkEndpoint.create(host: ' Node.LOCAL ', port: 4403);
      final parsed = parseNetworkEndpointIdForTest(
        'tcp:${endpoint.host}:${endpoint.port}',
      );
      expect(parsed, isNotNull);
      expect(parsed!.host, endpoint.host);
      expect(parsed.port, endpoint.port);
    });

    test('parses hostname-based endpoints', () {
      final parsed = parseNetworkEndpointIdForTest('tcp:node.local:4403');
      expect(parsed, isNotNull);
      expect(parsed!.host, 'node.local');
      expect(parsed.port, 4403);
    });

    test('returns null for BLE-style device IDs', () {
      expect(parseNetworkEndpointIdForTest('AA:BB:CC:DD:EE:FF'), isNull);
    });

    test('returns null for empty strings', () {
      expect(parseNetworkEndpointIdForTest(''), isNull);
      expect(parseNetworkEndpointIdForTest('tcp:'), isNull);
      expect(parseNetworkEndpointIdForTest('tcp::4403'), isNull);
      expect(parseNetworkEndpointIdForTest('tcp:host:'), isNull);
    });

    test('rejects out-of-range ports', () {
      expect(parseNetworkEndpointIdForTest('tcp:host:0'), isNull);
      expect(parseNetworkEndpointIdForTest('tcp:host:65536'), isNull);
      expect(parseNetworkEndpointIdForTest('tcp:host:not-a-number'), isNull);
    });

    test('lowercases hostnames so case variants hash to one reconnect key', () {
      final a = parseNetworkEndpointIdForTest('tcp:Node.Local:4403');
      final b = parseNetworkEndpointIdForTest('tcp:node.local:4403');
      expect(a, isNotNull);
      expect(b, isNotNull);
      expect(a!.host, 'node.local');
      expect(b!.host, 'node.local');
    });

    test('accepts uppercase scheme TCP:...', () {
      final parsed = parseNetworkEndpointIdForTest('TCP:10.0.0.5:4403');
      expect(parsed, isNotNull);
      expect(parsed!.host, '10.0.0.5');
      expect(parsed.port, 4403);
    });

    test('trims surrounding whitespace', () {
      final parsed = parseNetworkEndpointIdForTest('  tcp:10.0.0.5:4403  ');
      expect(parsed, isNotNull);
      expect(parsed!.host, '10.0.0.5');
      expect(parsed.port, 4403);
    });

    test('parses IPv6-bracketed form', () {
      final parsed = parseNetworkEndpointIdForTest('tcp:[::1]:4403');
      expect(parsed, isNotNull);
      expect(parsed!.host, '::1');
      expect(parsed.port, 4403);
    });

    test('rejects unterminated IPv6 bracket', () {
      expect(parseNetworkEndpointIdForTest('tcp:[::1:4403'), isNull);
    });

    test('rejects IPv6 form without port separator', () {
      expect(parseNetworkEndpointIdForTest('tcp:[::1]4403'), isNull);
      expect(parseNetworkEndpointIdForTest('tcp:[::1]'), isNull);
    });
  });

  group('network reconnect in-flight guard', () {
    test('sentinel is false outside a reconnect run (no real container '
        'invocation needed — structural assertion the flag exists and '
        'defaults false so a crashed loop cannot poison future runs)', () {
      expect(networkReconnectInFlightForTest, isFalse);
    });
  });
}
