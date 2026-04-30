// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// TappableSigilAvatar — `SigilAvatar` wrapper that defaults to navigating
// to `NodeDexDetailScreen` for the given node when tapped. Every node
// sigil/avatar in the app should be a portal to that node's NodeDex
// detail; making that the default of a single reusable widget is the
// only way to keep the contract uniform across feature modules.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/nodedex_entry.dart';
import '../models/sigil_evolution.dart';
import '../screens/nodedex_detail_screen.dart';
import 'sigil_painter.dart';

/// `SigilAvatar` that opens `NodeDexDetailScreen(nodeNum: nodeNum)` on
/// tap by default.
///
/// Use this everywhere a node sigil is rendered. Pass [onTapOverride]
/// only for the legitimate exceptions:
/// - the drawer self-header that opens self-profile rather than NodeDex,
/// - sites that are already inside `NodeDexDetailScreen` for this node
///   and want a peer or co-seen jump,
/// - a screen-specific peer detail sheet that wants its own behaviour.
///
/// To render the sigil non-interactively (decorative reference inside
/// content cards, stack overlays, etc.) pass `enableTap: false`.
class TappableSigilAvatar extends StatelessWidget {
  /// The node this sigil belongs to. Drives both the rendered sigil
  /// (when [sigil] is null) and the default navigation target.
  final int nodeNum;

  /// Pre-generated sigil data. If null the widget generates it from
  /// [nodeNum] via the underlying `SigilAvatar`.
  final SigilData? sigil;

  /// Rendered diameter (matches `SigilAvatar.size`).
  final double size;

  /// Optional badge widget to overlay on the avatar (status dot,
  /// trait icon, etc.).
  final Widget? badge;

  /// Optional evolution state for visual maturity effects.
  final SigilEvolution? evolution;

  /// Replace the default NodeDex navigation with custom behaviour.
  /// Only use for the documented exceptions above. When null, the
  /// default tap pushes `NodeDexDetailScreen(nodeNum: nodeNum)`.
  final VoidCallback? onTapOverride;

  /// When false, the avatar is rendered with no tap behaviour. Reserve
  /// for purely decorative renderings inside cards or stack overlays.
  final bool enableTap;

  const TappableSigilAvatar({
    super.key,
    required this.nodeNum,
    this.sigil,
    this.size = 44,
    this.badge,
    this.evolution,
    this.onTapOverride,
    this.enableTap = true,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = SigilAvatar(
      sigil: sigil,
      nodeNum: nodeNum,
      size: size,
      badge: badge,
      evolution: evolution,
    );

    if (!enableTap) return avatar;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        if (onTapOverride != null) {
          onTapOverride!();
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NodeDexDetailScreen(nodeNum: nodeNum),
          ),
        );
      },
      child: avatar,
    );
  }
}
