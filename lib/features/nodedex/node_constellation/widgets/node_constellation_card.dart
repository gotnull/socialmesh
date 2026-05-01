// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Card used inside the NodeDex Constellation timeline. Visual
// language is the Activity-Timeline / Microdose-Tasks family: calm,
// breathable, type signalled by the spine dot rather than a
// redundant icon-in-rounded-square inside each card body.
//
// Two density modes:
//   * hero=true  — centre identity card pinned at the top; renders
//                  the procedural sigil avatar and richer InfoTable.
//   * hero=false — full-width timeline-row card.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/info_table.dart';
import '../../widgets/sigil_painter.dart';
import '../node_constellation_models.dart';

/// One constellation card. Pass [hero] for the centre identity card.
/// When [hero] is true, [centerNodeNum] is used to render the
/// procedural sigil avatar in the header so the centre identity feels
/// like the gravitational anchor of the timeline.
class NodeConstellationCard extends StatelessWidget {
  final NodeDexGraphNode node;
  final bool hero;
  final int? centerNodeNum;
  final void Function(NodeDexGraphNode node)? onTap;

  const NodeConstellationCard({
    super.key,
    required this.node,
    this.hero = false,
    this.centerNodeNum,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = nodeAccentColor(context, node);
    final inferred = node.confidence == NodeDexGraphConfidence.low;
    final isAction = node.type == NodeDexGraphNodeType.action;

    final body = hero
        ? _buildHeroBody(context, accent, inferred)
        : (isAction
              ? _buildActionBody(context, accent)
              : _buildTimelineBody(context, accent, inferred));

    // Panel-reference card: soft rounded radius20, generous padding,
    // calm dark surface with a barely-there accent tint, no left
    // stripe (the section-header above the body carries the colour).
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius20),
      child: Container(
        decoration: BoxDecoration(
          color: context.card.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(AppTheme.radius20),
          border: Border.all(
            color: inferred
                ? context.border.withValues(alpha: 0.3)
                : context.border.withValues(alpha: 0.55),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing18,
          AppTheme.spacing16,
          AppTheme.spacing18,
          AppTheme.spacing18,
        ),
        child: body,
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!(node);
      },
      child: card,
    );
  }

  Widget _buildHeroBody(BuildContext context, Color accent, bool inferred) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (centerNodeNum != null)
          SigilAvatar(nodeNum: centerNodeNum, size: 56)
        else
          _IconBadge(accent: accent, icon: _iconForType(node.type, false)),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                node.label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                  height: 1.2,
                ),
                softWrap: true,
              ),
              if (node.subtitle != null && node.subtitle!.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  node.subtitle!,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textTertiary,
                    fontFamily: AppTheme.fontFamily,
                    height: 1.3,
                  ),
                ),
              ],
              if (node.details.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacing12),
                InfoTable(
                  rows: node.details
                      .map((d) => InfoTableRow(label: d.label, value: d.value))
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Standard timeline row: title-led, tag pill + meta below,
  /// optional info-table for richer types (encounter / route /
  /// telemetry).
  Widget _buildTimelineBody(BuildContext context, Color accent, bool inferred) {
    final l10n = context.l10n;
    final mqtt = node.viaMqtt;
    final title = _localizedLabel(context, node);
    final isRoute = node.type == NodeDexGraphNodeType.routeEvidence;
    final metaText = <String>[
      if (node.subtitle != null && node.subtitle!.isNotEmpty) node.subtitle!,
      if (node.timestamp != null) _formatRelative(node.timestamp!),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section caption — uppercase, letterspaced, accent dot.
        // Mirrors the "Color Theme" / "App Color" / "PORTFOLIO VALUE"
        // captions in the references.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.55),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            Expanded(
              child: Text(
                _captionForType(context, node.type),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.textTertiary,
                  letterSpacing: 1.2,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
            if (isRoute)
              _MetaPill(
                label: mqtt ? 'MQTT' : 'RF',
                color: accent,
                filled: true,
              ),
            if (inferred) ...[
              const SizedBox(width: AppTheme.spacing6),
              _MetaPill(
                label: l10n.nodedexConstellationFilterShowInferred,
                color: context.textTertiary,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppTheme.spacing10),
        // Title — bold, large, panel-style.
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: inferred ? context.textTertiary : context.textPrimary,
            fontFamily: AppTheme.fontFamily,
            height: 1.2,
          ),
          softWrap: true,
        ),
        if (metaText.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing4),
          Text(
            metaText,
            style: TextStyle(
              fontSize: 13,
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
              height: 1.3,
            ),
          ),
        ],
        if (node.details.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing14),
          InfoTable(
            rows: node.details
                .map((d) => InfoTableRow(label: d.label, value: d.value))
                .toList(growable: false),
          ),
        ],
      ],
    );
  }

  String _captionForType(BuildContext context, NodeDexGraphNodeType type) {
    final l10n = context.l10n;
    switch (type) {
      case NodeDexGraphNodeType.identity:
        return 'IDENTITY';
      case NodeDexGraphNodeType.encounter:
        return l10n.nodedexConstellationCardEncounters.toUpperCase();
      case NodeDexGraphNodeType.routeEvidence:
        return 'PATH';
      case NodeDexGraphNodeType.channel:
        return l10n.nodedexConstellationCardChannel.toUpperCase();
      case NodeDexGraphNodeType.telemetry:
        return l10n.nodedexConstellationCardTelemetry.toUpperCase();
      case NodeDexGraphNodeType.message:
        return l10n.nodedexConstellationCardMessages.toUpperCase();
      case NodeDexGraphNodeType.action:
        return 'ACTION';
      case NodeDexGraphNodeType.group:
        return 'GROUP';
    }
  }

  /// Action card collapses to a single line: label on the left, an
  /// accent-tinted arrow on the right. Same visual rhythm as the
  /// reference Activity-Timeline list rows.
  Widget _buildActionBody(BuildContext context, Color accent) {
    return Row(
      children: [
        _IconBadge(
          accent: accent,
          icon: _iconForAction(node.action) ?? Icons.bolt_outlined,
          size: 28,
        ),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: Text(
            _localizedLabel(context, node),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
              fontFamily: AppTheme.fontFamily,
              height: 1.2,
            ),
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: accent.withValues(alpha: 0.85),
        ),
      ],
    );
  }

  IconData _iconForType(NodeDexGraphNodeType type, bool mqtt) {
    switch (type) {
      case NodeDexGraphNodeType.identity:
        return Icons.hexagon_outlined;
      case NodeDexGraphNodeType.encounter:
        return Icons.history_toggle_off_outlined;
      case NodeDexGraphNodeType.routeEvidence:
        return mqtt ? Icons.cloud_outlined : Icons.cell_tower_outlined;
      case NodeDexGraphNodeType.channel:
        return Icons.tag_outlined;
      case NodeDexGraphNodeType.telemetry:
        return Icons.bar_chart_outlined;
      case NodeDexGraphNodeType.message:
        return Icons.forum_outlined;
      case NodeDexGraphNodeType.action:
        return _iconForAction(node.action) ?? Icons.bolt_outlined;
      case NodeDexGraphNodeType.group:
        return Icons.group_work_outlined;
    }
  }

  IconData? _iconForAction(NodeDexGraphAction? a) {
    if (a == null) return null;
    switch (a) {
      case NodeDexGraphAction.message:
        return Icons.forum_outlined;
      case NodeDexGraphAction.toggleFavourite:
        return Icons.star_outline_rounded;
      case NodeDexGraphAction.viewOnMap:
        return Icons.map_outlined;
      case NodeDexGraphAction.inspectDetails:
        return Icons.search_outlined;
    }
  }

  String _localizedLabel(BuildContext context, NodeDexGraphNode node) {
    final l10n = context.l10n;
    switch (node.type) {
      case NodeDexGraphNodeType.identity:
        return node.label;
      case NodeDexGraphNodeType.encounter:
        return l10n.nodedexConstellationCardEncounters;
      case NodeDexGraphNodeType.routeEvidence:
        return node.viaMqtt
            ? l10n.nodedexConstellationCardRouteMqtt
            : l10n.nodedexConstellationCardRouteRf;
      case NodeDexGraphNodeType.channel:
        return node.label;
      case NodeDexGraphNodeType.telemetry:
        return l10n.nodedexConstellationCardTelemetry;
      case NodeDexGraphNodeType.message:
        return l10n.nodedexConstellationCardMessages;
      case NodeDexGraphNodeType.action:
        return _localizedActionLabel(context, node);
      case NodeDexGraphNodeType.group:
        return node.label;
    }
  }

  String _localizedActionLabel(BuildContext context, NodeDexGraphNode node) {
    final l10n = context.l10n;
    switch (node.action) {
      case NodeDexGraphAction.message:
        return l10n.nodedexConstellationActionMessage;
      case NodeDexGraphAction.toggleFavourite:
        return l10n.nodedexConstellationActionFavourite;
      case NodeDexGraphAction.viewOnMap:
        return l10n.nodedexConstellationActionMap;
      case NodeDexGraphAction.inspectDetails:
        return l10n.nodedexConstellationActionDetails;
      case null:
        return node.label;
    }
  }
}

/// Per-type accent color. Exposed at the file scope so the spine
/// dot in the screen layer can match the colour of the card it
/// connects to without duplicating the table.
Color nodeAccentColor(BuildContext context, NodeDexGraphNode node) {
  if (node.centered) return context.accentColor;
  switch (node.type) {
    case NodeDexGraphNodeType.identity:
      return context.accentColor;
    case NodeDexGraphNodeType.encounter:
      return const Color(0xFF7C9CFF);
    case NodeDexGraphNodeType.routeEvidence:
      return node.viaMqtt ? const Color(0xFFFFA875) : const Color(0xFF59E0B7);
    case NodeDexGraphNodeType.channel:
      return const Color(0xFFB388FF);
    case NodeDexGraphNodeType.telemetry:
      return const Color(0xFF82B1FF);
    case NodeDexGraphNodeType.message:
      return const Color(0xFFFFD180);
    case NodeDexGraphNodeType.action:
      return context.accentColor;
    case NodeDexGraphNodeType.group:
      return context.textTertiary;
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final double size;

  const _IconBadge({required this.icon, required this.accent, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Icon(icon, size: size * 0.5, color: accent),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const _MetaPill({
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: 0.22)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius6),
        border: filled
            ? Border.all(color: color.withValues(alpha: 0.45), width: 0.8)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.6,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}

String _formatRelative(DateTime ts) {
  final now = DateTime.now();
  final diff = now.difference(ts);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}
