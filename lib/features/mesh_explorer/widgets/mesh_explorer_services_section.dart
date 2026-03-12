// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Services section for Mesh Explorer.
///
/// Renders nearby MRRP services as elegant cards using the
/// service presentation catalog to map raw service IDs into
/// public-facing titles, icons, and actions.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../services/protocol/sip/mrrp_types.dart';
import '../models/service_presentation.dart';

/// Display section for nearby MRRP services.
class MeshExplorerServicesSection extends StatelessWidget {
  /// Map of serviceId → peer count offering that service.
  final Map<int, int> services;

  const MeshExplorerServicesSection({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return _EmptyServices();
    }

    // Sort services: known services first, then by peer count descending
    final sorted = services.entries.toList()
      ..sort((a, b) {
        final aKnown = _isKnownService(a.key) ? 0 : 1;
        final bKnown = _isKnownService(b.key) ? 0 : 1;
        final knownCmp = aKnown.compareTo(bKnown);
        if (knownCmp != 0) return knownCmp;
        return b.value.compareTo(a.value);
      });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        children: [
          for (int i = 0; i < sorted.length; i++) ...[
            _ServiceCard(serviceId: sorted[i].key, peerCount: sorted[i].value),
            if (i < sorted.length - 1)
              const SizedBox(height: AppTheme.spacing8),
          ],
        ],
      ),
    );
  }

  bool _isKnownService(int serviceId) {
    return serviceId == MrrpServiceId.boardV1 ||
        serviceId == MrrpServiceId.profileV1 ||
        serviceId == MrrpServiceId.meetupV1;
  }
}

/// Empty state for no nearby services.
class _EmptyServices extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing24,
      ),
      child: Column(
        children: [
          Icon(
            Icons.extension_outlined,
            size: 40,
            color: context.textTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.meshExplorerEmptyServicesTitle,
            style: context.bodyStyle?.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.meshExplorerEmptyServicesBody,
            style: context.bodySmallStyle?.copyWith(
              color: context.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A single service card.
class _ServiceCard extends StatelessWidget {
  final int serviceId;
  final int peerCount;

  const _ServiceCard({required this.serviceId, required this.peerCount});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final presentation = ServicePresentationCatalog.forServiceId(
      serviceId,
      l10n,
    );

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Service icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
            ),
            child: Icon(
              presentation.icon,
              size: 22,
              color: context.accentColor,
            ),
          ),

          const SizedBox(width: AppTheme.spacing12),

          // Title + subtitle + peer count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  presentation.title,
                  style: context.bodyStyle?.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Row(
                  children: [
                    Text(
                      presentation.subtitle,
                      style: context.bodySmallStyle?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      '·',
                      style: context.bodySmallStyle?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      l10n.meshExplorerServicePeerCount(peerCount),
                      style: context.bodySmallStyle?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Privacy indicator
          if (presentation.requiresHandshake || presentation.requiresIdentity)
            Padding(
              padding: const EdgeInsets.only(left: AppTheme.spacing8),
              child: Icon(
                Icons.lock_outline,
                size: 16,
                color: context.textTertiary.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }
}
