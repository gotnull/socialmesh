// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/safety/safe_image.dart';
import '../../../core/theme.dart';
import '../../../models/social.dart';
import '../utils/signal_utils.dart';

/// Reusable thumbnail widget for displaying signal images.
///
/// Handles:
/// - Cloud images (mediaUrls) - prioritized
/// - Local images (imageLocalPath)
/// - Loading states with spinner
/// - Error fallback to icon
/// - Customizable size, shape, and decoration
class SignalThumbnail extends StatelessWidget {
  const SignalThumbnail({
    required this.signal,
    this.size = 48,
    this.borderRadius = 20,
    this.isCircular = false,
    this.borderColor,
    this.borderWidth = 1,
    this.fallbackIcon = Icons.sensors,
    this.fallbackIconColor,
    this.backgroundColor,
    this.showLoadingIndicator = true,
    super.key,
  });

  final Post signal;
  final double size;
  final double borderRadius;
  final bool isCircular;
  final Color? borderColor;
  final double borderWidth;
  final IconData fallbackIcon;
  final Color? fallbackIconColor;
  final Color? backgroundColor;
  final bool showLoadingIndicator;

  bool get _hasCloudImage => signal.mediaUrls.isNotEmpty;
  bool get _hasLocalImage =>
      signal.imageLocalPath != null && signal.imageLocalPath!.isNotEmpty;
  bool get hasImage => _hasCloudImage || _hasLocalImage;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor =
        borderColor ?? context.accentColor.withValues(alpha: 0.5);
    final effectiveIconColor = fallbackIconColor ?? context.accentColor;
    final effectiveBackgroundColor =
        backgroundColor ?? context.accentColor.withValues(alpha: 0.2);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: isCircular ? null : BorderRadius.circular(borderRadius),
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        border: Border.all(color: effectiveBorderColor, width: borderWidth),
      ),
      child: ClipRRect(
        borderRadius: isCircular
            ? BorderRadius.circular(size / 2)
            : BorderRadius.circular(borderRadius - borderWidth),
        child: hasImage
            ? _buildImage(context, effectiveIconColor)
            : _buildFallback(effectiveIconColor),
      ),
    );
  }

  Widget _buildImage(BuildContext context, Color iconColor) {
    // Prioritize cloud image (same as _SignalImage in signal_card.dart)
    if (_hasCloudImage) {
      return SafeImage.network(
        signal.mediaUrls.first,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: showLoadingIndicator
            ? Container(
                color: Colors.grey.shade800,
                child: Center(
                  child: SizedBox(
                    width: size * 0.4,
                    height: size * 0.4,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: iconColor,
                    ),
                  ),
                ),
              )
            : null,
        errorWidget: _buildFallback(iconColor),
      );
    } else if (_hasLocalImage) {
      return SafeImage.file(
        File(signal.imageLocalPath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: _buildFallback(iconColor),
      );
    }
    return _buildFallback(iconColor);
  }

  Widget _buildFallback(Color iconColor) {
    return Center(
      child: Icon(fallbackIcon, color: iconColor, size: size * 0.5),
    );
  }
}

/// A circular thumbnail specifically for map markers.
///
/// Uses colored border based on signal age and circular shape.
class SignalMapMarker extends StatelessWidget {
  const SignalMapMarker({
    required this.signal,
    required this.size,
    this.isSelected = false,
    super.key,
  });

  final Post signal;
  final double size;
  final bool isSelected;

  bool get _hasImage =>
      signal.mediaUrls.isNotEmpty ||
      (signal.imageLocalPath != null && signal.imageLocalPath!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final markerColor = getSignalAgeColor(signal.createdAt);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _hasImage ? null : markerColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? Colors.white
              : _hasImage
              ? markerColor
              : Colors.white54,
          width: isSelected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: markerColor.withValues(alpha: 0.5),
            blurRadius: isSelected ? 12 : 6,
            spreadRadius: isSelected ? 3 : 1,
          ),
        ],
      ),
      child: _hasImage
          ? ClipOval(
              child: SignalThumbnail(
                signal: signal,
                size: size,
                isCircular: true,
                borderWidth: 0,
                backgroundColor: Colors.grey.shade800,
                fallbackIconColor: Colors.white,
              ),
            )
          : Icon(
              Icons.sensors,
              color: Colors.white,
              size: isSelected ? size * 0.5 : size * 0.5,
            ),
    );
  }
}
