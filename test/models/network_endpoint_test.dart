// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/network_endpoint.dart';
import 'package:socialmesh/services/transport/network_transport.dart';

void main() {
  group('NetworkEndpoint', () {
    test('create() generates deterministic ID from host:port', () {
      final e1 = NetworkEndpoint.create(host: '192.168.1.1', port: 4403);
      final e2 = NetworkEndpoint.create(host: '192.168.1.1', port: 4403);
      expect(e1.id, e2.id);
    });

    test('create() uses default port', () {
      final e = NetworkEndpoint.create(host: 'mesh.local');
      expect(e.port, kMeshtasticDefaultPort);
      expect(e.port, 4403);
    });

    test('displayAddress formats host:port', () {
      final e = NetworkEndpoint.create(host: '10.0.0.5', port: 1234);
      expect(e.displayAddress, '10.0.0.5:1234');
    });

    test('toJson and fromJson round-trip', () {
      final original = NetworkEndpoint(
        id: 'abc123',
        host: '192.168.1.100',
        port: 4403,
        lastUsed: DateTime(2025, 1, 15, 10, 30),
        name: 'Living Room',
      );
      final json = original.toJson();
      final restored = NetworkEndpoint.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.host, original.host);
      expect(restored.port, original.port);
      expect(restored.lastUsed, original.lastUsed);
      expect(restored.name, original.name);
    });

    test('fromJson handles missing optional name', () {
      final json = {
        'id': 'test',
        'host': '10.0.0.1',
        'port': 4403,
        'lastUsed': '2025-01-01T00:00:00.000',
      };
      final e = NetworkEndpoint.fromJson(json);
      expect(e.name, isNull);
    });

    test('fromJson uses default port when missing', () {
      final json = {
        'id': 'test',
        'host': '10.0.0.1',
        'lastUsed': '2025-01-01T00:00:00.000',
      };
      final e = NetworkEndpoint.fromJson(json);
      expect(e.port, kMeshtasticDefaultPort);
    });

    test('encodeList and decodeList round-trip', () {
      final endpoints = [
        NetworkEndpoint.create(host: '10.0.0.1', port: 4403, name: 'Node A'),
        NetworkEndpoint.create(host: '10.0.0.2', port: 4404),
      ];
      final encoded = NetworkEndpoint.encodeList(endpoints);
      final decoded = NetworkEndpoint.decodeList(encoded);

      expect(decoded.length, 2);
      expect(decoded[0].host, '10.0.0.1');
      expect(decoded[0].name, 'Node A');
      expect(decoded[1].host, '10.0.0.2');
      expect(decoded[1].port, 4404);
      expect(decoded[1].name, isNull);
    });

    test('equality is based on id', () {
      final e1 = NetworkEndpoint(
        id: 'same',
        host: '10.0.0.1',
        port: 4403,
        lastUsed: DateTime.now(),
      );
      final e2 = NetworkEndpoint(
        id: 'same',
        host: '10.0.0.2',
        port: 9999,
        lastUsed: DateTime.now(),
      );
      expect(e1, equals(e2));
    });

    test('different IDs are not equal', () {
      final e1 = NetworkEndpoint(
        id: 'a',
        host: '10.0.0.1',
        port: 4403,
        lastUsed: DateTime.now(),
      );
      final e2 = NetworkEndpoint(
        id: 'b',
        host: '10.0.0.1',
        port: 4403,
        lastUsed: DateTime.now(),
      );
      expect(e1, isNot(equals(e2)));
    });

    test('copyWith creates modified copy', () {
      final original = NetworkEndpoint.create(host: '10.0.0.1');
      final updated = original.copyWith(name: 'Updated', port: 5555);
      expect(updated.host, original.host);
      expect(updated.name, 'Updated');
      expect(updated.port, 5555);
      expect(updated.id, original.id);
    });

    test('toString returns readable format', () {
      final e = NetworkEndpoint.create(host: '192.168.1.1', port: 4403);
      expect(e.toString(), 'NetworkEndpoint(192.168.1.1:4403)');
    });
  });
}
