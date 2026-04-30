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
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../features/nodedex/widgets/tappable_sigil_avatar.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/sip_providers.dart';
import '../../../services/haptic_service.dart';
import '../../../services/protocol/sip/sip_codec.dart';
import '../../../services/protocol/sip/sip_handshake.dart';
import '../../../utils/snackbar.dart';
import '../models/interaction_tier.dart';
import '../models/mesh_explorer_peer.dart';
import 'mesh_explorer_peer_detail_sheet.dart';
import 'mesh_explorer_scanning_empty_state.dart';

/// Display section for nearby mesh peers.
class MeshExplorerNearbySection extends StatelessWidget {
  final List<MeshExplorerPeer> peers;
  final VoidCallback onScan;

  const MeshExplorerNearbySection({
    super.key,
    required this.peers,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    if (peers.isEmpty) {
      return MeshExplorerScanningEmptyState(onScan: onScan);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            for (int i = 0; i < peers.length; i++) ...[
              _PeerTile(peer: peers[i]),
              if (i < peers.length - 1)
                Divider(
                  height: 1,
                  indent: AppTheme.spacing48,
                  color: context.border.withValues(alpha: 0.1),
                ),
            ],
          ],
        ),
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
    final hopCount = peer.hopCount;
    final hopLabel = hopCount == null
        ? l10n.meshExplorerHopCountUnknown
        : hopCount >= 3
        ? l10n.meshExplorerHopCountFar
        : l10n.meshExplorerHopCount(hopCount);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        onTap: () => _showPeerDetail(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing8,
          ),
          child: Row(
            children: [
              // Compact sigil avatar — IdentifiedPeer sigil taps jump
              // to NodeDex; for AnonymousPeer the seed is an ambient ID
              // (not a real nodeNum) so we leave the avatar inert and
              // let the row's InkWell handle the peer-detail sheet.
              TappableSigilAvatar(
                nodeNum: sigilSeed,
                size: 32,
                enableTap: peer is IdentifiedPeer,
              ),

              const SizedBox(width: AppTheme.spacing8),

              // Info column
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: context.bodySmallStyle?.copyWith(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badgeLabel != null) ...[
                      const SizedBox(width: AppTheme.spacing6),
                      _TierBadge(label: badgeLabel, color: badgeColor!),
                    ],
                    const SizedBox(width: AppTheme.spacing6),
                    Text(
                      hopLabel,
                      style: context.captionStyle?.copyWith(
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

    // Watch handshake state for anonymous peers to show progress.
    final hsState = peer.tier == InteractionTier.anonymous
        ? ref.watch(sipHandshakeStateProvider(peer.nodeId))
        : SipHandshakeState.idle;

    // While handshake is in-flight, show a progress indicator.
    if (_isHandshakeInProgress(hsState)) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing8,
          vertical: AppTheme.spacing4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.accentColor,
              ),
            ),
            const SizedBox(width: AppTheme.spacing6),
            Text(
              l10n.meshExplorerHandshakeInProgress,
              style: TextStyle(fontSize: 12, color: context.textTertiary),
            ),
          ],
        ),
      );
    }

    final (label, icon) = switch (peer.tier) {
      InteractionTier.anonymous => (
        l10n.meshExplorerActionHandshake,
        Icons.handshake_outlined,
      ),
      InteractionTier.handshaked => (null, Icons.verified_user_outlined),
      InteractionTier.identified || InteractionTier.pinned => (
        l10n.meshExplorerActionView,
        Icons.chevron_right,
      ),
    };

    if (label == null) {
      return IconButton(
        onPressed: () => _onAction(context, ref),
        icon: Icon(icon, size: 20),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: AppTheme.spacing32,
          minHeight: AppTheme.spacing32,
        ),
        tooltip: l10n.meshExplorerActionRequestIdentity,
      );
    }

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

  bool _isHandshakeInProgress(SipHandshakeState state) {
    return switch (state) {
      SipHandshakeState.helloSent ||
      SipHandshakeState.pendingApproval ||
      SipHandshakeState.challengeReceived ||
      SipHandshakeState.responseSent ||
      SipHandshakeState.challengeSent ||
      SipHandshakeState.responseReceived => true,
      _ => false,
    };
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref) async {
    final haptics = ref.read(hapticServiceProvider);
    final hs = ref.read(sipHandshakeProvider);
    final protocol = ref.read(protocolServiceProvider);
    final identity = ref.read(sipIdentityHandlerProvider);
    await haptics.trigger(HapticType.medium);

    switch (peer.tier) {
      case InteractionTier.anonymous:
        // If the peer already sent us a handshake request, do not
        // accept via tile-tap — consent is mandatory via the explicit
        // Accept / Decline buttons in the SIP hub's incoming-request
        // card. A tap here must never stand in for that consent.
        final currentState = hs?.getState(peer.nodeId);
        if (currentState == SipHandshakeState.pendingApproval) {
          return;
        }
        // Already in progress — don't interrupt.
        if (currentState != null &&
            currentState != SipHandshakeState.idle &&
            currentState != SipHandshakeState.declined &&
            currentState != SipHandshakeState.failed &&
            currentState != SipHandshakeState.timedOut) {
          return;
        }
        final frame = hs?.initiateHandshake(peer.nodeId);
        if (frame != null) {
          final encoded = SipCodec.encode(frame);
          if (encoded != null) {
            protocol.sendSipPacket(encoded);
            ref.read(sipCountersProvider).recordHandshakeInitiated();
            AppLogging.sip(
              'MESH_EXPLORER: HS_HELLO sent to '
              'node=0x${peer.nodeId.toRadixString(16)}',
            );
          }
        } else if (context.mounted) {
          showWarningSnackBar(
            context,
            context.l10n.meshExplorerHandshakeCooldown,
          );
        }
      case InteractionTier.handshaked:
        final outbound = identity?.buildIdReq();
        if (outbound != null) {
          protocol.sendSipPacket(outbound.encoded);
          AppLogging.sip(
            'MESH_EXPLORER: ID_REQ sent to '
            'node=0x${peer.nodeId.toRadixString(16)}',
          );
        }
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
