// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/theme.dart';

import '../../providers/app_providers.dart';
import 'animated_mesh_node.dart';

/// A mesh node that displays discovered node names orbiting around it during initialization.
/// Names appear as glowing chips that bounce in elegantly and fade out after a delay,
/// creating a dynamic and visually stunning loading experience.
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

  /// Maximum number of names to display simultaneously
  final int maxVisibleNames;

  /// How long each name chip stays visible before fading out
  final Duration chipDisplayDuration;

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
    this.maxVisibleNames = 6,
    this.chipDisplayDuration = const Duration(seconds: 4),
  });

  @override
  ConsumerState<NodeNamesMeshNode> createState() => _NodeNamesMeshNodeState();
}

class _NodeNamesMeshNodeState extends ConsumerState<NodeNamesMeshNode>
    with TickerProviderStateMixin {
  final List<_NodeChipEntry> _activeChips = [];
  final Set<String> _seenNames = {};
  final List<String> _nameQueue = [];
  late AnimationController _orbitController;
  int _nextSlotIndex = 0;

  @override
  void initState() {
    super.initState();
    // Slow orbit animation for the chip ring
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _orbitController.dispose();
    for (final chip in _activeChips) {
      chip.dispose();
    }
    super.dispose();
  }

  void _addNodeName(String name) {
    if (_seenNames.contains(name)) return;
    _seenNames.add(name);
    _nameQueue.add(name);
    _processQueue();
  }

  void _processQueue() {
    if (_nameQueue.isEmpty) return;
    if (_activeChips.length >= widget.maxVisibleNames) return;

    final name = _nameQueue.removeAt(0);
    _spawnChip(name);
  }

  void _spawnChip(String name) {
    // Calculate slot position (evenly distributed around the orbit)
    final slotAngle = (_nextSlotIndex * 2 * math.pi) / widget.maxVisibleNames;
    _nextSlotIndex = (_nextSlotIndex + 1) % widget.maxVisibleNames;

    // Create entrance animation with spring effect
    final entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Create exit animation
    final exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Spring curve for bouncy entrance
    final scaleAnimation = CurvedAnimation(
      parent: entranceController,
      curve: Curves.elasticOut,
    );

    final opacityAnimation = CurvedAnimation(
      parent: entranceController,
      curve: Curves.easeOut,
    );

    // Exit animations
    final exitScale = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: exitController, curve: Curves.easeInBack),
    );

    final exitOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: exitController, curve: Curves.easeIn));

    // Random slight offset for organic feel
    final random = math.Random();
    final radiusVariation = 0.9 + random.nextDouble() * 0.2; // 0.9-1.1
    final floatSpeed = 0.5 + random.nextDouble() * 1.0; // Varied float speed

    // Pick a color from gradient
    final colorIndex = _activeChips.length % widget.gradientColors.length;

    final chip = _NodeChipEntry(
      name: name,
      baseAngle: slotAngle,
      radiusMultiplier: radiusVariation,
      floatSpeed: floatSpeed,
      entranceController: entranceController,
      exitController: exitController,
      scaleAnimation: scaleAnimation,
      opacityAnimation: opacityAnimation,
      exitScale: exitScale,
      exitOpacity: exitOpacity,
      color: widget.gradientColors[colorIndex],
    );

    setState(() {
      _activeChips.add(chip);
    });

    // Start entrance animation
    entranceController.forward();

    // Schedule exit after display duration
    Future.delayed(widget.chipDisplayDuration, () {
      if (!mounted) return;
      exitController.forward().then((_) {
        if (!mounted) return;
        setState(() {
          _activeChips.remove(chip);
          chip.dispose();
        });
        // Process next in queue
        _processQueue();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to nodes provider for new discoveries
    final nodes = ref.watch(nodesProvider);

    // Add new node names as they come in
    if (widget.showNodeNames) {
      for (final node in nodes.values) {
        // Prefer shortName (compact 4-char ID) over longName for cleaner display
        final displayName = node.shortName ?? node.longName;
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
          // The mesh node itself (centered, slightly smaller)
          AccelerometerMeshNode(
            size: widget.size * 0.55,
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
          // Orbiting node name chips
          if (widget.showNodeNames)
            AnimatedBuilder(
              animation: Listenable.merge([
                _orbitController,
                ..._activeChips.map((c) => c.entranceController),
                ..._activeChips.map((c) => c.exitController),
              ]),
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _OrbitingChipsPainter(
                    chips: _activeChips,
                    orbitProgress: _orbitController.value,
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

class _NodeChipEntry {
  final String name;
  final double baseAngle;
  final double radiusMultiplier;
  final double floatSpeed;
  final AnimationController entranceController;
  final AnimationController exitController;
  final Animation<double> scaleAnimation;
  final Animation<double> opacityAnimation;
  final Animation<double> exitScale;
  final Animation<double> exitOpacity;
  final Color color;

  _NodeChipEntry({
    required this.name,
    required this.baseAngle,
    required this.radiusMultiplier,
    required this.floatSpeed,
    required this.entranceController,
    required this.exitController,
    required this.scaleAnimation,
    required this.opacityAnimation,
    required this.exitScale,
    required this.exitOpacity,
    required this.color,
  });

  void dispose() {
    entranceController.dispose();
    exitController.dispose();
  }

  double get currentScale {
    if (exitController.isAnimating || exitController.isCompleted) {
      return scaleAnimation.value * exitScale.value;
    }
    return scaleAnimation.value;
  }

  double get currentOpacity {
    if (exitController.isAnimating || exitController.isCompleted) {
      return opacityAnimation.value * exitOpacity.value;
    }
    return opacityAnimation.value;
  }

  bool get isExiting =>
      exitController.isAnimating || exitController.isCompleted;
}

class _OrbitingChipsPainter extends CustomPainter {
  final List<_NodeChipEntry> chips;
  final double orbitProgress;
  final List<Color> gradientColors;

  _OrbitingChipsPainter({
    required this.chips,
    required this.orbitProgress,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.42; // Orbit radius

    for (final chip in chips) {
      final opacity = chip.currentOpacity;
      if (opacity <= 0.01) continue;

      final scale = chip.currentScale.clamp(0.0, 1.5);
      if (scale <= 0.01) continue;

      // Calculate position with gentle orbit and float
      final orbitAngle =
          chip.baseAngle +
          (orbitProgress * 2 * math.pi * chip.floatSpeed * 0.1);
      final radius = baseRadius * chip.radiusMultiplier;

      // Add subtle vertical bobbing
      final bobOffset =
          math.sin(orbitProgress * 2 * math.pi * 2 + chip.baseAngle) * 4;

      final x = center.dx + math.cos(orbitAngle) * radius;
      final y = center.dy + math.sin(orbitAngle) * radius + bobOffset;
      final position = Offset(x, y);

      _drawChip(canvas, position, chip, scale, opacity);
    }
  }

  void _drawChip(
    Canvas canvas,
    Offset position,
    _NodeChipEntry chip,
    double scale,
    double opacity,
  ) {
    final displayName = _formatName(chip.name);

    // Measure text first
    final textSpan = TextSpan(
      text: displayName,
      style: TextStyle(
        fontSize: 11 * scale,
        fontWeight: FontWeight.w600,
        color: SemanticColors.glow(opacity),
        letterSpacing: 0.3,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    // Chip dimensions
    final chipWidth = textPainter.width + 16 * scale;
    final chipHeight = textPainter.height + 10 * scale;
    final chipRadius = chipHeight / 2;

    final chipRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: position, width: chipWidth, height: chipHeight),
      Radius.circular(chipRadius),
    );

    // Draw outer glow
    final glowPaint = Paint()
      ..color = chip.color.withValues(alpha: 0.4 * opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * scale);
    canvas.drawRRect(chipRect, glowPaint);

    // Draw chip background with gradient
    final bgRect = chipRect.outerRect;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        chip.color.withValues(alpha: 0.25 * opacity),
        chip.color.withValues(alpha: 0.15 * opacity),
      ],
    );

    final bgPaint = Paint()
      ..shader = gradient.createShader(bgRect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(chipRect, bgPaint);

    // Draw border with glow effect
    final borderPaint = Paint()
      ..color = chip.color.withValues(alpha: 0.6 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * scale;
    canvas.drawRRect(chipRect, borderPaint);

    // Draw subtle inner highlight
    final highlightRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(position.dx, position.dy - chipHeight * 0.15),
        width: chipWidth - 4 * scale,
        height: chipHeight * 0.4,
      ),
      Radius.circular(chipRadius * 0.8),
    );
    final highlightPaint = Paint()
      ..color = SemanticColors.glow(0.1 * opacity)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(highlightRect, highlightPaint);

    // Draw text
    final textOffset = Offset(
      position.dx - textPainter.width / 2,
      position.dy - textPainter.height / 2,
    );

    // Text shadow for depth
    final shadowSpan = TextSpan(
      text: displayName,
      style: TextStyle(
        fontSize: 11 * scale,
        fontWeight: FontWeight.w600,
        color: Colors.black.withValues(alpha: 0.3 * opacity),
        letterSpacing: 0.3,
      ),
    );
    final shadowPainter = TextPainter(
      text: shadowSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    shadowPainter.paint(canvas, textOffset + Offset(0, 1 * scale));

    // Main text
    textPainter.paint(canvas, textOffset);
  }

  String _formatName(String name) {
    // Clean up and truncate
    final cleaned = name.trim();
    if (cleaned.length > 12) {
      return '${cleaned.substring(0, 10)}…';
    }
    return cleaned;
  }

  @override
  bool shouldRepaint(_OrbitingChipsPainter oldDelegate) => true;
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
      maxVisibleNames: 6,
      chipDisplayDuration: const Duration(seconds: 5),
    );
  }
}
