// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q4: Riverpod notifier exposing the user-selected channel-list
// sort mode. Watched by the channels screen to render the chip
// selector + drive the sort + gate the manual-reorder drag handles.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/meshcore/widgets/meshcore_channel_sort.dart';
import '../services/meshcore/storage/meshcore_channel_sort_mode_store.dart';

class MeshCoreChannelSortModeNotifier
    extends AsyncNotifier<MeshCoreChannelSortMode> {
  MeshCoreChannelSortModeStore? _store;

  @override
  Future<MeshCoreChannelSortMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    _store = MeshCoreChannelSortModeStore(prefs);
    return _store!.read();
  }

  Future<void> setSortMode(MeshCoreChannelSortMode next) async {
    final store = _store;
    if (store == null) return;
    state = AsyncData(next);
    await store.write(next);
  }
}

final meshCoreChannelSortModeProvider =
    AsyncNotifierProvider<
      MeshCoreChannelSortModeNotifier,
      MeshCoreChannelSortMode
    >(MeshCoreChannelSortModeNotifier.new);
