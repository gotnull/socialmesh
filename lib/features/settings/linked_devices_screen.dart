import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/auto_scroll_text.dart';
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

class _LinkedDevicesScreenState extends ConsumerState<LinkedDevicesScreen> {
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
      return Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: context.background,
          title: Text(
            'Linked Devices',
            style: TextStyle(color: context.textPrimary),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  size: 64,
                  color: context.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign In Required',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to link your Meshtastic devices to your social profile.',
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final primaryNodeId = currentProfile.value?.primaryNodeId;

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          'Linked Devices',
          style: TextStyle(color: context.textPrimary),
        ),
      ),
      body: linkedNodesAsync.when(
        data: (linkedNodeIds) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(linkedNodeIdsProvider);
            },
            child: CustomScrollView(
              slivers: [
                // Header info
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Link your Meshtastic devices to your profile so others can find and follow you from the nodes list.',
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
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          'Linked Devices',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
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
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.devices_outlined,
                              size: 48,
                              color: context.textTertiary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Linked Devices',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Connect to a Meshtastic device and tap "Link Current Device" above.',
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
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: context.textTertiary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'To link another device, disconnect from your current device and connect to the new one.',
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
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.textTertiary),
              const SizedBox(height: 16),
              Text(
                'Failed to load linked devices',
                style: TextStyle(color: context.textSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.invalidate(linkedNodeIdsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _linkCurrentDevice(int nodeNum) async {
    if (_isLinking) return;

    setState(() => _isLinking = true);

    try {
      await linkNode(ref, nodeNum, setPrimary: true);
      if (mounted) {
        showSuccessSnackBar(context, 'Device linked to your profile');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to link device: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLinking = false);
      }
    }
  }

  Future<void> _setPrimaryNode(int nodeId) async {
    try {
      await setPrimaryNode(ref, nodeId);
      if (mounted) {
        showSuccessSnackBar(context, 'Primary device updated');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to set primary: $e');
      }
    }
  }

  Future<void> _unlinkDevice(int nodeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Unlink Device',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Remove this device from your profile? Others will no longer see your profile when viewing this node.',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _isUnlinking = true);

    try {
      await unlinkNode(ref, nodeId);
      // Reset banner dismissed state so it can show again
      await resetLinkDeviceBannerDismissState();
      if (mounted) {
        showSuccessSnackBar(context, 'Device unlinked');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to unlink: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUnlinking = false);
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AccentColors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AccentColors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AccentColors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.smartphone,
              color: AccentColors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected Device',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
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
                : const Text('Link'),
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

  Color _getNodeColor(int nodeNum) {
    final colors = [
      const Color(0xFF5B4FCE),
      const Color(0xFFD946A6),
      const Color(0xFF3B82F6),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF10B981),
    ];
    return colors[nodeNum % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isPrimary
              ? context.accentColor.withValues(alpha: 0.1)
              : context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary
                ? context.accentColor.withValues(alpha: 0.5)
                : context.border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showOptionsSheet(context),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  NodeAvatar(
                    text: node?.avatarName ?? nodeId.toRadixString(16)[0],
                    color: _getNodeColor(nodeId),
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
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
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.accentColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'PRIMARY',
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: AutoScrollText(
                                node?.longName ??
                                    '!${nodeId.toRadixString(16)}',
                                style: TextStyle(
                                  color: context.textTertiary,
                                  fontSize: 12,
                                  fontFamily: node?.longName != null
                                      ? null
                                      : 'monospace',
                                ),
                              ),
                            ),
                            if (node?.hardwareModel != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '•',
                                style: TextStyle(color: context.textTertiary),
                              ),
                              const SizedBox(width: 8),
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
        label: 'Send Message',
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
          label: 'View on Map',
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
          label: 'Set as Primary',
          subtitle: 'Show this device on your profile',
          onTap: () {
            Navigator.pop(context);
            onSetPrimary();
          },
        ),
      BottomSheetAction(
        icon: Icons.link_off,
        label: 'Unlink Device',
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
