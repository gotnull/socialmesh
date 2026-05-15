// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q2: SharedPreferences-backed store for the per-app MeshCore chat
// text-scale preference. Single-value (not per-conversation) so the
// user's chosen size applies to every MeshCore chat they open. Bounds
// match upstream's accepted range so a future device-to-device
// migration won't surface out-of-range values.

import 'package:shared_preferences/shared_preferences.dart';

const double kMeshCoreChatTextScaleMin = 0.8;
const double kMeshCoreChatTextScaleMax = 1.8;
const double kMeshCoreChatTextScaleDefault = 1.0;

class MeshCoreChatTextScaleStore {
  final SharedPreferences _prefs;
  MeshCoreChatTextScaleStore(this._prefs);

  static const String _key = 'meshcore_chat_text_scale';

  // Read the persisted scale, clamped into the accepted range. Returns
  // [kMeshCoreChatTextScaleDefault] when no value is stored.
  double read() {
    final raw = _prefs.getDouble(_key);
    if (raw == null) return kMeshCoreChatTextScaleDefault;
    return clamp(raw);
  }

  Future<bool> write(double value) {
    return _prefs.setDouble(_key, clamp(value));
  }

  // Pure clamp helper exposed for the notifier so it can mirror the
  // stored value's bounds before notifying listeners.
  static double clamp(double value) {
    if (value < kMeshCoreChatTextScaleMin) return kMeshCoreChatTextScaleMin;
    if (value > kMeshCoreChatTextScaleMax) return kMeshCoreChatTextScaleMax;
    return value;
  }
}
