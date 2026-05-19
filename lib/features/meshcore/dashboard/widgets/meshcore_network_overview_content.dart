// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/meshcore_providers.dart';

/// MeshCore-flavoured equivalent of `NetworkOverviewContent` from the
/// Meshtastic dashboard. Same visual shape (three stat tiles separated
/// by vertical dividers, icon + value + label), MeshCore data sources.
//
// Stats:
//   - Status: derived from `linkStatusProvider` (Connected / Disconnected).
//   - Contacts: online (lastSeen < 24h) over total - mirrors how the
//     MeshCore map's stale-fade gates "fresh" contacts.
//   - Channels: total channel count from `meshCoreChannelsProvider`.
class MeshCoreNetworkOverviewContent extends ConsumerWidget {
  const MeshCoreNetworkOverviewContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final linkStatus = ref.watch(linkStatusProvider);
    final contactsState = ref.watch(meshCoreContactsProvider);
    final channelsState = ref.watch(meshCoreChannelsProvider);

    final isConnected = linkStatus.isConnected;
    final now = DateTime.now();
    final totalContacts = contactsState.contacts.length;
    final onlineContacts = contactsState.contacts
        .where((c) => now.difference(c.lastSeen).inHours < 24)
        .length;
    final channelCount = channelsState.channels.length;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: isConnected ? Icons.check_circle : Icons.error_outline,
              iconColor: isConnected ? context.accentColor : AppTheme.errorRed,
              value: isConnected
                  ? l10n.dashboardStatusOnline
                  : l10n.dashboardStatusOffline,
              label: l10n.dashboardStatusLabel,
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _StatItem(
              icon: Icons.people_outline,
              iconColor: context.accentColor,
              value: '$onlineContacts/$totalContacts',
              label: l10n.meshcoreWidgetTotalContacts,
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _StatItem(
              icon: Icons.forum_outlined,
              iconColor: context.accentColor,
              value: channelCount.toString(),
              label: l10n.meshcoreWidgetChannels,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacing10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.radius12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing2),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: context.border.withValues(alpha: 0.5),
    );
  }
}
