// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Canonical mesh service types plus optional presets.
///
/// The canonical type is the real persisted capability. Presets are optional
/// creation-time flavor metadata used for iconography, starter content, and
/// display polish.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../utils/text_sanitizer.dart';

/// The real capability a mesh service instance provides.
enum MeshServiceType {
  feed(0),
  list(1),
  poll(2),
  signal(3),
  sensor(4);

  const MeshServiceType(this.code);

  final int code;

  static MeshServiceType? fromCode(int code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return null;
  }
}

/// Optional creation preset layered over a canonical service type.
enum MeshServicePresetId {
  bulletinBoard(0),
  trailConditions(1),
  lostAndFound(2),
  sharedChecklist(3),
  resourceList(4),
  taskBoard(5),
  weatherStation(6),
  sensorNode(7);

  const MeshServicePresetId(this.code);

  final int code;

  static MeshServicePresetId? fromCode(int code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return null;
  }
}

/// Canonical service-type metadata.
class MeshServiceTypeDefinition {
  final MeshServiceType type;
  final IconData icon;
  final Color accentColor;
  final int defaultTtlMinutes;
  final int maxTtlMinutes;
  final int maxTitleLength;
  final int maxDescriptionLength;
  final bool isPublic;

  const MeshServiceTypeDefinition({
    required this.type,
    required this.icon,
    required this.accentColor,
    required this.defaultTtlMinutes,
    required this.maxTtlMinutes,
    this.maxTitleLength = 60,
    this.maxDescriptionLength = 140,
    this.isPublic = true,
  });
}

/// Optional preset metadata layered on top of a canonical type.
class MeshServicePreset {
  final MeshServicePresetId id;
  final MeshServiceType canonicalType;
  final IconData icon;
  final Color accentColor;
  final int defaultTtlMinutes;
  final int maxTtlMinutes;
  final int maxTitleLength;
  final int maxDescriptionLength;
  final bool isPublic;

  const MeshServicePreset({
    required this.id,
    required this.canonicalType,
    required this.icon,
    required this.accentColor,
    required this.defaultTtlMinutes,
    required this.maxTtlMinutes,
    this.maxTitleLength = 60,
    this.maxDescriptionLength = 140,
    this.isPublic = true,
  });
}

/// Fully-resolved metadata for a canonical type with an optional preset.
class MeshServiceResolvedDefinition {
  final MeshServiceType canonicalType;
  final MeshServicePresetId? presetId;
  final IconData icon;
  final Color accentColor;
  final int defaultTtlMinutes;
  final int maxTtlMinutes;
  final int maxTitleLength;
  final int maxDescriptionLength;
  final bool isPublic;

  const MeshServiceResolvedDefinition({
    required this.canonicalType,
    required this.presetId,
    required this.icon,
    required this.accentColor,
    required this.defaultTtlMinutes,
    required this.maxTtlMinutes,
    required this.maxTitleLength,
    required this.maxDescriptionLength,
    required this.isPublic,
  });
}

/// Legacy template normalization result.
class MeshServiceLegacyNormalization {
  final MeshServiceType canonicalType;
  final MeshServicePresetId? presetId;

  const MeshServiceLegacyNormalization({
    required this.canonicalType,
    required this.presetId,
  });
}

/// Structured advert metadata for user-created mesh services.
class MeshServiceAdvertMetadata {
  static const int _magicS = 0x53;
  static const int _magicM = 0x4D;
  static const int _version = 1;
  static const int noPresetCode = 0xFF;

  final MeshServiceType? canonicalType;
  final MeshServicePresetId? presetId;
  final String title;

  const MeshServiceAdvertMetadata({
    required this.title,
    this.canonicalType,
    this.presetId,
  });

  bool get isStructured => canonicalType != null;

  static Uint8List encode({
    required MeshServiceType canonicalType,
    required MeshServicePresetId? presetId,
    required String title,
  }) {
    final titleBytes = utf8.encode(title);
    return Uint8List.fromList([
      _magicS,
      _magicM,
      _version,
      canonicalType.code,
      presetId?.code ?? noPresetCode,
      ...titleBytes,
    ]);
  }

  static MeshServiceAdvertMetadata decode(Uint8List metadata) {
    if (metadata.length >= 5 &&
        metadata[0] == _magicS &&
        metadata[1] == _magicM &&
        metadata[2] == _version) {
      final canonicalType = MeshServiceType.fromCode(metadata[3]);
      final presetCode = metadata[4];
      final presetId = presetCode == noPresetCode
          ? null
          : MeshServicePresetId.fromCode(presetCode);
      final title = metadata.length > 5
          ? sanitizeExternalText(
              utf8.decode(metadata.sublist(5), allowMalformed: true),
            )
          : '';
      return MeshServiceAdvertMetadata(
        canonicalType: canonicalType,
        presetId: presetId,
        title: title,
      );
    }

    return MeshServiceAdvertMetadata(
      title: sanitizeExternalText(utf8.decode(metadata, allowMalformed: true)),
    );
  }
}

/// Canonical service catalog.
abstract final class MeshServiceCatalog {
  static const feed = MeshServiceTypeDefinition(
    type: MeshServiceType.feed,
    icon: Icons.dashboard_outlined,
    accentColor: AccentColors.cyan,
    defaultTtlMinutes: 60,
    maxTtlMinutes: 1440, // 24h
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const list = MeshServiceTypeDefinition(
    type: MeshServiceType.list,
    icon: Icons.checklist_outlined,
    accentColor: AccentColors.orange,
    defaultTtlMinutes: 120,
    maxTtlMinutes: 1440,
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const poll = MeshServiceTypeDefinition(
    type: MeshServiceType.poll,
    icon: Icons.poll_outlined,
    accentColor: AccentColors.purple,
    defaultTtlMinutes: 60,
    maxTtlMinutes: 1440,
    maxTitleLength: 60,
    maxDescriptionLength: 100,
  );

  static const signal = MeshServiceTypeDefinition(
    type: MeshServiceType.signal,
    icon: Icons.cell_tower_outlined,
    accentColor: AccentColors.emerald,
    defaultTtlMinutes: 15,
    maxTtlMinutes: 30,
    maxTitleLength: 40,
    maxDescriptionLength: 80,
  );

  static const sensor = MeshServiceTypeDefinition(
    type: MeshServiceType.sensor,
    icon: Icons.speed_outlined,
    accentColor: AccentColors.teal,
    defaultTtlMinutes: 1440,
    maxTtlMinutes: 4320,
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const bulletinBoard = MeshServicePreset(
    id: MeshServicePresetId.bulletinBoard,
    canonicalType: MeshServiceType.feed,
    icon: Icons.dashboard_outlined,
    accentColor: AccentColors.cyan,
    defaultTtlMinutes: 60,
    maxTtlMinutes: 1440,
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const trailConditions = MeshServicePreset(
    id: MeshServicePresetId.trailConditions,
    canonicalType: MeshServiceType.feed,
    icon: Icons.terrain_outlined,
    accentColor: AccentColors.emerald,
    defaultTtlMinutes: 240,
    maxTtlMinutes: 1440,
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const lostAndFound = MeshServicePreset(
    id: MeshServicePresetId.lostAndFound,
    canonicalType: MeshServiceType.feed,
    icon: Icons.search_outlined,
    accentColor: AccentColors.coral,
    defaultTtlMinutes: 1440,
    maxTtlMinutes: 4320,
    maxTitleLength: 40,
    maxDescriptionLength: 140,
  );

  static const sharedChecklist = MeshServicePreset(
    id: MeshServicePresetId.sharedChecklist,
    canonicalType: MeshServiceType.list,
    icon: Icons.checklist_outlined,
    accentColor: AccentColors.orange,
    defaultTtlMinutes: 120,
    maxTtlMinutes: 1440,
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const resourceList = MeshServicePreset(
    id: MeshServicePresetId.resourceList,
    canonicalType: MeshServiceType.list,
    icon: Icons.list_alt_outlined,
    accentColor: AccentColors.sky,
    defaultTtlMinutes: 120,
    maxTtlMinutes: 1440,
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const taskBoard = MeshServicePreset(
    id: MeshServicePresetId.taskBoard,
    canonicalType: MeshServiceType.list,
    icon: Icons.view_kanban_outlined,
    accentColor: AccentColors.indigo,
    defaultTtlMinutes: 120,
    maxTtlMinutes: 1440,
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const weatherStation = MeshServicePreset(
    id: MeshServicePresetId.weatherStation,
    canonicalType: MeshServiceType.sensor,
    icon: Icons.cloud_outlined,
    accentColor: AccentColors.blue,
    defaultTtlMinutes: 1440,
    maxTtlMinutes: 4320, // 72h
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const sensorNode = MeshServicePreset(
    id: MeshServicePresetId.sensorNode,
    canonicalType: MeshServiceType.sensor,
    icon: Icons.speed_outlined,
    accentColor: AccentColors.teal,
    defaultTtlMinutes: 1440,
    maxTtlMinutes: 4320,
    maxTitleLength: 40,
    maxDescriptionLength: 100,
  );

  static const allTypes = [feed, list, poll, signal, sensor];

  static const allPresets = [
    bulletinBoard,
    trailConditions,
    lostAndFound,
    sharedChecklist,
    resourceList,
    taskBoard,
    weatherStation,
    sensorNode,
  ];

  static MeshServiceTypeDefinition? typeById(MeshServiceType type) {
    for (final value in allTypes) {
      if (value.type == type) return value;
    }
    return null;
  }

  static MeshServicePreset? presetById(MeshServicePresetId id) {
    for (final value in allPresets) {
      if (value.id == id) return value;
    }
    return null;
  }

  static List<MeshServicePreset> presetsForType(MeshServiceType type) {
    return allPresets
        .where((preset) => preset.canonicalType == type)
        .toList(growable: false);
  }

  static MeshServiceResolvedDefinition resolve({
    required MeshServiceType canonicalType,
    MeshServicePresetId? presetId,
  }) {
    final typeDefinition =
        typeById(canonicalType) ??
        const MeshServiceTypeDefinition(
          type: MeshServiceType.feed,
          icon: Icons.dashboard_outlined,
          accentColor: AccentColors.cyan,
          defaultTtlMinutes: 60,
          maxTtlMinutes: 1440,
          maxTitleLength: 40,
          maxDescriptionLength: 100,
        );
    final preset = presetId == null ? null : presetById(presetId);
    final validPreset = preset?.canonicalType == canonicalType ? preset : null;

    return MeshServiceResolvedDefinition(
      canonicalType: canonicalType,
      presetId: validPreset?.id,
      icon: validPreset?.icon ?? typeDefinition.icon,
      accentColor: validPreset?.accentColor ?? typeDefinition.accentColor,
      defaultTtlMinutes:
          validPreset?.defaultTtlMinutes ?? typeDefinition.defaultTtlMinutes,
      maxTtlMinutes: validPreset?.maxTtlMinutes ?? typeDefinition.maxTtlMinutes,
      maxTitleLength:
          validPreset?.maxTitleLength ?? typeDefinition.maxTitleLength,
      maxDescriptionLength:
          validPreset?.maxDescriptionLength ??
          typeDefinition.maxDescriptionLength,
      isPublic: validPreset?.isPublic ?? typeDefinition.isPublic,
    );
  }

  static MeshServiceLegacyNormalization normalizeLegacyTemplateId(
    String? legacyTemplateId,
  ) {
    return switch (legacyTemplateId) {
      'board' => const MeshServiceLegacyNormalization(
        canonicalType: MeshServiceType.feed,
        presetId: MeshServicePresetId.bulletinBoard,
      ),
      'signal' => const MeshServiceLegacyNormalization(
        canonicalType: MeshServiceType.signal,
        presetId: null,
      ),
      'poll' => const MeshServiceLegacyNormalization(
        canonicalType: MeshServiceType.poll,
        presetId: null,
      ),
      'checklist' => const MeshServiceLegacyNormalization(
        canonicalType: MeshServiceType.list,
        presetId: MeshServicePresetId.sharedChecklist,
      ),
      'resourceList' => const MeshServiceLegacyNormalization(
        canonicalType: MeshServiceType.list,
        presetId: MeshServicePresetId.resourceList,
      ),
      'weatherStation' => const MeshServiceLegacyNormalization(
        canonicalType: MeshServiceType.sensor,
        presetId: MeshServicePresetId.weatherStation,
      ),
      'sensorNode' => const MeshServiceLegacyNormalization(
        canonicalType: MeshServiceType.sensor,
        presetId: MeshServicePresetId.sensorNode,
      ),
      'taskBoard' => const MeshServiceLegacyNormalization(
        canonicalType: MeshServiceType.list,
        presetId: MeshServicePresetId.taskBoard,
      ),
      'trailConditions' => const MeshServiceLegacyNormalization(
        canonicalType: MeshServiceType.feed,
        presetId: MeshServicePresetId.trailConditions,
      ),
      'lostAndFound' => const MeshServiceLegacyNormalization(
        canonicalType: MeshServiceType.feed,
        presetId: MeshServicePresetId.lostAndFound,
      ),
      _ => const MeshServiceLegacyNormalization(
        canonicalType: MeshServiceType.feed,
        presetId: MeshServicePresetId.bulletinBoard,
      ),
    };
  }
}
