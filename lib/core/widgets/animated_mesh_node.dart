import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Physics modes for accelerometer-controlled mesh
enum MeshPhysicsMode {
  /// Momentum mode: accelerometer gives impulse, mesh continues spinning with friction
  momentum,

  /// Tilt mode: direct mapping where device tilt directly controls rotation (original behavior)
  tilt,

  /// Gyroscope mode: uses gyroscope for more precise rotation tracking
  gyroscope,

  /// Chaos mode: random perturbations added to movement
  chaos,

  /// Touch only mode: no accelerometer, only touch interaction
  touchOnly,
}

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

  /// Index of the vertex being grabbed (0-11), or -1 if none
  final int grabbedVertexIndex;

  /// Where to drag the grabbed vertex (in normalized 0-1 coordinates)
  final Offset? dragPosition;

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
    this.grabbedVertexIndex = -1,
    this.dragPosition,
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
        grabbedVertexIndex: widget.grabbedVertexIndex,
        dragPosition: widget.dragPosition,
      ),
    );

    // Apply scale for breathe animation
    if (scale != 1.0) {
      node = Transform.scale(scale: scale, child: node);
    }

    // Clip to bounds to prevent deformation from affecting layout
    return ClipRect(
      child: SizedBox(width: widget.size, height: widget.size, child: node),
    );
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

  /// Add two points
  _Point3D operator +(_Point3D other) =>
      _Point3D(x + other.x, y + other.y, z + other.z);

  /// Multiply by scalar
  _Point3D operator *(double scalar) =>
      _Point3D(x * scalar, y * scalar, z * scalar);

  /// Distance to another point
  double distanceTo(_Point3D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Normalize to unit length
  _Point3D normalized() {
    final len = math.sqrt(x * x + y * y + z * z);
    if (len == 0) return this;
    return _Point3D(x / len, y / len, z / len);
  }
}

/// Custom painter for the 3D icosahedron mesh (12 vertices, 30 edges)
/// Supports optional touch-based vertex deformation (Mario 64 style)
class _IcosahedronPainter extends CustomPainter {
  final List<Color> gradientColors;
  final double glowIntensity;
  final double lineThickness;
  final double nodeSize;
  final double rotationY;
  final double rotationX;
  final double rotationZ;

  /// Index of the vertex being grabbed (0-11), or -1 if none
  final int grabbedVertexIndex;

  /// Where to drag the grabbed vertex (in normalized 0-1 coordinates)
  final Offset? dragPosition;

  _IcosahedronPainter({
    required this.gradientColors,
    required this.glowIntensity,
    required this.lineThickness,
    required this.nodeSize,
    required this.rotationY,
    required this.rotationX,
    required this.rotationZ,
    this.grabbedVertexIndex = -1,
    this.dragPosition,
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

    // Apply touch deformation to projected points (Mario 64 style pull)
    final deformedPoints = _applyDeformation(projectedPoints, size);

    // Sort edges by average Z depth (back to front)
    final edgesWithDepth = <MapEntry<List<int>, double>>[];
    for (final edge in _edges) {
      final avgZ =
          (transformedPoints[edge[0]].z + transformedPoints[edge[1]].z) / 2;
      edgesWithDepth.add(MapEntry(edge, avgZ));
    }
    edgesWithDepth.sort((a, b) => a.value.compareTo(b.value));

    // Draw edges (back to front) using deformed points
    for (final entry in edgesWithDepth) {
      final edge = entry.key;
      final p1 = deformedPoints[edge[0]];
      final p2 = deformedPoints[edge[1]];
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

    // Draw nodes (back to front) using deformed points
    for (final entry in verticesWithDepth) {
      final i = entry.key;
      final point = deformedPoints[i];
      final depth = transformedPoints[i].z;
      _drawNode(canvas, point, size, depth);
    }
  }

  /// Move only the grabbed vertex to the drag position
  /// All other vertices stay in place - edges naturally stretch
  List<Offset> _applyDeformation(List<Offset> points, Size size) {
    if (grabbedVertexIndex < 0 ||
        grabbedVertexIndex >= points.length ||
        dragPosition == null) {
      return points;
    }

    // Convert drag position from normalized (0-1) to pixel coordinates
    final dragPixel = Offset(
      dragPosition!.dx * size.width,
      dragPosition!.dy * size.height,
    );

    // Copy all points, but move the grabbed vertex to the drag position
    final deformed = List<Offset>.from(points);
    deformed[grabbedVertexIndex] = dragPixel;

    return deformed;
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
        oldDelegate.nodeSize != nodeSize ||
        oldDelegate.grabbedVertexIndex != grabbedVertexIndex ||
        oldDelegate.dragPosition != dragPosition;
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
/// Supports multiple physics modes including momentum-based spinning.
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
  /// Only used in direct mode
  final double smoothing;

  /// Friction for momentum physics (0.0 - 1.0, higher = less friction)
  /// Used in momentum, bounce, drift, and chaos modes
  final double friction;

  /// Physics mode for controlling how accelerometer input affects rotation
  final MeshPhysicsMode physicsMode;

  /// Whether touch interaction is enabled (drag to spin, Mario 64 style)
  final bool enableTouch;

  /// Whether pull-to-stretch vertex deformation is enabled (Mario 64 style face pull)
  final bool enablePullToStretch;

  /// Intensity of touch-induced rotation (0.0 - 2.0)
  final double touchIntensity;

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
    this.friction = 0.985,
    this.physicsMode = MeshPhysicsMode.momentum,
    this.enableTouch = false,
    this.enablePullToStretch = true,
    this.touchIntensity = 1.0,
  });

  @override
  State<AccelerometerMeshNode> createState() => _AccelerometerMeshNodeState();
}

class _AccelerometerMeshNodeState extends State<AccelerometerMeshNode>
    with SingleTickerProviderStateMixin {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  late AnimationController _physicsController;

  // ============ ROTATION STATE ============
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  double _velocityX = 0.0;
  double _velocityY = 0.0;

  // ============ TOUCH STATE ============
  bool _isTouching = false;
  Offset? _lastTouchPosition;

  // ============ VERTEX GRAB STATE ============
  int _grabbedVertexIndex =
      -1; // Which of the 12 vertices is grabbed (-1 = none)
  int _springBackVertexIndex = -1; // Which vertex is springing back
  Offset?
  _dragPosition; // Where the grabbed vertex is being dragged (normalized 0-1)
  Offset?
  _originalVertexPosition; // Where the vertex was before grab (for spring-back)

  // ============ CONSTANTS ============
  static const double _maxVelocity = 0.15;
  static final double _phi = (1 + math.sqrt(5)) / 2;

  // For chaos mode
  final math.Random _random = math.Random();

  // Startup stabilization
  int _stabilizationFrames = 0;
  static const int _stabilizationDelay = 30;

  @override
  void initState() {
    super.initState();
    // Physics loop - ALWAYS runs regardless of settings
    _physicsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_physicsLoop);
    _physicsController.repeat();

    // Start accelerometer listener
    _startAccelerometer();
  }

  void _startAccelerometer() {
    _accelerometerSubscription =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 16),
        ).listen((event) {
          if (!mounted) return;
          _handleAccelerometer(event.x, event.y);
        });
  }

  // ============ ACCELEROMETER INPUT ============
  void _handleAccelerometer(double accelX, double accelY) {
    // RULE 1: touchOnly mode = no accelerometer ever
    if (widget.physicsMode == MeshPhysicsMode.touchOnly) return;

    // RULE 2: While touching = accelerometer paused
    if (_isTouching) return;

    // RULE 3: Wait for sensor stabilization
    if (_stabilizationFrames < _stabilizationDelay) {
      _stabilizationFrames++;
      return;
    }

    final sensitivity = widget.accelerometerSensitivity;
    final normalizedX = (accelX / 10.0).clamp(-1.0, 1.0);
    final normalizedY = (accelY / 10.0).clamp(-1.0, 1.0);

    switch (widget.physicsMode) {
      case MeshPhysicsMode.tilt:
        final targetX = normalizedY * sensitivity * math.pi;
        final targetY = normalizedX * sensitivity * math.pi;
        _rotationX =
            _rotationX * widget.smoothing + targetX * (1 - widget.smoothing);
        _rotationY =
            _rotationY * widget.smoothing + targetY * (1 - widget.smoothing);
        break;

      case MeshPhysicsMode.momentum:
        _velocityY += normalizedX * sensitivity * 0.005;
        _velocityX += normalizedY * sensitivity * 0.005;
        break;

      case MeshPhysicsMode.gyroscope:
        final targetX = normalizedY * sensitivity * math.pi * 1.5;
        final targetY = normalizedX * sensitivity * math.pi * 1.5;
        _rotationX = _rotationX * 0.7 + targetX * 0.3;
        _rotationY = _rotationY * 0.7 + targetY * 0.3;
        break;

      case MeshPhysicsMode.chaos:
        _velocityY += normalizedX * sensitivity * 0.005;
        _velocityX += normalizedY * sensitivity * 0.005;
        _velocityX += (_random.nextDouble() - 0.5) * 0.003;
        _velocityY += (_random.nextDouble() - 0.5) * 0.003;
        break;

      case MeshPhysicsMode.touchOnly:
        break;
    }

    // Clamp velocities
    _velocityX = _velocityX.clamp(-_maxVelocity, _maxVelocity);
    _velocityY = _velocityY.clamp(-_maxVelocity, _maxVelocity);
  }

  // ============ PHYSICS LOOP - ALWAYS RUNS ============
  void _physicsLoop() {
    if (!mounted) return;

    setState(() {
      // ALWAYS apply velocity to rotation (this makes everything spin)
      _rotationX += _velocityX;
      _rotationY += _velocityY;

      // ALWAYS apply friction (this makes things slow down)
      _velocityX *= widget.friction;
      _velocityY *= widget.friction;

      // Chaos mode random perturbations
      if (widget.physicsMode == MeshPhysicsMode.chaos && !_isTouching) {
        if (_random.nextDouble() < 0.1) {
          _velocityX += (_random.nextDouble() - 0.5) * 0.02;
          _velocityY += (_random.nextDouble() - 0.5) * 0.02;
        }
      }

      // SPRING-BACK: when not grabbing but have a drag position, animate back
      if (_grabbedVertexIndex < 0 &&
          _springBackVertexIndex >= 0 &&
          _dragPosition != null &&
          _originalVertexPosition != null) {
        // Lerp drag position back toward original
        final dx = _originalVertexPosition!.dx - _dragPosition!.dx;
        final dy = _originalVertexPosition!.dy - _dragPosition!.dy;
        final dist = math.sqrt(dx * dx + dy * dy);

        if (dist < 0.01) {
          // Close enough - snap to original and clear
          _dragPosition = null;
          _originalVertexPosition = null;
          _springBackVertexIndex = -1;
        } else {
          // Fast spring back (30% per frame)
          _dragPosition = Offset(
            _dragPosition!.dx + dx * 0.3,
            _dragPosition!.dy + dy * 0.3,
          );
        }
      }
    });
  }

  // ============ NODE HIT DETECTION ============
  /// Returns the index of the nearest vertex to touchPos, or -1 if none within grab radius
  /// Also returns the projected position of that vertex (for spring-back origin)
  (int index, Offset? position) _findNearestVertex(Offset touchPos) {
    const scale = 0.42;
    const perspective = 3.0;

    final vertices = <List<double>>[
      [-1, _phi, 0],
      [1, _phi, 0],
      [-1, -_phi, 0],
      [1, -_phi, 0],
      [0, -1, _phi],
      [0, 1, _phi],
      [0, -1, -_phi],
      [0, 1, -_phi],
      [_phi, 0, -1],
      [_phi, 0, 1],
      [-_phi, 0, -1],
      [-_phi, 0, 1],
    ];

    // Grab radius - 30% of widget size
    final grabRadius = 0.30 * widget.size;
    final grabRadiusSq = grabRadius * grabRadius;

    int nearestIndex = -1;
    double nearestDistSq = double.infinity;
    Offset? nearestPosition;

    for (int i = 0; i < vertices.length; i++) {
      final v = vertices[i];

      // Normalize to unit sphere then scale
      final len = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
      double x = v[0] / len * scale;
      double y = v[1] / len * scale;
      double z = v[2] / len * scale;

      // Rotate X
      final cosX = math.cos(_rotationX);
      final sinX = math.sin(_rotationX);
      final newY = y * cosX - z * sinX;
      final newZ = y * sinX + z * cosX;
      y = newY;
      z = newZ;

      // Rotate Y
      final cosY = math.cos(_rotationY);
      final sinY = math.sin(_rotationY);
      final newX = x * cosY + z * sinY;
      final newZ2 = -x * sinY + z * cosY;
      x = newX;
      z = newZ2;

      // Project to 2D
      final projScale = perspective / (perspective + z);
      final projX = x * projScale * widget.size / 2 + widget.size / 2;
      final projY = y * projScale * widget.size / 2 + widget.size / 2;

      // Check distance
      final dx = touchPos.dx - projX;
      final dy = touchPos.dy - projY;
      final distSq = dx * dx + dy * dy;

      if (distSq < grabRadiusSq && distSq < nearestDistSq) {
        nearestIndex = i;
        nearestDistSq = distSq;
        nearestPosition = Offset(
          projX / widget.size,
          projY / widget.size,
        ); // Normalized
      }
    }

    return (nearestIndex, nearestPosition);
  }

  // ============ TOUCH HANDLERS ============
  void _onPanStart(DragStartDetails details) {
    _isTouching = true;
    _lastTouchPosition = details.localPosition;

    // STOP momentum when touch starts
    _velocityX = 0.0;
    _velocityY = 0.0;

    // Try to grab a vertex (only if pull-to-stretch enabled)
    _grabbedVertexIndex = -1;
    if (widget.enablePullToStretch) {
      final (index, position) = _findNearestVertex(details.localPosition);
      if (index >= 0) {
        _grabbedVertexIndex = index;
        _originalVertexPosition = position;
        _dragPosition = Offset(
          details.localPosition.dx / widget.size,
          details.localPosition.dy / widget.size,
        );
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isTouching) return;

    final delta = details.localPosition - (_lastTouchPosition ?? Offset.zero);
    _lastTouchPosition = details.localPosition;

    if (_grabbedVertexIndex >= 0) {
      // DRAGGING A VERTEX - update drag position, mesh stays frozen
      _dragPosition = Offset(
        details.localPosition.dx / widget.size,
        details.localPosition.dy / widget.size,
      );
    } else if (widget.enableTouch) {
      // NO VERTEX GRABBED - rotation from drag
      final intensity = widget.touchIntensity * 0.015;
      _velocityY += delta.dx * intensity;
      _velocityX -= delta.dy * intensity;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    // SLINGSHOT: if we were dragging a vertex, apply momentum based on pull direction
    if (_grabbedVertexIndex >= 0 &&
        _dragPosition != null &&
        _originalVertexPosition != null) {
      final pullX = _dragPosition!.dx - _originalVertexPosition!.dx;
      final pullY = _dragPosition!.dy - _originalVertexPosition!.dy;
      final pullMag = math.sqrt(pullX * pullX + pullY * pullY);

      if (pullMag > 0.05) {
        // Slingshot strength based on pull distance
        final strength = pullMag * 2.0;
        _velocityY = pullX * strength;
        _velocityX = pullY * strength;

        // Allow higher velocity for slingshot
        _velocityX = _velocityX.clamp(-_maxVelocity * 3, _maxVelocity * 3);
        _velocityY = _velocityY.clamp(-_maxVelocity * 3, _maxVelocity * 3);
      }
    }

    _isTouching = false;
    // Store vertex index for spring-back animation before clearing
    if (_grabbedVertexIndex >= 0) {
      _springBackVertexIndex = _grabbedVertexIndex;
    }
    _grabbedVertexIndex = -1; // Release vertex - spring-back will animate it
    _lastTouchPosition = null;
    // Keep _dragPosition and _originalVertexPosition for spring-back animation
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _physicsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use grabbed index if actively grabbing, or springback index during animation
    final activeVertexIndex = _grabbedVertexIndex >= 0
        ? _grabbedVertexIndex
        : _springBackVertexIndex;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedMeshNode(
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
        grabbedVertexIndex: activeVertexIndex,
        dragPosition: _dragPosition,
      ),
    );
  }
}
