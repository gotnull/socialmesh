// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/node_color.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/auto_scroll_text.dart';
import '../../core/widgets/device_privacy_warning.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/node_avatar.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/social_providers.dart';
import '../../utils/snackbar.dart';
import '../map/map_screen.dart';
import '../messaging/messaging_screen.dart' show ChatScreen, ConversationType;
import '../nodes/widgets/link_device_banner.dart';

/// Screen for managing linked mesh devices on the user's social profile.
class LinkedDevicesScreen extends ConsumerStatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  ConsumerState<LinkedDevicesScreen> createState() =>
      _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends ConsumerState<LinkedDevicesScreen>
    with LifecycleSafeMixin {
  bool _isLinking = false;
  bool _isUnlinking = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final linkedNodesAsync = ref.watch(linkedNodeIdsProvider);
    final allNodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final currentProfile = ref.watch(userProfileProvider);

    if (currentUser == null) {
      return GlassScaffold(
        title: context.l10n.linkedDevicesTitle,
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_circle_outlined,
                      size: 64,
                      color: context.textTertiary,
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    Text(
                      context.l10n.linkedDevicesSignInRequired,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      context.l10n.linkedDevicesSignInBody,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final primaryNodeId = currentProfile.value?.primaryNodeId;

    return GlassScaffold(
      title: context.l10n.linkedDevicesTitle,
      slivers: [
        linkedNodesAsync.when(
          data: (linkedNodeIds) {
            return SliverMainAxisGroup(
              slivers: [
                // Header info
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      decoration: BoxDecoration(
                        color: context.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        border: Border.all(
                          color: context.accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: context.accentColor,
                            size: 24,
                          ),
                          const SizedBox(width: AppTheme.spacing12),
                          Expanded(
                            child: Text(
                              context.l10n.linkedDevicesLinkDescription,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Link current device button
                if (myNodeNum != null && !linkedNodeIds.contains(myNodeNum))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _LinkCurrentDeviceCard(
                        nodeNum: myNodeNum,
                        node: allNodes[myNodeNum],
                        isLinking: _isLinking,
                        onLink: () => _linkCurrentDevice(myNodeNum),
                      ),
                    ),
                  ),

                // Section header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacing16,
                      24,
                      16,
                      8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          context.l10n.linkedDevicesTitle,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius10,
                            ),
                          ),
                          child: Text(
                            linkedNodeIds.length.toString(),
                            style: TextStyle(
                              color: context.accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Linked devices list
                if (linkedNodeIds.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacing32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.devices_outlined,
                              size: 48,
                              color: context.textTertiary,
                            ),
                            const SizedBox(height: AppTheme.spacing16),
                            Text(
                              context.l10n.linkedDevicesNoDevices,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacing8),
                            Text(
                              context.l10n.linkedDevicesNoDevicesBody,
                              style: TextStyle(
                                color: context.textTertiary,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final nodeId = linkedNodeIds[index];
                      final node = allNodes[nodeId];
                      final isPrimary = nodeId == primaryNodeId;

                      return _LinkedDeviceCard(
                        nodeId: nodeId,
                        node: node,
                        isPrimary: isPrimary,
                        isUnlinking: _isUnlinking,
                        onSetPrimary: () => _setPrimaryNode(nodeId),
                        onUnlink: () => _unlinkDevice(nodeId),
                      );
                    }, childCount: linkedNodeIds.length),
                  ),

                // Tip at bottom
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacing16,
                      24,
                      16,
                      32,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacing12),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                        border: Border.all(color: context.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: context.textTertiary,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spacing12),
                          Expanded(
                            child: Text(
                              context.l10n.linkedDevicesLinkAnother,
                              style: TextStyle(
                                color: context.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: context.textTertiary,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    context.l10n.linkedDevicesLoadFailed,
                    style: TextStyle(color: context.textSecondary),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(linkedNodeIdsProvider),
                    child: Text(context.l10n.commonRetry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _linkCurrentDevice(int nodeNum) async {
    if (_isLinking) return;

    // Get node details to check position config
    final nodes = ref.read(nodesProvider);
    final node = nodes[nodeNum];

    if (node == null) {
      if (mounted) {
        showErrorSnackBar(context, context.l10n.linkedDevicesDeviceNotFound);
      }
      return;
    }

    // Check if device shares location based on position config
    final sharesLocation = node.hasPosition;

    final l10n = context.l10n;

    // Show privacy warning before linking
    final action = await DevicePrivacyWarning.show(
      context,
      nodeNum: nodeNum,
      deviceName: node.longName ?? l10n.linkedDevicesUnknownDevice,
      sharesLocation: sharesLocation,
      positionConfig: null, // Position config not available in MeshNode model
    );

    if (action != DevicePrivacyAction.proceed) {
      return;
    }

    safeSetState(() => _isLinking = true);

    try {
      await linkNode(ref, nodeNum, setPrimary: true);
      if (mounted) {
        showSuccessSnackBar(context, l10n.linkedDevicesLinked);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, l10n.linkedDevicesLinkFailed(e.toString()));
      }
    } finally {
      safeSetState(() => _isLinking = false);
    }
  }

  Future<void> _setPrimaryNode(int nodeId) async {
    final l10n = context.l10n;
    try {
      await setPrimaryNode(ref, nodeId);
      if (mounted) {
        showSuccessSnackBar(context, l10n.linkedDevicesPrimaryUpdated);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          l10n.linkedDevicesSetPrimaryFailed(e.toString()),
        );
      }
    }
  }

  Future<void> _unlinkDevice(int nodeId) async {
    AppLogging.settings(
      '🔗 [UnlinkDevice] Starting unlink for nodeId: $nodeId',
    );

    // Capture all the services and data we need BEFORE showing dialog
    // since widget may unmount during dialog due to provider rebuilds
    final socialService = ref.read(socialServiceProvider);
    final userProfileNotifier = ref.read(userProfileProvider.notifier);
    final currentProfile = ref.read(userProfileProvider).value;
    final currentUser = ref.read(currentUserProvider);
    final container = ProviderScope.containerOf(context);

    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.linkedDevicesUnlinkTitle,
      message: l10n.linkedDevicesUnlinkBody,
      confirmLabel: l10n.linkedDevicesUnlinkConfirm,
      isDestructive: true,
    );

    AppLogging.settings(
      '🔗 [UnlinkDevice] Dialog result: confirmed=$confirmed',
    );
    if (confirmed != true) {
      AppLogging.settings(
        '🔗 [UnlinkDevice] User cancelled or dialog dismissed',
      );
      return;
    }

    if (mounted) {
      safeSetState(() => _isUnlinking = true);
    }
    AppLogging.settings(
      '🔗 [UnlinkDevice] Starting unlink operation (mounted=$mounted)...',
    );

    try {
      // Use captured service directly - doesn't rely on widget being mounted
      AppLogging.settings('🔗 [UnlinkDevice] Calling unlinkNodeFromProfile...');
      await socialService.unlinkNodeFromProfile(nodeId);
      AppLogging.settings('🔗 [UnlinkDevice] Firestore unlink completed');

      // Update local profile if we have it
      if (currentProfile != null) {
        final updatedLinkedNodes = [...currentProfile.linkedNodeIds]
          ..remove(nodeId);
        final newPrimaryId = currentProfile.primaryNodeId == nodeId
            ? (updatedLinkedNodes.isNotEmpty ? updatedLinkedNodes.first : null)
            : currentProfile.primaryNodeId;
        AppLogging.settings(
          '🔗 [UnlinkDevice] Updating local profile: '
          'updatedLinkedNodes=$updatedLinkedNodes, newPrimaryId=$newPrimaryId',
        );
        try {
          await userProfileNotifier.updateLinkedNodes(
            updatedLinkedNodes,
            primaryNodeId: newPrimaryId,
            clearPrimaryNodeId: newPrimaryId == null,
          );
          AppLogging.settings(
            '🔗 [UnlinkDevice] Local profile update completed',
          );
        } catch (e) {
          AppLogging.settings(
            '🔗 [UnlinkDevice] Local profile update failed: $e',
          );
          // Don't rethrow - Firestore already updated
        }
      }

      // Invalidate providers using the container (works even if widget unmounted)
      AppLogging.settings(
        '🔗 [UnlinkDevice] Invalidating providers via container...',
      );
      container.invalidate(linkedNodeIdsProvider);
      container.invalidate(isNodeLinkedProvider(nodeId));
      container.invalidate(profileByNodeIdProvider(nodeId));
      if (currentUser != null) {
        container.invalidate(publicProfileProvider(currentUser.uid));
        container.invalidate(publicProfileStreamProvider(currentUser.uid));
      }
      AppLogging.settings('🔗 [UnlinkDevice] Providers invalidated');

      // Reset banner dismissed state for this specific node so it can show again
      await resetLinkDeviceBannerDismissState(nodeId: nodeId);
      AppLogging.settings(
        '🔗 [UnlinkDevice] Banner state reset for node $nodeId',
      );

      if (mounted) {
        showSuccessSnackBar(context, l10n.linkedDevicesUnlinked);
        AppLogging.settings('🔗 [UnlinkDevice] Success snackbar shown');
      }
    } catch (e, stackTrace) {
      AppLogging.settings('🔗 [UnlinkDevice] ERROR: $e');
      AppLogging.settings('🔗 [UnlinkDevice] Stack trace: $stackTrace');
      if (mounted) {
        showErrorSnackBar(
          context,
          l10n.linkedDevicesUnlinkFailed(e.toString()),
        );
      }
    } finally {
      if (mounted) {
        safeSetState(() => _isUnlinking = false);
        AppLogging.settings('🔗 [UnlinkDevice] Unlink operation finished');
      }
    }
  }
}

class _LinkCurrentDeviceCard extends StatelessWidget {
  const _LinkCurrentDeviceCard({
    required this.nodeNum,
    required this.node,
    required this.isLinking,
    required this.onLink,
  });

  final int nodeNum;
  final MeshNode? node;
  final bool isLinking;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AccentColors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: AccentColors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AccentColors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: const Icon(
              Icons.smartphone,
              color: AccentColors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.linkedDevicesConnectedDevice,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  node?.displayName ?? '!${nodeNum.toRadixString(16)}',
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: isLinking ? null : onLink,
            style: FilledButton.styleFrom(
              backgroundColor: AccentColors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: isLinking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(context.l10n.linkedDevicesLinkButton),
          ),
        ],
      ),
    );
  }
}

class _LinkedDeviceCard extends StatelessWidget {
  const _LinkedDeviceCard({
    required this.nodeId,
    required this.node,
    required this.isPrimary,
    required this.isUnlinking,
    required this.onSetPrimary,
    required this.onUnlink,
  });

  final int nodeId;
  final MeshNode? node;
  final bool isPrimary;
  final bool isUnlinking;
  final VoidCallback onSetPrimary;
  final VoidCallback onUnlink;

  Color _getNodeColor(int nodeNum) => nodeColorFromId(nodeNum);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isPrimary
              ? context.accentColor.withValues(alpha: 0.1)
              : context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(
            color: isPrimary
                ? context.accentColor.withValues(alpha: 0.5)
                : context.border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            onTap: () => _showOptionsSheet(context),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              child: Row(
                children: [
                  NodeAvatar(
                    text: node?.avatarName ?? nodeId.toRadixString(16)[0],
                    color: _getNodeColor(nodeId),
                    size: 44,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AutoScrollText(
                                node?.displayName ??
                                    '!${nodeId.toRadixString(16)}',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (isPrimary) ...[
                              const SizedBox(width: AppTheme.spacing8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.accentColor,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius4,
                                  ),
                                ),
                                child: Text(
                                  context.l10n.linkedDevicesPrimaryBadge,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacing4),
                        Row(
                          children: [
                            Text(
                              '!${nodeId.toRadixString(16)}',
                              style: TextStyle(
                                color: context.textTertiary,
                                fontSize: 12,
                                fontFamily: AppTheme.fontFamily,
                              ),
                            ),
                            if (node?.hardwareModel != null) ...[
                              const SizedBox(width: AppTheme.spacing8),
                              Text(
                                '•',
                                style: TextStyle(color: context.textTertiary),
                              ),
                              const SizedBox(width: AppTheme.spacing8),
                              Flexible(
                                child: Text(
                                  node!.hardwareModel!,
                                  style: TextStyle(
                                    color: context.textTertiary,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.more_vert, color: context.textTertiary, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    HapticFeedback.lightImpact();

    final actions = <BottomSheetAction>[
      BottomSheetAction(
        icon: Icons.message_outlined,
        iconColor: context.accentColor,
        label: context.l10n.linkedDevicesSendMessage,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              type: ConversationType.directMessage,
              nodeNum: nodeId,
              title: node?.displayName ?? '!${nodeId.toRadixString(16)}',
            ),
          ),
        ),
      ),
      if (node?.hasPosition == true)
        BottomSheetAction(
          icon: Icons.map_outlined,
          label: context.l10n.linkedDevicesViewOnMap,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MapScreen(initialNodeNum: nodeId),
            ),
          ),
        ),
      if (!isPrimary)
        BottomSheetAction(
          icon: Icons.star_outline,
          iconColor: context.accentColor,
          label: context.l10n.linkedDevicesSetAsPrimary,
          subtitle: context.l10n.linkedDevicesSetAsPrimarySubtitle,
          onTap: () {
            Navigator.pop(context);
            onSetPrimary();
          },
        ),
      BottomSheetAction(
        icon: Icons.link_off,
        label: context.l10n.linkedDevicesUnlinkTitle,
        isDestructive: true,
        onTap: () {
          Navigator.pop(context);
          onUnlink();
        },
      ),
    ];

    AppBottomSheet.showActions(
      context: context,
      header: Text(
        node?.displayName ?? '!${nodeId.toRadixString(16)}',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
        ),
      ),
      actions: actions,
    );
  }
}
