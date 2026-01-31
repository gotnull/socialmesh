// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../theme.dart';

/// A themed circular loading indicator that uses the app's accent color.
///
/// This is a simple wrapper around [CircularProgressIndicator] that:
/// - Uses the current theme's accent color
/// - Has a consistent stroke width
/// - Can be sized via the [size] parameter
///
/// Usage:
/// ```dart
/// LoadingIndicator(size: 20)
/// ```
class LoadingIndicator extends StatelessWidget {
  /// The diameter of the loading indicator.
  final double size;

  /// The stroke width of the circular indicator.
  final double strokeWidth;

  /// Optional custom color. If null, uses the theme's accent color.
  final Color? color;

  const LoadingIndicator({
    super.key,
    this.size = 20,
    this.strokeWidth = 2,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color ?? context.accentColor,
      ),
    );
  }
}
