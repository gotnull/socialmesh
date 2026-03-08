// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Hero summary card for the Mesh Explorer home screen.
///
/// Shows connection state, peer count, and service count in a
/// glanceable card at the top of the screen.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../providers/mesh_explorer_providers.dart';

/// Glanceable hero card showing mesh status summary.
class MeshExplorerHero extends StatelessWidget {
  final MeshExplorerSummary summary;

  const MeshExplorerHero({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(color: context.border.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection status row
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: summary.isConnected
                        ? SemanticColors.success
                        : SemanticColors.disabled,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  summary.isConnected
                      ? l10n.meshExplorerHeroConnected
                      : l10n.meshExplorerHeroDisconnected,
                  style: context.labelStyle?.copyWith(
                    color: summary.isConnected
                        ? SemanticColors.success
                        : context.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            if (summary.isConnected) ...[
              const SizedBox(height: AppTheme.spacing12),
              // Stats row
              Row(
                children: [
                  _StatPill(
                    icon: Icons.people_outline,
                    label: l10n.meshExplorerHeroPeersCount(summary.nearbyPeers),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  _StatPill(
                    icon: Icons.extension_outlined,
                    label: l10n.meshExplorerHeroServicesCount(
                      summary.activeServices,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small stat pill showing an icon and label.
class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: context.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.textTertiary),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            label,
            style: context.bodySmallStyle?.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
