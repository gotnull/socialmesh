// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_instance.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_template.dart';

void main() {
  group('MeshServiceInstance', () {
    late MeshServiceInstance active;
    late MeshServiceInstance stopped;
    late MeshServiceInstance expired;

    setUp(() {
      final now = DateTime.now();
      active = MeshServiceInstance(
        instanceId: 'test-active-001',
        canonicalType: MeshServiceType.feed,
        presetId: MeshServicePresetId.bulletinBoard,
        title: 'Test Board',
        description: 'A test bulletin board',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        status: MeshServiceStatus.active,
      );

      stopped = MeshServiceInstance(
        instanceId: 'test-stopped-001',
        canonicalType: MeshServiceType.poll,
        title: 'Stopped Poll',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        status: MeshServiceStatus.stopped,
      );

      expired = MeshServiceInstance(
        instanceId: 'test-expired-001',
        canonicalType: MeshServiceType.signal,
        title: 'Expired Signal',
        createdAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.subtract(const Duration(hours: 1)),
        status: MeshServiceStatus.active,
      );
    });

    test('isExpired returns false for future expiry', () {
      expect(active.isExpired, isFalse);
    });

    test('isExpired returns true for past expiry', () {
      expect(expired.isExpired, isTrue);
    });

    test('isActive returns true for active non-expired', () {
      expect(active.isActive, isTrue);
    });

    test('isActive returns false for stopped', () {
      expect(stopped.isActive, isFalse);
    });

    test('isActive returns false for expired', () {
      expect(expired.isActive, isFalse);
    });

    test('effectiveStatus returns stopped for stopped', () {
      expect(stopped.effectiveStatus, MeshServiceStatus.stopped);
    });

    test('effectiveStatus returns expired for past expiry', () {
      expect(expired.effectiveStatus, MeshServiceStatus.expired);
    });

    test('effectiveStatus returns active for active non-expired', () {
      expect(active.effectiveStatus, MeshServiceStatus.active);
    });

    test('remainingDuration is positive for active instance', () {
      expect(active.remainingDuration, isNotNull);
      expect(active.remainingDuration!.inMinutes, greaterThan(0));
    });

    test('remainingDuration is zero for expired instance', () {
      expect(expired.remainingDuration, Duration.zero);
    });

    test('no expiry returns null for isExpired-related props', () {
      final noExpiry = MeshServiceInstance(
        instanceId: 'test-no-expiry',
        canonicalType: MeshServiceType.feed,
        presetId: MeshServicePresetId.bulletinBoard,
        title: 'No Expiry',
        createdAt: DateTime.now(),
      );
      expect(noExpiry.isExpired, isFalse);
      expect(noExpiry.remainingDuration, isNull);
    });

    test('copyWith preserves immutability', () {
      final updated = active.copyWith(title: 'Updated Title');
      expect(updated.title, 'Updated Title');
      expect(updated.instanceId, active.instanceId);
      expect(updated.canonicalType, active.canonicalType);
      expect(updated.presetId, active.presetId);
      expect(active.title, 'Test Board'); // Original unchanged.
    });

    test('copyWith can change status', () {
      final stopped = active.copyWith(status: MeshServiceStatus.stopped);
      expect(stopped.status, MeshServiceStatus.stopped);
      expect(stopped.isActive, isFalse);
    });

    group('SQLite serialization', () {
      test('roundtrip preserves all fields', () {
        final instance = MeshServiceInstance(
          instanceId: 'ser-roundtrip',
          canonicalType: MeshServiceType.poll,
          title: 'Poll Test',
          description: 'A poll',
          createdAt: DateTime(2025, 6, 1, 12, 0),
          expiresAt: DateTime(2025, 6, 1, 13, 0),
          status: MeshServiceStatus.active,
          config: {
            'options': ['A', 'B', 'C'],
          },
        );

        final map = instance.toMap();
        final restored = MeshServiceInstance.fromMap(map);

        expect(restored.instanceId, instance.instanceId);
        expect(restored.canonicalType, instance.canonicalType);
        expect(restored.presetId, instance.presetId);
        expect(restored.title, instance.title);
        expect(restored.description, instance.description);
        expect(
          restored.createdAt.millisecondsSinceEpoch,
          instance.createdAt.millisecondsSinceEpoch,
        );
        expect(
          restored.expiresAt?.millisecondsSinceEpoch,
          instance.expiresAt?.millisecondsSinceEpoch,
        );
        expect(restored.status, instance.status);
        expect(restored.config['options'], ['A', 'B', 'C']);
        expect(restored.isLocal, isTrue);
      });

      test('toMap encodes config as JSON string', () {
        final instance = MeshServiceInstance(
          instanceId: 'json-test',
          canonicalType: MeshServiceType.list,
          presetId: MeshServicePresetId.sharedChecklist,
          title: 'Checklist',
          createdAt: DateTime(2025),
          config: {
            'items': ['item1', 'item2'],
          },
        );
        final map = instance.toMap();
        expect(map['config'], isA<String>());
        expect(map['config'] as String, contains('item1'));
      });

      test('fromMap handles null expires_at', () {
        final map = {
          'instance_id': 'null-exp',
          'canonical_type': 'feed',
          'preset_id': 'bulletinBoard',
          'title': 'No Expiry',
          'description': '',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'expires_at': null,
          'status': 'active',
          'config': '{}',
          'is_local': 1,
        };

        final instance = MeshServiceInstance.fromMap(map);
        expect(instance.expiresAt, isNull);
        expect(instance.isExpired, isFalse);
      });

      test('fromMap normalizes legacy template_id values', () {
        final map = {
          'instance_id': 'legacy-checklist',
          'template_id': 'checklist',
          'title': 'Checklist',
          'description': '',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'expires_at': null,
          'status': 'active',
          'config': '{}',
          'is_local': 1,
        };

        final instance = MeshServiceInstance.fromMap(map);
        expect(instance.canonicalType, MeshServiceType.list);
        expect(instance.presetId, MeshServicePresetId.sharedChecklist);
      });

      test('fromMap handles unknown template_id with fallback', () {
        final map = {
          'instance_id': 'unknown-tmpl',
          'template_id': 'nonexistent',
          'title': 'Unknown',
          'description': '',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'expires_at': null,
          'status': 'active',
          'config': '{}',
          'is_local': 1,
        };

        final instance = MeshServiceInstance.fromMap(map);
        expect(instance.canonicalType, MeshServiceType.feed);
        expect(instance.presetId, MeshServicePresetId.bulletinBoard);
      });
    });
  });
}
