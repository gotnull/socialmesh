// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Peer detail bottom sheet for Mesh Explorer.
///
/// Shows a detailed view of a nearby peer including sigil, identity state,
/// advertised services, and tier-appropriate actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../features/nodedex/widgets/sigil_painter.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/sip_providers.dart';
import '../../../services/haptic_service.dart';
import '../../../services/protocol/sip/sip_codec.dart';
import '../../../services/protocol/sip/sip_handshake.dart';
import '../../../utils/snackbar.dart';
import '../models/interaction_tier.dart';
import '../models/mesh_explorer_peer.dart';
import '../models/service_presentation.dart';

/// Bottom sheet showing detailed peer information.
class MeshExplorerPeerDetailSheet extends ConsumerWidget {
  final MeshExplorerPeer peer;

  const MeshExplorerPeerDetailSheet({super.key, required this.peer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    final sigilSeed = switch (peer) {
      AnonymousPeer p => p.ambientId,
      IdentifiedPeer p => p.sigilSeed,
    };

    final displayName = switch (peer) {
      AnonymousPeer() => l10n.meshExplorerPeerAnonymous,
      IdentifiedPeer p => p.displayName ?? l10n.meshExplorerPeerAnonymous,
    };

    final tierLabel = switch (peer.tier) {
      InteractionTier.anonymous => l10n.meshExplorerPeerAnonymous,
      InteractionTier.handshaked => l10n.meshExplorerPeerHandshaked,
      InteractionTier.identified => l10n.meshExplorerPeerVerified,
      InteractionTier.pinned => l10n.meshExplorerPeerPinned,
    };

    final hopCount = peer.hopCount;
    final hopLabel = hopCount == null
        ? l10n.meshExplorerHopCountUnknown
        : hopCount >= 3
        ? l10n.meshExplorerHopCountFar
        : l10n.meshExplorerHopCount(hopCount);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: sigil + name + tier
        _PeerHeader(
          sigilSeed: sigilSeed,
          displayName: displayName,
          tierLabel: tierLabel,
          tier: peer.tier,
          hopLabel: hopLabel,
        ),

        const SizedBox(height: AppTheme.spacing16),

        // Services section
        if (peer.serviceCount > 0) ...[
          _SectionLabel(label: l10n.meshExplorerPeerDetailServices),
          const SizedBox(height: AppTheme.spacing8),
          _ServicesList(
            serviceIds: switch (peer) {
              AnonymousPeer p => p.mrrpServiceIds,
              IdentifiedPeer p => p.mrrpServiceIds,
            },
          ),
          const SizedBox(height: AppTheme.spacing16),
        ],

        // Actions
        _SectionLabel(label: l10n.meshExplorerPeerDetailActions),
        const SizedBox(height: AppTheme.spacing8),
        _ActionButtons(peer: peer),
      ],
    );
  }
}

/// Header row with sigil, name, tier badge, and hop info.
class _PeerHeader extends StatelessWidget {
  final int sigilSeed;
  final String displayName;
  final String tierLabel;
  final InteractionTier tier;
  final String hopLabel;

  const _PeerHeader({
    required this.sigilSeed,
    required this.displayName,
    required this.tierLabel,
    required this.tier,
    required this.hopLabel,
  });

  @override
  Widget build(BuildContext context) {
    final tierColor = switch (tier) {
      InteractionTier.anonymous => context.textTertiary,
      InteractionTier.handshaked => SemanticColors.warning,
      InteractionTier.identified => SemanticColors.success,
      InteractionTier.pinned => SemanticColors.info,
    };

    return Row(
      children: [
        SigilAvatar(nodeNum: sigilSeed, size: 56),
        const SizedBox(width: AppTheme.spacing16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTheme.spacing4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                    child: Text(
                      tierLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: tierColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Icon(Icons.cell_tower, size: 14, color: context.textTertiary),
                  const SizedBox(width: AppTheme.spacing4),
                  Text(
                    hopLabel,
                    style: context.bodySmallStyle?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Section label used within the sheet.
class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: context.bodySmallStyle?.copyWith(
        color: context.textTertiary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// List of services advertised by this peer.
class _ServicesList extends StatelessWidget {
  final List<int> serviceIds;

  const _ServicesList({required this.serviceIds});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < serviceIds.length; i++) ...[
          _ServiceRow(serviceId: serviceIds[i]),
          if (i < serviceIds.length - 1)
            Divider(height: 1, color: context.border.withValues(alpha: 0.1)),
        ],
      ],
    );
  }
}

/// A single service row in the detail sheet.
class _ServiceRow extends StatelessWidget {
  final int serviceId;

  const _ServiceRow({required this.serviceId});

  @override
  Widget build(BuildContext context) {
    final presentation = ServicePresentationCatalog.forServiceId(
      serviceId,
      context.l10n,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      child: Row(
        children: [
          Icon(presentation.icon, size: 20, color: context.accentColor),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  presentation.title,
                  style: context.bodyStyle?.copyWith(
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  presentation.subtitle,
                  style: context.bodySmallStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (presentation.requiresHandshake || presentation.requiresIdentity)
            Icon(
              Icons.lock_outline,
              size: 14,
              color: context.textTertiary.withValues(alpha: 0.6),
            ),
        ],
      ),
    );
  }
}

/// Action buttons appropriate to the peer's interaction tier.
class _ActionButtons extends ConsumerWidget {
  final MeshExplorerPeer peer;

  const _ActionButtons({required this.peer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dmAvailable = ref.watch(meshPrivacyDmAvailableProvider);

    // Watch handshake state for anonymous peers.
    final hsState = peer.tier == InteractionTier.anonymous
        ? ref.watch(sipHandshakeStateProvider(peer.nodeId))
        : SipHandshakeState.idle;

    final handshakeInProgress = _isHandshakeInProgress(hsState);
    final pendingApproval = hsState == SipHandshakeState.pendingApproval;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Incoming handshake: accept / decline
        if (peer.tier == InteractionTier.anonymous &&
            dmAvailable &&
            pendingApproval) ...[
          Text(
            l10n.meshExplorerHandshakeReceived,
            style: context.bodySmallStyle?.copyWith(
              color: context.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _onDecline(context, ref),
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(l10n.meshExplorerHandshakeDecline),
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _onAccept(context, ref),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(l10n.meshExplorerHandshakeAccept),
                ),
              ),
            ],
          ),
        ]
        // Outbound handshake / initiate
        else if (peer.tier == InteractionTier.anonymous && dmAvailable)
          FilledButton.icon(
            onPressed: handshakeInProgress
                ? null
                : () => _onHandshake(context, ref),
            icon: handshakeInProgress
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.textTertiary,
                    ),
                  )
                : const Icon(Icons.handshake_outlined, size: 18),
            label: Text(
              handshakeInProgress
                  ? l10n.meshExplorerHandshakeInProgress
                  : l10n.meshExplorerActionHandshake,
            ),
          ),

        if (peer.tier == InteractionTier.handshaked)
          FilledButton.icon(
            onPressed: () => _onRequestIdentity(context, ref),
            icon: const Icon(Icons.verified_user_outlined, size: 18),
            label: Text(l10n.meshExplorerActionRequestIdentity),
          ),

        if (peer.tier == InteractionTier.identified ||
            peer.tier == InteractionTier.pinned) ...[
          // Pin/unpin toggle
          if (peer.tier == InteractionTier.identified)
            OutlinedButton.icon(
              onPressed: () => _onPin(context, ref),
              icon: const Icon(Icons.push_pin_outlined, size: 18),
              label: Text(l10n.meshExplorerActionPin),
            ),
          if (peer.tier == InteractionTier.pinned)
            OutlinedButton.icon(
              onPressed: () => _onUnpin(context, ref),
              icon: const Icon(Icons.push_pin, size: 18),
              label: Text(l10n.meshExplorerActionUnpin),
            ),
        ],

        const SizedBox(height: AppTheme.spacing8),

        // Block action (always available)
        TextButton.icon(
          onPressed: () => _onBlock(context, ref),
          icon: Icon(
            Icons.block,
            size: 18,
            color: SemanticColors.error.withValues(alpha: 0.8),
          ),
          label: Text(
            l10n.meshExplorerActionBlock,
            style: TextStyle(
              color: SemanticColors.error.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  bool _isHandshakeInProgress(SipHandshakeState state) {
    return switch (state) {
      SipHandshakeState.helloSent ||
      SipHandshakeState.challengeReceived ||
      SipHandshakeState.responseSent ||
      SipHandshakeState.challengeSent ||
      SipHandshakeState.responseReceived => true,
      _ => false,
    };
  }

  void _onAccept(BuildContext context, WidgetRef ref) {
    ref.read(hapticServiceProvider).trigger(HapticType.medium);
    final protocol = ref.read(protocolServiceProvider);
    protocol.acceptSipHandshake(peer.nodeId);
    Navigator.of(context).pop();
  }

  void _onDecline(BuildContext context, WidgetRef ref) {
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    final protocol = ref.read(protocolServiceProvider);
    protocol.declineSipHandshake(peer.nodeId);
    Navigator.of(context).pop();
  }

  void _onHandshake(BuildContext context, WidgetRef ref) {
    ref.read(hapticServiceProvider).trigger(HapticType.medium);
    final l10n = context.l10n;

    final handshake = ref.read(sipHandshakeProvider);
    if (handshake == null) {
      showErrorSnackBar(context, l10n.sipHandshakeFailed);
      return;
    }

    // Already in progress — don't interrupt.
    final currentState = handshake.getState(peer.nodeId);
    if (currentState != SipHandshakeState.idle &&
        currentState != SipHandshakeState.declined &&
        currentState != SipHandshakeState.failed &&
        currentState != SipHandshakeState.timedOut) {
      return;
    }

    final frame = handshake.initiateHandshake(peer.nodeId);
    if (frame == null) {
      showWarningSnackBar(context, l10n.meshExplorerHandshakeCooldown);
      return;
    }

    final encoded = SipCodec.encode(frame);
    if (encoded == null) {
      showErrorSnackBar(context, l10n.sipHandshakeFailed);
      return;
    }

    final protocol = ref.read(protocolServiceProvider);
    protocol.sendSipPacket(encoded);
    ref.read(sipCountersProvider).recordHandshakeInitiated();

    showInfoSnackBar(context, l10n.meshExplorerHandshakeSent);
    Navigator.of(context).pop();
  }

  void _onRequestIdentity(BuildContext context, WidgetRef ref) {
    ref.read(hapticServiceProvider).trigger(HapticType.medium);
    final identity = ref.read(sipIdentityHandlerProvider);
    final protocol = ref.read(protocolServiceProvider);
    final outbound = identity?.buildIdReq();
    if (outbound != null) {
      protocol.sendSipPacket(outbound.encoded);
      AppLogging.sip(
        'MESH_EXPLORER: ID_REQ sent to '
        'node=0x${peer.nodeId.toRadixString(16)}',
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _onPin(BuildContext context, WidgetRef ref) async {
    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticType.selection);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _onUnpin(BuildContext context, WidgetRef ref) async {
    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticType.selection);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _onBlock(BuildContext context, WidgetRef ref) async {
    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticType.heavy);
    if (context.mounted) Navigator.of(context).pop();
  }
}
