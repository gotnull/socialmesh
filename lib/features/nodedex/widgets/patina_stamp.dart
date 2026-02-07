// SPDX-License-Identifier: GPL-3.0-or-later

// Patina Stamp — subtle stamp-style display for patina score.
//
// Renders a compact, stamp-like label showing the node's patina
// score and its associated label. The stamp is designed to look
// like an archival classification mark — understated, precise,
// and earned rather than decorative.
//
// Visual style:
//   - Monospace numerals for the score
//   - Muted accent color border (from sigil palette)
//   - Very subtle background tint
//   - Reads like "Inked: 62" or "Archival: 91"
//
// The stamp intentionally avoids progress bars or gauges. Patina
// is not a goal to fill — it is a measurement of accumulated
// history that emerges naturally from observation.

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../services/patina_score.dart';

/// Compact stamp displaying a node's patina score.
///
/// Designed for use in the NodeDex detail header. The stamp
/// renders as a subtle bordered label with the patina category
/// name and numeric score.
///
/// Usage:
/// ```dart
/// PatinaStamp(
///   result: PatinaScore.compute(entry),
///   accentColor: entry.sigil?.primaryColor ?? context.accentColor,
/// )
/// ```
class PatinaStamp extends StatelessWidget {
  /// The computed patina result to display.
  final PatinaResult result;

  /// Accent color for the stamp border and text.
  /// Typically the node's sigil primary color.
  final Color accentColor;

  /// Whether to show the breakdown tooltip on long press.
  final bool showBreakdownOnLongPress;

  const PatinaStamp({
    super.key,
    required this.result,
    required this.accentColor,
    this.showBreakdownOnLongPress = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: showBreakdownOnLongPress
          ? () => _showBreakdown(context)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.2),
            width: 0.75,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stamp label (e.g., "Inked")
            Text(
              result.stampLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accentColor.withValues(alpha: 0.7),
                letterSpacing: 0.3,
              ),
            ),
            // Separator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                ':',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: accentColor.withValues(alpha: 0.4),
                ),
              ),
            ),
            // Numeric score (monospace for alignment)
            Text(
              result.score.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: AppTheme.fontFamily,
                color: accentColor.withValues(alpha: 0.8),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBreakdown(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag pill
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.textTertiary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title row with overall score
                Row(
                  children: [
                    Text(
                      'Patina Breakdown',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    PatinaStamp(
                      result: result,
                      accentColor: accentColor,
                      showBreakdownOnLongPress: false,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Accumulated history across six dimensions',
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
                ),
                const SizedBox(height: 20),

                // Axis breakdowns
                _AxisRow(
                  label: 'Tenure',
                  value: result.tenure,
                  description: 'How long this node has been known',
                  color: accentColor,
                  context: sheetContext,
                ),
                _AxisRow(
                  label: 'Encounters',
                  value: result.encounters,
                  description: 'Number of distinct observations',
                  color: accentColor,
                  context: sheetContext,
                ),
                _AxisRow(
                  label: 'Reach',
                  value: result.reach,
                  description: 'Geographic spread across regions',
                  color: accentColor,
                  context: sheetContext,
                ),
                _AxisRow(
                  label: 'Signal Depth',
                  value: result.signalDepth,
                  description: 'Quality of signal records collected',
                  color: accentColor,
                  context: sheetContext,
                ),
                _AxisRow(
                  label: 'Social',
                  value: result.social,
                  description: 'Co-seen relationships and messages',
                  color: accentColor,
                  context: sheetContext,
                ),
                _AxisRow(
                  label: 'Recency',
                  value: result.recency,
                  description: 'How recently this node was active',
                  color: accentColor,
                  context: sheetContext,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A single axis row in the patina breakdown sheet.
class _AxisRow extends StatelessWidget {
  final String label;
  final double value;
  final String description;
  final Color color;
  final BuildContext context;

  const _AxisRow({
    required this.label,
    required this.value,
    required this.description,
    required this.color,
    required this.context,
  });

  @override
  Widget build(BuildContext buildContext) {
    final percentage = (value * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: buildContext.textPrimary,
                  ),
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppTheme.fontFamily,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Subtle bar visualization (not a progress bar — just a
          // proportional fill for quick visual comparison)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  return Stack(
                    children: [
                      // Background track
                      Container(
                        width: constraints.maxWidth,
                        color: buildContext.border.withValues(alpha: 0.3),
                      ),
                      // Filled portion
                      Container(
                        width: constraints.maxWidth * value.clamp(0.0, 1.0),
                        color: color.withValues(alpha: 0.4),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(fontSize: 10, color: buildContext.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Inline patina indicator for list tiles.
///
/// A minimal version of the stamp that shows only the score
/// as a small tinted number. Used where space is constrained.
class PatinaIndicator extends StatelessWidget {
  /// The computed patina result.
  final PatinaResult result;

  /// Accent color from the node's sigil.
  final Color accentColor;

  const PatinaIndicator({
    super.key,
    required this.result,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${result.score}',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          fontFamily: AppTheme.fontFamily,
          color: accentColor.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
