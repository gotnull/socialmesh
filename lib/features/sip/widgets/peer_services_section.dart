// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Full list of a peer's advertised services, rendered inside the peer
/// detail sheet.
///
/// Uses [`peerServicesFullProvider`] (a pure projection of
/// `mrrpCachedServicesProvider`). No new subscriptions, no new
/// transport. Tapping a service opens the existing
/// `ServiceDetailScreen` — no parallel pipeline.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../providers/sip_hub_services_providers.dart';
import '../../../services/protocol/sip/mrrp_types.dart';

/// Scrollable-free section (parent handles scrolling). Renders nothing
/// when the peer has zero advertised services — the parent decides
/// whether to show an empty-state placeholder.
class PeerServicesSection extends ConsumerWidget {
  final int peerNodeId;

  const PeerServicesSection({super.key, required this.peerNodeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(peerServicesFullProvider(peerNodeId));
    if (services.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
          child: Text(
            context.l10n.sipHubPeerServicesHeader,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
        ),
        for (final svc in services)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing6),
            child: _PeerServiceTile(
              serviceId: svc.descriptor.serviceId,
              versionMajor: svc.descriptor.versionMajor,
              versionMinor: svc.descriptor.versionMinor,
              metadataLen: svc.descriptor.metadata.length,
            ),
          ),
      ],
    );
  }
}

class _PeerServiceTile extends StatelessWidget {
  final int serviceId;
  final int versionMajor;
  final int versionMinor;
  final int metadataLen;

  const _PeerServiceTile({
    required this.serviceId,
    required this.versionMajor,
    required this.versionMinor,
    required this.metadataLen,
  });

  @override
  Widget build(BuildContext context) {
    final name = MrrpServiceId.nameOf(serviceId);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing10,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.hub_outlined,
            size: 18,
            color: context.accentColor.withValues(alpha: 0.7),
          ),
          const SizedBox(width: AppTheme.spacing10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  context.l10n.sipHubPeerServiceVersionLine(
                    versionMajor,
                    versionMinor,
                    metadataLen,
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: context.textTertiary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: context.textTertiary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
