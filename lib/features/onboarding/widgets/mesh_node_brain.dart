import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/widgets/animated_mesh_node.dart';

/// Emotional states for the mesh brain advisor
enum MeshBrainMood {
  /// Default curious state - gentle wobble, looking around
  idle,

  /// Processing/thinking - faster spin, concentrated
  thinking,

  /// Excited/happy - bouncy, sparkly
  excited,

  /// Approving/nodding - up-down motion
  approving,

  /// Beckoning/inviting - forward pulse
  inviting,

  /// Alert/attention - quick pulse, bright
  alert,

  /// Speaking/explaining - rhythmic pulse synced to speech
  speaking,

  /// Sleepy/dormant - slow breathe, dim
  dormant,

  /// Celebrating - wild spin, particles
  celebrating,
}

/// A sentient mesh node brain that acts as an onboarding advisor.
/// Has personality, emotions, and responds to user interactions.
class MeshNodeBrain extends StatefulWidget {
  /// Size of the brain
  final double size;

  /// Current emotional mood
  final MeshBrainMood mood;

  /// Custom gradient colors (optional)
  final List<Color>? colors;

  /// Glow intensity multiplier
  final double glowIntensity;

  /// Whether the brain should respond to touch
  final bool interactive;

  /// Callback when tapped
  final VoidCallback? onTap;

  /// Whether to show thought particles
  final bool showThoughtParticles;

  /// External text being "spoken" (affects animation rhythm)
  final String? speakingText;

  const MeshNodeBrain({
    super.key,
    this.size = 180,
    this.mood = MeshBrainMood.idle,
    this.colors,
    this.glowIntensity = 0.8,
    this.interactive = true,
    this.onTap,
    this.showThoughtParticles = true,
    this.speakingText,
  });

  @override
  State<MeshNodeBrain> createState() => _MeshNodeBrainState();
}

class _MeshNodeBrainState extends State<MeshNodeBrain>
    with TickerProviderStateMixin {
  // Core animation controllers
  late AnimationController _wobbleController;
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late AnimationController _moodTransitionController;
  late AnimationController _particleController;
  late AnimationController _orbitController;

  // Animations
  late Animation<double> _wobbleX;
  late Animation<double> _wobbleY;
  late Animation<double> _pulse;
  late Animation<double> _bounce;

  // Random for organic motion
  final _random = math.Random();

  // Particle positions for thought bubbles
  final List<_ThoughtParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeParticles();
    _updateAnimationsForMood(widget.mood, animate: false);
  }

  void _initializeControllers() {
    // Wobble - organic swaying motion (prime ratio durations for non-repeating)
    _wobbleController = AnimationController(
      duration: const Duration(milliseconds: 2731),
      vsync: this,
    );

    // Pulse - glow breathing
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1879),
      vsync: this,
    );

    // Bounce - vertical motion
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1237),
      vsync: this,
    );

    // Mood transition
    _moodTransitionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Particles
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    // Orbit rings
    _orbitController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    )..repeat();

    // Initialize animations
    _wobbleX = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _wobbleController, curve: Curves.easeInOut),
    );
    _wobbleY = Tween<double>(begin: -0.06, end: 0.06).animate(
      CurvedAnimation(parent: _wobbleController, curve: Curves.easeInOut),
    );
    _pulse = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _bounce = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  void _initializeParticles() {
    for (int i = 0; i < 8; i++) {
      _particles.add(
        _ThoughtParticle(
          angle: (i / 8) * 2 * math.pi,
          radius: 0.6 + _random.nextDouble() * 0.4,
          speed: 0.5 + _random.nextDouble() * 0.5,
          size: 3 + _random.nextDouble() * 4,
          phase: _random.nextDouble() * 2 * math.pi,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(MeshNodeBrain oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _updateAnimationsForMood(widget.mood, animate: true);
    }
  }

  void _updateAnimationsForMood(MeshBrainMood mood, {required bool animate}) {
    // Stop all animations first
    _wobbleController.stop();
    _pulseController.stop();
    _bounceController.stop();

    // Reset and configure based on mood
    switch (mood) {
      case MeshBrainMood.idle:
        _wobbleController
          ..duration = const Duration(milliseconds: 2731)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 1879)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.thinking:
        _wobbleController
          ..duration = const Duration(milliseconds: 800)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 600)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.excited:
        _wobbleController
          ..duration = const Duration(milliseconds: 400)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 300)
          ..repeat(reverse: true);
        _bounceController
          ..duration = const Duration(milliseconds: 500)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.approving:
        _bounceController
          ..duration = const Duration(milliseconds: 400)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 1200)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.inviting:
        _pulseController
          ..duration = const Duration(milliseconds: 800)
          ..repeat(reverse: true);
        _bounceController
          ..duration = const Duration(milliseconds: 1500)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.alert:
        _pulseController
          ..duration = const Duration(milliseconds: 200)
          ..repeat(reverse: true);
        _wobbleController
          ..duration = const Duration(milliseconds: 150)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.speaking:
        _pulseController
          ..duration = const Duration(milliseconds: 400)
          ..repeat(reverse: true);
        _wobbleController
          ..duration = const Duration(milliseconds: 600)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.dormant:
        _pulseController
          ..duration = const Duration(milliseconds: 4000)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.celebrating:
        _wobbleController
          ..duration = const Duration(milliseconds: 300)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 200)
          ..repeat(reverse: true);
        _bounceController
          ..duration = const Duration(milliseconds: 350)
          ..repeat(reverse: true);
        break;
    }

    if (animate) {
      _moodTransitionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    _pulseController.dispose();
    _bounceController.dispose();
    _moodTransitionController.dispose();
    _particleController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  List<Color> get _colors =>
      widget.colors ??
      const [Color(0xFFFF6B4A), Color(0xFFE91E8C), Color(0xFF4F6AF6)];

  double get _moodGlowMultiplier {
    switch (widget.mood) {
      case MeshBrainMood.idle:
        return 1.0;
      case MeshBrainMood.thinking:
        return 1.3;
      case MeshBrainMood.excited:
        return 1.6;
      case MeshBrainMood.approving:
        return 1.2;
      case MeshBrainMood.inviting:
        return 1.4;
      case MeshBrainMood.alert:
        return 1.8;
      case MeshBrainMood.speaking:
        return 1.2;
      case MeshBrainMood.dormant:
        return 0.5;
      case MeshBrainMood.celebrating:
        return 2.0;
    }
  }

  double get _moodScale {
    switch (widget.mood) {
      case MeshBrainMood.excited:
        return 1.1;
      case MeshBrainMood.celebrating:
        return 1.15;
      case MeshBrainMood.dormant:
        return 0.95;
      default:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.interactive ? _handleTap : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _wobbleController,
          _pulseController,
          _bounceController,
          _moodTransitionController,
          _particleController,
          _orbitController,
        ]),
        builder: (context, child) {
          return SizedBox(
            width: widget.size * 1.6,
            height: widget.size * 1.6,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow rings
                ..._buildGlowRings(),

                // Thought particles
                if (widget.showThoughtParticles) ..._buildThoughtParticles(),

                // Orbital rings
                _buildOrbitalRings(),

                // Main brain mesh
                _buildBrainMesh(),

                // Inner core glow
                _buildCoreGlow(),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildGlowRings() {
    final intensity = widget.glowIntensity * _pulse.value * _moodGlowMultiplier;
    final baseColor = _colors[1];

    return [
      // Outer ring
      Container(
        width: widget.size * 1.5,
        height: widget.size * 1.5,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              baseColor.withValues(alpha: intensity * 0.15),
              baseColor.withValues(alpha: intensity * 0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
      ),
      // Middle ring
      Container(
        width: widget.size * 1.25,
        height: widget.size * 1.25,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              _colors[0].withValues(alpha: intensity * 0.2),
              _colors[2].withValues(alpha: intensity * 0.08),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildThoughtParticles() {
    final particles = <Widget>[];
    final isActive =
        widget.mood == MeshBrainMood.thinking ||
        widget.mood == MeshBrainMood.excited ||
        widget.mood == MeshBrainMood.celebrating;

    if (!isActive) return particles;

    for (final particle in _particles) {
      final progress = (_particleController.value + particle.phase) % 1.0;
      final angle = particle.angle + progress * 2 * math.pi * particle.speed;
      final radius =
          widget.size *
          0.5 *
          particle.radius *
          (0.8 + 0.2 * math.sin(progress * math.pi * 2));

      final x = math.cos(angle) * radius;
      final y = math.sin(angle) * radius * 0.6; // Flatten for 3D effect
      final opacity = math.sin(progress * math.pi) * 0.8;

      particles.add(
        Positioned(
          left: widget.size * 0.8 + x - particle.size / 2,
          top: widget.size * 0.8 + y - particle.size / 2,
          child: Container(
            width: particle.size,
            height: particle.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _colors[_random.nextInt(_colors.length)].withValues(
                alpha: opacity,
              ),
              boxShadow: [
                BoxShadow(
                  color: _colors[1].withValues(alpha: opacity * 0.5),
                  blurRadius: particle.size,
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

  Widget _buildOrbitalRings() {
    final rotation = _orbitController.value * 2 * math.pi;
    final isActive = widget.mood != MeshBrainMood.dormant;

    if (!isActive) return const SizedBox.shrink();

    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(0.3)
        ..rotateY(rotation),
      alignment: Alignment.center,
      child: CustomPaint(
        size: Size(widget.size * 1.3, widget.size * 1.3),
        painter: _OrbitalRingsPainter(
          colors: _colors,
          progress: _orbitController.value,
          intensity: _pulse.value * 0.6,
        ),
      ),
    );
  }

  Widget _buildBrainMesh() {
    // Calculate wobble offsets
    final wobbleX = _wobbleX.value;
    final wobbleY = _wobbleY.value;

    // Calculate bounce offset
    double bounceOffset = 0;
    if (widget.mood == MeshBrainMood.excited ||
        widget.mood == MeshBrainMood.approving ||
        widget.mood == MeshBrainMood.celebrating) {
      bounceOffset = math.sin(_bounce.value * math.pi) * 8;
    } else if (widget.mood == MeshBrainMood.inviting) {
      bounceOffset = math.sin(_bounce.value * math.pi * 2) * 4;
    }

    // Scale animation
    final scale = _moodScale + (_pulse.value - 0.85) * 0.1;

    return Transform.translate(
      offset: Offset(0, -bounceOffset),
      child: Transform.scale(
        scale: scale,
        child: AnimatedMeshNode(
          size: widget.size,
          animationType: _getMeshAnimationType(),
          gradientColors: _colors,
          glowIntensity:
              widget.glowIntensity * _pulse.value * _moodGlowMultiplier,
          lineThickness: 0.6,
          nodeSize: 0.9,
          externalRotationX: wobbleX,
          externalRotationY: wobbleY,
        ),
      ),
    );
  }

  MeshNodeAnimationType _getMeshAnimationType() {
    switch (widget.mood) {
      case MeshBrainMood.thinking:
      case MeshBrainMood.speaking:
        return MeshNodeAnimationType.rotate;
      case MeshBrainMood.excited:
      case MeshBrainMood.celebrating:
        return MeshNodeAnimationType.pulseRotate;
      case MeshBrainMood.dormant:
        return MeshNodeAnimationType.breathe;
      default:
        return MeshNodeAnimationType.tumble;
    }
  }

  Widget _buildCoreGlow() {
    final intensity = _pulse.value * widget.glowIntensity * _moodGlowMultiplier;

    return IgnorePointer(
      child: Container(
        width: widget.size * 0.3,
        height: widget.size * 0.3,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: intensity * 0.6),
              _colors[1].withValues(alpha: intensity * 0.3),
              Colors.transparent,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    widget.onTap?.call();
  }
}

/// Particle data for thought bubbles
class _ThoughtParticle {
  final double angle;
  final double radius;
  final double speed;
  final double size;
  final double phase;

  _ThoughtParticle({
    required this.angle,
    required this.radius,
    required this.speed,
    required this.size,
    required this.phase,
  });
}

/// Custom painter for orbital rings
class _OrbitalRingsPainter extends CustomPainter {
  final List<Color> colors;
  final double progress;
  final double intensity;

  _OrbitalRingsPainter({
    required this.colors,
    required this.progress,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.85;

    // Draw multiple orbital arcs
    for (int i = 0; i < 3; i++) {
      final startAngle = progress * 2 * math.pi + (i * math.pi * 2 / 3);
      final sweepAngle = math.pi * 0.6;

      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: intensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - i * 8),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitalRingsPainter oldDelegate) =>
      progress != oldDelegate.progress || intensity != oldDelegate.intensity;
}
