// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
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
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(
            color: context.border.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            BouncyTap(
              onTap: onToggleExpand,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                      child: Icon(
                        Icons.router,
                        size: 20,
                        color: context.accentColor,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sipPersonaHint ?? nodeHex,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing2),
                          Text(
                            l10n.mrrpHarnessPeerServices(services.length),
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  Divider(
                    height: 1,
                    color: context.border.withValues(alpha: 0.3),
                  ),
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
                    padding: const EdgeInsets.all(AppTheme.spacing12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onRefreshDirectory,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: context.accentColor.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius12,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spacing12,
                              ),
                            ),
                            icon: Icon(
                              Icons.refresh,
                              size: 16,
                              color: context.accentColor,
                            ),
                            label: Text(
                              l10n.mrrpHarnessRefreshDirectory,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.accentColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onTestRequest,
                            style: FilledButton.styleFrom(
                              backgroundColor: context.accentColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius12,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spacing12,
                              ),
                            ),
                            icon: const Icon(
                              Icons.send,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: Text(
                              l10n.mrrpHarnessTestRequest,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}
