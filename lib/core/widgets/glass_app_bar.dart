// SPDX-License-Identifier: GPL-3.0-or-later
// Glass App Bar
//
// Glassmorphic app bar components with backdrop blur effect.
// Provides both SliverAppBar and standard AppBar variants.

import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Blur sigma values tuned per platform.
/// iOS handles higher blur values better; Android benefits from reduced sigma.
class GlassConstants {
  GlassConstants._();

  /// Blur sigma for iOS (vibrancy feels native at higher values)
  static const double blurSigmaIOS = 20.0;

  /// Blur sigma for Android (lower for better performance)
  static const double blurSigmaAndroid = 14.0;

  /// Background fill opacity (semi-transparent)
  static const double fillOpacity = 0.18;

  /// Bottom border opacity
  static const double borderOpacity = 0.15;

  /// Border width
  static const double borderWidth = 0.5;

  /// Get platform-appropriate blur sigma
  static double get blurSigma {
    if (Platform.isIOS) {
      return blurSigmaIOS;
    }
    return blurSigmaAndroid;
  }
}

/// Physics for consistent iOS-style bounce scrolling across all screens.
///
/// Combines [AlwaysScrollableScrollPhysics] (scroll even when content fits)
/// with [BouncingScrollPhysics] (iOS-style overscroll bounce).
///
/// Use with [GlassScaffold] or any [CustomScrollView]:
/// ```dart
/// GlassScaffold(
///   physics: kGlassScrollPhysics,
///   slivers: [...],
/// )
/// ```
const ScrollPhysics kGlassScrollPhysics = AlwaysScrollableScrollPhysics(
  parent: BouncingScrollPhysics(),
);

/// A glassmorphic SliverAppBar with backdrop blur effect.
///
/// Use with CustomScrollView where content renders behind the app bar.
/// Requires the parent Scaffold to have `extendBodyBehindAppBar: true`.
///
/// Example:
/// ```dart
/// Scaffold(
///   extendBodyBehindAppBar: true,
///   body: CustomScrollView(
///     slivers: [
///       GlassSliverAppBar(
///         title: Text('My Screen'),
///         pinned: true,
///       ),
///       SliverList(...),
///     ],
///   ),
/// )
/// ```
class GlassSliverAppBar extends StatelessWidget {
  const GlassSliverAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.pinned = true,
    this.floating = false,
    this.snap = false,
    this.expandedHeight,
    this.collapsedHeight,
    this.flexibleSpace,
    this.bottom,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
    this.sigmaOverride,
    this.forceElevated = false,
    this.toolbarHeight,
  });

  /// The primary widget displayed in the app bar.
  final Widget? title;

  /// A widget to display before the title.
  final Widget? leading;

  /// Widgets to display after the title.
  final List<Widget>? actions;

  /// Whether the app bar should remain visible at the start of the scroll view.
  final bool pinned;

  /// Whether the app bar should become visible as soon as the user scrolls
  /// towards the app bar.
  final bool floating;

  /// If snap and floating are true, the floating app bar will "snap" into view.
  final bool snap;

  /// The size of the app bar when it is fully expanded.
  final double? expandedHeight;

  /// The height of the app bar when it is fully collapsed.
  final double? collapsedHeight;

  /// The widget shown when the app bar is expanded.
  final Widget? flexibleSpace;

  /// This widget appears across the bottom of the app bar.
  final PreferredSizeWidget? bottom;

  /// Whether the title should be centered.
  final bool? centerTitle;

  /// Whether to automatically add a leading widget.
  final bool automaticallyImplyLeading;

  /// Override the blur sigma value.
  final double? sigmaOverride;

  /// If true, displays a shadow beneath the app bar.
  final bool forceElevated;

  /// The height of the toolbar component of the app bar.
  final double? toolbarHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sigma = sigmaOverride ?? GlassConstants.blurSigma;
    final fillColor = isDark
        ? Colors.black.withValues(alpha: GlassConstants.fillOpacity)
        : Colors.white.withValues(alpha: GlassConstants.fillOpacity);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: GlassConstants.borderOpacity)
        : Colors.black.withValues(alpha: GlassConstants.borderOpacity * 0.5);

    // If user provides custom flexibleSpace, use it directly
    // Otherwise, create our glass effect
    final effectiveFlexibleSpace =
        flexibleSpace ??
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: Container(
              decoration: BoxDecoration(
                color: fillColor,
                border: Border(
                  bottom: BorderSide(
                    color: borderColor,
                    width: GlassConstants.borderWidth,
                  ),
                ),
              ),
            ),
          ),
        );

    return SliverAppBar(
      title: title,
      leading: leading,
      actions: actions,
      pinned: pinned,
      floating: floating,
      snap: snap,
      expandedHeight: expandedHeight,
      collapsedHeight: collapsedHeight ?? kToolbarHeight,
      flexibleSpace: effectiveFlexibleSpace,
      bottom: bottom,
      centerTitle: centerTitle ?? true,
      automaticallyImplyLeading: automaticallyImplyLeading,
      toolbarHeight: toolbarHeight ?? kToolbarHeight,
      forceElevated: forceElevated,
      // Glass styling - disable Material tinting
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      // System UI overlay style
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );
  }
}

/// A glassmorphic AppBar with backdrop blur effect.
///
/// Implements PreferredSizeWidget so it can be used as a standard Scaffold appBar.
/// Requires the parent Scaffold to have `extendBodyBehindAppBar: true`.
///
/// Example:
/// ```dart
/// Scaffold(
///   extendBodyBehindAppBar: true,
///   appBar: GlassAppBar(
///     title: Text('My Screen'),
///   ),
///   body: ListView(...),
/// )
/// ```
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
    this.sigmaOverride,
    this.bottom,
    this.toolbarHeight,
    this.titleSpacing,
    this.titleTextStyle,
  });

  /// The primary widget displayed in the app bar.
  final Widget? title;

  /// A widget to display before the title.
  final Widget? leading;

  /// Widgets to display after the title.
  final List<Widget>? actions;

  /// Whether the title should be centered.
  final bool? centerTitle;

  /// Whether to automatically add a leading widget.
  final bool automaticallyImplyLeading;

  /// Override the blur sigma value.
  final double? sigmaOverride;

  /// This widget appears across the bottom of the app bar.
  final PreferredSizeWidget? bottom;

  /// The height of the toolbar component of the app bar.
  final double? toolbarHeight;

  /// The spacing around the title content on the horizontal axis.
  final double? titleSpacing;

  /// The text style for the title.
  final TextStyle? titleTextStyle;

  @override
  Size get preferredSize => Size.fromHeight(
    (toolbarHeight ?? kToolbarHeight) + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sigma = sigmaOverride ?? GlassConstants.blurSigma;
    final fillColor = isDark
        ? Colors.black.withValues(alpha: GlassConstants.fillOpacity)
        : Colors.white.withValues(alpha: GlassConstants.fillOpacity);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: GlassConstants.borderOpacity)
        : Colors.black.withValues(alpha: GlassConstants.borderOpacity * 0.5);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          decoration: BoxDecoration(
            color: fillColor,
            border: Border(
              bottom: BorderSide(
                color: borderColor,
                width: GlassConstants.borderWidth,
              ),
            ),
          ),
          child: AppBar(
            title: title,
            leading: leading,
            actions: actions,
            centerTitle: centerTitle ?? true,
            automaticallyImplyLeading: automaticallyImplyLeading,
            bottom: bottom,
            toolbarHeight: toolbarHeight,
            titleSpacing: titleSpacing,
            titleTextStyle: titleTextStyle,
            // Glass styling - disable Material tinting
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0,
            // System UI overlay style
            systemOverlayStyle: isDark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
          ),
        ),
      ),
    );
  }
}

/// Extension to easily create a glass-styled title text
extension GlassAppBarTextExtension on BuildContext {
  /// Standard glass app bar title style
  TextStyle get glassAppBarTitleStyle =>
      Theme.of(this).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ) ??
      TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary);
}
