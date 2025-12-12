import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animation types available for the mesh node
enum MeshNodeAnimationType {
  /// Gentle pulsing glow effect
  pulse,

  /// Continuous Y-axis rotation (3D spin)
  rotate,

  /// Breathing scale effect
  breathe,

  /// Slow 3D tumble rotation
  tumble,

  /// Shimmer effect across the gradient
  shimmer,

  /// Combined pulse + rotate
  pulseRotate,

  /// Static (no animation)
  none,
}

/// Size presets for the mesh node
enum MeshNodeSize {
  tiny(24),
  small(32),
  medium(48),
  large(64),
  xlarge(96),
  hero(128);

  final double size;
  const MeshNodeSize(this.size);
}

/// A fully animatable 3D mesh cube widget with the brand gradient.
/// Replicates the SocialMesh app icon - a wireframe cube with gradient nodes.
/// Can be used as a loading indicator, decorative element, or icon.
class AnimatedMeshNode extends StatefulWidget {
  /// The size of the mesh node
  final double size;

  /// The animation type to use
  final MeshNodeAnimationType animationType;

  /// Animation duration (defaults vary by animation type)
  final Duration? duration;

  /// Whether the animation should run
  final bool animate;

  /// Custom gradient colors (defaults to brand gradient: orange → magenta → blue)
  final List<Color>? gradientColors;

  /// Glow intensity (0.0 - 1.0)
  final double glowIntensity;

  /// Line thickness multiplier
  final double lineThickness;

  /// Node (vertex) size multiplier
  final double nodeSize;

  /// Callback when animation completes one cycle
  final VoidCallback? onAnimationCycle;

  const AnimatedMeshNode({
    super.key,
    this.size = 48,
    this.animationType = MeshNodeAnimationType.pulse,
    this.duration,
    this.animate = true,
    this.gradientColors,
    this.glowIntensity = 0.6,
    this.lineThickness = 1.0,
    this.nodeSize = 1.0,
    this.onAnimationCycle,
  });

  /// Creates a mesh node with a preset size
  factory AnimatedMeshNode.sized(
    MeshNodeSize preset, {
    Key? key,
    MeshNodeAnimationType animationType = MeshNodeAnimationType.pulse,
    Duration? duration,
    bool animate = true,
    List<Color>? gradientColors,
    double glowIntensity = 0.6,
    double lineThickness = 1.0,
    double nodeSize = 1.0,
    VoidCallback? onAnimationCycle,
  }) {
    return AnimatedMeshNode(
      key: key,
      size: preset.size,
      animationType: animationType,
      duration: duration,
      animate: animate,
      gradientColors: gradientColors,
      glowIntensity: glowIntensity,
      lineThickness: lineThickness,
      nodeSize: nodeSize,
      onAnimationCycle: onAnimationCycle,
    );
  }

  /// Creates a loading indicator variant
  factory AnimatedMeshNode.loading({
    Key? key,
    double size = 32,
    List<Color>? gradientColors,
  }) {
    return AnimatedMeshNode(
      key: key,
      size: size,
      animationType: MeshNodeAnimationType.pulseRotate,
      glowIntensity: 0.8,
      gradientColors: gradientColors,
    );
  }

  @override
  State<AnimatedMeshNode> createState() => _AnimatedMeshNodeState();
}

class _AnimatedMeshNodeState extends State<AnimatedMeshNode>
    with TickerProviderStateMixin {
  late AnimationController _primaryController;
  late AnimationController _secondaryController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _breatheAnimation;
  late Animation<double> _tumbleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void didUpdateWidget(AnimatedMeshNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationType != widget.animationType ||
        oldWidget.duration != widget.duration ||
        oldWidget.animate != widget.animate) {
      _disposeControllers();
      _setupAnimations();
    }
  }

  void _setupAnimations() {
    final primaryDuration = widget.duration ?? _getDefaultDuration();
    final secondaryDuration = Duration(
      milliseconds: (primaryDuration.inMilliseconds * 1.5).round(),
    );

    _primaryController = AnimationController(
      duration: primaryDuration,
      vsync: this,
    );

    _secondaryController = AnimationController(
      duration: secondaryDuration,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _primaryController, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _primaryController, curve: Curves.linear),
    );

    _breatheAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _primaryController, curve: Curves.easeInOut),
    );

    _tumbleAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _secondaryController, curve: Curves.linear),
    );

    if (widget.animate) {
      _startAnimation();
    }

    _primaryController.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        widget.onAnimationCycle?.call();
      }
    });
  }

  Duration _getDefaultDuration() {
    switch (widget.animationType) {
      case MeshNodeAnimationType.pulse:
        return const Duration(milliseconds: 1500);
      case MeshNodeAnimationType.rotate:
        return const Duration(milliseconds: 4000);
      case MeshNodeAnimationType.breathe:
        return const Duration(milliseconds: 2000);
      case MeshNodeAnimationType.tumble:
        return const Duration(milliseconds: 8000);
      case MeshNodeAnimationType.shimmer:
        return const Duration(milliseconds: 2000);
      case MeshNodeAnimationType.pulseRotate:
        return const Duration(milliseconds: 3000);
      case MeshNodeAnimationType.none:
        return const Duration(milliseconds: 1000);
    }
  }

  void _startAnimation() {
    switch (widget.animationType) {
      case MeshNodeAnimationType.pulse:
      case MeshNodeAnimationType.breathe:
        _primaryController.repeat(reverse: true);
        break;
      case MeshNodeAnimationType.rotate:
      case MeshNodeAnimationType.shimmer:
        _primaryController.repeat();
        break;
      case MeshNodeAnimationType.tumble:
        _primaryController.repeat();
        _secondaryController.repeat();
        break;
      case MeshNodeAnimationType.pulseRotate:
        _primaryController.repeat();
        _secondaryController.repeat(reverse: true);
        break;
      case MeshNodeAnimationType.none:
        break;
    }
  }

  void _disposeControllers() {
    _primaryController.dispose();
    _secondaryController.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  // Brand gradient: orange/coral → magenta/pink → blue
  List<Color> get _gradientColors =>
      widget.gradientColors ??
      const [
        Color(0xFFFF6B4A), // Orange/coral (left side)
        Color(0xFFE91E8C), // Magenta/pink (middle)
        Color(0xFF4F6AF6), // Blue (right side)
      ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_primaryController, _secondaryController]),
      builder: (context, child) {
        return _buildAnimatedNode();
      },
    );
  }

  Widget _buildAnimatedNode() {
    // Calculate rotation angles based on animation type
    double rotationY = 0;
    double rotationX = 0;

    switch (widget.animationType) {
      case MeshNodeAnimationType.rotate:
        rotationY = _rotateAnimation.value;
        break;
      case MeshNodeAnimationType.tumble:
        rotationY = _rotateAnimation.value;
        rotationX = _tumbleAnimation.value * 0.3;
        break;
      case MeshNodeAnimationType.pulseRotate:
        rotationY = _rotateAnimation.value;
        break;
      default:
        break;
    }

    Widget node = CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _MeshCubePainter(
        gradientColors: _gradientColors,
        glowIntensity: _getGlowIntensity(),
        lineThickness: widget.lineThickness,
        nodeSize: widget.nodeSize,
        rotationY: rotationY,
        rotationX: rotationX,
      ),
    );

    // Apply scale for breathe animation
    if (widget.animationType == MeshNodeAnimationType.breathe) {
      node = Transform.scale(scale: _breatheAnimation.value, child: node);
    }

    return SizedBox(width: widget.size, height: widget.size, child: node);
  }

  double _getGlowIntensity() {
    if (!widget.animate) return widget.glowIntensity;

    switch (widget.animationType) {
      case MeshNodeAnimationType.pulse:
        return widget.glowIntensity * (0.5 + 0.5 * _pulseAnimation.value);
      case MeshNodeAnimationType.pulseRotate:
        return widget.glowIntensity * (0.6 + 0.4 * _secondaryController.value);
      default:
        return widget.glowIntensity;
    }
  }
}

/// 3D point representation
class _Point3D {
  final double x, y, z;
  const _Point3D(this.x, this.y, this.z);

  /// Rotate around Y axis
  _Point3D rotateY(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return _Point3D(x * cos + z * sin, y, -x * sin + z * cos);
  }

  /// Rotate around X axis
  _Point3D rotateX(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return _Point3D(x, y * cos - z * sin, y * sin + z * cos);
  }

  /// Project to 2D with perspective
  Offset project(double size, double perspective) {
    final scale = perspective / (perspective + z);
    return Offset(
      x * scale * size / 2 + size / 2,
      y * scale * size / 2 + size / 2,
    );
  }
}

/// Custom painter for the 3D mesh cube
class _MeshCubePainter extends CustomPainter {
  final List<Color> gradientColors;
  final double glowIntensity;
  final double lineThickness;
  final double nodeSize;
  final double rotationY;
  final double rotationX;

  _MeshCubePainter({
    required this.gradientColors,
    required this.glowIntensity,
    required this.lineThickness,
    required this.nodeSize,
    required this.rotationY,
    required this.rotationX,
  });

  // Cube vertices (normalized -1 to 1)
  static const _vertices = [
    _Point3D(-1, -1, -1), // 0: back-bottom-left
    _Point3D(1, -1, -1), // 1: back-bottom-right
    _Point3D(1, 1, -1), // 2: back-top-right
    _Point3D(-1, 1, -1), // 3: back-top-left
    _Point3D(-1, -1, 1), // 4: front-bottom-left
    _Point3D(1, -1, 1), // 5: front-bottom-right
    _Point3D(1, 1, 1), // 6: front-top-right
    _Point3D(-1, 1, 1), // 7: front-top-left
  ];

  // Edges as pairs of vertex indices
  static const _edges = [
    [0, 1], [1, 2], [2, 3], [3, 0], // Back face
    [4, 5], [5, 6], [6, 7], [7, 4], // Front face
    [0, 4], [1, 5], [2, 6], [3, 7], // Connecting edges
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const perspective = 4.0;
    const cubeScale = 0.35; // Scale down the cube to fit nicely

    // Transform and project all vertices
    final projectedPoints = <Offset>[];
    final transformedPoints = <_Point3D>[];

    for (final vertex in _vertices) {
      // Scale, rotate, then project
      var point = _Point3D(
        vertex.x * cubeScale,
        vertex.y * cubeScale,
        vertex.z * cubeScale,
      );
      point = point.rotateY(rotationY);
      point = point.rotateX(rotationX);
      transformedPoints.add(point);
      projectedPoints.add(point.project(size.width, perspective));
    }

    // Sort edges by average Z depth (back to front)
    final edgesWithDepth = <MapEntry<List<int>, double>>[];
    for (final edge in _edges) {
      final avgZ =
          (transformedPoints[edge[0]].z + transformedPoints[edge[1]].z) / 2;
      edgesWithDepth.add(MapEntry(edge, avgZ));
    }
    edgesWithDepth.sort((a, b) => a.value.compareTo(b.value));

    // Draw edges (back to front)
    for (final entry in edgesWithDepth) {
      final edge = entry.key;
      final p1 = projectedPoints[edge[0]];
      final p2 = projectedPoints[edge[1]];
      _drawEdge(canvas, p1, p2, size);
    }

    // Sort vertices by Z depth for drawing (back to front)
    final verticesWithDepth = <MapEntry<int, double>>[];
    for (var i = 0; i < transformedPoints.length; i++) {
      verticesWithDepth.add(MapEntry(i, transformedPoints[i].z));
    }
    verticesWithDepth.sort((a, b) => a.value.compareTo(b.value));

    // Draw nodes (back to front)
    for (final entry in verticesWithDepth) {
      final i = entry.key;
      final point = projectedPoints[i];
      final depth = transformedPoints[i].z;
      _drawNode(canvas, point, size, depth);
    }
  }

  void _drawEdge(Canvas canvas, Offset p1, Offset p2, Size size) {
    final baseWidth = size.width * 0.025 * lineThickness;

    // Calculate color based on X position (left=orange, middle=magenta, right=blue)
    final avgX = (p1.dx + p2.dx) / 2;
    final t = avgX / size.width;
    final color = _getGradientColor(t);

    // Draw glow
    if (glowIntensity > 0) {
      final glowPaint = Paint()
        ..color = color.withAlpha((40 * glowIntensity).round())
        ..strokeWidth = baseWidth * 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseWidth * 2);
      canvas.drawLine(p1, p2, glowPaint);
    }

    // Draw line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = baseWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p1, p2, linePaint);
  }

  void _drawNode(Canvas canvas, Offset point, Size size, double depth) {
    // Node size varies slightly based on depth (closer = bigger)
    final depthFactor = 1.0 + depth * 0.15;
    final baseRadius = size.width * 0.055 * nodeSize * depthFactor;

    // Color based on X position
    final t = point.dx / size.width;
    final color = _getGradientColor(t);

    // Draw outer glow
    if (glowIntensity > 0) {
      final glowPaint = Paint()
        ..color = color.withAlpha((60 * glowIntensity).round())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseRadius * 1.5);
      canvas.drawCircle(point, baseRadius * 2, glowPaint);
    }

    // Draw node fill
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, baseRadius, fillPaint);

    // Draw highlight
    final highlightOffset = Offset(
      point.dx - baseRadius * 0.3,
      point.dy - baseRadius * 0.3,
    );
    final highlightPaint = Paint()
      ..color = Colors.white.withAlpha(80)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(highlightOffset, baseRadius * 0.3, highlightPaint);
  }

  Color _getGradientColor(double t) {
    // t: 0 = left (orange), 0.5 = middle (magenta), 1 = right (blue)
    t = t.clamp(0.0, 1.0);

    if (gradientColors.length < 2) return gradientColors.first;

    if (gradientColors.length == 2) {
      return Color.lerp(gradientColors[0], gradientColors[1], t)!;
    }

    // 3+ colors: interpolate through all
    final segment = 1.0 / (gradientColors.length - 1);
    final index = (t / segment).floor().clamp(0, gradientColors.length - 2);
    final localT = (t - index * segment) / segment;

    return Color.lerp(
      gradientColors[index],
      gradientColors[index + 1],
      localT,
    )!;
  }

  @override
  bool shouldRepaint(covariant _MeshCubePainter oldDelegate) {
    return oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.rotationX != rotationX ||
        oldDelegate.lineThickness != lineThickness ||
        oldDelegate.nodeSize != nodeSize;
  }
}

/// Extension for easy access to mesh node in loading states
extension MeshNodeLoadingIndicator on BuildContext {
  /// Shows a centered mesh node loading indicator
  Widget meshNodeLoader({
    double size = 48,
    MeshNodeAnimationType animationType = MeshNodeAnimationType.pulseRotate,
  }) {
    return Center(
      child: AnimatedMeshNode(size: size, animationType: animationType),
    );
  }
}
