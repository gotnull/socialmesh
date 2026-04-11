// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Mesh Explorer home screen — the primary service-discovery hub.
///
/// Service-first layout: discoverable community services are the primary
/// content. Nearby peers are supporting context, not the headline.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/safety/lifecycle_mixin.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/logging.dart';
import '../../providers/app_providers.dart';
import '../../providers/mesh_explorer_providers.dart';
import '../../providers/help_providers.dart';
import '../../providers/sip_providers.dart';
import '../../services/haptic_service.dart';
import '../../utils/snackbar.dart';
import '../mesh_services/screens/create_service_screen.dart';
import 'widgets/mesh_explorer_hero.dart';
import 'widgets/mesh_explorer_nearby_section.dart';
import 'widgets/mesh_explorer_services_section.dart';

/// Primary Mesh Explorer screen.
///
/// Organized as a service-first discovery hub:
/// 1. Compact mesh status strip
/// 2. Live service cards (primary content)
/// 3. Compact nearby peers strip (supporting context)
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
          // Not-connected state takes over the whole screen
          if (!summary.isConnected)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _NotConnectedState(l10n: l10n),
            ),

          if (summary.isConnected) ...[
            // Compact mesh status strip
            SliverToBoxAdapter(
              child: MeshExplorerStatusStrip(summary: summary),
            ),

            // Primary content: service cards
            if (services.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacing16,
                    AppTheme.spacing16,
                    AppTheme.spacing16,
                    AppTheme.spacing8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: SemanticColors.success,
                      ),
                      const SizedBox(width: AppTheme.spacing8),
                      Text(
                        l10n.meshExplorerSectionLiveNow,
                        style: context.labelStyle?.copyWith(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: MeshExplorerServicesSection(services: services),
              ),
            ],

            // Empty state when connected but no services
            if (services.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyDiscoveryState(l10n: l10n, onScan: _onScan),
              ),

            // Compact nearby peers section (subordinate)
            if (peers.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacing16,
                    AppTheme.spacing24,
                    AppTheme.spacing16,
                    AppTheme.spacing8,
                  ),
                  child: Text(
                    l10n.meshExplorerSectionNearbyPeers,
                    style: context.labelStyle?.copyWith(
                      color: context.textTertiary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: MeshExplorerNearbySection(peers: peers, onScan: _onScan),
              ),
            ],
          ],

          // Bottom safe area padding
          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing32)),
        ],
      ),
    );
  }
}

/// Full-screen empty state when no radio is connected.
class _NotConnectedState extends StatelessWidget {
  final AppLocalizations l10n;

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
            const SizedBox(height: AppTheme.spacing24),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.bluetooth, size: 18),
              label: Text(l10n.meshExplorerNotConnectedAction),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state when connected but no services discovered.
class _EmptyDiscoveryState extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onScan;

  const _EmptyDiscoveryState({required this.l10n, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing24,
        vertical: AppTheme.spacing48,
      ),
      child: Column(
        children: [
          // Ambient icon cluster
          SizedBox(
            width: 120,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 0,
                  top: 10,
                  child: Icon(
                    Icons.dashboard_outlined,
                    size: 32,
                    color: AccentColors.cyan.withValues(alpha: 0.3),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 5,
                  child: Icon(
                    Icons.poll_outlined,
                    size: 28,
                    color: AccentColors.purple.withValues(alpha: 0.3),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: Icon(
                    Icons.cell_tower_outlined,
                    size: 36,
                    color: AccentColors.emerald.withValues(alpha: 0.3),
                  ),
                ),
                Icon(
                  Icons.explore_outlined,
                  size: 48,
                  color: context.textTertiary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            l10n.meshExplorerEmptyTitle,
            style: context.titleStyle?.copyWith(color: context.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.meshExplorerEmptyBody,
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing24),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CreateServiceScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.meshExplorerEmptyAction),
          ),
        ],
      ),
    );
  }
}
