// SPDX-License-Identifier: GPL-3.0-or-later

// Collection Slot — filled mini card preview and empty mystery slot.
//
// Two visual states for a single position in the album grid:
//
// 1. FilledSlot — a compact card preview showing:
//    - Rarity-colored border with optional glow
//    - Centered sigil at reduced size
//    - Node name (truncated) and hex ID
//    - Tiny trait dot indicator
//    - Mini holographic shimmer on rare+ cards
//    - Press feedback (scale animation)
//    - Tap callback to open detail/gallery
//
// 2. MysterySlot — an empty placeholder suggesting undiscovered nodes:
//    - Dashed border in muted theme color
//    - Faint "?" icon centered
//    - Very subtle pulse animation (respects reduce-motion)
//    - No interaction (purely decorative)
//
// Both slot types share the same dimensions (portrait, 5:7 aspect ratio)
// and border radius so they align cleanly in the album grid.
//
// Design constraints:
//   - No widget-per-particle or heavy effects — these appear in grids
//     of 12-30+ simultaneously visible slots
//   - All sizing is relative to slot width for responsive scaling
//   - Colors come from theme extensions and rarity system, never hardcoded
//   - Sigil rendering reuses the existing SigilPainter

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../models/nodedex_entry.dart';
import '../providers/nodedex_providers.dart';
import '../services/sigil_generator.dart';
import '../widgets/sigil_card.dart';
import '../widgets/sigil_painter.dart' show SigilWidget;
import 'album_constants.dart';
import 'holographic_effect.dart';

// =============================================================================
// Filled Slot — compact card preview for a discovered node
// =============================================================================

/// A compact card preview for a single discovered node in the album grid.
///
/// Shows the node's sigil, name, hex ID, and rarity border at thumbnail
/// scale. Tapping triggers [onTap] to open the detail view or gallery.
///
/// The slot renders a press-scale animation on touch for tactile feedback.
/// Rare, epic, and legendary cards receive a mini holographic shimmer.
///
/// Usage:
/// ```dart
/// FilledSlot(
///   entry: entry,
///   onTap: () => openGallery(entry),
///   animate: !reduceMotion,
/// )
/// ```
class FilledSlot extends ConsumerWidget {
  /// The NodeDex entry to display.
  final NodeDexEntry entry;

  /// Callback when the slot is tapped (short press).
  final VoidCallback? onTap;

  /// Callback when the slot is long-pressed (opens gallery).
  final VoidCallback? onLongPress;

  /// Whether animations are enabled (holographic shimmer, press scale).
  final bool animate;

  const FilledSlot({
    super.key,
    required this.entry,
    this.onTap,
    this.onLongPress,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traitResult = ref.watch(nodeDexTraitProvider(entry.nodeNum));
    final trait = traitResult.primary;
    final rarity = CardRarityVisuals.fromNodeData(
      encounterCount: entry.encounterCount,
      trait: trait,
    );
    final sigil = entry.sigil ?? SigilGenerator.generate(entry.nodeNum);
    final hexId =
        '!${entry.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    final name = entry.lastKnownName ?? hexId;

    return _PressScaleWrapper(
      animate: animate,
      onTap: onTap,
      onLongPress: onLongPress,
      child: AspectRatio(
        aspectRatio: AlbumConstants.slotAspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: context.isDarkMode
                ? const Color(0xFF1E2430)
                : const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(
              AlbumConstants.slotBorderRadius,
            ),
            border: Border.all(
              color: rarity.borderColor.withValues(alpha: 0.7),
              width: AlbumConstants.miniRarityBorderWidth,
            ),
            boxShadow: rarity.hasGlow
                ? [
                    BoxShadow(
                      color: rarity.glowColor.withValues(alpha: 0.2),
                      blurRadius: AlbumConstants.miniGlowBlur,
                      spreadRadius: AlbumConstants.miniGlowSpread,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              AlbumConstants.slotBorderRadius -
                  AlbumConstants.miniRarityBorderWidth,
            ),
            child: Stack(
              children: [
                // Card content
                Padding(
                  padding: const EdgeInsets.all(AlbumConstants.miniCardPadding),
                  child: Column(
                    children: [
                      // Sigil area
                      Expanded(
                        flex: 5,
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final sigilSize =
                                  math.min(
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  ) *
                                  AlbumConstants.miniSigilFraction;
                              return _MiniSigil(
                                sigil: sigil,
                                nodeNum: entry.nodeNum,
                                trait: trait,
                                rarity: rarity,
                                size: sigilSize,
                              );
                            },
                          ),
                        ),
                      ),

                      // Name and hex ID
                      Expanded(
                        flex: 2,
                        child: _MiniNamePlate(
                          name: name,
                          hexId: hexId,
                          trait: trait,
                        ),
                      ),
                    ],
                  ),
                ),

                // Holographic shimmer overlay for rare+ cards
                if (rarity.index >= CardRarity.rare.index)
                  MiniHolographicEffect(
                    rarityIndex: rarity.index,
                    animate: animate,
                  ),

                // Rarity accent bar at top
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          rarity.borderColor.withValues(alpha: 0.0),
                          rarity.borderColor.withValues(alpha: 0.5),
                          rarity.borderColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Mini sigil renderer
// =============================================================================

/// Renders a small sigil with a subtle glow halo behind it.
class _MiniSigil extends StatelessWidget {
  final SigilData sigil;
  final int nodeNum;
  final NodeTrait trait;
  final CardRarity rarity;
  final double size;

  const _MiniSigil({
    required this.sigil,
    required this.nodeNum,
    required this.trait,
    required this.rarity,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle glow halo
          Container(
            width: size * 0.85,
            height: size * 0.85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (sigil.primaryColor).withValues(alpha: 0.15),
                  blurRadius: size * 0.3,
                  spreadRadius: size * 0.05,
                ),
              ],
            ),
          ),
          // Sigil widget
          SigilWidget(sigil: sigil, size: size * 0.8, showGlow: false),
        ],
      ),
    );
  }
}

// =============================================================================
// Mini name plate
// =============================================================================

/// Compact name and hex ID display for the bottom of a filled slot.
class _MiniNamePlate extends StatelessWidget {
  final String name;
  final String hexId;
  final NodeTrait trait;

  const _MiniNamePlate({
    required this.name,
    required this.hexId,
    required this.trait,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Trait dot + name row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (trait != NodeTrait.unknown) ...[
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: trait.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: AlbumConstants.miniNameFontSize,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                  height: 1.2,
                ),
                maxLines: AlbumConstants.miniNameMaxLines,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          hexId,
          style: TextStyle(
            fontSize: AlbumConstants.miniHexFontSize,
            fontWeight: FontWeight.w500,
            fontFamily: AppTheme.fontFamily,
            color: context.textTertiary,
            letterSpacing: 0.5,
          ),
          maxLines: 1,
        ),
      ],
    );
  }
}

// =============================================================================
// Press scale animation wrapper
// =============================================================================

/// Wraps a child with a press-down scale animation for tactile feedback.
///
/// When the user presses and holds, the child scales down slightly.
/// On release it springs back. Respects [animate] flag for reduce-motion.
class _PressScaleWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool animate;

  const _PressScaleWrapper({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.animate = true,
  });

  @override
  State<_PressScaleWrapper> createState() => _PressScaleWrapperState();
}

class _PressScaleWrapperState extends State<_PressScaleWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AlbumConstants.pressScaleDuration,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: AlbumConstants.pressScaleFactor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.animate) _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.animate) _controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    if (widget.animate) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: widget.child,
      );
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: () {
        _controller.reverse();
        widget.onLongPress?.call();
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(scale: _scale.value, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

// =============================================================================
// Mystery Slot — empty placeholder for undiscovered nodes
// =============================================================================

/// An empty placeholder slot suggesting more nodes to discover.
///
/// Renders a dashed border with a faint "?" icon centered inside.
/// When [animate] is true, a very subtle pulse animation plays on
/// the "?" icon. The slot is purely decorative and ignores pointer
/// events.
///
/// Usage:
/// ```dart
/// MysterySlot(animate: !reduceMotion)
/// ```
class MysterySlot extends StatelessWidget {
  /// Whether to animate the mystery icon pulse.
  final bool animate;

  const MysterySlot({super.key, this.animate = true});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: AlbumConstants.slotAspectRatio,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: context.border.withValues(
              alpha: AlbumConstants.mysterySlotOpacity,
            ),
            borderRadius: AlbumConstants.slotBorderRadius,
            dashLength: AlbumConstants.emptySlotDashLength,
            dashGap: AlbumConstants.emptySlotDashGap,
            strokeWidth: AlbumConstants.emptySlotBorderWidth,
          ),
          child: Center(
            child: animate
                ? _PulsingMysteryIcon(
                    color: context.textTertiary.withValues(
                      alpha: AlbumConstants.mysterySlotOpacity,
                    ),
                  )
                : Icon(
                    Icons.help_outline_rounded,
                    size: AlbumConstants.mysteryIconSize,
                    color: context.textTertiary.withValues(
                      alpha: AlbumConstants.mysterySlotOpacity,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Pulsing mystery icon
// =============================================================================

/// A "?" icon with a slow, subtle opacity pulse animation.
///
/// The pulse cycles between 60% and 100% of the base opacity
/// over 2.5 seconds, creating a gentle breathing effect that
/// hints at undiscovered content without being distracting.
class _PulsingMysteryIcon extends StatefulWidget {
  final Color color;

  const _PulsingMysteryIcon({required this.color});

  @override
  State<_PulsingMysteryIcon> createState() => _PulsingMysteryIconState();
}

class _PulsingMysteryIconState extends State<_PulsingMysteryIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _opacity = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(opacity: _opacity.value, child: child);
      },
      child: Icon(
        Icons.help_outline_rounded,
        size: AlbumConstants.mysteryIconSize,
        color: widget.color,
      ),
    );
  }
}

// =============================================================================
// Dashed border painter
// =============================================================================

/// Paints a rounded-rectangle dashed border.
///
/// Used for the mystery slot outline. The border follows the
/// rounded rectangle path with configurable dash length, gap,
/// and stroke width.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;
  final double dashLength;
  final double dashGap;
  final double strokeWidth;

  _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.dashLength,
    required this.dashGap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dashLength, metric.length);
        final extractedPath = metric.extractPath(distance, end);
        canvas.drawPath(extractedPath, paint);
        distance += dashLength + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        borderRadius != oldDelegate.borderRadius ||
        dashLength != oldDelegate.dashLength ||
        dashGap != oldDelegate.dashGap ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}
