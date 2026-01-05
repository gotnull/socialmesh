import 'package:flutter/material.dart';
import '../theme.dart';

/// A smart avatar widget that displays node initials with adaptive text sizing.
/// Automatically adjusts font size based on text length to ensure it fits nicely
/// within the circular avatar, even for long hex node IDs.
///
/// Can display with gradient borders and online status indicators
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

  /// Whether to show a gradient border
  final bool showGradientBorder;

  /// Gradient colors for the border (defaults to accent colors)
  final List<Color>? gradientColors;

  /// Online status to display indicator
  final OnlineStatus? onlineStatus;

  /// Whether to show the online status indicator
  final bool showOnlineIndicator;

  /// Battery level (0-100) for battery ring indicator
  final int? batteryLevel;

  /// Whether to show battery percentage badge
  final bool showBatteryBadge;

  const NodeAvatar({
    super.key,
    required this.text,
    required this.color,
    this.size = 56,
    this.border,
    this.badge,
    this.badgeAlignment = Alignment.bottomRight,
    this.showGradientBorder = false,
    this.gradientColors,
    this.onlineStatus,
    this.showOnlineIndicator = false,
    this.batteryLevel,
    this.showBatteryBadge = false,
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

  Color _getBatteryColor() {
    if (batteryLevel == null) return Colors.grey;
    if (batteryLevel! > 100) return AccentColors.green; // Charging
    if (batteryLevel! > 50) return AccentColors.green;
    if (batteryLevel! > 20) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _getDisplayText();
    final fontSize = _calculateFontSize();
    final borderWidth = showGradientBorder ? 3.0 : 0.0;
    // Only show battery ring if NOT showing gradient border (avoid visual clutter)
    final showBatteryRing = batteryLevel != null && !showGradientBorder;
    final batteryRingWidth = showBatteryRing ? 3.0 : 0.0;
    final innerPadding = 3.0; // Always have padding around inner circle

    Widget avatar = Container(
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
            color: SemanticColors.onMarker,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: displayText.length > 4 ? -0.5 : 0,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.clip,
        ),
      ),
    );

    // Wrap in battery ring if battery level provided AND not showing gradient
    if (showBatteryRing) {
      final batteryPercent = (batteryLevel! > 100 ? 100 : batteryLevel!) / 100;
      final batteryColor = _getBatteryColor();

      avatar = Container(
        decoration: BoxDecoration(
          color: context.background,
          shape: BoxShape.circle,
        ),
        padding: EdgeInsets.all(innerPadding),
        child: CustomPaint(
          painter: _BatteryRingPainter(
            percent: batteryPercent,
            color: batteryColor,
            strokeWidth: batteryRingWidth,
          ),
          child: Padding(
            padding: EdgeInsets.all(batteryRingWidth + innerPadding),
            child: avatar,
          ),
        ),
      );
    }

    // Wrap in gradient border if needed (mutually exclusive with battery ring visually)
    if (showGradientBorder) {
      avatar = Container(
        width: size + (borderWidth * 2) + (innerPadding * 2),
        height: size + (borderWidth * 2) + (innerPadding * 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                gradientColors ??
                [
                  const Color(0xFFFFD600), // Yellow
                  const Color(0xFFFF7A00), // Orange
                  const Color(0xFFFF0069), // Pink
                  const Color(0xFFD300C5), // Purple
                ],
          ),
        ),
        padding: EdgeInsets.all(borderWidth),
        child: Container(
          decoration: BoxDecoration(
            color: context.background,
            shape: BoxShape.circle,
          ),
          padding: EdgeInsets.all(innerPadding),
          child: avatar,
        ),
      );
    }

    // Only show online dot when there's no other ring indicator
    final showOnlineDot =
        showOnlineIndicator &&
        onlineStatus != null &&
        !showGradientBorder &&
        !showBatteryRing;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        if (badge != null)
          Positioned.fill(
            child: Align(alignment: badgeAlignment, child: badge!),
          ),
        // Battery percentage badge (top-left) - only when battery level exists
        if (showBatteryBadge && batteryLevel != null)
          Positioned(
            top: -4,
            left: showGradientBorder ? borderWidth - 6 : -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getBatteryColor(),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.background, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                batteryLevel! > 100 ? '⚡' : '$batteryLevel%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        // Online status indicator (bottom-right) - only when no other ring indicators
        if (showOnlineDot)
          Positioned(
            bottom: 0,
            right: 0,
            child: _OnlineStatusIndicator(
              status: onlineStatus!,
              size: size * 0.25,
            ),
          ),
      ],
    );
  }
}

/// Custom painter for battery level ring around avatar
class _BatteryRingPainter extends CustomPainter {
  final double percent;
  final Color color;
  final double strokeWidth;

  _BatteryRingPainter({
    required this.percent,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track (gray)
    final trackPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Battery level arc
    final batteryPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * 3.14159 * percent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2, // Start at top
      sweepAngle,
      false,
      batteryPaint,
    );
  }

  @override
  bool shouldRepaint(_BatteryRingPainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.color != color;
  }
}

/// Online status enum
enum OnlineStatus { online, idle, offline, pending }

/// Online status indicator with gradient effect
class _OnlineStatusIndicator extends StatelessWidget {
  final OnlineStatus status;
  final double size;

  const _OnlineStatusIndicator({required this.status, required this.size});

  Color _getStatusColor() {
    switch (status) {
      case OnlineStatus.online:
        return AccentColors.green;
      case OnlineStatus.idle:
        return Colors.orange;
      case OnlineStatus.offline:
        return Colors.grey;
      case OnlineStatus.pending:
        return Colors.yellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [statusColor, statusColor.withValues(alpha: 0.7)],
        ),
        border: Border.all(color: context.background, width: size * 0.15),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Container(
        margin: EdgeInsets.all(size * 0.2),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
      ),
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
  final bool showGradientBorder;
  final List<Color>? gradientColors;
  final OnlineStatus? onlineStatus;
  final bool showOnlineIndicator;
  final int? batteryLevel;
  final bool showBatteryBadge;

  const NodeAvatarWithFallback({
    super.key,
    required this.text,
    this.avatarColor,
    this.size = 56,
    this.border,
    this.badge,
    this.fallbackColor = AppTheme.graphPurple,
    this.showGradientBorder = false,
    this.gradientColors,
    this.onlineStatus,
    this.showOnlineIndicator = false,
    this.batteryLevel,
    this.showBatteryBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return NodeAvatar(
      text: text,
      color: avatarColor != null ? Color(avatarColor!) : fallbackColor,
      size: size,
      border: border,
      badge: badge,
      showGradientBorder: showGradientBorder,
      gradientColors: gradientColors,
      onlineStatus: onlineStatus,
      showOnlineIndicator: showOnlineIndicator,
      batteryLevel: batteryLevel,
      showBatteryBadge: showBatteryBadge,
    );
  }
}
