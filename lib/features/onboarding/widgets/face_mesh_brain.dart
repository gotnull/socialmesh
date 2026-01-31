// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Face expression configuration for Ico
class FaceExpression {
  /// Left eye scale (0 = closed, 1 = normal, >1 = wide)
  final double leftEyeScale;

  /// Right eye scale (0 = closed, 1 = normal, >1 = wide)
  final double rightEyeScale;

  /// Mouth curve (-1 = frown, 0 = neutral, 1 = smile)
  final double mouthCurve;

  /// Mouth width (0 = tiny, 1 = normal, 2 = wide)
  final double mouthWidth;

  /// Eyebrow angle for left eye (negative = worried, positive = angry)
  final double leftBrowAngle;

  /// Eyebrow angle for right eye
  final double rightBrowAngle;

  /// Special eye effect (normal, hearts, stars, spirals, x_eyes)
  final EyeEffect eyeEffect;

  const FaceExpression({
    this.leftEyeScale = 1.0,
    this.rightEyeScale = 1.0,
    this.mouthCurve = 0.3,
    this.mouthWidth = 1.0,
    this.leftBrowAngle = 0.0,
    this.rightBrowAngle = 0.0,
    this.eyeEffect = EyeEffect.normal,
  });

  /// Interpolate between two expressions
  static FaceExpression lerp(FaceExpression a, FaceExpression b, double t) {
    return FaceExpression(
      leftEyeScale: a.leftEyeScale + (b.leftEyeScale - a.leftEyeScale) * t,
      rightEyeScale: a.rightEyeScale + (b.rightEyeScale - a.rightEyeScale) * t,
      mouthCurve: a.mouthCurve + (b.mouthCurve - a.mouthCurve) * t,
      mouthWidth: a.mouthWidth + (b.mouthWidth - a.mouthWidth) * t,
      leftBrowAngle: a.leftBrowAngle + (b.leftBrowAngle - a.leftBrowAngle) * t,
      rightBrowAngle:
          a.rightBrowAngle + (b.rightBrowAngle - a.rightBrowAngle) * t,
      eyeEffect: t < 0.5 ? a.eyeEffect : b.eyeEffect,
    );
  }

  /// Apply blink to this expression (modifies eye scales)
  FaceExpression withBlink(double blinkValue) {
    // blinkValue: 0 = eyes open, 1 = eyes closed
    final blinkScale = 1.0 - blinkValue;
    return FaceExpression(
      leftEyeScale: leftEyeScale * blinkScale,
      rightEyeScale: rightEyeScale * blinkScale,
      mouthCurve: mouthCurve,
      mouthWidth: mouthWidth,
      leftBrowAngle: leftBrowAngle,
      rightBrowAngle: rightBrowAngle,
      eyeEffect: eyeEffect,
    );
  }
}

/// Special eye effects
enum EyeEffect { normal, hearts, stars, spirals, xEyes }

/// A 3D icosahedron mesh with integrated face features.
/// Two of the front-facing nodes act as EYES and one of the front edges is the MOUTH.
/// The eyes can blink and the mouth curves to express emotions.
class FaceMeshBrain extends StatefulWidget {
  final double size;
  final List<Color>? colors;
  final double glowIntensity;
  final FaceExpression expression;
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final double pulseValue;
  final bool enableBlinking;
  final Duration blinkInterval;

  const FaceMeshBrain({
    super.key,
    this.size = 180,
    this.colors,
    this.glowIntensity = 0.8,
    this.expression = const FaceExpression(),
    this.rotationX = 0.0,
    this.rotationY = 0.0,
    this.rotationZ = 0.0,
    this.pulseValue = 1.0,
    this.enableBlinking = true,
    this.blinkInterval = const Duration(milliseconds: 3500),
  });

  @override
  State<FaceMeshBrain> createState() => _FaceMeshBrainState();
}

class _FaceMeshBrainState extends State<FaceMeshBrain>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  double _blinkValue = 0.0;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _blinkController.addListener(() {
      setState(() {
        // Quick close, slower open
        if (_blinkController.status == AnimationStatus.forward) {
          _blinkValue = Curves.easeIn.transform(_blinkController.value);
        } else {
          _blinkValue = Curves.easeOut.transform(1 - _blinkController.value);
        }
      });
    });

    if (widget.enableBlinking) {
      _startBlinkLoop();
    }
  }

  void _startBlinkLoop() async {
    while (mounted && widget.enableBlinking) {
      // Random interval with some variance
      final variance = (math.Random().nextDouble() - 0.5) * 1000;
      await Future.delayed(
        widget.blinkInterval + Duration(milliseconds: variance.toInt()),
      );
      if (!mounted) return;

      // Blink!
      await _blinkController.forward();
      await _blinkController.reverse();

      // Sometimes double-blink
      if (math.Random().nextDouble() < 0.2) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        await _blinkController.forward();
        await _blinkController.reverse();
      }
    }
  }

  @override
  void didUpdateWidget(FaceMeshBrain oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableBlinking != oldWidget.enableBlinking) {
      if (widget.enableBlinking) {
        _startBlinkLoop();
      }
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  List<Color> get _colors =>
      widget.colors ??
      const [Color(0xFFFF6B4A), Color(0xFFE91E8C), Color(0xFF4F6AF6)];

  @override
  Widget build(BuildContext context) {
    final effectiveExpression = widget.expression.withBlink(_blinkValue);

    return CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _FaceMeshPainter(
        colors: _colors,
        glowIntensity: widget.glowIntensity,
        expression: effectiveExpression,
        rotationX: widget.rotationX,
        rotationY: widget.rotationY,
        rotationZ: widget.rotationZ,
        pulseValue: widget.pulseValue,
      ),
    );
  }
}

/// 3D point representation
class _Point3D {
  double x, y, z;
  _Point3D(this.x, this.y, this.z);

  _Point3D rotateY(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return _Point3D(x * cos + z * sin, y, -x * sin + z * cos);
  }

  _Point3D rotateX(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return _Point3D(x, y * cos - z * sin, y * sin + z * cos);
  }

  _Point3D rotateZ(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return _Point3D(x * cos - y * sin, x * sin + y * cos, z);
  }

  Offset project(double size, double perspective) {
    final scale = perspective / (perspective + z);
    return Offset(
      x * scale * size / 2 + size / 2,
      y * scale * size / 2 + size / 2,
    );
  }

  _Point3D copy() => _Point3D(x, y, z);
}

/// Custom painter that draws an icosahedron with face features integrated into the mesh
class _FaceMeshPainter extends CustomPainter {
  final List<Color> colors;
  final double glowIntensity;
  final FaceExpression expression;
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final double pulseValue;

  static const double _perspective = 3.0;
  static final double _phi = (1 + math.sqrt(5)) / 2;

  // Vertex indices that will be used for facial features
  // After analyzing the icosahedron, these front-facing vertices work best as eyes
  static const int _leftEyeVertex = 11; // Left eye node
  static const int _rightEyeVertex = 9; // Right eye node
  // Mouth is formed by edge 4-3 which curves based on expression

  _FaceMeshPainter({
    required this.colors,
    required this.glowIntensity,
    required this.expression,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
    required this.pulseValue,
  });

  // Generate icosahedron vertices
  List<_Point3D> _generateVertices() {
    const scale = 0.42;

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

  // Icosahedron edges (30 total)
  static const List<List<int>> _edges = [
    [0, 1],
    [0, 5],
    [0, 7],
    [0, 10],
    [0, 11],
    [1, 5],
    [1, 7],
    [1, 8],
    [1, 9],
    [5, 9],
    [5, 4],
    [5, 11],
    [9, 4],
    [9, 3],
    [9, 8],
    [4, 3],
    [4, 2],
    [4, 11],
    [3, 2],
    [3, 6],
    [3, 8],
    [2, 6],
    [2, 10],
    [2, 11],
    [6, 7],
    [6, 8],
    [6, 10],
    [7, 8],
    [7, 10],
    [10, 11],
  ];

  // Mouth edges - these will be curved
  bool _isMouthEdge(int v1, int v2) {
    // Edges that form the lower front of the mesh (mouth area)
    final mouthEdges = [
      [4, 3], // Main mouth line
      [4, 2],
      [3, 2],
    ];
    for (final edge in mouthEdges) {
      if ((edge[0] == v1 && edge[1] == v2) ||
          (edge[0] == v2 && edge[1] == v1)) {
        return true;
      }
    }
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final vertices = _generateVertices();

    // Transform all vertices
    final transformedVertices = <_Point3D>[];
    for (final v in vertices) {
      var point = v.copy();
      point = point.rotateZ(rotationZ);
      point = point.rotateX(rotationX);
      point = point.rotateY(rotationY);
      transformedVertices.add(point);
    }

    // Project to 2D
    final projectedPoints = <Offset>[];
    for (final v in transformedVertices) {
      projectedPoints.add(v.project(size.width, _perspective));
    }

    // Sort edges by depth (back to front)
    final edgesWithDepth = <MapEntry<List<int>, double>>[];
    for (final edge in _edges) {
      final avgZ =
          (transformedVertices[edge[0]].z + transformedVertices[edge[1]].z) / 2;
      edgesWithDepth.add(MapEntry(edge, avgZ));
    }
    edgesWithDepth.sort((a, b) => a.value.compareTo(b.value));

    // Draw regular edges first (back to front)
    for (final entry in edgesWithDepth) {
      final edge = entry.key;
      final p1 = projectedPoints[edge[0]];
      final p2 = projectedPoints[edge[1]];
      final z1 = transformedVertices[edge[0]].z;
      final z2 = transformedVertices[edge[1]].z;

      if (_isMouthEdge(edge[0], edge[1])) {
        // Draw mouth edge with curve
        _drawMouthEdge(canvas, p1, p2, size, z1, z2, edge);
      } else {
        _drawEdge(canvas, p1, p2, size, z1, z2);
      }
    }

    // Sort vertices by depth for drawing (back to front)
    final verticesWithDepth = <MapEntry<int, double>>[];
    for (var i = 0; i < transformedVertices.length; i++) {
      verticesWithDepth.add(MapEntry(i, transformedVertices[i].z));
    }
    verticesWithDepth.sort((a, b) => a.value.compareTo(b.value));

    // Draw nodes (back to front)
    for (final entry in verticesWithDepth) {
      final i = entry.key;
      final point = projectedPoints[i];
      final depth = transformedVertices[i].z;

      if (i == _leftEyeVertex || i == _rightEyeVertex) {
        // Draw EYE node
        _drawEyeNode(canvas, point, size, depth, i == _leftEyeVertex);
      } else {
        // Draw regular node
        _drawNode(canvas, point, size, depth);
      }
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
    final baseWidth = size.width * 0.02;
    final avgZ = (z1 + z2) / 2;
    final depthFactor = ((avgZ + 0.5) * 0.9 + 0.3).clamp(0.35, 1.0);
    final avgX = (p1.dx + p2.dx) / 2;
    final t = avgX / size.width;
    final color = _getGradientColor(t);

    // Glow
    if (glowIntensity > 0) {
      final glowPaint = Paint()
        ..color = color.withAlpha((35 * glowIntensity * depthFactor).round())
        ..strokeWidth = baseWidth * 5
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseWidth * 2.5);
      canvas.drawLine(p1, p2, glowPaint);
    }

    // Line
    final linePaint = Paint()
      ..color = color.withAlpha((255 * depthFactor).round())
      ..strokeWidth = baseWidth * (0.5 + 0.5 * depthFactor)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p1, p2, linePaint);
  }

  void _drawMouthEdge(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Size size,
    double z1,
    double z2,
    List<int> edge,
  ) {
    final baseWidth = size.width * 0.025; // Slightly thicker for mouth
    final avgZ = (z1 + z2) / 2;
    final depthFactor = ((avgZ + 0.5) * 0.9 + 0.3).clamp(0.35, 1.0);
    final avgX = (p1.dx + p2.dx) / 2;
    final t = avgX / size.width;
    final color = _getGradientColor(t);

    // Only curve the main mouth edge (4-3)
    if ((edge[0] == 4 && edge[1] == 3) || (edge[0] == 3 && edge[1] == 4)) {
      // Calculate control point for curve
      final midPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      // Curve amount based on expression
      final curveOffset =
          expression.mouthCurve * size.width * 0.06 * expression.mouthWidth;

      final controlPoint = Offset(midPoint.dx, midPoint.dy + curveOffset);

      final path = Path();
      path.moveTo(p1.dx, p1.dy);
      path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, p2.dx, p2.dy);

      // Glow
      if (glowIntensity > 0) {
        final glowPaint = Paint()
          ..color = color.withAlpha((50 * glowIntensity * depthFactor).round())
          ..strokeWidth = baseWidth * 4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseWidth * 2);
        canvas.drawPath(path, glowPaint);
      }

      // Main line
      final linePaint = Paint()
        ..color = color.withAlpha((255 * depthFactor).round())
        ..strokeWidth = baseWidth * (0.6 + 0.5 * depthFactor)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, linePaint);
    } else {
      // Regular edge for other mouth area edges
      _drawEdge(canvas, p1, p2, size, z1, z2);
    }
  }

  void _drawNode(Canvas canvas, Offset point, Size size, double depth) {
    final depthFactor = ((depth + 0.5) * 1.0 + 0.5).clamp(0.5, 1.3);
    final baseRadius = size.width * 0.045 * depthFactor * pulseValue;
    final t = point.dx / size.width;
    final color = _getGradientColor(t);
    final opacity = ((depth + 0.5) * 1.2 + 0.4).clamp(0.45, 1.0);

    // Outer glow
    if (glowIntensity > 0) {
      final glowPaint = Paint()
        ..color = color.withAlpha((60 * glowIntensity * opacity).round())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseRadius * 2);
      canvas.drawCircle(point, baseRadius * 2.5, glowPaint);
    }

    // Fill
    final fillPaint = Paint()
      ..color = color.withAlpha((255 * opacity).round())
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, baseRadius, fillPaint);

    // Highlight
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

  void _drawEyeNode(
    Canvas canvas,
    Offset point,
    Size size,
    double depth,
    bool isLeftEye,
  ) {
    final depthFactor = ((depth + 0.5) * 1.0 + 0.5).clamp(0.5, 1.3);
    final eyeScale = isLeftEye
        ? expression.leftEyeScale
        : expression.rightEyeScale;

    // Eye size is larger than regular nodes and scales with expression
    final baseRadius =
        size.width * 0.065 * depthFactor * pulseValue * math.max(0.1, eyeScale);

    final t = point.dx / size.width;
    final color = _getGradientColor(t);
    final opacity = ((depth + 0.5) * 1.2 + 0.4).clamp(0.45, 1.0);

    // Handle special eye effects
    switch (expression.eyeEffect) {
      case EyeEffect.hearts:
        _drawHeartEye(canvas, point, baseRadius, color, opacity);
        return;
      case EyeEffect.stars:
        _drawStarEye(canvas, point, baseRadius, color, opacity);
        return;
      case EyeEffect.spirals:
        _drawSpiralEye(canvas, point, baseRadius, color, opacity);
        return;
      case EyeEffect.xEyes:
        _drawXEye(canvas, point, baseRadius, color, opacity);
        return;
      case EyeEffect.normal:
        break;
    }

    // If eye is nearly closed (blinking), draw a line instead
    if (eyeScale < 0.3) {
      final lineLength = size.width * 0.04;
      final linePaint = Paint()
        ..color = color.withAlpha((255 * opacity).round())
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      // Closed eye arc (like ^^ or --)
      final glowPaint = Paint()
        ..color = color.withAlpha((60 * glowIntensity * opacity).round())
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawLine(
        Offset(point.dx - lineLength, point.dy),
        Offset(point.dx + lineLength, point.dy),
        glowPaint,
      );
      canvas.drawLine(
        Offset(point.dx - lineLength, point.dy),
        Offset(point.dx + lineLength, point.dy),
        linePaint,
      );
      return;
    }

    // OUTER GLOW (big and diffuse)
    if (glowIntensity > 0) {
      final glowPaint = Paint()
        ..color = color.withAlpha((80 * glowIntensity * opacity).round())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseRadius * 2.5);
      canvas.drawCircle(point, baseRadius * 3, glowPaint);
    }

    // IRIS (main eye)
    final irisPaint = Paint()
      ..color = color.withAlpha((255 * opacity).round())
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, baseRadius, irisPaint);

    // PUPIL (dark center)
    final pupilRadius = baseRadius * 0.5;
    final pupilPaint = Paint()
      ..color = Colors.black.withAlpha((200 * opacity).round())
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, pupilRadius, pupilPaint);

    // HIGHLIGHT (white glint)
    final highlightOffset = Offset(
      point.dx - baseRadius * 0.3,
      point.dy - baseRadius * 0.35,
    );
    final highlightPaint = Paint()
      ..color = Colors.white.withAlpha((220 * opacity).round())
      ..style = PaintingStyle.fill;
    canvas.drawCircle(highlightOffset, baseRadius * 0.3, highlightPaint);

    // Secondary smaller highlight
    final highlight2Offset = Offset(
      point.dx + baseRadius * 0.2,
      point.dy + baseRadius * 0.15,
    );
    final highlight2Paint = Paint()
      ..color = Colors.white.withAlpha((120 * opacity).round())
      ..style = PaintingStyle.fill;
    canvas.drawCircle(highlight2Offset, baseRadius * 0.15, highlight2Paint);
  }

  void _drawHeartEye(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    final heartColor = const Color(0xFFFF69B4);

    // Glow
    final glowPaint = Paint()
      ..color = heartColor.withAlpha((60 * glowIntensity * opacity).round())
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 2);
    canvas.drawCircle(center, radius * 2, glowPaint);

    // Draw heart shape
    final path = Path();
    final size = radius * 1.5;
    path.moveTo(center.dx, center.dy + size * 0.3);
    path.cubicTo(
      center.dx - size,
      center.dy - size * 0.3,
      center.dx - size * 0.5,
      center.dy - size,
      center.dx,
      center.dy - size * 0.2,
    );
    path.cubicTo(
      center.dx + size * 0.5,
      center.dy - size,
      center.dx + size,
      center.dy - size * 0.3,
      center.dx,
      center.dy + size * 0.3,
    );

    final fillPaint = Paint()
      ..color = heartColor.withAlpha((255 * opacity).round())
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  void _drawStarEye(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    // Glow
    final glowPaint = Paint()
      ..color = color.withAlpha((80 * glowIntensity * opacity).round())
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 2);
    canvas.drawCircle(center, radius * 2.5, glowPaint);

    // Draw star
    final path = Path();
    final outerRadius = radius * 1.3;
    final innerRadius = radius * 0.5;

    for (int i = 0; i < 5; i++) {
      final outerAngle = (i * 4 * math.pi / 5) - math.pi / 2;
      final innerAngle = outerAngle + math.pi / 5;

      final outerPoint = Offset(
        center.dx + math.cos(outerAngle) * outerRadius,
        center.dy + math.sin(outerAngle) * outerRadius,
      );
      final innerPoint = Offset(
        center.dx + math.cos(innerAngle) * innerRadius,
        center.dy + math.sin(innerAngle) * innerRadius,
      );

      if (i == 0) {
        path.moveTo(outerPoint.dx, outerPoint.dy);
      } else {
        path.lineTo(outerPoint.dx, outerPoint.dy);
      }
      path.lineTo(innerPoint.dx, innerPoint.dy);
    }
    path.close();

    final fillPaint = Paint()
      ..color = Colors.yellow.withAlpha((255 * opacity).round())
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  void _drawSpiralEye(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    // Draw concentric circles
    for (int i = 3; i >= 1; i--) {
      final r = radius * i * 0.4;
      final alpha = (0.3 + i * 0.2) * opacity;

      final paint = Paint()
        ..color = color.withAlpha((255 * alpha).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, r, paint);
    }

    // Center dot
    final centerPaint = Paint()
      ..color = color.withAlpha((255 * opacity).round())
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.2, centerPaint);
  }

  void _drawXEye(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    final halfSize = radius * 0.8;
    final strokeWidth = radius * 0.3;

    // Glow
    final glowPaint = Paint()
      ..color = color.withAlpha((50 * glowIntensity * opacity).round())
      ..strokeWidth = strokeWidth * 2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawLine(
      Offset(center.dx - halfSize, center.dy - halfSize),
      Offset(center.dx + halfSize, center.dy + halfSize),
      glowPaint,
    );
    canvas.drawLine(
      Offset(center.dx + halfSize, center.dy - halfSize),
      Offset(center.dx - halfSize, center.dy + halfSize),
      glowPaint,
    );

    // X lines
    final linePaint = Paint()
      ..color = color.withAlpha((255 * opacity).round())
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - halfSize, center.dy - halfSize),
      Offset(center.dx + halfSize, center.dy + halfSize),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx + halfSize, center.dy - halfSize),
      Offset(center.dx - halfSize, center.dy + halfSize),
      linePaint,
    );
  }

  Color _getGradientColor(double t) {
    t = t.clamp(0.0, 1.0);

    if (colors.length < 2) return colors.first;
    if (colors.length == 2) {
      return Color.lerp(colors[0], colors[1], t)!;
    }

    final segment = 1.0 / (colors.length - 1);
    final index = (t / segment).floor().clamp(0, colors.length - 2);
    final localT = (t - index * segment) / segment;

    return Color.lerp(colors[index], colors[index + 1], localT)!;
  }

  @override
  bool shouldRepaint(_FaceMeshPainter oldDelegate) =>
      expression.leftEyeScale != oldDelegate.expression.leftEyeScale ||
      expression.rightEyeScale != oldDelegate.expression.rightEyeScale ||
      expression.mouthCurve != oldDelegate.expression.mouthCurve ||
      expression.mouthWidth != oldDelegate.expression.mouthWidth ||
      expression.eyeEffect != oldDelegate.expression.eyeEffect ||
      rotationX != oldDelegate.rotationX ||
      rotationY != oldDelegate.rotationY ||
      rotationZ != oldDelegate.rotationZ ||
      pulseValue != oldDelegate.pulseValue ||
      glowIntensity != oldDelegate.glowIntensity;
}
