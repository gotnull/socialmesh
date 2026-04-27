// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// SIP Peer Detail Sheet — bottom sheet showing peer info + handshake action.
//
// Redesigned to match NodeDex edge_detail_sheet pattern:
// - Sigil avatar header with resolved name + hex ID
// - Grouped info rows with semantic colors
// - Capability chips with check/cancel icons
// - Prominent handshake action button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/expert_details_expander.dart';
import '../../features/nodedex/models/nodedex_entry.dart';
import '../../features/nodedex/models/sigil_evolution.dart';
import '../../features/nodedex/providers/nodedex_providers.dart';
import '../../features/nodedex/services/patina_score.dart';
import '../../features/nodedex/services/trait_engine.dart';
import '../../features/nodedex/widgets/sigil_painter.dart';
import '../../features/nodes/node_display_name_resolver.dart';
import '../../models/mesh_models.dart';
import '../../providers/age_eligibility_provider.dart';
import '../../providers/app_providers.dart';
import '../../providers/sip_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/protocol/sip/sip_codec.dart';
import '../../services/protocol/sip/sip_types.dart';
import '../../services/protocol/sip/sip_discovery.dart';
import '../../services/protocol/sip/sip_handshake.dart';
import '../../utils/snackbar.dart';
import 'sip_dm_screen.dart';
import 'widgets/peer_services_section.dart';

/// Bottom sheet showing detailed info for a single SIP peer.
///
/// Displays a sigil avatar, resolved display name, device class,
/// capabilities, and last-seen time. Includes a handshake action button.
class SipPeerDetailSheet extends ConsumerWidget {
  final SipPeerCapability peer;

  const SipPeerDetailSheet({super.key, required this.peer});

  /// Show the peer detail sheet.
  static Future<void> show(BuildContext context, SipPeerCapability peer) {
    return AppBottomSheet.show(
      context: context,
      child: SipPeerDetailSheet(peer: peer),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entry = ref.watch(nodeDexEntryProvider(peer.nodeId));
    final nodes = ref.watch(nodesProvider);
    final node = nodes[peer.nodeId];
    final patinaResult = ref.watch(nodeDexPatinaProvider(peer.nodeId));
    final traitResult = ref.watch(nodeDexTraitProvider(peer.nodeId));
    final hexId =
        '!${peer.nodeId.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    final displayName = _resolveDisplayName(entry, node, peer.nodeId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: sigil avatar + name + hex ID
        Row(
          children: [
            _buildAvatar(context, entry, patinaResult, traitResult),
            const SizedBox(width: AppTheme.spacing14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    hexId,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.textTertiary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: AppTheme.spacing20),

        // Info rows — user-friendly fields visible by default
        _InfoRow(
          label: l10n.sipPeerDetailDeviceClass,
          value: deviceClassName(context, peer.deviceClass),
          icon: Icons.devices,
        ),
        _InfoRow(
          label: l10n.sipPeerDetailLastSeen,
          value: _formatLastSeen(context, peer.lastSeenMs),
          icon: Icons.schedule,
        ),

        const SizedBox(height: AppTheme.spacing16),

        // Capabilities section
        Text(
          l10n.sipPeerDetailCapabilities,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Wrap(
          spacing: AppTheme.spacing8,
          runSpacing: AppTheme.spacing8,
          children: [
            _CapChip(
              label: l10n.sipPeerDetailSupportsSip1,
              supported: peer.supportsSip1,
            ),
            _CapChip(
              label: l10n.sipPeerDetailSupportsSip3,
              supported: peer.supportsSip3,
            ),
            _CapChip(
              label: l10n.sipHubPeerDetailOverlayLink,
              supported: peer.supportsOverlayLinkV02,
            ),
            _CapChip(
              label: l10n.sipHubPeerDetailOverlayResource,
              supported: peer.supportsOverlayResourceV02,
            ),
            _CapChip(
              label: l10n.sipHubPeerDetailOverlaySecure,
              supported: peer.supportsOverlaySecureV03,
            ),
          ],
        ),

        const SizedBox(height: AppTheme.spacing20),

        // Advertised services (empty-collapses when none).
        PeerServicesSection(peerNodeId: peer.nodeId),

        const SizedBox(height: AppTheme.spacing8),

        // Expert details — protocol-level info behind toggle
        ExpertDetailsExpander(
          label: l10n.sipPeerDetailExpertToggle,
          expandedBuilder: (context) => Column(
            children: [
              _InfoRow(
                label: l10n.sipPeerDetailFeatures,
                value: '0x${peer.features.toRadixString(16)}',
                icon: Icons.extension,
              ),
              _InfoRow(
                label: l10n.sipPeerDetailMtu,
                value: '${peer.mtuHint}', // lint-allow: hardcoded-string
                icon: Icons.straighten,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.spacing24),

        // Handshake action
        _HandshakeButton(peer: peer),
      ],
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    NodeDexEntry? entry,
    PatinaResult patinaResult,
    TraitResult traitResult,
  ) {
    if (entry?.sigil != null) {
      return SigilAvatar(
        sigil: entry!.sigil,
        nodeNum: peer.nodeId,
        size: 56,
        evolution: SigilEvolution.fromPatina(
          patinaResult.score,
          trait: traitResult.primary,
        ),
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
      ),
      child: Icon(
        Icons.sensors,
        size: 28,
        color: context.accentColor.withValues(alpha: 0.7),
      ),
    );
  }

  static String _resolveDisplayName(
    NodeDexEntry? entry,
    MeshNode? node,
    int nodeId,
  ) {
    return entry?.localNickname ??
        entry?.sipDisplayName ??
        node?.displayName ??
        entry?.lastKnownName ??
        NodeDisplayNameResolver.defaultName(nodeId);
  }

  /// Returns a localized device class name for the given SIP device class code.
  ///
  /// Public so other SIP screens (e.g., discovery sheet) can reuse l10n
  /// mappings instead of duplicating hardcoded strings.
  static String deviceClassName(BuildContext context, int code) {
    final l10n = context.l10n;
    switch (code) {
      case 0:
        return l10n.sipPeerDetailDeviceUnknown;
      case 1:
        return l10n.sipPeerDetailDevicePhone;
      case 2:
        return l10n.sipPeerDetailDeviceTablet;
      case 3:
        return l10n.sipPeerDetailDeviceDesktop;
      default:
        return l10n.sipPeerDetailDeviceType(code);
    }
  }

  static String _formatLastSeen(BuildContext context, int lastSeenMs) {
    final l10n = context.l10n;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final diffMs = nowMs - lastSeenMs;
    final diffMinutes = diffMs ~/ 60000;

    if (diffMinutes < 1) return l10n.sipPeerDetailJustNow;
    if (diffMinutes < 60) return l10n.sipPeerDetailMinutesAgo(diffMinutes);
    final diffHours = diffMinutes ~/ 60;
    return l10n.sipPeerDetailHoursAgo(diffHours);
  }
}

// =============================================================================
// Info row — consistent with NodeDex detail screen pattern
// =============================================================================

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.textTertiary),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: context.textTertiary),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Capability chip
// =============================================================================

class _CapChip extends StatelessWidget {
  final String label;
  final bool supported;

  const _CapChip({required this.label, required this.supported});

  @override
  Widget build(BuildContext context) {
    final color = supported ? AccentColors.green : context.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            supported ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: color,
          ),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Handshake button — reflects current handshake state
// =============================================================================

class _HandshakeButton extends ConsumerWidget {
  final SipPeerCapability peer;

  const _HandshakeButton({required this.peer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final hsState = ref.watch(sipHandshakeStateProvider(peer.nodeId));
    final policy = ref.watch(ageSafetyPolicyProvider);
    final dmAvailable = ref.watch(meshPrivacyDmAvailableProvider);

    // Privacy gate: hide handshake button when DM is disabled.
    if (!dmAvailable) {
      return const SizedBox.shrink();
    }

    // Minor contact restriction: disable handshake initiation entirely.
    if (policy.shouldRestrictUnsolicitedContact) {
      return const SizedBox.shrink();
    }

    // pendingApproval is owned by the dedicated Incoming Requests tile
    // above the peer list — do not stand in for the Accept/Decline
    // buttons here (mandatory consent gate, SIP_HANDSHAKE_CONSENT.md).
    if (hsState == SipHandshakeState.pendingApproval) {
      return const SizedBox.shrink();
    }

    // Open-chat shortcut when an active DM session exists for this peer.
    ref.watch(sipDmEpochProvider);
    final dm = ref.read(sipDmManagerProvider);
    final sessions = dm?.activeSessions
        .where((s) => s.peerNodeId == peer.nodeId)
        .toList();
    if (sessions != null && sessions.isNotEmpty) {
      final session = sessions.first;
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _openChat(context, session.sessionTag),
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: Text(l10n.sipHubPeerDetailOpenChat),
        ),
      );
    }

    final (label, icon, enabled) = switch (hsState) {
      SipHandshakeState.idle => (
        l10n.sipHandshakeAction,
        Icons.handshake_outlined,
        true,
      ),
      SipHandshakeState.accepted => (
        l10n.sipHandshakeComplete,
        Icons.check_circle_outline,
        false,
      ),
      SipHandshakeState.failed || SipHandshakeState.timedOut => (
        l10n.sipHandshakeFailed,
        Icons.error_outline,
        true,
      ),
      _ => (l10n.sipHandshakeInProgress, Icons.hourglass_top, false),
    };

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: enabled ? () => _initiateHandshake(context, ref) : null,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }

  void _openChat(BuildContext context, int sessionTag) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SipDmScreen(sessionTag: sessionTag),
      ),
    );
  }

  void _initiateHandshake(BuildContext context, WidgetRef ref) {
    ref.read(hapticServiceProvider).trigger(HapticType.medium);
    final localL10n = context.l10n;

    final handshake = ref.read(sipHandshakeProvider);
    if (handshake == null) {
      // Chip is the single source of truth — no redundant snackbar.
      return;
    }

    final frame = handshake.initiateHandshake(peer.nodeId);
    if (frame == null) {
      showInfoSnackBar(context, localL10n.sipHandshakeInProgress);
      return;
    }

    final encoded = SipCodec.encode(frame);
    if (encoded == null) {
      return;
    }

    final protocol = ref.read(protocolServiceProvider);
    protocol.sendSipGated(encoded, SipMessageType.hsHello);
    ref.read(sipCountersProvider).recordHandshakeInitiated();

    showInfoSnackBar(context, localL10n.sipHandshakeInProgress);
    Navigator.of(context).pop();
  }
}
