// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'auto_scroll_text.dart';

/// A reusable AppBar that handles long titles with marquee scrolling.
///
/// Use this whenever displaying user-generated content like node names,
/// channel names, or any other potentially long text in the app bar title.
///
/// Example usage:
/// ```dart
/// MarqueeAppBar(
///   title: node.displayName,
///   subtitle: 'Direct Message',
///   leading: NodeAvatar(...),
///   actions: [...],
/// )
/// ```
class MarqueeAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// The main title text - will marquee if too long
  final String title;

  /// Optional subtitle displayed below the title
  final String? subtitle;

  /// Optional leading widget (typically back button or avatar)
  final Widget? leading;

  /// Whether to show a back button (default: true if no leading widget)
  final bool? showBackButton;

  /// Actions to display on the right side
  final List<Widget>? actions;

  /// Callback when the title area is tapped
  final VoidCallback? onTitleTap;

  /// Background color (defaults to theme background)
  final Color? backgroundColor;

  /// Title text style override
  final TextStyle? titleStyle;

  /// Subtitle text style override
  final TextStyle? subtitleStyle;

  /// Whether this is a sliver app bar
  final bool isSliver;

  /// Elevation (defaults to 0)
  final double elevation;

  /// System UI overlay style
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// Optional bottom widget (like a TabBar)
  final PreferredSizeWidget? bottom;

  /// Center the title (defaults to true for consistency)
  final bool centerTitle;

  const MarqueeAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.showBackButton,
    this.actions,
    this.onTitleTap,
    this.backgroundColor,
    this.titleStyle,
    this.subtitleStyle,
    this.isSliver = false,
    this.elevation = 0,
    this.systemOverlayStyle,
    this.bottom,
    this.centerTitle = true,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? context.background;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    final effectiveTitleStyle =
        titleStyle ??
        TextStyle(
          fontSize: hasSubtitle ? 16 : 20,
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
        );

    final effectiveSubtitleStyle =
        subtitleStyle ??
        Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: context.textTertiary);

    // Determine if we should show back button
    final shouldShowBack = showBackButton ?? (leading == null);
    final effectiveLeading =
        leading ??
        (shouldShowBack
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: context.textPrimary),
                onPressed: () => Navigator.maybePop(context),
              )
            : null);

    // Build the title widget
    Widget titleWidget;
    if (hasSubtitle) {
      // Title with subtitle layout
      titleWidget = Column(
        crossAxisAlignment: centerTitle
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AutoScrollText(title, style: effectiveTitleStyle),
          Text(
            subtitle!,
            style: effectiveSubtitleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else {
      // Simple title
      titleWidget = AutoScrollText(title, style: effectiveTitleStyle);
    }

    // Wrap in GestureDetector if onTitleTap is provided
    if (onTitleTap != null) {
      titleWidget = GestureDetector(
        onTap: onTitleTap,
        behavior: HitTestBehavior.opaque,
        child: titleWidget,
      );
    }

    if (isSliver) {
      return SliverAppBar(
        backgroundColor: bgColor,
        elevation: elevation,
        pinned: true,
        floating: false,
        leading: effectiveLeading,
        title: titleWidget,
        centerTitle: centerTitle,
        actions: actions,
        systemOverlayStyle: systemOverlayStyle,
        bottom: bottom,
      );
    }

    return AppBar(
      backgroundColor: bgColor,
      elevation: elevation,
      leading: effectiveLeading,
      title: titleWidget,
      titleSpacing: leading != null ? 0 : NavigationToolbar.kMiddleSpacing,
      centerTitle: centerTitle,
      actions: actions,
      systemOverlayStyle: systemOverlayStyle,
      bottom: bottom,
    );
  }
}

/// A variant of MarqueeAppBar that includes an avatar and supports
/// the common pattern of avatar + title + subtitle used in chat screens.
class MarqueeAppBarWithAvatar extends StatelessWidget
    implements PreferredSizeWidget {
  /// The main title text - will marquee if too long
  final String title;

  /// Optional subtitle displayed below the title
  final String? subtitle;

  /// The avatar widget to display
  final Widget avatar;

  /// Whether to show a back button before the avatar
  final bool showBackButton;

  /// Actions to display on the right side
  final List<Widget>? actions;

  /// Callback when the title/avatar area is tapped
  final VoidCallback? onTap;

  /// Background color (defaults to theme background)
  final Color? backgroundColor;

  /// Title text style override
  final TextStyle? titleStyle;

  /// Subtitle text style override
  final TextStyle? subtitleStyle;

  const MarqueeAppBarWithAvatar({
    super.key,
    required this.title,
    required this.avatar,
    this.subtitle,
    this.showBackButton = true,
    this.actions,
    this.onTap,
    this.backgroundColor,
    this.titleStyle,
    this.subtitleStyle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? context.background;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    final effectiveTitleStyle =
        titleStyle ??
        TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
        );

    final effectiveSubtitleStyle =
        subtitleStyle ??
        Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: context.textTertiary);

    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      leading: showBackButton
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: context.textPrimary),
              onPressed: () => Navigator.maybePop(context),
            )
          : null,
      titleSpacing: showBackButton ? 0 : 16,
      title: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AutoScrollText(title, style: effectiveTitleStyle),
                  if (hasSubtitle)
                    Text(
                      subtitle!,
                      style: effectiveSubtitleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: actions,
    );
  }
}
