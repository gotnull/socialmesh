// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/logging.dart';

/// Stable per-install identifier for unauthenticated external purchases.
///
/// Falls back here when `FirebaseAuth.currentUser?.uid` is null. The id is
/// generated once on first read, persisted to `SharedPreferences`, and
/// returned for the lifetime of the install. It survives logout/login,
/// app updates, and Riverpod container resets — only an app uninstall or
/// explicit clear-app-data wipes it.
///
/// This is the only persistent identity exposed to the external purchase
/// pipeline for anonymous users. Keep it opaque (UUID v4, no embedded
/// data) so it stays a pseudonymous handle, not a fingerprint.
class DeviceInstallId {
  static const String _prefsKey = 'external_purchase.device_install_id';
  static const Uuid _uuid = Uuid();

  /// Read or lazily mint the device install id.
  ///
  /// Returns the same value on every call within an install. Never
  /// throws — a SharedPreferences failure logs and falls back to an
  /// in-memory UUID, which keeps the current session working but will
  /// regenerate on cold start.
  static Future<String> read(SharedPreferences prefs) async {
    try {
      final existing = prefs.getString(_prefsKey);
      if (existing != null && existing.length >= 8) {
        return existing;
      }
      final fresh = _uuid.v4();
      final ok = await prefs.setString(_prefsKey, fresh);
      if (!ok) {
        AppLogging.purchase(
          '[DeviceInstallId] SharedPreferences setString returned false; using in-memory id',
        );
      }
      AppLogging.purchase('[DeviceInstallId] Minted new install id');
      return fresh;
    } catch (e) {
      AppLogging.purchase(
        '[DeviceInstallId] Read failed: $e — returning ephemeral id',
      );
      return _uuid.v4();
    }
  }

  /// Test-only reset hook. Removes the persisted id so the next `read`
  /// mints a fresh one. Production code should never call this.
  static Future<void> debugReset(SharedPreferences prefs) async {
    await prefs.remove(_prefsKey);
  }
}
