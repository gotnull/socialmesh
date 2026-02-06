// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/accessibility_preferences.dart';
import '../../providers/accessibility_providers.dart';
import '../accessibility_theme_adapter.dart';

/// Wrapper widget that applies accessibility preferences to its subtree
///
/// This widget should be placed high in the widget tree (typically wrapping
/// the MaterialApp or its content) to apply text scaling, density, and
/// other accessibility adjustments consistently.
///
/// It works by:
/// 1. Applying text scaling via MediaQuery override
/// 2. Providing accessibility preferences to descendants
/// 3. Applying animation duration adjustments
class AccessibilityWrapper extends ConsumerWidget {
  const AccessibilityWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(accessibilityPreferencesProvider);
    final useSystemScale = ref.watch(useSystemTextScaleProvider);

    // Get system text scale from MediaQuery
    final mediaQuery = MediaQuery.of(context);
    final systemTextScale = mediaQuery.textScaler.scale(1.0);

    // Calculate effective text scaler
    final effectiveTextScaler = AccessibilityThemeAdapter.effectiveTextScaler(
      preferences: prefs,
      systemTextScale: systemTextScale,
    );

    // If using system default, don't override MediaQuery
    if (useSystemScale) {
      return _AccessibilityDataProvider(preferences: prefs, child: child);
    }

    // Override MediaQuery with our text scaler
    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: effectiveTextScaler),
      child: _AccessibilityDataProvider(preferences: prefs, child: child),
    );
  }
}

/// InheritedWidget to provide accessibility preferences down the tree
///
/// This allows widgets to access accessibility preferences without needing
/// to watch the provider, which is useful for non-Consumer widgets.
class _AccessibilityDataProvider extends InheritedWidget {
  const _AccessibilityDataProvider({
    required this.preferences,
    required super.child,
  });

  final AccessibilityPreferences preferences;

  static _AccessibilityDataProvider? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_AccessibilityDataProvider>();
  }

  @override
  bool updateShouldNotify(_AccessibilityDataProvider oldWidget) {
    return preferences != oldWidget.preferences;
  }
}

/// Extension for easy access to accessibility preferences from BuildContext
extension AccessibilityContext on BuildContext {
  /// Get the current accessibility preferences, or defaults if not available
  AccessibilityPreferences get accessibilityPreferences {
    final provider = _AccessibilityDataProvider.maybeOf(this);
    return provider?.preferences ?? AccessibilityPreferences.defaults;
  }

  /// Whether reduce motion is enabled
  bool get reduceMotion {
    return accessibilityPreferences.reduceMotionMode.shouldReduceMotion;
  }

  /// Whether high contrast is enabled
  bool get highContrast {
    return accessibilityPreferences.contrastMode.isHighContrast;
  }

  /// Get animation duration adjusted for reduce motion preference
  Duration animationDuration(Duration baseDuration) {
    return AccessibilityThemeAdapter.animationDuration(
      baseDuration,
      accessibilityPreferences,
    );
  }

  /// Get minimum tap target size for current accessibility settings
  double get minTapTargetSize {
    return accessibilityPreferences.densityMode.minTapTargetSize;
  }

  /// Get spacing scaled by density preference
  double scaledSpacing(double baseSpacing) {
    return AccessibilityThemeAdapter.scaledSpacing(
      baseSpacing,
      accessibilityPreferences,
    );
  }
}

/// Widget that enforces minimum tap target size for accessibility
///
/// Wrap small interactive elements with this to ensure they meet
/// accessibility tap target requirements.
class AccessibleTapTarget extends ConsumerWidget {
  const AccessibleTapTarget({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minSize = ref.watch(minTapTargetSizeProvider);

    Widget content = ConstrainedBox(
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
      child: Center(child: child),
    );

    if (onTap != null) {
      content = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    if (semanticLabel != null) {
      content = Semantics(
        label: semanticLabel,
        button: onTap != null,
        child: content,
      );
    }

    return content;
  }
}

/// Animated container that respects reduce motion preference
///
/// When reduce motion is enabled, animations are instant.
/// Otherwise, uses the specified duration and curve.
class AccessibleAnimatedContainer extends ConsumerWidget {
  const AccessibleAnimatedContainer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeInOut,
    this.alignment,
    this.padding,
    this.color,
    this.decoration,
    this.foregroundDecoration,
    this.constraints,
    this.margin,
    this.transform,
    this.transformAlignment,
    this.clipBehavior = Clip.none,
    this.onEnd,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Decoration? decoration;
  final Decoration? foregroundDecoration;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? margin;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;
  final Clip clipBehavior;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion = ref.watch(reduceMotionEnabledProvider);

    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : duration,
      curve: reduceMotion ? Curves.linear : curve,
      alignment: alignment,
      padding: padding,
      color: color,
      decoration: decoration,
      foregroundDecoration: foregroundDecoration,
      constraints: constraints,
      margin: margin,
      transform: transform,
      transformAlignment: transformAlignment,
      clipBehavior: clipBehavior,
      onEnd: onEnd,
      child: child,
    );
  }
}

/// Opacity animation that respects reduce motion preference
class AccessibleAnimatedOpacity extends ConsumerWidget {
  const AccessibleAnimatedOpacity({
    super.key,
    required this.opacity,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeInOut,
    this.onEnd,
    this.alwaysIncludeSemantics = false,
  });

  final double opacity;
  final Widget child;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onEnd;
  final bool alwaysIncludeSemantics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion = ref.watch(reduceMotionEnabledProvider);

    return AnimatedOpacity(
      opacity: opacity,
      duration: reduceMotion ? Duration.zero : duration,
      curve: reduceMotion ? Curves.linear : curve,
      onEnd: onEnd,
      alwaysIncludeSemantics: alwaysIncludeSemantics,
      child: child,
    );
  }
}

/// Crossfade animation that respects reduce motion preference
class AccessibleAnimatedCrossFade extends ConsumerWidget {
  const AccessibleAnimatedCrossFade({
    super.key,
    required this.firstChild,
    required this.secondChild,
    required this.crossFadeState,
    this.duration = const Duration(milliseconds: 200),
    this.reverseDuration,
    this.firstCurve = Curves.linear,
    this.secondCurve = Curves.linear,
    this.sizeCurve = Curves.linear,
    this.alignment = Alignment.topCenter,
    this.layoutBuilder = AnimatedCrossFade.defaultLayoutBuilder,
    this.excludeBottomFocus = true,
  });

  final Widget firstChild;
  final Widget secondChild;
  final CrossFadeState crossFadeState;
  final Duration duration;
  final Duration? reverseDuration;
  final Curve firstCurve;
  final Curve secondCurve;
  final Curve sizeCurve;
  final AlignmentGeometry alignment;
  final AnimatedCrossFadeBuilder layoutBuilder;
  final bool excludeBottomFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion = ref.watch(reduceMotionEnabledProvider);
    final effectiveDuration = reduceMotion ? Duration.zero : duration;

    return AnimatedCrossFade(
      firstChild: firstChild,
      secondChild: secondChild,
      crossFadeState: crossFadeState,
      duration: effectiveDuration,
      reverseDuration: reduceMotion ? Duration.zero : reverseDuration,
      firstCurve: reduceMotion ? Curves.linear : firstCurve,
      secondCurve: reduceMotion ? Curves.linear : secondCurve,
      sizeCurve: reduceMotion ? Curves.linear : sizeCurve,
      alignment: alignment,
      layoutBuilder: layoutBuilder,
      excludeBottomFocus: excludeBottomFocus,
    );
  }
}
