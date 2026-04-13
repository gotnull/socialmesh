// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/models/service_schema.dart';
import 'package:socialmesh/features/mesh_services/models/service_schema_cache.dart';

void main() {
  group('ServiceSchemaCache', () {
    late ServiceSchemaCache cache;

    setUp(() {
      cache = ServiceSchemaCache();
    });

    const testSchema = ServiceSchema(
      serviceType: 'test.v1',
      title: 'Test',
      fields: [SchemaField(id: 1, name: 'Value', type: SchemaFieldType.number)],
    );

    test('put and get returns cached schema', () {
      cache.put(42, testSchema);
      final result = cache.get(42, 'test.v1');
      expect(result, isNotNull);
      expect(result!.serviceType, 'test.v1');
      expect(result.title, 'Test');
    });

    test('get returns null for uncached unknown type', () {
      expect(cache.get(42, 'nonexistent.v1'), isNull);
    });

    test('get falls back to built-in schemas', () {
      // "feed.v1" is a built-in template — should resolve without put().
      final result = cache.get(99, 'feed.v1');
      expect(result, isNotNull);
      expect(result!.serviceType, 'feed.v1');
    });

    test('contains returns true for cached entry', () {
      cache.put(42, testSchema);
      expect(cache.contains(42, 'test.v1'), isTrue);
    });

    test('contains returns true for built-in type', () {
      expect(cache.contains(99, 'sensor.v1'), isTrue);
    });

    test('contains returns false for unknown type', () {
      expect(cache.contains(99, 'nonexistent.v1'), isFalse);
    });

    test('different nodeId same serviceType are separate entries', () {
      cache.put(1, testSchema);
      // Node 2 has no cached entry for test.v1.
      expect(cache.get(2, 'test.v1'), isNull);
    });

    test('clear removes all entries', () {
      cache.put(1, testSchema);
      cache.put(2, testSchema);
      expect(cache.length, 2);
      cache.clear();
      expect(cache.length, 0);
    });

    test('evicts oldest when at capacity', () {
      // Fill to maxEntries with unique node IDs.
      for (var i = 0; i < ServiceSchemaCache.maxEntries; i++) {
        cache.put(
          i,
          ServiceSchema(serviceType: 'type_$i.v1', title: 'Type $i'),
        );
      }
      expect(cache.length, ServiceSchemaCache.maxEntries);

      // Adding one more should evict the oldest (node 0).
      cache.put(
        999,
        const ServiceSchema(serviceType: 'extra.v1', title: 'Extra'),
      );
      expect(cache.length, ServiceSchemaCache.maxEntries);
    });

    test('put overwrites existing entry for same key', () {
      cache.put(42, testSchema);
      const updated = ServiceSchema(serviceType: 'test.v1', title: 'Updated');
      cache.put(42, updated);
      expect(cache.length, 1);
      expect(cache.get(42, 'test.v1')!.title, 'Updated');
    });
  });
}
