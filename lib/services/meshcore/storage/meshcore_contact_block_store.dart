// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q8: SharedPreferences-backed per-contact block list. Local-only
// (no wire surface) — blocked contacts still appear on the radio's
// roster and their messages still arrive; SocialMesh just suppresses
// the OS notification for them so an unwanted peer can't keep
// nagging the user.
//
// Storage shape: a SharedPreferences `StringList` of lowercase pubkey
// hex strings. A list (not a set) so the JSON shape matches what
// Flutter's `SharedPreferences` natively supports; uniqueness is
// enforced at write time via `.toSet().toList()`.
//
// Distinct from D-Q3 favorites which lives in the firmware-side
// `flags` byte. Block is a SocialMesh-local concept — the upstream
// MeshCore firmware does not surface it.

import 'package:shared_preferences/shared_preferences.dart';

const String _kBlockedContactsKey = 'meshcore_blocked_contacts_v1';

class MeshCoreContactBlockStore {
  final SharedPreferences _prefs;
  MeshCoreContactBlockStore(this._prefs);

  /// Returns the current block list. Pubkey hex strings are
  /// normalised to lowercase so callers don't have to worry about
  /// case mismatches across the read/write boundary.
  Set<String> read() {
    final raw = _prefs.getStringList(_kBlockedContactsKey) ?? const [];
    return raw.map((s) => s.toLowerCase()).toSet();
  }

  /// Replace the block list wholesale. Used by the provider's
  /// notifier on every block/unblock transition.
  Future<bool> write(Set<String> blocked) {
    final normalised = blocked.map((s) => s.toLowerCase()).toSet().toList()
      ..sort();
    return _prefs.setStringList(_kBlockedContactsKey, normalised);
  }

  /// Pure helper for tests + the notifier's optimistic update path.
  /// Adds `pubKeyHex` to `current` and returns the new set.
  static Set<String> blockIn(Set<String> current, String pubKeyHex) {
    final normalised = pubKeyHex.toLowerCase();
    if (current.contains(normalised)) return current;
    return {...current, normalised};
  }

  /// Pure helper: remove `pubKeyHex` from `current` and return the
  /// new set. Returns the same instance reference when the key was
  /// not present so callers can skip an unnecessary write.
  static Set<String> unblockIn(Set<String> current, String pubKeyHex) {
    final normalised = pubKeyHex.toLowerCase();
    if (!current.contains(normalised)) return current;
    return current.where((k) => k != normalised).toSet();
  }
}
