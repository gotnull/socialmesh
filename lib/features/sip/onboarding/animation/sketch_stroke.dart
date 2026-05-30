// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Interactive sketch visual for the onboarding flow (screen 5).
//
// The user draws a short stroke on a small pad. Each finished stroke lights a
// peer dot, conveying "your drawing reaches someone nearby" without words.
// Drawing it themselves creates ownership the way a static illustration never
// could.

import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import 'handwriting_hello.dart';

/// A small draw pad. Each completed stroke pulses a peer indicator and fires
/// [onStroke] (for haptics).
class SketchStroke extends StatefulWidget {
  const SketchStroke({
    super.key,
    required this.accent,
    this.onStroke,
    this.hint = '',
  });

  final Color accent;
  final VoidCallback? onStroke;

  /// Faint prompt shown while the pad is empty.
  final String hint;

  @override
  State<SketchStroke> createState() => _SketchStrokeState();
}

class _SketchStrokeState extends State<SketchStroke>
    with SingleTickerProviderStateMixin {
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];
  late final AnimationController _deliverController;

  @override
  void initState() {
    super.initState();
    _deliverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _deliverController.dispose();
    super.dispose();
  }

  void _start(Offset p) {
    setState(() => _current = [p]);
  }

  void _update(Offset p) {
    setState(() => _current = [..._current, p]);
  }

  void _end() {
    if (_current.length < 2) {
      setState(() => _current = []);
      return;
    }
    setState(() {
      _strokes.add(_current);
      // Cap retained strokes so the pad never accumulates unbounded points.
      if (_strokes.length > 6) _strokes.removeAt(0);
      _current = [];
    });
    _deliverController.forward(from: 0);
    widget.onStroke?.call();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final isEmpty = _strokes.isEmpty && _current.isEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius16),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => _start(d.localPosition),
              onPanUpdate: (d) => _update(d.localPosition),
              onPanEnd: (_) => _end(),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _SketchPainter(
                          strokes: _strokes,
                          current: _current,
                          accent: accent,
                        ),
                      ),
                    ),
                  ),
                  if (isEmpty)
                    Positioned.fill(
                      child: Semantics(
                        label: widget.hint,
                        child: IgnorePointer(
                          child: HandwritingHello(accent: accent),
                        ),
                      ),
                    ),
                  // Peer "received" indicator.
                  Positioned(
                    right: AppTheme.spacing12,
                    bottom: AppTheme.spacing12,
                    child: AnimatedBuilder(
                      animation: _deliverController,
                      builder: (context, child) {
                        final v = _deliverController.value;
                        return Opacity(
                          opacity: 0.4 + v * 0.6,
                          child: Transform.scale(
                            scale: 0.9 + v * 0.3,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spacing6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.16),
                        ),
                        child: Icon(
                          Icons.person_outline,
                          size: 16,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SketchPainter extends CustomPainter {
  _SketchPainter({
    required this.strokes,
    required this.current,
    required this.accent,
  });

  final List<List<Offset>> strokes;
  final List<Offset> current;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent;
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }
    if (current.length > 1) {
      _drawStroke(canvas, current, paint);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SketchPainter old) =>
      old.strokes != strokes || old.current != current || old.accent != accent;
}
