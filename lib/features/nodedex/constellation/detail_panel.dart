// SPDX-License-Identifier: GPL-3.0-or-later

// Constellation detail panel — fixed bottom bar showing selected node info.
//
// Two states:
// 1. Default: summary stats (node count, edge count, density label)
// 2. Selected: node avatar, name, trait, link count, profile button, clear
//
// Uses AnimatedSwitcher for smooth state transitions.
// Follows project conventions: theme extensions, AppTheme constants,
// SigilAvatar, no magic numbers, no context after await.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../providers/nodedex_providers.dart';
import '../services/sigil_generator.dart';
import '../widgets/sigil_painter.dart';

// =============================================================================
// Edge density display
// =============================================================================

/// Visual density preset — controls which edges are visible.
///
/// Each preset maps to a percentile threshold: edges with weight
/// below that percentile are hidden. Higher percentile = fewer edges.
enum EdgeDensity {
  /// Stars only — zero background edges. Selection edges still appear.
  none(1.0, 'Stars', Icons.auto_awesome),

  /// Top ~20% of edges shown very faintly.
  sparse(0.80, 'Sparse', Icons.grain),

  /// Top ~40% of edges shown.
  normal(0.60, 'Normal', Icons.blur_on),

  /// Top ~70% of edges shown.
  dense(0.30, 'Dense', Icons.blur_circular),

  /// All edges shown.
  all(0.0, 'All', Icons.all_inclusive);

  /// The weight percentile threshold — edges below this are hidden.
  final double percentile;

  /// Human-readable label for the density level.
  final String label;

  /// Icon representing this density level.
  final IconData icon;

  const EdgeDensity(this.percentile, this.label, this.icon);

  /// Whether background edges should be drawn at all.
  /// In [none] mode, only selection edges are visible.
  bool get showBackgroundEdges => this != none;

  /// Cycle to the next density preset.
  EdgeDensity get next {
    final values = EdgeDensity.values;
    return values[(index + 1) % values.length];
  }
}

// =============================================================================
// Detail Panel
// =============================================================================

/// Fixed-height bottom bar for the constellation screen.
///
/// Shows summary stats when no node is selected, and detailed node
/// info when a node is tapped. Transitions are smooth via AnimatedSwitcher.
///
/// This widget is a [ConsumerWidget] because it reads node data and
/// trait providers for the selected node display.
class ConstellationDetailPanel extends ConsumerWidget {
  /// Currently selected node number (null = nothing selected).
  final int? selectedNodeNum;

  /// Total node count in the constellation.
  final int nodeCount;

  /// Total edge count in the constellation.
  final int edgeCount;

  /// Current edge density preset.
  final EdgeDensity density;

  /// Callback to clear the selection.
  final VoidCallback? onClear;

  /// Callback to open the full node profile.
  final VoidCallback? onOpenDetail;

  const ConstellationDetailPanel({
    super.key,
    this.selectedNodeNum,
    required this.nodeCount,
    required this.edgeCount,
    required this.density,
    this.onClear,
    this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0E18) : const Color(0xFFF5F6FA),
        border: Border(
          top: BorderSide(color: context.border.withValues(alpha: 0.10)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: selectedNodeNum != null
                  ? _SelectedContent(
                      key: ValueKey<int>(selectedNodeNum!),
                      nodeNum: selectedNodeNum!,
                      onClear: onClear,
                      onOpenDetail: onOpenDetail,
                    )
                  : _DefaultContent(
                      key: const ValueKey<String>('default'),
                      nodeCount: nodeCount,
                      edgeCount: edgeCount,
                      density: density,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Default content — summary stats
// =============================================================================

class _DefaultContent extends StatelessWidget {
  final int nodeCount;
  final int edgeCount;
  final EdgeDensity density;

  const _DefaultContent({
    super.key,
    required this.nodeCount,
    required this.edgeCount,
    required this.density,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor = context.textSecondary;
    final tertiaryColor = context.textTertiary;
    final accent = context.accentColor;

    return Row(
      children: [
        // Node count
        Icon(Icons.scatter_plot_outlined, size: 14, color: tertiaryColor),
        const SizedBox(width: 6),
        Text(
          _formatCount(nodeCount, 'node', 'nodes'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: AppTheme.fontFamily,
            color: secondaryColor,
          ),
        ),

        const SizedBox(width: 12),

        // Edge count
        Icon(Icons.link, size: 14, color: tertiaryColor),
        const SizedBox(width: 6),
        Text(
          _formatCount(edgeCount, 'link', 'links'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: AppTheme.fontFamily,
            color: secondaryColor,
          ),
        ),

        const Spacer(),

        // Density badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            density.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: AppTheme.fontFamily,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }

  /// Format a count with singular/plural label.
  static String _formatCount(int count, String singular, String plural) {
    if (count >= 10000) {
      return '${(count / 1000).toStringAsFixed(1)}k $plural';
    }
    if (count == 1) return '$count $singular';
    return '$count $plural';
  }
}

// =============================================================================
// Selected content — node avatar, name, trait, actions
// =============================================================================

class _SelectedContent extends ConsumerWidget {
  final int nodeNum;
  final VoidCallback? onClear;
  final VoidCallback? onOpenDetail;

  const _SelectedContent({
    super.key,
    required this.nodeNum,
    this.onClear,
    this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(nodeDexEntryProvider(nodeNum));
    final trait = ref.watch(nodeDexTraitProvider(nodeNum));
    final nodes = ref.watch(nodesProvider);
    final node = nodes[nodeNum];

    // Fallback to default view if entry not found.
    if (entry == null) {
      return const SizedBox.shrink();
    }

    final sigil = entry.sigil ?? SigilGenerator.generate(nodeNum);
    final name = node?.displayName ?? 'Node $nodeNum';
    final primaryText = context.textPrimary;
    final tertiaryText = context.textTertiary;

    return Row(
      children: [
        // Sigil avatar
        SigilAvatar(sigil: sigil, nodeNum: nodeNum, size: 32),
        const SizedBox(width: 10),

        // Name and trait
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Node name
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTheme.fontFamily,
                  color: primaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Trait + link count
              Row(
                children: [
                  // Trait color dot
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: trait.primary.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trait.primary.displayLabel,
                    style: TextStyle(fontSize: 11, color: tertiaryText),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.coSeenCount} links',
                    style: TextStyle(
                      fontSize: 11,
                      color: tertiaryText,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Profile button
        GestureDetector(
          onTap: onOpenDetail,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: sigil.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: sigil.primaryColor.withValues(alpha: 0.20),
              ),
            ),
            child: Text(
              'Profile',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: AppTheme.fontFamily,
                color: sigil.primaryColor,
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Clear selection
        GestureDetector(
          onTap: onClear,
          child: Icon(Icons.close, size: 18, color: tertiaryText),
        ),
      ],
    );
  }
}
