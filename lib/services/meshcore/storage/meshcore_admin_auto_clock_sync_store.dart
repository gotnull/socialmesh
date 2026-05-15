// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-D2: per-contact toggle for "fire `clock sync` automatically on
// successful admin login". Storage-only — no wire side. The admin
// settings screen reads + writes this toggle; the next admin login
// pipeline reads it before deciding whether to dispatch a `clock
// sync` CLI command alongside the standard `sendLogin`.
//
// Why per-contact: different repeaters have different operating
// conventions; some are GPS-synced, some aren't. A global toggle is
// the wrong granularity.
//
// Storage key: `meshcore_repeater_admin_auto_clock_sync.<pubKeyHex>`.
// Default: false. Absent key behaves identically to false.

import 'package:shared_preferences/shared_preferences.dart';

class MeshCoreAdminAutoClockSyncStore {
  final SharedPreferences _prefs;
  MeshCoreAdminAutoClockSyncStore(this._prefs);

  static String _key(String pubKeyHex) =>
      'meshcore_repeater_admin_auto_clock_sync.$pubKeyHex';

  bool isEnabled(String pubKeyHex) {
    return _prefs.getBool(_key(pubKeyHex)) ?? false;
  }

  Future<bool> setEnabled(String pubKeyHex, bool enabled) {
    return _prefs.setBool(_key(pubKeyHex), enabled);
  }
}
