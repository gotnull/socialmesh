// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Built-in schema definitions for canonical mesh service types.
library;

import 'mesh_service_instance.dart';
import 'mesh_service_template.dart';
import 'service_schema.dart';

abstract final class MeshServiceSchemas {
  static const feed = ServiceSchema(
    serviceType: 'feed.v1', // lint-allow: hardcoded-string
    title: 'Feed', // lint-allow: hardcoded-string
    fields: [
      SchemaField(
        id: 1,
        name: 'Posts',
        type: SchemaFieldType.list,
      ), // lint-allow: hardcoded-string
    ],
    actions: [
      SchemaAction(
        id: 1,
        name: 'List Posts',
        method: SchemaActionMethod.read,
      ), // lint-allow: hardcoded-string
      SchemaAction(
        id: 2,
        name: 'Post Update',
        method: SchemaActionMethod.write,
      ), // lint-allow: hardcoded-string
    ],
  );

  static const list = ServiceSchema(
    serviceType: 'list.v1', // lint-allow: hardcoded-string
    title: 'List', // lint-allow: hardcoded-string
    fields: [
      SchemaField(
        id: 1,
        name: 'Items',
        type: SchemaFieldType.list,
      ), // lint-allow: hardcoded-string
      SchemaField(
        id: 2,
        name: 'Completed',
        type: SchemaFieldType.number,
        unit: '%',
      ), // lint-allow: hardcoded-string
    ],
    actions: [
      SchemaAction(
        id: 1,
        name: 'List Items',
        method: SchemaActionMethod.read,
      ), // lint-allow: hardcoded-string
      SchemaAction(
        id: 2,
        name: 'Toggle Item',
        method: SchemaActionMethod.write,
      ), // lint-allow: hardcoded-string
      SchemaAction(
        id: 3,
        name: 'Add Item',
        method: SchemaActionMethod.write,
      ), // lint-allow: hardcoded-string
    ],
  );

  static const poll = ServiceSchema(
    serviceType: 'poll.v1', // lint-allow: hardcoded-string
    title: 'Poll', // lint-allow: hardcoded-string
    fields: [
      SchemaField(
        id: 1,
        name: 'Question',
        type: SchemaFieldType.text,
      ), // lint-allow: hardcoded-string
      SchemaField(
        id: 2,
        name: 'Options',
        type: SchemaFieldType.list,
      ), // lint-allow: hardcoded-string
      SchemaField(
        id: 3,
        name: 'Votes',
        type: SchemaFieldType.list,
      ), // lint-allow: hardcoded-string
    ],
    actions: [
      SchemaAction(
        id: 1,
        name: 'Get Poll',
        method: SchemaActionMethod.read,
      ), // lint-allow: hardcoded-string
      SchemaAction(
        id: 2,
        name: 'Vote',
        method: SchemaActionMethod.write,
      ), // lint-allow: hardcoded-string
    ],
  );

  static const signal = ServiceSchema(
    serviceType: 'signal.v1', // lint-allow: hardcoded-string
    title: 'Signal', // lint-allow: hardcoded-string
    fields: [
      SchemaField(
        id: 1,
        name: 'Signal Type',
        type: SchemaFieldType.choice,
        options: [
          'Mesh Testing',
          'Available to Chat',
          'Need Help',
          'Group Leaving Soon',
          'Coffee Break',
          'Field Exercise',
          'Network Relay Active',
          'Emergency Comms',
        ], // lint-allow: hardcoded-string
      ),
      SchemaField(
        id: 2,
        name: 'TTL',
        type: SchemaFieldType.number,
        unit: 'min',
      ), // lint-allow: hardcoded-string
    ],
    actions: [
      SchemaAction(
        id: 1,
        name: 'Broadcast',
        method: SchemaActionMethod.write,
      ), // lint-allow: hardcoded-string
      SchemaAction(
        id: 2,
        name: 'Acknowledge',
        method: SchemaActionMethod.write,
      ), // lint-allow: hardcoded-string
    ],
  );

  static const sensor = ServiceSchema(
    serviceType: 'sensor.v1', // lint-allow: hardcoded-string
    title: 'Sensor', // lint-allow: hardcoded-string
    fields: [
      SchemaField(
        id: 1,
        name: 'Reading 1',
        type: SchemaFieldType.number,
      ), // lint-allow: hardcoded-string
      SchemaField(
        id: 2,
        name: 'Reading 2',
        type: SchemaFieldType.number,
      ), // lint-allow: hardcoded-string
      SchemaField(
        id: 3,
        name: 'Status',
        type: SchemaFieldType.text,
      ), // lint-allow: hardcoded-string
      SchemaField(
        id: 4,
        name: 'Last Update',
        type: SchemaFieldType.timestamp,
      ), // lint-allow: hardcoded-string
    ],
    actions: [
      SchemaAction(
        id: 1,
        name: 'Get Latest',
        method: SchemaActionMethod.read,
      ), // lint-allow: hardcoded-string
    ],
  );

  static ServiceSchema? forType(MeshServiceType canonicalType) {
    return switch (canonicalType) {
      MeshServiceType.feed => feed,
      MeshServiceType.list => list,
      MeshServiceType.poll => poll,
      MeshServiceType.signal => signal,
      MeshServiceType.sensor => sensor,
    };
  }

  static ServiceSchema? forInstance(MeshServiceInstance instance) {
    return forType(instance.canonicalType);
  }
}
