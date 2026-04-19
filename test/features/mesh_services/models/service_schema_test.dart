// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/models/service_schema.dart';

void main() {
  group('SchemaFieldType', () {
    test('all codes are contiguous 0-6', () {
      final codes = SchemaFieldType.values.map((t) => t.code).toList();
      expect(codes, [0, 1, 2, 3, 4, 5, 6]);
    });

    test('fromCode round-trips all values', () {
      for (final t in SchemaFieldType.values) {
        expect(SchemaFieldType.fromCode(t.code), t);
      }
    });

    test('fromCode returns null for unknown code', () {
      expect(SchemaFieldType.fromCode(99), isNull);
    });
  });

  group('SchemaActionMethod', () {
    test('all codes are 0-2', () {
      final codes = SchemaActionMethod.values.map((m) => m.code).toList();
      expect(codes, [0, 1, 2]);
    });

    test('fromCode round-trips all values', () {
      for (final m in SchemaActionMethod.values) {
        expect(SchemaActionMethod.fromCode(m.code), m);
      }
    });

    test('fromCode returns null for unknown code', () {
      expect(SchemaActionMethod.fromCode(99), isNull);
    });
  });

  group('SchemaField', () {
    test('wireSize with no unit and no options', () {
      const field = SchemaField(
        id: 1,
        name: 'Temp',
        type: SchemaFieldType.number,
      );
      // id(1) + type(1) + nameLen(1) + name(4) + unitLen(1) + unit(0) +
      // optionCount(1) = 9
      expect(field.wireSize, 9);
    });

    test('wireSize with unit', () {
      const field = SchemaField(
        id: 1,
        name: 'Temp',
        type: SchemaFieldType.number,
        unit: 'C',
      );
      // 9 + 1 (unit length) = 10
      expect(field.wireSize, 10);
    });

    test('wireSize with options', () {
      const field = SchemaField(
        id: 1,
        name: 'Level',
        type: SchemaFieldType.choice,
        options: ['Low', 'Med', 'Hi'],
      );
      // id(1) + type(1) + nameLen(1) + name(5) + unitLen(1) + unit(0) +
      // optCount(1) + opt1Len(1)+opt1(3) + opt2Len(1)+opt2(3) +
      // opt3Len(1)+opt3(2) = 21
      expect(field.wireSize, 21);
    });
  });

  group('SchemaAction', () {
    test('wireSize', () {
      const action = SchemaAction(
        id: 1,
        name: 'Refresh',
        method: SchemaActionMethod.read,
      );
      // id(1) + method(1) + nameLen(1) + name(7) = 10
      expect(action.wireSize, 10);
    });
  });

  group('ServiceSchema', () {
    const schema = ServiceSchema(
      serviceType: 'weather.v1',
      title: 'Weather',
      fields: [
        SchemaField(
          id: 1,
          name: 'Temp',
          type: SchemaFieldType.number,
          unit: 'C',
        ),
        SchemaField(
          id: 2,
          name: 'Humidity',
          type: SchemaFieldType.number,
          unit: '%',
        ),
      ],
      actions: [
        SchemaAction(id: 1, name: 'Refresh', method: SchemaActionMethod.read),
      ],
    );

    test('fieldById returns matching field', () {
      expect(schema.fieldById(1)?.name, 'Temp');
      expect(schema.fieldById(2)?.name, 'Humidity');
    });

    test('fieldById returns null for unknown', () {
      expect(schema.fieldById(99), isNull);
    });

    test('actionById returns matching action', () {
      expect(schema.actionById(1)?.name, 'Refresh');
    });

    test('actionById returns null for unknown', () {
      expect(schema.actionById(99), isNull);
    });

    test('wireSize is positive', () {
      expect(schema.wireSize, greaterThan(0));
    });
  });

  group('ServiceSchemaCodec', () {
    const schema = ServiceSchema(
      serviceType: 'weather.v1',
      title: 'Weather',
      fields: [
        SchemaField(
          id: 1,
          name: 'Temp',
          type: SchemaFieldType.number,
          unit: 'C',
        ),
        SchemaField(
          id: 2,
          name: 'Humidity',
          type: SchemaFieldType.number,
          unit: '%',
        ),
        SchemaField(
          id: 3,
          name: 'Conditions',
          type: SchemaFieldType.choice,
          options: ['Clear', 'Cloudy', 'Rain'],
        ),
      ],
      actions: [
        SchemaAction(id: 1, name: 'Refresh', method: SchemaActionMethod.read),
      ],
    );

    test('encode produces non-null bytes', () {
      final bytes = ServiceSchemaCodec.encode(schema);
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(0));
      expect(bytes.length, lessThanOrEqualTo(512));
    });

    test('decode round-trips fields and actions', () {
      final bytes = ServiceSchemaCodec.encode(schema)!;
      final decoded = ServiceSchemaCodec.decode(bytes)!;

      expect(decoded.serviceType, schema.serviceType);
      expect(decoded.title, schema.title);
      expect(decoded.fields.length, schema.fields.length);
      expect(decoded.actions.length, schema.actions.length);

      // Check field 1.
      expect(decoded.fields[0].id, 1);
      expect(decoded.fields[0].name, 'Temp');
      expect(decoded.fields[0].type, SchemaFieldType.number);
      expect(decoded.fields[0].unit, 'C');
      expect(decoded.fields[0].options, isEmpty);

      // Check field 2.
      expect(decoded.fields[1].id, 2);
      expect(decoded.fields[1].name, 'Humidity');
      expect(decoded.fields[1].type, SchemaFieldType.number);
      expect(decoded.fields[1].unit, '%');

      // Check field 3 (choice with options).
      expect(decoded.fields[2].id, 3);
      expect(decoded.fields[2].name, 'Conditions');
      expect(decoded.fields[2].type, SchemaFieldType.choice);
      expect(decoded.fields[2].options, ['Clear', 'Cloudy', 'Rain']);

      // Check action.
      expect(decoded.actions[0].id, 1);
      expect(decoded.actions[0].name, 'Refresh');
      expect(decoded.actions[0].method, SchemaActionMethod.read);
    });

    test('decode returns null for too-short data', () {
      expect(ServiceSchemaCodec.decode(Uint8List(0)), isNull);
      expect(ServiceSchemaCodec.decode(Uint8List(2)), isNull);
    });

    test('decode returns null for truncated service type', () {
      // serviceTypeLen = 50 but only 3 bytes of data.
      final bad = Uint8List.fromList([50, 0, 0, 0]);
      expect(ServiceSchemaCodec.decode(bad), isNull);
    });

    test('encode returns null for oversized schema', () {
      // Build a schema with many long fields to exceed 512B.
      final bigFields = List.generate(
        16,
        (i) => SchemaField(
          id: i + 1,
          name: 'A' * 32,
          type: SchemaFieldType.text,
          unit: 'B' * 8,
          options: List.generate(16, (j) => 'Opt${j}_${'C' * 28}'),
        ),
      );
      final bigSchema = ServiceSchema(
        serviceType: 'test.v1',
        title: 'Test',
        fields: bigFields,
      );
      expect(ServiceSchemaCodec.encode(bigSchema), isNull);
    });

    test('encode/decode empty schema', () {
      const empty = ServiceSchema(serviceType: 'empty.v1', title: 'Empty');
      final bytes = ServiceSchemaCodec.encode(empty)!;
      final decoded = ServiceSchemaCodec.decode(bytes)!;

      expect(decoded.serviceType, 'empty.v1');
      expect(decoded.title, 'Empty');
      expect(decoded.fields, isEmpty);
      expect(decoded.actions, isEmpty);
    });

    test('encode/decode schema with all field types', () {
      const allTypes = ServiceSchema(
        serviceType: 'all.v1',
        title: 'All Types',
        fields: [
          SchemaField(id: 1, name: 'T', type: SchemaFieldType.text),
          SchemaField(id: 2, name: 'N', type: SchemaFieldType.number),
          SchemaField(id: 3, name: 'B', type: SchemaFieldType.boolean),
          SchemaField(id: 4, name: 'C', type: SchemaFieldType.choice),
          SchemaField(id: 5, name: 'L', type: SchemaFieldType.list),
          SchemaField(id: 6, name: 'A', type: SchemaFieldType.action),
          SchemaField(id: 7, name: 'S', type: SchemaFieldType.timestamp),
        ],
      );
      final bytes = ServiceSchemaCodec.encode(allTypes)!;
      final decoded = ServiceSchemaCodec.decode(bytes)!;

      expect(decoded.fields.length, 7);
      for (var i = 0; i < 7; i++) {
        expect(decoded.fields[i].type, allTypes.fields[i].type);
      }
    });

    test('encode/decode preserves multiple actions', () {
      const multi = ServiceSchema(
        serviceType: 'multi.v1',
        title: 'Multi',
        actions: [
          SchemaAction(id: 1, name: 'Read', method: SchemaActionMethod.read),
          SchemaAction(id: 2, name: 'Write', method: SchemaActionMethod.write),
          SchemaAction(
            id: 3,
            name: 'Delete',
            method: SchemaActionMethod.delete,
          ),
        ],
      );
      final bytes = ServiceSchemaCodec.encode(multi)!;
      final decoded = ServiceSchemaCodec.decode(bytes)!;

      expect(decoded.actions.length, 3);
      expect(decoded.actions[0].method, SchemaActionMethod.read);
      expect(decoded.actions[1].method, SchemaActionMethod.write);
      expect(decoded.actions[2].method, SchemaActionMethod.delete);
    });

    test('byte-level: first byte is service type length', () {
      final bytes = ServiceSchemaCodec.encode(schema)!;
      // "weather.v1" = 10 bytes
      expect(bytes[0], 10);
    });

    test('decode with unknown field type returns null', () {
      // Craft bytes: serviceType='t', title='t', 1 field with bad type
      final bytes = Uint8List.fromList([
        1, 0x74, // serviceType: "t"
        1, 0x74, // title: "t"
        1, // 1 field
        1, // field id = 1
        99, // field type = 99 (invalid)
        1, 0x78, // name: "x"
        0, // unit: ""
        0, // 0 options
        0, // 0 actions
      ]);
      expect(ServiceSchemaCodec.decode(bytes), isNull);
    });
  });
}
