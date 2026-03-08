// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Mesh Explorer home screen — the primary public-facing mesh discovery
/// experience. Shows nearby peers, services, and board activity in a
/// consumer-friendly card layout.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/safety/lifecycle_mixin.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/section_header.dart';
import '../../core/logging.dart';
import '../../providers/app_providers.dart';
import '../../providers/mesh_explorer_providers.dart';
import '../../providers/nearby_activity_provider.dart';
import '../../providers/sip_providers.dart';
import '../../services/haptic_service.dart';
import 'widgets/mesh_explorer_activity_section.dart';
import 'widgets/mesh_explorer_hero.dart';
import 'widgets/mesh_explorer_nearby_section.dart';
import 'widgets/mesh_explorer_services_section.dart';

/// Primary Mesh Explorer screen.
///
/// Organized as a sliver-based scrollable with:
/// 1. Hero summary area (connection state, peer/service counts)
/// 2. Nearby peers section
/// 3. Services section
class MeshExplorerScreen extends ConsumerStatefulWidget {
  const MeshExplorerScreen({super.key});

  @override
  ConsumerState<MeshExplorerScreen> createState() => _MeshExplorerScreenState();
}

class _MeshExplorerScreenState extends ConsumerState<MeshExplorerScreen>
    with LifecycleSafeMixin {
  Future<void> _onScan() async {
    final haptics = ref.read(hapticServiceProvider);
    final discovery = ref.read(sipDiscoveryProvider);
    final protocol = ref.read(protocolServiceProvider);
    await haptics.trigger(HapticType.medium);
    if (!mounted) return;

    if (discovery == null) return;

    final outbound = discovery.buildRollcallReq();
    if (outbound != null) {
      protocol.sendSipPacket(outbound.encoded);
      AppLogging.sip(
        'MESH_EXPLORER: ROLLCALL_REQ dispatched '
        '${outbound.encoded.length}B', // lint-allow: hardcoded-string
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = ref.watch(meshExplorerSummaryProvider);
    final peers = ref.watch(meshExplorerPeersProvider);
    final services = ref.watch(meshExplorerServicesProvider);
    final activities = ref.watch(nearbyActivityProvider);

    return GlassScaffold(
      title: l10n.meshExplorerTitle,
      actions: [
        if (summary.isConnected)
          IconButton(
            icon: const Icon(Icons.sensors, size: 22),
            tooltip: l10n.meshExplorerScanAction,
            onPressed: _onScan,
          ),
      ],
      slivers: [
        // Hero summary
        SliverToBoxAdapter(child: MeshExplorerHero(summary: summary)),

        // Activity section — ambient nearby events
        if (summary.isConnected && activities.isNotEmpty) ...[
          SliverPersistentHeader(
            pinned: false,
            delegate: SectionHeaderDelegate(
              title: l10n.nearbyActivitySectionTitle,
              count: activities.length,
            ),
          ),
          SliverToBoxAdapter(
            child: MeshExplorerActivitySection(activities: activities),
          ),
        ],

        // Nearby peers section
        if (summary.isConnected) ...[
          SliverPersistentHeader(
            pinned: false,
            delegate: SectionHeaderDelegate(
              title: l10n.meshExplorerSectionNearby,
              count: peers.length,
            ),
          ),
          SliverToBoxAdapter(child: MeshExplorerNearbySection(peers: peers)),

          // Services section
          SliverPersistentHeader(
            pinned: false,
            delegate: SectionHeaderDelegate(
              title: l10n.meshExplorerSectionServices,
              count: services.length,
            ),
          ),
          SliverToBoxAdapter(
            child: MeshExplorerServicesSection(services: services),
          ),
        ],

        // Not-connected state
        if (!summary.isConnected)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _NotConnectedState(l10n: l10n),
          ),

        // Bottom safe area padding
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing32)),
      ],
    );
  }
}

/// Full-screen empty state when no radio is connected.
class _NotConnectedState extends StatelessWidget {
  final dynamic l10n;

  const _NotConnectedState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cell_tower_outlined,
              size: 64,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              l10n.meshExplorerNotConnectedTitle,
              style: context.titleStyle?.copyWith(color: context.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              l10n.meshExplorerNotConnectedBody,
              style: context.bodySecondaryStyle?.copyWith(
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
