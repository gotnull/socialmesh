// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Animated scanning empty state for the Mesh Explorer nearby section.
///
/// Shown when the radio is connected but no peers have been discovered yet.
/// Uses [AnimatedEmptyState] for a consistent, radar-pulse scanning feel.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/widgets/animated_empty_state.dart';

/// Animated scanning state displayed while no SIP peers are visible.
class MeshExplorerScanningEmptyState extends StatelessWidget {
  const MeshExplorerScanningEmptyState({
    super.key,
    required this.onScan,
    this.scanEnabled = true,
    this.scanDisabledReason,
  });

  final VoidCallback onScan;
  final bool scanEnabled;
  final String? scanDisabledReason;

  static const _icons = [
    Icons.sensors,
    Icons.wifi_find,
    Icons.radar,
    Icons.people_outline,
    Icons.explore_outlined,
    Icons.person_search,
    Icons.network_check,
    Icons.cell_tower,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final taglines = [
      l10n.meshExplorerScanningTagline1,
      l10n.meshExplorerScanningTagline2,
      l10n.meshExplorerScanningTagline3,
      l10n.meshExplorerScanningTagline4,
    ];

    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: _icons,
        taglines: taglines,
        titlePrefix: l10n.meshExplorerScanningTitlePrefix,
        titleKeyword: l10n.meshExplorerScanningTitleKeyword,
        titleSuffix: l10n.meshExplorerScanningTitleSuffix,
        actionLabel: l10n.meshExplorerScanningAction,
        actionIcon: Icons.sensors,
        onAction: onScan,
        actionEnabled: scanEnabled,
        actionDisabledReason: scanDisabledReason,
      ),
    );
  }
}
