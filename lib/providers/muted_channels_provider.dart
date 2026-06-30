// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';
import '../services/notifications/channel_mute_prefs.dart';

/// Persists the set of channel indices whose notifications are muted.
///
/// Uses the same optimistic-empty / lazy-load pattern as
/// [HiddenSignalsNotifier] — the state starts as an empty set and is
/// populated from SharedPreferences on first build, so callers never
/// have to await anything.
class MutedChannelsNotifier extends Notifier<Set<int>> {
  static const _prefKey = mutedChannelsPrefKey;

  @override
  Set<int> build() {
    _loadFromPrefs();
    return {};
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_prefKey);
      if (stored != null) {
        state = stored.map((s) => int.tryParse(s)).whereType<int>().toSet();
      }
    } catch (e) {
      AppLogging.app('Failed to load muted channels: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefKey,
        state.map((i) => i.toString()).toList(),
      );
    } catch (e) {
      AppLogging.app('Failed to save muted channels: $e');
    }
  }

  /// Toggle mute for [channelIndex]. Returns the new muted state.
  Future<bool> toggleMute(int channelIndex) async {
    final isMuted = state.contains(channelIndex);
    if (isMuted) {
      state = {...state}..remove(channelIndex);
    } else {
      state = {...state, channelIndex};
    }
    await _saveToPrefs();
    AppLogging.app(
      isMuted ? 'Unmuted channel $channelIndex' : 'Muted channel $channelIndex',
    );
    return !isMuted;
  }

  bool isMuted(int channelIndex) => state.contains(channelIndex);
}

/// Provider that exposes the set of muted channel indices.
final mutedChannelsProvider = NotifierProvider<MutedChannelsNotifier, Set<int>>(
  MutedChannelsNotifier.new,
);

/// Convenience provider — returns `true` while the given channel index
/// has notifications muted.
final isChannelMutedProvider = Provider.family<bool, int>((ref, channelIndex) {
  return ref.watch(mutedChannelsProvider).contains(channelIndex);
});
