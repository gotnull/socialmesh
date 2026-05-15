// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q4: `MeshCoreChannelSortModeStore` pins.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_channel_sort.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_channel_sort_mode_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('default read is manual when no value persisted', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = MeshCoreChannelSortModeStore(prefs);
    expect(store.read(), MeshCoreChannelSortMode.manual);
  });

  test('write + read round-trips each enum value', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = MeshCoreChannelSortModeStore(prefs);
    for (final mode in MeshCoreChannelSortMode.values) {
      await store.write(mode);
      expect(store.read(), mode);
    }
  });

  test('unknown stored value falls back to manual (forward-compat)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'meshcore_channel_sort_mode': 'future_unknown_mode',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = MeshCoreChannelSortModeStore(prefs);
    expect(store.read(), MeshCoreChannelSortMode.manual);
  });
}
