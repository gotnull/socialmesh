// SPDX-License-Identifier: GPL-3.0-or-later

// Edge Detail Sheet — rich per-edge relationship info bottom sheet.
//
// Shows detailed information about a co-seen relationship between two
// nodes, including:
// - Both endpoint nodes with sigil avatars (tappable to navigate)
// - Relationship strength indicator (visual bar)
// - Co-seen count, message count, relationship age
// - Timeline visualization (first seen → last seen)
// - Contextual metadata about each endpoint
//
// This widget is shared between:
// - Constellation screen (tap "View Details" on edge info card)
// - Detail screen (tap a co-seen node row)

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../models/mesh_models.dart';
import '../../../providers/app_providers.dart';
import '../models/nodedex_entry.dart';
import '../providers/nodedex_providers.dart';
import '../services/sigil_generator.dart';
import '../services/trait_engine.dart';
import 'sigil_painter.dart';

/// Shows a detailed bottom sheet for a co-seen relationship (edge)
/// between two nodes.
///
/// Call [EdgeDetailSheet.show] to present the sheet. The sheet reads
/// live data from providers so it stays up-to-date.
class EdgeDetailSheet extends ConsumerWidget {
  /// Node number of the first endpoint.
  final int fromNodeNum;

  /// Node number of the second endpoint.
  final int toNodeNum;

  /// Callback when the user taps an endpoint to navigate to its detail.
  final ValueChanged<int>? onOpenNodeDetail;

  const EdgeDetailSheet({
    super.key,
    required this.fromNodeNum,
    required this.toNodeNum,
    this.onOpenNodeDetail,
  });

  /// Show the edge detail sheet as a modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required int fromNodeNum,
    required int toNodeNum,
    ValueChanged<int>? onOpenNodeDetail,
  }) {
    final fromHex =
        '!${fromNodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    final toHex =
        '!${toNodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    AppLogging.nodeDex('Edge detail sheet opened: $fromHex ↔ $toHex');
    return AppBottomSheet.show<void>(
      context: context,
      child: EdgeDetailSheet(
        fromNodeNum: fromNodeNum,
        toNodeNum: toNodeNum,
        onOpenNodeDetail: onOpenNodeDetail,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final fromEntry = ref.watch(nodeDexEntryProvider(fromNodeNum));
    final toEntry = ref.watch(nodeDexEntryProvider(toNodeNum));
    final fromNode = nodes[fromNodeNum];
    final toNode = nodes[toNodeNum];

    // Resolve the relationship from both directions (pick the one
    // that exists — they should be symmetric but we handle edge cases).
    final relationship =
        fromEntry?.coSeenNodes[toNodeNum] ?? toEntry?.coSeenNodes[fromNodeNum];

    if (relationship == null) {
      AppLogging.nodeDex(
        'Edge detail: no relationship found between $fromNodeNum and $toNodeNum',
      );
      return _buildNoRelationship(context);
    }

    AppLogging.nodeDex(
      'Edge detail loaded: co-seen ${relationship.count} times, '
      'messages: ${relationship.messageCount}, '
      'first: ${relationship.firstSeen}, last: ${relationship.lastSeen}',
    );

    final fromSigil = fromEntry?.sigil ?? SigilGenerator.generate(fromNodeNum);
    final toSigil = toEntry?.sigil ?? SigilGenerator.generate(toNodeNum);
    final fromName = fromNode?.displayName ?? _hexName(fromNodeNum);
    final toName = toNode?.displayName ?? _hexName(toNodeNum);

    final blendedColor =
        Color.lerp(fromSigil.primaryColor, toSigil.primaryColor, 0.5) ??
        context.accentColor;

    final fromTrait = ref.watch(nodeDexTraitProvider(fromNodeNum));
    final toTrait = ref.watch(nodeDexTraitProvider(toNodeNum));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        _buildHeader(context, blendedColor),

        const SizedBox(height: 20),

        // Endpoint nodes
        _buildEndpoints(
          context,
          fromSigil: fromSigil,
          toSigil: toSigil,
          fromName: fromName,
          toName: toName,
          fromTrait: fromTrait,
          toTrait: toTrait,
          fromNode: fromNode,
          toNode: toNode,
          blendedColor: blendedColor,
        ),

        const SizedBox(height: 20),

        // Strength indicator
        _buildStrengthIndicator(context, relationship, blendedColor),

        const SizedBox(height: 16),

        // Stats grid
        _buildStatsGrid(context, relationship, blendedColor),

        const SizedBox(height: 16),

        // Timeline
        _buildTimeline(context, relationship, blendedColor),

        // Message activity section (if any messages)
        if (relationship.messageCount > 0) ...[
          const SizedBox(height: 16),
          _buildMessageActivity(context, relationship, blendedColor),
        ],

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildNoRelationship(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.link_off,
          size: 48,
          color: context.textTertiary.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 12),
        Text(
          'No relationship data',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'These nodes have not been observed together.',
          style: TextStyle(fontSize: 13, color: context.textTertiary),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Color accent) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.15),
                accent.withValues(alpha: 0.08),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Icon(Icons.link, size: 20, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Constellation Link',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Co-seen relationship details',
                style: TextStyle(fontSize: 12, color: context.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEndpoints(
    BuildContext context, {
    required SigilData fromSigil,
    required SigilData toSigil,
    required String fromName,
    required String toName,
    required TraitResult fromTrait,
    required TraitResult toTrait,
    required MeshNode? fromNode,
    required MeshNode? toNode,
    required Color blendedColor,
  }) {
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // From endpoint
          Expanded(
            child: _EndpointTile(
              sigil: fromSigil,
              nodeNum: fromNodeNum,
              name: fromName,
              trait: fromTrait,
              isOnline: fromNode != null,
              onTap: onOpenNodeDetail != null
                  ? () {
                      Navigator.of(context).pop();
                      onOpenNodeDetail!(fromNodeNum);
                    }
                  : null,
            ),
          ),

          // Connection visual
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated-style link indicator
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        fromSigil.primaryColor.withValues(alpha: 0.15),
                        toSigil.primaryColor.withValues(alpha: 0.15),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: blendedColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    Icons.sync_alt,
                    size: 16,
                    color: blendedColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          // To endpoint
          Expanded(
            child: _EndpointTile(
              sigil: toSigil,
              nodeNum: toNodeNum,
              name: toName,
              trait: toTrait,
              isOnline: toNode != null,
              onTap: onOpenNodeDetail != null
                  ? () {
                      Navigator.of(context).pop();
                      onOpenNodeDetail!(toNodeNum);
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthIndicator(
    BuildContext context,
    CoSeenRelationship relationship,
    Color accent,
  ) {
    // Strength is a logarithmic scale based on co-seen count.
    // 1x = minimal, 5x = moderate, 10+ = strong, 25+ = very strong
    final strength = _strengthLabel(relationship.count);
    final strengthFraction = _strengthFraction(relationship.count);
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.signal_cellular_alt, size: 14, color: accent),
            const SizedBox(width: 6),
            Text(
              'Link Strength',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                strength,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Strength bar
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.06,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: strengthFraction,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withValues(alpha: 0.6), accent],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    CoSeenRelationship relationship,
    Color accent,
  ) {
    final dateFormat = DateFormat('d MMM yyyy');
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  icon: Icons.visibility_outlined,
                  label: 'Co-seen',
                  value: '${relationship.count}x',
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCell(
                  icon: Icons.chat_bubble_outline,
                  label: 'Messages',
                  value: '${relationship.messageCount}',
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  icon: Icons.calendar_today_outlined,
                  label: 'First Link',
                  value: dateFormat.format(relationship.firstSeen),
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCell(
                  icon: Icons.schedule_outlined,
                  label: 'Last Seen',
                  value: _formatRelativeTime(relationship.timeSinceLastSeen),
                  color: accent,
                ),
              ),
            ],
          ),
          if (relationship.relationshipAge.inHours >= 1) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    icon: Icons.timelapse_outlined,
                    label: 'Duration',
                    value: _formatDuration(relationship.relationshipAge),
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    CoSeenRelationship relationship,
    Color accent,
  ) {
    final dateFormat = DateFormat('d MMM yyyy, HH:mm');
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timeline, size: 14, color: accent),
            const SizedBox(width: 6),
            Text(
              'Relationship Timeline',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Timeline visual
        Row(
          children: [
            // First seen dot and label
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'First',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    dateFormat.format(relationship.firstSeen),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textSecondary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              ],
            ),

            // Connecting line
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.3),
                        accent.withValues(alpha: 0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),

            // Last seen dot and label
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Latest',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: accent, width: 1.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    dateFormat.format(relationship.lastSeen),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textSecondary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Age annotation
        if (relationship.relationshipAge.inHours >= 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.04,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Linked for ${_formatDuration(relationship.relationshipAge)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageActivity(
    BuildContext context,
    CoSeenRelationship relationship,
    Color accent,
  ) {
    final ageInDays = relationship.relationshipAge.inDays;
    final messagesPerDay = ageInDays > 0
        ? (relationship.messageCount / ageInDays).toStringAsFixed(1)
        : '${relationship.messageCount}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_outlined, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message Activity',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${relationship.messageCount} messages exchanged while co-present',
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                ),
              ],
            ),
          ),
          if (ageInDays > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  messagesPerDay,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                Text(
                  '/day',
                  style: TextStyle(fontSize: 10, color: context.textTertiary),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _hexName(int nodeNum) {
    return 'Node ${nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';
  }

  String _strengthLabel(int count) {
    if (count >= 25) return 'Very Strong';
    if (count >= 10) return 'Strong';
    if (count >= 5) return 'Moderate';
    if (count >= 2) return 'Emerging';
    return 'New';
  }

  double _strengthFraction(int count) {
    // Log-scale: 1→0.1, 5→0.4, 10→0.6, 25→0.85, 50+→1.0
    if (count <= 0) return 0.0;
    if (count >= 50) return 1.0;
    // ln(50) ≈ 3.912
    return (math.log(count) / math.log(50)).clamp(0.05, 1.0);
  }

  String _formatRelativeTime(Duration duration) {
    if (duration.inMinutes < 1) return 'just now';
    if (duration.inMinutes < 60) return '${duration.inMinutes}m ago';
    if (duration.inHours < 24) return '${duration.inHours}h ago';
    if (duration.inDays < 30) return '${duration.inDays}d ago';
    return '${(duration.inDays / 30).floor()}mo ago';
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays >= 365) {
      final years = duration.inDays ~/ 365;
      final months = (duration.inDays % 365) ~/ 30;
      if (months > 0) return '$years yr $months mo';
      return '$years yr';
    }
    if (duration.inDays >= 30) {
      final months = duration.inDays ~/ 30;
      final days = duration.inDays % 30;
      if (days > 0) return '$months mo $days d';
      return '$months mo';
    }
    if (duration.inDays >= 1) return '${duration.inDays} d';
    if (duration.inHours >= 1) return '${duration.inHours} hr';
    return '${duration.inMinutes} min';
  }
}

// =============================================================================
// Endpoint Tile
// =============================================================================

class _EndpointTile extends StatelessWidget {
  final SigilData sigil;
  final int nodeNum;
  final String name;
  final TraitResult trait;
  final bool isOnline;
  final VoidCallback? onTap;

  const _EndpointTile({
    required this.sigil,
    required this.nodeNum,
    required this.name,
    required this.trait,
    required this.isOnline,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          HapticFeedback.selectionClick();
          onTap!();
        }
      },
      child: Column(
        children: [
          // Sigil with online indicator
          Stack(
            children: [
              SigilAvatar(sigil: sigil, nodeNum: nodeNum, size: 44),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.card, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Name
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          // Hex ID
          Text(
            '!${nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}',
            style: TextStyle(
              fontSize: 9,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: 4),
          // Trait badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: trait.primary.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              trait.primary.displayLabel,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: trait.primary.color,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(height: 4),
            Text(
              'View profile',
              style: TextStyle(
                fontSize: 9,
                color: context.accentColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Stat Cell
// =============================================================================

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: context.textTertiary),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
