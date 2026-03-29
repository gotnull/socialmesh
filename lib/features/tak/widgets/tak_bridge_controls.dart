// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../services/haptic_service.dart';
import '../../../services/tak/providers/tak_bridge_providers.dart';
import 'tak_bridge_status_card.dart';

/// Bridge control section for the TAK settings screen.
class TakBridgeControls extends ConsumerWidget {
  const TakBridgeControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(takBridgeStatusProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SliverList(
      delegate: SliverChildListDelegate([
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing24,
            AppTheme.spacing16,
            AppTheme.spacing8,
          ),
          child: Text(
            l10n.takBridgeSectionTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Enable/disable toggle
        ListTile(
          title: Text(l10n.takBridgeEnableToggle),
          subtitle: Text(l10n.takBridgeEnableSubtitle),
          trailing: ThemedSwitch(
            value: status.isRunning,
            onChanged: (enabled) {
              ref.haptics.buttonTap();
              final bridge = ref.read(takMeshBridgeProvider);
              if (enabled) {
                bridge.start();
              } else {
                bridge.stop();
              }
              // Refresh status immediately instead of waiting for the
              // 5-second polling timer.
              ref.read(takBridgeStatusProvider.notifier).refresh();
            },
          ),
        ),

        // Status card
        if (status.isRunning) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            child: TakBridgeStatusCard(),
          ),
          const SizedBox(height: AppTheme.spacing8),
          // Connected clients count
          ListTile(
            leading: const Icon(Icons.devices),
            title: Text(l10n.takBridgeClientsTitle),
            trailing: Text(
              l10n.takBridgeConnectedClients(status.connectedClientCount),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],

        // Export data package button
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: Text(l10n.takBridgeExportPackage),
          subtitle: Text(l10n.takBridgeExportPackageSubtitle),
          onTap: () {
            ref.haptics.buttonTap();
            // Data package export handled by integration layer.
          },
        ),
      ]),
    );
  }
}
