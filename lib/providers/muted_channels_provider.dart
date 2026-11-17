// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../services/notifications/channel_mute_prefs.dart';
import '../services/storage/storage_service.dart';
import 'app_providers.dart';

/// Persists the set of channel indices whose notifications are muted.
///
/// The state is read synchronously from the persisted set held by
/// [SettingsService], so a screen that reads it gets the stored mutes rather
/// than an empty set while a load is still running. [toggleMute] decides from
/// the persisted set too, so a stale state can never turn a mute into an
/// unmute.
class MutedChannelsNotifier extends Notifier<Set<int>> {
  static const _prefKey = mutedChannelsPrefKey;

  @override
  Set<int> build() {
    final prefs = ref.watch(settingsServiceProvider).value?.prefs;
    return prefs == null ? {} : mutedChannelsInPrefs(prefs);
  }

  /// Toggle mute for [channelIndex]. Returns the new muted state.
  Future<bool> toggleMute(int channelIndex) async {
    final prefs = (await ref.read(settingsServiceProvider.future)).prefs;
    final current = mutedChannelsInPrefs(prefs);
    final mute = !current.contains(channelIndex);
    final next = mute
        ? {...current, channelIndex}
        : ({...current}..remove(channelIndex));
    try {
      await prefs.setStringList(
        _prefKey,
        next.map((i) => i.toString()).toList(),
      );
    } catch (e) {
      AppLogging.app('Failed to save muted channels: $e');
      state = current;
      return current.contains(channelIndex);
    }
    state = next;
    AppLogging.app(
      mute ? 'Muted channel $channelIndex' : 'Unmuted channel $channelIndex',
    );
    return mute;
  }

  bool isMuted(int channelIndex) => state.contains(channelIndex);
}

/// Provider that exposes the set of muted channel indices.
final mutedChannelsProvider = NotifierProvider<MutedChannelsNotifier, Set<int>>(
  MutedChannelsNotifier.new,
);

/// Convenience provider - returns `true` while the given channel index
/// has notifications muted.
final isChannelMutedProvider = Provider.family<bool, int>((ref, channelIndex) {
  return ref.watch(mutedChannelsProvider).contains(channelIndex);
});
