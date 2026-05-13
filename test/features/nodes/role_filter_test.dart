// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/nodes/role_filter.dart';
import 'package:socialmesh/models/mesh_models.dart';

/// Behavioural tests for the Sprint 3 shared role filter helpers.
///
/// The helpers operate on raw [MeshNode] iterables so they can power
/// both the Nodes tab and Messages > Contacts without dragging the
/// chip widget into either screen's test setup.
MeshNode _node(int n, {String? role}) =>
    MeshNode(nodeNum: n, longName: 'node-$n', role: role);

void main() {
  group('distinctRolesIn', () {
    test('always includes the All sentinel', () {
      expect(distinctRolesIn(const <MeshNode>[]), {roleFilterAll});
    });

    test('collects every concrete role present', () {
      final nodes = [
        _node(1, role: 'CLIENT'),
        _node(2, role: 'ROUTER'),
        _node(3, role: 'CLIENT'),
        _node(4, role: 'TRACKER'),
      ];
      expect(distinctRolesIn(nodes), {
        roleFilterAll,
        'CLIENT',
        'ROUTER',
        'TRACKER',
      });
    });

    test('skips null / empty role strings', () {
      final nodes = [_node(1), _node(2, role: ''), _node(3, role: 'CLIENT')];
      expect(distinctRolesIn(nodes), {roleFilterAll, 'CLIENT'});
    });
  });

  group('countNodesByRole', () {
    test('all-bucket counts every node, including role-less ones', () {
      final nodes = [
        _node(1, role: 'CLIENT'),
        _node(2),
        _node(3, role: 'ROUTER'),
        _node(4, role: 'CLIENT'),
      ];
      final counts = countNodesByRole(nodes);
      expect(counts[roleFilterAll], 4);
      expect(counts['CLIENT'], 2);
      expect(counts['ROUTER'], 1);
      // Role-less nodes are not bucketed by role.
      expect(counts.containsKey(''), false);
      expect(counts.containsKey(null), false);
    });

    test('empty input yields a zero all-bucket and no role buckets', () {
      final counts = countNodesByRole(const <MeshNode>[]);
      expect(counts[roleFilterAll], 0);
      expect(counts.length, 1);
    });
  });

  group('applyRoleFilter', () {
    test('roleFilterAll passes through unchanged', () {
      final nodes = [_node(1, role: 'CLIENT'), _node(2, role: 'ROUTER')];
      expect(applyRoleFilter(nodes, roleFilterAll).toList(), nodes);
    });

    test('concrete role filters strictly', () {
      final nodes = [
        _node(1, role: 'CLIENT'),
        _node(2, role: 'ROUTER'),
        _node(3, role: 'CLIENT'),
        _node(4),
      ];
      final filtered = applyRoleFilter(nodes, 'CLIENT').toList();
      expect(filtered.map((n) => n.nodeNum), [1, 3]);
    });

    test('role-less nodes never match a concrete filter', () {
      final nodes = [_node(1), _node(2, role: '')];
      expect(applyRoleFilter(nodes, 'CLIENT').toList(), isEmpty);
      // But they DO surface under the all sentinel.
      expect(applyRoleFilter(nodes, roleFilterAll).toList(), nodes);
    });
  });

  group('helper invariants protect against drift', () {
    test('roleFilterAll sentinel is not a valid protobuf role name', () {
      // The sentinel must not collide with any real Meshtastic role
      // string. Concrete role names are SCREAMING_SNAKE_CASE protobuf
      // names; the sentinel is intentionally bracketed by underscores
      // so it can never match a future role.
      expect(roleFilterAll.startsWith('_'), true);
      expect(roleFilterAll.endsWith('_'), true);
      expect(roleFilterAll.toUpperCase(), isNot(equals(roleFilterAll)));
    });
  });
}
