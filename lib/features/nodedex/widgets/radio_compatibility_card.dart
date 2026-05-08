// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Radio Compatibility Card — NodeDex detail-screen surface that compares
// the local radio's current preset / frequency offset against the values
// stamped on the entry's last observation, plus surfaces the latest
// observation's transport classification (direct RF, MQTT, relayed).
//
// Pure logic lives in services/radio_compatibility.dart. The provider
// in providers/nodedex_radio_compatibility_provider.dart joins the four
// inputs into a NodeDexRadioCompatibilitySummary; this widget renders.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/app_localizations.dart';
import '../models/observation_source.dart';
import '../models/observed_radio_preset.dart';
import '../providers/nodedex_radio_compatibility_provider.dart';
import '../services/radio_compatibility.dart';

/// NodeDex detail-screen card that surfaces radio compatibility context.
///
/// Hidden entirely for the user's own connected node (the surface
/// would compare a node to itself). For all other states the card
/// renders an InfoTable with at least the Reachability row so the user
/// gets explicit feedback even when comparison is impossible.
class RadioCompatibilityCard extends ConsumerWidget {
  final int nodeNum;

  const RadioCompatibilityCard({super.key, required this.nodeNum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(nodeDexRadioCompatibilityProvider(nodeNum));
    if (summary == null) return const SizedBox.shrink();

    // Self node: hide the entire card. Reachability vs. self has no
    // meaning and would clutter the detail screen.
    if (summary.status == NodeDexReachabilityStatus.selfNode) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final rows = _buildRows(summary, l10n);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing4,
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(
          color: context.border.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: l10n.nodedexRadioCompatibilityTitle,
            leadingIcon: Icons.radio_outlined,
          ),
          InfoTable(rows: rows),
        ],
      ),
    );
  }

  List<InfoTableRow> _buildRows(
    NodeDexRadioCompatibilitySummary summary,
    AppLocalizations l10n,
  ) {
    final rows = <InfoTableRow>[];

    // Reachability is always present — even when comparison is
    // impossible we surface an explicit row so the user gets feedback
    // rather than wondering why nothing rendered.
    rows.add(
      InfoTableRow(
        label: l10n.nodedexReachabilityLabel,
        value: _statusLabel(summary.status, l10n),
        icon: _statusIcon(summary.status),
        iconColor: _statusColor(summary.status),
      ),
    );

    // Local radio preset (right now) — only meaningful when a radio is
    // connected. Skipped for localRadioUnknown so the card doesn't
    // claim a preset we don't have.
    if (summary.localPresetNow != null) {
      final localPresetLabel =
          ObservedRadioPreset.fromProtobufValue(
            summary.localPresetNow,
          )?.label(l10n) ??
          l10n.nodedexRadioPresetUnknown;
      rows.add(
        InfoTableRow(
          label: l10n.nodedexLocalPresetNow,
          value: localPresetLabel,
          icon: Icons.settings_input_antenna_outlined,
        ),
      );
    }

    // Last observed on preset — the local preset that was active when
    // we last heard this node. Different from "your radio preset" only
    // when the local radio has changed since the last observation.
    if (summary.lastObservedOnPreset != null) {
      final observedPresetLabel =
          ObservedRadioPreset.fromProtobufValue(
            summary.lastObservedOnPreset,
          )?.label(l10n) ??
          l10n.nodedexRadioPresetUnknown;
      rows.add(
        InfoTableRow(
          label: l10n.nodedexLastObservedPreset,
          value: observedPresetLabel,
          icon: Icons.history_outlined,
        ),
      );
    }

    // Frequency offset (only when non-zero on either side; suppressing
    // 0.0 matches the existing "Freq Offset" row's policy).
    if (summary.lastObservedFrequencyOffset != null &&
        summary.lastObservedFrequencyOffset != 0.0) {
      rows.add(
        InfoTableRow(
          label: l10n.nodedexFrequencyOffset,
          value: l10n.nodedexFrequencyOffsetValue(
            summary.lastObservedFrequencyOffset!.toStringAsFixed(1),
          ),
          icon: Icons.tune_outlined,
        ),
      );
    }

    // Observation source (Direct RF / MQTT / Relayed RF / etc).
    if (summary.observationSource != null) {
      rows.add(
        InfoTableRow(
          label: l10n.nodedexObservationSourceLabel,
          value: summary.observationSource!.label(l10n),
          icon: _sourceIcon(summary.observationSource!),
        ),
      );
    }

    // Hops away. 0 → "Direct"; >0 → "N hop(s)".
    if (summary.hopsAway != null) {
      rows.add(
        InfoTableRow(
          label: l10n.nodedexHopsAwayLabel,
          value: l10n.nodedexHopsAwayValue(summary.hopsAway!),
          icon: Icons.alt_route_outlined,
        ),
      );
    }

    return rows;
  }

  String _statusLabel(NodeDexReachabilityStatus status, AppLocalizations l10n) {
    switch (status) {
      case NodeDexReachabilityStatus.likelyReachableOnRf:
        return l10n.nodedexReachabilityLikelyOnRf;
      case NodeDexReachabilityStatus.differentPreset:
        return l10n.nodedexReachabilityDifferentPreset;
      case NodeDexReachabilityStatus.differentFrequencyOffset:
        return l10n.nodedexReachabilityDifferentFrequencyOffset;
      case NodeDexReachabilityStatus.indirectOrMqttObservation:
        return l10n.nodedexReachabilityIndirectOrMqtt;
      case NodeDexReachabilityStatus.localRadioUnknown:
        return l10n.nodedexReachabilityLocalRadioUnknown;
      case NodeDexReachabilityStatus.unknown:
        return l10n.nodedexReachabilityUnknown;
      case NodeDexReachabilityStatus.selfNode:
        return l10n.nodedexReachabilitySelf;
    }
  }

  IconData _statusIcon(NodeDexReachabilityStatus status) {
    switch (status) {
      case NodeDexReachabilityStatus.likelyReachableOnRf:
        return Icons.check_circle_outline;
      case NodeDexReachabilityStatus.differentPreset:
      case NodeDexReachabilityStatus.differentFrequencyOffset:
        return Icons.warning_amber_outlined;
      case NodeDexReachabilityStatus.indirectOrMqttObservation:
        return Icons.alt_route_outlined;
      case NodeDexReachabilityStatus.localRadioUnknown:
        return Icons.power_off_outlined;
      case NodeDexReachabilityStatus.unknown:
        return Icons.help_outline;
      case NodeDexReachabilityStatus.selfNode:
        return Icons.smartphone_outlined;
    }
  }

  Color _statusColor(NodeDexReachabilityStatus status) {
    switch (status) {
      case NodeDexReachabilityStatus.likelyReachableOnRf:
        return AccentColors.green;
      case NodeDexReachabilityStatus.differentPreset:
        return AccentColors.orange;
      case NodeDexReachabilityStatus.differentFrequencyOffset:
        return AccentColors.yellow;
      case NodeDexReachabilityStatus.indirectOrMqttObservation:
        return AccentColors.red;
      case NodeDexReachabilityStatus.localRadioUnknown:
      case NodeDexReachabilityStatus.unknown:
      case NodeDexReachabilityStatus.selfNode:
        return AppTheme.textTertiary;
    }
  }

  IconData _sourceIcon(ObservationSource source) {
    switch (source) {
      case ObservationSource.directRf:
        return Icons.cell_tower;
      case ObservationSource.mqtt:
        return Icons.cloud_outlined;
      case ObservationSource.indirectRf:
        return Icons.alt_route_outlined;
      case ObservationSource.nodeDb:
        return Icons.sync_outlined;
      case ObservationSource.unknown:
        return Icons.help_outline;
    }
  }
}
