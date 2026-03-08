// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Nearby peers section for Mesh Explorer.
///
/// Renders anonymous and identified peer tiles in a card layout
/// with appropriate interaction affordances per tier.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../features/nodedex/widgets/sigil_painter.dart';
import '../../../providers/sip_providers.dart';
import '../../../services/haptic_service.dart';
import '../models/interaction_tier.dart';
import '../models/mesh_explorer_peer.dart';
import 'mesh_explorer_peer_detail_sheet.dart';

/// Display section for nearby mesh peers.
class MeshExplorerNearbySection extends StatelessWidget {
  final List<MeshExplorerPeer> peers;

  const MeshExplorerNearbySection({super.key, required this.peers});

  @override
  Widget build(BuildContext context) {
    if (peers.isEmpty) {
      return _EmptyNearby();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        children: [
          for (int i = 0; i < peers.length; i++) ...[
            _PeerTile(peer: peers[i]),
            if (i < peers.length - 1)
              Divider(height: 1, color: context.border.withValues(alpha: 0.15)),
          ],
        ],
      ),
    );
  }
}

/// Empty state for no nearby peers.
class _EmptyNearby extends StatelessWidget {
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
            Icons.people_outline,
            size: 40,
            color: context.textTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.meshExplorerEmptyNearbyTitle,
            style: context.bodyStyle?.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.meshExplorerEmptyNearbyBody,
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

/// A single peer tile in the nearby section.
class _PeerTile extends ConsumerWidget {
  final MeshExplorerPeer peer;

  const _PeerTile({required this.peer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    // Sigil seed depends on tier
    final sigilSeed = switch (peer) {
      AnonymousPeer p => p.ambientId,
      IdentifiedPeer p => p.sigilSeed,
    };

    // Display name
    final displayName = switch (peer) {
      AnonymousPeer() => l10n.meshExplorerPeerAnonymous,
      IdentifiedPeer p => p.displayName ?? l10n.meshExplorerPeerAnonymous,
    };

    // Tier badge
    final (badgeLabel, badgeColor) = _tierBadge(peer.tier, l10n);

    // Hop count label
    final hopLabel = peer.hopCount >= 3
        ? l10n.meshExplorerHopCountFar
        : l10n.meshExplorerHopCount(peer.hopCount);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        onTap: () => _showPeerDetail(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing12,
          ),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
          ),
          child: Row(
            children: [
              // Sigil avatar
              SigilAvatar(nodeNum: sigilSeed, size: 44),

              const SizedBox(width: AppTheme.spacing12),

              // Info column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + badge row
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: context.bodyStyle?.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeLabel != null) ...[
                          const SizedBox(width: AppTheme.spacing8),
                          _TierBadge(label: badgeLabel, color: badgeColor!),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    // Hop + service count row
                    Text(
                      '$hopLabel · ${l10n.meshExplorerServiceCount(peer.serviceCount)}',
                      style: context.bodySmallStyle?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // Action button
              _PeerAction(peer: peer),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPeerDetail(BuildContext context, WidgetRef ref) async {
    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticType.selection);

    if (!context.mounted) return;
    await AppBottomSheet.show(
      context: context,
      child: MeshExplorerPeerDetailSheet(peer: peer),
    );
  }

  (String?, Color?) _tierBadge(InteractionTier tier, dynamic l10n) {
    return switch (tier) {
      InteractionTier.anonymous => (null, null),
      InteractionTier.handshaked => (
        l10n.meshExplorerPeerHandshaked as String,
        SemanticColors.warning,
      ),
      InteractionTier.identified => (
        l10n.meshExplorerPeerVerified as String,
        SemanticColors.success,
      ),
      InteractionTier.pinned => (
        l10n.meshExplorerPeerPinned as String,
        SemanticColors.info,
      ),
    };
  }
}

/// Tier badge pill.
class _TierBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TierBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Action button on the right side of a peer tile.
class _PeerAction extends ConsumerWidget {
  final MeshExplorerPeer peer;

  const _PeerAction({required this.peer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    final (label, icon) = switch (peer.tier) {
      InteractionTier.anonymous => (
        l10n.meshExplorerActionHandshake,
        Icons.handshake_outlined,
      ),
      InteractionTier.handshaked => (
        l10n.meshExplorerActionRequestIdentity,
        Icons.verified_user_outlined,
      ),
      InteractionTier.identified || InteractionTier.pinned => (
        l10n.meshExplorerActionView,
        Icons.chevron_right,
      ),
    };

    return TextButton.icon(
      onPressed: () => _onAction(context, ref),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing8,
          vertical: AppTheme.spacing4,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref) async {
    final haptics = ref.read(hapticServiceProvider);
    final hs = ref.read(sipHandshakeProvider);
    final identity = ref.read(sipIdentityHandlerProvider);
    await haptics.trigger(HapticType.medium);

    switch (peer.tier) {
      case InteractionTier.anonymous:
        hs?.initiateHandshake(peer.nodeId);
      case InteractionTier.handshaked:
        identity?.buildIdReq();
      case InteractionTier.identified:
      case InteractionTier.pinned:
        if (!context.mounted) return;
        await AppBottomSheet.show(
          context: context,
          child: MeshExplorerPeerDetailSheet(peer: peer),
        );
    }
  }
}
