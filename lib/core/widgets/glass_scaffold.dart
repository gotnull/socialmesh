// Glass Scaffold
//
// A scaffold wrapper that provides a glassmorphic app bar with consistent
// backdrop blur across all screens. Handles extendBodyBehindAppBar, safe areas,
// and sliver-based scrolling automatically.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'glass_app_bar.dart';

/// A scaffold with a glassmorphic app bar that blurs content scrolling underneath.
///
/// This is the primary way to create screens with the glass effect.
/// It handles all the boilerplate: extendBodyBehindAppBar, CustomScrollView,
/// proper safe area padding, and the glass sliver app bar.
///
/// For sliver-based screens (most common):
/// ```dart
/// GlassScaffold(
///   title: 'My Screen',
///   slivers: [
///     SliverList(...),
///   ],
/// )
/// ```
///
/// For non-sliver screens using body:
/// ```dart
/// GlassScaffold.body(
///   title: 'My Screen',
///   body: MyWidget(),
/// )
/// ```
class GlassScaffold extends StatelessWidget {
  /// Creates a GlassScaffold with sliver-based content.
  ///
  /// The [slivers] are placed in a CustomScrollView below the glass app bar.
  const GlassScaffold({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    required this.slivers,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.drawer,
    this.endDrawer,
    this.scaffoldKey,
    this.pinned = true,
    this.floating = false,
    this.snap = false,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
    this.expandedHeight,
    this.flexibleSpace,
    this.bottom,
    this.physics,
    this.controller,
    this.primary = true,
    this.sigmaOverride,
    this.resizeToAvoidBottomInset = true,
  }) : body = null;

  /// Creates a GlassScaffold with a non-sliver body widget.
  ///
  /// The [body] is wrapped in a SliverToBoxAdapter automatically.
  /// Use this for simple screens that don't need sliver-level control.
  const GlassScaffold.body({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    required Widget this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.drawer,
    this.endDrawer,
    this.scaffoldKey,
    this.pinned = true,
    this.floating = false,
    this.snap = false,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
    this.expandedHeight,
    this.flexibleSpace,
    this.bottom,
    this.physics,
    this.controller,
    this.primary = true,
    this.sigmaOverride,
    this.resizeToAvoidBottomInset = true,
  }) : slivers = const [];

  /// Title text for the app bar.
  final String? title;

  /// Custom title widget (overrides [title]).
  final Widget? titleWidget;

  /// A widget to display before the title (e.g., hamburger menu, back button).
  final Widget? leading;

  /// Widgets to display after the title (e.g., action buttons).
  final List<Widget>? actions;

  /// The slivers to display in the CustomScrollView.
  final List<Widget> slivers;

  /// A non-sliver body widget (used with GlassScaffold.body constructor).
  final Widget? body;

  /// A floating action button.
  final Widget? floatingActionButton;

  /// Location of the floating action button.
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// A bottom navigation bar.
  final Widget? bottomNavigationBar;

  /// A drawer widget for the scaffold.
  final Widget? drawer;

  /// An end drawer widget for the scaffold.
  final Widget? endDrawer;

  /// Key for the scaffold.
  final GlobalKey<ScaffoldState>? scaffoldKey;

  /// Whether the app bar should remain visible at the start of the scroll view.
  final bool pinned;

  /// Whether the app bar should become visible as soon as the user scrolls
  /// towards the app bar.
  final bool floating;

  /// If snap and floating are true, the floating app bar will "snap" into view.
  final bool snap;

  /// Whether the title should be centered.
  final bool? centerTitle;

  /// Whether to automatically add a leading widget.
  final bool automaticallyImplyLeading;

  /// The size of the app bar when it is fully expanded.
  final double? expandedHeight;

  /// The widget shown when the app bar is expanded.
  final Widget? flexibleSpace;

  /// This widget appears across the bottom of the app bar.
  final PreferredSizeWidget? bottom;

  /// How the scroll view should respond to user input.
  final ScrollPhysics? physics;

  /// An object that can be used to control the position of the scroll view.
  final ScrollController? controller;

  /// Whether this is the primary scroll view associated with the parent.
  final bool primary;

  /// Override the blur sigma value.
  final double? sigmaOverride;

  /// Whether the body should resize when the keyboard appears.
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Build title widget
    Widget? effectiveTitle;
    if (titleWidget != null) {
      effectiveTitle = titleWidget;
    } else if (title != null) {
      effectiveTitle = Text(
        title!,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
        ),
      );
    }

    // Determine slivers to use
    final effectiveSlivers = body != null
        ? [SliverToBoxAdapter(child: body)]
        : slivers;

    // Default to kGlassScrollPhysics for consistent iOS bounce behavior
    final effectivePhysics = physics ?? kGlassScrollPhysics;

    return Scaffold(
      key: scaffoldKey,
      extendBodyBehindAppBar: true,
      backgroundColor: context.background,
      drawer: drawer,
      endDrawer: endDrawer,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: CustomScrollView(
        controller: controller,
        physics: effectivePhysics,
        primary: primary,
        slivers: [
          _GlassSliverAppBarInternal(
            title: effectiveTitle,
            leading: leading,
            actions: actions,
            pinned: pinned,
            floating: floating,
            snap: snap,
            centerTitle: centerTitle,
            automaticallyImplyLeading: automaticallyImplyLeading,
            expandedHeight: expandedHeight,
            flexibleSpace: flexibleSpace,
            bottom: bottom,
            sigmaOverride: sigmaOverride,
            isDark: isDark,
          ),
          ...effectiveSlivers,
        ],
      ),
    );
  }
}

/// Internal glass sliver app bar implementation that properly handles
/// the flex space and blur effect.
class _GlassSliverAppBarInternal extends StatelessWidget {
  const _GlassSliverAppBarInternal({
    this.title,
    this.leading,
    this.actions,
    required this.pinned,
    required this.floating,
    required this.snap,
    this.centerTitle,
    required this.automaticallyImplyLeading,
    this.expandedHeight,
    this.flexibleSpace,
    this.bottom,
    this.sigmaOverride,
    required this.isDark,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool pinned;
  final bool floating;
  final bool snap;
  final bool? centerTitle;
  final bool automaticallyImplyLeading;
  final double? expandedHeight;
  final Widget? flexibleSpace;
  final PreferredSizeWidget? bottom;
  final double? sigmaOverride;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final sigma = sigmaOverride ?? GlassConstants.blurSigma;
    final fillColor = isDark
        ? Colors.black.withValues(alpha: GlassConstants.fillOpacity)
        : Colors.white.withValues(alpha: GlassConstants.fillOpacity);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: GlassConstants.borderOpacity)
        : Colors.black.withValues(alpha: GlassConstants.borderOpacity * 0.5);

    // Calculate total height for the glass effect
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final toolbarHeight = kToolbarHeight;
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    final totalAppBarHeight = statusBarHeight + toolbarHeight + bottomHeight;

    return SliverAppBar(
      title: title,
      leading: leading,
      actions: actions,
      pinned: pinned,
      floating: floating,
      snap: snap,
      centerTitle: centerTitle ?? true,
      automaticallyImplyLeading: automaticallyImplyLeading,
      expandedHeight: expandedHeight,
      bottom: bottom,
      // Glass styling - disable Material tinting
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      // Glass background with blur
      flexibleSpace:
          flexibleSpace ??
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: Container(
                height: totalAppBarHeight,
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
          ),
      // System UI overlay style
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );
  }
}

/// A simpler helper function to wrap existing screens with glass styling.
///
/// Use this for quick migration of screens that already have their own
/// scroll views but want glass app bar styling.
///
/// Example:
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return glassScaffoldWrapper(
///     context: context,
///     title: 'My Screen',
///     leading: const HamburgerMenuButton(),
///     body: ListView(...),
///   );
/// }
/// ```
Widget glassScaffoldWrapper({
  required BuildContext context,
  String? title,
  Widget? titleWidget,
  Widget? leading,
  List<Widget>? actions,
  required Widget body,
  Widget? floatingActionButton,
  FloatingActionButtonLocation? floatingActionButtonLocation,
  Widget? bottomNavigationBar,
  PreferredSizeWidget? appBarBottom,
  double? sigmaOverride,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final sigma = sigmaOverride ?? GlassConstants.blurSigma;
  final fillColor = isDark
      ? Colors.black.withValues(alpha: GlassConstants.fillOpacity)
      : Colors.white.withValues(alpha: GlassConstants.fillOpacity);
  final borderColor = isDark
      ? Colors.white.withValues(alpha: GlassConstants.borderOpacity)
      : Colors.black.withValues(alpha: GlassConstants.borderOpacity * 0.5);

  // Build title widget
  Widget? effectiveTitle;
  if (titleWidget != null) {
    effectiveTitle = titleWidget;
  } else if (title != null) {
    effectiveTitle = Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: context.textPrimary,
      ),
    );
  }

  return Scaffold(
    extendBodyBehindAppBar: true,
    backgroundColor: context.background,
    floatingActionButton: floatingActionButton,
    floatingActionButtonLocation: floatingActionButtonLocation,
    bottomNavigationBar: bottomNavigationBar,
    appBar: PreferredSize(
      preferredSize: Size.fromHeight(
        kToolbarHeight + (appBarBottom?.preferredSize.height ?? 0),
      ),
      child: ClipRect(
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
              title: effectiveTitle,
              leading: leading,
              actions: actions,
              centerTitle: true,
              bottom: appBarBottom,
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
      ),
    ),
    body: body,
  );
}
