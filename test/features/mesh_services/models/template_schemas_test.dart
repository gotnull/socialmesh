// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_instance.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_template.dart';
import 'package:socialmesh/features/mesh_services/models/service_schema.dart';
import 'package:socialmesh/features/mesh_services/models/template_schemas.dart';

void main() {
  group('MeshServiceSchemas', () {
    test('forType returns non-null for all canonical types', () {
      for (final type in MeshServiceType.values.where(
        (t) => t != MeshServiceType.game,
      )) {
        final schema = MeshServiceSchemas.forType(type);
        expect(
          schema,
          isNotNull,
          reason: '$type should have a built-in schema',
        );
      }
    });

    test('all schemas have non-empty serviceType', () {
      for (final type in MeshServiceType.values.where(
        (t) => t != MeshServiceType.game,
      )) {
        final schema = MeshServiceSchemas.forType(type)!;
        expect(schema.serviceType, isNotEmpty, reason: '$type');
      }
    });

    test('all schemas have non-empty title', () {
      for (final type in MeshServiceType.values.where(
        (t) => t != MeshServiceType.game,
      )) {
        final schema = MeshServiceSchemas.forType(type)!;
        expect(schema.title, isNotEmpty, reason: '$type');
      }
    });

    test('all field IDs within a schema are unique', () {
      for (final type in MeshServiceType.values.where(
        (t) => t != MeshServiceType.game,
      )) {
        final schema = MeshServiceSchemas.forType(type)!;
        final fieldIds = schema.fields.map((f) => f.id).toSet();
        expect(
          fieldIds.length,
          schema.fields.length,
          reason: '$type has duplicate field IDs',
        );
      }
    });

    test('all action IDs within a schema are unique', () {
      for (final type in MeshServiceType.values.where(
        (t) => t != MeshServiceType.game,
      )) {
        final schema = MeshServiceSchemas.forType(type)!;
        final actionIds = schema.actions.map((a) => a.id).toSet();
        expect(
          actionIds.length,
          schema.actions.length,
          reason: '$type has duplicate action IDs',
        );
      }
    });

    test('all field IDs are in 1-255 range', () {
      for (final type in MeshServiceType.values.where(
        (t) => t != MeshServiceType.game,
      )) {
        final schema = MeshServiceSchemas.forType(type)!;
        for (final f in schema.fields) {
          expect(
            f.id,
            inInclusiveRange(1, 255),
            reason: '$type field ${f.name}',
          );
        }
      }
    });

    test('all schemas fit within 512-byte wire limit', () {
      for (final type in MeshServiceType.values.where(
        (t) => t != MeshServiceType.game,
      )) {
        final schema = MeshServiceSchemas.forType(type)!;
        final bytes = ServiceSchemaCodec.encode(schema);
        expect(
          bytes,
          isNotNull,
          reason: '$type schema exceeds 512B wire limit',
        );
      }
    });

    test('all schemas round-trip through codec', () {
      for (final type in MeshServiceType.values.where(
        (t) => t != MeshServiceType.game,
      )) {
        final schema = MeshServiceSchemas.forType(type)!;
        final bytes = ServiceSchemaCodec.encode(schema)!;
        final decoded = ServiceSchemaCodec.decode(bytes)!;

        expect(decoded.serviceType, schema.serviceType, reason: '$type');
        expect(decoded.title, schema.title, reason: '$type');
        expect(decoded.fields.length, schema.fields.length, reason: '$type');
        expect(decoded.actions.length, schema.actions.length, reason: '$type');
      }
    });

    test(
      'forType(game) returns null — games use dedicated UI, not schema',
      () {
        expect(
          MeshServiceSchemas.forType(MeshServiceType.game),
          isNull,
        );
      },
    );

    test('feed schema has feed.v1 type', () {
      expect(MeshServiceSchemas.feed.serviceType, 'feed.v1');
    });

    test('signal schema has signal.v1 type', () {
      expect(MeshServiceSchemas.signal.serviceType, 'signal.v1');
    });

    test('list schema has list.v1 type', () {
      expect(MeshServiceSchemas.list.serviceType, 'list.v1');
    });

    test('poll schema has poll.v1 type', () {
      expect(MeshServiceSchemas.poll.serviceType, 'poll.v1');
    });

    test('sensor schema has sensor.v1 type', () {
      expect(MeshServiceSchemas.sensor.serviceType, 'sensor.v1');
    });

    test('forInstance resolves schema from canonical type', () {
      final instance = MeshServiceInstance(
        instanceId: 'list-instance',
        canonicalType: MeshServiceType.list,
        presetId: MeshServicePresetId.taskBoard,
        title: 'Tasks',
        createdAt: DateTime(2025),
      );

      expect(MeshServiceSchemas.forInstance(instance), MeshServiceSchemas.list);
    });
  });
}
