// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Built-in schema definitions for each service template.
///
/// Every template maps to a default [ServiceSchema] that the generic
/// renderer can use. Unknown services also expose schemas via MRRP,
/// which peers cache and render dynamically.
library;

import 'service_schema.dart';
import 'mesh_service_template.dart';

/// Built-in schema definitions for each template type.
abstract final class TemplateSchemas {
  /// Board: bulletin posts.
  static const board = ServiceSchema(
    serviceType: 'board.v1', // lint-allow: hardcoded-string
    title: 'Bulletin Board', // lint-allow: hardcoded-string
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
        name: 'Post Message',
        method: SchemaActionMethod.write,
      ), // lint-allow: hardcoded-string
      SchemaAction(
        id: 3,
        name: 'Delete Post',
        method: SchemaActionMethod.delete,
      ), // lint-allow: hardcoded-string
    ],
  );

  /// Signal: anonymous ephemeral status.
  static const signal = ServiceSchema(
    serviceType: 'signal.v1', // lint-allow: hardcoded-string
    title: 'Signal', // lint-allow: hardcoded-string
    fields: [
      SchemaField(
        id: 1,
        name: 'Signal Type',
        type: SchemaFieldType.choice,
        options: [
          // lint-allow: hardcoded-string
          'Mesh Testing',
          'Available to Chat',
          'Need Help', // lint-allow: hardcoded-string
          'Group Leaving Soon',
          'Coffee Break',
          'Field Exercise', // lint-allow: hardcoded-string
          'Network Relay Active',
          'Emergency Comms', // lint-allow: hardcoded-string
        ],
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

  /// Poll: voting.
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

  /// Checklist: collaborative task list.
  static const checklist = ServiceSchema(
    serviceType: 'checklist.v1', // lint-allow: hardcoded-string
    title: 'Checklist', // lint-allow: hardcoded-string
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

  /// Resource list: shared resource inventory.
  static const resourceList = ServiceSchema(
    serviceType: 'resource_list.v1', // lint-allow: hardcoded-string
    title: 'Resource List', // lint-allow: hardcoded-string
    fields: [
      SchemaField(
        id: 1,
        name: 'Resources',
        type: SchemaFieldType.list,
      ), // lint-allow: hardcoded-string
    ],
    actions: [
      SchemaAction(
        id: 1,
        name: 'List Resources',
        method: SchemaActionMethod.read,
      ), // lint-allow: hardcoded-string
    ],
  );

  /// Weather station: environmental readings.
  static const weatherStation = ServiceSchema(
    serviceType: 'weather.v1', // lint-allow: hardcoded-string
    title: 'Weather Station', // lint-allow: hardcoded-string
    fields: [
      SchemaField(
        id: 1,
        name: 'Temperature',
        type: SchemaFieldType.number,
        unit: '\u00B0C',
      ), // lint-allow: hardcoded-string
      SchemaField(
        id: 2,
        name: 'Humidity',
        type: SchemaFieldType.number,
        unit: '%',
      ), // lint-allow: hardcoded-string
      SchemaField(
        id: 3,
        name: 'Pressure',
        type: SchemaFieldType.number,
        unit: 'hPa',
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

  /// Sensor node: generic sensor readings.
  static const sensorNode = ServiceSchema(
    serviceType: 'sensor.v1', // lint-allow: hardcoded-string
    title: 'Sensor Node', // lint-allow: hardcoded-string
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

  /// Task board: team task management.
  static const taskBoard = ServiceSchema(
    serviceType: 'taskboard.v1', // lint-allow: hardcoded-string
    title: 'Task Board', // lint-allow: hardcoded-string
    fields: [
      SchemaField(
        id: 1,
        name: 'Tasks',
        type: SchemaFieldType.list,
      ), // lint-allow: hardcoded-string
      SchemaField(
        id: 2,
        name: 'In Progress',
        type: SchemaFieldType.number,
      ), // lint-allow: hardcoded-string
      SchemaField(
        id: 3,
        name: 'Completed',
        type: SchemaFieldType.number,
      ), // lint-allow: hardcoded-string
    ],
    actions: [
      SchemaAction(
        id: 1,
        name: 'List Tasks',
        method: SchemaActionMethod.read,
      ), // lint-allow: hardcoded-string
      SchemaAction(
        id: 2,
        name: 'Add Task',
        method: SchemaActionMethod.write,
      ), // lint-allow: hardcoded-string
      SchemaAction(
        id: 3,
        name: 'Update Task',
        method: SchemaActionMethod.write,
      ), // lint-allow: hardcoded-string
    ],
  );

  /// Trail conditions: hiking/outdoor trail status.
  static const trailConditions = ServiceSchema(
    serviceType: 'trail.v1', // lint-allow: hardcoded-string
    title: 'Trail Conditions', // lint-allow: hardcoded-string
    fields: [
      SchemaField(
        id: 1,
        name: 'Condition',
        type: SchemaFieldType.choice,
        options: [
          // lint-allow: hardcoded-string
          'Clear',
          'Muddy',
          'Snowy',
          'Icy',
          'Flooded',
          'Blocked', // lint-allow: hardcoded-string
        ],
      ),
      SchemaField(
        id: 2,
        name: 'Notes',
        type: SchemaFieldType.text,
      ), // lint-allow: hardcoded-string
      SchemaField(
        id: 3,
        name: 'Last Report',
        type: SchemaFieldType.timestamp,
      ), // lint-allow: hardcoded-string
    ],
    actions: [
      SchemaAction(
        id: 1,
        name: 'Get Conditions',
        method: SchemaActionMethod.read,
      ), // lint-allow: hardcoded-string
      SchemaAction(
        id: 2,
        name: 'Report',
        method: SchemaActionMethod.write,
      ), // lint-allow: hardcoded-string
    ],
  );

  /// Lost & found: item tracking.
  static const lostAndFound = ServiceSchema(
    serviceType: 'lostandfound.v1', // lint-allow: hardcoded-string
    title: 'Lost & Found', // lint-allow: hardcoded-string
    fields: [
      SchemaField(
        id: 1,
        name: 'Items',
        type: SchemaFieldType.list,
      ), // lint-allow: hardcoded-string
      SchemaField(
        id: 2,
        name: 'Status',
        type: SchemaFieldType.choice,
        options: [
          // lint-allow: hardcoded-string
          'Lost', 'Found', 'Claimed', // lint-allow: hardcoded-string
        ],
      ),
    ],
    actions: [
      SchemaAction(
        id: 1,
        name: 'List Items',
        method: SchemaActionMethod.read,
      ), // lint-allow: hardcoded-string
      SchemaAction(
        id: 2,
        name: 'Report Item',
        method: SchemaActionMethod.write,
      ), // lint-allow: hardcoded-string
    ],
  );

  /// Look up the default schema for a template type.
  static ServiceSchema? forTemplate(MeshServiceTemplateId templateId) {
    return switch (templateId) {
      MeshServiceTemplateId.board => board,
      MeshServiceTemplateId.signal => signal,
      MeshServiceTemplateId.poll => poll,
      MeshServiceTemplateId.checklist => checklist,
      MeshServiceTemplateId.resourceList => resourceList,
      MeshServiceTemplateId.weatherStation => weatherStation,
      MeshServiceTemplateId.sensorNode => sensorNode,
      MeshServiceTemplateId.taskBoard => taskBoard,
      MeshServiceTemplateId.trailConditions => trailConditions,
      MeshServiceTemplateId.lostAndFound => lostAndFound,
    };
  }
}
