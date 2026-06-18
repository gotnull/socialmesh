// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/providers/node_groups_provider.dart';
import 'package:socialmesh/features/nodedex/providers/nodedex_providers.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        // Share one in-memory NodeDex database across the store providers.
        nodeDexDatabaseProvider.overrideWithValue(
          NodeDexDatabase(dbPathOverride: inMemoryDatabasePath),
        ),
      ],
    );
  }

  test('create / assign / delete through the provider', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    final initial = await container.read(nodeGroupsProvider.future);
    expect(initial.groups, isEmpty);

    final notifier = container.read(nodeGroupsProvider.notifier);
    final group = await notifier.createGroup(
      name: 'Repeaters',
      colorValue: 0xFF22C55E,
      iconKey: 'router',
    );

    var state = container.read(nodeGroupsProvider).value!;
    expect(state.groups.map((g) => g.name), ['Repeaters']);
    expect(state.groups.single.iconKey, 'router');

    await notifier.setNodeGroups(100, {group.id});
    await notifier.setNodeGroups(200, {group.id});
    state = container.read(nodeGroupsProvider).value!;
    expect(state.nodeCount(group.id), 2);
    expect(state.groupsForNode(100), {group.id});

    await notifier.removeNodeFromGroup(200, group.id);
    state = container.read(nodeGroupsProvider).value!;
    expect(state.nodeCount(group.id), 1);

    await notifier.deleteGroup(group.id);
    state = container.read(nodeGroupsProvider).value!;
    expect(state.groups, isEmpty);
    expect(state.membership[100], isNull);
  });

  test('createGroup assigns incrementing sortOrder', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(nodeGroupsProvider.future);
    final notifier = container.read(nodeGroupsProvider.notifier);

    await notifier.createGroup(name: 'A', colorValue: 1, iconKey: 'label');
    await notifier.createGroup(name: 'B', colorValue: 2, iconKey: 'star');

    final groups = container.read(nodeGroupsProvider).value!.groups;
    expect(groups.map((g) => g.name), ['A', 'B']);
    expect(groups.map((g) => g.sortOrder), [0, 1]);
  });
}
