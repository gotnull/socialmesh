import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import '../../core/theme.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../services/haptic_service.dart';

/// Provider to track discovered nodes for the overlay animation
final discoveredNodesQueueProvider =
    NotifierProvider<DiscoveredNodesNotifier, List<DiscoveredNodeEntry>>(
      DiscoveredNodesNotifier.new,
    );

/// Provider for haptic service
final hapticServiceProvider = Provider<HapticService>((ref) {
  return HapticService(ref);
});

class DiscoveredNodeEntry {
  final MeshNode node;
  final DateTime discoveredAt;
  final String id;
  final int signalStrength; // Cached for animation use

  DiscoveredNodeEntry({required this.node, required this.discoveredAt})
    : id = '${node.nodeNum}_${discoveredAt.millisecondsSinceEpoch}',
      signalStrength = node.rssi ?? -100;
}

class DiscoveredNodesNotifier extends Notifier<List<DiscoveredNodeEntry>> {
  @override
  List<DiscoveredNodeEntry> build() => [];

  void addNode(MeshNode node) {
    final entry = DiscoveredNodeEntry(node: node, discoveredAt: DateTime.now());
    state = [entry, ...state];

    // Remove after display duration (extended for premium feel)
    Future.delayed(const Duration(seconds: 5), () {
      removeNode(entry.id);
    });
  }

  void removeNode(String id) {
    state = state.where((e) => e.id != id).toList();
  }

  void clear() {
    state = [];
  }
}

/// Overlay widget that shows discovered nodes with rolling animation
class NodeDiscoveryOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const NodeDiscoveryOverlay({super.key, required this.child});

  @override
  ConsumerState<NodeDiscoveryOverlay> createState() =>
      _NodeDiscoveryOverlayState();
}

class _NodeDiscoveryOverlayState extends ConsumerState<NodeDiscoveryOverlay>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discoveredNodes = ref.watch(discoveredNodesQueueProvider);
    final isConnecting =
        ref.watch(autoReconnectStateProvider) ==
            AutoReconnectState.connecting ||
        ref.watch(autoReconnectStateProvider) == AutoReconnectState.scanning;

    // Listen for new node discoveries and trigger haptic
    ref.listen<MeshNode?>(nodeDiscoveryNotifierProvider, (previous, next) {
      if (next != null) {
        ref.read(discoveredNodesQueueProvider.notifier).addNode(next);
        // Trigger haptic feedback for node discovery
        HapticFeedback.mediumImpact();
      }
    });

    return Stack(
      children: [
        widget.child,

        // Subtle ambient radar sweep when scanning
        if (isConnecting || discoveredNodes.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: _AmbientRadarSweep(
                controller: _radarController,
                isActive: isConnecting,
              ),
            ),
          ),

        // Premium floating cards carousel
        if (discoveredNodes.isNotEmpty)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 90,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: SizedBox(
                height: 220,
                child: _PremiumCardCarousel(
                  entries: discoveredNodes.take(5).toList(),
                  onDismiss: (id) {
                    ref
                        .read(discoveredNodesQueueProvider.notifier)
                        .removeNode(id);
                  },
                ),
              ),
            ),
          ),

        // Scanning status indicator with particle effects
        if (isConnecting)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 0,
            right: 0,
            child: Center(
              child: _PremiumScanningIndicator(
                pulseController: _pulseController,
                nodeCount: discoveredNodes.length,
              ),
            ),
          ),
      ],
    );
  }
}

/// Ambient radar sweep background effect
class _AmbientRadarSweep extends StatelessWidget {
  final AnimationController controller;
  final bool isActive;

  const _AmbientRadarSweep({required this.controller, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _RadarSweepPainter(
            progress: controller.value,
            accentColor: context.accentColor,
            isActive: isActive,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _RadarSweepPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final bool isActive;

  _RadarSweepPainter({
    required this.progress,
    required this.accentColor,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height + 100);
    final maxRadius = size.height * 1.5;

    // Very subtle concentric circles (sonar/radar style)
    for (var i = 1; i <= 3; i++) {
      final radius = maxRadius * i / 3;
      final alpha = isActive ? 0.03 : 0.015;
      final circlePaint = Paint()
        ..color = accentColor.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, radius, circlePaint);
    }

    // Sweeping beam
    final sweepAngle = -math.pi + (progress * math.pi);
    final sweepPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(
        center.dx + math.cos(sweepAngle) * maxRadius,
        center.dy + math.sin(sweepAngle) * maxRadius,
      );

    // Gradient fade for sweep line
    final beamAlpha = isActive ? 0.15 : 0.05;
    final sweepPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          accentColor.withValues(alpha: beamAlpha),
          accentColor.withValues(alpha: 0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(sweepPath, sweepPaint);

    // Trailing glow effect
    for (var i = 1; i <= 8; i++) {
      final trailAngle = sweepAngle - (i * 0.08);
      final trailAlpha = (isActive ? 0.1 : 0.03) * (1 - i / 8);
      final trailPaint = Paint()
        ..color = accentColor.withValues(alpha: trailAlpha)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final trailPath = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(trailAngle) * maxRadius,
          center.dy + math.sin(trailAngle) * maxRadius,
        );
      canvas.drawPath(trailPath, trailPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isActive != isActive;
}

/// Premium scanning indicator with live stats
class _PremiumScanningIndicator extends StatelessWidget {
  final AnimationController pulseController;
  final int nodeCount;

  const _PremiumScanningIndicator({
    required this.pulseController,
    required this.nodeCount,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final pulseValue = pulseController.value;

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.card.withValues(alpha: 0.8),
                    context.surface.withValues(alpha: 0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: context.accentColor.withValues(
                    alpha: 0.3 + (pulseValue * 0.2),
                  ),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.accentColor.withValues(
                      alpha: 0.15 + (pulseValue * 0.1),
                    ),
                    blurRadius: 20 + (pulseValue * 10),
                    spreadRadius: -5,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated scanning icon
                  _ScanningOrb(pulseValue: pulseValue),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scanning Network',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nodeCount == 0
                            ? 'Searching for nodes...'
                            : '$nodeCount node${nodeCount == 1 ? '' : 's'} found',
                        style: TextStyle(
                          color: nodeCount > 0
                              ? context.accentColor
                              : context.textSecondary,
                          fontSize: 11,
                          fontWeight: nodeCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated scanning orb with ripple effect
class _ScanningOrb extends StatelessWidget {
  final double pulseValue;

  const _ScanningOrb({required this.pulseValue});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ripple
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: context.accentColor.withValues(
                  alpha: 0.2 * (1 - pulseValue),
                ),
                width: 1.5,
              ),
            ),
          ),
          // Middle ripple
          Transform.scale(
            scale: 0.7 + (pulseValue * 0.2),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.accentColor.withValues(
                  alpha: 0.1 + (pulseValue * 0.05),
                ),
                border: Border.all(
                  color: context.accentColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
          ),
          // Core
          MeshLoadingIndicator(
            size: 14,
            colors: [
              context.accentColor,
              context.accentColor.withValues(alpha: 0.6),
              context.accentColor.withValues(alpha: 0.3),
            ],
          ),
        ],
      ),
    );
  }
}

/// Premium floating cards carousel with depth and parallax
class _PremiumCardCarousel extends StatelessWidget {
  final List<DiscoveredNodeEntry> entries;
  final void Function(String id) onDismiss;

  const _PremiumCardCarousel({required this.entries, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Subtle ambient glow behind cards
        if (entries.isNotEmpty)
          Positioned(
            bottom: 20,
            child: Container(
              width: 300,
              height: 100,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    context.accentColor.withValues(alpha: 0.15),
                    context.accentColor.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        // Cards
        for (var i = entries.length - 1; i >= 0; i--)
          _PremiumCard(
            key: ValueKey(entries[i].id),
            entry: entries[i],
            index: i,
            totalCards: entries.length,
            onDismiss: () => onDismiss(entries[i].id),
          ),
      ],
    );
  }
}

class _PremiumCard extends StatefulWidget {
  final DiscoveredNodeEntry entry;
  final int index;
  final int totalCards;
  final VoidCallback onDismiss;

  const _PremiumCard({
    super.key,
    required this.entry,
    required this.index,
    required this.totalCards,
    required this.onDismiss,
  });

  @override
  State<_PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<_PremiumCard>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _idleController;
  late AnimationController _disintegrationController;

  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateYAnimation;
  late Animation<double> _floatAnimation;

  bool _isDisintegrating = false;
  bool _capturedImage = false;
  ui.Image? _cardImage;
  List<_DisintegrationFragment>? _fragments;
  final _repaintBoundaryKey = GlobalKey();
  final _random = math.Random();

  // Fragment grid configuration - higher = more fragments = smoother disintegration
  static const int _fragmentsX = 32; // Horizontal fragments
  static const int _fragmentsY = 18; // Vertical fragments

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    // Entry animation
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    // Idle floating animation
    _idleController = AnimationController(
      duration: Duration(milliseconds: 2500 + (widget.index * 200)),
      vsync: this,
    );

    // Disintegration animation - longer for dramatic effect
    _disintegrationController = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    );

    // Slide from right with bounce
    _slideAnimation = Tween<double>(begin: 350.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    // Fade in
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Scale up with slight overshoot
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutBack),
      ),
    );

    // 3D rotation (card flips in)
    _rotateYAnimation = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // Subtle floating animation
    _floatAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );

    // Stagger entry based on index
    final staggerDelay = widget.index * 120;
    Future.delayed(Duration(milliseconds: staggerDelay), () {
      if (mounted) {
        _entryController.forward().then((_) {
          if (mounted) {
            _idleController.repeat(reverse: true);
          }
        });
      }
    });

    // Schedule exit with pixel disintegration
    Future.delayed(Duration(milliseconds: 4200 + staggerDelay), () {
      _captureAndDisintegrate();
    });
  }

  /// Capture the card as an image, then start the disintegration
  Future<void> _captureAndDisintegrate() async {
    if (!mounted || _isDisintegrating) return;

    try {
      // Capture the widget as an image
      final boundary =
          _repaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        // Fallback: just dismiss
        widget.onDismiss();
        return;
      }

      // Capture at 2x resolution for crisp fragments
      final image = await boundary.toImage(pixelRatio: 2.0);

      if (!mounted) return;

      setState(() {
        _cardImage = image;
        _isDisintegrating = true;
        _capturedImage = true;
      });

      _idleController.stop();

      // Generate fragments from the captured image
      _generateFragments(image.width.toDouble(), image.height.toDouble());

      // Haptic feedback
      HapticFeedback.mediumImpact();

      // Start the disintegration animation
      _disintegrationController.forward().then((_) {
        if (mounted) widget.onDismiss();
      });
    } catch (e) {
      // Fallback: just dismiss
      if (mounted) widget.onDismiss();
    }
  }

  /// Generate fragment data for each piece of the disintegrating card
  void _generateFragments(double imageWidth, double imageHeight) {
    final fragmentWidth = imageWidth / _fragmentsX;
    final fragmentHeight = imageHeight / _fragmentsY;

    _fragments = [];

    for (int y = 0; y < _fragmentsY; y++) {
      for (int x = 0; x < _fragmentsX; x++) {
        // Normalized position (0-1)
        final normalizedX = x / _fragmentsX;
        final normalizedY = y / _fragmentsY;

        // Distance from center (for radial effects)
        final centerDistX = (normalizedX - 0.5).abs();
        final centerDistY = (normalizedY - 0.5).abs();
        final centerDist = math.sqrt(
          centerDistX * centerDistX + centerDistY * centerDistY,
        );

        // Disintegration starts from edges and moves inward with randomness
        // Also has a left-to-right sweep component
        final edgeFactor = centerDist * 0.4; // Edge pieces go first
        final sweepFactor = normalizedX * 0.35; // Left to right sweep
        final randomFactor = _random.nextDouble() * 0.25;
        final startDelay = (edgeFactor + sweepFactor + randomFactor).clamp(
          0.0,
          0.7,
        );

        // Calculate drift - fragments fly outward from center
        final directionX = (normalizedX - 0.5) * 2; // -1 to 1
        final directionY = (normalizedY - 0.5) * 2; // -1 to 1

        // Base drift with outward explosion + upward float (like ash)
        final driftX =
            directionX * (80 + _random.nextDouble() * 120) +
            (_random.nextDouble() - 0.3) * 60;
        final driftY =
            directionY * (60 + _random.nextDouble() * 80) -
            (40 + _random.nextDouble() * 100); // Upward bias

        // Z-axis drift for 3D effect (fragments come toward/away from viewer)
        final driftZ = (_random.nextDouble() - 0.5) * 200;

        // Rotation for each fragment
        final rotationX = (_random.nextDouble() - 0.5) * math.pi * 3;
        final rotationY = (_random.nextDouble() - 0.5) * math.pi * 3;
        final rotationZ = (_random.nextDouble() - 0.5) * math.pi * 4;

        // Scale variation - some fragments shrink faster
        final scaleEnd = 0.1 + _random.nextDouble() * 0.4;

        // Curve factor for non-linear paths
        final curveIntensity = (_random.nextDouble() - 0.5) * 2;

        _fragments!.add(
          _DisintegrationFragment(
            srcRect: Rect.fromLTWH(
              x * fragmentWidth,
              y * fragmentHeight,
              fragmentWidth,
              fragmentHeight,
            ),
            startDelay: startDelay,
            driftX: driftX,
            driftY: driftY,
            driftZ: driftZ,
            rotationX: rotationX,
            rotationY: rotationY,
            rotationZ: rotationZ,
            scaleEnd: scaleEnd,
            curveIntensity: curveIntensity,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _idleController.dispose();
    _disintegrationController.dispose();
    _cardImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.entry.node;
    final longName = node.longName ?? '';
    final shortName = node.shortName ?? '';
    final displayName = longName.isNotEmpty
        ? longName
        : shortName.isNotEmpty
        ? shortName
        : 'Unknown Node';
    final nodeId = node.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0');
    final rssi = node.rssi ?? 0;

    // Calculate depth-based transforms
    final horizontalOffset = widget.index * 20.0;
    final verticalOffset = widget.index * -6.0;
    final depthScale = 1.0 - (widget.index * 0.06);
    final baseRotation = widget.index * 0.02;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _entryController,
        _idleController,
        _disintegrationController,
      ]),
      builder: (context, child) {
        final currentSlide = _slideAnimation.value + horizontalOffset;
        final currentScale = _scaleAnimation.value * depthScale;
        final floatOffset = _idleController.isAnimating
            ? _floatAnimation.value * 3
            : 0.0;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0008) // Perspective
            ..leftTranslateByVector3(
              Vector3(currentSlide, verticalOffset + floatOffset, 0),
            )
            ..rotateY(_rotateYAnimation.value + baseRotation)
            ..scaleByVector3(Vector3.all(currentScale)),
          child: Opacity(
            opacity: _fadeAnimation.value * (1.0 - widget.index * 0.12),
            child: _capturedImage && _cardImage != null && _fragments != null
                // Show disintegrating fragments
                ? _DisintegrationRenderer(
                    image: _cardImage!,
                    fragments: _fragments!,
                    progress: _disintegrationController.value,
                  )
                // Show the actual card (wrapped in RepaintBoundary for capture)
                : RepaintBoundary(key: _repaintBoundaryKey, child: child),
          ),
        );
      },
      child: _buildCardContent(context, displayName, shortName, nodeId, rssi),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    String displayName,
    String shortName,
    String nodeId,
    int rssi,
  ) {
    final signalQuality = _getSignalQuality(rssi);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          width: 290,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.card.withValues(alpha: 0.85),
                context.surface.withValues(alpha: 0.7),
                context.card.withValues(alpha: 0.75),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: context.accentColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              // Inner glow
              BoxShadow(
                color: context.accentColor.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: -5,
                offset: const Offset(-2, -2),
              ),
              // Ambient shadow
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 12),
                spreadRadius: -5,
              ),
              // Colored glow based on signal
              BoxShadow(
                color: signalQuality.color.withValues(alpha: 0.15),
                blurRadius: 25,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with avatar and status
              Row(
                children: [
                  _PremiumNodeAvatar(
                    shortName: shortName,
                    signalQuality: signalQuality,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Discovery badge with animation
                        _DiscoveryBadge(),
                        const SizedBox(height: 8),
                        Text(
                          displayName,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Info chips row
              Row(
                children: [
                  // Node ID chip
                  _InfoChip(
                    icon: Icons.tag,
                    label: '!$nodeId',
                    color: context.textSecondary,
                    isMonospace: true,
                  ),
                  const Spacer(),
                  // Signal strength with animated indicator
                  if (rssi != 0)
                    _SignalChip(rssi: rssi, signalQuality: signalQuality),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _SignalQuality _getSignalQuality(int rssi) {
    if (rssi >= -60) {
      return _SignalQuality(
        label: 'Excellent',
        color: AccentColors.green,
        icon: Icons.signal_cellular_4_bar,
        strength: 1.0,
      );
    } else if (rssi >= -75) {
      return _SignalQuality(
        label: 'Good',
        color: AppTheme.warningYellow,
        icon: Icons.signal_cellular_alt_2_bar,
        strength: 0.6,
      );
    } else {
      return _SignalQuality(
        label: 'Weak',
        color: AppTheme.errorRed,
        icon: Icons.signal_cellular_alt_1_bar,
        strength: 0.3,
      );
    }
  }
}

/// Data class for each fragment of the disintegrating card
class _DisintegrationFragment {
  final Rect srcRect;
  final double startDelay;
  final double driftX;
  final double driftY;
  final double driftZ;
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final double scaleEnd;
  final double curveIntensity;

  const _DisintegrationFragment({
    required this.srcRect,
    required this.startDelay,
    required this.driftX,
    required this.driftY,
    required this.driftZ,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
    required this.scaleEnd,
    required this.curveIntensity,
  });
}

/// Widget that renders the disintegrating fragments
class _DisintegrationRenderer extends StatelessWidget {
  final ui.Image image;
  final List<_DisintegrationFragment> fragments;
  final double progress;

  const _DisintegrationRenderer({
    required this.image,
    required this.fragments,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DisintegrationPainter(
        image: image,
        fragments: fragments,
        progress: progress,
      ),
      size: Size(image.width / 2, image.height / 2), // Account for 2x capture
    );
  }
}

/// Custom painter that renders each fragment with its own transform
class _DisintegrationPainter extends CustomPainter {
  final ui.Image image;
  final List<_DisintegrationFragment> fragments;
  final double progress;

  _DisintegrationPainter({
    required this.image,
    required this.fragments,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.medium;

    // Scale factor (we captured at 2x)
    const scale = 0.5;

    for (final fragment in fragments) {
      // Calculate fragment-specific progress
      final fragmentProgress =
          ((progress - fragment.startDelay) / (1.0 - fragment.startDelay))
              .clamp(0.0, 1.0);

      if (fragmentProgress <= 0) {
        // Fragment hasn't started disintegrating - draw it in place
        final dstRect = Rect.fromLTWH(
          fragment.srcRect.left * scale,
          fragment.srcRect.top * scale,
          fragment.srcRect.width * scale,
          fragment.srcRect.height * scale,
        );
        canvas.drawImageRect(image, fragment.srcRect, dstRect, paint);
        continue;
      }

      // Easing curves for natural motion
      final moveProgress = Curves.easeOutCubic.transform(fragmentProgress);
      final fadeProgress = Curves.easeInQuad.transform(fragmentProgress);
      final scaleProgress = Curves.easeInCubic.transform(fragmentProgress);

      // Calculate current position
      final curveOffset =
          math.sin(moveProgress * math.pi) * fragment.curveIntensity * 30;
      final currentX =
          fragment.srcRect.center.dx * scale +
          fragment.driftX * moveProgress +
          curveOffset;
      final currentY =
          fragment.srcRect.center.dy * scale + fragment.driftY * moveProgress;
      final currentZ = fragment.driftZ * moveProgress;

      // Calculate current scale (shrinks as it flies away)
      final currentScale = 1.0 - (1.0 - fragment.scaleEnd) * scaleProgress;

      // Calculate opacity (fades out)
      final opacity = (1.0 - fadeProgress).clamp(0.0, 1.0);

      if (opacity <= 0 || currentScale <= 0) continue;

      // Set up paint with opacity
      paint.color = Color.fromRGBO(255, 255, 255, opacity);

      // Save canvas state
      canvas.save();

      // Apply perspective for Z movement
      final perspectiveFactor = 1.0 + currentZ * 0.001;

      // Move to fragment center
      canvas.translate(currentX, currentY);

      // Apply 3D rotations
      final scaleFactor = currentScale * perspectiveFactor;
      final matrix = Matrix4.identity()
        ..setEntry(3, 2, 0.002) // Perspective
        ..rotateX(fragment.rotationX * moveProgress)
        ..rotateY(fragment.rotationY * moveProgress)
        ..rotateZ(fragment.rotationZ * moveProgress)
        ..scaleByVector3(Vector3(scaleFactor, scaleFactor, scaleFactor));

      canvas.transform(matrix.storage);

      // Draw the fragment centered
      final halfWidth = fragment.srcRect.width * scale / 2;
      final halfHeight = fragment.srcRect.height * scale / 2;
      final dstRect = Rect.fromLTWH(
        -halfWidth,
        -halfHeight,
        fragment.srcRect.width * scale,
        fragment.srcRect.height * scale,
      );

      canvas.drawImageRect(image, fragment.srcRect, dstRect, paint);

      // Restore canvas state
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _DisintegrationPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SignalQuality {
  final String label;
  final Color color;
  final IconData icon;
  final double strength;

  _SignalQuality({
    required this.label,
    required this.color,
    required this.icon,
    required this.strength,
  });
}

/// Discovery badge with animated pulse effect
class _DiscoveryBadge extends StatefulWidget {
  @override
  State<_DiscoveryBadge> createState() => _DiscoveryBadgeState();
}

class _DiscoveryBadgeState extends State<_DiscoveryBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                context.accentColor.withValues(
                  alpha: 0.25 + (_pulseAnimation.value * 0.1),
                ),
                context.accentColor.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.accentColor.withValues(
                alpha: 0.4 * _pulseAnimation.value,
              ),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: context.accentColor.withValues(
                  alpha: 0.2 * _pulseAnimation.value,
                ),
                blurRadius: 8,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated dot indicator
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.accentColor,
                  boxShadow: [
                    BoxShadow(
                      color: context.accentColor.withValues(
                        alpha: 0.6 * _pulseAnimation.value,
                      ),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'DISCOVERED',
                style: TextStyle(
                  color: context.accentColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Info chip widget for node details
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isMonospace;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    this.isMonospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: isMonospace ? 'monospace' : null,
              letterSpacing: isMonospace ? 0.5 : 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Signal strength chip with animated bars
class _SignalChip extends StatefulWidget {
  final int rssi;
  final _SignalQuality signalQuality;

  const _SignalChip({required this.rssi, required this.signalQuality});

  @override
  State<_SignalChip> createState() => _SignalChipState();
}

class _SignalChipState extends State<_SignalChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _barController;

  @override
  void initState() {
    super.initState();
    _barController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _barController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.signalQuality.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.signalQuality.color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated signal bars
          _AnimatedSignalBars(
            controller: _barController,
            color: widget.signalQuality.color,
            strength: widget.signalQuality.strength,
          ),
          const SizedBox(width: 6),
          Text(
            '${widget.rssi} dBm',
            style: TextStyle(
              color: widget.signalQuality.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated signal strength bars
class _AnimatedSignalBars extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final double strength;

  const _AnimatedSignalBars({
    required this.controller,
    required this.color,
    required this.strength,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (index) {
            final barHeight = 4.0 + (index * 3);
            final isActive = (index + 1) / 4 <= strength;
            final delay = index * 0.15;
            final animValue = (controller.value - delay).clamp(0.0, 1.0);

            return Container(
              margin: EdgeInsets.only(right: index < 3 ? 2 : 0),
              width: 3,
              height: barHeight * animValue,
              decoration: BoxDecoration(
                color: isActive
                    ? color.withValues(alpha: 0.9)
                    : color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Premium node avatar with glow and ripple effects
class _PremiumNodeAvatar extends StatefulWidget {
  final String shortName;
  final _SignalQuality signalQuality;

  const _PremiumNodeAvatar({
    required this.shortName,
    required this.signalQuality,
  });

  @override
  State<_PremiumNodeAvatar> createState() => _PremiumNodeAvatarState();
}

class _PremiumNodeAvatarState extends State<_PremiumNodeAvatar>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _rippleController;
  late Animation<double> _glowAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowAnimation, _rippleAnimation]),
      builder: (context, child) {
        return SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple effect
              Transform.scale(
                scale: 1.0 + (_rippleAnimation.value * 0.3),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.accentColor.withValues(
                        alpha: 0.3 * (1 - _rippleAnimation.value),
                      ),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Glow background
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      context.accentColor.withValues(
                        alpha: 0.35 * _glowAnimation.value,
                      ),
                      context.accentColor.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: context.accentColor.withValues(
                        alpha: 0.25 * _glowAnimation.value,
                      ),
                      blurRadius: 14 + (6 * _glowAnimation.value),
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: widget.signalQuality.color.withValues(
                        alpha: 0.15 * _glowAnimation.value,
                      ),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ],
                ),
              ),
              // Avatar content
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.accentColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: widget.shortName.isNotEmpty
                      ? Text(
                          widget.shortName.substring(
                            0,
                            widget.shortName.length.clamp(0, 2),
                          ),
                          style: TextStyle(
                            color: context.accentColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        )
                      : Icon(
                          Icons.person_outline_rounded,
                          color: context.accentColor,
                          size: 26,
                        ),
                ),
              ),
              // Signal indicator dot
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: widget.signalQuality.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.card, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: widget.signalQuality.color.withValues(
                          alpha: 0.5,
                        ),
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
