// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/mrrp_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/protocol/sip/mrrp_constants.dart';
import '../../services/protocol/sip/mrrp_messages_advert.dart';
import '../../services/protocol/sip/mrrp_simulated_peer.dart';
import '../../services/protocol/sip/mrrp_types.dart';

/// Maximum simultaneous simulated peers.
const _kMaxSimPeers = 4;

/// Simulated Peer Lab — create and manage virtual MRRP peers.
class MrrpSimulatedPeerLabScreen extends ConsumerWidget {
  const MrrpSimulatedPeerLabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final simPeers = ref.watch(mrrpSimPeersProvider);
    final canCreate = simPeers.length < _kMaxSimPeers;

    // lint-allow: haptic-feedback — keyboard dismissal, not interactive action
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: l10n.mrrpHarnessSimLabTitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.mrrpHarnessSimCreate,
            onPressed: canCreate ? () => _createSimPeer(context, ref) : null,
          ),
        ],
        slivers: simPeers.isEmpty
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
                            Icons.smart_toy_outlined,
                            size: 64,
                            color: context.textTertiary,
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          Text(
                            l10n.mrrpHarnessSimLabTitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: context.textSecondary),
                          ),
                          const SizedBox(height: AppTheme.spacing8),
                          Text(
                            l10n.mrrpHarnessSimMaxPeers,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: context.textTertiary),
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          FilledButton.icon(
                            onPressed: () => _createSimPeer(context, ref),
                            icon: const Icon(Icons.add),
                            label: Text(l10n.mrrpHarnessSimCreate),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ]
            : [
                SliverPadding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _SimPeerCard(peer: simPeers[index]),
                      childCount: simPeers.length,
                    ),
                  ),
                ),
              ],
      ),
    );
  }

  void _createSimPeer(BuildContext context, WidgetRef ref) {
    ref.read(hapticServiceProvider).trigger(HapticType.medium);

    final notifier = ref.read(mrrpSimPeersProvider.notifier);
    final index = notifier.allocateIndex();
    final simId = 'SIM-$index'; // lint-allow: hardcoded-string
    final nodeId = MrrpSimulatedPeer.generateNodeId(index);

    final peer = MrrpSimulatedPeer(
      simId: simId,
      nodeId: nodeId,
      serviceIds: [MrrpServiceId.echoTest],
    );

    notifier.add(peer);

    // Inject into advert cache so peer inspector and composer see it.
    final advertEngine = ref.read(mrrpAdvertEngineProvider);
    if (advertEngine != null) {
      advertEngine.injectSimulatedPeer(nodeId, [
        MrrpAdvertDescriptor(
          serviceId: MrrpServiceId.echoTest,
          serviceType: MrrpServiceType.test,
          versionMajor: MrrpConstants.mrrpVersionMajor,
          versionMinor: MrrpConstants.mrrpVersionMinor,
          serviceFlags:
              MrrpServiceFlags.supportsRequest |
              MrrpServiceFlags.supportsResponse |
              MrrpServiceFlags.testOnly,
          metadata: Uint8List(0),
        ),
      ]);
    }

    AppLogging.mrrpHarness(
      'MRRP_SIM: created peer $simId '
      '(node=0x${nodeId.toRadixString(16)}), '
      'services=[echo.test], mode=normal', // lint-allow: hardcoded-string
    );
  }
}

/// Card showing a single simulated peer with mode controls.
class _SimPeerCard extends ConsumerWidget {
  final MrrpSimulatedPeer peer;

  const _SimPeerCard({required this.peer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final nodeHex =
        '0x${peer.nodeId.toRadixString(16).padLeft(8, '0').toUpperCase()}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.smart_toy, size: 24, color: AccentColors.purple),
                  const SizedBox(width: AppTheme.spacing8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AccentColors.purple.withAlpha(25),
                      borderRadius: BorderRadius.circular(AppTheme.radius4),
                    ),
                    child: Text(
                      l10n.mrrpHarnessSimBadge,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AccentColors.purple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    '${peer.simId} ($nodeHex)', // lint-allow: hardcoded-string
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: SemanticColors.error,
                    ),
                    onPressed: () {
                      ref
                          .read(hapticServiceProvider)
                          .trigger(HapticType.medium);
                      // Remove from advert cache first.
                      ref
                          .read(mrrpAdvertEngineProvider)
                          ?.removeSimulatedPeer(peer.nodeId);
                      ref
                          .read(mrrpSimPeersProvider.notifier)
                          .remove(peer.simId);
                    },
                  ),
                ],
              ),
              const Divider(height: AppTheme.spacing16),

              // Services
              Text(
                l10n.mrrpHarnessSimServices,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: AppTheme.spacing4),
              Wrap(
                spacing: AppTheme.spacing4,
                children: peer.serviceIds.map((id) {
                  return Chip(
                    label: Text(MrrpServiceId.nameOf(id)),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.spacing12),

              // Response mode
              Text(
                l10n.mrrpHarnessSimResponseMode,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: AppTheme.spacing4),
              SegmentedButton<SimResponseMode>(
                segments: [
                  ButtonSegment(
                    value: SimResponseMode.normal,
                    label: Text(l10n.mrrpHarnessSimModeNormal),
                  ),
                  ButtonSegment(
                    value: SimResponseMode.delayed,
                    label: Text(l10n.mrrpHarnessSimModeDelayed),
                  ),
                  ButtonSegment(
                    value: SimResponseMode.error,
                    label: Text(l10n.mrrpHarnessSimModeError),
                  ),
                ],
                selected: {peer.mode},
                onSelectionChanged: (v) {
                  ref.read(hapticServiceProvider).trigger(HapticType.light);
                  ref
                      .read(mrrpSimPeersProvider.notifier)
                      .updateMode(peer.simId, v.first);
                },
              ),
              const SizedBox(height: AppTheme.spacing4),
              SegmentedButton<SimResponseMode>(
                segments: [
                  ButtonSegment(
                    value: SimResponseMode.timeout,
                    label: Text(l10n.mrrpHarnessSimModeTimeout),
                  ),
                  ButtonSegment(
                    value: SimResponseMode.duplicate,
                    label: Text(l10n.mrrpHarnessSimModeDuplicate),
                  ),
                  ButtonSegment(
                    value: SimResponseMode.malformed,
                    label: Text(l10n.mrrpHarnessSimModeMalformed),
                  ),
                ],
                selected: {peer.mode},
                onSelectionChanged: (v) {
                  ref.read(hapticServiceProvider).trigger(HapticType.light);
                  ref
                      .read(mrrpSimPeersProvider.notifier)
                      .updateMode(peer.simId, v.first);
                },
              ),

              // Delay (when delayed mode)
              if (peer.mode == SimResponseMode.delayed) ...[
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  l10n.mrrpHarnessSimDelay,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                Slider(
                  value: peer.delaySeconds.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label:
                      '${peer.delaySeconds}s', // lint-allow: hardcoded-string
                  onChanged: (v) {
                    ref
                        .read(mrrpSimPeersProvider.notifier)
                        .updateDelay(peer.simId, v.round());
                  },
                ),
              ],

              // Error code (when error mode)
              if (peer.mode == SimResponseMode.error) ...[
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  l10n.mrrpHarnessSimErrorCode,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                DropdownButton<MrrpStatusCode>(
                  value: peer.errorStatus,
                  isExpanded: true,
                  items:
                      <MrrpStatusCode>[
                            MrrpStatusCode.busy,
                            MrrpStatusCode.notFound,
                            MrrpStatusCode.unsupported,
                            MrrpStatusCode.invalid,
                            MrrpStatusCode.internal,
                          ]
                          .map(
                            (code) => DropdownMenuItem<MrrpStatusCode>(
                              value: code,
                              child: Text(
                                '${code.name} (${code.code})', // lint-allow: hardcoded-string
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    ref
                        .read(mrrpSimPeersProvider.notifier)
                        .updateErrorStatus(peer.simId, v);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
