import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme.dart';

/// Amiga demoscene-inspired animated background.
/// Features: copper bars, starfield, sine wave bobs, and scanlines.
class DemosceneBackground extends StatefulWidget {
  /// Optional page offset for parallax scrolling effect
  final double pageOffset;

  /// Accent color for effects (defaults to primaryMagenta)
  final Color? accentColor;

  /// Whether to show the starfield layer
  final bool showStarfield;

  /// Whether to show the copper bars layer
  final bool showCopperBars;

  /// Whether to show the sine wave bobs layer
  final bool showSineWaveBobs;

  /// Whether to show CRT scanline overlay
  final bool showScanlines;

  const DemosceneBackground({
    super.key,
    this.pageOffset = 0.0,
    this.accentColor,
    this.showStarfield = true,
    this.showCopperBars = true,
    this.showSineWaveBobs = true,
    this.showScanlines = true,
  });

  @override
  State<DemosceneBackground> createState() => _DemosceneBackgroundState();
}

class _DemosceneBackgroundState extends State<DemosceneBackground>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _copperController;
  late final AnimationController _starfieldController;

  // Starfield data - pre-generated for performance
  late final List<_Star> _stars;

  // Sine wave bob data
  static const List<_BobData> _bobs = [
    _BobData(
      icon: Icons.router,
      color: AccentColors.green,
      size: 36,
      phase: 0.0,
      amplitude: 0.15,
      speed: 1.0,
      yOffset: 0.2,
    ),
    _BobData(
      icon: Icons.wifi_tethering,
      color: AppTheme.primaryMagenta,
      size: 32,
      phase: 0.5,
      amplitude: 0.12,
      speed: 1.3,
      yOffset: 0.35,
    ),
    _BobData(
      icon: Icons.cell_tower,
      color: AppTheme.graphBlue,
      size: 40,
      phase: 1.0,
      amplitude: 0.18,
      speed: 0.8,
      yOffset: 0.5,
    ),
    _BobData(
      icon: Icons.bluetooth,
      color: AppTheme.graphBlue,
      size: 28,
      phase: 1.5,
      amplitude: 0.1,
      speed: 1.5,
      yOffset: 0.65,
    ),
    _BobData(
      icon: Icons.sensors,
      color: AppTheme.warningYellow,
      size: 34,
      phase: 2.0,
      amplitude: 0.14,
      speed: 1.1,
      yOffset: 0.8,
    ),
    _BobData(
      icon: Icons.radio,
      color: AppTheme.primaryMagenta,
      size: 30,
      phase: 2.5,
      amplitude: 0.16,
      speed: 0.9,
      yOffset: 0.25,
    ),
    _BobData(
      icon: Icons.hub,
      color: AccentColors.green,
      size: 26,
      phase: 3.0,
      amplitude: 0.11,
      speed: 1.4,
      yOffset: 0.45,
    ),
    _BobData(
      icon: Icons.satellite_alt,
      color: AppTheme.warningYellow,
      size: 32,
      phase: 3.5,
      amplitude: 0.13,
      speed: 1.2,
      yOffset: 0.7,
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Main animation controller for coordinated effects
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Copper bars cycle faster for that classic effect
    _copperController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Starfield moves continuously
    _starfieldController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // Generate starfield
    _stars = _generateStars(150);
  }

  List<_Star> _generateStars(int count) {
    final random = math.Random(42); // Fixed seed for consistency
    return List.generate(count, (index) {
      return _Star(
        x: random.nextDouble(),
        y: random.nextDouble(),
        z: random.nextDouble() * 0.8 + 0.2, // 0.2 to 1.0 for depth
        brightness: random.nextDouble() * 0.5 + 0.5,
      );
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _copperController.dispose();
    _starfieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        // Base dark background
        Container(color: AppTheme.darkBackground),

        // Copper bars layer
        if (widget.showCopperBars)
          AnimatedBuilder(
            animation: _copperController,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: _CopperBarsPainter(
                  progress: _copperController.value,
                  pageOffset: widget.pageOffset,
                  accentColor: widget.accentColor ?? AppTheme.primaryMagenta,
                ),
              );
            },
          ),

        // Starfield layer
        if (widget.showStarfield)
          AnimatedBuilder(
            animation: _starfieldController,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: _StarfieldPainter(
                  stars: _stars,
                  progress: _starfieldController.value,
                  pageOffset: widget.pageOffset,
                ),
              );
            },
          ),

        // Sine wave bobs layer
        if (widget.showSineWaveBobs)
          AnimatedBuilder(
            animation: _mainController,
            builder: (context, child) {
              return Stack(
                children: _bobs
                    .map((bob) => _buildSineWaveBob(bob, size))
                    .toList(),
              );
            },
          ),

        // CRT scanline overlay
        if (widget.showScanlines)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ScanlinesPainter(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSineWaveBob(_BobData bob, Size screenSize) {
    final time = _mainController.value * 2 * math.pi * bob.speed;

    // Classic sine wave movement across screen
    final sineX = math.sin(time + bob.phase) * screenSize.width * bob.amplitude;

    // Secondary vertical sine for Lissajous-like motion
    final sineY = math.cos(time * 0.7 + bob.phase) * 20;

    // Bob position moves horizontally in sine pattern
    final baseX = screenSize.width * 0.5 + sineX;
    final baseY = screenSize.height * bob.yOffset + sineY;

    // Gentle rotation
    final rotation = math.sin(time * 0.5 + bob.phase) * 0.3;

    // Pulsing opacity and scale for that demoscene feel
    final pulse = 0.6 + math.sin(time * 2 + bob.phase) * 0.2;
    final scale = 0.9 + math.sin(time * 1.5 + bob.phase) * 0.1;

    // Color cycling effect (subtle)
    final hueShift = math.sin(time * 0.3 + bob.phase) * 0.1;

    return Positioned(
      left: baseX - bob.size / 2 - widget.pageOffset * 30,
      top: baseY - bob.size / 2,
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale,
          child: _buildGlowingIcon(bob, pulse, hueShift),
        ),
      ),
    );
  }

  Widget _buildGlowingIcon(_BobData bob, double opacity, double hueShift) {
    // Apply subtle hue shift for color cycling
    final hsv = HSVColor.fromColor(bob.color);
    final shiftedColor =
        hsv.withHue((hsv.hue + hueShift * 360) % 360).toColor();

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          // Outer glow
          BoxShadow(
            color: shiftedColor.withValues(alpha: opacity * 0.4),
            blurRadius: bob.size * 0.8,
            spreadRadius: bob.size * 0.2,
          ),
          // Inner glow
          BoxShadow(
            color: shiftedColor.withValues(alpha: opacity * 0.6),
            blurRadius: bob.size * 0.3,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Icon(
        bob.icon,
        size: bob.size,
        color: shiftedColor.withValues(alpha: opacity),
      ),
    );
  }
}

/// Copper bars painter - creates horizontal animated color gradient bars
class _CopperBarsPainter extends CustomPainter {
  final double progress;
  final double pageOffset;
  final Color accentColor;

  _CopperBarsPainter({
    required this.progress,
    required this.pageOffset,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Classic Amiga copper bar colors
    final colors = [
      AppTheme.primaryMagenta,
      AppTheme.primaryPurple,
      AppTheme.graphBlue,
      AccentColors.green,
      AppTheme.warningYellow,
      Colors.orange,
      Colors.red,
      AppTheme.primaryMagenta,
    ];

    const barCount = 12;
    final barHeight = size.height / barCount;

    for (int i = 0; i < barCount; i++) {
      // Sine wave offset for each bar creates the flowing effect
      final wave = math.sin(progress * 2 * math.pi + i * 0.5) * 0.5 + 0.5;
      final colorIndex = ((i + progress * colors.length) % colors.length);
      final colorIndexInt = colorIndex.floor();
      final colorBlend = colorIndex - colorIndexInt;

      // Interpolate between colors for smooth transitions
      final color1 = colors[colorIndexInt % colors.length];
      final color2 = colors[(colorIndexInt + 1) % colors.length];
      final blendedColor = Color.lerp(color1, color2, colorBlend)!;

      // Calculate bar opacity based on position and wave
      final opacity = 0.08 + wave * 0.07;

      // Gradient for each bar (brighter in middle)
      final barY = i * barHeight;
      final gradient = ui.Gradient.linear(
        Offset(0, barY),
        Offset(0, barY + barHeight),
        [
          blendedColor.withValues(alpha: opacity * 0.3),
          blendedColor.withValues(alpha: opacity),
          blendedColor.withValues(alpha: opacity * 0.3),
        ],
        [0.0, 0.5, 1.0],
      );

      paint.shader = gradient;
      canvas.drawRect(
        Rect.fromLTWH(0, barY, size.width, barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CopperBarsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pageOffset != pageOffset;
  }
}

/// Starfield painter - creates a 3D star field zooming effect
class _StarfieldPainter extends CustomPainter {
  final List<_Star> stars;
  final double progress;
  final double pageOffset;

  _StarfieldPainter({
    required this.stars,
    required this.progress,
    required this.pageOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2 - pageOffset * 20;
    final centerY = size.height / 2;

    for (final star in stars) {
      // Simulate z-movement (stars coming towards viewer)
      final z = (star.z + progress) % 1.0;
      final invertedZ = 1.0 - z; // Closer stars have lower z after inversion

      // Project 3D position to 2D (perspective projection)
      final scale = 1.0 / (invertedZ + 0.1);
      final projectedX = centerX + (star.x - 0.5) * size.width * scale * 0.8;
      final projectedY = centerY + (star.y - 0.5) * size.height * scale * 0.8;

      // Skip if outside screen
      if (projectedX < -10 ||
          projectedX > size.width + 10 ||
          projectedY < -10 ||
          projectedY > size.height + 10) {
        continue;
      }

      // Star size and brightness based on z-depth
      final starSize = (1.0 - invertedZ) * 3.0 + 0.5;
      final brightness = star.brightness * (1.0 - invertedZ * 0.5);

      // Draw star with subtle trail for motion blur effect
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: brightness * 0.8)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = starSize;

      // Motion trail (line towards center)
      final trailLength = starSize * 3 * (1.0 - invertedZ);
      final dx = (projectedX - centerX).sign * trailLength;
      final dy = (projectedY - centerY).sign * trailLength;

      canvas.drawLine(
        Offset(projectedX, projectedY),
        Offset(projectedX - dx * 0.5, projectedY - dy * 0.5),
        paint,
      );

      // Brighter star point
      paint.color = Colors.white.withValues(alpha: brightness);
      canvas.drawCircle(
        Offset(projectedX, projectedY),
        starSize * 0.6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pageOffset != pageOffset;
  }
}

/// CRT scanline overlay painter
class _ScanlinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.08);

    // Draw horizontal scanlines every 3 pixels for subtle CRT effect
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 1),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScanlinesPainter oldDelegate) => false;
}

/// Star data for starfield
class _Star {
  final double x; // 0.0 to 1.0
  final double y; // 0.0 to 1.0
  final double z; // 0.0 to 1.0 (depth)
  final double brightness; // 0.0 to 1.0

  const _Star({
    required this.x,
    required this.y,
    required this.z,
    required this.brightness,
  });
}

/// Bob data for sine wave icons
class _BobData {
  final IconData icon;
  final Color color;
  final double size;
  final double phase; // Phase offset in radians
  final double amplitude; // Movement amplitude as fraction of screen width
  final double speed; // Animation speed multiplier
  final double yOffset; // Vertical position as fraction of screen height

  const _BobData({
    required this.icon,
    required this.color,
    required this.size,
    required this.phase,
    required this.amplitude,
    required this.speed,
    required this.yOffset,
  });
}
