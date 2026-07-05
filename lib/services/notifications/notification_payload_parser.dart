// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'push_notification_service.dart';

// Pure payload -> navigation-event normalisation for local notification taps,
// extracted from the main-shell subscription so the routing decision is unit
// testable without a widget tree or plugin channel.

/// Parses a local-notification tap [payload] into a [NotificationNavigation].
///
/// Two payload conventions exist:
///   1. `type|deepLink` — used by FCM payloads converted into local
///      notifications (announcements, etc.). The deep link itself can contain
///      `:` (e.g. `https://...`), so the `|` separator is what splits type
///      from link.
///   2. `type:targetId[:more]` — the historical NotificationService
///      convention for DM / channel / MeshCore / SIP handshake / peer-found /
///      pet / aether / TAK / firmware notifications. First segment is the
///      type, rest is the target identifier.
/// A bare payload with neither separator is a type-only event.
NotificationNavigation parseLocalNotificationPayload(String payload) {
  String type;
  String? targetId;
  String? deepLink;
  if (payload.contains('|')) {
    final parts = payload.split('|');
    type = parts.first;
    deepLink = parts.length > 1 ? parts.sublist(1).join('|') : null;
  } else if (payload.contains(':')) {
    final parts = payload.split(':');
    type = parts.first;
    targetId = parts.length > 1 ? parts.sublist(1).join(':') : null;
  } else {
    type = payload;
  }
  return NotificationNavigation(
    type: type,
    targetId: targetId,
    deepLink: deepLink,
  );
}
