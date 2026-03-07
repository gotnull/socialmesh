// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/mrrp_providers.dart';
import '../../services/haptic_service.dart';
import 'mrrp_request_composer_screen.dart';
import 'widgets/mrrp_peer_tile.dart';

/// Live peer inspector — shows discovered MRRP-capable peers with
/// their advertised services, SIP state, and action buttons.
class MrrpPeerInspectorScreen extends ConsumerStatefulWidget {
  const MrrpPeerInspectorScreen({super.key});

  @override
  ConsumerState<MrrpPeerInspectorScreen> createState() =>
      _MrrpPeerInspectorScreenState();
}

class _MrrpPeerInspectorScreenState
    extends ConsumerState<MrrpPeerInspectorScreen> {
  final Set<int> _expandedPeers = {};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cachedServices = ref.watch(mrrpCachedServicesProvider);

    AppLogging.mrrpHarness(
      'MRRP_HARNESS: peer inspector showing ${cachedServices.length} peers, '
      '${cachedServices.values.fold<int>(0, (s, l) => s + l.length)} '
      'services total', // lint-allow: hardcoded-string
    );

    final peerIds = cachedServices.keys.toList()..sort();
    final isEmpty = peerIds.isEmpty;

    // lint-allow: haptic-feedback — keyboard dismissal, not interactive action
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: l10n.mrrpHarnessPeerInspectorTitle,
        slivers: isEmpty
            ? [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacing32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: context.textTertiary,
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          Text(
                            l10n.mrrpHarnessNoPeers,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: context.textSecondary),
                          ),
                          const SizedBox(height: AppTheme.spacing8),
                          Text(
                            l10n.mrrpHarnessNoPeersDescription,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: context.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ]
            : [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final peerId = peerIds[index];
                      final services = cachedServices[peerId] ?? [];
                      final isExpanded = _expandedPeers.contains(peerId);
                      return MrrpPeerTile(
                        nodeId: peerId,
                        services: services,
                        isExpanded: isExpanded,
                        onToggleExpand: () {
                          ref
                              .read(hapticServiceProvider)
                              .trigger(HapticType.light);
                          setState(() {
                            if (isExpanded) {
                              _expandedPeers.remove(peerId);
                            } else {
                              _expandedPeers.add(peerId);
                            }
                          });
                        },
                        onRefreshDirectory: () => _refreshDirectory(peerId),
                        onTestRequest: () => _openComposerForPeer(peerId),
                      );
                    }, childCount: peerIds.length),
                  ),
                ),
              ],
      ),
    );
  }

  void _refreshDirectory(int nodeId) {
    ref.read(hapticServiceProvider).trigger(HapticType.medium);
    final engine = ref.read(mrrpEngineProvider);
    if (engine == null) return;

    AppLogging.mrrpHarness(
      'MRRP_HARNESS: SERVICE_DIR_REQ sent to '
      'node=0x${nodeId.toRadixString(16)}', // lint-allow: hardcoded-string
    );

    // The advert engine handles SERVICE_DIR_REQ/RESP internally.
    // For now, we just trigger the provider rebuild.
    ref.read(mrrpAdvertEpochProvider.notifier).bump();
  }

  void _openComposerForPeer(int nodeId) {
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MrrpRequestComposerScreen(initialPeerNodeId: nodeId),
      ),
    );
  }
}
