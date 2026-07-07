// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../models/mesh_models.dart';

// Resolved label for a message's relay node. [text] is either a known node's
// display name (when [resolved] is true) or a bare hex byte such as "0xC4".
// [resolved] is true only when exactly one known node matched the relay byte,
// which callers use to style the unresolved case as muted metadata.
class RelayNodeLabel {
  final String text;
  final bool resolved;

  const RelayNodeLabel(this.text, {required this.resolved});
}

// Resolve a Meshtastic `relay_node` value to a display label.
//
// `relay_node` carries only the LOW BYTE of the relaying node's NodeNum, so a
// match against the known-node set can be ambiguous. To avoid asserting a node
// we cannot prove, a name is returned only when exactly one known node matches
// the byte; any other case (zero or 2+ matches) falls back to the hex byte.
//
// Returns null when there is nothing to show (relayNode 0 or null), so callers
// can gate the whole row on a null check.
RelayNodeLabel? resolveRelayNodeLabel(
  int? relayNode,
  Iterable<MeshNode> nodes,
) {
  final raw = relayNode ?? 0;
  if (raw == 0) return null;
  final suffix = raw & 0xFF;
  final matches = nodes.where((n) => (n.nodeNum & 0xFF) == suffix).toList();
  if (matches.length == 1) {
    final name = matches.first.displayName;
    if (name.isNotEmpty) return RelayNodeLabel(name, resolved: true);
  }
  // Zero or 2+ matches: show the low byte as an uppercase 2-digit hex value.
  return RelayNodeLabel(
    '0x${suffix.toRadixString(16).toUpperCase().padLeft(2, '0')}',
    resolved: false,
  );
}
