import 'package:flutter/material.dart';
import '../theme.dart';

/// A smart avatar widget that displays node initials with adaptive text sizing.
/// Automatically adjusts font size based on text length to ensure it fits nicely
/// within the circular avatar, even for long hex node IDs.
class NodeAvatar extends StatelessWidget {
  /// The text to display in the avatar (typically shortName or hex node ID)
  final String text;

  /// The background color of the avatar
  final Color color;

  /// The size of the avatar (both width and height)
  final double size;

  /// Optional border to display around the avatar
  final Border? border;

  /// Optional badge widget to overlay on the avatar
  final Widget? badge;

  /// Position of the badge (default: bottom-right)
  final AlignmentGeometry badgeAlignment;

  const NodeAvatar({
    super.key,
    required this.text,
    required this.color,
    this.size = 56,
    this.border,
    this.badge,
    this.badgeAlignment = Alignment.bottomRight,
  });

  /// Calculate the optimal font size based on text length and avatar size
  double _calculateFontSize() {
    final baseSize = size * 0.3; // Base is 30% of avatar size
    final length = text.length;

    if (length <= 2) {
      return baseSize * 1.2; // Larger for very short text
    } else if (length <= 4) {
      return baseSize; // Normal for 3-4 chars
    } else if (length <= 6) {
      return baseSize * 0.7; // Smaller for 5-6 chars
    } else {
      return baseSize * 0.55; // Even smaller for longer text
    }
  }

  /// Get a display-friendly version of the text
  /// For long hex codes, format them nicely
  String _getDisplayText() {
    if (text.length <= 4) {
      return text;
    }

    // For longer text (like hex node IDs), take first 5 chars
    // and display in a cleaner format
    if (text.length > 5) {
      return text.substring(0, 5).toLowerCase();
    }

    return text.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _getDisplayText();
    final fontSize = _calculateFontSize();

    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: border,
          ),
          child: Center(
            child: Text(
              displayText,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: displayText.length > 4 ? -0.5 : 0,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
        ),
        if (badge != null)
          Positioned.fill(
            child: Align(alignment: badgeAlignment, child: badge!),
          ),
      ],
    );
  }
}

/// A variant that shows a gradient or patterned background for nodes
/// without a custom avatar color
class NodeAvatarWithFallback extends StatelessWidget {
  final String text;
  final int? avatarColor;
  final double size;
  final Border? border;
  final Widget? badge;
  final Color fallbackColor;

  const NodeAvatarWithFallback({
    super.key,
    required this.text,
    this.avatarColor,
    this.size = 56,
    this.border,
    this.badge,
    this.fallbackColor = AppTheme.graphPurple,
  });

  @override
  Widget build(BuildContext context) {
    return NodeAvatar(
      text: text,
      color: avatarColor != null ? Color(avatarColor!) : fallbackColor,
      size: size,
      border: border,
      badge: badge,
    );
  }
}
