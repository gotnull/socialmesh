// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

// Compact-view toggle shared by the Messages > Contacts and Channels lists.
// The tabbed Messages surface has one overflow menu for both tabs, so one
// visual density covers both (unlike Nodes, which owns its own toggle).
// Persisted as messages_view_mode_index (0 = cards, 1 = compact), the same
// scheme as the Nodes screen's node_view_mode_index.
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
