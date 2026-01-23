import 'package:flutter/material.dart';

import '../theme.dart';

class AppBarOverflowMenu<T> extends StatelessWidget {
  const AppBarOverflowMenu({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.onOpened,
    this.onCanceled,
    this.tooltip = 'More options',
    this.color,
    this.surfaceTintColor,
    this.icon,
    this.iconColor,
    this.iconSize,
    this.enabled = true,
    this.offset,
    this.shape,
    this.elevation,
    this.padding,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final VoidCallback? onOpened;
  final VoidCallback? onCanceled;
  final String tooltip;
  final Color? color;
  final Color? surfaceTintColor;
  final Widget? icon;
  final Color? iconColor;
  final double? iconSize;
  final bool enabled;
  final Offset? offset;
  final ShapeBorder? shape;
  final double? elevation;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final resolvedIcon = icon ??
        Icon(
          Icons.more_vert,
          color: iconColor ?? context.textPrimary,
          size: iconSize,
        );
    final resolvedShape = shape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.border),
        );
    return PopupMenuButton<T>(
      icon: resolvedIcon,
      tooltip: tooltip,
      color: color ?? context.card,
      surfaceTintColor: surfaceTintColor ?? Colors.transparent,
      onSelected: onSelected,
      onOpened: onOpened,
      onCanceled: onCanceled,
      itemBuilder: itemBuilder,
      enabled: enabled,
      padding: padding ?? EdgeInsets.zero,
      offset: offset ?? Offset.zero,
      shape: resolvedShape,
      elevation: elevation,
    );
  }
}
