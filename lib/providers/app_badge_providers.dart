// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'meshcore_message_providers.dart';

// App-icon badge total. Lives in its own file because app_providers.dart
// (Meshtastic unread) and meshcore_message_providers.dart (MeshCore unread)
// are deliberately independent; this is the one place that sums across
// protocols. Consumed by the main shell, which pushes the total to
// NotificationService.setAppBadgeCount when the app backgrounds.

/// Total unread MeshCore messages across all conversations.
final meshCoreUnreadCountProvider = Provider<int>(
  (ref) => ref.watch(
    meshCoreConversationsProvider.select((s) => s.totalUnreadCount),
  ),
);

/// The number to show on the app icon badge: unread Meshtastic messages
/// (DMs + channels) plus unread MeshCore messages.
final appBadgeCountProvider = Provider<int>(
  (ref) =>
      ref.watch(unreadMessagesCountProvider) +
      ref.watch(meshCoreUnreadCountProvider),
);
