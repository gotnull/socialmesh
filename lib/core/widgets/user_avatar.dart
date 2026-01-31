// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Universal reusable avatar widget for displaying user/profile images.
///
/// Handles:
/// - Network images (http/https URLs)
/// - Local file images
/// - Fallback to initials or icon
/// - Proper sizing with border support
/// - Loading and error states
///
/// Usage:
/// ```dart
/// UserAvatar(
///   imageUrl: profile.avatarUrl,
///   initials: profile.initials,
///   size: 48,
///   borderWidth: 2,
///   borderColor: accentColor,
/// )
/// ```
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.fallbackIcon,
    this.size = 40,
    this.borderWidth = 0,
    this.borderColor,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
  });

  /// URL or local file path for the avatar image.
  /// Supports http/https URLs and local file paths.
  final String? imageUrl;

  /// Initials to show when no image is available.
  /// If null and no fallbackIcon, shows '?'.
  final String? initials;

  /// Icon to show when no image and no initials.
  /// Defaults to Icons.person.
  final IconData? fallbackIcon;

  /// Total size of the avatar (diameter).
  final double size;

  /// Width of the border around the avatar.
  /// The image will be inset by this amount.
  final double borderWidth;

  /// Color of the border. If null, uses accent color.
  final Color? borderColor;

  /// Background color for initials/icon fallback.
  /// If null, uses a translucent version of foreground color.
  final Color? backgroundColor;

  /// Color for initials text and fallback icon.
  /// If null, uses accent color.
  final Color? foregroundColor;

  /// Callback when avatar is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;
    final effectiveBorderColor = borderColor ?? accentColor;
    final effectiveForegroundColor = foregroundColor ?? accentColor;
    final effectiveBackgroundColor =
        backgroundColor ?? effectiveForegroundColor.withValues(alpha: 0.2);

    // Calculate inner image size (accounting for border)
    final innerSize = size - (borderWidth * 2);

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: effectiveBackgroundColor,
        border: borderWidth > 0
            ? Border.all(color: effectiveBorderColor, width: borderWidth)
            : null,
      ),
      child: borderWidth > 0
          ? Padding(
              padding: EdgeInsets.all(borderWidth),
              child: ClipOval(
                child: _buildContent(
                  context,
                  innerSize,
                  effectiveForegroundColor,
                  effectiveBackgroundColor,
                ),
              ),
            )
          : ClipOval(
              child: _buildContent(
                context,
                innerSize,
                effectiveForegroundColor,
                effectiveBackgroundColor,
              ),
            ),
    );

    if (onTap != null) {
      avatar = GestureDetector(onTap: onTap, child: avatar);
    }

    return avatar;
  }

  Widget _buildContent(
    BuildContext context,
    double innerSize,
    Color foreground,
    Color background,
  ) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      if (imageUrl!.startsWith('http')) {
        return Image.network(
          imageUrl!,
          width: innerSize,
          height: innerSize,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoading(innerSize, foreground, background);
          },
          errorBuilder: (context, error, stackTrace) =>
              _buildFallback(innerSize, foreground, background),
        );
      } else {
        // Local file path
        return Image.file(
          File(imageUrl!),
          width: innerSize,
          height: innerSize,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallback(innerSize, foreground, background),
        );
      }
    }
    return _buildFallback(innerSize, foreground, background);
  }

  Widget _buildLoading(double innerSize, Color foreground, Color background) {
    return Container(
      width: innerSize,
      height: innerSize,
      color: background,
      child: Center(
        child: SizedBox(
          width: innerSize * 0.4,
          height: innerSize * 0.4,
          child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
        ),
      ),
    );
  }

  Widget _buildFallback(double innerSize, Color foreground, Color background) {
    return Container(
      width: innerSize,
      height: innerSize,
      color: background,
      child: Center(
        child: initials != null && initials!.isNotEmpty
            ? Text(
                initials!.length > 2
                    ? initials!.substring(0, 2).toUpperCase()
                    : initials!.toUpperCase(),
                style: TextStyle(
                  fontSize: innerSize * 0.4,
                  fontWeight: FontWeight.bold,
                  color: foreground,
                ),
              )
            : Icon(
                fallbackIcon ?? Icons.person,
                size: innerSize * 0.5,
                color: foreground,
              ),
      ),
    );
  }
}
