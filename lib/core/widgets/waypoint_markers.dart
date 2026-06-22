// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../theme.dart';
import 'emoji_glyph.dart';

/// Map marker for a local "dropped pin" waypoint: a yellow circle with a pin
/// icon and a short stem. Distinct from shared mesh waypoints. Shared by the
/// main map screen and the route detail map so both render pins identically.
class LocalWaypointMarker extends StatelessWidget {
  const LocalWaypointMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.warningYellow,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.place, size: 14, color: Colors.white),
        ),
        Container(width: 2, height: 12, color: AppTheme.warningYellow),
      ],
    );
  }
}

/// Map marker for a shared mesh waypoint: an orange circle with the waypoint's
/// emoji glyph (or a pin icon when no emoji is set). Takes the icon as a
/// primitive code point + validity flag so this core widget never depends on
/// the feature-local `MeshWaypoint` model. Callers pass `waypoint.icon` and
/// `waypoint.hasRenderableIcon`.
class MeshWaypointMarker extends StatelessWidget {
  /// Unicode scalar for the waypoint's emoji glyph. Only rendered when
  /// [hasIcon] is true (the caller validates it is a renderable scalar).
  final int iconCodePoint;

  /// Whether [iconCodePoint] is a renderable emoji; false falls back to a pin.
  final bool hasIcon;

  const MeshWaypointMarker({
    super.key,
    required this.iconCodePoint,
    required this.hasIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AccentColors.orange,
        shape: BoxShape.circle,
        border: Border.all(color: SemanticColors.onMarker, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
        ],
      ),
      child: hasIcon
          ? EmojiGlyph(codePoint: iconCodePoint, size: 18)
          : Icon(Icons.place, size: 18, color: SemanticColors.onMarker),
    );
  }
}
