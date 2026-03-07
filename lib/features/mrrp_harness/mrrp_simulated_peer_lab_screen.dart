// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
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
                // Info card
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.accentColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        border: Border.all(
                          color: context.accentColor.withAlpha(50),
                        ),
                      ),
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: context.accentColor,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spacing12),
                          Expanded(
                            child: Text(
                              l10n.mrrpHarnessSimLabInfoText,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.only(bottom: AppTheme.spacing32),
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
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(
            color: context.border.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AccentColors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                    child: Icon(
                      Icons.smart_toy,
                      size: 20,
                      color: AccentColors.purple,
                    ),
                  ),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTheme.fontFamily,
                      color: context.textPrimary,
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
              const Divider(
                height: AppTheme.spacing24,
                color: Color(0x33FFFFFF),
              ),

              // Services
              _SimSectionLabel(label: l10n.mrrpHarnessSimServices),
              const SizedBox(height: AppTheme.spacing4),
              Wrap(
                spacing: AppTheme.spacing4,
                children: peer.serviceIds.map((id) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing8,
                      vertical: AppTheme.spacing2,
                    ),
                    decoration: BoxDecoration(
                      color: context.textPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      border: Border.all(
                        color: context.border.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      MrrpServiceId.nameOf(id),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFamily: AppTheme.fontFamily,
                        color: context.textSecondary,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.spacing12),

              // Response mode
              _SimSectionLabel(label: l10n.mrrpHarnessSimResponseMode),
              const SizedBox(height: AppTheme.spacing8),
              Wrap(
                spacing: AppTheme.spacing8,
                runSpacing: AppTheme.spacing8,
                children: SimResponseMode.values.map((mode) {
                  final isSelected = mode == peer.mode;
                  final label = switch (mode) {
                    SimResponseMode.normal => l10n.mrrpHarnessSimModeNormal,
                    SimResponseMode.delayed => l10n.mrrpHarnessSimModeDelayed,
                    SimResponseMode.error => l10n.mrrpHarnessSimModeError,
                    SimResponseMode.timeout => l10n.mrrpHarnessSimModeTimeout,
                    SimResponseMode.duplicate =>
                      l10n.mrrpHarnessSimModeDuplicate,
                    SimResponseMode.malformed =>
                      l10n.mrrpHarnessSimModeMalformed,
                  };
                  return BouncyTap(
                    onTap: () {
                      ref.read(hapticServiceProvider).trigger(HapticType.light);
                      ref
                          .read(mrrpSimPeersProvider.notifier)
                          .updateMode(peer.simId, mode);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing12,
                        vertical: AppTheme.spacing8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.accentColor.withValues(alpha: 0.15)
                            : context.card,
                        borderRadius: BorderRadius.circular(AppTheme.radius20),
                        border: Border.all(
                          color: isSelected
                              ? context.accentColor
                              : context.border.withValues(alpha: 0.5),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? context.accentColor
                              : context.textSecondary,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Delay (when delayed mode)
              if (peer.mode == SimResponseMode.delayed) ...[
                const SizedBox(height: AppTheme.spacing12),
                _SimSectionLabel(label: l10n.mrrpHarnessSimDelay),
                const SizedBox(height: AppTheme.spacing4),
                Slider(
                  value: peer.delaySeconds.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  activeColor: context.accentColor,
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
                const SizedBox(height: AppTheme.spacing12),
                _SimSectionLabel(label: l10n.mrrpHarnessSimErrorCode),
                const SizedBox(height: AppTheme.spacing8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing12,
                    vertical: AppTheme.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: context.background,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    border: Border.all(color: context.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<MrrpStatusCode>(
                      value: peer.errorStatus,
                      isExpanded: true,
                      dropdownColor: context.card,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textPrimary,
                      ),
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
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SimSectionLabel extends StatelessWidget {
  final String label;
  const _SimSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: context.textTertiary,
        letterSpacing: 1.2,
      ),
    );
  }
}
