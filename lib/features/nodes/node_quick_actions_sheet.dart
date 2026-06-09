// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/node_avatar.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../providers/countdown_providers.dart';
import '../../providers/presence_providers.dart';
import '../../utils/presence_utils.dart';
import '../nodedex/screens/nodedex_detail_screen.dart';
import 'node_actions.dart';
import 'node_detail_screen.dart';

/// Actions exposed by the shared node long-press quick action sheet.
///
/// Used by Messages > Contacts and the primary Nodes tab. The same
/// pattern as channels long-press: AppBottomSheet.showActions wired to
/// existing providers and services so there's no parallel local state.
enum NodeQuickAction {
  viewDetails,
  viewInNodeDex,
  favorite,
  mute,
  traceroute,
  disconnect,
}

/// Shows the long-press quick-action sheet for [node].
///
/// [isMyNode] controls whether the destructive "Disconnect device" entry
/// is appended (only meaningful for the user's own node tile).
/// [onDisconnect] is invoked when the user picks Disconnect; the caller
/// owns the actual transport teardown because that lives on the
/// nodes-screen state.
Future<void> showNodeQuickActionsSheet(
  BuildContext context,
  WidgetRef ref,
  MeshNode node, {
  bool isMyNode = false,
  VoidCallback? onDisconnect,
}) async {
  HapticFeedback.mediumImpact();

  final presence =
      ref.read(presenceMapProvider)[node.nodeNum]?.confidence ??
      PresenceConfidence.unknown;
  final lastHeardAge = node.lastHeard != null
      ? DateTime.now().difference(node.lastHeard!)
      : null;
  final subtitle = isMyNode
      ? context.l10n.nodesScreenConnectedDevice
      : presenceStatusText(presence, lastHeardAge);

  final cooldownRemaining = ref
      .read(countdownProvider.notifier)
      .globalTracerouteRemaining;

  AppLogging.nodes(
    '[QuickActions] sheet opened nodeNum=${node.nodeNum} '
    'isMyNode=$isMyNode cooldownRemaining=${cooldownRemaining}s',
  );

  final actions = <BottomSheetAction<NodeQuickAction>>[
    BottomSheetAction(
      icon: Icons.info_outline,
      label: context.l10n.quickActionViewDetails,
      value: NodeQuickAction.viewDetails,
    ),
    BottomSheetAction(
      icon: Icons.auto_awesome,
      label: context.l10n.quickActionViewInNodeDex,
      value: NodeQuickAction.viewInNodeDex,
    ),
    BottomSheetAction(
      icon: node.isFavorite ? Icons.star : Icons.star_border,
      iconColor: node.isFavorite ? AppTheme.warningYellow : null,
      label: node.isFavorite
          ? context.l10n.quickActionUnfavorite
          : context.l10n.quickActionFavorite,
      value: NodeQuickAction.favorite,
    ),
    BottomSheetAction(
      icon: node.isIgnored
          ? Icons.notifications_off
          : Icons.notifications_active,
      label: node.isIgnored
          ? context.l10n.quickActionUnmute
          : context.l10n.quickActionMute,
      value: NodeQuickAction.mute,
    ),
    BottomSheetAction(
      icon: Icons.route,
      label: context.l10n.quickActionSendTraceroute,
      value: NodeQuickAction.traceroute,
      enabled: cooldownRemaining == 0,
      subtitle: cooldownRemaining > 0
          ? context.l10n.quickActionTracerouteCooldown(cooldownRemaining)
          : null,
    ),
    if (isMyNode && onDisconnect != null)
      BottomSheetAction(
        icon: Icons.link_off_rounded,
        label: context.l10n.quickActionDisconnect,
        value: NodeQuickAction.disconnect,
        isDestructive: true,
      ),
  ];

  final result = await AppBottomSheet.showActions<NodeQuickAction>(
    context: context,
    actions: actions,
    header: _NodeQuickActionsHeader(node: node, subtitle: subtitle),
  );

  if (result == null || !context.mounted) {
    AppLogging.nodes(
      '[QuickActions] dismissed without action nodeNum=${node.nodeNum}',
    );
    return;
  }

  AppLogging.nodes(
    '[QuickActions] action=${result.name} nodeNum=${node.nodeNum}',
  );

  switch (result) {
    case NodeQuickAction.viewDetails:
      showNodeDetails(context, node, isMyNode);
    case NodeQuickAction.viewInNodeDex:
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => NodeDexDetailScreen(nodeNum: node.nodeNum),
        ),
      );
    case NodeQuickAction.favorite:
      await toggleNodeFavorite(context, ref, node);
    case NodeQuickAction.mute:
      await toggleNodeMute(context, ref, node);
    case NodeQuickAction.traceroute:
      await sendNodeTraceroute(context, ref, node);
    case NodeQuickAction.disconnect:
      onDisconnect?.call();
  }
}

/// Header for the node quick-action sheet. Mirrors BottomSheetHeader's
/// row layout but uses NodeAvatar so the SocialMesh node identity
/// remains visible in the sheet.
class _NodeQuickActionsHeader extends StatelessWidget {
  final MeshNode node;
  final String subtitle;

  const _NodeQuickActionsHeader({required this.node, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NodeAvatar(text: node.avatarName, color: context.accentColor, size: 48),
        const SizedBox(width: AppTheme.spacing16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                node.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTheme.spacing4),
              Text(
                subtitle.isEmpty
                    ? context.l10n.quickActionSubtitleNodeNum(
                        node.nodeNum.toRadixString(16),
                      )
                    : subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
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
