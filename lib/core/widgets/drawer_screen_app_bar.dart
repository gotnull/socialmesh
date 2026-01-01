// Drawer Screen App Bar
//
// Standardized AppBar for drawer menu screens with hamburger button,
// optional actions, and marquee scrolling for long titles.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'auto_scroll_text.dart';
import '../../features/navigation/main_shell.dart';

/// A standardized AppBar for screens accessed from the drawer menu.
///
/// Features:
/// - Hamburger menu button on the left
/// - Marquee scrolling for long titles
/// - Optional subtitle
/// - Overflow menu for many actions
/// - Consistent styling across all drawer screens
///
/// Example:
/// ```dart
/// DrawerScreenAppBar(
///   title: 'Mesh Health',
///   actions: [
///     IconButton(icon: Icon(Icons.refresh), onPressed: _refresh),
///   ],
///   overflowActions: [
///     DrawerAppBarAction(
///       icon: Icons.settings,
///       label: 'Settings',
///       onPressed: _openSettings,
///     ),
///   ],
/// )
/// ```
class DrawerScreenAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  /// The main title - will marquee if too long
  final String title;

  /// Optional subtitle below the title
  final String? subtitle;

  /// Primary actions shown as icons (limit to 2-3)
  final List<Widget>? actions;

  /// Additional actions shown in overflow popup menu
  final List<DrawerAppBarAction>? overflowActions;

  /// Badge widget shown next to title (e.g., "BETA" tag)
  final Widget? titleBadge;

  /// Background color
  final Color? backgroundColor;

  /// Optional bottom widget (like TabBar)
  final PreferredSizeWidget? bottom;

  /// Callback when title is tapped
  final VoidCallback? onTitleTap;

  const DrawerScreenAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.overflowActions,
    this.titleBadge,
    this.backgroundColor,
    this.bottom,
    this.onTitleTap,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? context.background;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    // Build title widget with optional subtitle
    Widget titleWidget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AutoScrollText(
                title,
                style: TextStyle(
                  fontSize: hasSubtitle ? 16 : 18,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ),
            if (titleBadge != null) ...[const SizedBox(width: 8), titleBadge!],
          ],
        ),
        if (hasSubtitle)
          Text(
            subtitle!,
            style: TextStyle(fontSize: 12, color: context.textTertiary),
          ),
      ],
    );

    if (onTitleTap != null) {
      titleWidget = GestureDetector(
        onTap: onTitleTap,
        behavior: HitTestBehavior.opaque,
        child: titleWidget,
      );
    }

    // Build combined actions list
    final combinedActions = <Widget>[
      ...?actions,
      if (overflowActions != null && overflowActions!.isNotEmpty)
        PopupMenuButton<int>(
          icon: Icon(Icons.more_vert, color: context.textSecondary),
          color: context.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (index) {
            HapticFeedback.selectionClick();
            overflowActions![index].onPressed?.call();
          },
          itemBuilder: (context) => overflowActions!.asMap().entries.map((e) {
            final action = e.value;
            return PopupMenuItem<int>(
              value: e.key,
              child: Row(
                children: [
                  Icon(
                    action.icon,
                    size: 20,
                    color: action.isDestructive
                        ? AppTheme.errorRed
                        : context.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    action.label,
                    style: TextStyle(
                      color: action.isDestructive
                          ? AppTheme.errorRed
                          : context.textPrimary,
                    ),
                  ),
                  if (action.trailing != null) ...[
                    const Spacer(),
                    action.trailing!,
                  ],
                ],
              ),
            );
          }).toList(),
        ),
    ];

    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      leading: const HamburgerMenuButton(),
      centerTitle: true,
      title: titleWidget,
      actions: combinedActions.isNotEmpty ? combinedActions : null,
      bottom: bottom,
    );
  }
}

/// An action item for the overflow menu
class DrawerAppBarAction {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;
  final Widget? trailing;

  const DrawerAppBarAction({
    required this.icon,
    required this.label,
    this.onPressed,
    this.isDestructive = false,
    this.trailing,
  });
}

/// A simple badge widget for titles (e.g., "BETA", "NEW")
class TitleBadge extends StatelessWidget {
  final String text;
  final Color? color;

  const TitleBadge(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? AppTheme.warningYellow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }
}
