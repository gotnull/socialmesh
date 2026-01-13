import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/social.dart';

/// Wraps a signal card and adds dust dissolution effect when it expires.
///
/// Features:
/// - Monitors TTL countdown
/// - Triggers dramatic dust dissolution when signal expires
/// - Particles scatter and fade away
/// - Calls onExpire callback when animation completes
class DustDissolveSignalCard extends StatefulWidget {
  const DustDissolveSignalCard({
    super.key,
    required this.signal,
    required this.child,
    this.onExpire,
    this.enabled = true,
  });

  final Post signal;
  final Widget child;
  final VoidCallback? onExpire;
  final bool enabled;

  @override
  State<DustDissolveSignalCard> createState() => _DustDissolveSignalCardState();
}

class _DustDissolveSignalCardState extends State<DustDissolveSignalCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _checkTimer;
  bool _isDissolving = false;
  final List<_DustParticle> _particles = [];
  final math.Random _random = math.Random();
  Size? _cardSize;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1500),
          )
          ..addListener(() => setState(() {}))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              widget.onExpire?.call();
            }
          });

    if (widget.enabled) {
      _startExpiryCheck();
    }
  }

  void _startExpiryCheck() {
    // Check every second for expiry
    _checkTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkExpiry();
    });
    // Initial check
    _checkExpiry();
  }

  void _checkExpiry() {
    if (_isDissolving) return;

    final expiresAt = widget.signal.expiresAt;
    if (expiresAt == null) return;

    final remaining = expiresAt.difference(DateTime.now());

    // Start dissolution when expired or about to expire (<1 second)
    if (remaining.inSeconds <= 0) {
      _startDissolve();
    }
  }

  void _startDissolve() {
    if (_isDissolving) return;
    _checkTimer?.cancel();

    setState(() {
      _isDissolving = true;
      _generateParticles();
    });

    _controller.forward(from: 0);
  }

  void _generateParticles() {
    _particles.clear();
    final size = _cardSize ?? const Size(300, 200);

    // Gradient colors for particles
    final colors = [
      const Color(0xFFFF3366),
      const Color(0xFF00D4FF),
      const Color(0xFFFFAA00),
      const Color(0xFF66FFAA),
      const Color(0xFFAA66FF),
      Colors.white,
    ];

    for (var i = 0; i < 1000; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;

      // Random dispersion angle and distance
      final angle = _random.nextDouble() * math.pi * 2;
      final distance = 100 + _random.nextDouble() * 200;
      final targetX = x + math.cos(angle) * distance;
      final targetY = y + math.sin(angle) * distance - distance * 0.3;

      _particles.add(
        _DustParticle(
          startX: x,
          startY: y,
          targetX: targetX,
          targetY: targetY,
          size: 1.5 + _random.nextDouble() * 3,
          color: colors[_random.nextInt(colors.length)],
          delay: _random.nextDouble() * 0.3,
          turbulence: 0.5 + _random.nextDouble() * 1.5,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(DustDissolveSignalCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _startExpiryCheck();
      } else {
        _checkTimer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _checkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Measure and display child
        if (!_isDissolving || _controller.value < 0.3)
          Opacity(
            opacity: _isDissolving
                ? (1 - _controller.value * 2).clamp(0.0, 1.0)
                : 1.0,
            child: _CardSizeCapture(
              onSizeChanged: (size) {
                if (_cardSize != size) {
                  _cardSize = size;
                }
              },
              child: widget.child,
            ),
          ),

        // Particle overlay
        if (_isDissolving && _cardSize != null)
          SizedBox(
            width: _cardSize!.width,
            height: _cardSize!.height,
            child: CustomPaint(
              painter: _DustDissolvePainter(
                particles: _particles,
                progress: _controller.value,
              ),
            ),
          ),
      ],
    );
  }
}

class _DustParticle {
  final double startX;
  final double startY;
  final double targetX;
  final double targetY;
  final double size;
  final Color color;
  final double delay;
  final double turbulence;

  _DustParticle({
    required this.startX,
    required this.startY,
    required this.targetX,
    required this.targetY,
    required this.size,
    required this.color,
    required this.delay,
    required this.turbulence,
  });
}

class _DustDissolvePainter extends CustomPainter {
  final List<_DustParticle> particles;
  final double progress;

  _DustDissolvePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Apply delay
      final adjustedProgress = ((progress - p.delay) / (1 - p.delay)).clamp(
        0.0,
        1.0,
      );
      if (adjustedProgress <= 0) continue;

      // Ease the progress
      final easedProgress = Curves.easeOutCubic.transform(adjustedProgress);

      // Turbulence for organic movement
      final turbX =
          math.sin(progress * math.pi * 4 + p.turbulence) * p.turbulence * 8;
      final turbY =
          math.cos(progress * math.pi * 3 + p.turbulence) * p.turbulence * 8;

      // Interpolate position
      final x = p.startX + (p.targetX - p.startX) * easedProgress + turbX;
      final y = p.startY + (p.targetY - p.startY) * easedProgress + turbY;

      // Fade out
      final alpha = (1 - easedProgress * 0.9).clamp(0.0, 1.0);

      if (alpha > 0) {
        // Glow
        final glowPaint = Paint()
          ..color = p.color.withValues(alpha: alpha * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(Offset(x, y), p.size * 1.5, glowPaint);

        // Core particle
        final paint = Paint()..color = p.color.withValues(alpha: alpha);
        canvas.drawCircle(
          Offset(x, y),
          p.size * (1 - easedProgress * 0.3),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DustDissolvePainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Helper widget to capture the size of a child
class _CardSizeCapture extends StatefulWidget {
  const _CardSizeCapture({required this.child, required this.onSizeChanged});

  final Widget child;
  final ValueChanged<Size> onSizeChanged;

  @override
  State<_CardSizeCapture> createState() => _CardSizeCaptureState();
}

class _CardSizeCaptureState extends State<_CardSizeCapture> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportSize());
  }

  void _reportSize() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      widget.onSizeChanged(box.size);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(key: _key, child: widget.child);
  }
}
