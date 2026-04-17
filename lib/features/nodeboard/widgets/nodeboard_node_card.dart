// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeDex bridge card: a "NODEBOARD" section card matching the NodeDex
// detail screen's card pattern. Watches nodeBoardSummaryForNodeProvider
// and renders nothing when the node has no associated board.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../providers/nodeboard_providers.dart';
import '../screens/nodeboard_screen.dart';
import 'nodeboard_card_container.dart';

class NodeBoardNodeCard extends ConsumerWidget {
  /// The node hex ID used to look up the board (matches
  /// `node_boards.owner_node_id` on the backend).
  final String nodeId;

  const NodeBoardNodeCard({super.key, required this.nodeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(nodeBoardSummaryForNodeProvider(nodeId));

    return summaryAsync.when(
      data: (summary) {
        if (summary == null) return const SizedBox.shrink();
        return NodeBoardCardContainer(
          title: 'NodeBoard', // lint-allow: hardcoded-string
          icon: Icons.dashboard_outlined,
          trailing: _VisitButton(
            onTap: () {
              AppLogging.nodeBoard(
                'NodeDex bridge: opening board nodeId=$nodeId slug=${summary.slug}',
              );
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NodeBoardScreen(slug: summary.slug),
                ),
              );
            },
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + sysop
              Text(
                summary.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                  letterSpacing: 0.2,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: AppTheme.spacing4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.person_outline,
                      size: 13,
                      color: context.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing4),
                  Expanded(
                    child: Text(
                      // lint-allow: hardcoded-string
                      'SysOp: ${summary.sysopName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              if (summary.tagline != null && summary.tagline!.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacing10),
                Text(
                  summary.tagline!,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spacing12),
              // Stat chips row
              Wrap(
                spacing: AppTheme.spacing8,
                runSpacing: AppTheme.spacing8,
                children: [
                  NodeBoardStatChip(
                    icon: Icons.forum_outlined,
                    // lint-allow: hardcoded-string
                    label: '${summary.stats.threadCount} threads',
                  ),
                  NodeBoardStatChip(
                    icon: Icons.mode_comment_outlined,
                    // lint-allow: hardcoded-string
                    label: '${summary.stats.replyCount} replies',
                  ),
                  NodeBoardStatChip(
                    icon: Icons.view_list_outlined,
                    // lint-allow: hardcoded-string
                    label: '${summary.stats.sectionCount} sections',
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _VisitButton extends StatelessWidget {
  final VoidCallback onTap;

  const _VisitButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return Material(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppTheme.radius20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing10,
            vertical: AppTheme.spacing4,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius20),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Visit', // lint-allow: hardcoded-string
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: AppTheme.spacing4),
              Icon(Icons.arrow_forward, size: 12, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
