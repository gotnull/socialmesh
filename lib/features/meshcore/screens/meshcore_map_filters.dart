// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../../models/meshcore_contact.dart';

/// Row 14: pure predicate for the map filter dialog. Centralised so
/// the marker render in `meshcore_map_screen.dart` and the unit tests
/// share the same source of truth.
///
/// `blockedHex` is the set of muted contacts' public keys in lowercase
/// hex form (matches the storage convention used by
/// `MeshCoreContactBlockStore`).
bool meshCoreMapMarkerVisible(
  MeshCoreContact contact, {
  required bool showChatNodes,
  required bool showRepeaters,
  required bool showOtherNodes,
  required bool showOnlyUnread,
  required bool hideMuted,
  required Set<String> blockedHex,
}) {
  // Type filters (chat node / repeater / other).
  if (contact.type == 2 && !showRepeaters) return false;
  if (contact.type == 1 && !showChatNodes) return false;
  if (contact.type != 1 && contact.type != 2 && !showOtherNodes) return false;

  // Row 14: unread-only + hide-muted overlays.
  if (showOnlyUnread && contact.unreadCount == 0) return false;
  if (hideMuted && blockedHex.contains(contact.publicKeyHex.toLowerCase())) {
    return false;
  }

  return true;
}
