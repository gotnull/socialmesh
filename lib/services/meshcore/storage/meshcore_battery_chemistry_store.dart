// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q11: SharedPreferences-backed per-self-radio battery chemistry
// override. Keyed by the self radio's lowercase pubkey hex so a
// user with multiple radios (different field deployments) gets
// the right chemistry for each.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'meshcore_battery_chemistry.dart';

const String _kBatteryChemistryKey = 'meshcore_battery_chemistry_v1';

class MeshCoreBatteryChemistryStore {
  final SharedPreferences _prefs;
  MeshCoreBatteryChemistryStore(this._prefs);

  /// Returns the persisted map of `lowercase pubkey hex → chemistry`.
  /// Empty when no overrides have been written.
  Map<String, MeshCoreBatteryChemistry> read() {
    final raw = _prefs.getString(_kBatteryChemistryKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const {};
      final result = <String, MeshCoreBatteryChemistry>{};
      decoded.forEach((key, value) {
        if (value is! String) return;
        final chem = _chemistryFromName(value);
        if (chem == null) return;
        result[key.toLowerCase()] = chem;
      });
      return result;
    } catch (_) {
      return const {};
    }
  }

  /// Replace the persisted map wholesale. The notifier calls this
  /// after every set / clear transition.
  Future<bool> write(Map<String, MeshCoreBatteryChemistry> overrides) {
    final encoded = jsonEncode(
      overrides.map((k, v) => MapEntry(k.toLowerCase(), v.name)),
    );
    return _prefs.setString(_kBatteryChemistryKey, encoded);
  }

  /// Pure helper: return [current] with [pubKeyHex] mapped to
  /// [chemistry]. `auto` is special-cased to remove the entry so
  /// the persisted map never grows with no-op overrides.
  static Map<String, MeshCoreBatteryChemistry> setIn({
    required Map<String, MeshCoreBatteryChemistry> current,
    required String pubKeyHex,
    required MeshCoreBatteryChemistry chemistry,
  }) {
    final key = pubKeyHex.toLowerCase();
    if (chemistry == MeshCoreBatteryChemistry.auto) {
      if (!current.containsKey(key)) return current;
      final next = Map<String, MeshCoreBatteryChemistry>.from(current);
      next.remove(key);
      return next;
    }
    if (current[key] == chemistry) return current;
    return {...current, key: chemistry};
  }

  /// Lookup helper: returns the override for [pubKeyHex] or `auto`
  /// when none is persisted. Case-insensitive on the lookup key.
  static MeshCoreBatteryChemistry lookup(
    Map<String, MeshCoreBatteryChemistry> current,
    String pubKeyHex,
  ) {
    return current[pubKeyHex.toLowerCase()] ?? MeshCoreBatteryChemistry.auto;
  }
}

MeshCoreBatteryChemistry? _chemistryFromName(String name) {
  for (final c in MeshCoreBatteryChemistry.values) {
    if (c.name == name) return c;
  }
  return null;
}
