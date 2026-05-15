// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q4: `meshCoreChannelSortModeProvider` notifier pins.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_channel_sort.dart';
import 'package:socialmesh/providers/meshcore_channel_sort_mode_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('initial state hydrates as manual when nothing persisted', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final value = await container.read(meshCoreChannelSortModeProvider.future);
    expect(value, MeshCoreChannelSortMode.manual);
  });

  test('initial state hydrates from the persisted value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'meshcore_channel_sort_mode': 'latest',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final value = await container.read(meshCoreChannelSortModeProvider.future);
    expect(value, MeshCoreChannelSortMode.latest);
  });

  test('setSortMode updates state + persists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(meshCoreChannelSortModeProvider.future);
    await container
        .read(meshCoreChannelSortModeProvider.notifier)
        .setSortMode(MeshCoreChannelSortMode.unread);
    expect(
      container.read(meshCoreChannelSortModeProvider).value,
      MeshCoreChannelSortMode.unread,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('meshcore_channel_sort_mode'), 'unread');
  });
}
