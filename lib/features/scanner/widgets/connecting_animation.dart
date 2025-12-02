import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Beautiful parallax-style connecting animation with floating icons
class ConnectingAnimation extends StatefulWidget {
  final String statusText;
  final VoidCallback? onCancel;
  final bool showCancel;

  const ConnectingAnimation({
    super.key,
    this.statusText = 'Connecting...',
    this.onCancel,
    this.showCancel = false,
  });

  @override
  State<ConnectingAnimation> createState() => _ConnectingAnimationState();
}

class _ConnectingAnimationState extends State<ConnectingAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _pulseController;
  late final List<_FloatingIcon> _icons;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Initialize floating icons with mesh/radio themed icons
    _icons = [
      _FloatingIcon(
        icon: Icons.router,
        color: AppTheme.primaryGreen,
        size: 48,
        startX: 0.1,
        startY: 0.15,
        parallaxFactor: 0.8,
        floatAmplitude: 20,
        floatSpeed: 1.2,
      ),
      _FloatingIcon(
        icon: Icons.wifi_tethering,
        color: AppTheme.primaryMagenta,
        size: 40,
        startX: 0.85,
        startY: 0.12,
        parallaxFactor: 1.2,
        floatAmplitude: 25,
        floatSpeed: 0.9,
      ),
      _FloatingIcon(
        icon: Icons.cell_tower,
        color: AppTheme.graphBlue,
        size: 52,
        startX: 0.75,
        startY: 0.75,
        parallaxFactor: 0.6,
        floatAmplitude: 18,
        floatSpeed: 1.4,
      ),
      _FloatingIcon(
        icon: Icons.bluetooth,
        color: AppTheme.graphBlue.withValues(alpha: 0.8),
        size: 36,
        startX: 0.15,
        startY: 0.7,
        parallaxFactor: 1.0,
        floatAmplitude: 22,
        floatSpeed: 1.1,
      ),
      _FloatingIcon(
        icon: Icons.signal_cellular_alt,
        color: AppTheme.primaryGreen.withValues(alpha: 0.7),
        size: 32,
        startX: 0.9,
        startY: 0.45,
        parallaxFactor: 1.4,
        floatAmplitude: 15,
        floatSpeed: 1.3,
      ),
      _FloatingIcon(
        icon: Icons.sensors,
        color: AppTheme.warningYellow,
        size: 44,
        startX: 0.05,
        startY: 0.45,
        parallaxFactor: 0.7,
        floatAmplitude: 28,
        floatSpeed: 0.8,
      ),
      _FloatingIcon(
        icon: Icons.radio,
        color: AppTheme.primaryMagenta.withValues(alpha: 0.6),
        size: 38,
        startX: 0.6,
        startY: 0.08,
        parallaxFactor: 1.1,
        floatAmplitude: 20,
        floatSpeed: 1.0,
      ),
      _FloatingIcon(
        icon: Icons.hub,
        color: AppTheme.textSecondary,
        size: 34,
        startX: 0.3,
        startY: 0.85,
        parallaxFactor: 0.9,
        floatAmplitude: 24,
        floatSpeed: 1.2,
      ),
      _FloatingIcon(
        icon: Icons.device_hub,
        color: AppTheme.primaryGreen.withValues(alpha: 0.5),
        size: 30,
        startX: 0.5,
        startY: 0.2,
        parallaxFactor: 1.3,
        floatAmplitude: 16,
        floatSpeed: 0.95,
      ),
      _FloatingIcon(
        icon: Icons.podcasts,
        color: AppTheme.graphBlue.withValues(alpha: 0.6),
        size: 42,
        startX: 0.2,
        startY: 0.35,
        parallaxFactor: 0.5,
        floatAmplitude: 30,
        floatSpeed: 0.7,
      ),
    ];
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Animated background gradient
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2 + (_pulseController.value * 0.3),
                  colors: [
                    AppTheme.primaryGreen.withValues(alpha: 0.08),
                    AppTheme.darkBackground.withValues(alpha: 0.95),
                    AppTheme.darkBackground,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            );
          },
        ),

        // Floating icons with parallax effect
        ..._icons.map((iconData) => _buildFloatingIcon(iconData, size)),

        // Center content
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status text
              Text(
                widget.statusText,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 12),
              // Animated dots
              _AnimatedDots(),
              if (widget.showCancel) ...[
                const SizedBox(height: 32),
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingIcon(_FloatingIcon iconData, Size screenSize) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatController, _pulseController]),
      builder: (context, child) {
        // Calculate floating position with parallax
        final time = _floatController.value * 2 * math.pi * iconData.floatSpeed;
        final floatX =
            math.sin(time) * iconData.floatAmplitude * iconData.parallaxFactor;
        final floatY =
            math.cos(time * 0.7) *
            iconData.floatAmplitude *
            iconData.parallaxFactor;

        // Subtle rotation
        final rotation = math.sin(time * 0.5) * 0.1;

        // Opacity pulse
        final opacity = 0.4 + (_pulseController.value * 0.3);

        return Positioned(
          left: screenSize.width * iconData.startX + floatX - iconData.size / 2,
          top: screenSize.height * iconData.startY + floatY - iconData.size / 2,
          child: Transform.rotate(
            angle: rotation,
            child: Icon(
              iconData.icon,
              size: iconData.size,
              color: iconData.color.withValues(alpha: opacity),
            ),
          ),
        );
      },
    );
  }
}

class _FloatingIcon {
  final IconData icon;
  final Color color;
  final double size;
  final double startX;
  final double startY;
  final double parallaxFactor;
  final double floatAmplitude;
  final double floatSpeed;

  const _FloatingIcon({
    required this.icon,
    required this.color,
    required this.size,
    required this.startX,
    required this.startY,
    required this.parallaxFactor,
    required this.floatAmplitude,
    required this.floatSpeed,
  });
}

class _AnimatedDots extends StatefulWidget {
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final progress = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = math.sin(progress * math.pi);

            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGreen.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Background-only version with floating icons (no center content)
/// Use this as a background layer behind other content
class ConnectingAnimationBackground extends StatefulWidget {
  const ConnectingAnimationBackground({super.key});

  @override
  State<ConnectingAnimationBackground> createState() =>
      _ConnectingAnimationBackgroundState();
}

class _ConnectingAnimationBackgroundState
    extends State<ConnectingAnimationBackground>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _pulseController;
  late final List<_FloatingIcon> _icons;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Initialize floating icons with mesh/radio themed icons
    _icons = [
      _FloatingIcon(
        icon: Icons.router,
        color: AppTheme.primaryGreen,
        size: 48,
        startX: 0.1,
        startY: 0.15,
        parallaxFactor: 0.8,
        floatAmplitude: 20,
        floatSpeed: 1.2,
      ),
      _FloatingIcon(
        icon: Icons.wifi_tethering,
        color: AppTheme.primaryMagenta,
        size: 40,
        startX: 0.85,
        startY: 0.12,
        parallaxFactor: 1.2,
        floatAmplitude: 25,
        floatSpeed: 0.9,
      ),
      _FloatingIcon(
        icon: Icons.cell_tower,
        color: AppTheme.graphBlue,
        size: 52,
        startX: 0.75,
        startY: 0.75,
        parallaxFactor: 0.6,
        floatAmplitude: 18,
        floatSpeed: 1.4,
      ),
      _FloatingIcon(
        icon: Icons.bluetooth,
        color: AppTheme.graphBlue.withValues(alpha: 0.8),
        size: 36,
        startX: 0.15,
        startY: 0.7,
        parallaxFactor: 1.0,
        floatAmplitude: 22,
        floatSpeed: 1.1,
      ),
      _FloatingIcon(
        icon: Icons.signal_cellular_alt,
        color: AppTheme.primaryGreen.withValues(alpha: 0.7),
        size: 32,
        startX: 0.9,
        startY: 0.45,
        parallaxFactor: 1.4,
        floatAmplitude: 15,
        floatSpeed: 1.3,
      ),
      _FloatingIcon(
        icon: Icons.sensors,
        color: AppTheme.warningYellow,
        size: 44,
        startX: 0.05,
        startY: 0.45,
        parallaxFactor: 0.7,
        floatAmplitude: 28,
        floatSpeed: 0.8,
      ),
      _FloatingIcon(
        icon: Icons.radio,
        color: AppTheme.primaryMagenta.withValues(alpha: 0.6),
        size: 38,
        startX: 0.6,
        startY: 0.08,
        parallaxFactor: 1.1,
        floatAmplitude: 20,
        floatSpeed: 1.0,
      ),
      _FloatingIcon(
        icon: Icons.hub,
        color: AppTheme.textSecondary,
        size: 34,
        startX: 0.3,
        startY: 0.85,
        parallaxFactor: 0.9,
        floatAmplitude: 24,
        floatSpeed: 1.2,
      ),
      _FloatingIcon(
        icon: Icons.device_hub,
        color: AppTheme.primaryGreen.withValues(alpha: 0.5),
        size: 30,
        startX: 0.5,
        startY: 0.2,
        parallaxFactor: 1.3,
        floatAmplitude: 16,
        floatSpeed: 0.95,
      ),
      _FloatingIcon(
        icon: Icons.podcasts,
        color: AppTheme.graphBlue.withValues(alpha: 0.6),
        size: 42,
        startX: 0.2,
        startY: 0.35,
        parallaxFactor: 0.5,
        floatAmplitude: 30,
        floatSpeed: 0.7,
      ),
    ];
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Animated background gradient
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2 + (_pulseController.value * 0.3),
                  colors: [
                    AppTheme.primaryGreen.withValues(alpha: 0.08),
                    AppTheme.darkBackground.withValues(alpha: 0.95),
                    AppTheme.darkBackground,
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

  Widget _buildFloatingIcon(_FloatingIcon iconData, Size screenSize) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatController, _pulseController]),
      builder: (context, child) {
        // Calculate floating position with parallax
        final time = _floatController.value * 2 * math.pi * iconData.floatSpeed;
        final floatX =
            math.sin(time) * iconData.floatAmplitude * iconData.parallaxFactor;
        final floatY =
            math.cos(time * 0.7) *
            iconData.floatAmplitude *
            iconData.parallaxFactor;

        // Subtle rotation
        final rotation = math.sin(time * 0.5) * 0.1;

        // Opacity pulse
        final opacity = 0.4 + (_pulseController.value * 0.3);

        return Positioned(
          left: screenSize.width * iconData.startX + floatX - iconData.size / 2,
          top: screenSize.height * iconData.startY + floatY - iconData.size / 2,
          child: Transform.rotate(
            angle: rotation,
            child: Icon(
              iconData.icon,
              size: iconData.size,
              color: iconData.color.withValues(alpha: opacity),
            ),
          ),
        );
      },
    );
  }
}
