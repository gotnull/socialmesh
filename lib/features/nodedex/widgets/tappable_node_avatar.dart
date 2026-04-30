// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// TappableNodeAvatar — `NodeAvatar` (initials variant) wrapped with the
// same tap-to-NodeDex contract as `TappableSigilAvatar`. Use this in
// surfaces where the design choice is the initials avatar (file
// transfer contacts, etc.). Both wrappers must keep their default tap
// behaviour aligned so any node identity glyph in the app reaches the
// same detail screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/node_avatar.dart';
import '../screens/nodedex_detail_screen.dart';

/// `NodeAvatar` that opens `NodeDexDetailScreen(nodeNum: nodeNum)` on
/// tap by default. Mirrors `TappableSigilAvatar`'s contract for the
/// initials-style avatar.
class TappableNodeAvatar extends StatelessWidget {
  /// The node this avatar belongs to. Drives the navigation target.
  final int nodeNum;

  /// Initials/short text rendered inside the circle.
  final String text;

  /// Background color of the avatar.
  final Color color;

  /// Rendered diameter (matches `NodeAvatar.size`).
  final double size;

  /// Optional border for the avatar.
  final Border? border;

  /// Optional badge widget overlaid on the avatar.
  final Widget? badge;

  /// Position of the badge (default: bottom-right).
  final AlignmentGeometry badgeAlignment;

  /// Whether to show a gradient border.
  final bool showGradientBorder;

  /// Gradient colors for the border.
  final List<Color>? gradientColors;

  /// Online status to display.
  final OnlineStatus? onlineStatus;

  /// Whether to show the online indicator dot.
  final bool showOnlineIndicator;

  /// Battery level (0-100).
  final int? batteryLevel;

  /// Whether to show the battery percentage badge.
  final bool showBatteryBadge;

  /// Replace the default NodeDex navigation. Reserve for the documented
  /// exceptions (drawer self-header, sites already on detail).
  final VoidCallback? onTapOverride;

  /// When false, the avatar is rendered without tap behaviour.
  final bool enableTap;

  const TappableNodeAvatar({
    super.key,
    required this.nodeNum,
    required this.text,
    required this.color,
    this.size = 56,
    this.border,
    this.badge,
    this.badgeAlignment = Alignment.bottomRight,
    this.showGradientBorder = false,
    this.gradientColors,
    this.onlineStatus,
    this.showOnlineIndicator = false,
    this.batteryLevel,
    this.showBatteryBadge = false,
    this.onTapOverride,
    this.enableTap = true,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = NodeAvatar(
      text: text,
      color: color,
      size: size,
      border: border,
      badge: badge,
      badgeAlignment: badgeAlignment,
      showGradientBorder: showGradientBorder,
      gradientColors: gradientColors,
      onlineStatus: onlineStatus,
      showOnlineIndicator: showOnlineIndicator,
      batteryLevel: batteryLevel,
      showBatteryBadge: showBatteryBadge,
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
