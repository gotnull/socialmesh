// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../models/mesh_models.dart';

/// Whether [message] matches an in-chat search for [query], which the caller
/// has already lower-cased. A message matches on its text or on its sender's
/// long or short name, taken from [sender] when the node is known and from the
/// names cached on the message otherwise.
bool messageMatchesChatSearch(Message message, MeshNode? sender, String query) {
  if (message.text.toLowerCase().contains(query)) return true;
  final names = [
    sender?.displayName ?? message.senderDisplayName,
    sender?.shortName ?? message.senderShortName,
  ];
  return names.any(
    (name) => name != null && name.toLowerCase().contains(query),
  );
}
