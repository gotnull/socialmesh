// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Protocol-neutral channel-list facade. Public watch_companion files
// MUST NOT import this file outside the snapshot composer.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/providers/app_providers.dart'
    show ActiveProtocol, activeProtocolProvider, channelsProvider;
import 'package:socialmesh/providers/meshcore_message_providers.dart'
    show meshCoreConversationsProvider;

import '../models/watch_companion_channel_preview.dart';
import '../watch_companion_providers.dart'
    show watchDefaultChannelIndexProvider;

/// Channel list shown in the Watch quick-send picker. One entry per
/// available channel; exactly one carries `isDefault == true` when the
/// persisted `watchDefaultChannelIndex` matches an existing channel
/// index. When no channel matches, no entry is marked default (the Watch
/// then falls back to the first listed entry on its own).
///
/// MeshCore note: there is no dedicated channel-list provider. The
/// conversation list (`meshCoreConversationsProvider`) carries
/// `isChannel`-flagged entries with a `channelIndex`; we surface those.
/// If MeshCore is connected but the conversation list hasn't yet
/// populated any channel entries, we return a conservative single-entry
/// "Public" channel at index 0 rather than fabricating a richer list.
final watchChannelsFacadeProvider =
    Provider<List<WatchCompanionChannelPreview>>((ref) {
      final activeProtocol = ref.watch(activeProtocolProvider);
      final defaultIndex = ref.watch(watchDefaultChannelIndexProvider);

      switch (activeProtocol) {
        case ActiveProtocol.none:
          return const <WatchCompanionChannelPreview>[];

        case ActiveProtocol.meshtastic:
          final channels = ref.watch(channelsProvider);
          return channels
              .map(
                (c) => WatchCompanionChannelPreview(
                  index: c.index,
                  name: c.name.isNotEmpty ? c.name : 'channel_${c.index}',
                  isDefault: c.index == defaultIndex,
                ),
              )
              .toList(growable: false);

        case ActiveProtocol.meshcore:
          final state = ref.watch(meshCoreConversationsProvider);
          final channelConvs = state.conversations
              .where((c) => c.isChannel)
              .toList(growable: false);

          if (channelConvs.isEmpty) {
            // Conservative fallback: public channel index 0 always exists on
            // MeshCore. We deliberately do not fabricate any other entries.
            return <WatchCompanionChannelPreview>[
              WatchCompanionChannelPreview(
                index: 0,
                name: 'Public',
                isDefault: defaultIndex == 0,
              ),
            ];
          }

          return channelConvs
              .map((c) {
                final idx = c.channelIndex ?? 0;
                return WatchCompanionChannelPreview(
                  index: idx,
                  name: c.name,
                  isDefault: idx == defaultIndex,
                );
              })
              .toList(growable: false);
      }
    });
