// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

// Compact-view toggles for the Messages > Contacts and Channels lists.
// The tabbed Messages surface has one overflow menu for both tabs, but each
// tab persists its own visual density (0 = cards, 1 = compact - the same
// scheme as the Nodes screen's node_view_mode_index). Contacts keeps the
// legacy shared key messages_view_mode_index; Channels has its own key,
// seeded from the legacy value so both tabs start where the user left them.
class MessagesCompactViewNotifier extends Notifier<bool> {
  @override
  bool build() {
    final settings = ref.watch(settingsServiceProvider).value;
    return settings?.messagesViewModeIndex == 1;
  }

  Future<void> toggle() async {
    final next = !state;
    state = next;
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setMessagesViewModeIndex(next ? 1 : 0);
  }
}

final messagesCompactViewProvider =
    NotifierProvider<MessagesCompactViewNotifier, bool>(
      MessagesCompactViewNotifier.new,
    );

class ChannelsCompactViewNotifier extends Notifier<bool> {
  @override
  bool build() {
    final settings = ref.watch(settingsServiceProvider).value;
    return settings?.channelsViewModeIndex == 1;
  }

  Future<void> toggle() async {
    final next = !state;
    state = next;
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setChannelsViewModeIndex(next ? 1 : 0);
  }
}

final channelsCompactViewProvider =
    NotifierProvider<ChannelsCompactViewNotifier, bool>(
      ChannelsCompactViewNotifier.new,
    );
