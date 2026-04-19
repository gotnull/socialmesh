// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../services/tak/providers/tak_bridge_providers.dart';

/// Card displaying TAK bridge statistics.
class TakBridgeStatusCard extends ConsumerWidget {
  const TakBridgeStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(takBridgeStatusProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  l10n.takBridgeStatsTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: status.isRunning
                        ? SemanticColors.success.withValues(alpha: 0.2)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Text(
                    status.isRunning
                        ? l10n.takBridgeStatusRunning
                        : l10n.takBridgeStatusStopped,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: status.isRunning
                          ? SemanticColors.success
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: l10n.takBridgePacketsInbound,
                    value: '${status.packetsInbound}',
                    icon: Icons.arrow_downward,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: _StatItem(
                    label: l10n.takBridgePacketsOutbound,
                    value: '${status.packetsOutbound}',
                    icon: Icons.arrow_upward,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: _StatItem(
                    label: l10n.takBridgeClientsTitle,
                    value: '${status.connectedClientCount}',
                    icon: Icons.devices,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
