import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/animated_mesh_node.dart';

/// Emotional states for Ico, the mesh brain advisor (icosahedron mascot)
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

/// Simple face expression data - just eye scales and mouth curve
/// No overlays, no extra colors - just modifies existing mesh nodes/edges
class _SimpleFaceExpression {
  final double leftEyeScale;
  final double rightEyeScale;
  final double mouthCurve;

  const _SimpleFaceExpression({
    this.leftEyeScale = 1.0,
    this.rightEyeScale = 1.0,
    this.mouthCurve = 0.0,
  });
}

/// Dynamic effect parameters for the mesh
/// Controls electricity, pulsing, and shimmer effects
class _DynamicEffects {
  /// Edge electricity effect (0 = none, 1 = maximum jitter/zap)
  final double edgeElectricity;

  /// Intensity of node pulse effect (0 = none, 1 = visible pulse)
  final double nodePulseIntensity;

  /// Shimmer effect traveling along edges (0 = none, 1 = bright)
  final double edgeShimmer;

  const _DynamicEffects({
    this.edgeElectricity = 0.0,
    this.nodePulseIntensity = 0.0,
    this.edgeShimmer = 0.0,
  });
}

/// Ghost-like personality parameters for expressive mesh deformation
/// Inspired by Destiny 2's Ghost companion - subtle but characterful
class _GhostPersonality {
  /// Squash/stretch ratio (1.0 = normal, <1 = squashed/sad, >1 = stretched/surprised)
  final double squashStretch;

  /// Shell openness (0 = contracted/scared, 1 = normal, 2 = fully open/excited)
  final double shellOpenness;

  /// Per-node jitter for nervous/excited micro-movements (0-1)
  final double nodeJitter;

  /// Attention direction - where it's "looking" (-1 to 1 for X/Y)
  final Offset attentionOffset;

  /// Head tilt angle for curious/confused expressions (radians)
  final double tiltAngle;

  /// Edge thickness multiplier (0.5 = thin/scared, 1 = normal, 1.5 = bold/confident)
  final double edgeThicknessMult;

  const _GhostPersonality({
    this.squashStretch = 1.0,
    this.shellOpenness = 1.0,
    this.nodeJitter = 0.0,
    this.attentionOffset = Offset.zero,
    this.tiltAngle = 0.0,
    this.edgeThicknessMult = 1.0,
  });
}

/// Ico - The sentient icosahedron mesh brain that acts as an advisor.
/// Has personality, emotions, and responds to user interactions.
/// Named "Ico" after its icosahedron geometry.
class MeshNodeBrain extends StatefulWidget {
  /// Size of Ico
  final double size;

  /// Current emotional mood
  final MeshBrainMood mood;

  /// Custom gradient colors (optional)
  final List<Color>? colors;

  /// Glow intensity multiplier
  final double glowIntensity;

  /// Line thickness multiplier (0.1 - 2.0)
  final double lineThickness;

  /// Node size multiplier (0.1 - 2.0)
  final double nodeSize;

  /// Whether Ico should respond to touch
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
    this.lineThickness = 0.6,
    this.nodeSize = 0.9,
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
  late AnimationController _spinController;

  // Animations
  late Animation<double> _wobbleX;
  late Animation<double> _wobbleY;
  late Animation<double> _pulse;
  late Animation<double> _bounce;
  late Animation<double> _spin;

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

    _spinController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
    // Spin like a top - full 360° rotation with elastic overshoot for cartoon snap
    // 2π radians = full rotation, with elasticOut it overshoots then settles
    _spin = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.elasticOut),
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
      _triggerMoodHaptics(widget.mood);
    }
  }

  /// Trigger haptic feedback based on mood for tactile emotional response
  void _triggerMoodHaptics(MeshBrainMood mood) {
    switch (mood) {
      // Strong positive haptics
      case MeshBrainMood.excited:
      case MeshBrainMood.celebrating:
      case MeshBrainMood.success:
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 100), () {
          HapticFeedback.mediumImpact();
        });
        break;

      // Happy vibrations
      case MeshBrainMood.happy:
      case MeshBrainMood.laughing:
      case MeshBrainMood.smiling:
      case MeshBrainMood.playful:
        HapticFeedback.mediumImpact();
        break;

      // Gentle love pulse
      case MeshBrainMood.love:
      case MeshBrainMood.grateful:
        HapticFeedback.lightImpact();
        Future.delayed(const Duration(milliseconds: 200), () {
          HapticFeedback.lightImpact();
        });
        break;

      // Alert/warning haptics
      case MeshBrainMood.alert:
      case MeshBrainMood.alarmed:
      case MeshBrainMood.error:
        HapticFeedback.heavyImpact();
        break;

      // Nervous/scared tremor
      case MeshBrainMood.nervous:
      case MeshBrainMood.scared:
        for (int i = 0; i < 3; i++) {
          Future.delayed(Duration(milliseconds: i * 80), () {
            HapticFeedback.lightImpact();
          });
        }
        break;

      // Angry rumble
      case MeshBrainMood.angry:
      case MeshBrainMood.grumpy:
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 150), () {
          HapticFeedback.heavyImpact();
        });
        break;

      // Glitch/error buzz
      case MeshBrainMood.glitching:
        HapticFeedback.vibrate();
        break;

      // Surprised jolt
      case MeshBrainMood.surprised:
        HapticFeedback.heavyImpact();
        break;

      // Energized pulse
      case MeshBrainMood.energized:
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 100), () {
          HapticFeedback.mediumImpact();
        });
        Future.delayed(const Duration(milliseconds: 200), () {
          HapticFeedback.mediumImpact();
        });
        break;

      // Soft transitions for calm moods
      case MeshBrainMood.zen:
      case MeshBrainMood.dormant:
      case MeshBrainMood.thinking:
        HapticFeedback.selectionClick();
        break;

      // Default light feedback
      default:
        HapticFeedback.lightImpact();
    }
  }

  void _updateAnimationsForMood(MeshBrainMood mood) {
    _wobbleController.stop();
    _pulseController.stop();
    _bounceController.stop();
    _specialController.stop();
    _spinController.stop();

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
        _spinController
          ..duration = const Duration(milliseconds: 1200)
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
        _spinController
          ..duration = const Duration(milliseconds: 1000)
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
        _spinController
          ..duration = const Duration(milliseconds: 1400)
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
        _spinController
          ..duration = const Duration(milliseconds: 1000)
          ..repeat(reverse: true);
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
        _spinController
          ..duration = const Duration(milliseconds: 1600)
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
    _spinController.dispose();
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
          _spinController,
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

                // Main brain mesh (the rotating icosahedron with face expressions)
                _buildBrainMesh(),

                // Inner core glow
                _buildCoreGlow(),

                // Additional effects for special moods (particles, etc.)
                ..._buildSpecialEffects(),
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

    // Get face expression values
    final faceExpr = _getFaceExpression();

    // Get dynamic effect values per mood
    final dynEffects = _getDynamicEffects();

    // Get Ghost-like personality values per mood
    final personality = _getGhostPersonality();

    // Use AnimatedMeshNode with native face expression support
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
          lineThickness: widget.lineThickness,
          nodeSize: widget.nodeSize,
          externalRotationX: wobbleX,
          externalRotationY: wobbleY,
          externalRotationZ: _spin.value,
          leftEyeScale: widget.showExpression ? faceExpr.leftEyeScale : 1.0,
          rightEyeScale: widget.showExpression ? faceExpr.rightEyeScale : 1.0,
          mouthCurve: widget.showExpression ? faceExpr.mouthCurve : 0.0,
          edgeElectricity: dynEffects.edgeElectricity,
          nodePulsePhase: _pulse.value, // Use pulse animation for phase
          nodePulseIntensity: dynEffects.nodePulseIntensity,
          edgeShimmer: dynEffects.edgeShimmer,
          // Ghost-like personality parameters
          squashStretch: personality.squashStretch,
          shellOpenness: personality.shellOpenness,
          nodeJitter: personality.nodeJitter,
          attentionOffset: personality.attentionOffset,
          tiltAngle: personality.tiltAngle,
          edgeThicknessMult: personality.edgeThicknessMult,
          breathePhase: _pulse.value,
        ),
      ),
    );
  }

  /// Dynamic effect parameters per mood
  _DynamicEffects _getDynamicEffects() {
    switch (widget.mood) {
      // === HIGH ENERGY / ELECTRIC MOODS ===
      case MeshBrainMood.excited:
        return _DynamicEffects(
          edgeElectricity: 0.4 + _pulse.value * 0.3,
          nodePulseIntensity: 0.8,
          edgeShimmer: 0.6,
        );
      case MeshBrainMood.energized:
        return const _DynamicEffects(
          edgeElectricity: 0.7,
          nodePulseIntensity: 0.9,
          edgeShimmer: 0.8,
        );
      case MeshBrainMood.surprised:
        return const _DynamicEffects(
          edgeElectricity: 0.5,
          nodePulseIntensity: 1.0,
          edgeShimmer: 0.4,
        );
      case MeshBrainMood.alarmed:
        return const _DynamicEffects(
          edgeElectricity: 0.6,
          nodePulseIntensity: 0.8,
          edgeShimmer: 0.3,
        );
      case MeshBrainMood.angry:
        return _DynamicEffects(
          edgeElectricity: 0.8 + _wobbleX.value.abs() * 0.2,
          nodePulseIntensity: 0.3,
          edgeShimmer: 0.0,
        );
      case MeshBrainMood.grumpy:
        return const _DynamicEffects(
          edgeElectricity: 0.3,
          nodePulseIntensity: 0.15,
          edgeShimmer: 0.0,
        );

      // === NERVOUS / ANXIOUS MOODS ===
      case MeshBrainMood.nervous:
        return _DynamicEffects(
          edgeElectricity: 0.2 + _wobbleX.value.abs() * 0.15,
          nodePulseIntensity: 0.4,
          edgeShimmer: 0.7,
        );
      case MeshBrainMood.scared:
        return _DynamicEffects(
          edgeElectricity: 0.4 + _wobbleX.value.abs() * 0.2,
          nodePulseIntensity: 0.6,
          edgeShimmer: 0.3,
        );
      case MeshBrainMood.embarrassed:
        return const _DynamicEffects(
          edgeElectricity: 0.1,
          nodePulseIntensity: 0.3,
          edgeShimmer: 0.2,
        );
      case MeshBrainMood.shy:
        return const _DynamicEffects(
          edgeElectricity: 0.05,
          nodePulseIntensity: 0.2,
          edgeShimmer: 0.15,
        );

      // === PROCESSING / THINKING MOODS ===
      case MeshBrainMood.thinking:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.3,
          edgeShimmer: 0.5,
        );
      case MeshBrainMood.focused:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.4,
          edgeShimmer: 0.6,
        );
      case MeshBrainMood.loading:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.6,
          edgeShimmer: 1.0,
        );
      case MeshBrainMood.alert:
        return const _DynamicEffects(
          edgeElectricity: 0.15,
          nodePulseIntensity: 0.5,
          edgeShimmer: 0.7,
        );

      // === GLITCHY / ERROR MOODS ===
      case MeshBrainMood.glitching:
        return _DynamicEffects(
          edgeElectricity: 0.9 + _wobbleX.value.abs() * 0.1,
          nodePulseIntensity: 0.8,
          edgeShimmer: 0.3,
        );
      case MeshBrainMood.error:
        return const _DynamicEffects(
          edgeElectricity: 0.7,
          nodePulseIntensity: 0.2,
          edgeShimmer: 0.0,
        );
      case MeshBrainMood.confused:
        return const _DynamicEffects(
          edgeElectricity: 0.25,
          nodePulseIntensity: 0.35,
          edgeShimmer: 0.4,
        );
      case MeshBrainMood.dizzy:
        return const _DynamicEffects(
          edgeElectricity: 0.3,
          nodePulseIntensity: 0.5,
          edgeShimmer: 0.5,
        );
      case MeshBrainMood.hypnotized:
        return const _DynamicEffects(
          edgeElectricity: 0.1,
          nodePulseIntensity: 0.7,
          edgeShimmer: 0.9,
        );

      // === HAPPY / POSITIVE MOODS ===
      case MeshBrainMood.happy:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.4,
          edgeShimmer: 0.3,
        );
      case MeshBrainMood.celebrating:
        return const _DynamicEffects(
          edgeElectricity: 0.2,
          nodePulseIntensity: 0.7,
          edgeShimmer: 0.6,
        );
      case MeshBrainMood.laughing:
        return _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.5 + _pulse.value * 0.3,
          edgeShimmer: 0.2,
        );
      case MeshBrainMood.tickled:
        return _DynamicEffects(
          edgeElectricity: 0.1,
          nodePulseIntensity: 0.6 + _pulse.value * 0.2,
          edgeShimmer: 0.3,
        );
      case MeshBrainMood.smiling:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.2,
          edgeShimmer: 0.2,
        );
      case MeshBrainMood.love:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.5,
          edgeShimmer: 0.4,
        );
      case MeshBrainMood.proud:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.3,
          edgeShimmer: 0.5,
        );
      case MeshBrainMood.grateful:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.25,
          edgeShimmer: 0.35,
        );
      case MeshBrainMood.hopeful:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.35,
          edgeShimmer: 0.45,
        );
      case MeshBrainMood.success:
        return const _DynamicEffects(
          edgeElectricity: 0.15,
          nodePulseIntensity: 0.6,
          edgeShimmer: 0.7,
        );

      // === CALM / RELAXED MOODS ===
      case MeshBrainMood.zen:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.15,
          edgeShimmer: 0.1,
        );
      case MeshBrainMood.dormant:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.05,
          edgeShimmer: 0.05,
        );
      case MeshBrainMood.tired:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.08,
          edgeShimmer: 0.05,
        );
      case MeshBrainMood.bored:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.08,
          edgeShimmer: 0.1,
        );

      // === SAD / NEGATIVE MOODS ===
      case MeshBrainMood.sad:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.1,
          edgeShimmer: 0.0,
        );
      case MeshBrainMood.annoyed:
        return const _DynamicEffects(
          edgeElectricity: 0.2,
          nodePulseIntensity: 0.2,
          edgeShimmer: 0.0,
        );

      // === PLAYFUL / MISCHIEVOUS MOODS ===
      case MeshBrainMood.curious:
        return const _DynamicEffects(
          edgeElectricity: 0.05,
          nodePulseIntensity: 0.35,
          edgeShimmer: 0.45,
        );
      case MeshBrainMood.playful:
        return const _DynamicEffects(
          edgeElectricity: 0.15,
          nodePulseIntensity: 0.5,
          edgeShimmer: 0.4,
        );
      case MeshBrainMood.mischievous:
        return const _DynamicEffects(
          edgeElectricity: 0.2,
          nodePulseIntensity: 0.45,
          edgeShimmer: 0.35,
        );
      case MeshBrainMood.sassy:
        return const _DynamicEffects(
          edgeElectricity: 0.1,
          nodePulseIntensity: 0.4,
          edgeShimmer: 0.5,
        );
      case MeshBrainMood.winking:
        return const _DynamicEffects(
          edgeElectricity: 0.05,
          nodePulseIntensity: 0.3,
          edgeShimmer: 0.4,
        );

      // === LISTENING / COMMUNICATION MOODS ===
      case MeshBrainMood.listening:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.2,
          edgeShimmer: 0.3,
        );
      case MeshBrainMood.speaking:
        return _DynamicEffects(
          edgeElectricity: 0.05,
          nodePulseIntensity: 0.4 + _pulse.value * 0.2,
          edgeShimmer: 0.25,
        );
      case MeshBrainMood.approving:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.3,
          edgeShimmer: 0.35,
        );
      case MeshBrainMood.inviting:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.35,
          edgeShimmer: 0.4,
        );

      // === DEFAULT ===
      case MeshBrainMood.idle:
        return const _DynamicEffects(
          edgeElectricity: 0.0,
          nodePulseIntensity: 0.2,
          edgeShimmer: 0.15,
        );
    }
  }

  /// Ghost-like personality parameters per mood
  /// Controls mesh deformation for expressive, characterful movements
  _GhostPersonality _getGhostPersonality() {
    switch (widget.mood) {
      // === EXCITED / ENERGETIC ===
      case MeshBrainMood.excited:
        return _GhostPersonality(
          squashStretch:
              1.15 +
              math.sin(_pulse.value * math.pi * 4) * 0.1, // Bouncy stretch
          shellOpenness: 1.4, // Wide open, excited
          nodeJitter: 0.6, // Vibrating with excitement
          attentionOffset: Offset(0, -0.2), // Looking up eagerly
          tiltAngle: math.sin(_pulse.value * math.pi * 2) * 0.1, // Quick tilts
          edgeThicknessMult: 1.2, // Bold lines
        );
      case MeshBrainMood.energized:
        return _GhostPersonality(
          squashStretch: 1.1,
          shellOpenness: 1.3,
          nodeJitter: 0.8, // Very jittery
          attentionOffset: Offset(
            math.sin(_pulse.value * math.pi * 3) * 0.15,
            math.cos(_pulse.value * math.pi * 3) * 0.15,
          ), // Darting around
          tiltAngle: 0.0,
          edgeThicknessMult: 1.3,
        );
      case MeshBrainMood.celebrating:
        return _GhostPersonality(
          squashStretch:
              1.2 +
              math.sin(_pulse.value * math.pi * 6) * 0.15, // Rapid bouncing
          shellOpenness: 1.5, // Fully open celebration
          nodeJitter: 0.5,
          attentionOffset: Offset(0, -0.3), // Looking up
          tiltAngle: math.sin(_pulse.value * math.pi * 4) * 0.15,
          edgeThicknessMult: 1.25,
        );

      // === HAPPY / POSITIVE ===
      case MeshBrainMood.happy:
        return _GhostPersonality(
          squashStretch: 1.05,
          shellOpenness: 1.15,
          nodeJitter: 0.1,
          attentionOffset: Offset(0, -0.1), // Slightly up, optimistic
          tiltAngle: 0.05, // Slight happy tilt
          edgeThicknessMult: 1.1,
        );
      case MeshBrainMood.smiling:
        return const _GhostPersonality(
          squashStretch: 1.02,
          shellOpenness: 1.1,
          nodeJitter: 0.0,
          attentionOffset: Offset.zero,
          tiltAngle: 0.03,
          edgeThicknessMult: 1.05,
        );
      case MeshBrainMood.love:
        return _GhostPersonality(
          squashStretch:
              1.0 + math.sin(_pulse.value * math.pi * 2) * 0.05, // Gentle pulse
          shellOpenness: 1.2,
          nodeJitter: 0.0,
          attentionOffset: Offset(0, -0.1),
          tiltAngle: math.sin(_pulse.value * math.pi) * 0.08, // Dreamy sway
          edgeThicknessMult: 1.0,
        );
      case MeshBrainMood.proud:
        return const _GhostPersonality(
          squashStretch: 1.1, // Standing tall
          shellOpenness: 1.25, // Puffed up
          nodeJitter: 0.0,
          attentionOffset: Offset(0, -0.2), // Chin up
          tiltAngle: 0.0,
          edgeThicknessMult: 1.2, // Bold
        );
      case MeshBrainMood.grateful:
        return _GhostPersonality(
          squashStretch: 0.95, // Slight humble bow
          shellOpenness: 1.0,
          nodeJitter: 0.0,
          attentionOffset: Offset(
            0,
            0.15 + math.sin(_pulse.value * math.pi) * 0.1,
          ), // Bowing
          tiltAngle: 0.1, // Grateful tilt
          edgeThicknessMult: 0.95,
        );

      // === SURPRISED / ALERT ===
      case MeshBrainMood.surprised:
        return const _GhostPersonality(
          squashStretch: 1.25, // Stretched tall in surprise
          shellOpenness: 1.5, // Wide open
          nodeJitter: 0.3, // Startled jitter
          attentionOffset: Offset(0, -0.25), // Looking up startled
          tiltAngle: 0.0,
          edgeThicknessMult: 1.15,
        );
      case MeshBrainMood.alarmed:
        return _GhostPersonality(
          squashStretch: 1.2,
          shellOpenness: 1.4,
          nodeJitter: 0.5 + _wobbleX.value.abs() * 0.2,
          attentionOffset: Offset(_wobbleX.value * 0.2, -0.2), // Darting eyes
          tiltAngle: _wobbleX.value * 0.1,
          edgeThicknessMult: 1.1,
        );
      case MeshBrainMood.alert:
        return const _GhostPersonality(
          squashStretch: 1.08,
          shellOpenness: 1.2,
          nodeJitter: 0.15,
          attentionOffset: Offset(0, -0.15),
          tiltAngle: 0.0,
          edgeThicknessMult: 1.1,
        );

      // === SCARED / NERVOUS ===
      case MeshBrainMood.scared:
        return _GhostPersonality(
          squashStretch: 0.8, // Shrinking down
          shellOpenness: 0.6, // Contracted, protecting
          nodeJitter: 0.7, // Trembling
          attentionOffset: Offset(
            _wobbleX.value * 0.15,
            0.1,
          ), // Looking around fearfully
          tiltAngle: _wobbleX.value * 0.15,
          edgeThicknessMult: 0.7, // Thin, fragile lines
        );
      case MeshBrainMood.nervous:
        return _GhostPersonality(
          squashStretch: 0.95,
          shellOpenness: 0.85,
          nodeJitter: 0.5, // Fidgety
          attentionOffset: Offset(
            math.sin(_pulse.value * math.pi * 5) * 0.1,
            math.cos(_pulse.value * math.pi * 3) * 0.05,
          ), // Darting nervously
          tiltAngle: _wobbleX.value * 0.08,
          edgeThicknessMult: 0.85,
        );
      case MeshBrainMood.shy:
        return _GhostPersonality(
          squashStretch: 0.9, // Shrinking
          shellOpenness: 0.75, // Closed off
          nodeJitter: 0.2,
          attentionOffset: Offset(0.15, 0.2), // Looking away/down
          tiltAngle: 0.15, // Bashful tilt
          edgeThicknessMult: 0.8,
        );
      case MeshBrainMood.embarrassed:
        return const _GhostPersonality(
          squashStretch: 0.92,
          shellOpenness: 0.8,
          nodeJitter: 0.25,
          attentionOffset: Offset(0.1, 0.15), // Looking away
          tiltAngle: 0.12,
          edgeThicknessMult: 0.85,
        );

      // === SAD / LOW ENERGY ===
      case MeshBrainMood.sad:
        return const _GhostPersonality(
          squashStretch: 0.85, // Deflated
          shellOpenness: 0.7, // Closed in
          nodeJitter: 0.0,
          attentionOffset: Offset(0, 0.25), // Looking down
          tiltAngle: 0.1, // Drooping tilt
          edgeThicknessMult: 0.75, // Thin, weak lines
        );
      case MeshBrainMood.tired:
        return _GhostPersonality(
          squashStretch: 0.88,
          shellOpenness: 0.75,
          nodeJitter: 0.0,
          attentionOffset: Offset(
            0,
            0.2 + math.sin(_pulse.value * math.pi) * 0.1,
          ), // Nodding off
          tiltAngle: 0.08 + math.sin(_pulse.value * math.pi) * 0.05,
          edgeThicknessMult: 0.8,
        );
      case MeshBrainMood.dormant:
        return const _GhostPersonality(
          squashStretch: 0.9,
          shellOpenness: 0.65, // Very closed
          nodeJitter: 0.0,
          attentionOffset: Offset(0, 0.15),
          tiltAngle: 0.05,
          edgeThicknessMult: 0.7,
        );
      case MeshBrainMood.bored:
        return _GhostPersonality(
          squashStretch: 0.95,
          shellOpenness: 0.85,
          nodeJitter: 0.0,
          attentionOffset: Offset(
            math.sin(_pulse.value * math.pi * 0.5) * 0.2, // Slow wandering gaze
            0.1,
          ),
          tiltAngle: math.sin(_pulse.value * math.pi) * 0.05,
          edgeThicknessMult: 0.9,
        );

      // === ANGRY / FRUSTRATED ===
      case MeshBrainMood.angry:
        return _GhostPersonality(
          squashStretch: 0.9 + _wobbleX.value.abs() * 0.1, // Pulsing with anger
          shellOpenness: 1.1,
          nodeJitter: 0.4, // Seething
          attentionOffset: Offset(0, -0.15), // Intense forward stare
          tiltAngle: _wobbleX.value * 0.05,
          edgeThicknessMult: 1.3, // Bold, aggressive lines
        );
      case MeshBrainMood.grumpy:
        return const _GhostPersonality(
          squashStretch: 0.92,
          shellOpenness: 0.9,
          nodeJitter: 0.1,
          attentionOffset: Offset(0, 0.1), // Scowling down
          tiltAngle: -0.05, // Grumpy lean
          edgeThicknessMult: 1.1,
        );
      case MeshBrainMood.annoyed:
        return _GhostPersonality(
          squashStretch: 0.95,
          shellOpenness: 0.95,
          nodeJitter: 0.2,
          attentionOffset: Offset(_wobbleX.value * 0.1, 0),
          tiltAngle: -0.03,
          edgeThicknessMult: 1.05,
        );

      // === THINKING / PROCESSING ===
      case MeshBrainMood.thinking:
        return _GhostPersonality(
          squashStretch: 1.0,
          shellOpenness: 1.0,
          nodeJitter: 0.05,
          attentionOffset: Offset(0.15, -0.1), // Looking up and to side
          tiltAngle: 0.12, // Pondering tilt
          edgeThicknessMult: 1.0,
        );
      case MeshBrainMood.curious:
        return _GhostPersonality(
          squashStretch: 1.05,
          shellOpenness: 1.15,
          nodeJitter: 0.1,
          attentionOffset: Offset(
            math.sin(_pulse.value * math.pi * 2) * 0.15,
            -0.1,
          ), // Looking around curiously
          tiltAngle:
              0.18 + math.sin(_pulse.value * math.pi) * 0.08, // Head tilts
          edgeThicknessMult: 1.0,
        );
      case MeshBrainMood.confused:
        return _GhostPersonality(
          squashStretch: 0.98,
          shellOpenness: 1.0,
          nodeJitter: 0.15,
          attentionOffset: Offset(
            math.sin(_pulse.value * math.pi * 3) * 0.12,
            math.cos(_pulse.value * math.pi * 2) * 0.08,
          ),
          tiltAngle:
              math.sin(_pulse.value * math.pi * 2) * 0.2, // Confused tilting
          edgeThicknessMult: 0.95,
        );
      case MeshBrainMood.focused:
        return const _GhostPersonality(
          squashStretch: 1.02,
          shellOpenness: 1.05,
          nodeJitter: 0.0,
          attentionOffset: Offset(0, -0.1), // Locked on target
          tiltAngle: 0.0,
          edgeThicknessMult: 1.1,
        );
      case MeshBrainMood.loading:
        return _GhostPersonality(
          squashStretch: 1.0 + math.sin(_pulse.value * math.pi * 2) * 0.03,
          shellOpenness: 1.0,
          nodeJitter: 0.1,
          attentionOffset: Offset.zero,
          tiltAngle: 0.0,
          edgeThicknessMult: 1.0,
        );

      // === PLAYFUL / MISCHIEVOUS ===
      case MeshBrainMood.playful:
        return _GhostPersonality(
          squashStretch: 1.0 + math.sin(_pulse.value * math.pi * 3) * 0.08,
          shellOpenness: 1.2,
          nodeJitter: 0.3,
          attentionOffset: Offset(
            math.sin(_pulse.value * math.pi * 2) * 0.15,
            math.cos(_pulse.value * math.pi * 2) * 0.1,
          ),
          tiltAngle: math.sin(_pulse.value * math.pi * 2) * 0.12,
          edgeThicknessMult: 1.05,
        );
      case MeshBrainMood.mischievous:
        return _GhostPersonality(
          squashStretch: 1.02,
          shellOpenness: 1.1,
          nodeJitter: 0.2,
          attentionOffset: Offset(0.2, -0.05), // Sly sideways look
          tiltAngle: -0.1, // Scheming tilt
          edgeThicknessMult: 1.0,
        );
      case MeshBrainMood.sassy:
        return _GhostPersonality(
          squashStretch: 1.0,
          shellOpenness: 1.15,
          nodeJitter: 0.15,
          attentionOffset: Offset(
            0.15 + math.sin(_pulse.value * math.pi * 2) * 0.1,
            0,
          ),
          tiltAngle: -0.15, // Sassy head tilt
          edgeThicknessMult: 1.1,
        );
      case MeshBrainMood.winking:
        return _GhostPersonality(
          squashStretch: 1.0,
          shellOpenness: 1.1,
          nodeJitter: 0.05,
          attentionOffset: Offset(0.1, 0),
          tiltAngle: 0.08,
          edgeThicknessMult: 1.0,
        );

      // === COMMUNICATION ===
      case MeshBrainMood.speaking:
        return _GhostPersonality(
          squashStretch:
              1.0 +
              math.sin(_pulse.value * math.pi * 4) * 0.04, // Talking movement
          shellOpenness: 1.1,
          nodeJitter: 0.1,
          attentionOffset: Offset(0, -0.05),
          tiltAngle: math.sin(_pulse.value * math.pi * 2) * 0.05,
          edgeThicknessMult: 1.05,
        );
      case MeshBrainMood.listening:
        return _GhostPersonality(
          squashStretch: 1.0,
          shellOpenness: 1.05,
          nodeJitter: 0.0,
          attentionOffset: Offset(
            math.sin(_pulse.value * math.pi) * 0.05,
            -0.05,
          ),
          tiltAngle: 0.1, // Attentive tilt
          edgeThicknessMult: 0.95,
        );
      case MeshBrainMood.approving:
        return _GhostPersonality(
          squashStretch:
              1.0 + math.sin(_pulse.value * math.pi * 2) * 0.05, // Nodding
          shellOpenness: 1.1,
          nodeJitter: 0.0,
          attentionOffset: Offset(
            0,
            -0.05 + math.sin(_pulse.value * math.pi * 2) * 0.1,
          ),
          tiltAngle: 0.05,
          edgeThicknessMult: 1.05,
        );
      case MeshBrainMood.inviting:
        return _GhostPersonality(
          squashStretch: 1.05,
          shellOpenness: 1.2,
          nodeJitter: 0.05,
          attentionOffset: Offset(0, -0.1),
          tiltAngle: 0.05,
          edgeThicknessMult: 1.0,
        );

      // === SPECIAL STATES ===
      case MeshBrainMood.laughing:
        return _GhostPersonality(
          squashStretch:
              0.9 +
              math.sin(_pulse.value * math.pi * 6) * 0.15, // Laughing bounce
          shellOpenness: 1.3,
          nodeJitter: 0.4,
          attentionOffset: Offset(0, -0.1),
          tiltAngle: math.sin(_pulse.value * math.pi * 3) * 0.1,
          edgeThicknessMult: 1.0,
        );
      case MeshBrainMood.tickled:
        return _GhostPersonality(
          squashStretch: 0.95 + math.sin(_pulse.value * math.pi * 8) * 0.1,
          shellOpenness: 1.2,
          nodeJitter: 0.6,
          attentionOffset: Offset(
            math.sin(_pulse.value * math.pi * 4) * 0.1,
            math.cos(_pulse.value * math.pi * 4) * 0.1,
          ),
          tiltAngle: math.sin(_pulse.value * math.pi * 4) * 0.15,
          edgeThicknessMult: 0.95,
        );
      case MeshBrainMood.dizzy:
        return _GhostPersonality(
          squashStretch: 1.0 + math.sin(_pulse.value * math.pi * 2) * 0.08,
          shellOpenness: 1.0,
          nodeJitter: 0.3,
          attentionOffset: Offset(
            math.sin(_pulse.value * math.pi * 4) * 0.2,
            math.cos(_pulse.value * math.pi * 4) * 0.2,
          ), // Spinning
          tiltAngle: _pulse.value * math.pi * 2, // Spinning tilt
          edgeThicknessMult: 0.9,
        );
      case MeshBrainMood.glitching:
        return _GhostPersonality(
          squashStretch: 1.0 + (math.Random().nextDouble() - 0.5) * 0.2,
          shellOpenness: 1.0 + (math.Random().nextDouble() - 0.5) * 0.3,
          nodeJitter: 1.0, // Maximum jitter
          attentionOffset: Offset(
            (math.Random().nextDouble() - 0.5) * 0.3,
            (math.Random().nextDouble() - 0.5) * 0.3,
          ),
          tiltAngle: (math.Random().nextDouble() - 0.5) * 0.3,
          edgeThicknessMult: 0.8 + math.Random().nextDouble() * 0.4,
        );
      case MeshBrainMood.error:
        return _GhostPersonality(
          squashStretch: 0.95,
          shellOpenness: 0.9,
          nodeJitter: 0.5,
          attentionOffset: Offset(0, 0),
          tiltAngle: _wobbleX.value * 0.1,
          edgeThicknessMult: 0.85,
        );
      case MeshBrainMood.success:
        return _GhostPersonality(
          squashStretch: 1.15,
          shellOpenness: 1.35,
          nodeJitter: 0.2,
          attentionOffset: Offset(0, -0.2),
          tiltAngle: 0.0,
          edgeThicknessMult: 1.2,
        );
      case MeshBrainMood.zen:
        return _GhostPersonality(
          squashStretch:
              1.0 +
              math.sin(_pulse.value * math.pi) * 0.02, // Very gentle breathing
          shellOpenness: 1.0,
          nodeJitter: 0.0,
          attentionOffset: Offset(0, 0),
          tiltAngle: 0.0,
          edgeThicknessMult: 0.9,
        );
      case MeshBrainMood.hypnotized:
        return _GhostPersonality(
          squashStretch: 1.0,
          shellOpenness: 1.0,
          nodeJitter: 0.0,
          attentionOffset: Offset(
            math.sin(_pulse.value * math.pi * 2) * 0.1,
            math.cos(_pulse.value * math.pi * 2) * 0.1,
          ), // Slow circular
          tiltAngle: _pulse.value * math.pi * 0.5,
          edgeThicknessMult: 1.0,
        );
      case MeshBrainMood.hopeful:
        return const _GhostPersonality(
          squashStretch: 1.08,
          shellOpenness: 1.15,
          nodeJitter: 0.05,
          attentionOffset: Offset(0, -0.2), // Looking up hopefully
          tiltAngle: 0.0,
          edgeThicknessMult: 1.0,
        );

      // === DEFAULT ===
      case MeshBrainMood.idle:
        return _GhostPersonality(
          squashStretch:
              1.0 +
              math.sin(_pulse.value * math.pi) * 0.02, // Subtle idle breathing
          shellOpenness: 1.0,
          nodeJitter: 0.0,
          attentionOffset: Offset(
            math.sin(_pulse.value * math.pi * 0.3) *
                0.05, // Slow idle look-around
            math.cos(_pulse.value * math.pi * 0.2) * 0.03,
          ),
          tiltAngle: math.sin(_pulse.value * math.pi * 0.5) * 0.03,
          edgeThicknessMult: 1.0,
        );
    }
  }

  /// Simple face expression data (just scales and curve)
  _SimpleFaceExpression _getFaceExpression() {
    switch (widget.mood) {
      // === POSITIVE EMOTIONS ===
      case MeshBrainMood.idle:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.0,
          rightEyeScale: 1.0,
          mouthCurve: 0.3,
        );
      case MeshBrainMood.happy:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.1,
          rightEyeScale: 1.1,
          mouthCurve: 0.8,
        );
      case MeshBrainMood.excited:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.4,
          rightEyeScale: 1.4,
          mouthCurve: 1.0,
        );
      case MeshBrainMood.celebrating:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.3,
          rightEyeScale: 1.3,
          mouthCurve: 1.0,
        );
      case MeshBrainMood.laughing:
        return _SimpleFaceExpression(
          leftEyeScale: 0.5 + _pulse.value * 0.3, // Squinting from laughing
          rightEyeScale: 0.5 + _pulse.value * 0.3,
          mouthCurve: 1.0,
        );
      case MeshBrainMood.tickled:
        return _SimpleFaceExpression(
          leftEyeScale: 0.5 + _pulse.value * 0.4,
          rightEyeScale: 0.5 + _pulse.value * 0.4,
          mouthCurve: 0.9,
        );
      case MeshBrainMood.smiling:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.8, // Gentle squint
          rightEyeScale: 0.8,
          mouthCurve: 0.7,
        );
      case MeshBrainMood.love:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.2,
          rightEyeScale: 1.2,
          mouthCurve: 0.6,
        );
      case MeshBrainMood.proud:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.9,
          rightEyeScale: 0.9,
          mouthCurve: 0.5,
        );
      case MeshBrainMood.grateful:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.7, // Eyes softly closed
          rightEyeScale: 0.7,
          mouthCurve: 0.6,
        );
      case MeshBrainMood.hopeful:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.2,
          rightEyeScale: 1.2,
          mouthCurve: 0.4,
        );
      case MeshBrainMood.playful:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.2,
          rightEyeScale: 1.2, // Both eyes open and bright
          mouthCurve: 0.8,
        );
      case MeshBrainMood.energized:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.3,
          rightEyeScale: 1.3,
          mouthCurve: 0.9,
        );

      // === NEUTRAL/COMMUNICATIVE ===
      case MeshBrainMood.thinking:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.9,
          rightEyeScale: 0.9,
          mouthCurve: 0.0,
        );
      case MeshBrainMood.speaking:
        return _SimpleFaceExpression(
          leftEyeScale: 1.0,
          rightEyeScale: 1.0,
          mouthCurve: 0.2 + _pulse.value * 0.3, // Mouth moves while speaking
        );
      case MeshBrainMood.curious:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.3,
          rightEyeScale: 1.1,
          mouthCurve: 0.2,
        );
      case MeshBrainMood.focused:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.8,
          rightEyeScale: 0.8,
          mouthCurve: 0.0,
        );
      case MeshBrainMood.approving:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.9,
          rightEyeScale: 0.9,
          mouthCurve: 0.5,
        );
      case MeshBrainMood.inviting:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.1,
          rightEyeScale: 1.1,
          mouthCurve: 0.6,
        );
      case MeshBrainMood.winking:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.1,
          rightEyeScale: 0.5, // Squinting wink
          mouthCurve: 0.7,
        );
      case MeshBrainMood.listening:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.0,
          rightEyeScale: 1.0,
          mouthCurve: 0.2,
        );

      // === ALERTNESS ===
      case MeshBrainMood.alert:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.4,
          rightEyeScale: 1.4,
          mouthCurve: 0.0,
        );
      case MeshBrainMood.surprised:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.6,
          rightEyeScale: 1.6,
          mouthCurve: -0.3, // O-shape
        );
      case MeshBrainMood.alarmed:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.5,
          rightEyeScale: 1.5,
          mouthCurve: -0.5,
        );

      // === NEGATIVE/LOW ENERGY ===
      case MeshBrainMood.sad:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.7,
          rightEyeScale: 0.7,
          mouthCurve: -0.7,
        );
      case MeshBrainMood.dormant:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.5, // Sleepy
          rightEyeScale: 0.5,
          mouthCurve: 0.1,
        );
      case MeshBrainMood.tired:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.4,
          rightEyeScale: 0.4,
          mouthCurve: -0.2,
        );
      case MeshBrainMood.bored:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.6,
          rightEyeScale: 0.6,
          mouthCurve: -0.1,
        );
      case MeshBrainMood.confused:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.2,
          rightEyeScale: 0.8,
          mouthCurve: -0.2,
        );
      case MeshBrainMood.nervous:
        return _SimpleFaceExpression(
          leftEyeScale: 1.1 + _pulse.value * 0.2, // Jittery
          rightEyeScale: 1.1 + _pulse.value * 0.2,
          mouthCurve: -0.3,
        );
      case MeshBrainMood.scared:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.5,
          rightEyeScale: 1.5,
          mouthCurve: -0.6,
        );
      case MeshBrainMood.embarrassed:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.5,
          rightEyeScale: 0.5,
          mouthCurve: -0.3,
        );
      case MeshBrainMood.shy:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.6,
          rightEyeScale: 0.6,
          mouthCurve: 0.2,
        );
      case MeshBrainMood.grumpy:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.7,
          rightEyeScale: 0.7,
          mouthCurve: -0.5,
        );
      case MeshBrainMood.annoyed:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.8,
          rightEyeScale: 0.8,
          mouthCurve: -0.4,
        );
      case MeshBrainMood.angry:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.9,
          rightEyeScale: 0.9,
          mouthCurve: -0.6,
        );

      // === SPECIAL ===
      case MeshBrainMood.dizzy:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.0,
          rightEyeScale: 1.0,
          mouthCurve: -0.2,
        );
      case MeshBrainMood.glitching:
        return _SimpleFaceExpression(
          leftEyeScale: 0.5 + _pulse.value * 1.0, // Glitchy
          rightEyeScale: 1.5 - _pulse.value * 1.0,
          mouthCurve: -0.5 + _pulse.value * 1.0,
        );
      case MeshBrainMood.zen:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.5, // Meditating
          rightEyeScale: 0.5,
          mouthCurve: 0.3,
        );
      case MeshBrainMood.sassy:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.0,
          rightEyeScale: 0.6, // Side eye
          mouthCurve: 0.4,
        );
      case MeshBrainMood.mischievous:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.0,
          rightEyeScale: 0.6, // Sneaky squint
          mouthCurve: 0.6,
        );
      case MeshBrainMood.hypnotized:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.2,
          rightEyeScale: 1.2,
          mouthCurve: 0.0,
        );
      case MeshBrainMood.loading:
        return _SimpleFaceExpression(
          leftEyeScale: 0.8 + _pulse.value * 0.4,
          rightEyeScale: 0.8 + _pulse.value * 0.4,
          mouthCurve: 0.0,
        );
      case MeshBrainMood.error:
        return const _SimpleFaceExpression(
          leftEyeScale: 1.0,
          rightEyeScale: 1.0,
          mouthCurve: -0.8,
        );
      case MeshBrainMood.success:
        return const _SimpleFaceExpression(
          leftEyeScale: 0.7, // Happy squint
          rightEyeScale: 0.7,
          mouthCurve: 1.0,
        );
    }
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

  /// Build special particle effects for certain moods - each mood gets unique effects
  List<Widget> _buildSpecialEffects() {
    final effects = <Widget>[];

    switch (widget.mood) {
      // === POSITIVE EMOTIONS ===
      case MeshBrainMood.happy:
      case MeshBrainMood.smiling:
        effects.add(_buildSparkleEffect());
        break;

      case MeshBrainMood.excited:
      case MeshBrainMood.celebrating:
      case MeshBrainMood.success:
        effects.add(_buildStarBurstEffect());
        effects.add(_buildSparkleEffect());
        break;

      case MeshBrainMood.laughing:
      case MeshBrainMood.tickled:
        effects.add(_buildJoyBubblesEffect());
        break;

      case MeshBrainMood.love:
        effects.add(_buildHeartParticles());
        effects.add(_buildLoveGlowEffect());
        break;

      case MeshBrainMood.proud:
        effects.add(_buildCrownEffect());
        break;

      case MeshBrainMood.grateful:
        effects.add(_buildWarmGlowEffect());
        break;

      case MeshBrainMood.hopeful:
        effects.add(_buildRisingSparkEffect());
        break;

      case MeshBrainMood.playful:
        effects.add(_buildBouncingDotsEffect());
        break;

      case MeshBrainMood.energized:
        effects.add(_buildLightningEffect());
        effects.add(_buildElectricAuraEffect());
        break;

      // === NEUTRAL/COMMUNICATIVE ===
      case MeshBrainMood.thinking:
        effects.add(_buildThinkingDotsEffect());
        break;

      case MeshBrainMood.speaking:
        effects.add(_buildSoundWavesEffect());
        break;

      case MeshBrainMood.curious:
        effects.add(_buildQuestionMarkEffect());
        break;

      case MeshBrainMood.focused:
        effects.add(_buildFocusRingsEffect());
        break;

      case MeshBrainMood.winking:
        effects.add(_buildWinkSparkleEffect());
        break;

      case MeshBrainMood.listening:
        effects.add(_buildSoundWavesEffect());
        break;

      // === ALERTNESS ===
      case MeshBrainMood.alert:
        effects.add(_buildAlertPulseEffect());
        break;

      case MeshBrainMood.surprised:
        effects.add(_buildExclamationEffect());
        break;

      case MeshBrainMood.alarmed:
        effects.add(_buildWarningFlashEffect());
        break;

      // === NEGATIVE/LOW ENERGY ===
      case MeshBrainMood.sad:
        effects.add(_buildRainDropsEffect());
        effects.add(_buildTearDropEffect());
        break;

      case MeshBrainMood.tired:
      case MeshBrainMood.dormant:
        effects.add(_buildZzzEffect());
        break;

      case MeshBrainMood.bored:
        effects.add(_buildYawnEffect());
        break;

      case MeshBrainMood.confused:
        effects.add(_buildConfusionSwirls());
        break;

      case MeshBrainMood.nervous:
        effects.add(_buildSweatDropEffect());
        effects.add(_buildShakeLines());
        break;

      case MeshBrainMood.scared:
        effects.add(_buildFearTremorEffect());
        effects.add(_buildShakeLines());
        break;

      case MeshBrainMood.embarrassed:
        effects.add(_buildBlushEffect());
        break;

      case MeshBrainMood.shy:
        effects.add(_buildBlushEffect());
        break;

      case MeshBrainMood.angry:
        effects.add(_buildAngerVeinsEffect());
        effects.add(_buildSteamEffect());
        break;

      case MeshBrainMood.grumpy:
      case MeshBrainMood.annoyed:
        effects.add(_buildAngerVeinsEffect());
        break;

      // === SPECIAL ===
      case MeshBrainMood.dizzy:
        effects.add(_buildDizzyEffect());
        break;

      case MeshBrainMood.glitching:
        effects.add(_buildGlitchEffect());
        effects.add(_buildStaticEffect());
        break;

      case MeshBrainMood.zen:
        effects.add(_buildZenAuraEffect());
        effects.add(_buildFloatingLeavesEffect());
        break;

      case MeshBrainMood.sassy:
        effects.add(_buildSassySparkEffect());
        break;

      case MeshBrainMood.mischievous:
        effects.add(_buildDevilHornsEffect());
        break;

      case MeshBrainMood.hypnotized:
        effects.add(_buildHypnoEffect());
        break;

      case MeshBrainMood.loading:
        effects.add(_buildLoadingDotsEffect());
        break;

      case MeshBrainMood.error:
        effects.add(_buildErrorCrossEffect());
        effects.add(_buildStaticEffect());
        break;

      default:
        break;
    }

    return effects;
  }

  // ==========================================
  // POSITIVE EMOTION EFFECTS
  // ==========================================

  Widget _buildSparkleEffect() {
    return CustomPaint(
      size: Size(widget.size * 1.4, widget.size * 1.4),
      painter: _SparklePainter(
        progress: _particleController.value,
        colors: _colors,
        count: 8,
      ),
    );
  }

  Widget _buildStarBurstEffect() {
    return CustomPaint(
      size: Size(widget.size * 1.5, widget.size * 1.5),
      painter: _StarBurstPainter(
        progress: _particleController.value,
        colors: _colors,
      ),
    );
  }

  Widget _buildJoyBubblesEffect() {
    return CustomPaint(
      size: Size(widget.size * 1.3, widget.size * 1.3),
      painter: _JoyBubblesPainter(
        progress: _particleController.value,
        color: _colors[1],
      ),
    );
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

  Widget _buildLoveGlowEffect() {
    return Container(
      width: widget.size * 1.2,
      height: widget.size * 1.2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFFFF69B4).withAlpha((60 * _pulse.value).round()),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildCrownEffect() {
    return Transform.translate(
      offset: Offset(0, -widget.size * 0.45),
      child: CustomPaint(
        size: Size(widget.size * 0.4, widget.size * 0.25),
        painter: _CrownPainter(progress: _pulse.value, color: Colors.amber),
      ),
    );
  }

  Widget _buildWarmGlowEffect() {
    return Container(
      width: widget.size * 1.3,
      height: widget.size * 1.3,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.amber.withAlpha((40 * _pulse.value).round()),
            Colors.orange.withAlpha((20 * _pulse.value).round()),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildRisingSparkEffect() {
    return CustomPaint(
      size: Size(widget.size * 1.2, widget.size * 1.4),
      painter: _RisingSparkPainter(
        progress: _particleController.value,
        color: Colors.yellow,
      ),
    );
  }

  Widget _buildBouncingDotsEffect() {
    return CustomPaint(
      size: Size(widget.size * 1.3, widget.size * 1.3),
      painter: _BouncingDotsPainter(
        progress: _bounceController.value,
        colors: _colors,
      ),
    );
  }

  // ==========================================
  // ENERGY EFFECTS
  // ==========================================

  Widget _buildLightningEffect() {
    return CustomPaint(
      size: Size(widget.size * 1.5, widget.size * 1.5),
      painter: _LightningPainter(
        progress: _particleController.value,
        color: _colors[0],
        intensity: _pulse.value,
      ),
    );
  }

  Widget _buildElectricAuraEffect() {
    return CustomPaint(
      size: Size(widget.size * 1.4, widget.size * 1.4),
      painter: _ElectricAuraPainter(
        progress: _particleController.value,
        colors: _colors,
      ),
    );
  }

  // ==========================================
  // COMMUNICATIVE EFFECTS
  // ==========================================

  Widget _buildThinkingDotsEffect() {
    return Transform.translate(
      offset: Offset(widget.size * 0.4, -widget.size * 0.3),
      child: CustomPaint(
        size: Size(widget.size * 0.4, widget.size * 0.2),
        painter: _ThinkingDotsPainter(
          progress: _pulseController.value,
          color: _colors[1],
        ),
      ),
    );
  }

  Widget _buildSoundWavesEffect() {
    return CustomPaint(
      size: Size(widget.size * 1.4, widget.size * 1.4),
      painter: _SoundWavesPainter(progress: _pulse.value, color: _colors[1]),
    );
  }

  Widget _buildQuestionMarkEffect() {
    return Transform.translate(
      offset: Offset(widget.size * 0.35, -widget.size * 0.35),
      child: Text(
        '?',
        style: TextStyle(
          fontSize: widget.size * 0.25,
          color: _colors[1].withAlpha((200 * _pulse.value).round()),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFocusRingsEffect() {
    return CustomPaint(
      size: Size(widget.size * 1.3, widget.size * 1.3),
      painter: _FocusRingsPainter(progress: _pulse.value, color: _colors[2]),
    );
  }

  Widget _buildWinkSparkleEffect() {
    return Transform.translate(
      offset: Offset(widget.size * 0.25, -widget.size * 0.15),
      child: CustomPaint(
        size: Size(widget.size * 0.15, widget.size * 0.15),
        painter: _SingleStarPainter(
          progress: _pulse.value,
          color: Colors.yellow,
        ),
      ),
    );
  }

  // ==========================================
  // ALERT EFFECTS
  // ==========================================

  Widget _buildAlertPulseEffect() {
    return Container(
      width: widget.size * (1.0 + _pulse.value * 0.3),
      height: widget.size * (1.0 + _pulse.value * 0.3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.orange.withAlpha((150 * _pulse.value).round()),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildExclamationEffect() {
    return Transform.translate(
      offset: Offset(0, -widget.size * 0.5),
      child: Text(
        '!',
        style: TextStyle(
          fontSize: widget.size * 0.35,
          color: Colors.yellow.withAlpha((255 * _pulse.value).round()),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildWarningFlashEffect() {
    return Container(
      width: widget.size * 1.4,
      height: widget.size * 1.4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.red.withAlpha((80 * _pulse.value).round()),
            Colors.orange.withAlpha((40 * _pulse.value).round()),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  // ==========================================
  // NEGATIVE EMOTION EFFECTS
  // ==========================================

  Widget _buildRainDropsEffect() {
    return CustomPaint(
      size: Size(widget.size * 1.5, widget.size * 1.8),
      painter: _RainDropsPainter(
        progress: _particleController.value,
        color: Colors.lightBlue.shade300,
      ),
    );
  }

  Widget _buildTearDropEffect() {
    return Transform.translate(
      offset: Offset(-widget.size * 0.15, widget.size * 0.1),
      child: CustomPaint(
        size: Size(widget.size * 0.1, widget.size * 0.15),
        painter: _TearDropPainter(
          progress: _particleController.value,
          color: Colors.lightBlue.shade200,
        ),
      ),
    );
  }

  Widget _buildZzzEffect() {
    return Transform.translate(
      offset: Offset(widget.size * 0.35, -widget.size * 0.25),
      child: CustomPaint(
        size: Size(widget.size * 0.3, widget.size * 0.25),
        painter: _ZzzPainter(
          progress: _pulseController.value,
          color: _colors[2],
        ),
      ),
    );
  }

  Widget _buildYawnEffect() {
    return Container(
      width: widget.size * 1.2,
      height: widget.size * 1.2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.grey.withAlpha((30 * (1 - _pulse.value)).round()),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildConfusionSwirls() {
    return CustomPaint(
      size: Size(widget.size * 1.3, widget.size * 1.3),
      painter: _ConfusionSwirlsPainter(
        progress: _specialController.value,
        color: _colors[1],
      ),
    );
  }

  Widget _buildSweatDropEffect() {
    return Transform.translate(
      offset: Offset(widget.size * 0.3, -widget.size * 0.2),
      child: CustomPaint(
        size: Size(widget.size * 0.08, widget.size * 0.12),
        painter: _SweatDropPainter(
          progress: _pulse.value,
          color: Colors.lightBlue.shade200,
        ),
      ),
    );
  }

  Widget _buildShakeLines() {
    return CustomPaint(
      size: Size(widget.size * 1.3, widget.size * 1.3),
      painter: _ShakeLinesPainter(
        progress: _wobbleController.value,
        color: _colors[0],
      ),
    );
  }

  Widget _buildFearTremorEffect() {
    return CustomPaint(
      size: Size(widget.size * 1.4, widget.size * 1.4),
      painter: _FearTremorPainter(
        progress: _pulseController.value,
        color: Colors.purple.shade200,
      ),
    );
  }

  Widget _buildBlushEffect() {
    return Transform.translate(
      offset: Offset(0, widget.size * 0.05),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: widget.size * 0.12,
            height: widget.size * 0.08,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.size * 0.04),
              color: Colors.pink.withAlpha((100 * _pulse.value).round()),
            ),
          ),
          SizedBox(width: widget.size * 0.3),
          Container(
            width: widget.size * 0.12,
            height: widget.size * 0.08,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.size * 0.04),
              color: Colors.pink.withAlpha((100 * _pulse.value).round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAngerVeinsEffect() {
    return Transform.translate(
      offset: Offset(widget.size * 0.25, -widget.size * 0.25),
      child: CustomPaint(
        size: Size(widget.size * 0.15, widget.size * 0.15),
        painter: _AngerVeinPainter(progress: _pulse.value, color: Colors.red),
      ),
    );
  }

  Widget _buildSteamEffect() {
    return CustomPaint(
      size: Size(widget.size * 1.3, widget.size * 1.5),
      painter: _SteamPainter(
        progress: _particleController.value,
        color: Colors.grey,
      ),
    );
  }

  // ==========================================
  // SPECIAL EFFECTS
  // ==========================================

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

  Widget _buildStaticEffect() {
    return CustomPaint(
      size: Size(widget.size * 1.2, widget.size * 1.2),
      painter: _StaticNoisePainter(
        seed: (_particleController.value * 100).toInt(),
        color: _colors[0],
      ),
    );
  }

  Widget _buildZenAuraEffect() {
    return Container(
      width: widget.size * 1.5,
      height: widget.size * 1.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.cyan.withAlpha((30 * _pulse.value).round()),
            Colors.teal.withAlpha((20 * _pulse.value).round()),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingLeavesEffect() {
    return CustomPaint(
      size: Size(widget.size * 1.4, widget.size * 1.4),
      painter: _FloatingLeavesPainter(
        progress: _particleController.value,
        color: Colors.green.shade300,
      ),
    );
  }

  Widget _buildSassySparkEffect() {
    return Transform.translate(
      offset: Offset(widget.size * 0.3, -widget.size * 0.2),
      child: CustomPaint(
        size: Size(widget.size * 0.2, widget.size * 0.2),
        painter: _SassySparkPainter(progress: _pulse.value, color: Colors.pink),
      ),
    );
  }

  Widget _buildDevilHornsEffect() {
    return Transform.translate(
      offset: Offset(0, -widget.size * 0.45),
      child: CustomPaint(
        size: Size(widget.size * 0.5, widget.size * 0.2),
        painter: _DevilHornsPainter(progress: _pulse.value, color: Colors.red),
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

  Widget _buildLoadingDotsEffect() {
    return Transform.translate(
      offset: Offset(0, widget.size * 0.75), // Moved down for more spacing
      child: CustomPaint(
        size: Size(widget.size * 0.4, widget.size * 0.1),
        painter: _LoadingDotsPainter(
          progress: _particleController.value,
          color: _colors[1],
        ),
      ),
    );
  }

  Widget _buildErrorCrossEffect() {
    return CustomPaint(
      size: Size(widget.size * 0.3, widget.size * 0.3),
      painter: _ErrorCrossPainter(progress: _pulse.value, color: Colors.red),
    );
  }

  void _handleTap() {
    // Trigger haptic on tap
    HapticFeedback.lightImpact();
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

// ==========================================
// NEW PARTICLE/EFFECT PAINTERS
// ==========================================

/// Sparkle effect painter - floating sparkles
class _SparklePainter extends CustomPainter {
  final double progress;
  final List<Color> colors;
  final int count;

  _SparklePainter({
    required this.progress,
    required this.colors,
    this.count = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final random = math.Random(42);

    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi + progress * math.pi;
      final distance =
          size.width * 0.3 + random.nextDouble() * size.width * 0.15;
      final sparkleProgress = (progress + i / count) % 1.0;
      final opacity = math.sin(sparkleProgress * math.pi);
      final sparkleSize = 3 + random.nextDouble() * 4;

      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;

      _drawSparkle(
        canvas,
        Offset(x, y),
        sparkleSize * opacity,
        colors[i % colors.length].withAlpha((255 * opacity).round()),
      );
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color;

    // Four-pointed star sparkle
    final path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.lineTo(center.dx + size * 0.3, center.dy);
    path.lineTo(center.dx, center.dy + size);
    path.lineTo(center.dx - size * 0.3, center.dy);
    path.close();

    path.moveTo(center.dx - size, center.dy);
    path.lineTo(center.dx, center.dy + size * 0.3);
    path.lineTo(center.dx + size, center.dy);
    path.lineTo(center.dx, center.dy - size * 0.3);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Star burst effect for celebrations
class _StarBurstPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  _StarBurstPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * math.pi;
      final burstProgress = (progress * 2 + i / 12) % 1.0;
      final distance = burstProgress * size.width * 0.5;
      final opacity = (1 - burstProgress).clamp(0.0, 1.0);

      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;

      canvas.drawCircle(
        Offset(x, y),
        3 * opacity,
        Paint()
          ..color = colors[i % colors.length].withAlpha(
            (255 * opacity).round(),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_StarBurstPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Joy bubbles effect
class _JoyBubblesPainter extends CustomPainter {
  final double progress;
  final Color color;

  _JoyBubblesPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final random = math.Random(123);

    for (int i = 0; i < 8; i++) {
      final bubbleProgress = (progress + i / 8) % 1.0;
      final angle = random.nextDouble() * 2 * math.pi;
      final startX = center.dx + math.cos(angle) * size.width * 0.2;
      final y = center.dy - bubbleProgress * size.height * 0.4;
      final opacity = math.sin(bubbleProgress * math.pi);
      final bubbleSize = 4 + random.nextDouble() * 6;

      canvas.drawCircle(
        Offset(startX + math.sin(bubbleProgress * 4 * math.pi) * 10, y),
        bubbleSize * opacity,
        Paint()
          ..color = color.withAlpha((150 * opacity).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_JoyBubblesPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Crown effect for proud mood
class _CrownPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CrownPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Crown shape
    path.moveTo(0, h);
    path.lineTo(w * 0.15, h * 0.3);
    path.lineTo(w * 0.3, h * 0.6);
    path.lineTo(w * 0.5, 0);
    path.lineTo(w * 0.7, h * 0.6);
    path.lineTo(w * 0.85, h * 0.3);
    path.lineTo(w, h);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withAlpha((200 * progress).round())
        ..style = PaintingStyle.fill,
    );

    // Jewels
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.35),
      3,
      Paint()..color = Colors.red.withAlpha((255 * progress).round()),
    );
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Rising spark effect for hopeful mood
class _RisingSparkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RisingSparkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(456);

    for (int i = 0; i < 6; i++) {
      final sparkProgress = (progress + i / 6) % 1.0;
      final x = size.width * (0.3 + random.nextDouble() * 0.4);
      final y = size.height * (1 - sparkProgress);
      final opacity = math.sin(sparkProgress * math.pi);

      canvas.drawCircle(
        Offset(x, y),
        2 + opacity * 2,
        Paint()..color = color.withAlpha((255 * opacity).round()),
      );
    }
  }

  @override
  bool shouldRepaint(_RisingSparkPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Bouncing dots effect
class _BouncingDotsPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  _BouncingDotsPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 5; i++) {
      final angle = (i / 5) * 2 * math.pi + progress * math.pi;
      final bounce = math.sin((progress + i / 5) * 2 * math.pi).abs();
      final distance = size.width * 0.35 + bounce * 10;

      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;

      canvas.drawCircle(
        Offset(x, y),
        4 + bounce * 3,
        Paint()..color = colors[i % colors.length].withAlpha(200),
      );
    }
  }

  @override
  bool shouldRepaint(_BouncingDotsPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Lightning effect for energized mood
class _LightningPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double intensity;

  _LightningPainter({
    required this.progress,
    required this.color,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random((progress * 10).toInt());
    final center = Offset(size.width / 2, size.height / 2);

    // Draw 2-3 lightning bolts
    for (int bolt = 0; bolt < 3; bolt++) {
      if (random.nextDouble() > 0.6) continue;

      final angle = random.nextDouble() * 2 * math.pi;
      final startDistance = size.width * 0.15;
      final endDistance = size.width * 0.45;

      final start = Offset(
        center.dx + math.cos(angle) * startDistance,
        center.dy + math.sin(angle) * startDistance,
      );
      final end = Offset(
        center.dx + math.cos(angle) * endDistance,
        center.dy + math.sin(angle) * endDistance,
      );

      _drawLightningBolt(canvas, start, end, color, random);
    }
  }

  void _drawLightningBolt(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
    math.Random random,
  ) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    final segments = 4;
    var current = start;

    for (int i = 0; i < segments; i++) {
      final t = (i + 1) / segments;
      final target = Offset.lerp(start, end, t)!;
      final offset = (random.nextDouble() - 0.5) * 15;

      final perpX = -(end.dy - start.dy);
      final perpY = end.dx - start.dx;
      final len = math.sqrt(perpX * perpX + perpY * perpY);

      current = Offset(
        target.dx + (perpX / len) * offset,
        target.dy + (perpY / len) * offset,
      );
      path.lineTo(current.dx, current.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withAlpha((255 * intensity).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Glow
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withAlpha((80 * intensity).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(_LightningPainter oldDelegate) =>
      progress != oldDelegate.progress || intensity != oldDelegate.intensity;
}

/// Electric aura effect
class _ElectricAuraPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  _ElectricAuraPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final random = math.Random((progress * 20).toInt());

    for (int i = 0; i < 16; i++) {
      final angle = (i / 16) * 2 * math.pi;
      final jitter = (random.nextDouble() - 0.5) * 8;
      final radius = size.width * 0.4 + jitter;

      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;

      canvas.drawCircle(
        Offset(x, y),
        2,
        Paint()..color = colors[i % colors.length].withAlpha(180),
      );
    }
  }

  @override
  bool shouldRepaint(_ElectricAuraPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Thinking dots effect (... animation)
class _ThinkingDotsPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ThinkingDotsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      final dotProgress = (progress + i * 0.2) % 1.0;
      final bounce = math.sin(dotProgress * math.pi);
      final x = size.width * (0.2 + i * 0.3);
      final y = size.height * 0.5 - bounce * 8;

      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()..color = color.withAlpha((200 * (0.5 + bounce * 0.5)).round()),
      );
    }
  }

  @override
  bool shouldRepaint(_ThinkingDotsPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Sound waves effect for speaking/listening
class _SoundWavesPainter extends CustomPainter {
  final double progress;
  final Color color;

  _SoundWavesPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + i * 0.15) % 1.0;
      final radius = size.width * 0.25 + waveProgress * size.width * 0.2;
      final opacity = (1 - waveProgress).clamp(0.0, 0.6);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 3,
        math.pi * 2 / 3,
        false,
        Paint()
          ..color = color.withAlpha((255 * opacity).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_SoundWavesPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Focus rings effect
class _FocusRingsPainter extends CustomPainter {
  final double progress;
  final Color color;

  _FocusRingsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 2; i++) {
      final radius = size.width * 0.35 + i * 15;
      final opacity = progress * (i == 0 ? 0.4 : 0.2);

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withAlpha((255 * opacity).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_FocusRingsPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Single star painter for wink effect
class _SingleStarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _SingleStarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final starSize = size.width * 0.4 * progress;

    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * 2 * math.pi - math.pi / 4;
      final point = Offset(
        center.dx + math.cos(angle) * starSize,
        center.dy + math.sin(angle) * starSize,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(center.dx, center.dy);
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()..color = color.withAlpha((255 * progress).round()),
    );
  }

  @override
  bool shouldRepaint(_SingleStarPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Rain drops effect for sad mood
class _RainDropsPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RainDropsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(789);

    for (int i = 0; i < 12; i++) {
      final dropProgress = (progress + i / 12) % 1.0;
      final x = size.width * (0.1 + random.nextDouble() * 0.8);
      final y = dropProgress * size.height;
      final opacity = math.sin(dropProgress * math.pi) * 0.7;

      // Raindrop shape
      final path = Path();
      path.moveTo(x, y - 6);
      path.quadraticBezierTo(x + 3, y, x, y + 4);
      path.quadraticBezierTo(x - 3, y, x, y - 6);

      canvas.drawPath(
        path,
        Paint()..color = color.withAlpha((255 * opacity).round()),
      );
    }
  }

  @override
  bool shouldRepaint(_RainDropsPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Tear drop effect
class _TearDropPainter extends CustomPainter {
  final double progress;
  final Color color;

  _TearDropPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final opacity = math.sin(progress * math.pi);

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.quadraticBezierTo(
      size.width,
      size.height * 0.5,
      size.width / 2,
      size.height,
    );
    path.quadraticBezierTo(0, size.height * 0.5, size.width / 2, 0);

    canvas.save();
    canvas.translate(0, y * 0.5);
    canvas.drawPath(
      path,
      Paint()..color = color.withAlpha((200 * opacity).round()),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TearDropPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Zzz effect for sleeping
class _ZzzPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ZzzPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < 3; i++) {
      final zProgress = (progress + i * 0.25) % 1.0;
      final opacity = math.sin(zProgress * math.pi);
      final fontSize = 10.0 + i * 4;
      final x = i * 8.0;
      final y = -zProgress * 15 - i * 8;

      textPainter.text = TextSpan(
        text: 'z',
        style: TextStyle(
          fontSize: fontSize,
          color: color.withAlpha((200 * opacity).round()),
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x, y + size.height));
    }
  }

  @override
  bool shouldRepaint(_ZzzPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Confusion swirls effect
class _ConfusionSwirlsPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ConfusionSwirlsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 3; i++) {
      final angle =
          progress * 2 * math.pi * (i.isEven ? 1 : -1) + i * math.pi / 3;
      final radius = size.width * 0.3 + i * 8;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        math.pi,
        false,
        Paint()
          ..color = color.withAlpha(100)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Question marks
    final textPainter = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
          fontSize: 14,
          color: color.withAlpha(
            (150 * math.sin(progress * math.pi * 2).abs()).round(),
          ),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width * 0.7, size.height * 0.2));
  }

  @override
  bool shouldRepaint(_ConfusionSwirlsPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Sweat drop effect for nervous
class _SweatDropPainter extends CustomPainter {
  final double progress;
  final Color color;

  _SweatDropPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final bounce = math.sin(progress * math.pi * 4).abs();
    final y = bounce * 5;

    final path = Path();
    path.moveTo(size.width / 2, y);
    path.quadraticBezierTo(
      size.width,
      size.height * 0.6 + y,
      size.width / 2,
      size.height + y,
    );
    path.quadraticBezierTo(0, size.height * 0.6 + y, size.width / 2, y);

    canvas.drawPath(path, Paint()..color = color.withAlpha(180));
  }

  @override
  bool shouldRepaint(_SweatDropPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Shake lines effect for nervous/scared
class _ShakeLinesPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ShakeLinesPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shake = math.sin(progress * math.pi * 8) * 3;

    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * 2 * math.pi + math.pi / 4;
      final innerRadius = size.width * 0.38;
      final outerRadius = size.width * 0.45;

      final start = Offset(
        center.dx + math.cos(angle) * innerRadius + shake,
        center.dy + math.sin(angle) * innerRadius,
      );
      final end = Offset(
        center.dx + math.cos(angle) * outerRadius + shake,
        center.dy + math.sin(angle) * outerRadius,
      );

      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = color.withAlpha(100)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ShakeLinesPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Fear tremor effect
class _FearTremorPainter extends CustomPainter {
  final double progress;
  final Color color;

  _FearTremorPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final tremor = math.sin(progress * math.pi * 6) * 2;

    // Wavy fear aura
    final path = Path();
    for (double angle = 0; angle < 2 * math.pi; angle += 0.1) {
      final wave = math.sin(angle * 8 + progress * math.pi * 4) * 5;
      final radius = size.width * 0.4 + wave + tremor;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;

      if (angle == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withAlpha(60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_FearTremorPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Anger vein effect
class _AngerVeinPainter extends CustomPainter {
  final double progress;
  final Color color;

  _AngerVeinPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Classic anime anger symbol (cross vein)
    final paint = Paint()
      ..color = color.withAlpha((255 * progress).round())
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Two crossed lines with slight curve
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.8),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.8, size.height * 0.2),
      Offset(size.width * 0.2, size.height * 0.8),
      paint,
    );

    // Small bulges at the center
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      4 * progress,
      Paint()..color = color.withAlpha((200 * progress).round()),
    );
  }

  @override
  bool shouldRepaint(_AngerVeinPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Steam effect for angry mood
class _SteamPainter extends CustomPainter {
  final double progress;
  final Color color;

  _SteamPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(321);

    for (int i = 0; i < 4; i++) {
      final steamProgress = (progress + i / 4) % 1.0;
      final x = size.width * (0.3 + random.nextDouble() * 0.4);
      final y = size.height * 0.3 - steamProgress * size.height * 0.4;
      final opacity = (1 - steamProgress) * 0.5;
      final wave = math.sin(steamProgress * math.pi * 2) * 8;

      // Wavy steam line
      final path = Path();
      path.moveTo(x, y + 20);
      path.quadraticBezierTo(x + wave, y + 10, x, y);

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withAlpha((255 * opacity).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SteamPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Static noise effect for glitching
class _StaticNoisePainter extends CustomPainter {
  final int seed;
  final Color color;

  _StaticNoisePainter({required this.seed, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);

    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final w = 2 + random.nextDouble() * 8;
      final h = 1 + random.nextDouble() * 2;

      canvas.drawRect(
        Rect.fromLTWH(x, y, w, h),
        Paint()..color = color.withAlpha(50 + random.nextInt(100)),
      );
    }
  }

  @override
  bool shouldRepaint(_StaticNoisePainter oldDelegate) =>
      seed != oldDelegate.seed;
}

/// Floating leaves effect for zen mood
class _FloatingLeavesPainter extends CustomPainter {
  final double progress;
  final Color color;

  _FloatingLeavesPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(654);

    for (int i = 0; i < 5; i++) {
      final leafProgress = (progress + i / 5) % 1.0;
      final startX = random.nextDouble() * size.width;
      final x = startX + math.sin(leafProgress * math.pi * 2) * 20;
      final y = leafProgress * size.height;
      final rotation = leafProgress * math.pi * 2;
      final opacity = math.sin(leafProgress * math.pi) * 0.6;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      // Simple leaf shape
      final path = Path();
      path.moveTo(0, -6);
      path.quadraticBezierTo(6, 0, 0, 6);
      path.quadraticBezierTo(-6, 0, 0, -6);

      canvas.drawPath(
        path,
        Paint()..color = color.withAlpha((255 * opacity).round()),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FloatingLeavesPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Sassy spark effect
class _SassySparkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _SassySparkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Sparkle with attitude
    final sparkSize = size.width * 0.4 * progress;

    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * 2 * math.pi + progress * math.pi;
      final length = i.isEven ? sparkSize : sparkSize * 0.6;

      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(angle) * length,
          center.dy + math.sin(angle) * length,
        ),
        Paint()
          ..color = color.withAlpha((255 * progress).round())
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SassySparkPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Devil horns effect for mischievous
class _DevilHornsPainter extends CustomPainter {
  final double progress;
  final Color color;

  _DevilHornsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha((255 * progress).round())
      ..style = PaintingStyle.fill;

    // Left horn
    final leftPath = Path();
    leftPath.moveTo(size.width * 0.2, size.height);
    leftPath.lineTo(size.width * 0.1, 0);
    leftPath.lineTo(size.width * 0.3, size.height * 0.7);
    leftPath.close();
    canvas.drawPath(leftPath, paint);

    // Right horn
    final rightPath = Path();
    rightPath.moveTo(size.width * 0.8, size.height);
    rightPath.lineTo(size.width * 0.9, 0);
    rightPath.lineTo(size.width * 0.7, size.height * 0.7);
    rightPath.close();
    canvas.drawPath(rightPath, paint);
  }

  @override
  bool shouldRepaint(_DevilHornsPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Loading dots effect
class _LoadingDotsPainter extends CustomPainter {
  final double progress;
  final Color color;

  _LoadingDotsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      final dotProgress = (progress * 3 - i).clamp(0.0, 1.0);
      final scale = math.sin(dotProgress * math.pi);
      final x = size.width * (0.2 + i * 0.3);

      canvas.drawCircle(
        Offset(x, size.height / 2),
        4 * (0.5 + scale * 0.5),
        Paint()..color = color.withAlpha((200 * (0.5 + scale * 0.5)).round()),
      );
    }
  }

  @override
  bool shouldRepaint(_LoadingDotsPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Error cross effect
class _ErrorCrossPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ErrorCrossPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha((255 * progress).round())
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final margin = size.width * 0.2;
    canvas.drawLine(
      Offset(margin, margin),
      Offset(size.width - margin, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(margin, size.height - margin),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ErrorCrossPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
