// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// "My actions" chips tile used inside the NodeDex Constellation
// bento grid. Mirrors the "My activities" tile in the
// events-dashboard reference: a section header line and a flowing
// row of category-style chips.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme.dart';
import '../node_constellation_models.dart';

class NodeConstellationActionsTile extends StatelessWidget {
  /// All visible action nodes for the centre.
  final List<NodeDexGraphNode> actions;
  final String title;

  /// Looks up the localised label + icon for an action node.
  final String Function(BuildContext context, NodeDexGraphNode node) labelOf;
  final IconData Function(NodeDexGraphAction action) iconOf;
  final Color Function(BuildContext context, NodeDexGraphNode node) accentOf;

  /// Tap handler.
  final void Function(NodeDexGraphNode node) onTap;

  const NodeConstellationActionsTile({
    super.key,
    required this.actions,
    required this.title,
    required this.labelOf,
    required this.iconOf,
    required this.accentOf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius16),
      child: Container(
        decoration: BoxDecoration(
          color: context.card.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(color: context.border.withValues(alpha: 0.55)),
        ),
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            Wrap(
              spacing: AppTheme.spacing8,
              runSpacing: AppTheme.spacing8,
              children: [
                for (final node in actions)
                  _ActionChip(
                    label: labelOf(context, node),
                    icon: node.action != null ? iconOf(node.action!) : null,
                    accent: accentOf(context, node),
                    onTap: () => onTap(node),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color accent;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.accent,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing12,
          vertical: AppTheme.spacing8,
        ),
        decoration: BoxDecoration(
          color: context.background.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppTheme.radius20),
          border: Border.all(color: accent.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: AppTheme.spacing6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
