import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
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
  String _searchQuery = '';

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
        child: Scaffold(
          backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: context.background,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Reachability',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warningYellow.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppTheme.warningYellow.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'BETA',
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
              tooltip: 'About Reachability',
              onPressed: () => _showInfoDialog(context),
            ),
            IcoHelpAppBarButton(topicId: 'reachability_overview'),
          ],
        ),
        body: Column(
          children: [
            // Disclaimer banner
            _DisclaimerBanner(),

            // Summary row
            _ReachabilitySummary(
              highCount: nodesByReach.high.length,
              mediumCount: nodesByReach.medium.length,
              lowCount: nodesByReach.low.length,
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search nodes',
                    hintStyle: TextStyle(color: context.textTertiary),
                    prefixIcon: Icon(Icons.search, color: context.textTertiary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),

            // Divider
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: context.border.withValues(alpha: 0.3),
            ),

            // Node list
            Expanded(
              child: filteredNodes.isEmpty
                  ? _EmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      itemCount: filteredNodes.length,
                      itemBuilder: (context, index) {
                        final nodeData = filteredNodes[index];
                        return Perspective3DSlide(
                          index: index,
                          direction: SlideDirection.left,
                          enabled: animationsEnabled,
                          child: _ReachabilityNodeCard(
                            nodeData: nodeData,
                            animationsEnabled: animationsEnabled,
                            onTap: () => showNodeDetailsSheet(
                              context,
                              nodeData.node,
                              false,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: Row(
          children: [
            Icon(Icons.info_outline, color: context.textSecondary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'About Reachability',
                style: TextStyle(color: context.textPrimary),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoSection(
                title: 'What is this?',
                content:
                    'This screen shows a probabilistic estimate of how likely '
                    'your messages will reach each node. It is NOT a guarantee '
                    'of delivery.',
              ),
              SizedBox(height: 16),
              _InfoSection(
                title: 'Scoring Model',
                content:
                    'Opportunistic Mesh Reach Likelihood Model (v1) — BETA\n\n'
                    'A heuristic scoring model that estimates likelihood of '
                    'reaching a node based on observed RF metrics and packet '
                    'history. This score represents likelihood, not reachability. '
                    'Meshtastic forwards packets opportunistically without routing. '
                    'A high score does not guarantee delivery.',
              ),
              SizedBox(height: 16),
              _InfoSection(
                title: 'How is it calculated?',
                content:
                    'The likelihood score combines several factors:\n'
                    '• Freshness: How recently we heard from the node\n'
                    '• Path Depth: Number of hops observed\n'
                    '• Signal Quality: RSSI and SNR when available\n'
                    '• Observation Pattern: Direct vs relayed packets\n'
                    '• ACK History: DM acknowledgement success rate',
              ),
              SizedBox(height: 16),
              _InfoSection(
                title: 'What the levels mean',
                content:
                    '• High: Strong recent indicators, but not guaranteed\n'
                    '• Medium: Moderate confidence based on available data\n'
                    '• Low: Weak or stale indicators, delivery unlikely',
              ),
              SizedBox(height: 16),
              _InfoSection(
                title: 'Important limitations',
                content:
                    '• Meshtastic has no true routing tables\n'
                    '• No end-to-end acknowledgements exist\n'
                    '• Forwarding is opportunistic\n'
                    '• Mesh topology changes constantly\n'
                    '• All estimates based on passive observation only',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
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
        const SizedBox(height: 4),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warningYellow.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warningYellow.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: AppTheme.warningYellow),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Likelihood estimates only. Delivery is never guaranteed in a mesh network.',
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
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
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _SummaryChip(
            label: 'High',
            count: highCount,
            color: _ReachabilityColors.high,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Medium',
            count: mediumCount,
            color: _ReachabilityColors.medium,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Low',
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
          borderRadius: BorderRadius.circular(10),
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
            const SizedBox(height: 2),
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
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.wifi_find, size: 40, color: context.textTertiary),
          ),
          SizedBox(height: 24),
          Text(
            'No nodes discovered yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Nodes will appear as they\'re observed\non the mesh network.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.textTertiary),
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
      const Color(0xFF3B82F6),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF10B981),
    ];
    return colors[nodeData.node.nodeNum % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final likelihood = nodeData.reachability.likelihood;
    final likelihoodColor = _ReachabilityColors.forLikelihood(likelihood);
    final likelihoodLabel = _ReachabilityColors.labelFor(likelihood);

    return BouncyTap(
      onTap: onTap,
      scaleFactor: animationsEnabled ? 0.98 : 1.0,
      enable3DPress: animationsEnabled,
      tiltDegrees: 4.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getAvatarColor().withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    nodeData.node.shortName?.isNotEmpty == true
                        ? nodeData.node.shortName!.substring(0, 1).toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _getAvatarColor(),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),

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
                            borderRadius: BorderRadius.circular(6),
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
                    const SizedBox(height: 4),

                    // Short ID
                    Text(
                      '!${nodeData.node.nodeNum.toRadixString(16).padLeft(8, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Metrics row
                    Row(
                      children: [
                        _MetricItem(
                          icon: Icons.route_outlined,
                          label: nodeData.reachability.pathDepthLabel,
                        ),
                        const SizedBox(width: 12),
                        _MetricItem(
                          icon: Icons.schedule_outlined,
                          label: nodeData.reachability.freshnessLabel,
                        ),
                        const SizedBox(width: 12),
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
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.textSecondary),
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
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: score,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$percentage%',
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
  static const high = Color(0xFFFBBF24);

  // Orange for medium - neutral caution
  static const medium = Color(0xFFF97316);

  // Gray-blue for low - indicates uncertainty
  static const low = Color(0xFF9CA3AF);

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

  static String labelFor(ReachLikelihood likelihood) {
    switch (likelihood) {
      case ReachLikelihood.high:
        return 'High';
      case ReachLikelihood.medium:
        return 'Medium';
      case ReachLikelihood.low:
        return 'Low';
    }
  }
}
