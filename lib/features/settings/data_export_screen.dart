// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../services/backup/device_config_bundle.dart';
import '../../services/backup/device_config_backup_service.dart';
import '../../utils/share_utils.dart';
import '../../utils/snackbar.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/telemetry_providers.dart';
import '../automations/automation_providers.dart';
import '../../core/widgets/loading_indicator.dart';
import 'widgets/device_config_restore_sheet.dart';

class DataExportScreen extends ConsumerStatefulWidget {
  const DataExportScreen({super.key});

  @override
  ConsumerState<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends ConsumerState<DataExportScreen>
    with LifecycleSafeMixin<DataExportScreen> {
  final Set<String> _exportingTypes = {};
  final Set<String> _clearingTypes = {};

  /// Helper to share with proper iPad support
  Future<void> _shareText(String text, {String? subject}) async {
    await shareText(text, subject: subject, context: context);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: context.l10n.dataExportTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Messages
              _buildSectionHeader(context.l10n.dataExportSectionMessages),
              Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(color: context.border),
                ),
                child: Column(
                  children: [
                    _buildExportTile(
                      icon: Icons.message_outlined,
                      title: context.l10n.dataExportAllMessages,
                      subtitle: context.l10n.dataExportAllMessagesSubtitle,
                      format: context.l10n.dataExportFormatCsv,
                      type: 'messages',
                      onExport: _exportMessages,
                      onClear: () => _confirmClear(
                        'messages',
                        context.l10n.dataExportClearAllMessages,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppTheme.spacing24),

              // Telemetry
              _buildSectionHeader(context.l10n.dataExportSectionTelemetry),
              Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(color: context.border),
                ),
                child: Column(
                  children: [
                    _buildExportTile(
                      icon: Icons.battery_charging_full,
                      title: context.l10n.dataExportDeviceMetrics,
                      subtitle: context.l10n.dataExportDeviceMetricsSubtitle,
                      format: context.l10n.dataExportFormatCsv,
                      type: 'device_metrics',
                      onExport: _exportDeviceMetrics,
                      onClear: () => _confirmClear(
                        'device_metrics',
                        context.l10n.dataExportClearDeviceMetrics,
                      ),
                    ),
                    _buildDivider(),
                    _buildExportTile(
                      icon: Icons.thermostat,
                      title: context.l10n.dataExportEnvironmentMetrics,
                      subtitle:
                          context.l10n.dataExportEnvironmentMetricsSubtitle,
                      format: context.l10n.dataExportFormatCsv,
                      type: 'environment_metrics',
                      onExport: _exportEnvironmentMetrics,
                      onClear: () => _confirmClear(
                        'environment_metrics',
                        context.l10n.dataExportClearEnvironmentMetrics,
                      ),
                    ),
                    _buildDivider(),
                    _buildExportTile(
                      icon: Icons.air,
                      title: context.l10n.dataExportAirQuality,
                      subtitle: context.l10n.dataExportAirQualitySubtitle,
                      format: context.l10n.dataExportFormatCsv,
                      type: 'air_quality',
                      onExport: _exportAirQuality,
                      onClear: () => _confirmClear(
                        'air_quality',
                        context.l10n.dataExportClearAirQualityData,
                      ),
                    ),
                    _buildDivider(),
                    _buildExportTile(
                      icon: Icons.bolt,
                      title: context.l10n.dataExportPowerMetrics,
                      subtitle: context.l10n.dataExportPowerMetricsSubtitle,
                      format: context.l10n.dataExportFormatCsv,
                      type: 'power_metrics',
                      onExport: _exportPowerMetrics,
                      onClear: () => _confirmClear(
                        'power_metrics',
                        context.l10n.dataExportClearPowerMetrics,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppTheme.spacing24),

              // Position Data
              _buildSectionHeader(context.l10n.dataExportSectionPositionData),
              Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(color: context.border),
                ),
                child: Column(
                  children: [
                    _buildExportTile(
                      icon: Icons.location_on_outlined,
                      title: context.l10n.dataExportPositionHistory,
                      subtitle: context.l10n.dataExportPositionHistorySubtitle,
                      format: context.l10n.dataExportFormatCsv,
                      type: 'positions',
                      onExport: _exportPositions,
                      onClear: () => _confirmClear(
                        'positions',
                        context.l10n.dataExportClearPositionHistory,
                      ),
                    ),
                    _buildDivider(),
                    _buildExportTile(
                      icon: Icons.route,
                      title: context.l10n.dataExportRoutes,
                      subtitle: context.l10n.dataExportRoutesSubtitle,
                      format: context.l10n.dataExportFormatGpx,
                      type: 'routes',
                      onExport: _exportRoutes,
                      onClear: () => _confirmClear(
                        'routes',
                        context.l10n.dataExportClearAllRoutes,
                      ),
                    ),
                    _buildDivider(),
                    _buildExportTile(
                      icon: Icons.timeline,
                      title: context.l10n.dataExportTraceroutes,
                      subtitle: context.l10n.dataExportTraceroutesSubtitle,
                      format: context.l10n.dataExportFormatCsv,
                      type: 'traceroutes',
                      onExport: _exportTraceroutes,
                      onClear: () => _confirmClear(
                        'traceroutes',
                        context.l10n.dataExportClearTracerouteData,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppTheme.spacing24),

              // Device Configuration
              _buildSectionHeader(context.l10n.dataExportSectionDeviceConfig),
              Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(color: context.border),
                ),
                child: Column(
                  children: [
                    _buildExportTile(
                      icon: Icons.settings_backup_restore,
                      title: context.l10n.dataExportDeviceConfigBackupTitle,
                      subtitle:
                          context.l10n.dataExportDeviceConfigBackupSubtitle,
                      format: context.l10n.dataExportDeviceConfigFormatJson,
                      type: 'device_config_backup',
                      onExport: _exportDeviceConfig,
                      onClear: null,
                    ),
                    _buildDivider(),
                    _buildRestoreTile(
                      icon: Icons.restore,
                      title: context.l10n.dataExportDeviceConfigRestoreTitle,
                      subtitle:
                          context.l10n.dataExportDeviceConfigRestoreSubtitle,
                      format: context.l10n.dataExportDeviceConfigFormatImport,
                      type: 'device_config_restore',
                      onRestore: _restoreDeviceConfig,
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppTheme.spacing24),

              // Automations
              _buildSectionHeader(context.l10n.dataExportSectionAutomations),
              Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(color: context.border),
                ),
                child: Column(
                  children: [
                    _buildExportTile(
                      icon: Icons.auto_awesome,
                      title: context.l10n.dataExportAutomationRules,
                      subtitle: context.l10n.dataExportAutomationRulesSubtitle,
                      format: context.l10n.dataExportFormatJson,
                      type: 'automations',
                      onExport: _exportAutomations,
                      onClear: () => _confirmClear(
                        'automations',
                        context.l10n.dataExportClearAllAutomationRules,
                      ),
                    ),
                    _buildDivider(),
                    _buildExportTile(
                      icon: Icons.history,
                      title: context.l10n.dataExportExecutionLog,
                      subtitle: context.l10n.dataExportExecutionLogSubtitle,
                      format: context.l10n.dataExportFormatJson,
                      type: 'automation_log',
                      onExport: _exportAutomationLog,
                      onClear: () => _confirmClear(
                        'automation_log',
                        context.l10n.dataExportClearAutomationLog,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppTheme.spacing24),

              // Nodes
              _buildSectionHeader(context.l10n.dataExportSectionNetwork),
              Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(color: context.border),
                ),
                child: Column(
                  children: [
                    _buildExportTile(
                      icon: Icons.hub_outlined,
                      title: context.l10n.dataExportNodeList,
                      subtitle: context.l10n.dataExportNodeListSubtitle,
                      format: context.l10n.dataExportFormatCsv,
                      type: 'nodes',
                      onExport: _exportNodes,
                      onClear: null, // Can't clear nodes - managed by protocol
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppTheme.spacing24),

              // All Data
              _buildSectionHeader(context.l10n.dataExportSectionCompleteExport),
              Container(
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(
                    color: context.accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: _buildExportTile(
                  icon: Icons.archive_outlined,
                  title: context.l10n.dataExportExportAll,
                  subtitle: context.l10n.dataExportExportAllSubtitle,
                  format: context.l10n.dataExportFormatJson,
                  type: 'all',
                  onExport: _exportAll,
                  onClear: null,
                  isHighlighted: true,
                ),
              ),

              SizedBox(height: AppTheme.spacing24),

              // Clear All Data
              _buildSectionHeader(context.l10n.dataExportSectionClearData),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(
                    color: AppTheme.errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  onTap: () => _confirmClearAll(),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_forever,
                            color: AppTheme.errorRed,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.dataExportClearAll,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.errorRed,
                                ),
                              ),
                              SizedBox(height: AppTheme.spacing2),
                              Text(
                                context.l10n.dataExportClearAllSubtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.warning_amber,
                          color: AppTheme.errorRed,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacing24),

              // Info
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: AccentColors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(
                    color: AccentColors.blue.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AccentColors.blue.withValues(alpha: 0.8),
                      size: 24,
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Text(
                        context.l10n.dataExportInfoText,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacing32),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: context.textSecondary,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: context.border.withValues(alpha: 0.3),
    );
  }

  Widget _buildExportTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String format,
    required String type,
    required Future<void> Function() onExport,
    VoidCallback? onClear,
    bool isHighlighted = false,
  }) {
    final isExporting = _exportingTypes.contains(type);
    final isClearing = _clearingTypes.contains(type);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isHighlighted ? context.accentColor : context.accentColor)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Icon(
              icon,
              color: isHighlighted ? context.accentColor : context.accentColor,
              size: 22,
            ),
          ),
          SizedBox(width: AppTheme.spacing14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isHighlighted
                        ? context.accentColor
                        : context.textPrimary,
                  ),
                ),
                SizedBox(height: AppTheme.spacing2),
                Text(
                  subtitle,
                  style: context.bodySmallStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(AppTheme.radius6),
            ),
            child: Text(
              format,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.textTertiary,
              ),
            ),
          ),
          SizedBox(width: AppTheme.spacing8),
          // Clear button
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
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: context.l10n.dataExportTooltipClearData,
              ),
          ],
          SizedBox(width: AppTheme.spacing4),
          // Export button
          if (isExporting)
            LoadingIndicator(size: 20)
          else
            IconButton(
              icon: Icon(Icons.ios_share, color: context.accentColor, size: 20),
              onPressed: () => _handleExport(type, onExport),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: context.l10n.dataExportTooltipExport,
            ),
        ],
      ),
    );
  }

  Widget _buildRestoreTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String format,
    required String type,
    required Future<void> Function() onRestore,
  }) {
    final isWorking = _exportingTypes.contains(type);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Icon(icon, color: context.accentColor, size: 22),
          ),
          SizedBox(width: AppTheme.spacing14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                SizedBox(height: AppTheme.spacing2),
                Text(
                  subtitle,
                  style: context.bodySmallStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(AppTheme.radius6),
            ),
            child: Text(
              format,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.textTertiary,
              ),
            ),
          ),
          SizedBox(width: AppTheme.spacing4),
          if (isWorking)
            LoadingIndicator(size: 20)
          else
            IconButton(
              icon: Icon(
                Icons.file_upload_outlined,
                color: context.accentColor,
                size: 20,
              ),
              onPressed: () => _handleExport(type, onRestore),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: context.l10n.dataExportDeviceConfigRestoreTitle,
            ),
        ],
      ),
    );
  }

  Future<void> _handleExport(
    String type,
    Future<void> Function() exportFn,
  ) async {
    setState(() {
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
      if (mounted) {
        setState(() {
          _exportingTypes.remove(type);
        });
      }
    }
  }

  void _confirmClear(String type, String dataName) async {
    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.dataExportClearConfirmTitle(dataName),
      message: l10n.dataExportClearConfirmMsg(dataName),
      confirmLabel: l10n.dataExportClearConfirmBtn,
      isDestructive: true,
    );
    if (confirmed == true && mounted) {
      _handleClear(type);
    }
  }

  void _confirmClearAll() async {
    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.dataExportClearAllConfirmTitle,
      message: l10n.dataExportClearAllConfirmMsg,
      confirmLabel: l10n.dataExportClearAllConfirmBtn,
      isDestructive: true,
    );
    if (confirmed == true && mounted) {
      _handleClearAll();
    }
  }

  Future<void> _handleClear(String type) async {
    // Capture providers BEFORE await to avoid accessing disposed state
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
      showErrorSnackBar(context, l10n.dataExportClearFailed(e.toString()));
    } finally {
      safeSetState(() {
        _clearingTypes.remove(type);
      });
    }
  }

  Future<void> _handleClearAll() async {
    final types = [
      'messages',
      'device_metrics',
      'environment_metrics',
      'air_quality',
      'power_metrics',
      'positions',
      'routes',
      'traceroutes',
      'automation_log',
    ];

    // Capture providers BEFORE await
    final l10n = context.l10n;
    final messagesNotifier = ref.read(messagesProvider.notifier);
    final routesNotifier = ref.read(routesProvider.notifier);
    final automationRepo = ref.read(automationRepositoryProvider);

    for (final type in types) {
      safeSetState(() {
        _clearingTypes.add(type);
      });
    }

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
      await automationRepo.clearLog();

      if (!mounted) return;
      showSuccessSnackBar(context, l10n.dataExportAllDataCleared);
    } catch (e) {
      showErrorSnackBar(context, l10n.dataExportClearFailed(e.toString()));
    } finally {
      safeSetState(() {
        _clearingTypes.clear();
      });
    }
  }

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

    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 100, 100);
    final safePosition = getSafeSharePosition(context, sharePositionOrigin);

    try {
      final capture = await backupService.capture();
      if (!mounted) return;

      final bundle = capture.bundle;
      final json = bundle.encode();
      final filename = bundle.suggestedFilename();

      final tempDir = await getTemporaryDirectory();
      if (!mounted) return;
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(json);
      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: l10n.dataExportDeviceConfigBackupShareSubject,
        sharePositionOrigin: safePosition,
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

  Future<void> _exportMessages() async {
    final messages = ref.read(messagesProvider);
    final nodes = ref.read(nodesProvider);

    final buffer = StringBuffer();
    buffer.writeln('timestamp,from_node,from_name,channel,message,is_direct');

    for (final msg in messages) {
      final fromNode = nodes[msg.from];
      final fromName =
          fromNode?.longName ??
          fromNode?.shortName ??
          context.l10n.dataExportUnknownSender;
      final timestamp = msg.timestamp.toIso8601String();
      final text = msg.text.replaceAll('"', '""');
      buffer.writeln(
        '$timestamp,${msg.from},"$fromName",${msg.channel},"$text",${msg.isDirect}',
      );
    }

    await _shareText(
      buffer.toString(),
      subject: context.l10n.dataExportShareSubjectMessages,
    );
  }

  Future<void> _exportDeviceMetrics() async {
    final subject = context.l10n.dataExportShareSubjectDeviceMetrics;
    final logs = await ref.read(deviceMetricsLogsProvider.future);

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,node_num,battery_level,voltage,channel_utilization,air_util_tx,uptime', // lint-allow: hardcoded-string
    );

    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.nodeNum},${log.batteryLevel},${log.voltage},${log.channelUtilization},${log.airUtilTx},${log.uptimeSeconds}',
      );
    }

    await _shareText(buffer.toString(), subject: subject);
  }

  Future<void> _exportEnvironmentMetrics() async {
    final subject = context.l10n.dataExportShareSubjectEnvironmentMetrics;
    final logs = await ref.read(environmentMetricsLogsProvider.future);

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,node_num,temperature,relative_humidity,barometric_pressure,gas_resistance,iaq', // lint-allow: hardcoded-string
    );

    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.nodeNum},${log.temperature},${log.humidity},${log.barometricPressure},${log.gasResistance},${log.iaq}',
      );
    }

    await _shareText(buffer.toString(), subject: subject);
  }

  Future<void> _exportAirQuality() async {
    final subject = context.l10n.dataExportShareSubjectAirQuality;
    final logs = await ref.read(airQualityMetricsLogsProvider.future);

    final buffer = StringBuffer();
    buffer.writeln('timestamp,node_num,pm10,pm25,pm100,co2');

    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.nodeNum},${log.pm10Standard},${log.pm25Standard},${log.pm100Standard},${log.co2}',
      );
    }

    await _shareText(buffer.toString(), subject: subject);
  }

  Future<void> _exportPowerMetrics() async {
    final subject = context.l10n.dataExportShareSubjectPowerMetrics;
    final logs = await ref.read(powerMetricsLogsProvider.future);

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,node_num,ch1_voltage,ch1_current,ch2_voltage,ch2_current,ch3_voltage,ch3_current', // lint-allow: hardcoded-string
    );

    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.nodeNum},${log.ch1Voltage},${log.ch1Current},${log.ch2Voltage},${log.ch2Current},${log.ch3Voltage},${log.ch3Current}',
      );
    }

    await _shareText(buffer.toString(), subject: subject);
  }

  Future<void> _exportPositions() async {
    final subject = context.l10n.dataExportShareSubjectPositionHistory;
    final logs = await ref.read(positionLogsProvider.future);

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,node_num,latitude,longitude,altitude,sats_in_view,ground_speed,ground_track', // lint-allow: hardcoded-string
    );

    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.nodeNum},${log.latitude},${log.longitude},${log.altitude},${log.satsInView},${log.speed},${log.heading}',
      );
    }

    await _shareText(buffer.toString(), subject: subject);
  }

  Future<void> _exportRoutes() async {
    final routes = ref.read(routesProvider);

    if (routes.isEmpty) {
      if (mounted) {
        showInfoSnackBar(context, context.l10n.dataExportNoRoutesToExport);
      }
      return;
    }

    // Export as GPX
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
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

    await _shareText(
      buffer.toString(),
      subject: context.l10n.dataExportShareSubjectRoutes,
    );
  }

  Future<void> _exportTraceroutes() async {
    final l10n = context.l10n;
    final logs = await ref.read(traceRouteLogsProvider.future);

    final buffer = StringBuffer();
    buffer.writeln('timestamp,target_node,hops,route,snr_values');

    for (final log in logs) {
      final hopNodes = log.hops.map((h) => h.nodeNum).join('>');
      final snrValues = log.hops
          .map((h) => h.snr ?? l10n.dataExportSnrNotAvailable)
          .join(',');
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.targetNode},${log.hops.length},"$hopNodes","$snrValues"',
      );
    }

    await _shareText(
      buffer.toString(),
      subject: l10n.dataExportShareSubjectTraceroutes,
    );
  }

  Future<void> _exportAutomations() async {
    final repo = ref.read(automationRepositoryProvider);
    final automations = repo.automations;

    if (automations.isEmpty) {
      if (mounted) {
        showInfoSnackBar(context, context.l10n.dataExportNoAutomationsToExport);
      }
      return;
    }

    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'version': '1.0',
      'automations': automations.map((a) => a.toJson()).toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(data);
    await _shareText(
      json,
      subject: context.l10n.dataExportShareSubjectAutomations,
    );
  }

  Future<void> _exportAutomationLog() async {
    final repo = ref.read(automationRepositoryProvider);
    final log = repo.log;

    if (log.isEmpty) {
      if (mounted) {
        showInfoSnackBar(
          context,
          context.l10n.dataExportNoAutomationLogEntries,
        );
      }
      return;
    }

    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'version': '1.0',
      'executionLog': log.map((l) => l.toJson()).toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(data);
    await _shareText(
      json,
      subject: context.l10n.dataExportShareSubjectAutomationLog,
    );
  }

  Future<void> _exportNodes() async {
    final nodes = ref.read(nodesProvider);

    final buffer = StringBuffer();
    buffer.writeln(
      'node_num,user_id,long_name,short_name,hardware,role,latitude,longitude,altitude,battery_level,snr,last_heard', // lint-allow: hardcoded-string
    );

    for (final node in nodes.values) {
      buffer.writeln(
        '${node.nodeNum},"${node.userId ?? ''}","${node.longName ?? ''}","${node.shortName ?? ''}","${node.hardwareModel ?? ''}","${node.role ?? ''}",${node.latitude ?? ''},${node.longitude ?? ''},${node.altitude ?? ''},${node.batteryLevel ?? ''},${node.snr ?? ''},${node.lastHeard?.toIso8601String() ?? ''}',
      );
    }

    await _shareText(
      buffer.toString(),
      subject: context.l10n.dataExportShareSubjectNodeList,
    );
  }

  Future<void> _exportAll() async {
    final nodes = ref.read(nodesProvider);
    final messages = ref.read(messagesProvider);
    final deviceMetrics = await ref.read(deviceMetricsLogsProvider.future);
    final envMetrics = await ref.read(environmentMetricsLogsProvider.future);
    final airQuality = await ref.read(airQualityMetricsLogsProvider.future);
    final powerMetrics = await ref.read(powerMetricsLogsProvider.future);
    final positions = await ref.read(positionLogsProvider.future);
    if (!mounted) return;
    final routes = ref.read(routesProvider);
    final traceroutes = await ref.read(traceRouteLogsProvider.future);

    // Get automation data
    if (!mounted) return;
    final automationRepo = ref.read(automationRepositoryProvider);

    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'version': '1.0',
      'nodes': nodes.values.map((n) => _nodeToMap(n)).toList(),
      'messages': messages.map((m) => _messageToMap(m)).toList(),
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

    final json = const JsonEncoder.withIndent('  ').convert(data);

    await _shareText(
      json,
      subject: context.l10n.dataExportShareSubjectComplete,
    );
  }

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
