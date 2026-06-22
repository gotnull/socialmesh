// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/widgets.dart';

import '../models/mesh_models.dart';
import '../utils/text_sanitizer.dart';

// Derives a stable per-node colour from the node number's low three bytes used
// directly as RGB. This mirrors the official Meshtastic apps so the same node
// shows the same colour across implementations, and gives 16M buckets instead
// of a small fixed palette (which collided constantly on `nodeNum % paletteLen`).

/// Maps a node number to a deterministic colour using its low three bytes as
/// RGB (red = bits 16-23, green = bits 8-15, blue = bits 0-7), fully opaque.
Color nodeColorFromId(int nodeNum) {
  final value = nodeNum & 0xFFFFFF;
  final red = (value >> 16) & 0xFF;
  final green = (value >> 8) & 0xFF;
  final blue = value & 0xFF;
  return Color.fromARGB(0xFF, red, green, blue);
}

/// Resolves a node's display colour: an explicit user-set [avatarColor] wins,
/// otherwise the colour is derived from [nodeNum] via [nodeColorFromId].
Color resolveNodeColor({required int nodeNum, int? avatarColor}) {
  if (avatarColor != null) return Color(avatarColor);
  return nodeColorFromId(nodeNum);
}

/// True when [color] is light enough that a dark foreground reads better than a
/// light one. Uses Meshtastic's weighted-luminance formula and 0.5 threshold so
/// the contrasting border/text matches the official apps. Colour channels are
/// 0.0-1.0 in this Flutter version, so the weighted sum lands in the same range.
bool isLightNodeColor(Color color) {
  final brightness = (color.r * 299 + color.g * 587 + color.b * 114) / 1000;
  return brightness > 0.5;
}

/// A black-or-white colour that contrasts with [color], for an avatar's text or
/// outline so even very dark or very light node colours stay legible on the
/// dark-glass UI.
Color nodeContrastColor(Color color) =>
    isLightNodeColor(color) ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

/// The short label rendered inside a node's map marker.
///
/// Returns the node's shortName (capped at 4 grapheme clusters per the
/// Meshtastic spec, sanitized for lone surrogates / control chars) so a node
/// labelled e.g. "MYSO" reads as itself rather than collapsing to "M". Falls
/// back to the last 4 hex digits of [MeshNode.nodeNum] when no shortName is set.
String nodeMarkerLabel(MeshNode node) {
  final shortName = node.shortName;
  if (shortName != null && shortName.isNotEmpty) {
    // safeInitials sanitizes (repairs lone surrogates / strips controls) then
    // takes up to 4 grapheme clusters — grapheme-aware for emoji + accents.
    final initials = safeInitials(shortName, 4);
    if (initials.isNotEmpty) return initials;
  }
  // Last 4 hex digits — matches the canonical short-form id used
  // elsewhere in the app for nodes without a self-reported name.
  final hex = node.nodeNum.toRadixString(16).padLeft(8, '0');
  return hex.substring(hex.length - 4).toUpperCase();
}
