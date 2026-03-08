// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Schema descriptor model for mesh services.
///
/// Every service instance may expose a schema that describes its fields
/// and actions. Peers cache this schema once and use field IDs (not names)
/// in subsequent payloads — minimizing LoRa airtime.
///
/// Wire-compact: field IDs are uint8, types are uint8. The full schema
/// is transmitted only on first request; subsequent payloads carry only
/// field ID → value pairs.
library;

import 'dart:typed_data';

/// Field types that a schema descriptor can declare.
///
/// Each maps to a specific UI widget in the generic renderer.
enum SchemaFieldType {
  /// Free-text label (read-only or editable).
  text(0),

  /// Numeric display (with optional unit).
  number(1),

  /// Boolean toggle.
  boolean(2),

  /// Single-select from a list of options.
  choice(3),

  /// Ordered list of items.
  list(4),

  /// Actionable button.
  action(5),

  /// Relative or absolute timestamp.
  timestamp(6);

  const SchemaFieldType(this.code);

  /// Wire code for this field type.
  final int code;

  /// Look up a field type by wire code. Returns null if unknown.
  static SchemaFieldType? fromCode(int code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

/// Method types for schema actions.
enum SchemaActionMethod {
  /// Read-only retrieval.
  read(0),

  /// Write / mutation.
  write(1),

  /// Delete / removal.
  delete(2);

  const SchemaActionMethod(this.code);
  final int code;

  static SchemaActionMethod? fromCode(int code) {
    for (final m in values) {
      if (m.code == code) return m;
    }
    return null;
  }
}

/// A single field in a service schema.
class SchemaField {
  /// Unique field identifier (uint8, 1-255). Used as key in payloads.
  final int id;

  /// Human-readable field name (display label).
  final String name;

  /// Field data type.
  final SchemaFieldType type;

  /// Optional unit string (e.g., "C", "%", "hPa").
  final String unit;

  /// For [SchemaFieldType.choice]: the list of option labels.
  final List<String> options;

  const SchemaField({
    required this.id,
    required this.name,
    required this.type,
    this.unit = '',
    this.options = const [],
  });

  /// Estimated wire size for this field descriptor.
  int get wireSize {
    // id(1) + type(1) + nameLen(1) + name(N) + unitLen(1) + unit(N) +
    // optionCount(1) + [optionLen(1) + option(N)]...
    var size = 5 + name.length + unit.length;
    for (final opt in options) {
      size += 1 + opt.length;
    }
    return size;
  }
}

/// A single action in a service schema.
class SchemaAction {
  /// Unique action identifier (uint8, 1-255).
  final int id;

  /// Human-readable action name (button label).
  final String name;

  /// Action method (read, write, delete).
  final SchemaActionMethod method;

  const SchemaAction({
    required this.id,
    required this.name,
    required this.method,
  });

  /// Wire size: id(1) + method(1) + nameLen(1) + name(N).
  int get wireSize => 3 + name.length;
}

/// Complete schema descriptor for a service instance.
///
/// Cached locally after first retrieval. Subsequent data payloads
/// reference fields by [SchemaField.id], not by name.
class ServiceSchema {
  /// Service type identifier (e.g., "weather.v1").
  final String serviceType;

  /// Human-readable title.
  final String title;

  /// Ordered list of fields.
  final List<SchemaField> fields;

  /// Ordered list of actions.
  final List<SchemaAction> actions;

  const ServiceSchema({
    required this.serviceType,
    required this.title,
    this.fields = const [],
    this.actions = const [],
  });

  /// Look up a field by ID. Returns null if not found.
  SchemaField? fieldById(int id) {
    for (final f in fields) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Look up an action by ID. Returns null if not found.
  SchemaAction? actionById(int id) {
    for (final a in actions) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Total wire size estimate for the full schema.
  int get wireSize {
    // serviceTypeLen(1) + serviceType(N) + titleLen(1) + title(N) +
    // fieldCount(1) + fields + actionCount(1) + actions
    var size = 3 + serviceType.length + title.length;
    for (final f in fields) {
      size += f.wireSize;
    }
    for (final a in actions) {
      size += a.wireSize;
    }
    return size;
  }
}

/// Compact binary codec for [ServiceSchema].
///
/// Wire format:
///   serviceTypeLen(1) + serviceType(N) +
///   titleLen(1) + title(N) +
///   fieldCount(1) + [field]... +
///   actionCount(1) + [action]...
///
/// Field wire format:
///   id(1) + type(1) + nameLen(1) + name(N) +
///   unitLen(1) + unit(N) +
///   optionCount(1) + [optionLen(1) + option(N)]...
///
/// Action wire format:
///   id(1) + method(1) + nameLen(1) + name(N)
abstract final class ServiceSchemaCodec {
  /// Encode a schema to compact binary. Returns null if too large.
  static Uint8List? encode(ServiceSchema schema) {
    final builder = BytesBuilder(copy: false);

    // Service type (length-prefixed).
    final stBytes = _truncUtf8(schema.serviceType, 32);
    builder.addByte(stBytes.length);
    builder.add(stBytes);

    // Title (length-prefixed).
    final titleBytes = _truncUtf8(schema.title, 60);
    builder.addByte(titleBytes.length);
    builder.add(titleBytes);

    // Fields.
    final fieldCount = schema.fields.length.clamp(0, 16);
    builder.addByte(fieldCount);
    for (var i = 0; i < fieldCount; i++) {
      _encodeField(builder, schema.fields[i]);
    }

    // Actions.
    final actionCount = schema.actions.length.clamp(0, 8);
    builder.addByte(actionCount);
    for (var i = 0; i < actionCount; i++) {
      _encodeAction(builder, schema.actions[i]);
    }

    final bytes = Uint8List.fromList(builder.toBytes());
    // Schema must fit in max payload (may be split across requests).
    if (bytes.length > 512) return null;
    return bytes;
  }

  /// Decode a schema from compact binary. Returns null if malformed.
  static ServiceSchema? decode(Uint8List data) {
    if (data.length < 4) return null;
    var offset = 0;

    // Service type.
    final stLen = data[offset++];
    if (offset + stLen > data.length) return null;
    final serviceType = String.fromCharCodes(data, offset, offset + stLen);
    offset += stLen;

    // Title.
    if (offset >= data.length) return null;
    final titleLen = data[offset++];
    if (offset + titleLen > data.length) return null;
    final title = String.fromCharCodes(data, offset, offset + titleLen);
    offset += titleLen;

    // Fields.
    if (offset >= data.length) return null;
    final fieldCount = data[offset++];
    final fields = <SchemaField>[];
    for (var i = 0; i < fieldCount; i++) {
      final result = _decodeField(data, offset);
      if (result == null) return null;
      fields.add(result.field);
      offset = result.nextOffset;
    }

    // Actions.
    if (offset >= data.length) return null;
    final actionCount = data[offset++];
    final actions = <SchemaAction>[];
    for (var i = 0; i < actionCount; i++) {
      final result = _decodeAction(data, offset);
      if (result == null) return null;
      actions.add(result.action);
      offset = result.nextOffset;
    }

    return ServiceSchema(
      serviceType: serviceType,
      title: title,
      fields: fields,
      actions: actions,
    );
  }

  static void _encodeField(BytesBuilder builder, SchemaField field) {
    builder.addByte(field.id & 0xFF);
    builder.addByte(field.type.code);

    final nameBytes = _truncUtf8(field.name, 32);
    builder.addByte(nameBytes.length);
    builder.add(nameBytes);

    final unitBytes = _truncUtf8(field.unit, 8);
    builder.addByte(unitBytes.length);
    builder.add(unitBytes);

    final optCount = field.options.length.clamp(0, 16);
    builder.addByte(optCount);
    for (var i = 0; i < optCount; i++) {
      final optBytes = _truncUtf8(field.options[i], 32);
      builder.addByte(optBytes.length);
      builder.add(optBytes);
    }
  }

  static void _encodeAction(BytesBuilder builder, SchemaAction action) {
    builder.addByte(action.id & 0xFF);
    builder.addByte(action.method.code);

    final nameBytes = _truncUtf8(action.name, 32);
    builder.addByte(nameBytes.length);
    builder.add(nameBytes);
  }

  static ({SchemaField field, int nextOffset})? _decodeField(
    Uint8List data,
    int offset,
  ) {
    if (offset + 3 > data.length) return null;
    final id = data[offset++];
    final typeCode = data[offset++];
    final type = SchemaFieldType.fromCode(typeCode);
    if (type == null) return null;

    final nameLen = data[offset++];
    if (offset + nameLen > data.length) return null;
    final name = String.fromCharCodes(data, offset, offset + nameLen);
    offset += nameLen;

    if (offset >= data.length) return null;
    final unitLen = data[offset++];
    if (offset + unitLen > data.length) return null;
    final unit = String.fromCharCodes(data, offset, offset + unitLen);
    offset += unitLen;

    if (offset >= data.length) return null;
    final optCount = data[offset++];
    final options = <String>[];
    for (var i = 0; i < optCount; i++) {
      if (offset >= data.length) return null;
      final optLen = data[offset++];
      if (offset + optLen > data.length) return null;
      options.add(String.fromCharCodes(data, offset, offset + optLen));
      offset += optLen;
    }

    return (
      field: SchemaField(
        id: id,
        name: name,
        type: type,
        unit: unit,
        options: options,
      ),
      nextOffset: offset,
    );
  }

  static ({SchemaAction action, int nextOffset})? _decodeAction(
    Uint8List data,
    int offset,
  ) {
    if (offset + 3 > data.length) return null;
    final id = data[offset++];
    final methodCode = data[offset++];
    final method = SchemaActionMethod.fromCode(methodCode);
    if (method == null) return null;

    final nameLen = data[offset++];
    if (offset + nameLen > data.length) return null;
    final name = String.fromCharCodes(data, offset, offset + nameLen);
    offset += nameLen;

    return (
      action: SchemaAction(id: id, name: name, method: method),
      nextOffset: offset,
    );
  }

  static Uint8List _truncUtf8(String text, int maxBytes) {
    var encoded = Uint8List.fromList(text.codeUnits);
    if (encoded.length > maxBytes) {
      encoded = Uint8List.sublistView(encoded, 0, maxBytes);
    }
    return encoded;
  }
}
