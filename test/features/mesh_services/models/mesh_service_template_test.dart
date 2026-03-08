// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_template.dart';

void main() {
  group('MeshServiceTemplateCatalog', () {
    test('all contains exactly 10 templates', () {
      expect(MeshServiceTemplateCatalog.all.length, 10);
    });

    test('all template IDs are unique', () {
      final ids = MeshServiceTemplateCatalog.all.map((t) => t.id).toSet();
      expect(ids.length, MeshServiceTemplateCatalog.all.length);
    });

    test('board template has correct MRRP service ID', () {
      final t = MeshServiceTemplateCatalog.board;
      expect(t.id, MeshServiceTemplateId.board);
      expect(t.mrrpServiceId, 0x00000003);
      expect(t.icon, Icons.dashboard_outlined);
      expect(t.defaultTtlMinutes, 60);
      expect(t.maxTtlMinutes, 1440);
      expect(t.isPublic, isTrue);
    });

    test('signal template has correct MRRP service ID', () {
      final t = MeshServiceTemplateCatalog.signal;
      expect(t.id, MeshServiceTemplateId.signal);
      expect(t.mrrpServiceId, 0x00000004);
      expect(t.defaultTtlMinutes, 15);
      expect(t.maxTtlMinutes, 30);
    });

    test('poll template has no MRRP service ID', () {
      final t = MeshServiceTemplateCatalog.poll;
      expect(t.id, MeshServiceTemplateId.poll);
      expect(t.mrrpServiceId, isNull);
      expect(t.defaultTtlMinutes, 60);
    });

    test('checklist template has no MRRP service ID', () {
      final t = MeshServiceTemplateCatalog.checklist;
      expect(t.id, MeshServiceTemplateId.checklist);
      expect(t.mrrpServiceId, isNull);
      expect(t.defaultTtlMinutes, 120);
    });

    test('resourceList template has no MRRP service ID', () {
      final t = MeshServiceTemplateCatalog.resourceList;
      expect(t.id, MeshServiceTemplateId.resourceList);
      expect(t.mrrpServiceId, isNull);
      expect(t.defaultTtlMinutes, 120);
    });

    test('byId returns correct template', () {
      for (final t in MeshServiceTemplateCatalog.all) {
        expect(MeshServiceTemplateCatalog.byId(t.id), t);
      }
    });

    test('all templates have positive TTLs', () {
      for (final t in MeshServiceTemplateCatalog.all) {
        expect(t.defaultTtlMinutes, greaterThan(0));
        expect(t.maxTtlMinutes, greaterThanOrEqualTo(t.defaultTtlMinutes));
      }
    });

    test('all templates have positive max lengths', () {
      for (final t in MeshServiceTemplateCatalog.all) {
        expect(t.maxTitleLength, greaterThan(0));
        expect(t.maxDescriptionLength, greaterThan(0));
      }
    });
  });
}
