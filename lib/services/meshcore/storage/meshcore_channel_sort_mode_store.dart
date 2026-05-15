// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q4: SharedPreferences-backed store for the user-selected
// channel-list sort mode. Single value (not per-tab) so the
// chosen mode applies across All / Public / Private / Hidden.
//
// Forward-compat: an unknown stored value (e.g. a future enum
// addition that this build doesn't know) falls back to `manual` so
// the user sees the legacy reorder behavior instead of a crash.

import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/meshcore/widgets/meshcore_channel_sort.dart';

class MeshCoreChannelSortModeStore {
  final SharedPreferences _prefs;
  MeshCoreChannelSortModeStore(this._prefs);

  static const String _key = 'meshcore_channel_sort_mode';

  MeshCoreChannelSortMode read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return MeshCoreChannelSortMode.manual;
    return MeshCoreChannelSortMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => MeshCoreChannelSortMode.manual,
    );
  }

  Future<bool> write(MeshCoreChannelSortMode mode) {
    return _prefs.setString(_key, mode.name);
  }
}
