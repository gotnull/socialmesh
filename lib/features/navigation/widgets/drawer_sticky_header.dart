// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Sticky header delegate for drawer section headers.
///
/// Opaque by design — do NOT wrap in `BackdropFilter`. A live blur on a
/// pinned sticky header re-runs every frame as content scrolls under it
/// and dropped frames on older devices.
class DrawerStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final ThemeData theme;

  DrawerStickyHeaderDelegate({required this.title, required this.theme});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.only(left: 24, top: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }

  @override
  double get maxExtent => 32;

  @override
  double get minExtent => 32;

  @override
  bool shouldRebuild(covariant DrawerStickyHeaderDelegate oldDelegate) {
    return title != oldDelegate.title;
  }
}
