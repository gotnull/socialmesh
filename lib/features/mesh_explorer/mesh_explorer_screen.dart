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
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/section_header.dart';
import '../../core/logging.dart';
import '../../providers/app_providers.dart';
import '../../providers/mesh_explorer_providers.dart';
import '../../providers/help_providers.dart';
import '../../providers/sip_providers.dart';
import '../../services/haptic_service.dart';
import '../../utils/snackbar.dart';
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
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    // User is now looking at the screen — clear unseen peer badge.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(newMeshPeerCountProvider.notifier).clear();
      }
    });
  }

  Future<void> _onScan() async {
    if (_isScanning) return;

    final haptics = ref.read(hapticServiceProvider);
    final discovery = ref.read(sipDiscoveryProvider);
    final protocol = ref.read(protocolServiceProvider);
    final scanSentMsg = context.l10n.meshExplorerScanSent;
    final scanCooldownMsg = context.l10n.meshExplorerScanCooldown;
    await haptics.trigger(HapticType.medium);
    if (!mounted) return;

    if (discovery == null) return;

    setState(() => _isScanning = true);

    final outbound = discovery.buildRollcallReq(force: true);
    if (outbound != null) {
      protocol.sendSipPacket(outbound.encoded);
      AppLogging.sip(
        'MESH_EXPLORER: ROLLCALL_REQ dispatched '
        '${outbound.encoded.length}B', // lint-allow: hardcoded-string
      );
      if (mounted) {
        showInfoSnackBar(context, scanSentMsg);
      }
    } else if (mounted) {
      showWarningSnackBar(context, scanCooldownMsg);
    }

    // Keep scanning indicator briefly for visual feedback.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _isScanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = ref.watch(meshExplorerSummaryProvider);
    final peers = ref.watch(meshExplorerPeersProvider);
    final services = ref.watch(meshExplorerServicesProvider);

    return HelpTourController(
      topicId: 'mesh_explorer_overview',
      stepKeys: const {},
      child: GlassScaffold(
        title: l10n.meshExplorerTitle,
        actions: [
          if (summary.isConnected)
            _isScanning
                ? Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing12),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.accentColor,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.sensors, size: 22),
                    tooltip: l10n.meshExplorerScanAction,
                    onPressed: _onScan,
                  ),
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              if (value == 'help') {
                ref
                    .read(helpProvider.notifier)
                    .startTour(
                      'mesh_explorer_overview',
                    ); // lint-allow: hardcoded-string
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'help', // lint-allow: hardcoded-string
                child: Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      size: 18,
                      color: context.textSecondary,
                    ),
                    SizedBox(width: AppTheme.spacing8),
                    Text(l10n.meshExplorerHelp),
                  ],
                ),
              ),
            ],
          ),
        ],
        slivers: [
          // Hero summary
          SliverToBoxAdapter(child: MeshExplorerHero(summary: summary)),

          // Nearby peers section
          if (summary.isConnected) ...[
            SliverPersistentHeader(
              pinned: false,
              delegate: SectionHeaderDelegate(
                title: l10n.meshExplorerSectionNearby,
                count: peers.length,
              ),
            ),
            SliverToBoxAdapter(
              child: MeshExplorerNearbySection(peers: peers, onScan: _onScan),
            ),

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
      ),
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
