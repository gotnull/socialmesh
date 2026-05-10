// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/operations/domain/operation_catalog.dart';
import 'package:socialmesh/features/operations/models/operation_models.dart';

void main() {
  group('Operations catalog', () {
    final catalog = buildOperationCatalog();
    final byId = {for (final d in catalog) d.id: d};

    test('every catalog id appears in OperationIds', () {
      final knownIds = {
        OperationIds.firstContact,
        OperationIds.signalHunter,
        OperationIds.pathfinder,
        OperationIds.longRangeObserver,
        OperationIds.nightWatch,
        OperationIds.multiHopObserver,
        OperationIds.mapCoverage,
      };
      for (final def in catalog) {
        expect(
          knownIds,
          contains(def.id),
          reason: 'Catalog id ${def.id} missing from OperationIds.',
        );
      }
    });

    test('v1 enabled operations are exactly first_contact + signal_hunter + '
        'pathfinder', () {
      final enabled = catalog.where((d) => d.enabled).map((d) => d.id).toSet();
      expect(enabled, {
        OperationIds.firstContact,
        OperationIds.signalHunter,
        OperationIds.pathfinder,
      });
    });

    test('deferred operations are present and disabled', () {
      for (final id in [
        OperationIds.longRangeObserver,
        OperationIds.nightWatch,
        OperationIds.multiHopObserver,
        OperationIds.mapCoverage,
      ]) {
        final def = byId[id];
        expect(def, isNotNull, reason: 'Missing deferred operation $id');
        expect(
          def!.enabled,
          isFalse,
          reason: 'Deferred operation $id should not be enabled in v1.',
        );
      }
    });

    test('every operation has at least one objective with target > 0', () {
      for (final def in catalog) {
        expect(
          def.objectives,
          isNotEmpty,
          reason: '${def.id} has no objectives',
        );
        for (final o in def.objectives) {
          expect(
            o.target,
            greaterThan(0),
            reason: '${def.id}.${o.id} has non-positive target',
          );
        }
      }
    });

    test('objective ids are unique within each operation', () {
      for (final def in catalog) {
        final ids = def.objectives.map((o) => o.id).toList();
        expect(
          ids.toSet().length,
          ids.length,
          reason: '${def.id} has duplicate objective ids',
        );
      }
    });

    test('FIRST_CONTACT and SIGNAL_HUNTER target the right counts', () {
      expect(byId[OperationIds.firstContact]!.objectives.first.target, 1);
      expect(byId[OperationIds.signalHunter]!.objectives.first.target, 10);
    });

    test('PATHFINDER objective is a tracerouteSuccess', () {
      expect(
        byId[OperationIds.pathfinder]!.objectives.first.kind,
        OperationObjectiveKind.tracerouteSuccess,
      );
    });
  });
}
