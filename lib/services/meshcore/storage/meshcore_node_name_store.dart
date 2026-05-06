// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Local mirror of the node name the user last applied to a MeshCore device.
//
// Why this exists: node name is firmware-authoritative. It comes back via
// SELF_INFO once the device session is up. But there's a window between
// app cold-start (or post-disconnect) and the next SELF_INFO response in
// which the settings UI has nothing to show, so the Node Name tile reads
// "Not set" even when the user previously named that radio. This store
// caches the most recent name keyed by node id (4-byte pubkey hex prefix)
// so the UI can render the last-known value while waiting for firmware
// to confirm.
//
// The mirror is updated only after the firmware accepts the rename, so a
// failed save never overwrites the cached value.

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-backed cache of the last node name applied to a
/// MeshCore device, keyed by [_keyPrefix] + lowercased node id.
class MeshCoreNodeNameStore {
  static const String _keyPrefix = 'meshcore_node_name_';

  /// Optional preferences override for tests.
  final SharedPreferences? _prefs;

  MeshCoreNodeNameStore({SharedPreferences? preferences})
    : _prefs = preferences;

  Future<SharedPreferences> _resolve() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  String _keyFor(String nodeKey) => '$_keyPrefix${nodeKey.toLowerCase()}';

  /// Save the most recently applied node name for [nodeKey]. Empty names
  /// are treated as a no-op so an in-flight clear never overwrites a
  /// good cached value.
  Future<void> save(String nodeKey, String name) async {
    if (nodeKey.isEmpty) return;
    if (name.isEmpty) return;
    final prefs = await _resolve();
    await prefs.setString(_keyFor(nodeKey), name);
  }

  /// Load the cached node name for [nodeKey], or `null` if none was ever
  /// saved.
  Future<String?> load(String nodeKey) async {
    if (nodeKey.isEmpty) return null;
    final prefs = await _resolve();
    return prefs.getString(_keyFor(nodeKey));
  }

  /// Forget the cached name for [nodeKey].
  Future<void> clear(String nodeKey) async {
    if (nodeKey.isEmpty) return;
    final prefs = await _resolve();
    await prefs.remove(_keyFor(nodeKey));
  }
}
