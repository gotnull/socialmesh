// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/telemetry_providers.dart';
import '../../services/backup/device_config_backup_service.dart';
import '../../services/backup/device_config_bundle.dart';
import '../../utils/share_utils.dart';
import '../../utils/snackbar.dart';
import '../automations/automation_providers.dart';
import 'widgets/device_config_restore_sheet.dart';

/// Schema version embedded in JSON exports. Bump on incompatible changes.
const String _kExportSchemaVersion = '1.0';

/// Separator for traceroute hop sequences in CSV exports.
const String _kTracerouteHopSeparator = '>';

class DataExportScreen extends ConsumerStatefulWidget {
  const DataExportScreen({super.key});

  @override
  ConsumerState<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends ConsumerState<DataExportScreen>
    with LifecycleSafeMixin<DataExportScreen> {
  final Set<String> _exportingTypes = {};
  final Set<String> _clearingTypes = {};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GlassScaffold(
      title: l10n.dataExportTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _SectionHeader(title: l10n.dataExportSectionMessages),
              _buildExportTile(
                icon: Icons.message_outlined,
                title: l10n.dataExportAllMessages,
                subtitle: l10n.dataExportAllMessagesSubtitle,
                format: l10n.dataExportFormatCsv,
                type: 'messages',
                onExport: _exportMessages,
                onClear: () =>
                    _confirmClear('messages', l10n.dataExportClearAllMessages),
              ),

              _SectionHeader(title: l10n.dataExportSectionTelemetry),
              _buildExportTile(
                icon: Icons.battery_charging_full,
                title: l10n.dataExportDeviceMetrics,
                subtitle: l10n.dataExportDeviceMetricsSubtitle,
                format: l10n.dataExportFormatCsv,
                type: 'device_metrics',
                onExport: _exportDeviceMetrics,
                onClear: () => _confirmClear(
                  'device_metrics',
                  l10n.dataExportClearDeviceMetrics,
                ),
              ),
              _buildExportTile(
                icon: Icons.thermostat,
                title: l10n.dataExportEnvironmentMetrics,
                subtitle: l10n.dataExportEnvironmentMetricsSubtitle,
                format: l10n.dataExportFormatCsv,
                type: 'environment_metrics',
                onExport: _exportEnvironmentMetrics,
                onClear: () => _confirmClear(
                  'environment_metrics',
                  l10n.dataExportClearEnvironmentMetrics,
                ),
              ),
              _buildExportTile(
                icon: Icons.air,
                title: l10n.dataExportAirQuality,
                subtitle: l10n.dataExportAirQualitySubtitle,
                format: l10n.dataExportFormatCsv,
                type: 'air_quality',
                onExport: _exportAirQuality,
                onClear: () => _confirmClear(
                  'air_quality',
                  l10n.dataExportClearAirQualityData,
                ),
              ),
              _buildExportTile(
                icon: Icons.bolt,
                title: l10n.dataExportPowerMetrics,
                subtitle: l10n.dataExportPowerMetricsSubtitle,
                format: l10n.dataExportFormatCsv,
                type: 'power_metrics',
                onExport: _exportPowerMetrics,
                onClear: () => _confirmClear(
                  'power_metrics',
                  l10n.dataExportClearPowerMetrics,
                ),
              ),

              _SectionHeader(title: l10n.dataExportSectionPositionData),
              _buildExportTile(
                icon: Icons.location_on_outlined,
                title: l10n.dataExportPositionHistory,
                subtitle: l10n.dataExportPositionHistorySubtitle,
                format: l10n.dataExportFormatCsv,
                type: 'positions',
                onExport: _exportPositions,
                onClear: () => _confirmClear(
                  'positions',
                  l10n.dataExportClearPositionHistory,
                ),
              ),
              _buildExportTile(
                icon: Icons.route,
                title: l10n.dataExportRoutes,
                subtitle: l10n.dataExportRoutesSubtitle,
                format: l10n.dataExportFormatGpx,
                type: 'routes',
                onExport: _exportRoutes,
                onClear: () =>
                    _confirmClear('routes', l10n.dataExportClearAllRoutes),
              ),
              _buildExportTile(
                icon: Icons.timeline,
                title: l10n.dataExportTraceroutes,
                subtitle: l10n.dataExportTraceroutesSubtitle,
                format: l10n.dataExportFormatCsv,
                type: 'traceroutes',
                onExport: _exportTraceroutes,
                onClear: () => _confirmClear(
                  'traceroutes',
                  l10n.dataExportClearTracerouteData,
                ),
              ),

              _SectionHeader(title: l10n.dataExportSectionDeviceConfig),
              _buildExportTile(
                icon: Icons.settings_backup_restore,
                title: l10n.dataExportDeviceConfigBackupTitle,
                subtitle: l10n.dataExportDeviceConfigBackupSubtitle,
                format: l10n.dataExportDeviceConfigFormatJson,
                type: 'device_config_backup',
                onExport: _exportDeviceConfig,
              ),
              _buildExportTile(
                icon: Icons.restore,
                title: l10n.dataExportDeviceConfigRestoreTitle,
                subtitle: l10n.dataExportDeviceConfigRestoreSubtitle,
                format: l10n.dataExportDeviceConfigFormatJson,
                type: 'device_config_restore',
                onExport: _restoreDeviceConfig,
                actionIcon: Icons.file_upload_outlined,
                actionTooltip: l10n.dataExportDeviceConfigRestoreTitle,
              ),

              _SectionHeader(title: l10n.dataExportSectionAutomations),
              _buildExportTile(
                icon: Icons.auto_awesome,
                title: l10n.dataExportAutomationRules,
                subtitle: l10n.dataExportAutomationRulesSubtitle,
                format: l10n.dataExportFormatJson,
                type: 'automations',
                onExport: _exportAutomations,
                onClear: () => _confirmClear(
                  'automations',
                  l10n.dataExportClearAllAutomationRules,
                ),
              ),
              _buildExportTile(
                icon: Icons.history,
                title: l10n.dataExportExecutionLog,
                subtitle: l10n.dataExportExecutionLogSubtitle,
                format: l10n.dataExportFormatJson,
                type: 'automation_log',
                onExport: _exportAutomationLog,
                onClear: () => _confirmClear(
                  'automation_log',
                  l10n.dataExportClearAutomationLog,
                ),
              ),

              _SectionHeader(title: l10n.dataExportSectionNetwork),
              _buildExportTile(
                icon: Icons.hub_outlined,
                title: l10n.dataExportNodeList,
                subtitle: l10n.dataExportNodeListSubtitle,
                format: l10n.dataExportFormatCsv,
                type: 'nodes',
                onExport: _exportNodes,
              ),

              _SectionHeader(title: l10n.dataExportSectionCompleteExport),
              _buildExportTile(
                icon: Icons.archive_outlined,
                title: l10n.dataExportExportAll,
                subtitle: l10n.dataExportExportAllSubtitle,
                format: l10n.dataExportFormatJson,
                type: 'all',
                onExport: _exportAll,
                isHighlighted: true,
              ),

              _SectionHeader(title: l10n.dataExportSectionClearData),
              _ClearAllTile(
                label: l10n.dataExportClearAll,
                subtitle: l10n.dataExportClearAllSubtitle,
                onTap: _confirmClearAll,
              ),

              const SizedBox(height: AppTheme.spacing16),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                ),
                child: _InfoBanner(text: l10n.dataExportInfoText),
              ),

              const SizedBox(height: AppTheme.spacing32),
            ]),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tile primitive
  // ---------------------------------------------------------------------------

  /// Canonical settings-style tile (per `mqtt_config_screen.dart::_SettingsTile`)
  /// extended with an export action button + optional clear button.
  ///
  /// `actionIcon` defaults to `Icons.ios_share`. Pass `Icons.file_upload_outlined`
  /// for import-style actions like the device-config restore tile.
  /// `isHighlighted: true` paints the tile with the accent tint + border, used
  /// for the "Complete Export" tile.
  Widget _buildExportTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String format,
    required String type,
    required Future<void> Function() onExport,
    VoidCallback? onClear,
    IconData? actionIcon,
    String? actionTooltip,
    bool isHighlighted = false,
  }) {
    final l10n = context.l10n;
    final isExporting = _exportingTypes.contains(type);
    final isClearing = _clearingTypes.contains(type);
    final accent = context.accentColor;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: isHighlighted ? accent.withValues(alpha: 0.1) : context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: isHighlighted
            ? Border.all(color: accent.withValues(alpha: 0.3))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing12,
        ),
        child: Row(
          children: [
            Icon(icon, color: isHighlighted ? accent : context.textSecondary),
            SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isHighlighted ? accent : context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    subtitle,
                    style: context.bodySmallStyle?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            _FormatPill(label: format),
            SizedBox(width: AppTheme.spacing8),
            if (onClear != null) ...[
              if (isClearing)
                LoadingIndicator(size: 20)
              else
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: context.textTertiary.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: l10n.dataExportTooltipClearData,
                ),
            ],
            SizedBox(width: AppTheme.spacing4),
            if (isExporting)
              LoadingIndicator(size: 20)
            else
              IconButton(
                icon: Icon(
                  actionIcon ?? Icons.ios_share,
                  color: accent,
                  size: 20,
                ),
                onPressed: () => _handleExport(type, onExport),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: actionTooltip ?? l10n.dataExportTooltipExport,
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action handlers
  // ---------------------------------------------------------------------------

  Future<void> _handleExport(
    String type,
    Future<void> Function() exportFn,
  ) async {
    safeSetState(() {
      _exportingTypes.add(type);
    });

    try {
      await exportFn();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          context.l10n.dataExportExportFailed(e.toString()),
        );
      }
    } finally {
      safeSetState(() {
        _exportingTypes.remove(type);
      });
    }
  }

  Future<void> _confirmClear(String type, String dataName) async {
    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.dataExportClearConfirmTitle(dataName),
      message: l10n.dataExportClearConfirmMsg(dataName),
      confirmLabel: l10n.dataExportClearConfirmBtn,
      isDestructive: true,
    );
    if (confirmed == true && mounted) {
      await _handleClear(type);
    }
  }

  Future<void> _confirmClearAll() async {
    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.dataExportClearAllConfirmTitle,
      message: l10n.dataExportClearAllConfirmMsg,
      confirmLabel: l10n.dataExportClearAllConfirmBtn,
      isDestructive: true,
    );
    if (confirmed == true && mounted) {
      await _handleClearAll();
    }
  }

  Future<void> _handleClear(String type) async {
    // Capture providers + l10n BEFORE await to avoid accessing disposed state
    // and to keep error snackbars valid even after navigation.
    final l10n = context.l10n;
    final messagesNotifier = ref.read(messagesProvider.notifier);
    final routesNotifier = ref.read(routesProvider.notifier);
    final automationsNotifier = ref.read(automationsProvider.notifier);
    final automationRepo = ref.read(automationRepositoryProvider);

    safeSetState(() {
      _clearingTypes.add(type);
    });

    try {
      final storage = await ref.read(telemetryStorageProvider.future);
      if (!mounted) return;

      switch (type) {
        case 'messages':
          messagesNotifier.clearMessages();
          break;
        case 'device_metrics':
          await storage.clearDeviceMetrics();
          break;
        case 'environment_metrics':
          await storage.clearEnvironmentMetrics();
          break;
        case 'air_quality':
          await storage.clearAirQualityMetrics();
          break;
        case 'power_metrics':
          await storage.clearPowerMetrics();
          break;
        case 'positions':
          await storage.clearPositionLogs();
          break;
        case 'routes':
          final routeStorage = await ref.read(routeStorageProvider.future);
          if (!mounted) return;
          await routeStorage.clearAllRoutes();
          if (!mounted) return;
          routesNotifier.refresh();
          break;
        case 'traceroutes':
          final trRepo = await ref.read(tracerouteRepositoryProvider.future);
          if (!mounted) return;
          await trRepo.deleteAllRuns();
          ref.invalidate(traceRouteLogsProvider);
          break;
        case 'automations':
          for (final auto in automationRepo.automations.toList()) {
            await automationRepo.deleteAutomation(auto.id);
            if (!mounted) return;
          }
          automationsNotifier.refresh();
          break;
        case 'automation_log':
          await automationRepo.clearLog();
          break;
      }

      if (!mounted) return;
      showSuccessSnackBar(context, l10n.dataExportDataCleared);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, l10n.dataExportClearFailed(e.toString()));
    } finally {
      safeSetState(() {
        _clearingTypes.remove(type);
      });
    }
  }

  Future<void> _handleClearAll() async {
    // Track every type the user expects to be cleared so the spinner state
    // and the actual delete pass stay in sync.
    const types = [
      'messages',
      'device_metrics',
      'environment_metrics',
      'air_quality',
      'power_metrics',
      'positions',
      'routes',
      'traceroutes',
      'automations',
      'automation_log',
    ];

    final l10n = context.l10n;
    final messagesNotifier = ref.read(messagesProvider.notifier);
    final routesNotifier = ref.read(routesProvider.notifier);
    final automationsNotifier = ref.read(automationsProvider.notifier);
    final automationRepo = ref.read(automationRepositoryProvider);

    safeSetState(() {
      _clearingTypes.addAll(types);
    });

    try {
      final storage = await ref.read(telemetryStorageProvider.future);
      if (!mounted) return;

      messagesNotifier.clearMessages();
      await storage.clearAllData();
      if (!mounted) return;

      final routeStorage = await ref.read(routeStorageProvider.future);
      if (!mounted) return;
      await routeStorage.clearAllRoutes();
      if (!mounted) return;
      routesNotifier.refresh();

      final trRepo = await ref.read(tracerouteRepositoryProvider.future);
      if (!mounted) return;
      await trRepo.deleteAllRuns();
      ref.invalidate(traceRouteLogsProvider);

      for (final auto in automationRepo.automations.toList()) {
        await automationRepo.deleteAutomation(auto.id);
        if (!mounted) return;
      }
      automationsNotifier.refresh();

      await automationRepo.clearLog();
      if (!mounted) return;

      showSuccessSnackBar(context, l10n.dataExportAllDataCleared);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, l10n.dataExportClearFailed(e.toString()));
    } finally {
      safeSetState(() {
        _clearingTypes.clear();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Device config (backup + restore)
  // ---------------------------------------------------------------------------

  Future<void> _exportDeviceConfig() async {
    final l10n = context.l10n;
    final protocol = ref.read(protocolServiceProvider);
    final backupService = ref.read(deviceConfigBackupServiceProvider);

    if (protocol.myNodeNum == null) {
      showErrorSnackBar(context, l10n.dataExportDeviceConfigBackupNotConnected);
      return;
    }

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.dataExportDeviceConfigBackupWarningTitle,
      message: l10n.dataExportDeviceConfigBackupWarningBody,
      confirmLabel: l10n.dataExportDeviceConfigBackupContinueBtn,
      cancelLabel: l10n.dataExportDeviceConfigBackupCancelBtn,
    );
    if (confirmed != true || !mounted) return;

    try {
      final capture = await backupService.capture();
      if (!mounted) return;

      final bundle = capture.bundle;
      await shareTextAsFile(
        bundle.encode(),
        filename: bundle.suggestedFilename(),
        mimeType: 'application/json',
        subject: l10n.dataExportDeviceConfigBackupShareSubject,
        context: context,
      );

      if (!mounted) return;
      if (capture.missingSections.isNotEmpty) {
        showInfoSnackBar(
          context,
          l10n.dataExportDeviceConfigBackupPartial(
            capture.missingSections.length,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        l10n.dataExportDeviceConfigBackupFailed(e.toString()),
      );
    }
  }

  Future<void> _restoreDeviceConfig() async {
    final l10n = context.l10n;
    final protocol = ref.read(protocolServiceProvider);
    final backupService = ref.read(deviceConfigBackupServiceProvider);

    if (protocol.myNodeNum == null) {
      showErrorSnackBar(
        context,
        l10n.dataExportDeviceConfigRestoreNotConnected,
      );
      return;
    }

    final pickResult = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (pickResult == null || pickResult.files.isEmpty) return;
    if (!mounted) return;

    final picked = pickResult.files.first;
    final bytes = picked.bytes;
    if (bytes == null) {
      showErrorSnackBar(context, l10n.dataExportDeviceConfigRestoreInvalidFile);
      return;
    }

    DeviceConfigBundle bundle;
    try {
      bundle = DeviceConfigBundle.decode(utf8.decode(bytes));
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, l10n.dataExportDeviceConfigRestoreInvalidFile);
      return;
    }

    if (bundle.isEmpty) {
      showInfoSnackBar(context, l10n.dataExportDeviceConfigRestoreEmpty);
      return;
    }

    final report = await AppBottomSheet.showScrollable<RestoreReport>(
      context: context,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (controller) => DeviceConfigRestoreSheet(
        bundle: bundle,
        connectedNodeNum: protocol.myNodeNum,
        scrollController: controller,
        onRestore: (selection) => backupService.restore(bundle, selection),
      ),
    );

    if (!mounted || report == null) return;

    final total = report.appliedCount + report.failed.length;
    if (report.hasFailures) {
      showErrorSnackBar(
        context,
        l10n.dataExportDeviceConfigRestoreSummaryWithFailures(
          report.appliedCount,
          total,
          report.failed.length,
        ),
      );
    } else {
      showSuccessSnackBar(
        context,
        l10n.dataExportDeviceConfigRestoreSummary(report.appliedCount, total),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Per-section exports
  // ---------------------------------------------------------------------------

  Future<void> _exportMessages() async {
    final l10n = context.l10n;
    final messages = ref.read(messagesProvider);
    final nodes = ref.read(nodesProvider);

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,from_node,from_name,channel,message,is_direct', // lint-allow: hardcoded-string
    );

    for (final msg in messages) {
      final fromNode = nodes[msg.from];
      final fromName =
          fromNode?.longName ??
          fromNode?.shortName ??
          l10n.dataExportUnknownSender;
      buffer.writeln(
        '${_csv(msg.timestamp.toIso8601String())},'
        '${_csv(msg.from)},'
        '${_csv(fromName)},'
        '${_csv(msg.channel)},'
        '${_csv(msg.text)},'
        '${_csv(msg.isDirect)}',
      );
    }

    await shareTextAsFile(
      buffer.toString(),
      filename: _filename('messages', 'csv'),
      mimeType: 'text/csv',
      subject: l10n.dataExportShareSubjectMessages,
      context: context,
    );
  }

  Future<void> _exportDeviceMetrics() async {
    final l10n = context.l10n;
    final logs = await ref.read(deviceMetricsLogsProvider.future);
    if (!mounted) return;

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,node_num,battery_level,voltage,channel_utilization,air_util_tx,uptime', // lint-allow: hardcoded-string
    );
    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.nodeNum},${log.batteryLevel},${log.voltage},${log.channelUtilization},${log.airUtilTx},${log.uptimeSeconds}',
      );
    }

    await shareTextAsFile(
      buffer.toString(),
      filename: _filename('device-metrics', 'csv'),
      mimeType: 'text/csv',
      subject: l10n.dataExportShareSubjectDeviceMetrics,
      context: context,
    );
  }

  Future<void> _exportEnvironmentMetrics() async {
    final l10n = context.l10n;
    final logs = await ref.read(environmentMetricsLogsProvider.future);
    if (!mounted) return;

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,node_num,temperature,relative_humidity,barometric_pressure,gas_resistance,iaq', // lint-allow: hardcoded-string
    );
    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.nodeNum},${log.temperature},${log.humidity},${log.barometricPressure},${log.gasResistance},${log.iaq}',
      );
    }

    await shareTextAsFile(
      buffer.toString(),
      filename: _filename('environment-metrics', 'csv'),
      mimeType: 'text/csv',
      subject: l10n.dataExportShareSubjectEnvironmentMetrics,
      context: context,
    );
  }

  Future<void> _exportAirQuality() async {
    final l10n = context.l10n;
    final logs = await ref.read(airQualityMetricsLogsProvider.future);
    if (!mounted) return;

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,node_num,pm10,pm25,pm100,co2', // lint-allow: hardcoded-string
    );
    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.nodeNum},${log.pm10Standard},${log.pm25Standard},${log.pm100Standard},${log.co2}',
      );
    }

    await shareTextAsFile(
      buffer.toString(),
      filename: _filename('air-quality', 'csv'),
      mimeType: 'text/csv',
      subject: l10n.dataExportShareSubjectAirQuality,
      context: context,
    );
  }

  Future<void> _exportPowerMetrics() async {
    final l10n = context.l10n;
    final logs = await ref.read(powerMetricsLogsProvider.future);
    if (!mounted) return;

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,node_num,ch1_voltage,ch1_current,ch2_voltage,ch2_current,ch3_voltage,ch3_current', // lint-allow: hardcoded-string
    );
    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.nodeNum},${log.ch1Voltage},${log.ch1Current},${log.ch2Voltage},${log.ch2Current},${log.ch3Voltage},${log.ch3Current}',
      );
    }

    await shareTextAsFile(
      buffer.toString(),
      filename: _filename('power-metrics', 'csv'),
      mimeType: 'text/csv',
      subject: l10n.dataExportShareSubjectPowerMetrics,
      context: context,
    );
  }

  Future<void> _exportPositions() async {
    final l10n = context.l10n;
    final logs = await ref.read(positionLogsProvider.future);
    if (!mounted) return;

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,node_num,latitude,longitude,altitude,sats_in_view,ground_speed,ground_track', // lint-allow: hardcoded-string
    );
    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.nodeNum},${log.latitude},${log.longitude},${log.altitude},${log.satsInView},${log.speed},${log.heading}',
      );
    }

    await shareTextAsFile(
      buffer.toString(),
      filename: _filename('positions', 'csv'),
      mimeType: 'text/csv',
      subject: l10n.dataExportShareSubjectPositionHistory,
      context: context,
    );
  }

  Future<void> _exportRoutes() async {
    final l10n = context.l10n;
    final routes = ref.read(routesProvider);

    final buffer = StringBuffer();
    buffer.writeln(
      '<?xml version="1.0" encoding="UTF-8"?>',
    ); // lint-allow: hardcoded-string
    buffer.writeln(
      '<gpx version="1.1" creator="Socialmesh" xmlns="http://www.topografix.com/GPX/1/1">', // lint-allow: hardcoded-string
    );

    for (final route in routes) {
      buffer.writeln('  <trk>');
      buffer.writeln('    <name>${_escapeXml(route.name)}</name>');
      if (route.notes != null) {
        buffer.writeln('    <desc>${_escapeXml(route.notes!)}</desc>');
      }
      buffer.writeln('    <trkseg>');
      for (final loc in route.locations) {
        buffer.write(
          '      <trkpt lat="${loc.latitude}" lon="${loc.longitude}">', // lint-allow: hardcoded-string
        );
        if (loc.altitude != null) {
          buffer.write('<ele>${loc.altitude}</ele>');
        }
        buffer.write('<time>${loc.timestamp.toUtc().toIso8601String()}</time>');
        buffer.writeln('</trkpt>');
      }
      buffer.writeln('    </trkseg>');
      buffer.writeln('  </trk>');
    }

    buffer.writeln('</gpx>');

    await shareTextAsFile(
      buffer.toString(),
      filename: _filename('routes', 'gpx'),
      mimeType: 'application/gpx+xml',
      subject: l10n.dataExportShareSubjectRoutes,
      context: context,
    );
  }

  Future<void> _exportTraceroutes() async {
    final l10n = context.l10n;
    final logs = await ref.read(traceRouteLogsProvider.future);
    if (!mounted) return;

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,target_node,hops,route,snr_values', // lint-allow: hardcoded-string
    );
    for (final log in logs) {
      final hopNodes = log.hops
          .map((h) => h.nodeNum)
          .join(_kTracerouteHopSeparator);
      final snrValues = log.hops
          .map((h) => h.snr ?? l10n.dataExportSnrNotAvailable)
          .join(',');
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.targetNode},${log.hops.length},'
        '${_csv(hopNodes)},${_csv(snrValues)}',
      );
    }

    await shareTextAsFile(
      buffer.toString(),
      filename: _filename('traceroutes', 'csv'),
      mimeType: 'text/csv',
      subject: l10n.dataExportShareSubjectTraceroutes,
      context: context,
    );
  }

  Future<void> _exportAutomations() async {
    final l10n = context.l10n;
    final repo = ref.read(automationRepositoryProvider);

    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'version': _kExportSchemaVersion,
      'automations': repo.automations.map((a) => a.toJson()).toList(),
    };

    await shareTextAsFile(
      const JsonEncoder.withIndent('  ').convert(data),
      filename: _filename('automations', 'json'),
      mimeType: 'application/json',
      subject: l10n.dataExportShareSubjectAutomations,
      context: context,
    );
  }

  Future<void> _exportAutomationLog() async {
    final l10n = context.l10n;
    final repo = ref.read(automationRepositoryProvider);

    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'version': _kExportSchemaVersion,
      'executionLog': repo.log.map((l) => l.toJson()).toList(),
    };

    await shareTextAsFile(
      const JsonEncoder.withIndent('  ').convert(data),
      filename: _filename('automation-log', 'json'),
      mimeType: 'application/json',
      subject: l10n.dataExportShareSubjectAutomationLog,
      context: context,
    );
  }

  Future<void> _exportNodes() async {
    final l10n = context.l10n;
    final nodes = ref.read(nodesProvider);

    final buffer = StringBuffer();
    buffer.writeln(
      'node_num,user_id,long_name,short_name,hardware,role,latitude,longitude,altitude,battery_level,snr,last_heard', // lint-allow: hardcoded-string
    );
    for (final node in nodes.values) {
      buffer.writeln(
        '${node.nodeNum},'
        '${_csv(node.userId ?? '')},'
        '${_csv(node.longName ?? '')},'
        '${_csv(node.shortName ?? '')},'
        '${_csv(node.hardwareModel ?? '')},'
        '${_csv(node.role ?? '')},'
        '${node.latitude ?? ''},${node.longitude ?? ''},${node.altitude ?? ''},'
        '${node.batteryLevel ?? ''},${node.snr ?? ''},'
        '${node.lastHeard?.toIso8601String() ?? ''}',
      );
    }

    await shareTextAsFile(
      buffer.toString(),
      filename: _filename('nodes', 'csv'),
      mimeType: 'text/csv',
      subject: l10n.dataExportShareSubjectNodeList,
      context: context,
    );
  }

  Future<void> _exportAll() async {
    final l10n = context.l10n;

    // Privacy gate: this bundle includes DM bodies, every node position, and
    // the full node list. Make the user opt in explicitly.
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.dataExportCompleteWarningTitle,
      message: l10n.dataExportCompleteWarningBody,
      confirmLabel: l10n.dataExportCompleteWarningContinueBtn,
      cancelLabel: l10n.dataExportCompleteWarningCancelBtn,
    );
    if (confirmed != true || !mounted) return;

    final nodes = ref.read(nodesProvider);
    final messages = ref.read(messagesProvider);
    final deviceMetrics = await ref.read(deviceMetricsLogsProvider.future);
    if (!mounted) return;
    final envMetrics = await ref.read(environmentMetricsLogsProvider.future);
    if (!mounted) return;
    final airQuality = await ref.read(airQualityMetricsLogsProvider.future);
    if (!mounted) return;
    final powerMetrics = await ref.read(powerMetricsLogsProvider.future);
    if (!mounted) return;
    final positions = await ref.read(positionLogsProvider.future);
    if (!mounted) return;
    final routes = ref.read(routesProvider);
    final traceroutes = await ref.read(traceRouteLogsProvider.future);
    if (!mounted) return;
    final automationRepo = ref.read(automationRepositoryProvider);

    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'version': _kExportSchemaVersion,
      'nodes': nodes.values.map(_nodeToMap).toList(),
      'messages': messages.map(_messageToMap).toList(),
      'deviceMetrics': deviceMetrics.map((l) => l.toJson()).toList(),
      'environmentMetrics': envMetrics.map((l) => l.toJson()).toList(),
      'airQualityMetrics': airQuality.map((l) => l.toJson()).toList(),
      'powerMetrics': powerMetrics.map((l) => l.toJson()).toList(),
      'positions': positions.map((l) => l.toJson()).toList(),
      'routes': routes.map((r) => r.toJson()).toList(),
      'traceroutes': traceroutes.map((l) => l.toJson()).toList(),
      'automations': automationRepo.automations.map((a) => a.toJson()).toList(),
      'automationLog': automationRepo.log.map((l) => l.toJson()).toList(),
    };

    await shareTextAsFile(
      const JsonEncoder.withIndent('  ').convert(data),
      filename: _filename('complete-export', 'json'),
      mimeType: 'application/json',
      subject: l10n.dataExportShareSubjectComplete,
      context: context,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _nodeToMap(MeshNode node) {
    return {
      'nodeNum': node.nodeNum,
      'userId': node.userId,
      'longName': node.longName,
      'shortName': node.shortName,
      'hardwareModel': node.hardwareModel,
      'role': node.role,
      'latitude': node.latitude,
      'longitude': node.longitude,
      'altitude': node.altitude,
      'batteryLevel': node.batteryLevel,
      'snr': node.snr,
      'lastHeard': node.lastHeard?.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> _messageToMap(Message msg) {
    return {
      'id': msg.id,
      'from': msg.from,
      'to': msg.to,
      'text': msg.text,
      'timestamp': msg.timestamp.millisecondsSinceEpoch,
      'channel': msg.channel,
      'status': msg.status.name,
    };
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

/// Canonical inner-settings section header, mirroring `_SectionHeader` in
/// `mqtt_config_screen.dart`.
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: context.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Compact format-pill rendered to the right of an export tile's title.
class _FormatPill extends StatelessWidget {
  final String label;
  const _FormatPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: context.background,
        borderRadius: BorderRadius.circular(AppTheme.radius6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.textTertiary,
        ),
      ),
    );
  }
}

/// Destructive "Clear all data" tile. Mirrors the canonical settings tile but
/// paints a red tint + border + tappable to make the destructive intent
/// unmistakable.
class _ClearAllTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ClearAllTile({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          child: Row(
            children: [
              const Icon(Icons.delete_forever, color: AppTheme.errorRed),
              SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.errorRed,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      subtitle,
                      style: context.bodySmallStyle?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.warning_amber, color: AppTheme.errorRed, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom info banner explaining what the screen does.
class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AccentColors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: AccentColors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AccentColors.blue.withValues(alpha: 0.8),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Format a value for inclusion in a CSV row. Strings/dynamic values get
/// double-quote escaping per RFC 4180; numbers and bools pass through.
String _csv(Object? value) {
  if (value == null) return '';
  if (value is num || value is bool) return value.toString();
  final s = value.toString();
  if (s.contains('"') ||
      s.contains(',') ||
      s.contains('\n') ||
      s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String _filename(String stem, String ext) {
  final now = DateTime.now().toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp =
      '${now.year}${two(now.month)}${two(now.day)}'
      '${two(now.hour)}${two(now.minute)}';
  return 'socialmesh-$stem-$stamp.$ext';
}
