// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../theme.dart';

/// The app's draggable scroll bar, for a scrollable driven by [controller].
///
/// [GlassScaffold] applies it to its own scroll view when `scrollbar` is set.
/// A list that scrolls inside the scaffold body (a reorderable list, a tab's
/// own scroll view) wraps itself in this directly, so every bar shares one
/// look. [padding] keeps the track clear of headers pinned over the list.
class AppScrollbar extends StatelessWidget {
  const AppScrollbar({
    super.key,
    required this.controller,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final ScrollController controller;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawScrollbar(
      controller: controller,
      interactive: true,
      thickness: AppTheme.scrollbarThickness,
      radius: const Radius.circular(AppTheme.radius2),
      thumbColor: context.textTertiary,
      minThumbLength: AppTheme.scrollbarMinThumbLength,
      crossAxisMargin: AppTheme.scrollbarMargin,
      mainAxisMargin: AppTheme.scrollbarMargin,
      timeToFade: AppTheme.scrollbarTimeToFade,
      fadeDuration: AppTheme.scrollbarFadeDuration,
      padding: padding,
      child: child,
    );
  }
}
