// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../services/protocol/sip/mrrp_advert_engine.dart';

import 'mrrp_service_tile.dart';

/// Tile showing a discovered MRRP peer with expandable service details.
class MrrpPeerTile extends StatelessWidget {
  final int nodeId;
  final List<MrrpCachedService> services;
  final String? sipPersonaHint;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onRefreshDirectory;
  final VoidCallback onTestRequest;

  const MrrpPeerTile({
    required this.nodeId,
    required this.services,
    this.sipPersonaHint,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onRefreshDirectory,
    required this.onTestRequest,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nodeHex =
        '0x${nodeId.toRadixString(16).padLeft(8, '0').toUpperCase()}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              onTap: onToggleExpand,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                child: Row(
                  children: [
                    Icon(Icons.router, size: 24, color: context.accentColor),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sipPersonaHint ?? nodeHex,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: AppTheme.spacing2),
                          Text(
                            l10n.mrrpHarnessPeerServices(services.length),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: context.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              const Divider(height: 1),
              // Service list
              ...services.map(
                (svc) => MrrpServiceTile(
                  descriptor: svc.descriptor,
                  cachedAt: svc.cachedAt,
                  isExpired: svc.isExpired,
                ),
              ),
              // Action buttons
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onRefreshDirectory,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(l10n.mrrpHarnessRefreshDirectory),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onTestRequest,
                        icon: const Icon(Icons.send, size: 18),
                        label: Text(l10n.mrrpHarnessTestRequest),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
