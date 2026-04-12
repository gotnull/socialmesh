// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_template.dart';

void main() {
  group('MeshServiceCatalog', () {
    test('allTypes contains exactly 5 canonical service types', () {
      expect(MeshServiceCatalog.allTypes.length, 5);
    });

    test('all canonical type IDs are unique', () {
      final ids = MeshServiceCatalog.allTypes.map((t) => t.type).toSet();
      expect(ids.length, MeshServiceCatalog.allTypes.length);
    });

    test('all preset IDs are unique', () {
      final ids = MeshServiceCatalog.allPresets.map((p) => p.id).toSet();
      expect(ids.length, MeshServiceCatalog.allPresets.length);
    });

    test('feed type has expected defaults', () {
      final t = MeshServiceCatalog.feed;
      expect(t.type, MeshServiceType.feed);
      expect(t.icon, Icons.dashboard_outlined);
      expect(t.defaultTtlMinutes, 60);
      expect(t.maxTtlMinutes, 1440);
      expect(t.isPublic, isTrue);
    });

    test('signal type has expected defaults', () {
      final t = MeshServiceCatalog.signal;
      expect(t.type, MeshServiceType.signal);
      expect(t.defaultTtlMinutes, 15);
      expect(t.maxTtlMinutes, 30);
    });

    test('poll type has expected defaults', () {
      final t = MeshServiceCatalog.poll;
      expect(t.type, MeshServiceType.poll);
      expect(t.defaultTtlMinutes, 60);
    });

    test('presetsForType filters presets by canonical type', () {
      final listPresets = MeshServiceCatalog.presetsForType(
        MeshServiceType.list,
      );
      expect(
        listPresets.map((p) => p.id),
        containsAll(<MeshServicePresetId>[
          MeshServicePresetId.sharedChecklist,
          MeshServicePresetId.resourceList,
          MeshServicePresetId.taskBoard,
        ]),
      );
      expect(
        listPresets.every(
          (preset) => preset.canonicalType == MeshServiceType.list,
        ),
        isTrue,
      );
    });

    test('resolve applies preset overrides when compatible', () {
      final resolved = MeshServiceCatalog.resolve(
        canonicalType: MeshServiceType.feed,
        presetId: MeshServicePresetId.trailConditions,
      );

      expect(resolved.canonicalType, MeshServiceType.feed);
      expect(resolved.presetId, MeshServicePresetId.trailConditions);
      expect(resolved.icon, Icons.terrain_outlined);
      expect(resolved.defaultTtlMinutes, 240);
    });

    test('resolve ignores incompatible preset IDs', () {
      final resolved = MeshServiceCatalog.resolve(
        canonicalType: MeshServiceType.signal,
        presetId: MeshServicePresetId.taskBoard,
      );

      expect(resolved.canonicalType, MeshServiceType.signal);
      expect(resolved.presetId, isNull);
      expect(resolved.icon, MeshServiceCatalog.signal.icon);
    });

    test('all canonical types have positive TTLs', () {
      for (final t in MeshServiceCatalog.allTypes) {
        expect(t.defaultTtlMinutes, greaterThan(0));
        expect(t.maxTtlMinutes, greaterThanOrEqualTo(t.defaultTtlMinutes));
      }
    });

    test('all canonical types have positive max lengths', () {
      for (final t in MeshServiceCatalog.allTypes) {
        expect(t.maxTitleLength, greaterThan(0));
        expect(t.maxDescriptionLength, greaterThan(0));
      }
    });

    test('legacy board template normalizes to feed bulletin board', () {
      final normalized = MeshServiceCatalog.normalizeLegacyTemplateId('board');
      expect(normalized.canonicalType, MeshServiceType.feed);
      expect(normalized.presetId, MeshServicePresetId.bulletinBoard);
    });

    test('legacy checklist template normalizes to list shared checklist', () {
      final normalized = MeshServiceCatalog.normalizeLegacyTemplateId(
        'checklist',
      );
      expect(normalized.canonicalType, MeshServiceType.list);
      expect(normalized.presetId, MeshServicePresetId.sharedChecklist);
    });
  });
}
