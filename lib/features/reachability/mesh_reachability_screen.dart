// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: haptic-feedback — GestureDetector is for keyboard dismissal, not user interaction
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/status_banner.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../models/reachability_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/reachability_provider.dart';
import '../nodes/nodes_screen.dart';

/// Mesh Reachability Screen
///
/// Displays a probabilistic assessment of node reachability based on
/// passively observed mesh data. This is an estimate only, not a guarantee.
///
/// Key constraints:
/// - No probing traffic is sent
/// - All data comes from passive observation
/// - Scores are probabilistic, not deterministic
/// - No green indicators or checkmarks (to avoid implying certainty)
class MeshReachabilityScreen extends ConsumerStatefulWidget {
  const MeshReachabilityScreen({super.key});

  @override
  ConsumerState<MeshReachabilityScreen> createState() =>
      _MeshReachabilityScreenState();
}

class _MeshReachabilityScreenState
    extends ConsumerState<MeshReachabilityScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final nodesByReach = ref.watch(nodesByReachabilityProvider);
    final allNodes = ref.watch(nodesWithReachabilityProvider);
    final animationsEnabled = ref.watch(animationsEnabledProvider);

    // Filter nodes by search
    List<NodeWithReachability> filteredNodes = allNodes;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredNodes = allNodes.where((n) {
        return n.node.displayName.toLowerCase().contains(query) ||
            n.node.nodeNum.toString().contains(query);
      }).toList();
    }

    return HelpTourController(
      topicId: 'reachability_overview',
      stepKeys: const {},
      child: GestureDetector(
        onTap: _dismissKeyboard,
        child: GlassScaffold(
          resizeToAvoidBottomInset: false,
          titleWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.reachabilityScreenTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warningYellow.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radius4),
                  border: Border.all(
                    color: AppTheme.warningYellow.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  context.l10n.reachabilityBetaBadge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warningYellow,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: context.l10n.reachabilityAboutTooltip,
              onPressed: () => _showInfoDialog(context),
            ),
            IcoHelpAppBarButton(topicId: 'reachability_overview'),
          ],
          slivers: [
            // Disclaimer banner
            SliverToBoxAdapter(child: _DisclaimerBanner()),

            // Summary row
            SliverToBoxAdapter(
              child: _ReachabilitySummary(
                highCount: nodesByReach.high.length,
                mediumCount: nodesByReach.medium.length,
                lowCount: nodesByReach.low.length,
              ),
            ),

            // Pinned search header
            SliverPersistentHeader(
              pinned: true,
              delegate: SearchFilterHeaderDelegate(
                searchController: _searchController,
                searchQuery: _searchQuery,
                onSearchChanged: (value) =>
                    setState(() => _searchQuery = value),
                hintText: context.l10n.reachabilitySearchHint,
                textScaler: MediaQuery.textScalerOf(context),
              ),
            ),

            // Node list
            if (filteredNodes.isEmpty)
              SliverFillRemaining(child: _EmptyState())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final nodeData = filteredNodes[index];
                  return Perspective3DSlide(
                    index: index,
                    direction: SlideDirection.left,
                    enabled: animationsEnabled,
                    child: _ReachabilityNodeCard(
                      nodeData: nodeData,
                      animationsEnabled: animationsEnabled,
                      onTap: () =>
                          showNodeDetailsSheet(context, nodeData.node, false),
                    ),
                  );
                }, childCount: filteredNodes.length),
              ),

            // Bottom padding
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    AppBottomSheet.showScrollable(
      context: context,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      title: context.l10n.reachabilityAboutTitle,
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.reachabilityGotIt),
        ),
      ),
      builder: (scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoSection(
              title: context.l10n.reachabilityWhatIsThisTitle,
              content: context.l10n.reachabilityWhatIsThisContent,
            ),
            const SizedBox(height: AppTheme.spacing16),
            _InfoSection(
              title: context.l10n.reachabilityScoringModelTitle,
              content: context.l10n.reachabilityScoringModelContent,
            ),
            const SizedBox(height: AppTheme.spacing16),
            _InfoSection(
              title: context.l10n.reachabilityHowCalculatedTitle,
              content: context.l10n.reachabilityHowCalculatedContent,
            ),
            const SizedBox(height: AppTheme.spacing16),
            _InfoSection(
              title: context.l10n.reachabilityLevelsMeanTitle,
              content: context.l10n.reachabilityLevelsMeanContent,
            ),
            const SizedBox(height: AppTheme.spacing16),
            _InfoSection(
              title: context.l10n.reachabilityLimitationsTitle,
              content: context.l10n.reachabilityLimitationsContent,
            ),
            const SizedBox(height: AppTheme.spacing16),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final String content;

  const _InfoSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          content,
          style: TextStyle(
            fontSize: 13,
            color: context.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _DisclaimerBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 0),
      child: StatusBanner.warning(
        title: context.l10n.reachabilityDisclaimerBanner,
        margin: EdgeInsets.zero,
      ),
    );
  }
}

class _ReachabilitySummary extends StatelessWidget {
  final int highCount;
  final int mediumCount;
  final int lowCount;

  const _ReachabilitySummary({
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppTheme.spacing16, 12, 16, 0),
      child: Row(
        children: [
          _SummaryChip(
            label: context.l10n.reachabilityLevelHigh,
            count: highCount,
            color: _ReachabilityColors.high,
          ),
          const SizedBox(width: AppTheme.spacing8),
          _SummaryChip(
            label: context.l10n.reachabilityLevelMedium,
            count: mediumCount,
            color: _ReachabilityColors.medium,
          ),
          const SizedBox(width: AppTheme.spacing8),
          _SummaryChip(
            label: context.l10n.reachabilityLevelLow,
            count: lowCount,
            color: _ReachabilityColors.low,
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radius10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: AppTheme.spacing2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius16),
            ),
            child: Icon(Icons.wifi_find, size: 40, color: context.textTertiary),
          ),
          SizedBox(height: AppTheme.spacing24),
          Text(
            context.l10n.reachabilityEmptyTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
          SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.reachabilityEmptyDescription,
            textAlign: TextAlign.center,
            style: context.bodySmallStyle?.copyWith(
              color: context.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReachabilityNodeCard extends StatelessWidget {
  final NodeWithReachability nodeData;
  final bool animationsEnabled;
  final VoidCallback onTap;

  const _ReachabilityNodeCard({
    required this.nodeData,
    required this.animationsEnabled,
    required this.onTap,
  });

  Color _getAvatarColor() {
    if (nodeData.node.avatarColor != null) {
      return Color(nodeData.node.avatarColor!);
    }
    final colors = [
      const Color(0xFF5B4FCE),
      const Color(0xFFD946A6),
      AppTheme.graphBlue,
      const Color(0xFFF59E0B),
      AppTheme.errorRed,
      AccentColors.emerald,
    ];
    return colors[nodeData.node.nodeNum % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final likelihood = nodeData.reachability.likelihood;
    final likelihoodColor = _ReachabilityColors.forLikelihood(likelihood);
    final likelihoodLabel = _ReachabilityColors.labelFor(context, likelihood);

    return BouncyTap(
      onTap: onTap,
      scaleFactor: animationsEnabled ? 0.98 : 1.0,
      enable3DPress: animationsEnabled,
      tiltDegrees: 4.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getAvatarColor().withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Center(
                  child: Text(
                    nodeData.node.shortName?.isNotEmpty == true
                        ? nodeData.node.shortName!.characters.first
                              .toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _getAvatarColor(),
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppTheme.spacing12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nodeData.node.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Likelihood badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: likelihoodColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius6,
                            ),
                            border: Border.all(
                              color: likelihoodColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            likelihoodLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: likelihoodColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing4),

                    // Short ID
                    Text(
                      '!${nodeData.node.nodeNum.toRadixString(16).padLeft(8, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),

                    // Metrics row
                    Row(
                      children: [
                        _MetricItem(
                          icon: Icons.route_outlined,
                          label: nodeData.reachability.pathDepthLabel,
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        _MetricItem(
                          icon: Icons.schedule_outlined,
                          label: nodeData.reachability.freshnessLabel,
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        _ScoreIndicator(
                          score: nodeData.reachability.score,
                          color: likelihoodColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.textTertiary),
        SizedBox(width: AppTheme.spacing4),
        Text(
          label,
          style: context.bodySmallStyle?.copyWith(color: context.textSecondary),
        ),
      ],
    );
  }
}

class _ScoreIndicator extends StatelessWidget {
  final double score;
  final Color color;

  const _ScoreIndicator({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    final percentage = (score * 100).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mini progress bar
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppTheme.radius2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: score,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacing6),
        Text(
          context.l10n.reachabilityScorePercent('$percentage'),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Colors for reachability levels.
/// Uses amber/orange/gray palette to avoid implying certainty
/// (no green checkmarks or success indicators).
class _ReachabilityColors {
  // Amber for high - warm but not green (not implying success)
  static const high = AppTheme.warningYellow;

  // Orange for medium - neutral caution
  static const medium = AccentColors.orange;

  // Gray-blue for low - indicates uncertainty
  static const low = AppTheme.textTertiary;

  static Color forLikelihood(ReachLikelihood likelihood) {
    switch (likelihood) {
      case ReachLikelihood.high:
        return high;
      case ReachLikelihood.medium:
        return medium;
      case ReachLikelihood.low:
        return low;
    }
  }

  static String labelFor(BuildContext context, ReachLikelihood likelihood) {
    switch (likelihood) {
      case ReachLikelihood.high:
        return context.l10n.reachabilityLevelHigh;
      case ReachLikelihood.medium:
        return context.l10n.reachabilityLevelMedium;
      case ReachLikelihood.low:
        return context.l10n.reachabilityLevelLow;
    }
  }
}
