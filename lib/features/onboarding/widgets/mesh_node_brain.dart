import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/widgets/animated_mesh_node.dart';

/// Emotional states for the mesh brain advisor
enum MeshBrainMood {
  // === POSITIVE EMOTIONS ===
  /// Default curious state - gentle wobble, looking around
  idle,

  /// Happy - bouncy, bright glow
  happy,

  /// Excited - very bouncy, sparkly, fast
  excited,

  /// Celebrating - wild spin, particles everywhere
  celebrating,

  /// Laughing - rapid shake, jittery bounce
  laughing,

  /// Tickled - quick small wiggles, giggly motion
  tickled,

  /// Smiling - warm glow, gentle pulse
  smiling,

  /// Love - heart-like pulse, pink tint, floating
  love,

  /// Proud - puffed up, tall stance, bright
  proud,

  /// Grateful - gentle bow motion, warm
  grateful,

  /// Hopeful - upward gaze, rising motion
  hopeful,

  /// Playful - bouncing around, mischievous
  playful,

  /// Energized - rapid spin, electric
  energized,

  // === NEUTRAL/COMMUNICATIVE ===
  /// Thinking - concentrated spin
  thinking,

  /// Speaking - rhythmic pulse
  speaking,

  /// Curious - tilting, examining
  curious,

  /// Focused - intense, still, bright center
  focused,

  /// Approving - nodding up-down
  approving,

  /// Inviting - beckoning forward pulse
  inviting,

  /// Winking - asymmetric playful pulse
  winking,

  /// Listening - attentive, slight lean
  listening,

  // === ALERTNESS ===
  /// Alert - quick pulse, bright
  alert,

  /// Surprised - sudden scale up, flash
  surprised,

  /// Alarmed - rapid flash, warning
  alarmed,

  // === NEGATIVE/LOW ENERGY ===
  /// Sad - droopy, dim, slow
  sad,

  /// Sleepy/dormant - very slow breathe
  dormant,

  /// Tired - sluggish, dim
  tired,

  /// Bored - slow droop, occasional sigh
  bored,

  /// Confused - wobbling, tilting, uncertain
  confused,

  /// Nervous - shaky, flickering
  nervous,

  /// Scared - trembling, shrinking
  scared,

  /// Embarrassed - shrinking, warm tint
  embarrassed,

  /// Shy - small, hiding motion
  shy,

  /// Grumpy - heavy, dark, slow
  grumpy,

  /// Annoyed - twitching, irritated
  annoyed,

  /// Angry - red tint, sharp movements
  angry,

  // === SPECIAL ===
  /// Dizzy - spiral motion, disoriented
  dizzy,

  /// Glitching - digital corruption effect
  glitching,

  /// Zen - peaceful, meditative, slow breathe
  zen,

  /// Sassy - attitude, side movements
  sassy,

  /// Mischievous - sneaky, plotting
  mischievous,

  /// Hypnotized - spiral, trance-like
  hypnotized,

  /// Loading - processing indicator
  loading,

  /// Error - red flash, shake
  error,

  /// Success - green glow, celebration
  success,
}

/// Extension to get display name and emoji for moods
extension MeshBrainMoodExtension on MeshBrainMood {
  String get displayName {
    switch (this) {
      case MeshBrainMood.idle:
        return 'Idle';
      case MeshBrainMood.happy:
        return 'Happy';
      case MeshBrainMood.excited:
        return 'Excited';
      case MeshBrainMood.celebrating:
        return 'Celebrating';
      case MeshBrainMood.laughing:
        return 'Laughing';
      case MeshBrainMood.tickled:
        return 'Tickled';
      case MeshBrainMood.smiling:
        return 'Smiling';
      case MeshBrainMood.love:
        return 'Love';
      case MeshBrainMood.proud:
        return 'Proud';
      case MeshBrainMood.grateful:
        return 'Grateful';
      case MeshBrainMood.hopeful:
        return 'Hopeful';
      case MeshBrainMood.playful:
        return 'Playful';
      case MeshBrainMood.energized:
        return 'Energized';
      case MeshBrainMood.thinking:
        return 'Thinking';
      case MeshBrainMood.speaking:
        return 'Speaking';
      case MeshBrainMood.curious:
        return 'Curious';
      case MeshBrainMood.focused:
        return 'Focused';
      case MeshBrainMood.approving:
        return 'Approving';
      case MeshBrainMood.inviting:
        return 'Inviting';
      case MeshBrainMood.winking:
        return 'Winking';
      case MeshBrainMood.listening:
        return 'Listening';
      case MeshBrainMood.alert:
        return 'Alert';
      case MeshBrainMood.surprised:
        return 'Surprised';
      case MeshBrainMood.alarmed:
        return 'Alarmed';
      case MeshBrainMood.sad:
        return 'Sad';
      case MeshBrainMood.dormant:
        return 'Dormant';
      case MeshBrainMood.tired:
        return 'Tired';
      case MeshBrainMood.bored:
        return 'Bored';
      case MeshBrainMood.confused:
        return 'Confused';
      case MeshBrainMood.nervous:
        return 'Nervous';
      case MeshBrainMood.scared:
        return 'Scared';
      case MeshBrainMood.embarrassed:
        return 'Embarrassed';
      case MeshBrainMood.shy:
        return 'Shy';
      case MeshBrainMood.grumpy:
        return 'Grumpy';
      case MeshBrainMood.annoyed:
        return 'Annoyed';
      case MeshBrainMood.angry:
        return 'Angry';
      case MeshBrainMood.dizzy:
        return 'Dizzy';
      case MeshBrainMood.glitching:
        return 'Glitching';
      case MeshBrainMood.zen:
        return 'Zen';
      case MeshBrainMood.sassy:
        return 'Sassy';
      case MeshBrainMood.mischievous:
        return 'Mischievous';
      case MeshBrainMood.hypnotized:
        return 'Hypnotized';
      case MeshBrainMood.loading:
        return 'Loading';
      case MeshBrainMood.error:
        return 'Error';
      case MeshBrainMood.success:
        return 'Success';
    }
  }

  String get emoji {
    switch (this) {
      case MeshBrainMood.idle:
        return '😐';
      case MeshBrainMood.happy:
        return '😊';
      case MeshBrainMood.excited:
        return '🤩';
      case MeshBrainMood.celebrating:
        return '🎉';
      case MeshBrainMood.laughing:
        return '😂';
      case MeshBrainMood.tickled:
        return '🤭';
      case MeshBrainMood.smiling:
        return '😄';
      case MeshBrainMood.love:
        return '😍';
      case MeshBrainMood.proud:
        return '😤';
      case MeshBrainMood.grateful:
        return '🙏';
      case MeshBrainMood.hopeful:
        return '🌟';
      case MeshBrainMood.playful:
        return '😜';
      case MeshBrainMood.energized:
        return '⚡';
      case MeshBrainMood.thinking:
        return '🤔';
      case MeshBrainMood.speaking:
        return '💬';
      case MeshBrainMood.curious:
        return '🧐';
      case MeshBrainMood.focused:
        return '🎯';
      case MeshBrainMood.approving:
        return '👍';
      case MeshBrainMood.inviting:
        return '👋';
      case MeshBrainMood.winking:
        return '😉';
      case MeshBrainMood.listening:
        return '👂';
      case MeshBrainMood.alert:
        return '⚠️';
      case MeshBrainMood.surprised:
        return '😲';
      case MeshBrainMood.alarmed:
        return '🚨';
      case MeshBrainMood.sad:
        return '😢';
      case MeshBrainMood.dormant:
        return '😴';
      case MeshBrainMood.tired:
        return '😩';
      case MeshBrainMood.bored:
        return '😑';
      case MeshBrainMood.confused:
        return '😵';
      case MeshBrainMood.nervous:
        return '😰';
      case MeshBrainMood.scared:
        return '😱';
      case MeshBrainMood.embarrassed:
        return '😳';
      case MeshBrainMood.shy:
        return '🙈';
      case MeshBrainMood.grumpy:
        return '😠';
      case MeshBrainMood.annoyed:
        return '😤';
      case MeshBrainMood.angry:
        return '🔥';
      case MeshBrainMood.dizzy:
        return '💫';
      case MeshBrainMood.glitching:
        return '👾';
      case MeshBrainMood.zen:
        return '🧘';
      case MeshBrainMood.sassy:
        return '💅';
      case MeshBrainMood.mischievous:
        return '😈';
      case MeshBrainMood.hypnotized:
        return '🌀';
      case MeshBrainMood.loading:
        return '⏳';
      case MeshBrainMood.error:
        return '❌';
      case MeshBrainMood.success:
        return '✅';
    }
  }

  /// Get category for grouping
  String get category {
    switch (this) {
      case MeshBrainMood.idle:
      case MeshBrainMood.happy:
      case MeshBrainMood.excited:
      case MeshBrainMood.celebrating:
      case MeshBrainMood.laughing:
      case MeshBrainMood.tickled:
      case MeshBrainMood.smiling:
      case MeshBrainMood.love:
      case MeshBrainMood.proud:
      case MeshBrainMood.grateful:
      case MeshBrainMood.hopeful:
      case MeshBrainMood.playful:
      case MeshBrainMood.energized:
        return 'Positive';
      case MeshBrainMood.thinking:
      case MeshBrainMood.speaking:
      case MeshBrainMood.curious:
      case MeshBrainMood.focused:
      case MeshBrainMood.approving:
      case MeshBrainMood.inviting:
      case MeshBrainMood.winking:
      case MeshBrainMood.listening:
        return 'Neutral';
      case MeshBrainMood.alert:
      case MeshBrainMood.surprised:
      case MeshBrainMood.alarmed:
        return 'Alert';
      case MeshBrainMood.sad:
      case MeshBrainMood.dormant:
      case MeshBrainMood.tired:
      case MeshBrainMood.bored:
      case MeshBrainMood.confused:
      case MeshBrainMood.nervous:
      case MeshBrainMood.scared:
      case MeshBrainMood.embarrassed:
      case MeshBrainMood.shy:
      case MeshBrainMood.grumpy:
      case MeshBrainMood.annoyed:
      case MeshBrainMood.angry:
        return 'Negative';
      case MeshBrainMood.dizzy:
      case MeshBrainMood.glitching:
      case MeshBrainMood.zen:
      case MeshBrainMood.sassy:
      case MeshBrainMood.mischievous:
      case MeshBrainMood.hypnotized:
      case MeshBrainMood.loading:
      case MeshBrainMood.error:
      case MeshBrainMood.success:
        return 'Special';
    }
  }
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

  /// Whether to show expression overlay (eyes, mouth)
  final bool showExpression;

  const MeshNodeBrain({
    super.key,
    this.size = 180,
    this.mood = MeshBrainMood.idle,
    this.colors,
    this.glowIntensity = 0.8,
    this.interactive = true,
    this.onTap,
    this.showThoughtParticles = true,
    this.showExpression = true,
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
  late AnimationController _particleController;
  late AnimationController _orbitController;
  late AnimationController _expressionController;
  late AnimationController _specialController;

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
    _updateAnimationsForMood(widget.mood);
  }

  void _initializeControllers() {
    _wobbleController = AnimationController(
      duration: const Duration(milliseconds: 2731),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1879),
      vsync: this,
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1237),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _orbitController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    )..repeat();

    _expressionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _specialController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

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
    for (int i = 0; i < 12; i++) {
      _particles.add(
        _ThoughtParticle(
          angle: (i / 12) * 2 * math.pi,
          radius: 0.5 + _random.nextDouble() * 0.5,
          speed: 0.3 + _random.nextDouble() * 0.7,
          size: 2 + _random.nextDouble() * 5,
          phase: _random.nextDouble() * 2 * math.pi,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(MeshNodeBrain oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _updateAnimationsForMood(widget.mood);
    }
  }

  void _updateAnimationsForMood(MeshBrainMood mood) {
    _wobbleController.stop();
    _pulseController.stop();
    _bounceController.stop();
    _specialController.stop();

    switch (mood) {
      // === POSITIVE ===
      case MeshBrainMood.idle:
        _wobbleController
          ..duration = const Duration(milliseconds: 2731)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 1879)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.happy:
        _wobbleController
          ..duration = const Duration(milliseconds: 600)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 500)
          ..repeat(reverse: true);
        _bounceController
          ..duration = const Duration(milliseconds: 800)
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

      case MeshBrainMood.laughing:
        _wobbleController
          ..duration = const Duration(milliseconds: 120)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 150)
          ..repeat(reverse: true);
        _bounceController
          ..duration = const Duration(milliseconds: 200)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.tickled:
        _wobbleController
          ..duration = const Duration(milliseconds: 80)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 100)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.smiling:
        _pulseController
          ..duration = const Duration(milliseconds: 1500)
          ..repeat(reverse: true);
        _wobbleController
          ..duration = const Duration(milliseconds: 2000)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.love:
        _pulseController
          ..duration = const Duration(milliseconds: 600)
          ..repeat(reverse: true);
        _bounceController
          ..duration = const Duration(milliseconds: 1200)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.proud:
        _pulseController
          ..duration = const Duration(milliseconds: 1000)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.grateful:
        _bounceController
          ..duration = const Duration(milliseconds: 2000)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 1500)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.hopeful:
        _bounceController
          ..duration = const Duration(milliseconds: 1500)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 1200)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.playful:
        _wobbleController
          ..duration = const Duration(milliseconds: 500)
          ..repeat(reverse: true);
        _bounceController
          ..duration = const Duration(milliseconds: 600)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 400)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.energized:
        _wobbleController
          ..duration = const Duration(milliseconds: 200)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 150)
          ..repeat(reverse: true);
        break;

      // === NEUTRAL ===
      case MeshBrainMood.thinking:
        _wobbleController
          ..duration = const Duration(milliseconds: 800)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 600)
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

      case MeshBrainMood.curious:
        _wobbleController
          ..duration = const Duration(milliseconds: 1200)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 1000)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.focused:
        _pulseController
          ..duration = const Duration(milliseconds: 2000)
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

      case MeshBrainMood.winking:
        _pulseController
          ..duration = const Duration(milliseconds: 800)
          ..repeat(reverse: true);
        _expressionController
          ..duration = const Duration(milliseconds: 300)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.listening:
        _wobbleController
          ..duration = const Duration(milliseconds: 1500)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 1800)
          ..repeat(reverse: true);
        break;

      // === ALERT ===
      case MeshBrainMood.alert:
        _pulseController
          ..duration = const Duration(milliseconds: 200)
          ..repeat(reverse: true);
        _wobbleController
          ..duration = const Duration(milliseconds: 150)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.surprised:
        _pulseController
          ..duration = const Duration(milliseconds: 150)
          ..repeat(reverse: true);
        _specialController
          ..duration = const Duration(milliseconds: 300)
          ..forward();
        break;

      case MeshBrainMood.alarmed:
        _pulseController
          ..duration = const Duration(milliseconds: 100)
          ..repeat(reverse: true);
        _wobbleController
          ..duration = const Duration(milliseconds: 80)
          ..repeat(reverse: true);
        break;

      // === NEGATIVE ===
      case MeshBrainMood.sad:
        _pulseController
          ..duration = const Duration(milliseconds: 3000)
          ..repeat(reverse: true);
        _bounceController
          ..duration = const Duration(milliseconds: 2500)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.dormant:
        _pulseController
          ..duration = const Duration(milliseconds: 4000)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.tired:
        _pulseController
          ..duration = const Duration(milliseconds: 3500)
          ..repeat(reverse: true);
        _wobbleController
          ..duration = const Duration(milliseconds: 4000)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.bored:
        _pulseController
          ..duration = const Duration(milliseconds: 3000)
          ..repeat(reverse: true);
        _wobbleController
          ..duration = const Duration(milliseconds: 5000)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.confused:
        _wobbleController
          ..duration = const Duration(milliseconds: 600)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 800)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.nervous:
        _wobbleController
          ..duration = const Duration(milliseconds: 150)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 200)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.scared:
        _wobbleController
          ..duration = const Duration(milliseconds: 100)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 120)
          ..repeat(reverse: true);
        _bounceController
          ..duration = const Duration(milliseconds: 150)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.embarrassed:
        _pulseController
          ..duration = const Duration(milliseconds: 500)
          ..repeat(reverse: true);
        _bounceController
          ..duration = const Duration(milliseconds: 800)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.shy:
        _pulseController
          ..duration = const Duration(milliseconds: 1500)
          ..repeat(reverse: true);
        _wobbleController
          ..duration = const Duration(milliseconds: 2000)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.grumpy:
        _pulseController
          ..duration = const Duration(milliseconds: 2000)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.annoyed:
        _wobbleController
          ..duration = const Duration(milliseconds: 300)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 400)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.angry:
        _wobbleController
          ..duration = const Duration(milliseconds: 200)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 150)
          ..repeat(reverse: true);
        break;

      // === SPECIAL ===
      case MeshBrainMood.dizzy:
        _wobbleController
          ..duration = const Duration(milliseconds: 400)
          ..repeat();
        _pulseController
          ..duration = const Duration(milliseconds: 500)
          ..repeat(reverse: true);
        _specialController
          ..duration = const Duration(milliseconds: 2000)
          ..repeat();
        break;

      case MeshBrainMood.glitching:
        _wobbleController
          ..duration = const Duration(milliseconds: 50)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 80)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.zen:
        _pulseController
          ..duration = const Duration(milliseconds: 5000)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.sassy:
        _wobbleController
          ..duration = const Duration(milliseconds: 700)
          ..repeat(reverse: true);
        _bounceController
          ..duration = const Duration(milliseconds: 500)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 600)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.mischievous:
        _wobbleController
          ..duration = const Duration(milliseconds: 800)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 500)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.hypnotized:
        _specialController
          ..duration = const Duration(milliseconds: 3000)
          ..repeat();
        _pulseController
          ..duration = const Duration(milliseconds: 1500)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.loading:
        _specialController
          ..duration = const Duration(milliseconds: 1500)
          ..repeat();
        _pulseController
          ..duration = const Duration(milliseconds: 800)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.error:
        _wobbleController
          ..duration = const Duration(milliseconds: 100)
          ..repeat(reverse: true);
        _pulseController
          ..duration = const Duration(milliseconds: 200)
          ..repeat(reverse: true);
        break;

      case MeshBrainMood.success:
        _pulseController
          ..duration = const Duration(milliseconds: 400)
          ..repeat(reverse: true);
        _bounceController
          ..duration = const Duration(milliseconds: 600)
          ..repeat(reverse: true);
        break;
    }
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    _pulseController.dispose();
    _bounceController.dispose();
    _particleController.dispose();
    _orbitController.dispose();
    _expressionController.dispose();
    _specialController.dispose();
    super.dispose();
  }

  List<Color> get _defaultColors {
    // Return mood-specific colors
    switch (widget.mood) {
      case MeshBrainMood.love:
        return const [Color(0xFFFF69B4), Color(0xFFFF1493), Color(0xFFFF69B4)];
      case MeshBrainMood.angry:
        return const [Color(0xFFFF4444), Color(0xFFCC0000), Color(0xFFFF6666)];
      case MeshBrainMood.sad:
        return const [Color(0xFF6699CC), Color(0xFF336699), Color(0xFF99CCFF)];
      case MeshBrainMood.scared:
        return const [Color(0xFF9966CC), Color(0xFF663399), Color(0xFFCC99FF)];
      case MeshBrainMood.error:
        return const [Color(0xFFFF0000), Color(0xFFCC0000), Color(0xFFFF3333)];
      case MeshBrainMood.success:
        return const [Color(0xFF00FF00), Color(0xFF00CC00), Color(0xFF66FF66)];
      case MeshBrainMood.energized:
        return const [Color(0xFFFFFF00), Color(0xFFFFCC00), Color(0xFFFFFF66)];
      case MeshBrainMood.zen:
        return const [Color(0xFF00FFFF), Color(0xFF00CCCC), Color(0xFF66FFFF)];
      case MeshBrainMood.glitching:
        return const [Color(0xFF00FF00), Color(0xFFFF00FF), Color(0xFF00FFFF)];
      case MeshBrainMood.embarrassed:
        return const [Color(0xFFFF9999), Color(0xFFFF6666), Color(0xFFFFCCCC)];
      default:
        return const [Color(0xFFFF6B4A), Color(0xFFE91E8C), Color(0xFF4F6AF6)];
    }
  }

  List<Color> get _colors => widget.colors ?? _defaultColors;

  double get _moodGlowMultiplier {
    switch (widget.mood) {
      case MeshBrainMood.idle:
      case MeshBrainMood.listening:
      case MeshBrainMood.curious:
        return 1.0;
      case MeshBrainMood.thinking:
      case MeshBrainMood.speaking:
      case MeshBrainMood.approving:
      case MeshBrainMood.smiling:
        return 1.2;
      case MeshBrainMood.happy:
      case MeshBrainMood.hopeful:
      case MeshBrainMood.grateful:
      case MeshBrainMood.inviting:
        return 1.3;
      case MeshBrainMood.excited:
      case MeshBrainMood.proud:
      case MeshBrainMood.playful:
      case MeshBrainMood.love:
        return 1.5;
      case MeshBrainMood.alert:
      case MeshBrainMood.surprised:
      case MeshBrainMood.winking:
        return 1.6;
      case MeshBrainMood.celebrating:
      case MeshBrainMood.energized:
      case MeshBrainMood.success:
        return 1.8;
      case MeshBrainMood.laughing:
      case MeshBrainMood.tickled:
        return 1.7;
      case MeshBrainMood.alarmed:
      case MeshBrainMood.angry:
      case MeshBrainMood.error:
        return 2.0;
      case MeshBrainMood.dormant:
      case MeshBrainMood.tired:
      case MeshBrainMood.bored:
        return 0.5;
      case MeshBrainMood.sad:
      case MeshBrainMood.grumpy:
        return 0.6;
      case MeshBrainMood.shy:
      case MeshBrainMood.embarrassed:
        return 0.8;
      case MeshBrainMood.nervous:
      case MeshBrainMood.scared:
      case MeshBrainMood.confused:
        return 1.4;
      case MeshBrainMood.annoyed:
        return 1.3;
      case MeshBrainMood.dizzy:
      case MeshBrainMood.hypnotized:
        return 1.5;
      case MeshBrainMood.glitching:
        return 2.2;
      case MeshBrainMood.zen:
        return 0.9;
      case MeshBrainMood.sassy:
      case MeshBrainMood.mischievous:
        return 1.4;
      case MeshBrainMood.focused:
        return 1.6;
      case MeshBrainMood.loading:
        return 1.2;
    }
  }

  double get _moodScale {
    switch (widget.mood) {
      case MeshBrainMood.excited:
      case MeshBrainMood.happy:
      case MeshBrainMood.playful:
        return 1.08;
      case MeshBrainMood.celebrating:
      case MeshBrainMood.laughing:
        return 1.12;
      case MeshBrainMood.proud:
        return 1.15;
      case MeshBrainMood.surprised:
        return 1.2;
      case MeshBrainMood.dormant:
      case MeshBrainMood.tired:
      case MeshBrainMood.sad:
        return 0.92;
      case MeshBrainMood.shy:
      case MeshBrainMood.scared:
      case MeshBrainMood.embarrassed:
        return 0.88;
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
          _particleController,
          _orbitController,
          _expressionController,
          _specialController,
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

                // Expression overlay (eyes, mouth effects)
                if (widget.showExpression) _buildExpressionOverlay(),
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
    final isActive = _shouldShowParticles;

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
      final y = math.sin(angle) * radius * 0.6;
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

  bool get _shouldShowParticles {
    switch (widget.mood) {
      case MeshBrainMood.thinking:
      case MeshBrainMood.excited:
      case MeshBrainMood.celebrating:
      case MeshBrainMood.love:
      case MeshBrainMood.laughing:
      case MeshBrainMood.energized:
      case MeshBrainMood.confused:
      case MeshBrainMood.dizzy:
      case MeshBrainMood.success:
        return true;
      default:
        return false;
    }
  }

  Widget _buildOrbitalRings() {
    final rotation = _orbitController.value * 2 * math.pi;
    final isActive =
        widget.mood != MeshBrainMood.dormant &&
        widget.mood != MeshBrainMood.tired &&
        widget.mood != MeshBrainMood.sad;

    if (!isActive) return const SizedBox.shrink();

    double extraRotation = 0;
    if (widget.mood == MeshBrainMood.dizzy ||
        widget.mood == MeshBrainMood.hypnotized) {
      extraRotation = _specialController.value * 4 * math.pi;
    }

    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(0.3)
        ..rotateY(rotation + extraRotation),
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
    double wobbleX = _wobbleX.value;
    double wobbleY = _wobbleY.value;

    // Special wobble modifications
    if (widget.mood == MeshBrainMood.dizzy) {
      final dizzyAngle = _specialController.value * 2 * math.pi;
      wobbleX += math.sin(dizzyAngle) * 0.2;
      wobbleY += math.cos(dizzyAngle) * 0.15;
    } else if (widget.mood == MeshBrainMood.sassy) {
      wobbleX *= 1.5; // More side-to-side attitude
    } else if (widget.mood == MeshBrainMood.curious) {
      wobbleX *= 0.5;
      wobbleY = math.sin(_wobbleController.value * math.pi) * 0.15; // Tilt
    }

    // Calculate bounce offset
    double bounceOffset = 0;
    if (widget.mood == MeshBrainMood.excited ||
        widget.mood == MeshBrainMood.happy ||
        widget.mood == MeshBrainMood.celebrating ||
        widget.mood == MeshBrainMood.laughing ||
        widget.mood == MeshBrainMood.playful ||
        widget.mood == MeshBrainMood.success) {
      bounceOffset = math.sin(_bounce.value * math.pi) * 10;
    } else if (widget.mood == MeshBrainMood.approving) {
      bounceOffset = math.sin(_bounce.value * math.pi * 2) * 6;
    } else if (widget.mood == MeshBrainMood.sad ||
        widget.mood == MeshBrainMood.tired) {
      bounceOffset = -math.sin(_bounce.value * math.pi) * 4; // Drooping
    } else if (widget.mood == MeshBrainMood.hopeful) {
      bounceOffset = -math.sin(_bounce.value * math.pi) * 8; // Rising up
    } else if (widget.mood == MeshBrainMood.grateful) {
      bounceOffset = math.sin(_bounce.value * math.pi) * 5; // Gentle bow
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
      case MeshBrainMood.focused:
        return MeshNodeAnimationType.rotate;
      case MeshBrainMood.excited:
      case MeshBrainMood.celebrating:
      case MeshBrainMood.energized:
      case MeshBrainMood.success:
        return MeshNodeAnimationType.pulseRotate;
      case MeshBrainMood.dormant:
      case MeshBrainMood.tired:
      case MeshBrainMood.zen:
        return MeshNodeAnimationType.breathe;
      case MeshBrainMood.loading:
      case MeshBrainMood.hypnotized:
        return MeshNodeAnimationType.rotate;
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

  Widget _buildExpressionOverlay() {
    // Build mood-specific overlays (eyes, effects, etc.)
    switch (widget.mood) {
      case MeshBrainMood.love:
        return _buildHeartParticles();
      case MeshBrainMood.dizzy:
        return _buildDizzyEffect();
      case MeshBrainMood.hypnotized:
        return _buildHypnoEffect();
      case MeshBrainMood.glitching:
        return _buildGlitchEffect();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHeartParticles() {
    return Positioned.fill(
      child: CustomPaint(
        painter: _HeartParticlesPainter(
          progress: _particleController.value,
          color: const Color(0xFFFF69B4),
        ),
      ),
    );
  }

  Widget _buildDizzyEffect() {
    return Transform.rotate(
      angle: _specialController.value * 4 * math.pi,
      child: CustomPaint(
        size: Size(widget.size * 1.2, widget.size * 1.2),
        painter: _DizzyStarsPainter(
          progress: _specialController.value,
          color: Colors.yellow,
        ),
      ),
    );
  }

  Widget _buildHypnoEffect() {
    return CustomPaint(
      size: Size(widget.size * 1.3, widget.size * 1.3),
      painter: _HypnoSpiralPainter(
        progress: _specialController.value,
        colors: _colors,
      ),
    );
  }

  Widget _buildGlitchEffect() {
    final offset = (_random.nextDouble() - 0.5) * 4;
    return Transform.translate(
      offset: Offset(offset, offset),
      child: Opacity(
        opacity: 0.3 + _random.nextDouble() * 0.4,
        child: Container(
          width: widget.size * 0.8,
          height: widget.size * 0.8,
          decoration: BoxDecoration(
            border: Border.all(color: _colors[_random.nextInt(3)], width: 2),
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

/// Heart particles painter for love mood
class _HeartParticlesPainter extends CustomPainter {
  final double progress;
  final Color color;

  _HeartParticlesPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final random = math.Random(42);

    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * math.pi + progress * math.pi;
      final distance = 30 + random.nextDouble() * 20;
      final heartSize = 6 + random.nextDouble() * 4;
      final opacity = (math.sin((progress + i / 6) * 2 * math.pi) + 1) / 2;

      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance - progress * 20;

      _drawHeart(
        canvas,
        Offset(x, y),
        heartSize,
        color.withValues(alpha: opacity * 0.8),
      );
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final path = Path();
    path.moveTo(center.dx, center.dy + size * 0.3);
    path.cubicTo(
      center.dx - size,
      center.dy - size * 0.5,
      center.dx - size * 0.5,
      center.dy - size,
      center.dx,
      center.dy - size * 0.3,
    );
    path.cubicTo(
      center.dx + size * 0.5,
      center.dy - size,
      center.dx + size,
      center.dy - size * 0.5,
      center.dx,
      center.dy + size * 0.3,
    );

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HeartParticlesPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Dizzy stars painter
class _DizzyStarsPainter extends CustomPainter {
  final double progress;
  final Color color;

  _DizzyStarsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 5; i++) {
      final angle = (i / 5) * 2 * math.pi + progress * 4 * math.pi;
      final distance = size.width * 0.35;
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;

      _drawStar(canvas, Offset(x, y), 8, color.withValues(alpha: 0.8));
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Color color) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 4 * math.pi / 5) - math.pi / 2;
      final point = Offset(
        center.dx + math.cos(angle) * size,
        center.dy + math.sin(angle) * size,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DizzyStarsPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Hypno spiral painter
class _HypnoSpiralPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  _HypnoSpiralPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int ring = 0; ring < 4; ring++) {
      final radius = (ring + 1) * size.width / 10;
      final startAngle = progress * 2 * math.pi * (ring.isEven ? 1 : -1);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        math.pi * 1.5,
        false,
        Paint()
          ..color = colors[ring % colors.length].withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_HypnoSpiralPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
