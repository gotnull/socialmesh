// SPDX-License-Identifier: GPL-3.0-or-later

// Trait Badge — compact trait indicator for NodeDex list items and detail screens.
//
// Displays the inferred personality trait of a node as a styled badge
// with icon, label, and trait-specific color. Comes in multiple sizes:
// - compact: icon + short label, for list items
// - standard: icon + label + confidence, for cards
// - expanded: icon + label + description + confidence bar, for detail screens
//
// Trait colors are defined on NodeTrait itself for consistency.
// The badge never allows user editing — traits are always derived.

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../models/nodedex_entry.dart';
import '../services/trait_engine.dart';

/// Display size for the trait badge.
enum TraitBadgeSize {
  /// Minimal: just the icon with a colored background.
  minimal,

  /// Compact: icon + short label, fits inline in list rows.
  compact,

  /// Standard: icon + label, slightly larger for cards.
  standard,

  /// Expanded: full detail with description and confidence bar.
  expanded,
}

/// A badge that displays a node's inferred personality trait.
///
/// The badge is read-only — traits are always computed from real data
/// and cannot be manually assigned. The visual treatment uses the
/// trait's own color for immediate recognition.
class TraitBadge extends StatelessWidget {
  /// The trait to display.
  final NodeTrait trait;

  /// Optional confidence value (0.0 to 1.0) for the confidence indicator.
  final double? confidence;

  /// Display size of the badge.
  final TraitBadgeSize size;

  /// Whether to show the confidence indicator (only for standard and expanded).
  final bool showConfidence;

  /// Optional tap handler.
  final VoidCallback? onTap;

  const TraitBadge({
    super.key,
    required this.trait,
    this.confidence,
    this.size = TraitBadgeSize.compact,
    this.showConfidence = false,
    this.onTap,
  });

  /// Create a badge from a TraitResult.
  factory TraitBadge.fromResult({
    Key? key,
    required TraitResult result,
    TraitBadgeSize size = TraitBadgeSize.compact,
    bool showConfidence = false,
    VoidCallback? onTap,
  }) {
    return TraitBadge(
      key: key,
      trait: result.primary,
      confidence: result.confidence,
      size: size,
      showConfidence: showConfidence,
      onTap: onTap,
    );
  }

  IconData get _traitIcon {
    return switch (trait) {
      NodeTrait.wanderer => Icons.explore_outlined,
      NodeTrait.beacon => Icons.flare_outlined,
      NodeTrait.ghost => Icons.visibility_off_outlined,
      NodeTrait.sentinel => Icons.shield_outlined,
      NodeTrait.relay => Icons.swap_horiz,
      NodeTrait.courier => Icons.local_shipping_outlined,
      NodeTrait.anchor => Icons.anchor_outlined,
      NodeTrait.drifter => Icons.waves_outlined,
      NodeTrait.unknown => Icons.auto_awesome_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return switch (size) {
      TraitBadgeSize.minimal => _buildMinimal(context),
      TraitBadgeSize.compact => _buildCompact(context),
      TraitBadgeSize.standard => _buildStandard(context),
      TraitBadgeSize.expanded => _buildExpanded(context),
    };
  }

  Widget _buildMinimal(BuildContext context) {
    final color = trait.color;

    Widget badge = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(_traitIcon, size: 14, color: color),
    );

    if (onTap != null) {
      badge = GestureDetector(onTap: onTap, child: badge);
    }

    return Tooltip(message: trait.displayLabel, child: badge);
  }

  Widget _buildCompact(BuildContext context) {
    final color = trait.color;

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_traitIcon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            trait.displayLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      badge = GestureDetector(onTap: onTap, child: badge);
    }

    return badge;
  }

  Widget _buildStandard(BuildContext context) {
    final color = trait.color;
    final effectiveConfidence = confidence ?? 0.0;

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_traitIcon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            trait.displayLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (showConfidence && effectiveConfidence > 0) ...[
            const SizedBox(width: 8),
            _ConfidenceDot(
              confidence: effectiveConfidence,
              color: color,
              size: 16,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      badge = GestureDetector(onTap: onTap, child: badge);
    }

    return badge;
  }

  Widget _buildExpanded(BuildContext context) {
    final color = trait.color;
    final effectiveConfidence = confidence ?? 0.0;

    Widget content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row: icon + label + confidence
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_traitIcon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trait.displayLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trait.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (showConfidence && effectiveConfidence > 0)
                _ConfidenceDot(
                  confidence: effectiveConfidence,
                  color: color,
                  size: 24,
                  showLabel: true,
                ),
            ],
          ),

          // Confidence bar
          if (showConfidence && effectiveConfidence > 0) ...[
            const SizedBox(height: 12),
            _ConfidenceBar(confidence: effectiveConfidence, color: color),
          ],
        ],
      ),
    );

    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }

    return content;
  }
}

/// Inline trait indicator that shows just the icon with a tooltip.
///
/// Use this when space is very limited (e.g., in a data table or map marker).
class TraitIcon extends StatelessWidget {
  final NodeTrait trait;
  final double size;

  const TraitIcon({super.key, required this.trait, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final icon = switch (trait) {
      NodeTrait.wanderer => Icons.explore_outlined,
      NodeTrait.beacon => Icons.flare_outlined,
      NodeTrait.ghost => Icons.visibility_off_outlined,
      NodeTrait.sentinel => Icons.shield_outlined,
      NodeTrait.relay => Icons.swap_horiz,
      NodeTrait.courier => Icons.local_shipping_outlined,
      NodeTrait.anchor => Icons.anchor_outlined,
      NodeTrait.drifter => Icons.waves_outlined,
      NodeTrait.unknown => Icons.help_outline,
    };

    return Tooltip(
      message: trait.displayLabel,
      child: Icon(icon, size: size, color: trait.color),
    );
  }
}

/// Row of trait badges for a node that has both primary and secondary traits.
class TraitBadgeRow extends StatelessWidget {
  final TraitResult result;
  final TraitBadgeSize size;

  const TraitBadgeRow({
    super.key,
    required this.result,
    this.size = TraitBadgeSize.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TraitBadge(
          trait: result.primary,
          confidence: result.confidence,
          size: size,
        ),
        if (result.secondary != null) ...[
          const SizedBox(width: 6),
          Opacity(
            opacity: 0.7,
            child: TraitBadge(
              trait: result.secondary!,
              confidence: result.secondaryConfidence,
              size: size == TraitBadgeSize.expanded
                  ? TraitBadgeSize.standard
                  : TraitBadgeSize.minimal,
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// Internal widgets
// =============================================================================

/// Circular confidence indicator that shows a filled arc.
class _ConfidenceDot extends StatelessWidget {
  final double confidence;
  final Color color;
  final double size;
  final bool showLabel;

  const _ConfidenceDot({
    required this.confidence,
    required this.color,
    this.size = 16,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (confidence * 100).round();

    if (showLabel) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _ConfidenceArcPainter(
                progress: confidence,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      );
    }

    return Tooltip(
      message: 'Confidence: $percentage%',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ConfidenceArcPainter(progress: confidence, color: color),
        ),
      ),
    );
  }
}

/// Horizontal confidence bar for the expanded badge.
class _ConfidenceBar extends StatelessWidget {
  final double confidence;
  final Color color;

  const _ConfidenceBar({required this.confidence, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Confidence',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: context.textTertiary,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              '${(confidence * 100).round()}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 4,
            child: LinearProgressIndicator(
              value: confidence,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                color.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// CustomPainter for the circular confidence arc.
class _ConfidenceArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ConfidenceArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 2) / 2;

    // Background track.
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc.
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    const startAngle = -3.14159265358979 / 2; // Start at top
    final sweepAngle = 2 * 3.14159265358979 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ConfidenceArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Social tag badge for user-assigned node classifications.
///
/// Unlike trait badges, social tags ARE user-editable. They represent
/// the user's personal classification of a node.
class SocialTagBadge extends StatelessWidget {
  final NodeSocialTag tag;
  final VoidCallback? onTap;
  final bool compact;

  const SocialTagBadge({
    super.key,
    required this.tag,
    this.onTap,
    this.compact = false,
  });

  IconData get _tagIcon {
    return switch (tag) {
      NodeSocialTag.contact => Icons.person_outline,
      NodeSocialTag.trustedNode => Icons.verified_user_outlined,
      NodeSocialTag.knownRelay => Icons.cell_tower,
      NodeSocialTag.frequentPeer => Icons.people_outline,
    };
  }

  Color get _tagColor {
    return switch (tag) {
      NodeSocialTag.contact => const Color(0xFF0EA5E9),
      NodeSocialTag.trustedNode => const Color(0xFF10B981),
      NodeSocialTag.knownRelay => const Color(0xFFF97316),
      NodeSocialTag.frequentPeer => const Color(0xFF8B5CF6),
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _tagColor;

    Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(compact ? 10 : 14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_tagIcon, size: compact ? 11 : 13, color: color),
          SizedBox(width: compact ? 3 : 5),
          Text(
            tag.displayLabel,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      badge = GestureDetector(onTap: onTap, child: badge);
    }

    return badge;
  }
}

/// Selector sheet for choosing a social tag.
///
/// Presents all available social tags with descriptions and allows
/// the user to select one or clear the current tag.
class SocialTagSelector extends StatelessWidget {
  final NodeSocialTag? currentTag;
  final ValueChanged<NodeSocialTag?> onTagSelected;

  const SocialTagSelector({
    super.key,
    this.currentTag,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Classify Node',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
        ),
        Text(
          'Assign a personal classification to this node. '
          'This is only visible to you.',
          style: TextStyle(fontSize: 13, color: context.textSecondary),
        ),
        const SizedBox(height: 16),
        ...NodeSocialTag.values.map((tag) {
          final isSelected = tag == currentTag;
          return _SocialTagOption(
            tag: tag,
            isSelected: isSelected,
            onTap: () => onTagSelected(tag),
          );
        }),
        if (currentTag != null) ...[
          const SizedBox(height: 8),
          _ClearTagOption(onTap: () => onTagSelected(null)),
        ],
      ],
    );
  }
}

class _SocialTagOption extends StatelessWidget {
  final NodeSocialTag tag;
  final bool isSelected;
  final VoidCallback onTap;

  const _SocialTagOption({
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (tag) {
      NodeSocialTag.contact => const Color(0xFF0EA5E9),
      NodeSocialTag.trustedNode => const Color(0xFF10B981),
      NodeSocialTag.knownRelay => const Color(0xFFF97316),
      NodeSocialTag.frequentPeer => const Color(0xFF8B5CF6),
    };

    final icon = switch (tag) {
      NodeSocialTag.contact => Icons.person_outline,
      NodeSocialTag.trustedNode => Icons.verified_user_outlined,
      NodeSocialTag.knownRelay => Icons.cell_tower,
      NodeSocialTag.frequentPeer => Icons.people_outline,
    };

    final description = switch (tag) {
      NodeSocialTag.contact => 'A person you communicate with',
      NodeSocialTag.trustedNode => 'Verified infrastructure you trust',
      NodeSocialTag.knownRelay => 'A node that forwards traffic reliably',
      NodeSocialTag.frequentPeer => 'Regularly seen on the mesh',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.1) : context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.4)
                    : context.border.withValues(alpha: 0.3),
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tag.displayLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? color : context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, size: 20, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClearTagOption extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearTagOption({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.border.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.textTertiary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.clear, size: 18, color: context.textTertiary),
              ),
              const SizedBox(width: 12),
              Text(
                'Remove Classification',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
