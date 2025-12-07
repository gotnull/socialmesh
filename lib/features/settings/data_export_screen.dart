import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../utils/snackbar.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/telemetry_providers.dart';
import '../automations/automation_providers.dart';

class DataExportScreen extends ConsumerStatefulWidget {
  const DataExportScreen({super.key});

  @override
  ConsumerState<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends ConsumerState<DataExportScreen> {
  final Set<String> _exportingTypes = {};
  final Set<String> _clearingTypes = {};

  /// Helper to share with proper iPad support
  Future<void> _shareText(String text, {String? subject}) async {
    // Use screen center for iPad popover positioning
    final size = MediaQuery.of(context).size;
    final sharePositionOrigin = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
    await Share.share(
      text,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Export Data',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Messages
          _buildSectionHeader('Messages'),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              children: [
                _buildExportTile(
                  icon: Icons.message_outlined,
                  title: 'All Messages',
                  subtitle: 'Export all channel and direct messages',
                  format: 'CSV',
                  type: 'messages',
                  onExport: _exportMessages,
                  onClear: () => _confirmClear('messages', 'all messages'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Telemetry
          _buildSectionHeader('Telemetry'),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              children: [
                _buildExportTile(
                  icon: Icons.battery_charging_full,
                  title: 'Device Metrics',
                  subtitle: 'Battery, voltage, utilization logs',
                  format: 'CSV',
                  type: 'device_metrics',
                  onExport: _exportDeviceMetrics,
                  onClear: () =>
                      _confirmClear('device_metrics', 'device metrics'),
                ),
                _buildDivider(),
                _buildExportTile(
                  icon: Icons.thermostat,
                  title: 'Environment Metrics',
                  subtitle: 'Temperature, humidity, pressure logs',
                  format: 'CSV',
                  type: 'environment_metrics',
                  onExport: _exportEnvironmentMetrics,
                  onClear: () => _confirmClear(
                    'environment_metrics',
                    'environment metrics',
                  ),
                ),
                _buildDivider(),
                _buildExportTile(
                  icon: Icons.air,
                  title: 'Air Quality',
                  subtitle: 'PM2.5, PM10, CO2 readings',
                  format: 'CSV',
                  type: 'air_quality',
                  onExport: _exportAirQuality,
                  onClear: () =>
                      _confirmClear('air_quality', 'air quality data'),
                ),
                _buildDivider(),
                _buildExportTile(
                  icon: Icons.bolt,
                  title: 'Power Metrics',
                  subtitle: 'Channel voltage and current',
                  format: 'CSV',
                  type: 'power_metrics',
                  onExport: _exportPowerMetrics,
                  onClear: () =>
                      _confirmClear('power_metrics', 'power metrics'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Position Data
          _buildSectionHeader('Position Data'),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              children: [
                _buildExportTile(
                  icon: Icons.location_on_outlined,
                  title: 'Position History',
                  subtitle: 'GPS position logs with timestamps',
                  format: 'CSV',
                  type: 'positions',
                  onExport: _exportPositions,
                  onClear: () => _confirmClear('positions', 'position history'),
                ),
                _buildDivider(),
                _buildExportTile(
                  icon: Icons.route,
                  title: 'Routes',
                  subtitle: 'Recorded routes and tracks',
                  format: 'GPX',
                  type: 'routes',
                  onExport: _exportRoutes,
                  onClear: () => _confirmClear('routes', 'all routes'),
                ),
                _buildDivider(),
                _buildExportTile(
                  icon: Icons.timeline,
                  title: 'Traceroutes',
                  subtitle: 'Network path analysis',
                  format: 'CSV',
                  type: 'traceroutes',
                  onExport: _exportTraceroutes,
                  onClear: () =>
                      _confirmClear('traceroutes', 'traceroute data'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Automations
          _buildSectionHeader('Automations'),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              children: [
                _buildExportTile(
                  icon: Icons.auto_awesome,
                  title: 'Automation Rules',
                  subtitle: 'All automation configurations',
                  format: 'JSON',
                  type: 'automations',
                  onExport: _exportAutomations,
                  onClear: () =>
                      _confirmClear('automations', 'all automation rules'),
                ),
                _buildDivider(),
                _buildExportTile(
                  icon: Icons.history,
                  title: 'Execution Log',
                  subtitle: 'Automation trigger history with results',
                  format: 'JSON',
                  type: 'automation_log',
                  onExport: _exportAutomationLog,
                  onClear: () =>
                      _confirmClear('automation_log', 'automation log'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Nodes
          _buildSectionHeader('Network'),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              children: [
                _buildExportTile(
                  icon: Icons.hub_outlined,
                  title: 'Node List',
                  subtitle: 'All discovered nodes with details',
                  format: 'CSV',
                  type: 'nodes',
                  onExport: _exportNodes,
                  onClear: null, // Can't clear nodes - managed by protocol
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // All Data
          _buildSectionHeader('Complete Export'),
          Container(
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: _buildExportTile(
              icon: Icons.archive_outlined,
              title: 'Export All Data',
              subtitle: 'Complete backup of all app data',
              format: 'JSON',
              type: 'all',
              onExport: _exportAll,
              onClear: null,
              isHighlighted: true,
            ),
          ),

          const SizedBox(height: 24),

          // Clear All Data
          _buildSectionHeader('Clear Data'),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.errorRed.withValues(alpha: 0.3),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _confirmClearAll(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_forever,
                        color: AppTheme.errorRed,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clear All Data',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.errorRed,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Delete all stored telemetry, routes, and logs',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.warning_amber,
                      color: AppTheme.errorRed,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AccentColors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
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
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Exported files can be shared via email, AirDrop, or saved to Files. Tap the trash icon to clear specific data.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: AppTheme.darkBorder.withValues(alpha: 0.3),
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isHighlighted ? context.accentColor : context.accentColor)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isHighlighted ? context.accentColor : context.accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isHighlighted ? context.accentColor : Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              format,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Clear button
          if (onClear != null) ...[
            if (isClearing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.errorRed,
                ),
              )
            else
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: AppTheme.textTertiary.withValues(alpha: 0.6),
                  size: 20,
                ),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Clear data',
              ),
          ],
          const SizedBox(width: 4),
          // Export button
          if (isExporting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: Icon(Icons.ios_share, color: context.accentColor, size: 20),
              onPressed: () => _handleExport(type, onExport),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Export',
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
        showErrorSnackBar(context, 'Export failed: $e');
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
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Clear $dataName?',
      message:
          'This will permanently delete all $dataName. This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed == true && mounted) {
      _handleClear(type);
    }
  }

  void _confirmClearAll() async {
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Clear All Data?',
      message:
          'This will permanently delete ALL stored data including telemetry, routes, and automation logs. This action cannot be undone.',
      confirmLabel: 'Delete All',
      isDestructive: true,
    );
    if (confirmed == true && mounted) {
      _handleClearAll();
    }
  }

  Future<void> _handleClear(String type) async {
    setState(() {
      _clearingTypes.add(type);
    });

    try {
      final storage = await ref.read(telemetryStorageProvider.future);

      switch (type) {
        case 'messages':
          ref.read(messagesProvider.notifier).clearMessages();
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
          await routeStorage.clearAllRoutes();
          ref.read(routesProvider.notifier).refresh();
          break;
        case 'traceroutes':
          await storage.clearTraceRouteLogs();
          break;
        case 'automations':
          final repo = ref.read(automationRepositoryProvider);
          for (final auto in repo.automations.toList()) {
            await repo.deleteAutomation(auto.id);
          }
          ref.read(automationsProvider.notifier).refresh();
          break;
        case 'automation_log':
          final repo = ref.read(automationRepositoryProvider);
          await repo.clearLog();
          break;
      }

      if (mounted) {
        showAppSnackBar(context, 'Data cleared');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to clear data: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _clearingTypes.remove(type);
        });
      }
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

    for (final type in types) {
      setState(() {
        _clearingTypes.add(type);
      });
    }

    try {
      final storage = await ref.read(telemetryStorageProvider.future);
      ref.read(messagesProvider.notifier).clearMessages();
      await storage.clearAllData();

      final routeStorage = await ref.read(routeStorageProvider.future);
      await routeStorage.clearAllRoutes();
      ref.read(routesProvider.notifier).refresh();

      final repo = ref.read(automationRepositoryProvider);
      await repo.clearLog();

      if (mounted) {
        showAppSnackBar(context, 'All data cleared');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to clear data: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _clearingTypes.clear();
        });
      }
    }
  }

  Future<void> _exportMessages() async {
    final messages = ref.read(messagesProvider);
    final nodes = ref.read(nodesProvider);

    final buffer = StringBuffer();
    buffer.writeln('timestamp,from_node,from_name,channel,message,is_direct');

    for (final msg in messages) {
      final fromNode = nodes[msg.from];
      final fromName = fromNode?.longName ?? fromNode?.shortName ?? 'Unknown';
      final timestamp = msg.timestamp.toIso8601String();
      final text = msg.text.replaceAll('"', '""');
      buffer.writeln(
        '$timestamp,${msg.from},"$fromName",${msg.channel},"$text",${msg.isDirect}',
      );
    }

    await _shareText(buffer.toString(), subject: 'Socialmesh Messages Export');
  }

  Future<void> _exportDeviceMetrics() async {
    final logs = await ref.read(deviceMetricsLogsProvider.future);

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,node_num,battery_level,voltage,channel_utilization,air_util_tx,uptime',
    );

    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.nodeNum},${log.batteryLevel},${log.voltage},${log.channelUtilization},${log.airUtilTx},${log.uptimeSeconds}',
      );
    }

    await _shareText(
      buffer.toString(),
      subject: 'Socialmesh Device Metrics Export',
    );
  }

  Future<void> _exportEnvironmentMetrics() async {
    final logs = await ref.read(environmentMetricsLogsProvider.future);

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,node_num,temperature,relative_humidity,barometric_pressure,gas_resistance,iaq',
    );

    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.nodeNum},${log.temperature},${log.humidity},${log.barometricPressure},${log.gasResistance},${log.iaq}',
      );
    }

    await _shareText(
      buffer.toString(),
      subject: 'Socialmesh Environment Metrics Export',
    );
  }

  Future<void> _exportAirQuality() async {
    final logs = await ref.read(airQualityMetricsLogsProvider.future);

    final buffer = StringBuffer();
    buffer.writeln('timestamp,node_num,pm10,pm25,pm100,co2');

    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.nodeNum},${log.pm10Standard},${log.pm25Standard},${log.pm100Standard},${log.co2}',
      );
    }

    await _shareText(
      buffer.toString(),
      subject: 'Socialmesh Air Quality Export',
    );
  }

  Future<void> _exportPowerMetrics() async {
    final logs = await ref.read(powerMetricsLogsProvider.future);

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,node_num,ch1_voltage,ch1_current,ch2_voltage,ch2_current,ch3_voltage,ch3_current',
    );

    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.nodeNum},${log.ch1Voltage},${log.ch1Current},${log.ch2Voltage},${log.ch2Current},${log.ch3Voltage},${log.ch3Current}',
      );
    }

    await _shareText(
      buffer.toString(),
      subject: 'Socialmesh Power Metrics Export',
    );
  }

  Future<void> _exportPositions() async {
    final logs = await ref.read(positionLogsProvider.future);

    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,node_num,latitude,longitude,altitude,sats_in_view,ground_speed,ground_track',
    );

    for (final log in logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.nodeNum},${log.latitude},${log.longitude},${log.altitude},${log.satsInView},${log.speed},${log.heading}',
      );
    }

    await _shareText(
      buffer.toString(),
      subject: 'Socialmesh Position History Export',
    );
  }

  Future<void> _exportRoutes() async {
    final routes = ref.read(routesProvider);

    if (routes.isEmpty) {
      if (mounted) {
        showAppSnackBar(context, 'No routes to export');
      }
      return;
    }

    // Export as GPX
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<gpx version="1.1" creator="Socialmesh" xmlns="http://www.topografix.com/GPX/1/1">',
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
          '      <trkpt lat="${loc.latitude}" lon="${loc.longitude}">',
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

    await _shareText(buffer.toString(), subject: 'Socialmesh Routes Export');
  }

  Future<void> _exportTraceroutes() async {
    final logs = await ref.read(traceRouteLogsProvider.future);

    final buffer = StringBuffer();
    buffer.writeln('timestamp,target_node,hops,route,snr_values');

    for (final log in logs) {
      final hopNodes = log.hops.map((h) => h.nodeNum).join('>');
      final snrValues = log.hops.map((h) => h.snr ?? 'N/A').join(',');
      buffer.writeln(
        '${log.timestamp.toIso8601String()},${log.targetNode},${log.hops.length},"$hopNodes","$snrValues"',
      );
    }

    await _shareText(
      buffer.toString(),
      subject: 'Socialmesh Traceroute Export',
    );
  }

  Future<void> _exportAutomations() async {
    final repo = ref.read(automationRepositoryProvider);
    final automations = repo.automations;

    if (automations.isEmpty) {
      if (mounted) {
        showAppSnackBar(context, 'No automations to export');
      }
      return;
    }

    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'version': '1.0',
      'automations': automations.map((a) => a.toJson()).toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(data);
    await _shareText(json, subject: 'Socialmesh Automations Export');
  }

  Future<void> _exportAutomationLog() async {
    final repo = ref.read(automationRepositoryProvider);
    final log = repo.log;

    if (log.isEmpty) {
      if (mounted) {
        showAppSnackBar(context, 'No automation log entries');
      }
      return;
    }

    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'version': '1.0',
      'executionLog': log.map((l) => l.toJson()).toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(data);
    await _shareText(json, subject: 'Socialmesh Automation Log Export');
  }

  Future<void> _exportNodes() async {
    final nodes = ref.read(nodesProvider);

    final buffer = StringBuffer();
    buffer.writeln(
      'node_num,user_id,long_name,short_name,hardware,role,latitude,longitude,altitude,battery_level,snr,last_heard',
    );

    for (final node in nodes.values) {
      buffer.writeln(
        '${node.nodeNum},"${node.userId ?? ''}","${node.longName ?? ''}","${node.shortName ?? ''}","${node.hardwareModel ?? ''}","${node.role ?? ''}",${node.latitude ?? ''},${node.longitude ?? ''},${node.altitude ?? ''},${node.batteryLevel ?? ''},${node.snr ?? ''},${node.lastHeard?.toIso8601String() ?? ''}',
      );
    }

    await _shareText(buffer.toString(), subject: 'Socialmesh Node List Export');
  }

  Future<void> _exportAll() async {
    final nodes = ref.read(nodesProvider);
    final messages = ref.read(messagesProvider);
    final deviceMetrics = await ref.read(deviceMetricsLogsProvider.future);
    final envMetrics = await ref.read(environmentMetricsLogsProvider.future);
    final airQuality = await ref.read(airQualityMetricsLogsProvider.future);
    final powerMetrics = await ref.read(powerMetricsLogsProvider.future);
    final positions = await ref.read(positionLogsProvider.future);
    final routes = ref.read(routesProvider);
    final traceroutes = await ref.read(traceRouteLogsProvider.future);

    // Get automation data
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

    await _shareText(json, subject: 'Socialmesh Complete Export');
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
