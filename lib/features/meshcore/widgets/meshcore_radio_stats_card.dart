// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D35-A / D35-B-A / D35-PACKETS-A: MeshCore companion-radio stats card.
//
// Surfaces the firmware-backed stats subtypes fetched via
// `CMD_GET_STATS` (0x38):
//   - RADIO (D35-A): noise floor, RSSI, SNR, TX/RX airtime, 1 Hz poll.
//   - CORE (D35-B-A): uptime, firmware TX queue, opaque error flags
//     when non-zero, 0.2 Hz poll.
//   - PACKETS (D35-PACKETS-A): collapsible subsection. RX/TX
//     aggregates, sent/recv flood/direct breakdown, opaque reception
//     errors. Lazy 0.1 Hz poll that ONLY runs while expanded - the
//     provider auto-disposes when no listener subscribes.
//
// All three fetch paths bypass the D34a chat rate limiter; polling
// does NOT compete with chat airtime (regression-pinned).
//
// Privacy: the card NEVER renders pubkeys, MMFs, channel names, raw
// payloads, message plaintext, or envelope content. Only typed
// numeric values from the firmware. Pinned by the widget redaction
// sweep in the D35-A / D35-B-A / D35-PACKETS-A widget tests.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/protocol/meshcore_messages.dart';

class MeshCoreRadioStatsCard extends ConsumerStatefulWidget {
  const MeshCoreRadioStatsCard({super.key});

  @override
  ConsumerState<MeshCoreRadioStatsCard> createState() =>
      _MeshCoreRadioStatsCardState();
}

class _MeshCoreRadioStatsCardState
    extends ConsumerState<MeshCoreRadioStatsCard> {
  /// D35-PACKETS-A: collapsed by default. The packets provider is only
  /// watched when this is true, so its auto-dispose timer never runs
  /// for users who don't expand the section.
  bool _packetsExpanded = false;

  @override
  Widget build(BuildContext context) {
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
            if (snapshot.isConnected) ...[
              const SizedBox(height: AppTheme.spacing12),
              _PacketsSection(
                expanded: _packetsExpanded,
                l10n: l10n,
                onToggle: () =>
                    setState(() => _packetsExpanded = !_packetsExpanded),
              ),
            ],
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

/// D35-PACKETS-A: collapsible "Packet counters" subsection.
///
/// The header row is always rendered; the inner `Consumer` that
/// watches `meshCorePacketsStatsProvider` is mounted ONLY when
/// expanded. Combined with `NotifierProvider.autoDispose` on the
/// packets provider, this gives strict lazy semantics: collapsed =
/// no listener = no timer = zero wire chatter. Pinned by the
/// provider auto-dispose test and by a live-smoke step asserting no
/// `event=packets_stats.fetched` log lines while collapsed.
class _PacketsSection extends StatelessWidget {
  final bool expanded;
  final AppLocalizations l10n;
  final VoidCallback onToggle;

  const _PacketsSection({
    required this.expanded,
    required this.l10n,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const ValueKey('meshcore-radio-stats-packets-header'),
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing4,
              vertical: AppTheme.spacing8,
            ),
            child: Row(
              children: [
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: context.textSecondary,
                  semanticLabel: expanded
                      ? l10n.meshcoreRadioStatsPacketsCollapse
                      : l10n.meshcoreRadioStatsPacketsExpand,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    l10n.meshcoreRadioStatsPacketsSection,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: AppTheme.spacing4),
          const _PacketsBody(),
        ],
      ],
    );
  }
}

/// Inner Consumer wrapper. Watching this provider here (and only
/// here) is what triggers the auto-dispose timer to start. When the
/// parent collapses the section, this widget unmounts, the listener
/// drops, and `MeshCorePacketsStatsNotifier.dispose` cancels the
/// timer.
class _PacketsBody extends ConsumerWidget {
  const _PacketsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final snapshot = ref.watch(meshCorePacketsStatsProvider);
    final latest = snapshot.latest;

    if (latest == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
        child: Row(
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: 14,
              color: context.textTertiary,
            ),
            const SizedBox(width: AppTheme.spacing8),
            Expanded(
              child: Text(
                l10n.meshcoreRadioStatsFetching,
                key: const ValueKey('meshcore-radio-stats-packets-fetching'),
                style: TextStyle(
                  color: context.textSecondary,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final rows = <InfoTableRow>[
      InfoTableRow(
        label: l10n.meshcoreRadioStatsPacketsReceived,
        value: l10n.meshcoreRadioStatsPacketsCount(
          _formatCount(latest.packetsReceived),
        ),
        icon: Icons.call_received_rounded,
      ),
      InfoTableRow(
        label: l10n.meshcoreRadioStatsPacketsSent,
        value: l10n.meshcoreRadioStatsPacketsCount(
          _formatCount(latest.packetsSent),
        ),
        icon: Icons.call_made_rounded,
      ),
      InfoTableRow(
        label: l10n.meshcoreRadioStatsPacketsSentFlood,
        value: l10n.meshcoreRadioStatsPacketsCount(
          _formatCount(latest.sentFlood),
        ),
        icon: Icons.broadcast_on_personal_rounded,
      ),
      InfoTableRow(
        label: l10n.meshcoreRadioStatsPacketsSentDirect,
        value: l10n.meshcoreRadioStatsPacketsCount(
          _formatCount(latest.sentDirect),
        ),
        icon: Icons.near_me_rounded,
      ),
      InfoTableRow(
        label: l10n.meshcoreRadioStatsPacketsRecvFlood,
        value: l10n.meshcoreRadioStatsPacketsCount(
          _formatCount(latest.recvFlood),
        ),
        icon: Icons.podcasts_rounded,
      ),
      InfoTableRow(
        label: l10n.meshcoreRadioStatsPacketsRecvDirect,
        value: l10n.meshcoreRadioStatsPacketsCount(
          _formatCount(latest.recvDirect),
        ),
        icon: Icons.cell_tower_rounded,
      ),
      InfoTableRow(
        label: l10n.meshcoreRadioStatsPacketsRecvErrors,
        value: l10n.meshcoreRadioStatsPacketsCount(
          _formatCount(latest.recvErrors),
        ),
        icon: Icons.warning_amber_rounded,
      ),
    ];

    return Opacity(
      opacity: snapshot.isStale ? 0.55 : 1.0,
      child: InfoTable(rows: rows),
    );
  }

  /// Format an integer with thousands separators (e.g. 1247 -> "1,247").
  /// Uses a manual grouping so the result is locale-stable.
  static String _formatCount(int n) {
    if (n < 1000) return '$n';
    final s = n.toString();
    final buf = StringBuffer();
    var firstGroup = s.length % 3;
    if (firstGroup == 0) firstGroup = 3;
    buf.write(s.substring(0, firstGroup));
    for (var i = firstGroup; i < s.length; i += 3) {
      buf.write(',');
      buf.write(s.substring(i, i + 3));
    }
    return buf.toString();
  }
}
