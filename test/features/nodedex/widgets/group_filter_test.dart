// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/models/node_group.dart';
import 'package:socialmesh/features/nodedex/widgets/group_filter.dart';

NodeGroup _group(String id) => NodeGroup(
  id: id,
  name: id,
  colorValue: 0xFF000000,
  iconKey: 'star',
  createdAtMs: 0,
  updatedAtMs: 0,
);

void main() {
  group('matchesGroupFilter', () {
    const membership = <int, Set<String>>{
      1: {'g1'},
      2: {'g1', 'g2'},
      3: {'g2'},
    };

    test('the all sentinel passes every node through', () {
      expect(matchesGroupFilter(membership, 1, groupFilterAll), isTrue);
      expect(matchesGroupFilter(membership, 999, groupFilterAll), isTrue);
    });

    test('passes only members of the selected group', () {
      expect(matchesGroupFilter(membership, 1, 'g1'), isTrue);
      expect(matchesGroupFilter(membership, 3, 'g1'), isFalse);
      expect(matchesGroupFilter(membership, 2, 'g2'), isTrue);
    });

    test('a node with no membership entry never matches a group', () {
      expect(matchesGroupFilter(membership, 42, 'g1'), isFalse);
    });
  });

  group('resolveGroupFilter', () {
    final groups = [_group('g1'), _group('g2')];

    test('keeps the all sentinel', () {
      expect(resolveGroupFilter(groupFilterAll, groups), groupFilterAll);
    });

    test('keeps a selection that still exists', () {
      expect(resolveGroupFilter('g2', groups), 'g2');
    });

    // Regression: deleting the selected group from the Manage screen left a
    // stale id that matched no node, so the list read as empty until the
    // screen was rebuilt. The selection must fall back to the all sentinel.
    test('falls back to all when the selected group was deleted', () {
      expect(resolveGroupFilter('g1', const <NodeGroup>[]), groupFilterAll);
      expect(resolveGroupFilter('g1', [_group('g2')]), groupFilterAll);
    });
  });
}
