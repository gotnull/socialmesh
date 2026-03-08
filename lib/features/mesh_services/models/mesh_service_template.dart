// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Built-in mesh service templates.
///
/// Templates are developer-defined types. Users create instances from
/// these templates — they never author arbitrary protocol behavior.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Identifies a built-in service template.
enum MeshServiceTemplateId {
  board,
  signal,
  poll,
  checklist,
  resourceList,
  weatherStation,
  sensorNode,
  taskBoard,
  trailConditions,
  lostAndFound,
}

/// A built-in service template definition.
///
/// Immutable. Created in code, never by users.
class MeshServiceTemplate {
  /// Template identifier.
  final MeshServiceTemplateId id;

  /// The MRRP service ID this template maps to (e.g., board.v1 = 0x00000003).
  /// Null for templates that use a shared instance service ID.
  final int? mrrpServiceId;

  /// Icon for the template picker.
  final IconData icon;

  /// Accent color for this template's UI surfaces.
  final Color accentColor;

  /// Default TTL in minutes for instances of this template.
  final int defaultTtlMinutes;

  /// Maximum TTL in minutes.
  final int maxTtlMinutes;

  /// Maximum title length in characters.
  final int maxTitleLength;

  /// Maximum description length in characters.
  final int maxDescriptionLength;

  /// Whether this template produces public (no handshake) services.
  final bool isPublic;

  const MeshServiceTemplate({
    required this.id,
    this.mrrpServiceId,
    required this.icon,
    required this.accentColor,
    required this.defaultTtlMinutes,
    required this.maxTtlMinutes,
    this.maxTitleLength = 60,
    this.maxDescriptionLength = 140,
    this.isPublic = true,
  });
}

/// The catalog of all built-in templates.
///
/// This is the single source of truth for what users can create.
abstract final class MeshServiceTemplateCatalog {
  static const board = MeshServiceTemplate(
    id: MeshServiceTemplateId.board,
    mrrpServiceId: 0x00000003, // board.v1
    icon: Icons.dashboard_outlined,
    accentColor: AccentColors.cyan,
    defaultTtlMinutes: 60,
    maxTtlMinutes: 1440, // 24h
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const signal = MeshServiceTemplate(
    id: MeshServiceTemplateId.signal,
    mrrpServiceId: 0x00000004, // signal.v1
    icon: Icons.cell_tower_outlined,
    accentColor: AccentColors.emerald,
    defaultTtlMinutes: 15,
    maxTtlMinutes: 30,
    maxTitleLength: 40,
    maxDescriptionLength: 80,
  );

  static const poll = MeshServiceTemplate(
    id: MeshServiceTemplateId.poll,
    icon: Icons.poll_outlined,
    accentColor: AccentColors.purple,
    defaultTtlMinutes: 60,
    maxTtlMinutes: 1440,
    maxTitleLength: 60,
    maxDescriptionLength: 100,
  );

  static const checklist = MeshServiceTemplate(
    id: MeshServiceTemplateId.checklist,
    icon: Icons.checklist_outlined,
    accentColor: AccentColors.orange,
    defaultTtlMinutes: 120,
    maxTtlMinutes: 1440,
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const resourceList = MeshServiceTemplate(
    id: MeshServiceTemplateId.resourceList,
    icon: Icons.list_alt_outlined,
    accentColor: AccentColors.sky,
    defaultTtlMinutes: 120,
    maxTtlMinutes: 1440,
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const weatherStation = MeshServiceTemplate(
    id: MeshServiceTemplateId.weatherStation,
    icon: Icons.cloud_outlined,
    accentColor: AccentColors.blue,
    defaultTtlMinutes: 1440,
    maxTtlMinutes: 4320, // 72h
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const sensorNode = MeshServiceTemplate(
    id: MeshServiceTemplateId.sensorNode,
    icon: Icons.speed_outlined,
    accentColor: AccentColors.teal,
    defaultTtlMinutes: 1440,
    maxTtlMinutes: 4320,
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const taskBoard = MeshServiceTemplate(
    id: MeshServiceTemplateId.taskBoard,
    icon: Icons.view_kanban_outlined,
    accentColor: AccentColors.indigo,
    defaultTtlMinutes: 120,
    maxTtlMinutes: 1440,
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const trailConditions = MeshServiceTemplate(
    id: MeshServiceTemplateId.trailConditions,
    icon: Icons.terrain_outlined,
    accentColor: AccentColors.emerald,
    defaultTtlMinutes: 240,
    maxTtlMinutes: 1440,
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const lostAndFound = MeshServiceTemplate(
    id: MeshServiceTemplateId.lostAndFound,
    icon: Icons.search_outlined,
    accentColor: AccentColors.coral,
    defaultTtlMinutes: 1440,
    maxTtlMinutes: 4320,
    maxTitleLength: 40,
    maxDescriptionLength: 140,
  );

  /// All available templates in display order.
  static const all = [
    board,
    signal,
    poll,
    checklist,
    resourceList,
    weatherStation,
    sensorNode,
    taskBoard,
    trailConditions,
    lostAndFound,
  ];

  /// Look up a template by ID.
  static MeshServiceTemplate? byId(MeshServiceTemplateId id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }
}
