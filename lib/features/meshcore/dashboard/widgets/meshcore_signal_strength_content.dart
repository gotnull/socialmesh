// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../models/meshcore_contact.dart';
import '../../../../providers/meshcore_providers.dart';

/// MeshCore-flavoured equivalent of `SignalStrengthContent`. Meshtastic
/// has a continuous RSSI stream from the active radio; MeshCore peers
/// don't expose per-link RSSI to the companion radio, so we aggregate
/// the per-contact SNR values carried in advert frames instead. Shows:
///   - the median SNR across contacts that carry an SNR
///   - the best and worst contact SNR
///   - counts of "strong" / "weak" links by LoRa SNR band
class MeshCoreSignalStrengthContent extends ConsumerWidget {
  const MeshCoreSignalStrengthContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contactsState = ref.watch(meshCoreContactsProvider);

    final contactsWithSnr = contactsState.contacts
        .where((c) => c.snrDb != null)
        .toList();

    if (contactsWithSnr.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.signal_cellular_off_rounded,
              size: 32,
              color: context.textTertiary,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              l10n.meshcoreWidgetSignalEmpty,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final sortedSnrs = contactsWithSnr.map((c) => c.snrDb!).toList()..sort();
    final median = sortedSnrs[sortedSnrs.length ~/ 2];
    final best = sortedSnrs.last;
    final worst = sortedSnrs.first;
    final strongCount = contactsWithSnr.where((c) => c.snrDb! >= -7).length;
    final weakCount = contactsWithSnr.where((c) => c.snrDb! < -12).length;
    final medianColor = _snrColor(median);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        children: [
          // Median SNR gauge - circular indicator using SNR-to-percentage
          // mapping (0 dB = 100%, -20 dB = 0%, linear interpolation).
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    backgroundColor: context.border,
                    valueColor: AlwaysStoppedAnimation(
                      context.border.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: _snrToPercent(median) / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(medianColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${median.toStringAsFixed(1)} dB',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: medianColor,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    Text(
                      l10n.meshcoreWidgetSignalMedianLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: medianColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SignalStat(
                icon: Icons.trending_up_rounded,
                label: l10n.meshcoreWidgetSignalBestLabel,
                value: '${best.toStringAsFixed(1)} dB',
                color: _snrColor(best),
              ),
              _SignalStat(
                icon: Icons.bolt_rounded,
                label: l10n.meshcoreWidgetSignalStrongLabel,
                value: '$strongCount/${contactsWithSnr.length}',
                color: AccentColors.green,
              ),
              _SignalStat(
                icon: Icons.trending_down_rounded,
                label: l10n.meshcoreWidgetSignalWorstLabel,
                value: '${worst.toStringAsFixed(1)} dB',
                color: _snrColor(worst),
              ),
              _SignalStat(
                icon: Icons.warning_amber_rounded,
                label: l10n.meshcoreWidgetSignalWeakLabel,
                value: '$weakCount',
                color: weakCount > 0
                    ? AppTheme.warningYellow
                    : context.textTertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // SNR-to-percentage mapping matches the LoRa band thresholds used
  // for the per-contact SNR badge: 0 dB caps to 100%, -20 dB floors to
  // 0%, linear interpolation in between.
  double _snrToPercent(double snrDb) {
    final clamped = snrDb.clamp(-20.0, 0.0);
    return ((clamped + 20) / 20 * 100).clamp(0.0, 100.0);
  }

  Color _snrColor(double snrDb) {
    if (snrDb >= 0) return AccentColors.green;
    if (snrDb >= -7) return AccentColors.cyan;
    if (snrDb >= -12) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }
}

class _SignalStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SignalStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
        ),
      ],
    );
  }
}

// Keep the per-contact tuple shape testable by other surfaces. Not
// exposed externally yet but provided so widget tests in follow-up
// slices can verify the aggregation without rendering the full widget.
@visibleForTesting
({double median, double best, double worst, int strongCount, int weakCount})
meshCoreSignalAggregateForTesting(List<MeshCoreContact> contacts) {
  final withSnr = contacts.where((c) => c.snrDb != null).toList();
  final snrs = withSnr.map((c) => c.snrDb!).toList()..sort();
  return (
    median: snrs.isEmpty ? 0.0 : snrs[snrs.length ~/ 2],
    best: snrs.isEmpty ? 0.0 : snrs.last,
    worst: snrs.isEmpty ? 0.0 : snrs.first,
    strongCount: withSnr.where((c) => c.snrDb! >= -7).length,
    weakCount: withSnr.where((c) => c.snrDb! < -12).length,
  );
}
