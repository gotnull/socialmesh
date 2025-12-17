import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import 'animated_mesh_node.dart';

/// A mesh node that displays discovered node names on its vertices during initialization.
/// The icosahedron has 12 vertices, so up to 12 node names can be displayed.
/// Names fade in as nodes are discovered, creating a dynamic loading experience.
class NodeNamesMeshNode extends ConsumerStatefulWidget {
  /// Size of the mesh node
  final double size;

  /// Animation type for the mesh
  final MeshNodeAnimationType animationType;

  /// Glow intensity
  final double glowIntensity;

  /// Line thickness
  final double lineThickness;

  /// Node (vertex) size
  final double nodeSize;

  /// Gradient colors
  final List<Color> gradientColors;

  /// Whether to show node names
  final bool showNodeNames;

  /// Maximum number of names to display (max 12 for icosahedron vertices)
  final int maxNames;

  /// Text style for node names
  final TextStyle? nameTextStyle;

  /// Whether names should orbit with the mesh rotation
  final bool namesOrbitWithMesh;

  const NodeNamesMeshNode({
    super.key,
    this.size = 200,
    this.animationType = MeshNodeAnimationType.tumble,
    this.glowIntensity = 0.5,
    this.lineThickness = 0.5,
    this.nodeSize = 0.8,
    this.gradientColors = const [
      Color(0xFFFF6B4A),
      Color(0xFFE91E8C),
      Color(0xFF4F6AF6),
    ],
    this.showNodeNames = true,
    this.maxNames = 12,
    this.nameTextStyle,
    this.namesOrbitWithMesh = true,
  });

  @override
  ConsumerState<NodeNamesMeshNode> createState() => _NodeNamesMeshNodeState();
}

class _NodeNamesMeshNodeState extends ConsumerState<NodeNamesMeshNode>
    with TickerProviderStateMixin {
  final List<_NodeNameEntry> _nodeNames = [];
  late AnimationController _rotationController;

  // Icosahedron vertex positions (normalized -1 to 1)
  // Using golden ratio for icosahedron geometry
  static final List<Offset> _vertexPositions = _generateVertexPositions();

  static List<Offset> _generateVertexPositions() {
    // Scale to position names around the mesh
    const scale = 0.35;

    // 12 vertices of an icosahedron projected to 2D
    // We use a simplified projection that looks good on screen
    final vertices = <Offset>[
      Offset(0, -1 * scale), // Top
      Offset(0.95 * scale, -0.45 * scale), // Upper ring
      Offset(0.59 * scale, 0.8 * scale),
      Offset(-0.59 * scale, 0.8 * scale),
      Offset(-0.95 * scale, -0.45 * scale),
      Offset(0.59 * scale, -0.8 * scale), // Lower ring
      Offset(0.95 * scale, 0.45 * scale),
      Offset(0, 1 * scale), // Bottom
      Offset(-0.95 * scale, 0.45 * scale),
      Offset(-0.59 * scale, -0.8 * scale),
      Offset(0.3 * scale, 0.3 * scale), // Inner vertices
      Offset(-0.3 * scale, -0.3 * scale),
    ];

    return vertices;
  }

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    for (final entry in _nodeNames) {
      entry.controller.dispose();
    }
    super.dispose();
  }

  void _addNodeName(String name) {
    if (_nodeNames.length >= widget.maxNames) return;
    if (_nodeNames.any((e) => e.name == name)) return;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final entry = _NodeNameEntry(
      name: name,
      vertexIndex: _nodeNames.length,
      controller: controller,
      opacity: CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );

    setState(() {
      _nodeNames.add(entry);
    });

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to nodes provider for new discoveries
    final nodes = ref.watch(nodesProvider);

    // Add new node names as they come in
    if (widget.showNodeNames) {
      for (final node in nodes.values) {
        final displayName = node.longName ?? node.shortName;
        if (displayName != null && displayName.isNotEmpty) {
          _addNodeName(displayName);
        }
      }
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The mesh node itself
          AccelerometerMeshNode(
            size: widget.size * 0.7, // Slightly smaller to make room for names
            animationType: widget.animationType,
            glowIntensity: widget.glowIntensity,
            lineThickness: widget.lineThickness,
            nodeSize: widget.nodeSize,
            gradientColors: widget.gradientColors,
            accelerometerSensitivity: 0.3,
            friction: 0.95,
            physicsMode: MeshPhysicsMode.momentum,
            enableTouch: false,
            enablePullToStretch: false,
          ),
          // Node names floating around
          if (widget.showNodeNames)
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _NodeNamesPainter(
                    entries: _nodeNames,
                    vertexPositions: _vertexPositions,
                    rotationAngle: widget.namesOrbitWithMesh
                        ? _rotationController.value * 2 * math.pi
                        : 0,
                    textStyle:
                        widget.nameTextStyle ??
                        TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                          shadows: [
                            Shadow(
                              color: widget.gradientColors.first.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                    gradientColors: widget.gradientColors,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _NodeNameEntry {
  final String name;
  final int vertexIndex;
  final AnimationController controller;
  final Animation<double> opacity;

  _NodeNameEntry({
    required this.name,
    required this.vertexIndex,
    required this.controller,
    required this.opacity,
  });
}

class _NodeNamesPainter extends CustomPainter {
  final List<_NodeNameEntry> entries;
  final List<Offset> vertexPositions;
  final double rotationAngle;
  final TextStyle textStyle;
  final List<Color> gradientColors;

  _NodeNamesPainter({
    required this.entries,
    required this.vertexPositions,
    required this.rotationAngle,
    required this.textStyle,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (final entry in entries) {
      if (entry.vertexIndex >= vertexPositions.length) continue;

      final basePos = vertexPositions[entry.vertexIndex];

      // Apply rotation
      final rotatedX =
          basePos.dx * math.cos(rotationAngle) -
          basePos.dy * math.sin(rotationAngle);
      final rotatedY =
          basePos.dx * math.sin(rotationAngle) +
          basePos.dy * math.cos(rotationAngle);

      final position = Offset(
        center.dx + rotatedX * radius,
        center.dy + rotatedY * radius,
      );

      // Calculate color based on vertex index
      final colorIndex = entry.vertexIndex % gradientColors.length;
      final color = gradientColors[colorIndex];

      // Draw text with fade-in opacity
      final opacity = entry.opacity.value;
      if (opacity <= 0) continue;

      final textSpan = TextSpan(
        text: _truncateName(entry.name),
        style: textStyle.copyWith(
          color:
              textStyle.color?.withValues(alpha: opacity) ??
              Colors.white.withValues(alpha: opacity),
          shadows: [
            Shadow(
              color: color.withValues(alpha: 0.6 * opacity),
              blurRadius: 6,
            ),
            Shadow(
              color: Colors.black.withValues(alpha: 0.3 * opacity),
              blurRadius: 2,
            ),
          ],
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      // Center the text on the position
      final textOffset = Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      );

      textPainter.paint(canvas, textOffset);
    }
  }

  String _truncateName(String name) {
    // Truncate long names
    if (name.length > 10) {
      return '${name.substring(0, 8)}…';
    }
    return name;
  }

  @override
  bool shouldRepaint(_NodeNamesPainter oldDelegate) {
    return oldDelegate.entries.length != entries.length ||
        oldDelegate.rotationAngle != rotationAngle ||
        entries.any((e) => e.controller.isAnimating);
  }
}

/// A splash screen variant that shows node names during initialization
class NodeNamesLoadingSplash extends ConsumerWidget {
  final double size;
  final bool showNodeNames;

  const NodeNamesLoadingSplash({
    super.key,
    this.size = 300,
    this.showNodeNames = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NodeNamesMeshNode(
      size: size,
      showNodeNames: showNodeNames,
      animationType: MeshNodeAnimationType.tumble,
      glowIntensity: 0.6,
      lineThickness: 0.6,
      nodeSize: 1.0,
    );
  }
}
