// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Looping mesh network animation with glowing nodes and connections.
class MeshNetworkAnimation extends StatefulWidget {
  const MeshNetworkAnimation({super.key});

  @override
  State<MeshNetworkAnimation> createState() => _MeshNetworkAnimationState();
}

class _MeshNetworkAnimationState extends State<MeshNetworkAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _driftController;

  final List<_MeshNode> _nodes = [];
  final List<_MeshConnection> _connections = [];
  final Random _random = Random();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();
  }

  void _generateNodes(Size size) {
    if (_initialized) return;

    const nodeCount = 18;
    for (var i = 0; i < nodeCount; i++) {
      _nodes.add(
        _MeshNode(
          position: Offset(
            _random.nextDouble() * size.width,
            _random.nextDouble() * size.height,
          ),
          driftOffset: Offset(
            (_random.nextDouble() - 0.5) * 40,
            (_random.nextDouble() - 0.5) * 40,
          ),
          size: 3.0 + _random.nextDouble() * 5.0,
          phase: _random.nextDouble(),
        ),
      );
    }

    for (var i = 0; i < _nodes.length; i++) {
      for (var j = i + 1; j < _nodes.length; j++) {
        final distance = (_nodes[i].position - _nodes[j].position).distance;
        if (distance < 180) {
          _connections.add(_MeshConnection(startIndex: i, endIndex: j));
        }
      }
    }

    _initialized = true;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _driftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _generateNodes(size);

        return AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _driftController]),
          builder: (context, _) {
            return CustomPaint(
              painter: _MeshNetworkPainter(
                nodes: _nodes,
                connections: _connections,
                pulseValue: _pulseController.value,
                driftValue: _driftController.value,
              ),
              size: size,
            );
          },
        );
      },
    );
  }
}

class _MeshNode {
  _MeshNode({
    required this.position,
    required this.driftOffset,
    required this.size,
    required this.phase,
  });

  final Offset position;
  final Offset driftOffset;
  final double size;
  final double phase;
}

class _MeshConnection {
  _MeshConnection({required this.startIndex, required this.endIndex});

  final int startIndex;
  final int endIndex;
}

class _MeshNetworkPainter extends CustomPainter {
  _MeshNetworkPainter({
    required this.nodes,
    required this.connections,
    required this.pulseValue,
    required this.driftValue,
  });

  final List<_MeshNode> nodes;
  final List<_MeshConnection> connections;
  final double pulseValue;
  final double driftValue;

  Offset _getNodePosition(_MeshNode node) {
    final driftPhase = (driftValue + node.phase) % 1.0;
    final driftX = sin(driftPhase * 2 * pi) * node.driftOffset.dx;
    final driftY = cos(driftPhase * 2 * pi) * node.driftOffset.dy;
    return node.position + Offset(driftX, driftY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const accentColor = Color(0xFF00E5FF);
    const secondaryColor = Color(0xFF7C4DFF);

    for (final connection in connections) {
      final startPos = _getNodePosition(nodes[connection.startIndex]);
      final endPos = _getNodePosition(nodes[connection.endIndex]);

      final glowPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.15)
        ..strokeWidth = 4.0 + pulseValue * 2
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawLine(startPos, endPos, glowPaint);

      final linePaint = Paint()
        ..color = secondaryColor.withValues(alpha: 0.3)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(startPos, endPos, linePaint);
    }

    for (final node in nodes) {
      final pos = _getNodePosition(node);
      final nodePulse = (pulseValue + node.phase) % 1.0;
      final currentSize = node.size * (0.8 + nodePulse * 0.4);

      final glowPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.15 + nodePulse * 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(pos, currentSize + 6, glowPaint);

      final nodePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.8),
            accentColor.withValues(alpha: 0.6),
            secondaryColor.withValues(alpha: 0.2),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: pos, radius: currentSize));
      canvas.drawCircle(pos, currentSize, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeshNetworkPainter oldDelegate) => true;
}
