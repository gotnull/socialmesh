import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Animation types available for the mesh node
enum MeshNodeAnimationType {
  /// Gentle pulsing glow effect
  pulse,

  /// Continuous Y-axis rotation (3D spin)
  rotate,

  /// Breathing scale effect
  breathe,

  /// Slow 3D tumble rotation on multiple axes
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

/// A fully animatable 3D icosahedron mesh widget with the brand gradient.
/// Replicates the SocialMesh app icon - a spherical wireframe with gradient nodes.
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

  /// External rotation offset for X axis (radians) - e.g., from accelerometer
  final double externalRotationX;

  /// External rotation offset for Y axis (radians) - e.g., from accelerometer
  final double externalRotationY;

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
    this.externalRotationX = 0.0,
    this.externalRotationY = 0.0,
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
  late AnimationController _tertiaryController;

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

    // Use prime number ratios for non-repeating seamless animation
    final secondaryDuration = Duration(
      milliseconds: (primaryDuration.inMilliseconds * 1.31).round(),
    );
    final tertiaryDuration = Duration(
      milliseconds: (primaryDuration.inMilliseconds * 1.73).round(),
    );

    _primaryController = AnimationController(
      duration: primaryDuration,
      vsync: this,
    );

    _secondaryController = AnimationController(
      duration: secondaryDuration,
      vsync: this,
    );

    _tertiaryController = AnimationController(
      duration: tertiaryDuration,
      vsync: this,
    );

    if (widget.animate) {
      _startAnimation();
    }

    _primaryController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationCycle?.call();
      }
    });
  }

  Duration _getDefaultDuration() {
    switch (widget.animationType) {
      case MeshNodeAnimationType.pulse:
        return const Duration(milliseconds: 1500);
      case MeshNodeAnimationType.rotate:
        return const Duration(milliseconds: 6000);
      case MeshNodeAnimationType.breathe:
        return const Duration(milliseconds: 2000);
      case MeshNodeAnimationType.tumble:
        return const Duration(milliseconds: 10000);
      case MeshNodeAnimationType.shimmer:
        return const Duration(milliseconds: 2000);
      case MeshNodeAnimationType.pulseRotate:
        return const Duration(milliseconds: 4000);
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
        // All three controllers run continuously for seamless tumble
        _primaryController.repeat();
        _secondaryController.repeat();
        _tertiaryController.repeat();
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
    _tertiaryController.dispose();
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
      animation: Listenable.merge([
        _primaryController,
        _secondaryController,
        _tertiaryController,
      ]),
      builder: (context, child) {
        return _buildAnimatedNode();
      },
    );
  }

  Widget _buildAnimatedNode() {
    // Calculate rotation angles based on animation type
    double rotationY = 0;
    double rotationX = 0;
    double rotationZ = 0;
    double scale = 1.0;
    double glowMultiplier = 1.0;

    switch (widget.animationType) {
      case MeshNodeAnimationType.rotate:
        // Seamless full rotation
        rotationY = _primaryController.value * 2 * math.pi;
        break;
      case MeshNodeAnimationType.tumble:
        // Three independent rotations for organic tumble - all seamless
        rotationY = _primaryController.value * 2 * math.pi;
        rotationX = _secondaryController.value * 2 * math.pi;
        rotationZ = _tertiaryController.value * 2 * math.pi;
        break;
      case MeshNodeAnimationType.pulseRotate:
        rotationY = _primaryController.value * 2 * math.pi;
        glowMultiplier = 0.6 + 0.4 * _secondaryController.value;
        break;
      case MeshNodeAnimationType.pulse:
        glowMultiplier = 0.5 + 0.5 * _primaryController.value;
        break;
      case MeshNodeAnimationType.breathe:
        scale = 0.9 + 0.2 * _primaryController.value;
        break;
      default:
        break;
    }

    // Add external rotation offsets (e.g., from accelerometer)
    rotationX += widget.externalRotationX;
    rotationY += widget.externalRotationY;

    Widget node = CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _IcosahedronPainter(
        gradientColors: _gradientColors,
        glowIntensity: widget.glowIntensity * glowMultiplier,
        lineThickness: widget.lineThickness,
        nodeSize: widget.nodeSize,
        rotationY: rotationY,
        rotationX: rotationX,
        rotationZ: rotationZ,
      ),
    );

    // Apply scale for breathe animation
    if (scale != 1.0) {
      node = Transform.scale(scale: scale, child: node);
    }

    return SizedBox(width: widget.size, height: widget.size, child: node);
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

  /// Rotate around Z axis
  _Point3D rotateZ(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return _Point3D(x * cos - y * sin, x * sin + y * cos, z);
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

/// Custom painter for the 3D icosahedron mesh (12 vertices, 30 edges)
class _IcosahedronPainter extends CustomPainter {
  final List<Color> gradientColors;
  final double glowIntensity;
  final double lineThickness;
  final double nodeSize;
  final double rotationY;
  final double rotationX;
  final double rotationZ;

  _IcosahedronPainter({
    required this.gradientColors,
    required this.glowIntensity,
    required this.lineThickness,
    required this.nodeSize,
    required this.rotationY,
    required this.rotationX,
    required this.rotationZ,
  });

  // Golden ratio for icosahedron
  static final double _phi = (1 + math.sqrt(5)) / 2;

  // Icosahedron has 12 vertices - perfectly spherical distribution
  static final List<_Point3D> _vertices = _generateVertices();

  static List<_Point3D> _generateVertices() {
    const scale = 0.42;

    // Icosahedron vertices: 3 perpendicular golden rectangles
    final vertices = <_Point3D>[
      // Rectangle in XY plane
      _Point3D(-1, _phi, 0),
      _Point3D(1, _phi, 0),
      _Point3D(-1, -_phi, 0),
      _Point3D(1, -_phi, 0),
      // Rectangle in YZ plane
      _Point3D(0, -1, _phi),
      _Point3D(0, 1, _phi),
      _Point3D(0, -1, -_phi),
      _Point3D(0, 1, -_phi),
      // Rectangle in XZ plane
      _Point3D(_phi, 0, -1),
      _Point3D(_phi, 0, 1),
      _Point3D(-_phi, 0, -1),
      _Point3D(-_phi, 0, 1),
    ];

    // Normalize to unit sphere and scale
    return vertices.map((v) {
      final len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
      return _Point3D(v.x / len * scale, v.y / len * scale, v.z / len * scale);
    }).toList();
  }

  // Icosahedron has exactly 30 edges - each vertex connects to 5 others
  static const List<List<int>> _edges = [
    // Top pentagon (around vertex 0 and 1)
    [0, 1], [0, 5], [0, 7], [0, 10], [0, 11],
    [1, 5], [1, 7], [1, 8], [1, 9],
    // Middle band
    [5, 9], [5, 4], [5, 11],
    [9, 4], [9, 3], [9, 8],
    [4, 3], [4, 2], [4, 11],
    [3, 2], [3, 6], [3, 8],
    // Bottom pentagon (around vertex 2 and 6)
    [2, 6], [2, 10], [2, 11],
    [6, 7], [6, 8], [6, 10],
    [7, 8], [7, 10],
    [10, 11],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const perspective = 3.0;

    // Transform and project all vertices
    final projectedPoints = <Offset>[];
    final transformedPoints = <_Point3D>[];

    for (final vertex in _vertices) {
      var point = vertex;
      // Apply rotations in order: Z, X, Y for natural tumble
      point = point.rotateZ(rotationZ);
      point = point.rotateX(rotationX);
      point = point.rotateY(rotationY);
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
      final z1 = transformedPoints[edge[0]].z;
      final z2 = transformedPoints[edge[1]].z;
      _drawEdge(canvas, p1, p2, size, z1, z2);
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

  void _drawEdge(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Size size,
    double z1,
    double z2,
  ) {
    final baseWidth = size.width * 0.02 * lineThickness;

    // Depth-based opacity - normalize z from [-0.42, 0.42] to [0.3, 1.0]
    final avgZ = (z1 + z2) / 2;
    final depthFactor = ((avgZ + 0.5) * 0.9 + 0.3).clamp(0.35, 1.0);

    // Calculate color based on X position (left=orange, middle=magenta, right=blue)
    final avgX = (p1.dx + p2.dx) / 2;
    final t = avgX / size.width;
    final color = _getGradientColor(t);

    // Draw glow
    if (glowIntensity > 0) {
      final glowPaint = Paint()
        ..color = color.withAlpha((35 * glowIntensity * depthFactor).round())
        ..strokeWidth = baseWidth * 5
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseWidth * 2.5);
      canvas.drawLine(p1, p2, glowPaint);
    }

    // Draw line
    final linePaint = Paint()
      ..color = color.withAlpha((255 * depthFactor).round())
      ..strokeWidth = baseWidth * (0.5 + 0.5 * depthFactor)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p1, p2, linePaint);
  }

  void _drawNode(Canvas canvas, Offset point, Size size, double depth) {
    // Node size varies based on depth (closer = bigger)
    // Normalize depth from [-0.42, 0.42] to reasonable scale
    final depthFactor = ((depth + 0.5) * 1.0 + 0.5).clamp(0.5, 1.3);
    final baseRadius = size.width * 0.045 * nodeSize * depthFactor;

    // Color based on X position
    final t = point.dx / size.width;
    final color = _getGradientColor(t);

    // Opacity based on depth
    final opacity = ((depth + 0.5) * 1.2 + 0.4).clamp(0.45, 1.0);

    // Draw outer glow
    if (glowIntensity > 0) {
      final glowPaint = Paint()
        ..color = color.withAlpha((60 * glowIntensity * opacity).round())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseRadius * 2);
      canvas.drawCircle(point, baseRadius * 2.5, glowPaint);
    }

    // Draw node fill
    final fillPaint = Paint()
      ..color = color.withAlpha((255 * opacity).round())
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, baseRadius, fillPaint);

    // Draw subtle inner highlight for 3D spherical effect
    if (baseRadius > 2) {
      final highlightOffset = Offset(
        point.dx - baseRadius * 0.3,
        point.dy - baseRadius * 0.3,
      );
      final highlightPaint = Paint()
        ..color = Colors.white.withAlpha((70 * opacity).round())
        ..style = PaintingStyle.fill;
      canvas.drawCircle(highlightOffset, baseRadius * 0.35, highlightPaint);
    }
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
  bool shouldRepaint(covariant _IcosahedronPainter oldDelegate) {
    return oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationZ != rotationZ ||
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

/// An AnimatedMeshNode that responds to device accelerometer for interactive rotation.
/// Tilting the device left/right and forward/back will influence the mesh rotation.
class AccelerometerMeshNode extends StatefulWidget {
  /// The size of the mesh node
  final double size;

  /// The animation type to use
  final MeshNodeAnimationType animationType;

  /// Animation duration
  final Duration? duration;

  /// Whether the base animation should run
  final bool animate;

  /// Custom gradient colors
  final List<Color>? gradientColors;

  /// Glow intensity (0.0 - 1.0)
  final double glowIntensity;

  /// Line thickness multiplier
  final double lineThickness;

  /// Node (vertex) size multiplier
  final double nodeSize;

  /// Sensitivity of accelerometer influence (0.0 - 1.0)
  final double accelerometerSensitivity;

  /// Smoothing factor for accelerometer input (0.0 - 1.0, higher = smoother)
  final double smoothing;

  const AccelerometerMeshNode({
    super.key,
    this.size = 48,
    this.animationType = MeshNodeAnimationType.tumble,
    this.duration,
    this.animate = true,
    this.gradientColors,
    this.glowIntensity = 0.6,
    this.lineThickness = 1.0,
    this.nodeSize = 1.0,
    this.accelerometerSensitivity = 0.15,
    this.smoothing = 0.85,
  });

  @override
  State<AccelerometerMeshNode> createState() => _AccelerometerMeshNodeState();
}

class _AccelerometerMeshNodeState extends State<AccelerometerMeshNode> {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  double _targetRotationX = 0.0;
  double _targetRotationY = 0.0;

  @override
  void initState() {
    super.initState();
    _startAccelerometer();
  }

  void _startAccelerometer() {
    _accelerometerSubscription =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 16), // ~60fps
        ).listen((event) {
          if (!mounted) return;

          // Map accelerometer values to rotation
          // X accelerometer = tilt left/right = rotate around Y axis
          // Y accelerometer = tilt forward/back = rotate around X axis
          final sensitivity = widget.accelerometerSensitivity;

          // Clamp and scale the values
          _targetRotationY =
              (event.x / 10.0).clamp(-1.0, 1.0) * sensitivity * math.pi;
          _targetRotationX =
              (event.y / 10.0).clamp(-1.0, 1.0) * sensitivity * math.pi;

          // Apply smoothing for fluid motion
          setState(() {
            _rotationX =
                _rotationX * widget.smoothing +
                _targetRotationX * (1 - widget.smoothing);
            _rotationY =
                _rotationY * widget.smoothing +
                _targetRotationY * (1 - widget.smoothing);
          });
        });
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedMeshNode(
      size: widget.size,
      animationType: widget.animationType,
      duration: widget.duration,
      animate: widget.animate,
      gradientColors: widget.gradientColors,
      glowIntensity: widget.glowIntensity,
      lineThickness: widget.lineThickness,
      nodeSize: widget.nodeSize,
      externalRotationX: _rotationX,
      externalRotationY: _rotationY,
    );
  }
}
