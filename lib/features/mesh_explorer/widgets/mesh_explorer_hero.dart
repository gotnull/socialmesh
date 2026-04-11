// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Compact mesh status strip for the Mesh Explorer home screen.
///
/// Shows connection state, peer count, and service count in a
/// visually subordinate strip at the top — not the main content.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../providers/mesh_explorer_providers.dart';

/// Compact status strip showing mesh connectivity at a glance.
class MeshExplorerStatusStrip extends StatelessWidget {
  final MeshExplorerSummary summary;

  const MeshExplorerStatusStrip({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing4,
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: summary.isConnected
                  ? SemanticColors.success
                  : SemanticColors.disabled,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              summary.isConnected
                  ? l10n.meshExplorerStatusPeersAndServices(
                      summary.nearbyPeers,
                      summary.activeServices,
                    )
                  : l10n.meshExplorerHeroDisconnected,
              style: context.captionStyle?.copyWith(
                color: context.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
