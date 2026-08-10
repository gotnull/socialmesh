// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/routing/conversation_routes.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/node_avatar.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../providers/countdown_providers.dart';
import '../../providers/presence_providers.dart';
import '../../utils/presence_utils.dart';
import '../../utils/snackbar.dart';
import '../incidents/providers/incident_help_trust_provider.dart';
import '../incidents/screens/help_circle_screen.dart';
import '../map/map_screen.dart';
import '../messaging/messaging_screen.dart';
import '../nodedex/screens/nodedex_detail_screen.dart';
import '../nodedex/widgets/node_group_assign_sheet.dart';
import 'node_actions.dart';
import 'node_detail_screen.dart';

/// Actions exposed by the shared node long-press quick action sheet.
///
/// Used by Messages > Contacts and the primary Nodes tab. The same
/// pattern as channels long-press: AppBottomSheet.showActions wired to
/// existing providers and services so there's no parallel local state.
enum NodeQuickAction {
  viewDetails,
  message,
  showOnMap,
  viewInNodeDex,
  assignGroups,
  favorite,
  mute,
  helpCircle,
  manageHelpCircle,
  traceroute,
  remove,
  disconnect,
}

/// Whether Help Mode is enabled (both Incident Mode flags on).
bool get _helpModeEnabled =>
    AppFeatureFlags.isMeshIncidentsEnabled &&
    AppFeatureFlags.isIncidentHelpRequestEnabled;

/// Whether the Help Circle opt-in action should be offered for a peer.
/// Gated on Help Mode and never offered for the user's own node.
bool _helpCircleActionVisible({required bool isMyNode}) =>
    !isMyNode && _helpModeEnabled;

/// Whether the "Manage Help Circle" entry should be offered. Shown on the
/// user's own-device sheet so the Help Circle screen (and the share-my-code QR)
/// is reachable without an active help request.
bool _manageHelpCircleVisible({required bool isMyNode}) =>
    isMyNode && _helpModeEnabled;

/// Shows the long-press quick-action sheet for [node].
///
/// [isMyNode] controls whether the destructive "Disconnect device" entry
/// is appended (only meaningful for the user's own node tile).
/// [onDisconnect] is invoked when the user picks Disconnect; the caller
/// owns the actual transport teardown because that lives on the
/// nodes-screen state.
/// [showMessageAction] lets the Messages > Contacts caller suppress the
/// "Message" entry, where tapping the tile already opens the chat.
Future<void> showNodeQuickActionsSheet(
  BuildContext context,
  WidgetRef ref,
  MeshNode node, {
  bool isMyNode = false,
  VoidCallback? onDisconnect,
  bool showMessageAction = true,
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
    if (showMessageAction)
      BottomSheetAction(
        icon: Icons.chat_bubble_outline,
        label: context.l10n.nodeDetailMessageButton,
        value: NodeQuickAction.message,
      ),
    if (node.hasPosition)
      BottomSheetAction(
        icon: Icons.map_outlined,
        label: context.l10n.nodeDetailMenuShowOnMap,
        value: NodeQuickAction.showOnMap,
      ),
    BottomSheetAction(
      icon: Icons.auto_awesome,
      label: context.l10n.quickActionViewInNodeDex,
      value: NodeQuickAction.viewInNodeDex,
    ),
    BottomSheetAction(
      icon: Icons.category_outlined,
      label: context.l10n.quickActionAssignGroups,
      value: NodeQuickAction.assignGroups,
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
    if (_helpCircleActionVisible(isMyNode: isMyNode))
      BottomSheetAction(
        icon: ref.read(incidentHelpTrustedIdsProvider).contains(node.nodeNum)
            ? Icons.health_and_safety
            : Icons.health_and_safety_outlined,
        iconColor:
            ref.read(incidentHelpTrustedIdsProvider).contains(node.nodeNum)
            ? AppTheme.successGreen
            : null,
        label: ref.read(incidentHelpTrustedIdsProvider).contains(node.nodeNum)
            ? context.l10n.helpModeCircleRemove
            : context.l10n.helpModeCircleAdd,
        value: NodeQuickAction.helpCircle,
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
    if (_manageHelpCircleVisible(isMyNode: isMyNode))
      BottomSheetAction(
        icon: Icons.health_and_safety_outlined,
        label: context.l10n.helpModeCircleManage,
        value: NodeQuickAction.manageHelpCircle,
      ),
    if (!isMyNode)
      BottomSheetAction(
        icon: Icons.delete_outline,
        label: context.l10n.nodeDetailMenuRemoveNode,
        value: NodeQuickAction.remove,
        isDestructive: true,
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
    case NodeQuickAction.message:
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            type: ConversationType.directMessage,
            nodeNum: node.nodeNum,
            title: node.displayName,
            avatarColor: node.avatarColor,
          ),
          settings: RouteSettings(name: meshtasticDmRouteName(node.nodeNum)),
        ),
      );
    case NodeQuickAction.showOnMap:
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => MapScreen(initialNodeNum: node.nodeNum),
        ),
      );
    case NodeQuickAction.viewInNodeDex:
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => NodeDexDetailScreen(nodeNum: node.nodeNum),
        ),
      );
    case NodeQuickAction.assignGroups:
      await NodeGroupAssignSheet.show(
        context,
        nodeNum: node.nodeNum,
        nodeName: node.displayName,
      );
    case NodeQuickAction.favorite:
      await toggleNodeFavorite(context, ref, node);
    case NodeQuickAction.mute:
      await toggleNodeMute(context, ref, node);
    case NodeQuickAction.helpCircle:
      await _toggleHelpCircle(context, ref, node);
    case NodeQuickAction.manageHelpCircle:
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const HelpCircleScreen()),
      );
    case NodeQuickAction.traceroute:
      await sendNodeTraceroute(context, ref, node);
    case NodeQuickAction.remove:
      await confirmAndRemoveNode(context, ref, node);
    case NodeQuickAction.disconnect:
      onDisconnect?.call();
  }
}

/// Adds or removes [node] from the local Help Circle (Help Mode trust source).
/// Takes effect immediately for the in-memory trust predicate, then persists.
Future<void> _toggleHelpCircle(
  BuildContext context,
  WidgetRef ref,
  MeshNode node,
) async {
  final notifier = ref.read(incidentHelpTrustProvider.notifier);
  final wasTrusted = ref
      .read(incidentHelpTrustedIdsProvider)
      .contains(node.nodeNum);
  final name = node.displayName;

  if (wasTrusted) {
    // Removing trust is destructive (the peer can no longer exchange Help
    // Requests), so confirm before applying.
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.helpModeCircleRemoveConfirmTitle,
      message: context.l10n.helpModeCircleRemoveConfirmBody(name),
      confirmLabel: context.l10n.commonRemove,
      cancelLabel: context.l10n.commonCancel,
      isDestructive: true,
    );
    if (confirmed != true) return;
    await notifier.untrust(node.nodeNum);
    if (!context.mounted) return;
    showSuccessSnackBar(context, context.l10n.helpModeCircleRemovedSnack(name));
    return;
  }

  // Adding grants trust, so confirm first and explain what trust means
  // (manual, local, not channel-based, no precise location, two-way).
  final confirmed = await AppBottomSheet.showConfirm(
    context: context,
    title: context.l10n.helpModeCircleAddConfirmTitle,
    message: context.l10n.helpModeCircleAddConfirmBody,
    confirmLabel: context.l10n.commonAdd,
    cancelLabel: context.l10n.commonCancel,
  );
  if (confirmed != true) return;

  await notifier.trust(
    node.nodeNum,
    displayName: name,
    nowMs: DateTime.now().millisecondsSinceEpoch,
  );
  if (!context.mounted) return;
  showSuccessSnackBar(context, context.l10n.helpModeCircleAddedSnack(name));
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
