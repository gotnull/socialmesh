// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/transport.dart';
import '../../../providers/app_providers.dart';
import '../../nodedex/widgets/tappable_sigil_avatar.dart';

/// Node info header for the drawer — shows current node details
/// including sigil avatar, name, ID, and connection status chip.
class DrawerNodeHeader extends ConsumerWidget {
  const DrawerNodeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final nodes = ref.watch(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    final connectionStateAsync = ref.watch(connectionStateProvider);

    final isConnected = connectionStateAsync.when(
      data: (state) => state == DeviceConnectionState.connected,
      loading: () => false,
      error: (e, s) => false,
    );

    // Get node display info
    final nodeName = myNode?.longName ?? context.l10n.drawerNodeNotConnected;
    final nodeId = myNodeNum != null ? '!${myNodeNum.toRadixString(16)}' : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing20, 20, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Node sigil avatar — matches NodeDex list style. Tap opens
          // self-NodeDex (the canonical "this is me" detail view).
          // Disabled before myNodeNum is known.
          TappableSigilAvatar(
            nodeNum: myNodeNum ?? 0,
            enableTap: myNodeNum != null,
            size: 56,
            badge: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isConnected ? AppTheme.successGreen : AppTheme.errorRed,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          // Node info - flexible column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Node name — full width, no competing chip
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
                // Node ID + connection status chip on same row
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
                                ? context.l10n.drawerNodeOnline
                                : context.l10n.drawerNodeOffline,
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
