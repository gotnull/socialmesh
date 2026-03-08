// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_template.dart';
import 'package:socialmesh/features/mesh_services/models/service_schema.dart';
import 'package:socialmesh/features/mesh_services/models/template_schemas.dart';

void main() {
  group('TemplateSchemas', () {
    test('forTemplate returns non-null for all template IDs', () {
      for (final id in MeshServiceTemplateId.values) {
        final schema = TemplateSchemas.forTemplate(id);
        expect(schema, isNotNull, reason: '$id should have a built-in schema');
      }
    });

    test('all schemas have non-empty serviceType', () {
      for (final id in MeshServiceTemplateId.values) {
        final schema = TemplateSchemas.forTemplate(id)!;
        expect(schema.serviceType, isNotEmpty, reason: '$id');
      }
    });

    test('all schemas have non-empty title', () {
      for (final id in MeshServiceTemplateId.values) {
        final schema = TemplateSchemas.forTemplate(id)!;
        expect(schema.title, isNotEmpty, reason: '$id');
      }
    });

    test('all field IDs within a schema are unique', () {
      for (final id in MeshServiceTemplateId.values) {
        final schema = TemplateSchemas.forTemplate(id)!;
        final fieldIds = schema.fields.map((f) => f.id).toSet();
        expect(
          fieldIds.length,
          schema.fields.length,
          reason: '$id has duplicate field IDs',
        );
      }
    });

    test('all action IDs within a schema are unique', () {
      for (final id in MeshServiceTemplateId.values) {
        final schema = TemplateSchemas.forTemplate(id)!;
        final actionIds = schema.actions.map((a) => a.id).toSet();
        expect(
          actionIds.length,
          schema.actions.length,
          reason: '$id has duplicate action IDs',
        );
      }
    });

    test('all field IDs are in 1-255 range', () {
      for (final id in MeshServiceTemplateId.values) {
        final schema = TemplateSchemas.forTemplate(id)!;
        for (final f in schema.fields) {
          expect(f.id, inInclusiveRange(1, 255), reason: '$id field ${f.name}');
        }
      }
    });

    test('all schemas fit within 512-byte wire limit', () {
      for (final id in MeshServiceTemplateId.values) {
        final schema = TemplateSchemas.forTemplate(id)!;
        final bytes = ServiceSchemaCodec.encode(schema);
        expect(bytes, isNotNull, reason: '$id schema exceeds 512B wire limit');
      }
    });

    test('all schemas round-trip through codec', () {
      for (final id in MeshServiceTemplateId.values) {
        final schema = TemplateSchemas.forTemplate(id)!;
        final bytes = ServiceSchemaCodec.encode(schema)!;
        final decoded = ServiceSchemaCodec.decode(bytes)!;

        expect(decoded.serviceType, schema.serviceType, reason: '$id');
        expect(decoded.title, schema.title, reason: '$id');
        expect(decoded.fields.length, schema.fields.length, reason: '$id');
        expect(decoded.actions.length, schema.actions.length, reason: '$id');
      }
    });

    test('board schema has board.v1 type', () {
      expect(TemplateSchemas.board.serviceType, 'board.v1');
    });

    test('signal schema has signal.v1 type', () {
      expect(TemplateSchemas.signal.serviceType, 'signal.v1');
    });

    test('weatherStation schema has weather.v1 type', () {
      expect(TemplateSchemas.weatherStation.serviceType, 'weather.v1');
    });

    test('sensorNode schema has sensor.v1 type', () {
      expect(TemplateSchemas.sensorNode.serviceType, 'sensor.v1');
    });

    test('taskBoard schema has taskboard.v1 type', () {
      expect(TemplateSchemas.taskBoard.serviceType, 'taskboard.v1');
    });

    test('trailConditions schema has trail.v1 type', () {
      expect(TemplateSchemas.trailConditions.serviceType, 'trail.v1');
    });

    test('lostAndFound schema has lostandfound.v1 type', () {
      expect(TemplateSchemas.lostAndFound.serviceType, 'lostandfound.v1');
    });
  });
}
