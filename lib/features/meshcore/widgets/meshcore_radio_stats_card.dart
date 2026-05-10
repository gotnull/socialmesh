// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D35-A: MeshCore companion-radio stats Tools card.
//
// Surfaces the firmware-backed RADIO subtype (`STATS_TYPE_RADIO`)
// fetched via `CMD_GET_STATS` (0x38). Polls at 1 Hz while mounted via
// `meshCoreRadioStatsProvider`. The fetch path bypasses the D34a chat
// rate limiter, so polling does NOT compete with chat airtime.
//
// Privacy: the card NEVER renders pubkeys, MMFs, channel names, raw
// payloads, message plaintext, or envelope content. Only typed
// numeric values from the firmware: noise floor (dBm), last RSSI
// (dBm), last SNR (dB), TX/RX airtime (Duration). Pinned by the
// widget redaction sweep in `d35_radio_stats_card_test.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/protocol/meshcore_messages.dart';

class MeshCoreRadioStatsCard extends ConsumerWidget {
  const MeshCoreRadioStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final snapshot = ref.watch(meshCoreRadioStatsProvider);
    final core = ref.watch(meshCoreCoreStatsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing4,
      ),
      child: Container(
        key: const ValueKey('meshcore-radio-stats-card'),
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              title: l10n.meshcoreRadioStatsTitle,
              leadingIcon: Icons.cell_tower_rounded,
            ),
            _Body(snapshot: snapshot, core: core, l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final MeshCoreRadioStatsSnapshot snapshot;
  final MeshCoreCoreStatsSnapshot core;
  final AppLocalizations l10n;

  const _Body({required this.snapshot, required this.core, required this.l10n});

  @override
  Widget build(BuildContext context) {
    if (!snapshot.isConnected) {
      return _Placeholder(
        key: const ValueKey('meshcore-radio-stats-no-session'),
        icon: Icons.link_off_rounded,
        text: l10n.meshcoreRadioStatsNoSession,
      );
    }
    final latest = snapshot.latest;
    if (latest == null) {
      return _Placeholder(
        key: const ValueKey('meshcore-radio-stats-fetching'),
        icon: Icons.hourglass_empty_rounded,
        text: l10n.meshcoreRadioStatsFetching,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (snapshot.isStale)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
            child: _StaleHint(label: l10n.meshcoreRadioStatsStale),
          ),
        Opacity(
          opacity: snapshot.isStale ? 0.55 : 1.0,
          child: InfoTable(rows: _buildRows(latest)),
        ),
        const SizedBox(height: AppTheme.spacing8),
        _ResetNote(label: l10n.meshcoreRadioStatsAirtimeResetNote),
        if (_visibleErrorFlags() != null) ...[
          const SizedBox(height: AppTheme.spacing4),
          _ErrorFlagsHelper(label: l10n.meshcoreRadioStatsErrorFlagsHelper),
        ],
      ],
    );
  }

  /// Build the InfoTable rows: 5 RADIO rows from D35-A, plus CORE
  /// rows (uptime + firmware TX queue) when CORE data has landed.
  /// Error flags row appends only when the value is non-zero.
  List<InfoTableRow> _buildRows(MeshCoreRadioStats latest) {
    final rows = <InfoTableRow>[
      InfoTableRow(
        label: l10n.meshcoreRadioStatsNoiseFloor,
        value: l10n.meshcoreRadioStatsDbm(latest.noiseFloorDbm),
        icon: Icons.graphic_eq_rounded,
      ),
      InfoTableRow(
        label: l10n.meshcoreRadioStatsLastRssi,
        value: l10n.meshcoreRadioStatsDbm(latest.lastRssiDbm),
        icon: Icons.signal_cellular_alt_rounded,
      ),
      InfoTableRow(
        label: l10n.meshcoreRadioStatsLastSnr,
        value: l10n.meshcoreRadioStatsDb(latest.snrDb.toStringAsFixed(1)),
        icon: Icons.show_chart_rounded,
      ),
      InfoTableRow(
        label: l10n.meshcoreRadioStatsTxAirtime,
        value: _formatDuration(l10n, latest.txAirtime),
        icon: Icons.upload_rounded,
      ),
      InfoTableRow(
        label: l10n.meshcoreRadioStatsRxAirtime,
        value: _formatDuration(l10n, latest.rxAirtime),
        icon: Icons.download_rounded,
      ),
    ];
    final coreLatest = core.latest;
    if (coreLatest != null) {
      rows.addAll([
        InfoTableRow(
          label: l10n.meshcoreRadioStatsUptime,
          value: _formatDuration(l10n, coreLatest.uptime),
          icon: Icons.timer_rounded,
        ),
        InfoTableRow(
          label: l10n.meshcoreRadioStatsFirmwareQueue,
          value: '${coreLatest.queueLength}',
          icon: Icons.queue_rounded,
        ),
      ]);
      final hex = _visibleErrorFlags();
      if (hex != null) {
        rows.add(
          InfoTableRow(
            label: l10n.meshcoreRadioStatsFirmwareErrorFlags,
            value: l10n.meshcoreRadioStatsErrorFlagsHex(hex),
            icon: Icons.error_outline_rounded,
          ),
        );
      }
    }
    return rows;
  }

  /// Returns the 4-character zero-padded uppercase hex string for the
  /// CORE error flags when they are non-zero; otherwise `null` so the
  /// row + helper text are hidden. Per D35-B-A spec: bits are NOT
  /// labelled; the value is opaque support-report material only.
  String? _visibleErrorFlags() {
    final coreLatest = core.latest;
    if (coreLatest == null) return null;
    if (coreLatest.errorFlags == 0) return null;
    return coreLatest.errorFlags
        .toRadixString(16)
        .padLeft(4, '0')
        .toUpperCase();
  }

  static String _formatDuration(AppLocalizations l10n, Duration d) {
    final totalSeconds = d.inSeconds;
    if (totalSeconds < 60) {
      return l10n.meshcoreRadioStatsDurationSeconds(totalSeconds);
    }
    if (totalSeconds < 3600) {
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      return l10n.meshcoreRadioStatsDurationMs(minutes, seconds);
    }
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    return l10n.meshcoreRadioStatsDurationHm(hours, minutes);
  }
}

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Placeholder({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.textTertiary),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.textSecondary,
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaleHint extends StatelessWidget {
  final String label;
  const _StaleHint({required this.label});

  @override
  Widget build(BuildContext context) {
    final accent = AccentColors.orange;
    return Container(
      key: const ValueKey('meshcore-radio-stats-stale-hint'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 14, color: accent),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: accent,
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetNote extends StatelessWidget {
  final String label;
  const _ResetNote({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 12, color: context.textTertiary),
        const SizedBox(width: AppTheme.spacing8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

/// D35-B-A: helper paragraph rendered under the error-flags row when
/// the value is non-zero. Clarifies the value is opaque and only
/// useful for support reports; the per-bit semantics are not exposed
/// by the firmware so this client never invents labels.
class _ErrorFlagsHelper extends StatelessWidget {
  final String label;
  const _ErrorFlagsHelper({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.help_outline_rounded, size: 12, color: context.textTertiary),
        const SizedBox(width: AppTheme.spacing8),
        Expanded(
          child: Text(
            label,
            key: const ValueKey('meshcore-radio-stats-error-flags-helper'),
            style: TextStyle(
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}
