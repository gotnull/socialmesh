// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/units/distance_format.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/splash_mesh_provider.dart';
import '../../../utils/export_format.dart';
import '../../../utils/share_utils.dart';
import '../../../utils/snackbar.dart';
import '../../../utils/time_format.dart';
import '../../../utils/uptime_formatter.dart';
import 'range_test_export.dart';
import 'range_test_models.dart';
import 'range_test_providers.dart';

enum _SessionAction { exportCsv, exportKml, delete }

/// One recorded Range Test session: its summary, every packet heard, and
/// export to CSV or KML.
class RangeTestSessionScreen extends ConsumerStatefulWidget {
  final int sessionId;

  const RangeTestSessionScreen({super.key, required this.sessionId});

  @override
  ConsumerState<RangeTestSessionScreen> createState() =>
      _RangeTestSessionScreenState();
}

class _RangeTestSessionScreenState extends ConsumerState<RangeTestSessionScreen>
    with LifecycleSafeMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  RangeTestSession? _session() {
    final sessions = ref.read(rangeTestProvider).value?.sessions;
    return sessions?.where((s) => s.id == widget.sessionId).firstOrNull;
  }

  Future<void> _onAction(_SessionAction action) async {
    HapticFeedback.selectionClick();
    switch (action) {
      case _SessionAction.exportCsv:
        await _export(kml: false);
      case _SessionAction.exportKml:
        await _export(kml: true);
      case _SessionAction.delete:
        await _delete();
    }
  }

  Future<void> _export({required bool kml}) async {
    final session = _session();
    if (session == null) return;
    final l10n = context.l10n;
    final title = l10n.rangeTestKmlName(
      AppTimeFormat.fullDateAndTime(context).format(session.startedAt),
    );
    try {
      final readings = await ref.read(
        rangeTestReadingsProvider(widget.sessionId).future,
      );
      if (!mounted) return;
      if (kml && !readings.any((r) => r.hasRxPosition)) {
        showInfoSnackBar(context, l10n.rangeTestKmlNoPositions);
        return;
      }
      await shareTextAsFile(
        kml
            ? rangeTestKml(readings, documentName: title)
            : rangeTestCsv(readings),
        filename: exportFileName(
          'range-test',
          kml ? 'kml' : 'csv',
          at: session.startedAt,
        ),
        mimeType: kml
            ? 'application/vnd.google-earth.kml+xml'
            : 'text/csv', // lint-allow: hardcoded-string - MIME types
        subject: title,
        context: context,
      );
    } catch (e) {
      AppLogging.settings('Range test export failed: $e');
      if (mounted) {
        showErrorSnackBar(context, l10n.rangeTestExportFailed('$e'));
      }
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.rangeTestDeleteTitle,
      message: l10n.rangeTestDeleteMessage,
      confirmLabel: l10n.rangeTestDelete,
      cancelLabel: l10n.commonCancel,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    final notifier = ref.read(rangeTestProvider.notifier);
    await notifier.delete(widget.sessionId);
    safeNavigatorPop();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(
      rangeTestProvider.select(
        (s) => s.value?.sessions
            .where((x) => x.id == widget.sessionId)
            .firstOrNull,
      ),
    );
    final readingsAsync = ref.watch(
      rangeTestReadingsProvider(widget.sessionId),
    );
    final readings = readingsAsync.value;

    return GlassScaffold(
      title: context.l10n.rangeTestTitle,
      controller: _scrollController,
      scrollbar: true,
      actions: [
        if (session != null)
          AppBarOverflowMenu<_SessionAction>(
            onSelected: _onAction,
            itemBuilder: (context) => [
              _menuItem(
                _SessionAction.exportCsv,
                Icons.table_chart_outlined,
                context.l10n.rangeTestExportCsv,
              ),
              _menuItem(
                _SessionAction.exportKml,
                Icons.map_outlined,
                context.l10n.rangeTestExportKml,
              ),
              if (!session.isOpen)
                _menuItem(
                  _SessionAction.delete,
                  Icons.delete_outline,
                  context.l10n.rangeTestDelete,
                ),
            ],
          ),
      ],
      slivers: [
        if (session == null || readings == null)
          SliverFillRemaining(
            child: readingsAsync.hasError
                ? Center(
                    child: Text(
                      context.l10n.rangeTestLoadFailed,
                      style: TextStyle(color: context.textSecondary),
                    ),
                  )
                : const ScreenLoadingIndicator(),
          )
        else
          ..._content(session, readings),
      ],
    );
  }

  PopupMenuItem<_SessionAction> _menuItem(
    _SessionAction value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: context.textSecondary),
          SizedBox(width: AppTheme.spacing12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  List<Widget> _content(
    RangeTestSession session,
    List<RangeTestReading> readings,
  ) {
    final l10n = context.l10n;
    final summary = RangeTestSummary.of(readings);
    final units = ref.watch(measurementUnitsProvider);
    final dateTime = AppTimeFormat.fullDateAndTime(context);
    final expected = summary.expectedCount;
    final endedAt = session.endedAt;

    String? distance(double? meters) =>
        meters == null ? null : formatDistanceMeters(meters, units, l10n);

    final rows = <InfoTableRow>[
      InfoTableRow(
        label: l10n.rangeTestReceived,
        value: expected == null || expected == 0
            ? context.formatCount(readings.length)
            : l10n.rangeTestReceivedValue(
                summary.sequencedCount,
                expected,
                (summary.sequencedCount * 100 / expected).round(),
              ),
        icon: Icons.podcasts,
      ),
      InfoTableRow(
        label: l10n.rangeTestAvgSnr,
        value: summary.averageSnr == null
            ? '--'
            : '${summary.averageSnr!.toStringAsFixed(1)} dB',
        icon: Icons.signal_cellular_alt,
      ),
      InfoTableRow(
        label: l10n.rangeTestAvgRssi,
        value: summary.averageRssi == null
            ? '--'
            : '${summary.averageRssi!.toStringAsFixed(0)} dBm',
        icon: Icons.network_check,
      ),
      InfoTableRow(
        label: l10n.rangeTestMaxDist,
        value: distance(summary.maxDistanceMeters) ?? '--',
        icon: Icons.straighten,
      ),
      InfoTableRow(
        label: l10n.rangeTestStarted,
        value: dateTime.format(session.startedAt),
        icon: Icons.play_arrow_outlined,
      ),
      InfoTableRow(
        label: l10n.rangeTestDuration,
        value: endedAt == null
            ? l10n.rangeTestRecordingActive
            : formatUptime(endedAt.difference(session.startedAt).inSeconds),
        icon: Icons.timer_outlined,
      ),
    ];

    // Newest first, so a live session shows the latest packet at the top.
    final newestFirst = readings.reversed.toList();
    final missed = summary.missedBefore.reversed.toList();

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing16,
          AppTheme.spacing8,
          AppTheme.spacing16,
          0,
        ),
        sliver: SliverList.list(
          children: [
            SectionTitle(title: dateTime.format(session.startedAt)),
            Container(
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
              child: InfoTable(rows: rows, showBorder: false),
            ),
            const SizedBox(height: AppTheme.spacing16),
            SectionTitle(title: l10n.rangeTestPackets),
            if (readings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacing16,
                ),
                child: Text(
                  l10n.rangeTestNoPackets,
                  style: TextStyle(color: context.textSecondary),
                ),
              ),
          ],
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacing24),
        sliver: SliverList.builder(
          itemCount: newestFirst.length,
          itemBuilder: (context, index) => _ReadingRow(
            reading: newestFirst[index],
            missedBefore: missed[index],
            distance: distance(newestFirst[index].distanceMeters),
          ),
        ),
      ),
    ];
  }
}

class _ReadingRow extends StatelessWidget {
  final RangeTestReading reading;
  final int missedBefore;
  final String? distance;

  const _ReadingRow({
    required this.reading,
    required this.missedBefore,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final snr = reading.rxSnr;
    final rssi = reading.rxRssi;
    final details = [
      AppTimeFormat.timeWithSeconds(context).format(reading.receivedAt),
      ?distance,
      reading.senderName ?? rangeTestNodeId(reading.senderNodeNum),
      if (reading.viaMqtt) l10n.rangeTestViaMqtt,
    ].join(' · '); // lint-allow: hardcoded-string - separator

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing2,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing10,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: AppTheme.spacing48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing6,
              vertical: AppTheme.spacing4,
            ),
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
            ),
            child: Text(
              reading.sequence == null ? '--' : '#${reading.sequence}',
              textAlign: TextAlign.center,
              style: context.bodySmallStyle?.copyWith(
                color: context.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SNR ${snr == null ? '--' : snr.toStringAsFixed(1)} dB · '
                  'RSSI ${rssi ?? '--'} dBm', // lint-allow: hardcoded-string - units
                  style: context.bodySecondaryStyle?.copyWith(
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  details,
                  style: context.bodySmallStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
                if (missedBefore > 0) ...[
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    l10n.rangeTestMissed(missedBefore),
                    style: context.bodySmallStyle?.copyWith(
                      color: AppTheme.warningYellow,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
