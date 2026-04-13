// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:socialmesh/features/nodes/node_display_name_resolver.dart';

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

import '../../../utils/time_format.dart';

import '../../../core/l10n/l10n_extension.dart';
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

  /// Optional relationship override from the row that opened the sheet.
  ///
  /// When present, this keeps the sheet aligned with the exact co-seen
  /// evidence already shown in the UI instead of falling back to the raw
  /// historical edge map.
  final CoSeenRelationship? relationship;

  /// Callback when the user taps an endpoint to navigate to its detail.
  final ValueChanged<int>? onOpenNodeDetail;

  const EdgeDetailSheet({
    super.key,
    required this.fromNodeNum,
    required this.toNodeNum,
    this.relationship,
    this.onOpenNodeDetail,
  });

  /// Show the edge detail sheet as a modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required int fromNodeNum,
    required int toNodeNum,
    CoSeenRelationship? relationship,
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
        relationship: relationship,
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
    final resolvedRelationship =
        relationship ??
        fromEntry?.coSeenNodes[toNodeNum] ??
        toEntry?.coSeenNodes[fromNodeNum];

    if (resolvedRelationship == null) {
      AppLogging.nodeDex(
        'Edge detail: no relationship found between $fromNodeNum and $toNodeNum',
      );
      return _buildNoRelationship(context);
    }

    AppLogging.nodeDex(
      'Edge detail loaded: co-seen ${resolvedRelationship.count} times, '
      'messages: ${resolvedRelationship.messageCount}, '
      'first: ${resolvedRelationship.firstSeen}, '
      'last: ${resolvedRelationship.lastSeen}',
    );

    final fromSigil = fromEntry?.sigil ?? SigilGenerator.generate(fromNodeNum);
    final toSigil = toEntry?.sigil ?? SigilGenerator.generate(toNodeNum);
    final fromName =
        fromEntry?.localNickname ??
        fromNode?.displayName ??
        fromEntry?.lastKnownName ??
        _hexName(fromNodeNum);
    final toName =
        toEntry?.localNickname ??
        toNode?.displayName ??
        toEntry?.lastKnownName ??
        _hexName(toNodeNum);

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

        const SizedBox(height: AppTheme.spacing20),

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

        const SizedBox(height: AppTheme.spacing20),

        // Strength indicator
        _buildStrengthIndicator(context, resolvedRelationship, blendedColor),

        const SizedBox(height: AppTheme.spacing16),

        // Stats grid
        _buildStatsGrid(context, resolvedRelationship, blendedColor),

        const SizedBox(height: AppTheme.spacing16),

        // Timeline
        _buildTimeline(context, resolvedRelationship, blendedColor),

        // Message activity section (if any messages)
        if (resolvedRelationship.messageCount > 0) ...[
          const SizedBox(height: AppTheme.spacing16),
          _buildMessageActivity(context, resolvedRelationship, blendedColor),
        ],

        const SizedBox(height: AppTheme.spacing8),
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
        const SizedBox(height: AppTheme.spacing12),
        Text(
          context.l10n.nodedexNoRelationshipDataTitle,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing6),
        Text(
          context.l10n.nodedexNoRelationshipDataDescription,
          style: TextStyle(fontSize: 13, color: context.textTertiary),
        ),
        const SizedBox(height: AppTheme.spacing16),
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
        const SizedBox(width: AppTheme.spacing14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.nodedexConstellationLinkTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const SizedBox(height: AppTheme.spacing2),
              Text(
                context.l10n.nodedexCoSeenRelationshipDetails,
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
      padding: const EdgeInsets.all(AppTheme.spacing14),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.radius14),
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
    final strength = _strengthLabel(context, relationship.count);
    final strengthFraction = _strengthFraction(relationship.count);
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.signal_cellular_alt, size: 14, color: accent),
            const SizedBox(width: AppTheme.spacing6),
            Text(
              context.l10n.nodedexLinkStrengthLabel,
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
                borderRadius: BorderRadius.circular(AppTheme.radius8),
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
        const SizedBox(height: AppTheme.spacing8),
        // Strength bar
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.06,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radius3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: strengthFraction,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withValues(alpha: 0.6), accent],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radius3),
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
      padding: const EdgeInsets.all(AppTheme.spacing14),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.radius14),
        border: Border.all(color: context.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  icon: Icons.visibility_outlined,
                  label: context.l10n.nodedexStatCoSeen,
                  value: '${relationship.count}x',
                  color: accent,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: _StatCell(
                  icon: Icons.chat_bubble_outline,
                  label: context.l10n.nodedexStatMessages,
                  value: '${relationship.messageCount}',
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  icon: Icons.calendar_today_outlined,
                  label: context.l10n.nodedexStatFirstLink,
                  value: dateFormat.format(relationship.firstSeen),
                  color: accent,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: _StatCell(
                  icon: Icons.schedule_outlined,
                  label: context.l10n.nodedexStatLastSeen,
                  value: _formatRelativeTime(
                    context,
                    relationship.timeSinceLastSeen,
                  ),
                  color: accent,
                ),
              ),
            ],
          ),
          if (relationship.relationshipAge.inHours >= 1) ...[
            const SizedBox(height: AppTheme.spacing12),
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    icon: Icons.timelapse_outlined,
                    label: context.l10n.nodedexStatDuration,
                    value: _formatDuration(
                      context,
                      relationship.relationshipAge,
                    ),
                    color: accent,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
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
    final dateFormat = AppTimeFormat.withDatePrefix(context, 'd MMM yyyy,');
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timeline, size: 14, color: accent),
            const SizedBox(width: AppTheme.spacing6),
            Text(
              context.l10n.nodedexRelationshipTimeline,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing10),
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
                    const SizedBox(width: AppTheme.spacing6),
                    Text(
                      context.l10n.nodedexTimelineFirst,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing3),
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
                    borderRadius: BorderRadius.circular(AppTheme.radius1),
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
                      context.l10n.nodedexTimelineLatest,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.textTertiary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing6),
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
                const SizedBox(height: AppTheme.spacing3),
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
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Text(
                  context.l10n.nodedexLinkedForDuration(
                    _formatDuration(context, relationship.relationshipAge),
                  ),
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
      padding: const EdgeInsets.all(AppTheme.spacing14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radius14),
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
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.nodedexMessageActivity,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  context.l10n.nodedexMessagesExchangedCoPresent(
                    relationship.messageCount,
                  ),
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
                  context.l10n.nodedexPerDay,
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
    return NodeDisplayNameResolver.defaultName(nodeNum);
  }

  String _strengthLabel(BuildContext context, int count) {
    final l10n = context.l10n;
    if (count >= 25) return l10n.nodedexStrengthVeryStrong;
    if (count >= 10) return l10n.nodedexStrengthStrong;
    if (count >= 5) return l10n.nodedexStrengthModerate;
    if (count >= 2) return l10n.nodedexStrengthEmerging;
    return l10n.nodedexStrengthNew;
  }

  double _strengthFraction(int count) {
    // Log-scale: 1→0.1, 5→0.4, 10→0.6, 25→0.85, 50+→1.0
    if (count <= 0) return 0.0;
    if (count >= 50) return 1.0;
    // ln(50) ≈ 3.912
    return (math.log(count) / math.log(50)).clamp(0.05, 1.0);
  }

  String _formatRelativeTime(BuildContext context, Duration duration) {
    final l10n = context.l10n;
    if (duration.inMinutes < 1) return l10n.nodedexRelativeJustNow;
    if (duration.inMinutes < 60) {
      return l10n.nodedexRelativeMinutesAgo(duration.inMinutes);
    }
    if (duration.inHours < 24) {
      return l10n.nodedexRelativeHoursAgo(duration.inHours);
    }
    if (duration.inDays < 30) {
      return l10n.nodedexRelativeDaysAgo(duration.inDays);
    }
    return l10n.nodedexRelativeMonthsAgo((duration.inDays / 30).floor());
  }

  String _formatDuration(BuildContext context, Duration duration) {
    final l10n = context.l10n;
    if (duration.inDays >= 365) {
      final years = duration.inDays ~/ 365;
      final months = (duration.inDays % 365) ~/ 30;
      if (months > 0) return l10n.nodedexDurationYearsMonths(years, months);
      return l10n.nodedexDurationYears(years);
    }
    if (duration.inDays >= 30) {
      final months = duration.inDays ~/ 30;
      final days = duration.inDays % 30;
      if (days > 0) return l10n.nodedexDurationMonthsDays(months, days);
      return l10n.nodedexDurationMonths(months);
    }
    if (duration.inDays >= 1) return l10n.nodedexDurationDays(duration.inDays);
    if (duration.inHours >= 1) {
      return l10n.nodedexDurationHours(duration.inHours);
    }
    return l10n.nodedexDurationMinutes(duration.inMinutes);
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
          const SizedBox(height: AppTheme.spacing8),
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
          const SizedBox(height: AppTheme.spacing2),
          // Hex ID
          Text(
            '!${nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}',
            style: TextStyle(
              fontSize: 9,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          // Trait badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: trait.primary.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius6),
            ),
            child: Text(
              trait.primary.displayLabel(context.l10n),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: trait.primary.color,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(height: AppTheme.spacing4),
            Text(
              context.l10n.nodedexViewProfile,
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
        const SizedBox(width: AppTheme.spacing6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: context.textTertiary),
              ),
              const SizedBox(height: AppTheme.spacing1),
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
