import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animation types available for the mesh node
enum MeshNodeAnimationType {
  /// Gentle pulsing glow effect
  pulse,

  /// Continuous rotation
  rotate,

  /// Breathing scale effect
  breathe,

  /// Orbiting particles around the node
  orbit,

  /// Wave ripple effect emanating from center
  ripple,

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

/// A fully animatable mesh node widget with the brand gradient.
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

  /// Custom gradient colors (defaults to brand gradient)
  final List<Color>? gradientColors;

  /// Glow intensity (0.0 - 1.0)
  final double glowIntensity;

  /// Number of connection points on the node (3-8)
  final int connectionPoints;

  /// Whether to show the inner hexagon detail
  final bool showInnerDetail;

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
    this.connectionPoints = 6,
    this.showInnerDetail = true,
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
    int connectionPoints = 6,
    bool showInnerDetail = true,
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
      connectionPoints: connectionPoints,
      showInnerDetail: showInnerDetail,
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
  late Animation<double> _shimmerAnimation;

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

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _primaryController, curve: Curves.easeInOut),
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
        return const Duration(milliseconds: 3000);
      case MeshNodeAnimationType.breathe:
        return const Duration(milliseconds: 2000);
      case MeshNodeAnimationType.orbit:
        return const Duration(milliseconds: 4000);
      case MeshNodeAnimationType.ripple:
        return const Duration(milliseconds: 1800);
      case MeshNodeAnimationType.shimmer:
        return const Duration(milliseconds: 2000);
      case MeshNodeAnimationType.pulseRotate:
        return const Duration(milliseconds: 2000);
      case MeshNodeAnimationType.none:
        return const Duration(milliseconds: 1000);
    }
  }

  void _startAnimation() {
    switch (widget.animationType) {
      case MeshNodeAnimationType.pulse:
      case MeshNodeAnimationType.breathe:
      case MeshNodeAnimationType.ripple:
        _primaryController.repeat(reverse: true);
        break;
      case MeshNodeAnimationType.rotate:
      case MeshNodeAnimationType.orbit:
        _primaryController.repeat();
        break;
      case MeshNodeAnimationType.shimmer:
        _primaryController.repeat();
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

  List<Color> get _gradientColors =>
      widget.gradientColors ??
      const [
        Color(0xFFE91E8C), // Magenta
        Color(0xFF8B5CF6), // Purple
        Color(0xFF4F6AF6), // Blue
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
    Widget node = CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _MeshNodePainter(
        gradientColors: _gradientColors,
        glowIntensity: _getGlowIntensity(),
        connectionPoints: widget.connectionPoints,
        showInnerDetail: widget.showInnerDetail,
        shimmerProgress: widget.animationType == MeshNodeAnimationType.shimmer
            ? _shimmerAnimation.value
            : null,
        rippleProgress: widget.animationType == MeshNodeAnimationType.ripple
            ? _pulseAnimation.value
            : null,
      ),
    );

    // Apply transformations based on animation type
    switch (widget.animationType) {
      case MeshNodeAnimationType.rotate:
        node = Transform.rotate(angle: _rotateAnimation.value, child: node);
        break;
      case MeshNodeAnimationType.breathe:
        node = Transform.scale(scale: _breatheAnimation.value, child: node);
        break;
      case MeshNodeAnimationType.pulseRotate:
        node = Transform.rotate(
          angle: _rotateAnimation.value,
          child: Transform.scale(
            scale: 0.95 + (0.1 * _secondaryController.value),
            child: node,
          ),
        );
        break;
      case MeshNodeAnimationType.orbit:
        node = Stack(
          alignment: Alignment.center,
          children: [node, ..._buildOrbitingParticles()],
        );
        break;
      default:
        break;
    }

    return SizedBox(width: widget.size, height: widget.size, child: node);
  }

  double _getGlowIntensity() {
    if (!widget.animate) return widget.glowIntensity;

    switch (widget.animationType) {
      case MeshNodeAnimationType.pulse:
      case MeshNodeAnimationType.ripple:
        return widget.glowIntensity * (0.5 + 0.5 * _pulseAnimation.value);
      case MeshNodeAnimationType.pulseRotate:
        return widget.glowIntensity * (0.6 + 0.4 * _secondaryController.value);
      default:
        return widget.glowIntensity;
    }
  }

  List<Widget> _buildOrbitingParticles() {
    final particles = <Widget>[];
    const particleCount = 3;
    final orbitRadius = widget.size * 0.45;

    for (var i = 0; i < particleCount; i++) {
      final baseAngle = (2 * math.pi / particleCount) * i;
      final angle = baseAngle + _rotateAnimation.value;
      final x = math.cos(angle) * orbitRadius;
      final y = math.sin(angle) * orbitRadius;

      particles.add(
        Transform.translate(
          offset: Offset(x, y),
          child: Container(
            width: widget.size * 0.08,
            height: widget.size * 0.08,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _gradientColors[i % _gradientColors.length],
                  _gradientColors[i % _gradientColors.length].withAlpha(0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _gradientColors[i % _gradientColors.length].withAlpha(
                    150,
                  ),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return particles;
  }
}

/// Custom painter for the mesh node
class _MeshNodePainter extends CustomPainter {
  final List<Color> gradientColors;
  final double glowIntensity;
  final int connectionPoints;
  final bool showInnerDetail;
  final double? shimmerProgress;
  final double? rippleProgress;

  _MeshNodePainter({
    required this.gradientColors,
    required this.glowIntensity,
    required this.connectionPoints,
    required this.showInnerDetail,
    this.shimmerProgress,
    this.rippleProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw outer glow
    _drawGlow(canvas, center, radius);

    // Draw ripple effect if active
    if (rippleProgress != null) {
      _drawRipple(canvas, center, radius);
    }

    // Draw main hexagonal node
    _drawHexagon(canvas, center, radius * 0.75);

    // Draw connection points
    _drawConnectionPoints(canvas, center, radius * 0.85);

    // Draw inner detail
    if (showInnerDetail) {
      _drawInnerHexagon(canvas, center, radius * 0.4);
    }

    // Draw shimmer overlay if active
    if (shimmerProgress != null) {
      _drawShimmer(canvas, size);
    }
  }

  void _drawGlow(Canvas canvas, Offset center, double radius) {
    final glowPaint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.3);

    for (var i = 0; i < gradientColors.length; i++) {
      final glowRadius = radius * (1.0 - i * 0.15);
      glowPaint.color = gradientColors[i].withAlpha(
        (50 * glowIntensity).round(),
      );
      canvas.drawCircle(center, glowRadius, glowPaint);
    }
  }

  void _drawRipple(Canvas canvas, Offset center, double radius) {
    final rippleRadius = radius * (0.8 + rippleProgress! * 0.6);
    final ripplePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = gradientColors[0].withAlpha(
        ((1 - rippleProgress!) * 100).round(),
      );

    canvas.drawCircle(center, rippleRadius, ripplePaint);

    // Second ripple ring
    final rippleRadius2 = radius * (0.6 + rippleProgress! * 0.5);
    ripplePaint.color = gradientColors[1].withAlpha(
      ((1 - rippleProgress!) * 80).round(),
    );
    canvas.drawCircle(center, rippleRadius2, ripplePaint);
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius) {
    final path = _createHexagonPath(center, radius);

    // Create gradient shader
    final gradient = SweepGradient(
      colors: [...gradientColors, gradientColors.first],
      startAngle: 0,
      endAngle: 2 * math.pi,
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Draw border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawPath(path, borderPaint);
  }

  void _drawInnerHexagon(Canvas canvas, Offset center, double radius) {
    final path = _createHexagonPath(center, radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withAlpha(100);

    canvas.drawPath(path, paint);

    // Draw center dot
    final centerPaint = Paint()
      ..color = Colors.white.withAlpha(180)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.2, centerPaint);
  }

  void _drawConnectionPoints(Canvas canvas, Offset center, double radius) {
    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (var i = 0; i < connectionPoints; i++) {
      final angle = (2 * math.pi / connectionPoints) * i - math.pi / 2;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;

      // Glow
      glowPaint.color = gradientColors[i % gradientColors.length].withAlpha(
        (150 * glowIntensity).round(),
      );
      canvas.drawCircle(Offset(x, y), 4, glowPaint);

      // Point
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }

    // Draw connection lines between points
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withAlpha(50);

    for (var i = 0; i < connectionPoints; i++) {
      final angle1 = (2 * math.pi / connectionPoints) * i - math.pi / 2;
      final x1 = center.dx + math.cos(angle1) * radius;
      final y1 = center.dy + math.sin(angle1) * radius;

      // Connect to next point
      final nextIndex = (i + 1) % connectionPoints;
      final angle2 = (2 * math.pi / connectionPoints) * nextIndex - math.pi / 2;
      final x2 = center.dx + math.cos(angle2) * radius;
      final y2 = center.dy + math.sin(angle2) * radius;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);

      // Connect to center
      linePaint.color = Colors.white.withAlpha(30);
      canvas.drawLine(Offset(x1, y1), center, linePaint);
    }
  }

  void _drawShimmer(Canvas canvas, Size size) {
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withAlpha(0),
          Colors.white.withAlpha(60),
          Colors.white.withAlpha(0),
        ],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment(-1.0 + shimmerProgress! * 2, -1.0),
        end: Alignment(0.0 + shimmerProgress! * 2, 1.0),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..blendMode = BlendMode.srcATop;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), shimmerPaint);
  }

  Path _createHexagonPath(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _MeshNodePainter oldDelegate) {
    return oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.shimmerProgress != shimmerProgress ||
        oldDelegate.rippleProgress != rippleProgress;
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
