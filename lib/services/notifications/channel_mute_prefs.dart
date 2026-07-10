// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key under which the set of muted channel indices is
/// persisted, as a list of stringified ints.
///
/// Written by `MutedChannelsNotifier`; read by every notification-dispatch
/// path so the mute decision is identical across all of them.
const String mutedChannelsPrefKey = 'muted_channel_indices';

/// Returns `true` when [channelIndex] is in the persisted muted-channels set.
///
/// Reads SharedPreferences directly so every dispatch path (foreground
/// in-app, Android background, foreground FCM) makes the same mute decision
/// from the authoritative persisted value, not from `MutedChannelsNotifier`'s
/// in-memory state, which is an empty set until its async hydration completes.
/// During a reconnect message flood the provider can still be empty, which
/// would let a muted channel notify; reading prefs here closes that window.
bool isChannelMutedInPrefs(SharedPreferences prefs, int channelIndex) {
  final stored = prefs.getStringList(mutedChannelsPrefKey);
  if (stored == null) return false;
  return stored
      .map((s) => int.tryParse(s))
      .whereType<int>()
      .contains(channelIndex);
}

/// The channel index whose mute state gates a message's notification, or `null`
/// when per-channel mute does not apply to this message.
///
/// Per-channel mute is a property of channel broadcasts only. A direct message
/// carries a channel index too (often 0, the Primary Channel), but muting a
/// channel must never silence DMs - so this returns `null` for any non-broadcast
/// message. A broadcast with an unresolved channel index is treated as the
/// Primary Channel (0). Every notification-dispatch path uses this so the
/// broadcast-vs-DM distinction is identical across all of them.
int? muteIndexForMessage({required bool isBroadcast, required int? channel}) {
  if (!isBroadcast) return null;
  return channel ?? 0;
}
