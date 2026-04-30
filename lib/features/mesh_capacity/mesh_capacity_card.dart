// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Mesh Capacity Advisor card.
//
// Reads [meshCapacitySnapshotProvider] + [meshCapacityCardVisibleProvider]
// and renders a [StatusBanner] tuned to the recommendation severity.
// Tapping the card opens [MeshCapacityExplanationSheet]. The dismiss
// (×) button suppresses the current `reasonCode` for the session via
// [meshCapacityDismissalProvider].
//
// The widget never mutates radio state. It can navigate to the radio
// settings screen — that path lives in the explanation sheet, not the
// card itself, so there is no one-tap "change preset" affordance.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_banner.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/mesh_capacity_provider.dart';
import '../../services/mesh_capacity/mesh_capacity_models.dart';
import 'mesh_capacity_explanation_sheet.dart';

class MeshCapacityCard extends ConsumerWidget {
  const MeshCapacityCard({super.key, this.sourceSurface = 'mesh_explorer'});

  /// Surface name used for telemetry log lines (e.g. `mesh_explorer`).
  final String sourceSurface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(meshCapacityCardVisibleProvider);
    if (!visible) return const SizedBox.shrink();

    final snapshot = ref.watch(meshCapacitySnapshotProvider);
    final l10n = context.l10n;
    final reason = snapshot.recommendation.reasonCode;
    final severity = snapshot.recommendation.severity;
    final title = _titleFor(l10n, snapshot);
    final subtitle = _subtitleFor(l10n, snapshot);

    AppLogging.meshCapacity(
      'card shown reasonCode=${reason.name} '
      'pressureLevel=${snapshot.pressureLevel.name} '
      'currentPreset=${snapshot.currentModemPreset?.name ?? 'unknown'} '
      'sourceSurface=$sourceSurface',
    );

    final banner = _bannerForSeverity(
      severity: severity,
      title: title,
      subtitle: subtitle,
      onTap: () {
        AppLogging.meshCapacity(
          'explanation opened reasonCode=${reason.name} '
          'sourceSurface=$sourceSurface',
        );
        MeshCapacityExplanationSheet.show(
          context: context,
          snapshot: snapshot,
          sourceSurface: sourceSurface,
        );
      },
      onDismiss: () {
        ref.read(meshCapacityDismissalProvider.notifier).dismiss(reason);
      },
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing16,
        AppTheme.spacing4,
      ),
      child: banner,
    );
  }

  StatusBanner _bannerForSeverity({
    required MeshCapacityRecommendationSeverity severity,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required VoidCallback onDismiss,
  }) {
    switch (severity) {
      case MeshCapacityRecommendationSeverity.warning:
        return StatusBanner.warning(
          title: title,
          subtitle: subtitle,
          icon: Icons.cell_tower_outlined,
          onTap: onTap,
          onDismiss: onDismiss,
        );
      case MeshCapacityRecommendationSeverity.advisory:
        return StatusBanner.warning(
          title: title,
          subtitle: subtitle,
          icon: Icons.network_check,
          onTap: onTap,
          onDismiss: onDismiss,
        );
      case MeshCapacityRecommendationSeverity.info:
      case MeshCapacityRecommendationSeverity.none:
        return StatusBanner.info(
          title: title,
          subtitle: subtitle,
          icon: Icons.info_outline,
          onTap: onTap,
          onDismiss: onDismiss,
        );
    }
  }

  String _titleFor(AppLocalizations l10n, MeshCapacitySnapshot snapshot) {
    if (snapshot.recommendation.reasonCode ==
        MeshCapacityReasonCode.presetUnknown) {
      return l10n.meshCapacityCardTitlePresetUnknown;
    }
    switch (snapshot.pressureLevel) {
      case MeshCapacityPressureLevel.capacityLimited:
        return l10n.meshCapacityCardTitleCapacityLimited;
      case MeshCapacityPressureLevel.congested:
        return l10n.meshCapacityCardTitleCongested;
      case MeshCapacityPressureLevel.busy:
      case MeshCapacityPressureLevel.healthy:
      case MeshCapacityPressureLevel.unknown:
        return l10n.meshCapacityCardTitleBusy;
    }
  }

  String _subtitleFor(AppLocalizations l10n, MeshCapacitySnapshot snapshot) {
    if (snapshot.recommendation.reasonCode ==
        MeshCapacityReasonCode.presetUnknown) {
      return l10n.meshCapacityCardSubtitlePresetUnknown;
    }
    final count = snapshot.activeRfNodes15m;
    switch (snapshot.pressureLevel) {
      case MeshCapacityPressureLevel.capacityLimited:
        return l10n.meshCapacityCardSubtitleCapacityLimited(count);
      case MeshCapacityPressureLevel.congested:
        return l10n.meshCapacityCardSubtitleCongested(count);
      case MeshCapacityPressureLevel.busy:
      case MeshCapacityPressureLevel.healthy:
      case MeshCapacityPressureLevel.unknown:
        return l10n.meshCapacityCardSubtitleBusy(count);
    }
  }
}
