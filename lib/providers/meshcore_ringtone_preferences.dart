// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';

/// Pack Phase 1 - per-MeshCore-notification-channel ringtone selection.
//
// Persists a `Map<channelId, rtttl>` to SharedPreferences. Channel IDs
// match the Android notification channel identifiers registered in
// `notification_service.dart` so the lookup at fire-time is a single
// map read.
//
// Storage shape (JSON inside a single SharedPreferences key):
//   {
//     "meshcore_adverts":        "RingTone:d=4,o=5,b=140:...",
//     "meshcore_batch_summary":  "Other:d=4,o=5,b=140:..."
//   }
//
// Channels without a custom selection fall back to the system default
// for the channel.
const String _kPrefsKey = 'meshcore.ringtones.preferences';

/// Canonical channel-id constants. Keep in sync with
/// [notification_service.dart].
abstract class MeshCoreRingtoneChannel {
  /// PUSH_CODE_NEW_ADVERT (0x8A) - new peer first-hear.
  static const String adverts = 'meshcore_adverts';

  /// Batch summary aggregation for rate-limited adverts.
  static const String batchSummary = 'meshcore_batch_summary';

  /// Iteration order surfaced to the picker UI - keep adverts first so
  /// the user lands on the most-customised channel by default.
  static const List<String> all = [adverts, batchSummary];
}

class MeshCoreRingtonePreferencesNotifier
    extends AsyncNotifier<Map<String, String>> {
  SharedPreferences? _prefs;

  @override
  Future<Map<String, String>> build() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_kPrefsKey);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      final out = <String, String>{};
      for (final entry in decoded.entries) {
        final k = entry.key;
        final v = entry.value;
        if (k is String && v is String && v.isNotEmpty) out[k] = v;
      }
      AppLogging.notifications(
        'event=meshcore_ringtones.loaded count=${out.length}',
      );
      return out;
    } catch (e) {
      AppLogging.notifications(
        'event=meshcore_ringtones.load.failed reason=${e.runtimeType}',
      );
      return <String, String>{};
    }
  }

  /// Look up the user-selected RTTTL for [channelId]. Null when the
  /// user has not customised this channel - caller falls through to
  /// the system default sound.
  String? getRtttl(String channelId) => state.value?[channelId];

  /// Persist a custom RTTTL for [channelId]. Empty / blank RTTTL is
  /// treated as a clear (removes the entry).
  Future<void> setRtttl(String channelId, String rtttl) async {
    final trimmed = rtttl.trim();
    if (trimmed.isEmpty) {
      await clear(channelId);
      return;
    }
    final current = Map<String, String>.from(state.value ?? const {});
    if (current[channelId] == trimmed) return;
    current[channelId] = trimmed;
    state = AsyncData(current);
    await _persist(current);
    AppLogging.notifications(
      'event=meshcore_ringtones.saved channel=$channelId rtttl_len=${trimmed.length}',
    );
  }

  /// Remove the customisation for [channelId]. The channel falls back
  /// to its default sound on the next fire.
  Future<void> clear(String channelId) async {
    final current = Map<String, String>.from(state.value ?? const {});
    if (!current.containsKey(channelId)) return;
    current.remove(channelId);
    state = AsyncData(current);
    await _persist(current);
    AppLogging.notifications(
      'event=meshcore_ringtones.cleared channel=$channelId',
    );
  }

  Future<void> _persist(Map<String, String> map) async {
    final prefs = _prefs;
    if (prefs == null) return;
    if (map.isEmpty) {
      await prefs.remove(_kPrefsKey);
      return;
    }
    await prefs.setString(_kPrefsKey, jsonEncode(map));
  }
}

final meshCoreRingtonePreferencesProvider =
    AsyncNotifierProvider<
      MeshCoreRingtonePreferencesNotifier,
      Map<String, String>
    >(MeshCoreRingtonePreferencesNotifier.new);

/// Off-the-UI-thread read of the persisted preference for a single
/// channel. `NotificationService` is a non-Riverpod singleton and
/// doesn't have access to the provider container; this helper lets it
/// look up the user's selection at fire time without a refactor.
/// Returns null when no customisation is set - caller falls through to
/// the system default sound.
Future<String?> readMeshCoreRingtoneForChannel(String channelId) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kPrefsKey);
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final v = decoded[channelId];
    if (v is! String || v.isEmpty) return null;
    return v;
  } catch (_) {
    return null;
  }
}
