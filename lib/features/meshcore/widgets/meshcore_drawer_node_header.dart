// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/node_avatar.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_providers.dart';
import 'meshcore_sigil_avatar.dart';

/// Node info header for the MeshCore drawer that shows current node
/// details: sigil avatar, name, node ID, and connection status chip.
///
/// Counterpart to [DrawerNodeHeader] in
/// `lib/features/navigation/widgets/drawer_node_header.dart`. Mirrors
/// Meshtastic's layout: name on row one, node ID + status chip on row
/// two. The avatar is a pubkey-seeded sigil when SelfInfo is available
/// (D-S3); falls back to the initials [NodeAvatar] before identify
/// completes.
///
/// [onSelfTap] is invoked when the sigil is tapped. Pass a callback
/// that opens the MeshCore device sheet (the "this is me" surface,
/// analogous to Meshtastic's NodeDexDetailScreen of self). When null,
/// the avatar is non-interactive.
class MeshCoreDrawerNodeHeader extends ConsumerWidget {
  final VoidCallback? onSelfTap;

  const MeshCoreDrawerNodeHeader({super.key, this.onSelfTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final linkStatus = ref.watch(linkStatusProvider);
    final selfInfo = ref.watch(meshCoreSelfInfoProvider);
    final isConnected = linkStatus.isConnected;

    final nodeName = selfInfo.selfInfo?.nodeName.isNotEmpty == true
        ? selfInfo.selfInfo!.nodeName
        : linkStatus.deviceName ??
              context.l10n.meshcoreShellDefaultDeviceNameFull;

    final nodeId = selfInfo.selfInfo != null
        ? '#${selfInfo.selfInfo!.pubKey.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase()}'
        : '';

    final pubKey = selfInfo.selfInfo?.pubKey;
    final hasSigilKey = pubKey != null && pubKey.length >= 4;

    final initials = nodeName.length >= 2
        ? nodeName.substring(0, 2).toUpperCase()
        : context.l10n.meshcoreShellDefaultInitials;

    final statusBadge = Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: isConnected ? AppTheme.successGreen : AppTheme.errorRed,
        shape: BoxShape.circle,
        border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
      ),
    );

    final Widget avatar = hasSigilKey
        ? MeshCoreSigilAvatar(
            pubKey: pubKey,
            size: 56,
            badge: statusBadge,
            onTap: onSelfTap,
          )
        : NodeAvatar(
            text: initials,
            color: isConnected ? accentColor : theme.dividerColor,
            size: 56,
            showOnlineIndicator: true,
            onlineStatus: isConnected
                ? OnlineStatus.online
                : OnlineStatus.offline,
            border: isConnected
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  )
                : null,
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing20, 20, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatar,
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nodeName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontFamily,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.spacing4),
                Row(
                  children: [
                    if (nodeId.isNotEmpty)
                      Text(
                        nodeId,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: AppTheme.fontFamily,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    if (nodeId.isNotEmpty)
                      const SizedBox(width: AppTheme.spacing8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isConnected
                            ? AppTheme.successGreen.withValues(alpha: 0.15)
                            : AppTheme.errorRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? AppTheme.successGreen
                                  : AppTheme.errorRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing4),
                          Text(
                            isConnected
                                ? context.l10n.meshcoreShellStatusOnline
                                : context.l10n.meshcoreShellStatusOffline,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              fontFamily: AppTheme.fontFamily,
                              color: isConnected
                                  ? AppTheme.successGreen
                                  : AppTheme.errorRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
