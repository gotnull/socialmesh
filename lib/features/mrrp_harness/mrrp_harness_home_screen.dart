// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/section_header.dart';
import '../../providers/app_providers.dart';
import '../../providers/mrrp_providers.dart';
import '../../providers/sip_providers.dart';
import '../../services/haptic_service.dart';
import 'mrrp_fixture_replay_screen.dart';
import 'mrrp_peer_inspector_screen.dart';
import 'mrrp_qa_runner_screen.dart';
import 'mrrp_request_composer_screen.dart';
import 'mrrp_service_browser_screen.dart';
import 'mrrp_simulated_peer_lab_screen.dart';
import 'mrrp_traffic_console_screen.dart';

/// MRRP Protocol Harness home screen.
///
/// Shows protocol status, connected radio state, SIP peer count,
/// registered MRRP services, budget usage, and quick action buttons.
class MrrpHarnessHomeScreen extends ConsumerStatefulWidget {
  const MrrpHarnessHomeScreen({super.key});

  @override
  ConsumerState<MrrpHarnessHomeScreen> createState() =>
      _MrrpHarnessHomeScreenState();
}

class _MrrpHarnessHomeScreenState extends ConsumerState<MrrpHarnessHomeScreen> {
  String _lastLogSignature = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sipEnabled = ref.watch(sipEnabledProvider);
    final mrrpEnabled = ref.watch(mrrpEnabledProvider);
    final peerCount = ref.watch(sipPeerCountProvider);
    final registry = ref.watch(mrrpServiceRegistryProvider);
    final serviceCount = registry?.count ?? 0;
    final rateLimiter = ref.read(sipRateLimiterProvider);
    final isConnected = ref.watch(
      transportProvider.select((t) => t.state == DeviceConnectionState.connected),
    );
    final cachedServices = ref.watch(mrrpCachedServicesProvider);
    final remotePeerCount = cachedServices.length;

    // Deduplicate identical log lines across rebuilds.
    final sig =
        '$sipEnabled|$mrrpEnabled|$peerCount|$serviceCount'; // lint-allow: hardcoded-string
    if (sig != _lastLogSignature) {
      _lastLogSignature = sig;
      AppLogging.mrrpHarness(
        'MRRP_HARNESS: home build — sip=$sipEnabled, mrrp=$mrrpEnabled, '
        'peers=$peerCount, services=$serviceCount', // lint-allow: hardcoded-string
      );
    }

    // lint-allow: haptic-feedback — keyboard dismissal, not interactive action
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: l10n.mrrpHarnessTitle,
        slivers: [
          // --- Protocol Status section ---
          SliverPersistentHeader(
            pinned: true,
            delegate: SectionHeaderDelegate(
              title: l10n.mrrpHarnessSectionStatus,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _StatusRow(
                  icon: Icons.wifi_tethering,
                  label: l10n.mrrpHarnessStatusSip,
                  value: sipEnabled
                      ? l10n.mrrpHarnessStatusEnabled
                      : l10n.mrrpHarnessStatusDisabled,
                  valueColor: sipEnabled
                      ? SemanticColors.success
                      : SemanticColors.error,
                ),
                _StatusRow(
                  icon: Icons.hub,
                  label: l10n.mrrpHarnessStatusMrrp,
                  value: mrrpEnabled
                      ? l10n.mrrpHarnessStatusEnabled
                      : l10n.mrrpHarnessStatusDisabled,
                  valueColor: mrrpEnabled
                      ? SemanticColors.success
                      : SemanticColors.error,
                ),
                _StatusRow(
                  icon: Icons.bluetooth,
                  label: l10n.mrrpHarnessRadioState,
                  value: isConnected
                      ? l10n.mrrpHarnessRadioConnected
                      : l10n.mrrpHarnessRadioDisconnected,
                  valueColor: isConnected
                      ? SemanticColors.success
                      : SemanticColors.muted,
                ),
                _StatusRow(
                  icon: Icons.people,
                  label: l10n.mrrpHarnessSipPeers,
                  value:
                      '$peerCount ($remotePeerCount MRRP)', // lint-allow: hardcoded-string
                ),
                _StatusRow(
                  icon: Icons.extension,
                  label: l10n.mrrpHarnessMrrpServices,
                  value: '$serviceCount',
                ),
                _StatusRow(
                  icon: Icons.speed,
                  label: l10n.mrrpHarnessBudget,
                  value: l10n.mrrpHarnessBudgetValue(
                    rateLimiter.remainingBytes,
                    rateLimiter.capacity,
                  ),
                ),
              ]),
            ),
          ),

          // --- Quick Actions section ---
          SliverPersistentHeader(
            pinned: true,
            delegate: SectionHeaderDelegate(
              title: l10n.mrrpHarnessSectionActions,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing8,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ActionButton(
                  icon: Icons.search,
                  label: l10n.mrrpHarnessScanPeers,
                  onTap: () {
                    ref.read(hapticServiceProvider).trigger(HapticType.light);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MrrpPeerInspectorScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppTheme.spacing8),
                _ActionButton(
                  icon: Icons.dns,
                  label: l10n.mrrpHarnessBrowseServices,
                  onTap: () {
                    ref.read(hapticServiceProvider).trigger(HapticType.light);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MrrpServiceBrowserScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppTheme.spacing8),
                _ActionButton(
                  icon: Icons.send,
                  label: l10n.mrrpHarnessOpenComposer,
                  onTap: () {
                    ref.read(hapticServiceProvider).trigger(HapticType.light);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MrrpRequestComposerScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppTheme.spacing8),
                _ActionButton(
                  icon: Icons.monitor_heart,
                  label: l10n.mrrpHarnessOpenTraffic,
                  onTap: () {
                    ref.read(hapticServiceProvider).trigger(HapticType.light);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MrrpTrafficConsoleScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppTheme.spacing8),
                _ActionButton(
                  icon: Icons.smart_toy,
                  label: l10n.mrrpHarnessOpenSimLab,
                  onTap: () {
                    ref.read(hapticServiceProvider).trigger(HapticType.light);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MrrpSimulatedPeerLabScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppTheme.spacing8),
                _ActionButton(
                  icon: Icons.science,
                  label: l10n.mrrpHarnessOpenFixtures,
                  onTap: () {
                    ref.read(hapticServiceProvider).trigger(HapticType.light);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MrrpFixtureReplayScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppTheme.spacing8),
                _ActionButton(
                  icon: Icons.playlist_play,
                  label: l10n.mrrpHarnessOpenQaRunner,
                  onTap: () {
                    ref.read(hapticServiceProvider).trigger(HapticType.light);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MrrpQaRunnerScreen(),
                      ),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single status row showing icon, label, and value.
class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.textSecondary),
          const SizedBox(width: AppTheme.spacing12),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: valueColor ?? context.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A quick action button.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(AppTheme.radius12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing14,
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: context.accentColor),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, size: 20, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
