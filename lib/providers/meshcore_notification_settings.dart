// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Row 11.b: per-category MeshCore notification toggles. Phase 2 ships
// with a single switch (advert notifications); future categories
// (batch summary in Row 11.c, presence pings, etc.) add their own
// providers next to this one without breaking the API.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kAdvertNotificationsKey =
    'meshcore.notifications.adverts.enabled';

class MeshCoreAdvertNotificationsEnabledNotifier extends AsyncNotifier<bool> {
  SharedPreferences? _prefs;

  @override
  Future<bool> build() async {
    _prefs = await SharedPreferences.getInstance();
    // Default ON so users hear about new peers out of the box.
    return _prefs!.getBool(_kAdvertNotificationsKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    if (state.value == value) return;
    state = AsyncData(value);
    await _prefs?.setBool(_kAdvertNotificationsKey, value);
  }

  /// Synchronous gate for use inside Riverpod build / notification
  /// firing paths. Returns true until SharedPreferences has hydrated
  /// to mirror the default-ON behaviour.
  bool get isEnabled => state.value ?? true;
}

final meshCoreAdvertNotificationsEnabledProvider =
    AsyncNotifierProvider<MeshCoreAdvertNotificationsEnabledNotifier, bool>(
      MeshCoreAdvertNotificationsEnabledNotifier.new,
    );
