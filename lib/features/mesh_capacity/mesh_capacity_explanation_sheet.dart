// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Mesh Capacity Advisor explanation sheet.
//
// Bottom sheet that explains why preset choice matters, surfaces the
// user's current snapshot (active RF nodes / current preset / suggested
// preset), and exposes a single "Open radio settings" entry point so
// the user can change the preset themselves with the existing tested
// confirmation flow on RadioConfigScreen. The sheet never writes to
// the device — it only navigates.

import 'package:flutter/material.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/meshtastic/modem_preset_metadata.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/section_header.dart';
import '../../l10n/app_localizations.dart';
import '../../services/mesh_capacity/mesh_capacity_models.dart';
import '../settings/radio_config_screen.dart';

class MeshCapacityExplanationSheet extends StatelessWidget {
  const MeshCapacityExplanationSheet({
    super.key,
    required this.snapshot,
    required this.scrollController,
    required this.sourceSurface,
  });

  final MeshCapacitySnapshot snapshot;
  final ScrollController scrollController;
  final String sourceSurface;

  static Future<void> show({
    required BuildContext context,
    required MeshCapacitySnapshot snapshot,
    required String sourceSurface,
  }) {
    return AppBottomSheet.showScrollable<void>(
      context: context,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      title: context.l10n.meshCapacitySheetTitle,
      builder: (controller) => MeshCapacityExplanationSheet(
        snapshot: snapshot,
        scrollController: controller,
        sourceSurface: sourceSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preset = snapshot.currentModemPreset;
    final presetMetadata = preset == null
        ? null
        : modemPresetMetadataFor(preset);
    final suggestedPreset = snapshot.recommendation.suggestedPreset;
    final suggestedMetadata = suggestedPreset == null
        ? null
        : modemPresetMetadataFor(suggestedPreset);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing24,
        AppTheme.spacing0,
        AppTheme.spacing24,
        AppTheme.spacing24,
      ),
      children: [
        Text(
          l10n.meshCapacitySheetIntro,
          style: context.bodyStyle?.copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: AppTheme.spacing16),
        Text(
          l10n.meshCapacitySheetTradeoff,
          style: context.bodyStyle?.copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: AppTheme.spacing24),

        SectionTitle(title: l10n.meshCapacitySheetSnapshotHeader),
        const SizedBox(height: AppTheme.spacing8),
        InfoTable(
          rows: [
            InfoTableRow(
              label: l10n.meshCapacitySheetCurrentPresetLabel,
              value: presetMetadata != null
                  ? presetMetadata.label(l10n)
                  : l10n.meshCapacitySheetPresetUnknownValue,
            ),
            InfoTableRow(
              label: l10n.meshCapacitySheetActiveNodes5mLabel,
              value: '${snapshot.activeRfNodes5m}',
            ),
            InfoTableRow(
              label: l10n.meshCapacitySheetActiveNodes15mLabel,
              value: '${snapshot.activeRfNodes15m}',
            ),
            InfoTableRow(
              label: l10n.meshCapacitySheetActiveNodes60mLabel,
              value: '${snapshot.activeRfNodes60m}',
            ),
            InfoTableRow(
              label: l10n.meshCapacitySheetTotalKnownLabel,
              value: '${snapshot.totalKnownNodes}',
            ),
            InfoTableRow(
              label: l10n.meshCapacitySheetPressureLabel,
              value: _pressureLabel(l10n, snapshot.pressureLevel),
            ),
            if (suggestedMetadata != null)
              InfoTableRow(
                label: l10n.meshCapacitySheetSuggestedPresetLabel,
                value: suggestedMetadata.label(l10n),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing24),

        SectionTitle(title: l10n.meshCapacitySheetRiskHeader),
        const SizedBox(height: AppTheme.spacing8),
        Text(
          l10n.meshCapacitySheetRiskBody,
          style: context.bodyStyle?.copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: AppTheme.spacing24),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              AppLogging.meshCapacity(
                'radio settings opened from advisor '
                'reasonCode=${snapshot.recommendation.reasonCode.name} '
                'sourceSurface=$sourceSurface',
              );
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RadioConfigScreen(),
                ),
              );
            },
            icon: const Icon(Icons.settings_input_antenna, size: 18),
            label: Text(l10n.meshCapacitySheetOpenSettings),
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.meshCapacitySheetClose),
          ),
        ),
      ],
    );
  }

  String _pressureLabel(
    AppLocalizations l10n,
    MeshCapacityPressureLevel level,
  ) {
    switch (level) {
      case MeshCapacityPressureLevel.unknown:
        return l10n.meshCapacityPressureUnknown;
      case MeshCapacityPressureLevel.healthy:
        return l10n.meshCapacityPressureHealthy;
      case MeshCapacityPressureLevel.busy:
        return l10n.meshCapacityPressureBusy;
      case MeshCapacityPressureLevel.congested:
        return l10n.meshCapacityPressureCongested;
      case MeshCapacityPressureLevel.capacityLimited:
        return l10n.meshCapacityPressureCapacityLimited;
    }
  }
}
