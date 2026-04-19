// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Inline preview row of a peer's advertised services.
///
/// Renders up to [peerServicePreviewMax] service chips on the SIP hub
/// peer tile, followed by a "+N more" tag when the peer advertises
/// additional services beyond the preview cap. Tap goes through the
/// parent tile — this widget is presentational only, no GestureDetector.
///
/// Data comes from [`peerServicesPreviewProvider`] +
/// [`peerServicesCountProvider`] — thin projections of
/// `mrrpCachedServicesProvider`. No new subscriptions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../providers/sip_hub_services_providers.dart';
import '../../../services/protocol/sip/mrrp_types.dart';

/// Shown inline on the SIP hub peer tile. Empty-collapsing: renders
/// nothing when the peer has no advertised (public, non-expired)
/// services.
class PeerServicePreviewRow extends ConsumerWidget {
  /// Peer node id used as provider family key.
  final int peerNodeId;

  const PeerServicePreviewRow({super.key, required this.peerNodeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(peerServicesPreviewProvider(peerNodeId));
    if (preview.isEmpty) return const SizedBox.shrink();

    final total = ref.watch(peerServicesCountProvider(peerNodeId));
    final remainder = total - preview.length;

    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing6),
      child: Wrap(
        spacing: AppTheme.spacing6,
        runSpacing: AppTheme.spacing4,
        children: [
          for (final svc in preview)
            _ServiceChip(serviceId: svc.descriptor.serviceId),
          if (remainder > 0) _MoreChip(count: remainder),
        ],
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  final int serviceId;

  const _ServiceChip({required this.serviceId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius6),
      ),
      child: Text(
        MrrpServiceId.nameOf(serviceId),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: context.accentColor,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}

class _MoreChip extends StatelessWidget {
  final int count;

  const _MoreChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: context.textTertiary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius6),
      ),
      child: Text(
        context.l10n.sipHubPeerServiceMoreCount(count),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: context.textTertiary,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}
