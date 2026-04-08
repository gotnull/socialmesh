// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/animated_empty_state.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/nearby_person_card.dart';
import '../../providers/app_providers.dart';
import '../../providers/sip_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/protocol/sip/sip_discovery.dart';
import 'sip_peer_detail_sheet.dart';

/// Bottom sheet showing discovered SIP peers.
///
/// Displays a list of SIP-capable peers detected via beacon or rollcall,
/// with a "Scan for Socialmesh" button to trigger a rollcall request.
class SipDiscoverySheet extends ConsumerStatefulWidget {
  const SipDiscoverySheet({super.key});

  /// Show the discovery sheet.
  static Future<void> show(BuildContext context) {
    return AppBottomSheet.show(
      context: context,
      child: const SipDiscoverySheet(),
    );
  }

  @override
  ConsumerState<SipDiscoverySheet> createState() => _SipDiscoverySheetState();
}

class _SipDiscoverySheetState extends ConsumerState<SipDiscoverySheet> {
  bool _scanning = false;

  void _onScan() {
    final discovery = ref.read(sipDiscoveryProvider);
    AppLogging.sip(
      'SIP_DISCOVERY: scan tapped, discovery=${discovery != null}',
    );
    if (discovery == null) return;

    final haptics = ref.read(hapticServiceProvider);
    haptics.trigger(HapticType.light);

    final outbound = discovery.buildRollcallReq(force: true);
    if (outbound != null) {
      // Send the encoded SIP frame over the mesh transport.
      final protocol = ref.read(protocolServiceProvider);
      protocol.sendSipPacket(outbound.encoded);
      AppLogging.sip(
        'SIP_DISCOVERY: ROLLCALL_REQ dispatched ${outbound.encoded.length}B',
      );
      setState(() => _scanning = true);
      // Reset scanning state after a short delay.
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _scanning = false);
      });
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final peers = ref.watch(sipDiscoveredPeersProvider);
    final theme = Theme.of(context);
    AppLogging.sip('SIP_DISCOVERY: build — peers=${peers.length}');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
          child: Text(
            l10n.sipDiscoveryTitle,
            style: theme.textTheme.titleLarge,
          ),
        ),

        // Scan button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _scanning ? null : _onScan,
            icon: _scanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.radar, size: 18),
            label: Text(
              _scanning
                  ? l10n.sipDiscoveryScanCooldown(3)
                  : l10n.sipDiscoveryScanButton,
            ),
          ),
        ),

        const SizedBox(height: AppTheme.spacing16),

        // Peer list or empty state
        if (peers.isEmpty)
          _buildEmptyState(context, l10n)
        else
          ..._buildPeerList(context, peers, theme),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, dynamic l10n) {
    final taglines = [
      l10n.sipHubScanningTagline1 as String,
      l10n.sipHubScanningTagline2 as String,
      l10n.sipHubScanningTagline3 as String,
      l10n.sipHubScanningTagline4 as String,
    ];

    return SizedBox(
      height: 360,
      child: AnimatedEmptyState(
        config: AnimatedEmptyStateConfig(
          icons: const [
            Icons.sensors,
            Icons.wifi_find,
            Icons.radar,
            Icons.people_outline,
            Icons.explore_outlined,
            Icons.person_search,
          ],
          taglines: taglines,
          titlePrefix: l10n.sipHubScanningTitlePrefix as String,
          titleKeyword: l10n.sipHubScanningTitleKeyword as String,
          titleSuffix: l10n.sipHubScanningTitleSuffix as String,
        ),
      ),
    );
  }

  List<Widget> _buildPeerList(
    BuildContext context,
    List<SipPeerCapability> peers,
    ThemeData theme,
  ) {
    return [
      Text(
        context.l10n.sipDiscoveryPeersNearby(peers.length),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      const SizedBox(height: AppTheme.spacing8),
      ...peers.map((peer) => _PeerTile(peer: peer)),
    ];
  }
}

class _PeerTile extends ConsumerWidget {
  final SipPeerCapability peer;

  const _PeerTile({required this.peer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final nodeHex =
        '!${peer.nodeId.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    final deviceClassName = SipPeerDetailSheet.deviceClassName(
      context,
      peer.deviceClass,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: NearbyPersonCard(
        avatar: CircleAvatar(
          radius: 24,
          backgroundColor: context.accentColor.withValues(alpha: 0.1),
          child: Icon(
            Icons.sensors,
            color: context.accentColor.withValues(alpha: 0.7),
            size: 20,
          ),
        ),
        displayName: '${l10n.sipDiscoveryPeerAnonymous} $nodeHex',
        statusLine: l10n.sipDiscoveryDeviceClass(deviceClassName),
        statusColor: context.accentColor,
        onTap: () {
          ref.read(hapticServiceProvider).trigger(HapticType.selection);
          SipPeerDetailSheet.show(context, peer);
        },
      ),
    );
  }
}
