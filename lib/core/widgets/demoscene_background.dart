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

  // Mesh network nodes - positioned around the screen
  late final List<_MeshNode> _meshNodes;

  @override
  void initState() {
    super.initState();

    // Main animation controller for coordinated effects
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Copper bars cycle faster for that classic effect
    _copperController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Starfield moves continuously
    _starfieldController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // Generate starfield
    _stars = _generateStars(120);

    // Generate mesh network nodes
    _meshNodes = _generateMeshNodes();
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

  List<_MeshNode> _generateMeshNodes() {
    // Create nodes in a distributed pattern
    return [
      _MeshNode(
        baseX: 0.15,
        baseY: 0.18,
        icon: Icons.router,
        color: AccentColors.green,
        size: 32,
        phase: 0.0,
      ),
      _MeshNode(
        baseX: 0.85,
        baseY: 0.15,
        icon: Icons.wifi_tethering,
        color: AppTheme.primaryMagenta,
        size: 28,
        phase: 0.7,
      ),
      _MeshNode(
        baseX: 0.5,
        baseY: 0.35,
        icon: Icons.cell_tower,
        color: AppTheme.graphBlue,
        size: 36,
        phase: 1.4,
      ),
      _MeshNode(
        baseX: 0.2,
        baseY: 0.55,
        icon: Icons.sensors,
        color: AppTheme.warningYellow,
        size: 26,
        phase: 2.1,
      ),
      _MeshNode(
        baseX: 0.75,
        baseY: 0.5,
        icon: Icons.bluetooth,
        color: AppTheme.graphBlue,
        size: 30,
        phase: 2.8,
      ),
      _MeshNode(
        baseX: 0.4,
        baseY: 0.72,
        icon: Icons.hub,
        color: AccentColors.green,
        size: 28,
        phase: 3.5,
      ),
      _MeshNode(
        baseX: 0.88,
        baseY: 0.75,
        icon: Icons.radio,
        color: AppTheme.primaryMagenta,
        size: 30,
        phase: 4.2,
      ),
      _MeshNode(
        baseX: 0.12,
        baseY: 0.85,
        icon: Icons.satellite_alt,
        color: AppTheme.warningYellow,
        size: 32,
        phase: 4.9,
      ),
    ];
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

        // 3D Perspective floor at bottom (Lawnmower Man style!)
        AnimatedBuilder(
          animation: _mainController,
          builder: (context, child) {
            return CustomPaint(
              size: size,
              painter: _PerspectiveFloorPainter(
                progress: _mainController.value,
                pageOffset: widget.pageOffset,
              ),
            );
          },
        ),

        // Copper bars layer (constrained band)
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

        // Mesh network layer - nodes connected with animated lines
        if (widget.showSineWaveBobs)
          AnimatedBuilder(
            animation: _mainController,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: _MeshNetworkPainter(
                  nodes: _meshNodes,
                  progress: _mainController.value,
                  pageOffset: widget.pageOffset,
                ),
              );
            },
          ),

        // CRT scanline overlay
        if (widget.showScanlines)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ScanlinesPainter()),
            ),
          ),
      ],
    );
  }
}

/// Copper bars painter - creates horizontal animated color gradient bars
/// with plasma-like undulation effect inspired by classic Amiga demos
/// Now contained to a band in the middle of the screen
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

    // Classic Amiga copper bar color palette - iconic demoscene colors
    final colors = [
      const Color(0xFFFF0080), // Hot pink
      const Color(0xFFFF00FF), // Magenta
      const Color(0xFF8000FF), // Purple
      const Color(0xFF0080FF), // Blue
      const Color(0xFF00FFFF), // Cyan
      const Color(0xFF00FF80), // Mint
      const Color(0xFF00FF00), // Green
      const Color(0xFF80FF00), // Yellow-green
      const Color(0xFFFFFF00), // Yellow
      const Color(0xFFFF8000), // Orange
      const Color(0xFFFF0000), // Red
      const Color(0xFFFF0080), // Back to pink
    ];

    // Constrain copper bars to middle band of screen
    const barCount = 8;
    final bandHeight = size.height * 0.25; // Only 25% of screen height
    final barHeight = bandHeight / barCount;
    final time = progress * math.pi * 2;

    // Animate the band position with a slow sine wave
    final bandY = size.height * 0.35 + math.sin(time * 0.3) * size.height * 0.1;

    for (int i = 0; i < barCount; i++) {
      // Plasma-like sine wave creates undulating color bands
      final wave1 = math.sin(time + i * 0.4);
      final wave2 = math.sin(time * 1.3 + i * 0.3);
      final combinedWave = (wave1 + wave2) / 2;

      // Calculate color index with plasma-like smoothness
      final colorProgress = (i / barCount + progress + combinedWave * 0.15);
      final colorIndex = (colorProgress * colors.length) % colors.length;
      final colorIndexInt = colorIndex.floor();
      final colorBlend = colorIndex - colorIndexInt;

      // Interpolate between colors for smooth rainbow transitions
      final color1 = colors[colorIndexInt % colors.length];
      final color2 = colors[(colorIndexInt + 1) % colors.length];
      final blendedColor = Color.lerp(color1, color2, colorBlend)!;

      // Intensity based on position in band (fade at edges)
      final posInBand = i / (barCount - 1);
      final edgeFade = math.sin(posInBand * math.pi); // 0 at edges, 1 in middle
      final intensity = (0.05 + (combinedWave * 0.5 + 0.5) * 0.06) * edgeFade;

      // Position with slight sine wave horizontal offset (raster effect)
      final barY = bandY + i * barHeight;
      final xOffset = math.sin(time * 2 + i * 0.3) * 8 - pageOffset * 0.5;

      // Create gradient for this bar - brighter center, faded edges
      final gradient = ui.Gradient.linear(
        Offset(xOffset, barY),
        Offset(xOffset, barY + barHeight),
        [
          blendedColor.withValues(alpha: intensity * 0.3),
          blendedColor.withValues(alpha: intensity),
          blendedColor.withValues(alpha: intensity * 0.3),
        ],
        [0.0, 0.5, 1.0],
      );

      paint.shader = gradient;
      canvas.drawRect(
        Rect.fromLTWH(0, barY, size.width, barHeight * 1.2),
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

/// 3D Perspective floor painter - Lawnmower Man / early 90s demo style
/// Creates a scrolling grid floor with rotating turbine/gear element
class _PerspectiveFloorPainter extends CustomPainter {
  final double progress;
  final double pageOffset;

  _PerspectiveFloorPainter({required this.progress, required this.pageOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final floorTop = size.height * 0.72; // Floor starts at 72% down
    final floorHeight = size.height - floorTop;
    final centerX = size.width / 2 - pageOffset * 10;
    final horizon = floorTop;
    final time = progress * math.pi * 2;

    // Save canvas state for clipping
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, floorTop, size.width, floorHeight));

    // Draw perspective grid
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Scrolling offset for forward motion effect
    final scrollOffset = (progress * 8) % 1.0;

    // Draw horizontal lines (receding into distance)
    const horizontalLines = 12;
    for (int i = 0; i <= horizontalLines; i++) {
      // Perspective: lines closer together near horizon
      final t = (i + scrollOffset) / horizontalLines;
      final perspectiveT = math.pow(t, 2.2); // Non-linear for perspective
      final y = horizon + perspectiveT * floorHeight;

      // Fade based on distance (closer = brighter)
      final brightness = t * 0.5;
      final hue = (time * 0.1 + t * 0.3) % 1.0;

      gridPaint.color = HSVColor.fromAHSV(
        brightness,
        hue * 360,
        0.8,
        1.0,
      ).toColor();

      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw vertical lines (converging to vanishing point)
    const verticalLines = 16;
    for (int i = -verticalLines ~/ 2; i <= verticalLines ~/ 2; i++) {
      // Lines converge at center horizon
      final xAtHorizon = centerX;
      final xAtBottom = centerX + i * (size.width / verticalLines) * 1.5;

      // Fade based on distance from center
      final distFromCenter = (i.abs() / (verticalLines / 2));
      final brightness = (1.0 - distFromCenter * 0.5) * 0.4;
      final hue = (time * 0.15 + distFromCenter * 0.2) % 1.0;

      gridPaint.color = HSVColor.fromAHSV(
        brightness,
        hue * 360,
        0.7,
        1.0,
      ).toColor();

      canvas.drawLine(
        Offset(xAtHorizon, horizon),
        Offset(xAtBottom, size.height),
        gridPaint,
      );
    }

    canvas.restore();

    // Draw rotating 3D turbine/gear at the horizon
    _drawTurbine(canvas, size, centerX, horizon, time);
  }

  void _drawTurbine(
    Canvas canvas,
    Size size,
    double centerX,
    double horizon,
    double time,
  ) {
    final turbineY = horizon + 15;
    final turbineRadius = size.width * 0.12;

    // Rotation angle
    final rotation = time * 1.5;

    canvas.save();
    canvas.translate(centerX, turbineY);
    canvas.rotate(rotation);

    // Draw gear teeth / turbine blades
    const bladeCount = 8;
    final bladePaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < bladeCount; i++) {
      final angle = (i / bladeCount) * math.pi * 2;

      // Blade gradient based on angle for 3D effect
      final depth = math.cos(angle + rotation * 0.5) * 0.5 + 0.5;
      final brightness = 0.3 + depth * 0.4;

      // Cycle through demoscene colors
      final hue = ((i / bladeCount) + progress * 0.5) % 1.0;
      bladePaint.color = HSVColor.fromAHSV(
        brightness,
        hue * 360,
        0.8,
        1.0,
      ).toColor();

      // Draw blade as a tapered shape
      final innerRadius = turbineRadius * 0.3;
      final outerRadius = turbineRadius;
      final bladeWidth = math.pi / bladeCount * 0.7;

      final path = Path();
      path.moveTo(
        math.cos(angle - bladeWidth * 0.3) * innerRadius,
        math.sin(angle - bladeWidth * 0.3) * innerRadius,
      );
      path.lineTo(
        math.cos(angle - bladeWidth) * outerRadius,
        math.sin(angle - bladeWidth) * outerRadius,
      );
      path.lineTo(
        math.cos(angle + bladeWidth) * outerRadius,
        math.sin(angle + bladeWidth) * outerRadius,
      );
      path.lineTo(
        math.cos(angle + bladeWidth * 0.3) * innerRadius,
        math.sin(angle + bladeWidth * 0.3) * innerRadius,
      );
      path.close();

      canvas.drawPath(path, bladePaint);
    }

    // Center hub with glow
    final hubPaint = Paint()
      ..color = AppTheme.primaryMagenta.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset.zero, turbineRadius * 0.25, hubPaint);

    hubPaint
      ..color = Colors.white.withValues(alpha: 0.9)
      ..maskFilter = null;
    canvas.drawCircle(Offset.zero, turbineRadius * 0.15, hubPaint);

    // Inner detail ring
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppTheme.primaryMagenta.withValues(alpha: 0.6);
    canvas.drawCircle(Offset.zero, turbineRadius * 0.5, ringPaint);

    canvas.restore();

    // Add glow effect behind turbine
    final glowPaint = Paint()
      ..color = AppTheme.primaryMagenta.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(
      Offset(centerX, turbineY),
      turbineRadius * 1.2,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(_PerspectiveFloorPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pageOffset != pageOffset;
  }
}

/// Starfield painter - creates a 3D star field zooming effect
/// Classic demoscene starfield with streak trails
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
    final centerX = size.width / 2 - pageOffset * 30;
    final centerY = size.height / 2;

    for (final star in stars) {
      // Simulate z-movement (stars coming towards viewer)
      final z = (star.z + progress * 2) % 1.0;
      final invertedZ = 1.0 - z; // Closer stars have lower z after inversion

      // Skip very distant stars for performance
      if (invertedZ > 0.95) continue;

      // Project 3D position to 2D (perspective projection)
      final perspectiveScale = 1.0 / (invertedZ + 0.05);
      final projectedX =
          centerX + (star.x - 0.5) * size.width * perspectiveScale * 0.9;
      final projectedY =
          centerY + (star.y - 0.5) * size.height * perspectiveScale * 0.9;

      // Skip if outside screen
      if (projectedX < -20 ||
          projectedX > size.width + 20 ||
          projectedY < -20 ||
          projectedY > size.height + 20) {
        continue;
      }

      // Star size and brightness based on z-depth
      // Closer stars are bigger and brighter
      final starSize = (1.0 - invertedZ) * 4.0 + 0.3;
      final brightness = star.brightness * (1.0 - invertedZ * 0.3);

      // Calculate velocity direction (away from center)
      final dx = projectedX - centerX;
      final dy = projectedY - centerY;
      final dist = math.sqrt(dx * dx + dy * dy);
      final normalizedDx = dist > 0 ? dx / dist : 0.0;
      final normalizedDy = dist > 0 ? dy / dist : 0.0;

      // Motion trail length based on proximity
      final trailLength = starSize * 6 * (1.0 - invertedZ);

      // Draw motion streak with gradient
      final trailPaint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = starSize * 0.8;

      // Draw trail with fading opacity
      for (int t = 4; t >= 0; t--) {
        final trailFactor = t / 4.0;
        final tx = projectedX - normalizedDx * trailLength * trailFactor;
        final ty = projectedY - normalizedDy * trailLength * trailFactor;

        trailPaint.color = Colors.white.withValues(
          alpha: brightness * (1.0 - trailFactor) * 0.4,
        );
        canvas.drawCircle(
          Offset(tx, ty),
          starSize * (1.0 - trailFactor * 0.5),
          trailPaint,
        );
      }

      // Bright star point with subtle color tint
      final starPaint = Paint()
        ..color = Color.lerp(
          Colors.white,
          star.brightness > 0.7
              ? const Color(0xFF88CCFF)
              : const Color(0xFFFFFFCC),
          0.3,
        )!.withValues(alpha: brightness);
      canvas.drawCircle(
        Offset(projectedX, projectedY),
        starSize * 0.8,
        starPaint,
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
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.06);

    // Draw horizontal scanlines every 4 pixels for subtle CRT effect
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinesPainter oldDelegate) => false;
}

/// Mesh network painter - draws nodes and animated connecting lines
class _MeshNetworkPainter extends CustomPainter {
  final List<_MeshNode> nodes;
  final double progress;
  final double pageOffset;

  _MeshNetworkPainter({
    required this.nodes,
    required this.progress,
    required this.pageOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * math.pi * 2;

    // Calculate animated positions for each node
    final positions = <Offset>[];
    final nodeColors = <Color>[];

    for (final node in nodes) {
      // Gentle floating motion
      final floatX = math.sin(time * 0.5 + node.phase) * 15;
      final floatY = math.cos(time * 0.4 + node.phase * 1.3) * 12;

      final x = size.width * node.baseX + floatX - pageOffset * 20;
      final y = size.height * node.baseY + floatY;

      positions.add(Offset(x, y));
      nodeColors.add(node.color);
    }

    // Draw mesh connections (lines between nearby nodes)
    final connectionPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Connect nodes that are within range
    const maxDistance = 280.0;

    for (int i = 0; i < positions.length; i++) {
      for (int j = i + 1; j < positions.length; j++) {
        final p1 = positions[i];
        final p2 = positions[j];
        final dx = p2.dx - p1.dx;
        final dy = p2.dy - p1.dy;
        final distance = math.sqrt(dx * dx + dy * dy);

        if (distance < maxDistance) {
          // Fade based on distance
          final distanceFade = 1.0 - (distance / maxDistance);

          // Animated pulse along the connection
          final pulsePhase = (time * 0.8 + i * 0.5 + j * 0.3) % (math.pi * 2);
          final pulse = (math.sin(pulsePhase) * 0.5 + 0.5) * 0.4 + 0.2;

          // Blend colors from both nodes
          final blendedColor = Color.lerp(nodeColors[i], nodeColors[j], 0.5)!;

          connectionPaint.color = blendedColor.withValues(
            alpha: distanceFade * pulse * 0.5,
          );
          connectionPaint.strokeWidth = 1.5 + distanceFade * 1.0;

          canvas.drawLine(p1, p2, connectionPaint);

          // Draw animated "data packet" traveling along connection
          final packetProgress = ((time * 0.3 + i * 0.7 + j * 0.4) % 1.0);
          final packetX = p1.dx + dx * packetProgress;
          final packetY = p1.dy + dy * packetProgress;

          final packetPaint = Paint()
            ..color = blendedColor.withValues(alpha: distanceFade * 0.6)
            ..style = PaintingStyle.fill;

          canvas.drawCircle(
            Offset(packetX, packetY),
            2.5 + distanceFade * 1.5,
            packetPaint,
          );
        }
      }
    }

    // Draw nodes on top
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final pos = positions[i];

      // Pulsing glow
      final pulse = 0.5 + math.sin(time * 1.5 + node.phase) * 0.3;

      // Outer glow
      final glowPaint = Paint()
        ..color = node.color.withValues(alpha: pulse * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(pos, node.size * 0.6, glowPaint);

      // Inner glow
      final innerGlowPaint = Paint()
        ..color = node.color.withValues(alpha: pulse * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(pos, node.size * 0.4, innerGlowPaint);

      // Draw icon using TextPainter for Icons
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(node.icon.codePoint),
          style: TextStyle(
            fontSize: node.size * 0.8,
            fontFamily: node.icon.fontFamily,
            package: node.icon.fontPackage,
            color: node.color.withValues(alpha: pulse + 0.3),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        Offset(pos.dx - iconPainter.width / 2, pos.dy - iconPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_MeshNetworkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pageOffset != pageOffset;
  }
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

/// Mesh node data
class _MeshNode {
  final double baseX; // Base X position (0.0 to 1.0)
  final double baseY; // Base Y position (0.0 to 1.0)
  final IconData icon;
  final Color color;
  final double size;
  final double phase; // Animation phase offset

  const _MeshNode({
    required this.baseX,
    required this.baseY,
    required this.icon,
    required this.color,
    required this.size,
    required this.phase,
  });
}
