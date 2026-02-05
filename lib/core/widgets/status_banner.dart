// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme.dart';
import 'loading_indicator.dart';

/// The visual style/type of the status banner
enum StatusBannerType {
  /// Informational (blue) - neutral info
  info,

  /// Success (green) - positive confirmation
  success,

  /// Warning (yellow/orange) - caution
  warning,

  /// Error (red) - problem/failure
  error,

  /// Accent (theme color) - branded/highlighted
  accent,

  /// Custom - use [color] parameter
  custom,
}

/// A reusable status banner widget for displaying info, warnings, errors,
/// loading states, and other status messages consistently across the app.
///
/// Supports:
/// - Multiple preset types (info, success, warning, error, accent)
/// - Custom colors
/// - Loading indicator or custom icon
/// - Title and optional subtitle
/// - Optional trailing widget
/// - Top-aligned icons for multi-line content
///
/// Example usage:
/// ```dart
/// StatusBanner(
///   type: StatusBannerType.info,
///   title: 'Scanning for devices',
///   subtitle: 'Looking for Meshtastic devices...',
///   isLoading: true,
/// )
///
/// StatusBanner.warning(
///   title: 'No encryption',
///   subtitle: 'Messages in this channel are not encrypted.',
/// )
///
/// StatusBanner.accent(
///   title: 'Synced to cloud',
///   icon: Icons.cloud_done,
/// )
/// ```
class StatusBanner extends StatelessWidget {
  /// The type of banner determining colors
  final StatusBannerType type;

  /// Custom color (only used when type is [StatusBannerType.custom])
  final Color? color;

  /// The main title text
  final String title;

  /// Optional subtitle/description text
  final String? subtitle;

  /// Icon to display (ignored if [isLoading] is true)
  final IconData? icon;

  /// Whether to show a loading indicator instead of an icon
  final bool isLoading;

  /// Optional trailing widget (e.g., a button or badge)
  final Widget? trailing;

  /// Padding inside the banner
  final EdgeInsetsGeometry padding;

  /// Margin around the banner
  final EdgeInsetsGeometry margin;

  /// Border radius of the banner
  final double borderRadius;

  /// Background opacity (0.0 to 1.0)
  final double backgroundOpacity;

  /// Border opacity (0.0 to 1.0)
  final double borderOpacity;

  /// Whether to show the icon/loading indicator
  final bool showLeading;

  /// Optional callback when banner is tapped
  final VoidCallback? onTap;

  /// Optional callback when dismiss button is tapped (shows X button when set)
  final VoidCallback? onDismiss;

  const StatusBanner({
    super.key,
    this.type = StatusBannerType.info,
    this.color,
    required this.title,
    this.subtitle,
    this.icon,
    this.isLoading = false,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 12,
    this.backgroundOpacity = 0.15,
    this.borderOpacity = 0.3,
    this.showLeading = true,
    this.onDismiss,
    this.onTap,
  });

  /// Creates an info (blue) status banner
  factory StatusBanner.info({
    Key? key,
    required String title,
    String? subtitle,
    IconData icon = Icons.info_outline,
    bool isLoading = false,
    Widget? trailing,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    double borderRadius = 12,
    VoidCallback? onTap,
    VoidCallback? onDismiss,
  }) {
    return StatusBanner(
      key: key,
      type: StatusBannerType.info,
      title: title,
      subtitle: subtitle,
      icon: icon,
      isLoading: isLoading,
      trailing: trailing,
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      onTap: onTap,
      onDismiss: onDismiss,
    );
  }

  /// Creates a success (green) status banner
  factory StatusBanner.success({
    Key? key,
    required String title,
    String? subtitle,
    IconData icon = Icons.check_circle_outline,
    bool isLoading = false,
    Widget? trailing,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    double borderRadius = 12,
    VoidCallback? onTap,
    VoidCallback? onDismiss,
  }) {
    return StatusBanner(
      key: key,
      type: StatusBannerType.success,
      title: title,
      subtitle: subtitle,
      icon: icon,
      isLoading: isLoading,
      trailing: trailing,
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      onTap: onTap,
      onDismiss: onDismiss,
    );
  }

  /// Creates a warning (yellow) status banner
  factory StatusBanner.warning({
    Key? key,
    required String title,
    String? subtitle,
    IconData icon = Icons.warning_amber_rounded,
    bool isLoading = false,
    Widget? trailing,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    double borderRadius = 12,
    VoidCallback? onTap,
    VoidCallback? onDismiss,
  }) {
    return StatusBanner(
      key: key,
      type: StatusBannerType.warning,
      title: title,
      subtitle: subtitle,
      icon: icon,
      isLoading: isLoading,
      trailing: trailing,
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      onTap: onTap,
      onDismiss: onDismiss,
    );
  }

  /// Creates an error (red) status banner
  factory StatusBanner.error({
    Key? key,
    required String title,
    String? subtitle,
    IconData icon = Icons.error_outline,
    bool isLoading = false,
    Widget? trailing,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    double borderRadius = 12,
    VoidCallback? onTap,
    VoidCallback? onDismiss,
  }) {
    return StatusBanner(
      key: key,
      type: StatusBannerType.error,
      title: title,
      subtitle: subtitle,
      icon: icon,
      isLoading: isLoading,
      trailing: trailing,
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      onTap: onTap,
      onDismiss: onDismiss,
    );
  }

  /// Creates an accent-colored status banner (uses theme accent)
  factory StatusBanner.accent({
    Key? key,
    required String title,
    String? subtitle,
    IconData? icon,
    bool isLoading = false,
    Widget? trailing,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    double borderRadius = 12,
    VoidCallback? onTap,
    VoidCallback? onDismiss,
  }) {
    return StatusBanner(
      key: key,
      type: StatusBannerType.accent,
      title: title,
      subtitle: subtitle,
      icon: icon,
      isLoading: isLoading,
      trailing: trailing,
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      onTap: onTap,
      onDismiss: onDismiss,
    );
  }

  /// Creates a custom-colored status banner
  factory StatusBanner.custom({
    Key? key,
    required Color color,
    required String title,
    String? subtitle,
    IconData? icon,
    bool isLoading = false,
    Widget? trailing,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    double borderRadius = 12,
    double backgroundOpacity = 0.15,
    double borderOpacity = 0.3,
    VoidCallback? onTap,
    VoidCallback? onDismiss,
  }) {
    return StatusBanner(
      key: key,
      type: StatusBannerType.custom,
      color: color,
      title: title,
      subtitle: subtitle,
      icon: icon,
      isLoading: isLoading,
      trailing: trailing,
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      backgroundOpacity: backgroundOpacity,
      borderOpacity: borderOpacity,
      onTap: onTap,
      onDismiss: onDismiss,
    );
  }

  Color _getColor(BuildContext context) {
    switch (type) {
      case StatusBannerType.info:
        return Colors.blue;
      case StatusBannerType.success:
        return AppTheme.successGreen;
      case StatusBannerType.warning:
        return AppTheme.warningYellow;
      case StatusBannerType.error:
        return AppTheme.errorRed;
      case StatusBannerType.accent:
        return context.accentColor;
      case StatusBannerType.custom:
        return color ?? Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannerColor = _getColor(context);

    Widget content = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: backgroundOpacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: bannerColor.withValues(alpha: borderOpacity)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLeading) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: isLoading
                  ? LoadingIndicator(size: 20, color: bannerColor)
                  : Icon(
                      icon ?? _getDefaultIcon(),
                      size: 20,
                      color: bannerColor,
                    ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, size: 20, color: bannerColor),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }

    return content;
  }

  IconData _getDefaultIcon() {
    switch (type) {
      case StatusBannerType.info:
        return Icons.info_outline;
      case StatusBannerType.success:
        return Icons.check_circle_outline;
      case StatusBannerType.warning:
        return Icons.warning_amber_rounded;
      case StatusBannerType.error:
        return Icons.error_outline;
      case StatusBannerType.accent:
        return Icons.info_outline;
      case StatusBannerType.custom:
        return Icons.info_outline;
    }
  }
}
