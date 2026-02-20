// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../services/trust_score.dart';

/// Size variants for the trust indicator.
enum TrustIndicatorSize {
  /// Dot only — 10px colored circle. For avatar overlays.
  dot,

  /// Compact pill — icon + label. For list tile badges.
  compact,

  /// Standard pill — icon + label + description. For detail screens.
  standard,
}

/// A visual indicator of a node's computed trust level.
///
/// Renders as a colored dot, compact pill, or expanded badge
/// depending on the [size] parameter. The trust level determines
/// the color and label — see [TrustLevel] for the color mapping.
///
/// This indicator shows *computed* trust, not user-assigned tags.
/// It must always be visually distinct from [SocialTagBadge].
class TrustIndicator extends StatelessWidget {
  /// The trust level to display.
  final TrustLevel level;

  /// Display size variant.
  final TrustIndicatorSize size;

  /// Optional tap handler (e.g., to show trust breakdown).
  final VoidCallback? onTap;

  const TrustIndicator({
    super.key,
    required this.level,
    this.size = TrustIndicatorSize.compact,
    this.onTap,
  });

  /// Create an indicator from a [TrustResult].
  factory TrustIndicator.fromResult({
    Key? key,
    required TrustResult result,
    TrustIndicatorSize size = TrustIndicatorSize.compact,
    VoidCallback? onTap,
  }) {
    return TrustIndicator(
      key: key,
      level: result.level,
      size: size,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Never show anything for unknown trust level.
    if (level == TrustLevel.unknown) return const SizedBox.shrink();

    return switch (size) {
      TrustIndicatorSize.dot => _buildDot(context),
      TrustIndicatorSize.compact => _buildCompact(context),
      TrustIndicatorSize.standard => _buildStandard(context),
    };
  }

  Widget _buildDot(BuildContext context) {
    final color = level.color;

    Widget dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: context.background, width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4),
        ],
      ),
    );

    if (onTap != null) {
      dot = GestureDetector(onTap: onTap, child: dot);
    }

    return Tooltip(message: level.displayLabel, child: dot);
  }

  Widget _buildCompact(BuildContext context) {
    final color = level.color;

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level.icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            level.displayLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
              fontFamily: AppTheme.fontFamily,
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
    final color = level.color;

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level.icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                level.displayLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.2,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              Text(
                level.description,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.7),
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
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
