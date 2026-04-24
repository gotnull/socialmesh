// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

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
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
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

  /// Whether tapping the stamp opens the breakdown sheet. Set false
  /// when rendering the stamp inside that very sheet to avoid
  /// recursive presentation.
  final bool interactive;

  const PatinaStamp({
    super.key,
    required this.result,
    required this.accentColor,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    final localizedLabel = PatinaScore.localizedStampLabel(
      result.stampLabel,
      context.l10n,
    );
    return GestureDetector(
      onTap: interactive
          ? () {
              HapticFeedback.selectionClick();
              _showBreakdown(context);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing10,
          vertical: AppTheme.spacing4,
        ),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radius6),
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
              localizedLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accentColor.withValues(alpha: 0.7),
                letterSpacing: 0.3,
              ),
            ),
            // Separator
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing4,
              ),
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
            // Visible (i) tap target — never hide the breakdown behind
            // a long-press; people don't know to try it.
            if (interactive) ...[
              const SizedBox(width: AppTheme.spacing4),
              Icon(
                Icons.info_outline,
                size: 12,
                color: accentColor.withValues(alpha: 0.6),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBreakdown(BuildContext context) {
    final l10n = context.l10n;
    AppBottomSheet.showScrollable<void>(
      context: context,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing24,
            0,
            AppTheme.spacing24,
            AppTheme.spacing24,
          ),
          children: [
            // Title row with overall score stamp on the right.
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.nodedexPatinaBreakdownTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                PatinaStamp(
                  result: result,
                  accentColor: accentColor,
                  interactive: false,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              l10n.nodedexPatinaBreakdownSubtitle,
              style: TextStyle(fontSize: 12, color: context.textTertiary),
            ),
            const SizedBox(height: AppTheme.spacing20),

            // Axis breakdowns
            _AxisRow(
              label: l10n.nodedexPatinaAxisTenure,
              value: result.tenure,
              description: l10n.nodedexPatinaAxisTenureDescription,
              color: accentColor,
            ),
            _AxisRow(
              label: l10n.nodedexPatinaAxisEncounters,
              value: result.encounters,
              description: l10n.nodedexPatinaAxisEncountersDescription,
              color: accentColor,
            ),
            _AxisRow(
              label: l10n.nodedexPatinaAxisReach,
              value: result.reach,
              description: l10n.nodedexPatinaAxisReachDescription,
              color: accentColor,
            ),
            _AxisRow(
              label: l10n.nodedexPatinaAxisSignalDepth,
              value: result.signalDepth,
              description: l10n.nodedexPatinaAxisSignalDepthDescription,
              color: accentColor,
            ),
            _AxisRow(
              label: l10n.nodedexPatinaAxisSocial,
              value: result.social,
              description: l10n.nodedexPatinaAxisSocialDescription,
              color: accentColor,
            ),
            _AxisRow(
              label: l10n.nodedexPatinaAxisRecency,
              value: result.recency,
              description: l10n.nodedexPatinaAxisRecencyDescription,
              color: accentColor,
            ),
          ],
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

  const _AxisRow({
    required this.label,
    required this.value,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (value * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
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
                    color: context.textPrimary,
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
          const SizedBox(height: AppTheme.spacing4),
          // Subtle bar visualization (not a progress bar — just a
          // proportional fill for quick visual comparison)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius2),
            child: SizedBox(
              height: 3,
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  return Stack(
                    children: [
                      // Background track
                      Container(
                        width: constraints.maxWidth,
                        color: context.border.withValues(alpha: 0.3),
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
          const SizedBox(height: AppTheme.spacing2),
          Text(
            description,
            style: TextStyle(fontSize: 10, color: context.textTertiary),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 11, color: accentColor),
          const SizedBox(width: AppTheme.spacing3),
          Text(
            '${result.score}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: AppTheme.fontFamily,
              color: accentColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
