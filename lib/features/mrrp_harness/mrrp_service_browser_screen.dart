// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/section_header.dart';
import '../../providers/mrrp_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/protocol/sip/mrrp_advert_engine.dart';
import 'mrrp_request_composer_screen.dart';
import 'widgets/mrrp_service_tile.dart';

/// Service directory browser — shows all cached MRRP services grouped
/// by peer node ID with expandable raw hex and launch-to-composer actions.
class MrrpServiceBrowserScreen extends ConsumerWidget {
  const MrrpServiceBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cachedServices = ref.watch(mrrpCachedServicesProvider);

    AppLogging.mrrpHarness(
      'MRRP_HARNESS: service browser — '
      '${cachedServices.length} peers, '
      '${cachedServices.values.fold<int>(0, (s, l) => s + l.length)} '
      'services total', // lint-allow: hardcoded-string
    );

    final peerIds = cachedServices.keys.toList()..sort();
    final isEmpty = peerIds.isEmpty;

    // lint-allow: haptic-feedback — keyboard dismissal, not interactive action
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: l10n.mrrpHarnessServiceBrowserTitle,
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
                            Icons.dns_outlined,
                            size: 64,
                            color: context.textTertiary,
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          Text(
                            l10n.mrrpHarnessNoServices,
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
            : _buildServiceSlivers(context, ref, peerIds, cachedServices),
      ),
    );
  }

  List<Widget> _buildServiceSlivers(
    BuildContext context,
    WidgetRef ref,
    List<int> peerIds,
    Map<int, List<MrrpCachedService>> cachedServices,
  ) {
    final slivers = <Widget>[];

    for (final peerId in peerIds) {
      final services = cachedServices[peerId] ?? [];
      if (services.isEmpty) continue;

      final nodeHex =
          '0x${peerId.toRadixString(16).padLeft(8, '0').toUpperCase()}';

      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(title: nodeHex),
        ),
      );

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing4,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final svc = services[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    border: Border.all(
                      color: context.border.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      onTap: () {
                        ref
                            .read(hapticServiceProvider)
                            .trigger(HapticType.light);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MrrpRequestComposerScreen(
                              initialPeerNodeId: peerId,
                              initialServiceId: svc.descriptor.serviceId,
                            ),
                          ),
                        );
                      },
                      child: MrrpServiceTile(
                        descriptor: svc.descriptor,
                        cachedAt: svc.cachedAt,
                        isExpired: svc.isExpired,
                      ),
                    ),
                  ),
                ),
              );
            }, childCount: services.length),
          ),
        ),
      );
    }

    return slivers;
  }
}
