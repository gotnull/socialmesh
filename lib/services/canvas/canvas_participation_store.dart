// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// SharedPreferences-backed store for MeshCanvas participation
// settings.
//
// Source of truth: docs/canvas/CANVAS_PARTICIPATION_V0_1.md §3.
// Pattern mirrors `MeshCoreChannelSortModeStore` — a thin wrapper
// over a single `SharedPreferences` instance with sync read + async
// write methods. No caching, no migrations, no schema version. Three
// keys, three booleans, all default `false`.
//
// The store does not enforce mutation invariants (e.g. participation
// off forces sharing off). That logic lives in the notifier so this
// stays a pure I/O surface that tests can exercise without faking the
// notifier.

import 'package:shared_preferences/shared_preferences.dart';

import 'canvas_participation_models.dart';

class MeshCanvasParticipationStore {
  final SharedPreferences _prefs;

  MeshCanvasParticipationStore(this._prefs);

  static const String _keyOnboardingSeen =
      'mesh_canvas.participation.onboarding_seen';
  static const String _keyParticipationEnabled =
      'mesh_canvas.participation.enabled';
  static const String _keyPresenceSharingEnabled =
      'mesh_canvas.participation.presence_sharing_enabled';

  /// Reads the persisted settings. Missing keys default to `false` so
  /// a cold install lands in the safe initial state.
  MeshCanvasParticipationSettings readSettings() {
    return MeshCanvasParticipationSettings(
      onboardingSeen: _prefs.getBool(_keyOnboardingSeen) ?? false,
      participationEnabled: _prefs.getBool(_keyParticipationEnabled) ?? false,
      presenceSharingEnabled:
          _prefs.getBool(_keyPresenceSharingEnabled) ?? false,
    );
  }

  /// Persists [settings] verbatim. Caller is responsible for any
  /// invariant enforcement before write.
  Future<void> writeSettings(MeshCanvasParticipationSettings settings) async {
    await _prefs.setBool(_keyOnboardingSeen, settings.onboardingSeen);
    await _prefs.setBool(
      _keyParticipationEnabled,
      settings.participationEnabled,
    );
    await _prefs.setBool(
      _keyPresenceSharingEnabled,
      settings.presenceSharingEnabled,
    );
  }

  /// Removes every participation key. Currently unused by app code;
  /// exposed for test setup + future destructive-reset admin actions.
  Future<void> reset() async {
    await _prefs.remove(_keyOnboardingSeen);
    await _prefs.remove(_keyParticipationEnabled);
    await _prefs.remove(_keyPresenceSharingEnabled);
  }
}
