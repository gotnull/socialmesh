import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// Shared animated background with floating mesh/radio icons.
/// Used by onboarding, connecting screen, and splash screen.
class FloatingIconsBackground extends StatefulWidget {
  /// Optional page offset for parallax scrolling effect (0.0 = no offset)
  final double pageOffset;

  /// Accent color for the gradient (defaults to primaryMagenta)
  final Color? accentColor;

  const FloatingIconsBackground({
    super.key,
    this.pageOffset = 0.0,
    this.accentColor,
  });

  @override
  State<FloatingIconsBackground> createState() =>
      _FloatingIconsBackgroundState();
}

class _FloatingIconsBackgroundState extends State<FloatingIconsBackground>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _pulseController;

  static const List<_FloatingIconData> _icons = [
    _FloatingIconData(
      icon: Icons.router,
      color: AccentColors.green,
      size: 44,
      startX: 0.08,
      startY: 0.12,
      parallaxFactor: 0.8,
      floatAmplitude: 18,
      floatSpeed: 1.2,
    ),
    _FloatingIconData(
      icon: Icons.wifi_tethering,
      color: AppTheme.primaryMagenta,
      size: 38,
      startX: 0.88,
      startY: 0.1,
      parallaxFactor: 1.2,
      floatAmplitude: 22,
      floatSpeed: 0.9,
    ),
    _FloatingIconData(
      icon: Icons.cell_tower,
      color: AppTheme.graphBlue,
      size: 48,
      startX: 0.78,
      startY: 0.78,
      parallaxFactor: 0.6,
      floatAmplitude: 16,
      floatSpeed: 1.4,
    ),
    _FloatingIconData(
      icon: Icons.bluetooth,
      color: AppTheme.graphBlue,
      colorAlpha: 0.8,
      size: 34,
      startX: 0.12,
      startY: 0.72,
      parallaxFactor: 1.0,
      floatAmplitude: 20,
      floatSpeed: 1.1,
    ),
    _FloatingIconData(
      icon: Icons.signal_cellular_alt,
      color: AccentColors.green,
      colorAlpha: 0.7,
      size: 30,
      startX: 0.92,
      startY: 0.42,
      parallaxFactor: 1.4,
      floatAmplitude: 14,
      floatSpeed: 1.3,
    ),
    _FloatingIconData(
      icon: Icons.sensors,
      color: AppTheme.warningYellow,
      size: 40,
      startX: 0.04,
      startY: 0.42,
      parallaxFactor: 0.7,
      floatAmplitude: 24,
      floatSpeed: 0.8,
    ),
    _FloatingIconData(
      icon: Icons.radio,
      color: AppTheme.primaryMagenta,
      colorAlpha: 0.6,
      size: 36,
      startX: 0.65,
      startY: 0.06,
      parallaxFactor: 1.1,
      floatAmplitude: 18,
      floatSpeed: 1.0,
    ),
    _FloatingIconData(
      icon: Icons.hub,
      color: AppTheme.textSecondary,
      size: 32,
      startX: 0.28,
      startY: 0.88,
      parallaxFactor: 0.9,
      floatAmplitude: 22,
      floatSpeed: 1.2,
    ),
    _FloatingIconData(
      icon: Icons.device_hub,
      color: AccentColors.green,
      colorAlpha: 0.5,
      size: 28,
      startX: 0.48,
      startY: 0.18,
      parallaxFactor: 1.3,
      floatAmplitude: 14,
      floatSpeed: 0.95,
    ),
    _FloatingIconData(
      icon: Icons.podcasts,
      color: AppTheme.graphBlue,
      colorAlpha: 0.6,
      size: 38,
      startX: 0.18,
      startY: 0.32,
      parallaxFactor: 0.5,
      floatAmplitude: 26,
      floatSpeed: 0.7,
    ),
    _FloatingIconData(
      icon: Icons.lan,
      color: AppTheme.primaryPurple,
      colorAlpha: 0.5,
      size: 32,
      startX: 0.82,
      startY: 0.58,
      parallaxFactor: 0.85,
      floatAmplitude: 20,
      floatSpeed: 1.15,
    ),
    _FloatingIconData(
      icon: Icons.satellite_alt,
      color: AppTheme.warningYellow,
      colorAlpha: 0.5,
      size: 36,
      startX: 0.38,
      startY: 0.68,
      parallaxFactor: 1.05,
      floatAmplitude: 18,
      floatSpeed: 0.85,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor ?? AppTheme.primaryMagenta;
    final size = MediaQuery.sizeOf(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Animated gradient background
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            // Stronger accent visibility in light mode
            final accentAlpha = isDarkMode ? 0.12 : 0.18;

            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    -0.5 + (widget.pageOffset * 0.3),
                    -0.3 + (widget.pageOffset * 0.1),
                  ),
                  radius: 1.5 + (_pulseController.value * 0.2),
                  colors: [
                    accentColor.withValues(alpha: accentAlpha),
                    context.background.withValues(alpha: 0.98),
                    context.background,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            );
          },
        ),

        // Floating icons with parallax effect
        ..._icons.map((iconData) => _buildFloatingIcon(iconData, size)),
      ],
    );
  }

  Widget _buildFloatingIcon(_FloatingIconData iconData, Size screenSize) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatController, _pulseController]),
      builder: (context, child) {
        // Get top padding to adjust for status bar offset
        final topPadding = MediaQuery.paddingOf(context).top;
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        // Calculate floating position with parallax
        final time = _floatController.value * 2 * math.pi * iconData.floatSpeed;
        final floatX =
            math.sin(time) * iconData.floatAmplitude * iconData.parallaxFactor;
        final floatY =
            math.cos(time * 0.7) *
            iconData.floatAmplitude *
            iconData.parallaxFactor;

        // Add page-based parallax movement
        final pageParallaxX = widget.pageOffset * 30 * iconData.parallaxFactor;

        // Subtle rotation
        final rotation = math.sin(time * 0.5) * 0.1;

        // Opacity pulse - higher opacity in light mode for visibility
        final baseOpacity = isDarkMode ? 0.3 : 0.5;
        final pulseRange = isDarkMode ? 0.25 : 0.3;
        final opacity = baseOpacity + (_pulseController.value * pulseRange);

        // Use darker version of color in light mode for better contrast
        var baseColor = iconData.color;
        // Replace textSecondary (light gray) with a more visible color in light mode
        if (baseColor == AppTheme.textSecondary && !isDarkMode) {
          baseColor = AppTheme.graphBlue;
        }

        final effectiveAlpha = isDarkMode
            ? opacity * iconData.colorAlpha
            : opacity * math.min(iconData.colorAlpha + 0.3, 1.0);

        final colorWithAlpha = baseColor.withValues(alpha: effectiveAlpha);

        // Position relative to screen, but Stack may start below status bar
        // So subtract topPadding to compensate
        return Positioned(
          left:
              screenSize.width * iconData.startX +
              floatX -
              pageParallaxX -
              iconData.size / 2,
          top:
              screenSize.height * iconData.startY +
              floatY -
              iconData.size / 2 -
              topPadding,
          child: Transform.rotate(
            angle: rotation,
            child: Icon(
              iconData.icon,
              size: iconData.size,
              color: colorWithAlpha,
            ),
          ),
        );
      },
    );
  }
}

class _FloatingIconData {
  final IconData icon;
  final Color color;
  final double colorAlpha;
  final double size;
  final double startX;
  final double startY;
  final double parallaxFactor;
  final double floatAmplitude;
  final double floatSpeed;

  const _FloatingIconData({
    required this.icon,
    required this.color,
    this.colorAlpha = 1.0,
    required this.size,
    required this.startX,
    required this.startY,
    required this.parallaxFactor,
    required this.floatAmplitude,
    required this.floatSpeed,
  });
}
