// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

/// A widget that adds a gradient fade effect at the edges of its child.
///
/// Commonly used for:
/// - Fading content at the edge of horizontal scroll views
/// - Adding a shadow under sticky headers
/// - Blending content near static UI elements
///
/// Example usage:
/// ```dart
/// EdgeFade(
///   edges: {EdgeFadePosition.end},
///   fadeSize: 24,
///   child: ListView(...),
/// )
/// ```
class EdgeFade extends StatelessWidget {
  /// The child widget to apply the fade effect to.
  final Widget child;

  /// Which edges should have the fade effect.
  final Set<EdgeFadePosition> edges;

  /// The size of the fade gradient in logical pixels.
  final double fadeSize;

  /// The color to fade to. Defaults to the scaffold background color.
  final Color? fadeColor;

  const EdgeFade({
    super.key,
    required this.child,
    this.edges = const {EdgeFadePosition.end},
    this.fadeSize = 24,
    this.fadeColor,
  });

  /// Creates an EdgeFade that fades the end (right) edge only.
  const EdgeFade.end({
    super.key,
    required this.child,
    this.fadeSize = 24,
    this.fadeColor,
  }) : edges = const {EdgeFadePosition.end};

  /// Creates an EdgeFade that fades both horizontal edges.
  const EdgeFade.horizontal({
    super.key,
    required this.child,
    this.fadeSize = 24,
    this.fadeColor,
  }) : edges = const {EdgeFadePosition.start, EdgeFadePosition.end};

  /// Creates an EdgeFade that fades the bottom edge only.
  const EdgeFade.bottom({
    super.key,
    required this.child,
    this.fadeSize = 16,
    this.fadeColor,
  }) : edges = const {EdgeFadePosition.bottom};

  @override
  Widget build(BuildContext context) {
    final color = fadeColor ?? Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      children: [
        child,
        // Start (left) fade
        if (edges.contains(EdgeFadePosition.start))
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: fadeSize,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [color, color.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        // End (right) fade
        if (edges.contains(EdgeFadePosition.end))
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: fadeSize,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [color.withValues(alpha: 0), color],
                  ),
                ),
              ),
            ),
          ),
        // Top fade
        if (edges.contains(EdgeFadePosition.top))
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: fadeSize,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        // Bottom fade
        if (edges.contains(EdgeFadePosition.bottom))
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: fadeSize,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color.withValues(alpha: 0), color],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Positions where edge fade can be applied.
enum EdgeFadePosition {
  /// Left edge (or start in LTR layouts)
  start,

  /// Right edge (or end in LTR layouts)
  end,

  /// Top edge
  top,

  /// Bottom edge
  bottom,
}

/// A widget that adds a shadow below it, useful for sticky headers.
///
/// Shows content scrolling underneath with a subtle shadow effect.
class StickyHeaderShadow extends StatelessWidget {
  /// The header content.
  final Widget child;

  /// The shadow color. Defaults to black.
  final Color? shadowColor;

  /// The shadow blur radius.
  final double blurRadius;

  /// The shadow spread.
  final double spreadRadius;

  /// The vertical offset of the shadow.
  final double offsetY;

  const StickyHeaderShadow({
    super.key,
    required this.child,
    this.shadowColor,
    this.blurRadius = 8,
    this.spreadRadius = 0,
    this.offsetY = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: (shadowColor ?? Colors.black).withValues(alpha: 0.3),
            blurRadius: blurRadius,
            spreadRadius: spreadRadius,
            offset: Offset(0, offsetY),
          ),
        ],
      ),
      child: child,
    );
  }
}
