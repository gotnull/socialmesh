// SPDX-License-Identifier: GPL-3.0-or-later

/// Discovery Source Filter Chips — Local/Remote/Mixed toggles for the
/// NodeDex screen filter bar.
///
/// These chips allow users to filter the NodeDex entry list by how
/// nodes were discovered:
/// - Local: discovered via the local mesh radio (BLE/USB → LoRa)
/// - Remote: discovered via the Global Layer MQTT broker
/// - Mixed: discovered via both local mesh and Global Layer
///
/// The chips are only shown when the Global Layer is set up and
/// remote sightings recording is enabled. When no remote sightings
/// exist, the chips are hidden to avoid confusing users who have
/// not configured the Global Layer.
///
/// Usage:
/// ```dart
/// DiscoverySourceFilterRow()
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mqtt/mqtt_remote_sighting.dart';
import '../../../core/theme.dart';
import '../../../providers/mqtt_nodedex_providers.dart';

/// A row of filter chips for discovery source filtering in the NodeDex.
///
/// Automatically hides itself when remote sightings are not enabled
/// or when no remote sightings have been recorded, to keep the UI
/// clean for users who are not using the Global Layer.
class DiscoverySourceFilterRow extends ConsumerWidget {
  const DiscoverySourceFilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(remoteSightingsEnabledProvider);
    final sightingCount = ref.watch(remoteSightingCountProvider);

    // Hide entirely when remote sightings are not enabled or empty
    if (!isEnabled || sightingCount == 0) return const SizedBox.shrink();

    final currentFilter = ref.watch(discoverySourceFilterProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _DiscoverySourceChip(
              source: null,
              label: 'All Sources',
              icon: Icons.layers_outlined,
              isSelected: currentFilter == null,
              onTap: () {
                ref.read(discoverySourceFilterProvider.notifier).clear();
              },
            ),
            const SizedBox(width: 8),
            _DiscoverySourceChip(
              source: NodeDiscoverySource.local,
              label: NodeDiscoverySource.local.displayLabel,
              icon: Icons.cell_tower,
              isSelected: currentFilter == NodeDiscoverySource.local,
              onTap: () {
                ref
                    .read(discoverySourceFilterProvider.notifier)
                    .toggle(NodeDiscoverySource.local);
              },
            ),
            const SizedBox(width: 8),
            _DiscoverySourceChip(
              source: NodeDiscoverySource.remote,
              label: NodeDiscoverySource.remote.displayLabel,
              icon: Icons.cloud_outlined,
              isSelected: currentFilter == NodeDiscoverySource.remote,
              count: sightingCount,
              onTap: () {
                ref
                    .read(discoverySourceFilterProvider.notifier)
                    .toggle(NodeDiscoverySource.remote);
              },
            ),
            const SizedBox(width: 8),
            _DiscoverySourceChip(
              source: NodeDiscoverySource.mixed,
              label: NodeDiscoverySource.mixed.displayLabel,
              icon: Icons.sync_alt,
              isSelected: currentFilter == NodeDiscoverySource.mixed,
              onTap: () {
                ref
                    .read(discoverySourceFilterProvider.notifier)
                    .toggle(NodeDiscoverySource.mixed);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A single discovery source filter chip.
///
/// Displays the source label, an icon, and an optional count badge.
/// Tapping toggles the filter — tapping the already-selected chip
/// clears the filter back to "All Sources".
class _DiscoverySourceChip extends StatelessWidget {
  final NodeDiscoverySource? source;
  final String label;
  final IconData icon;
  final bool isSelected;
  final int? count;
  final VoidCallback onTap;

  const _DiscoverySourceChip({
    required this.source,
    required this.label,
    required this.icon,
    required this.isSelected,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorForSource(source, context);
    final selectedBg = color.withValues(alpha: 0.15);
    final selectedBorder = color.withValues(alpha: 0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : context.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? selectedBorder : context.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? color : context.textTertiary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? color : context.textSecondary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.2)
                        : context.textTertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _compactCount(count!),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : context.textTertiary,
                      fontFamily: AppTheme.fontFamily,
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

  Color _colorForSource(NodeDiscoverySource? source, BuildContext context) {
    if (source == null) return context.accentColor;
    return switch (source) {
      NodeDiscoverySource.local => AppTheme.successGreen,
      NodeDiscoverySource.remote => const Color(0xFF38BDF8),
      NodeDiscoverySource.mixed => AppTheme.warningYellow,
    };
  }

  String _compactCount(int n) {
    if (n < 1000) return n.toString();
    if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '${(n / 1000).toStringAsFixed(0)}k';
  }
}

/// A compact inline badge showing the discovery source count in
/// the NodeDex stats card.
///
/// Shows a small "N remote" or "N mixed" indicator that links to
/// the discovery source filter when tapped.
class DiscoverySourceStatBadge extends ConsumerWidget {
  const DiscoverySourceStatBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(remoteSightingsEnabledProvider);
    final stats = ref.watch(remoteSightingStatsProvider);

    if (!isEnabled || !stats.hasData) return const SizedBox.shrink();

    return Tooltip(
      message: '${stats.uniqueNodes} nodes seen via Global Layer',
      child: InkWell(
        onTap: () {
          ref
              .read(discoverySourceFilterProvider.notifier)
              .toggle(NodeDiscoverySource.remote);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_outlined,
                size: 12,
                color: Color(0xFF38BDF8),
              ),
              const SizedBox(width: 4),
              Text(
                '${stats.uniqueNodes} remote',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF38BDF8),
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              if (stats.recentSightings > 0) ...[
                const SizedBox(width: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.successGreen,
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
