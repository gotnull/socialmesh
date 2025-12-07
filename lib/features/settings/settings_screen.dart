import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../models/subscription_models.dart';
import '../../services/storage/storage_service.dart';
import '../../services/notifications/notification_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/mesh.pbenum.dart' as pbenum;
import '../device/region_selection_screen.dart';
import 'device_management_screen.dart';
import 'device_config_screen.dart';
import 'radio_config_screen.dart';
import 'position_config_screen.dart';
import 'display_config_screen.dart';
import 'mqtt_config_screen.dart';
import 'bluetooth_config_screen.dart';
import 'network_config_screen.dart';
import 'power_config_screen.dart';
import 'security_config_screen.dart';
import 'ringtone_screen.dart';
import 'subscription_screen.dart';
import 'premium_widgets.dart';
import 'ifttt_config_screen.dart';
import '../automations/automations_screen.dart';
import 'canned_responses_screen.dart';
import 'range_test_screen.dart';
import 'store_forward_config_screen.dart';
import 'detection_sensor_config_screen.dart';
import '../map/offline_maps_screen.dart';
import 'data_export_screen.dart';
import '../device/serial_config_screen.dart';
import '../device/gps_status_screen.dart';
import '../device/firmware_update_screen.dart';
import '../device/ambient_lighting_config_screen.dart';
import '../device/pax_counter_config_screen.dart';
import '../device/telemetry_config_screen.dart';
import '../debug/app_log_screen.dart';
import '../telemetry/device_metrics_log_screen.dart';
import '../telemetry/environment_metrics_log_screen.dart';
import '../telemetry/position_log_screen.dart';
import '../telemetry/traceroute_log_screen.dart';
import '../telemetry/air_quality_log_screen.dart';
import '../telemetry/pax_counter_log_screen.dart';
import '../telemetry/detection_sensor_log_screen.dart';
import '../routes/routes_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildSubscriptionSection(BuildContext context) {
    final subscriptionState = ref.watch(subscriptionStateProvider);
    final currentTier = subscriptionState.tier;

    Color tierColor;
    String tierName;
    IconData tierIcon;

    switch (currentTier) {
      case SubscriptionTier.free:
        tierColor = AppTheme.textTertiary;
        tierName = 'Free';
        tierIcon = Icons.person_outline;
      case SubscriptionTier.premium:
        tierColor = AppTheme.primaryGreen;
        tierName = 'Premium';
        tierIcon = Icons.star;
      case SubscriptionTier.pro:
        tierColor = AppTheme.accentOrange;
        tierName = 'Pro';
        tierIcon = Icons.workspace_premium;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'SUBSCRIPTION'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(tierIcon, color: tierColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              tierName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: tierColor,
                              ),
                            ),
                            if (subscriptionState.isTrialing) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningYellow.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${subscriptionState.trialDaysRemaining}d trial',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.warningYellow,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentTier == SubscriptionTier.free
                              ? 'Upgrade for more features'
                              : 'Manage subscription',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                ],
              ),
            ),
          ),
        ),
        // Trial banner if applicable
        if (subscriptionState.isTrialing)
          const Padding(padding: EdgeInsets.only(top: 8), child: TrialBanner()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsServiceAsync = ref.watch(settingsServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: settingsServiceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading settings: $error',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(settingsServiceProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (settingsService) {
          // Watch accent color for dynamic updates (triggers rebuild when changed)
          ref.watch(accentColorProvider);

          // Get current region for display
          final regionAsync = ref.watch(deviceRegionProvider);
          final regionSubtitle = regionAsync.when(
            data: (region) {
              if (region == pbenum.RegionCode.UNSET_REGION) {
                return 'Not configured';
              }
              // Find the region info for display
              final regionInfo = availableRegions
                  .where((r) => r.code == region)
                  .firstOrNull;
              if (regionInfo != null) {
                return '${regionInfo.name} (${regionInfo.frequency})';
              }
              return region.name;
            },
            loading: () => 'Loading...',
            error: (e, _) => 'Configure device radio frequency',
          );

          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Subscription Section
              _buildSubscriptionSection(context),

              const SizedBox(height: 16),

              // Connection Section
              _SectionHeader(title: 'CONNECTION'),
              _SettingsTile(
                icon: Icons.bluetooth,
                title: 'Auto-reconnect',
                subtitle: 'Automatically reconnect to last device',
                trailing: ThemedSwitch(
                  value: settingsService.autoReconnect,
                  onChanged: (value) async {
                    HapticFeedback.selectionClick();
                    await settingsService.setAutoReconnect(value);
                    setState(() {});
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Appearance Section
              const _SectionHeader(title: 'APPEARANCE'),
              _SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Accent color',
                subtitle: AccentColors.nameFor(ref.watch(accentColorProvider)),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: ref.watch(accentColorProvider),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
                onTap: () =>
                    _showAccentColorPicker(context, ref, settingsService),
              ),

              const SizedBox(height: 16),

              // Notifications Section
              _SectionHeader(title: 'NOTIFICATIONS'),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Push notifications',
                subtitle: 'Master toggle for all notifications',
                trailing: ThemedSwitch(
                  value: settingsService.notificationsEnabled,
                  onChanged: (value) async {
                    HapticFeedback.selectionClick();
                    await settingsService.setNotificationsEnabled(value);
                    setState(() {});
                  },
                ),
              ),
              if (settingsService.notificationsEnabled) ...[
                _SettingsTile(
                  icon: Icons.person_add_outlined,
                  title: 'New nodes',
                  subtitle: 'Notify when new nodes join the mesh',
                  trailing: ThemedSwitch(
                    value: settingsService.newNodeNotificationsEnabled,
                    onChanged: (value) async {
                      HapticFeedback.selectionClick();
                      await settingsService.setNewNodeNotificationsEnabled(
                        value,
                      );
                      setState(() {});
                    },
                  ),
                ),
                _SettingsTile(
                  icon: Icons.chat_bubble_outline,
                  title: 'Direct messages',
                  subtitle: 'Notify for private messages',
                  trailing: ThemedSwitch(
                    value: settingsService.directMessageNotificationsEnabled,
                    onChanged: (value) async {
                      HapticFeedback.selectionClick();
                      await settingsService
                          .setDirectMessageNotificationsEnabled(value);
                      setState(() {});
                    },
                  ),
                ),
                _SettingsTile(
                  icon: Icons.forum_outlined,
                  title: 'Channel messages',
                  subtitle: 'Notify for channel broadcasts',
                  trailing: ThemedSwitch(
                    value: settingsService.channelMessageNotificationsEnabled,
                    onChanged: (value) async {
                      HapticFeedback.selectionClick();
                      await settingsService
                          .setChannelMessageNotificationsEnabled(value);
                      setState(() {});
                    },
                  ),
                ),
                _SettingsTile(
                  icon: Icons.volume_up_outlined,
                  title: 'Sound',
                  subtitle: 'Play sound with notifications',
                  trailing: ThemedSwitch(
                    value: settingsService.notificationSoundEnabled,
                    onChanged: (value) async {
                      HapticFeedback.selectionClick();
                      await settingsService.setNotificationSoundEnabled(value);
                      setState(() {});
                    },
                  ),
                ),
                _SettingsTile(
                  icon: Icons.vibration,
                  title: 'Vibration',
                  subtitle: 'Vibrate with notifications',
                  trailing: ThemedSwitch(
                    value: settingsService.notificationVibrationEnabled,
                    onChanged: (value) async {
                      HapticFeedback.selectionClick();
                      await settingsService.setNotificationVibrationEnabled(
                        value,
                      );
                      setState(() {});
                    },
                  ),
                ),
                _SettingsTile(
                  icon: Icons.bug_report_outlined,
                  title: 'Test notification',
                  subtitle: 'Send a test notification',
                  onTap: () => _testNotification(context),
                ),
              ],

              const SizedBox(height: 16),

              // Messaging Section
              _SectionHeader(title: 'MESSAGING'),
              _SettingsTile(
                icon: Icons.bolt,
                title: 'Quick responses',
                subtitle: 'Manage canned responses for fast messaging',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CannedResponsesScreen(),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Data Section
              _SectionHeader(title: 'DATA & STORAGE'),
              _SettingsTile(
                icon: Icons.history,
                title: 'Message history',
                subtitle:
                    '${settingsService.messageHistoryLimit} messages stored',
                onTap: () => _showHistoryLimitDialog(context, settingsService),
              ),
              // Premium: Cloud Backup
              _PremiumSettingsTile(
                feature: PremiumFeature.cloudBackup,
                icon: Icons.cloud_upload,
                title: 'Cloud Backup',
                subtitle: 'Backup messages and settings to cloud',
              ),
              // Premium: Offline Maps
              _PremiumSettingsTile(
                feature: PremiumFeature.offlineMaps,
                icon: Icons.map,
                title: 'Offline Maps',
                subtitle: 'Download map regions for offline use',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OfflineMapsScreen()),
                ),
              ),
              // Premium: Message Export
              _PremiumSettingsTile(
                feature: PremiumFeature.messageExport,
                icon: Icons.download,
                title: 'Export Messages',
                subtitle: 'Export messages to PDF or CSV',
              ),
              _SettingsTile(
                icon: Icons.delete_sweep_outlined,
                title: 'Clear message history',
                subtitle: 'Delete all stored messages',
                onTap: () => _confirmClearMessages(context, ref),
              ),
              _SettingsTile(
                icon: Icons.delete_forever,
                iconColor: AppTheme.errorRed,
                title: 'Clear all data',
                titleColor: AppTheme.errorRed,
                subtitle: 'Delete messages, settings, and keys',
                onTap: () => _confirmClearData(context, ref),
              ),

              const SizedBox(height: 16),

              // Device Section
              _SectionHeader(title: 'DEVICE'),
              _SettingsTile(
                icon: Icons.language,
                title: 'Region / Frequency',
                subtitle: regionSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const RegionSelectionScreen(isInitialSetup: false),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.settings,
                title: 'Device Role & Settings',
                subtitle: 'Configure device behavior and role',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeviceConfigScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.radio,
                title: 'Radio Configuration',
                subtitle: 'LoRa settings, modem preset, power',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RadioConfigScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.gps_fixed,
                title: 'Position & GPS',
                subtitle: 'GPS mode, broadcast intervals, fixed position',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PositionConfigScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.display_settings,
                title: 'Display Settings',
                subtitle: 'Screen timeout, units, display mode',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DisplayConfigScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.bluetooth,
                title: 'Bluetooth',
                subtitle: 'Pairing mode, PIN settings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BluetoothConfigScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.wifi,
                title: 'Network',
                subtitle: 'WiFi, Ethernet, NTP settings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NetworkConfigScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.battery_full,
                title: 'Power Management',
                subtitle: 'Power saving, sleep settings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PowerConfigScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.security,
                title: 'Security',
                subtitle: 'Access controls, managed mode',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SecurityConfigScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.power_settings_new,
                title: 'Device Management',
                subtitle: 'Reboot, shutdown, factory reset',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DeviceManagementScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'Device info',
                subtitle: 'View connected device details',
                onTap: () => _showDeviceInfo(context, ref),
              ),
              _SettingsTile(
                icon: Icons.qr_code_scanner,
                title: 'Import channel via QR',
                subtitle: 'Scan a Meshtastic channel QR code',
                onTap: () => Navigator.pushNamed(context, '/qr-import'),
              ),

              const SizedBox(height: 16),

              // Modules Section
              _SectionHeader(title: 'MODULES'),
              _SettingsTile(
                icon: Icons.cloud,
                title: 'MQTT',
                subtitle: 'Configure mesh-to-internet bridge',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MqttConfigScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.webhook,
                title: 'IFTTT Integration',
                subtitle: 'Automate with webhooks and smart triggers',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IftttConfigScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.bolt,
                title: 'Automations',
                subtitle: 'Create trigger-action rules for mesh events',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AutomationsScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.radar,
                title: 'Range Test',
                subtitle: 'Test signal range with other nodes',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RangeTestScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.storage,
                title: 'Store & Forward',
                subtitle: 'Store and relay messages for offline nodes',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreForwardConfigScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.sensors,
                title: 'Detection Sensor',
                subtitle: 'Configure GPIO-based motion/door sensors',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DetectionSensorConfigScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.music_note,
                title: 'Ringtone',
                subtitle: 'Customize notification sound (RTTTL)',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RingtoneScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.lightbulb_outline,
                title: 'Ambient Lighting',
                subtitle: 'Configure LED and RGB settings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AmbientLightingConfigScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.people_outline,
                title: 'PAX Counter',
                subtitle: 'WiFi/BLE device detection settings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaxCounterConfigScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.analytics_outlined,
                title: 'Telemetry Intervals',
                subtitle: 'Configure telemetry update frequency',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TelemetryConfigScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.usb_rounded,
                title: 'Serial',
                subtitle: 'Serial port configuration',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SerialConfigScreen()),
                ),
              ),

              const SizedBox(height: 16),

              // Telemetry Section
              _SectionHeader(title: 'TELEMETRY LOGS'),
              _SettingsTile(
                icon: Icons.battery_charging_full,
                title: 'Device Metrics',
                subtitle: 'Battery, voltage, utilization history',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DeviceMetricsLogScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.thermostat,
                title: 'Environment Metrics',
                subtitle: 'Temperature, humidity, pressure logs',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EnvironmentMetricsLogScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.air,
                title: 'Air Quality',
                subtitle: 'PM2.5, PM10, CO2 readings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AirQualityLogScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.location_on_outlined,
                title: 'Position History',
                subtitle: 'GPS position logs',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PositionLogScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.timeline,
                title: 'Traceroute History',
                subtitle: 'Network path analysis logs',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TraceRouteLogScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.people_alt_outlined,
                title: 'PAX Counter Logs',
                subtitle: 'Device detection history',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaxCounterLogScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.sensors,
                title: 'Detection Sensor Logs',
                subtitle: 'Sensor event history',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DetectionSensorLogScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.route,
                title: 'Routes',
                subtitle: 'Record and manage GPS routes',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RoutesScreen()),
                ),
              ),

              const SizedBox(height: 16),

              // Tools Section
              _SectionHeader(title: 'TOOLS'),
              _SettingsTile(
                icon: Icons.gps_fixed,
                title: 'GPS Status',
                subtitle: 'View detailed GPS information',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GpsStatusScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.system_update,
                title: 'Firmware Update',
                subtitle: 'Check for device firmware updates',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FirmwareUpdateScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.ios_share,
                title: 'Export Data',
                subtitle: 'Export messages, telemetry, routes',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DataExportScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.article_outlined,
                title: 'App Log',
                subtitle: 'View application debug logs',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppLogScreen()),
                ),
              ),

              const SizedBox(height: 16),

              // About Section
              _SectionHeader(title: 'ABOUT'),
              _SettingsTile(
                icon: Icons.info,
                title: 'Socialmesh',
                subtitle: 'Meshtastic companion app • Version 1.0.0',
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Future<void> _testNotification(BuildContext context) async {
    debugPrint('🔔 Test notification button tapped');
    final notificationService = NotificationService();

    // First ensure initialized
    debugPrint('🔔 Initializing notification service...');
    await notificationService.initialize();
    debugPrint('🔔 Notification service initialized');

    // Show a test DM notification
    debugPrint('🔔 Showing test notification...');
    try {
      await notificationService.showNewMessageNotification(
        senderName: 'Gotnull',
        senderShortName: '45a1',
        message:
            'This is a test notification to verify notifications are working correctly.',
        fromNodeNum: 999999,
        playSound: true,
        vibrate: true,
      );
      debugPrint('🔔 Test notification show() completed');
    } catch (e) {
      debugPrint('🔔 Test notification error: $e');
      if (context.mounted) {
        showErrorSnackBar(context, 'Notification error: $e');
      }
      return;
    }

    if (context.mounted) {
      showAppSnackBar(
        context,
        'Test notification sent - check notification center',
      );
    }
  }

  void _showAccentColorPicker(
    BuildContext context,
    WidgetRef ref,
    SettingsService settingsService,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final currentColor = ref.watch(accentColorProvider);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Accent Color',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: AccentColors.all.map((color) {
                      final isSelected =
                          color.toARGB32() == currentColor.toARGB32();
                      return BouncyTap(
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          ref.read(accentColorProvider.notifier).state = color;
                          await settingsService.setAccentColor(
                            color.toARGB32(),
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                        scaleFactor: 0.9,
                        child: AnimatedScale(
                          scale: isSelected ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.2),
                                width: isSelected ? 3 : 2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.6),
                                        blurRadius: 12,
                                        spreadRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      key: ValueKey('check'),
                                      color: Colors.white,
                                      size: 24,
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('empty'),
                                    ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showHistoryLimitDialog(
    BuildContext context,
    SettingsService settingsService,
  ) {
    final limits = [50, 100, 200, 500, 1000];

    AppBottomSheet.showPicker<int>(
      context: context,
      title: 'Message History Limit',
      items: limits,
      selectedItem: settingsService.messageHistoryLimit,
      itemBuilder: (limit, isSelected) => ListTile(
        leading: Icon(
          isSelected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: isSelected ? context.accentColor : AppTheme.textTertiary,
        ),
        title: Text(
          '$limit messages',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'JetBrainsMono',
          ),
        ),
      ),
    ).then((selectedLimit) {
      if (selectedLimit != null) {
        settingsService.setMessageHistoryLimit(selectedLimit);
      }
    });
  }

  Future<void> _confirmClearMessages(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text(
          'Clear Messages',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete all stored messages. This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ref.read(messagesProvider.notifier).clearMessages();
      showAppSnackBar(context, 'Messages cleared');
    }
  }

  Future<void> _confirmClearData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text(
          'Clear All Data',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete all messages, settings, and channel keys. This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final secureStorage = ref.read(secureStorageProvider);
      final settingsServiceAsync = ref.read(settingsServiceProvider);
      final messagesNotifier = ref.read(messagesProvider.notifier);
      final nodesNotifier = ref.read(nodesProvider.notifier);
      final channelsNotifier = ref.read(channelsProvider.notifier);

      await secureStorage.clearAll();

      settingsServiceAsync.whenData((settingsService) async {
        await settingsService.clearAll();
      });

      messagesNotifier.clearMessages();
      nodesNotifier.clearNodes();
      channelsNotifier.clearChannels();

      if (context.mounted) {
        showAppSnackBar(context, 'All data cleared');
      }
    }
  }

  void _showDeviceInfo(BuildContext context, WidgetRef ref) {
    final connectedDevice = ref.read(connectedDeviceProvider);
    final myNodeNum = ref.read(myNodeNumProvider);
    final nodes = ref.read(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Device Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          InfoTable(
            rows: [
              InfoTableRow(
                label: 'Device Name',
                value: connectedDevice?.name ?? 'Not connected',
                icon: Icons.bluetooth,
              ),
              InfoTableRow(
                label: 'Connection',
                value: connectedDevice?.type.name.toUpperCase() ?? 'None',
                icon: Icons.wifi,
              ),
              InfoTableRow(
                label: 'Node Number',
                value: myNodeNum?.toString() ?? 'Unknown',
                icon: Icons.tag,
              ),
              InfoTableRow(
                label: 'Long Name',
                value: myNode?.longName ?? 'Unknown',
                icon: Icons.badge_outlined,
              ),
              InfoTableRow(
                label: 'Short Name',
                value: myNode?.shortName ?? 'Unknown',
                icon: Icons.short_text,
              ),
              InfoTableRow(
                label: 'Hardware',
                value: myNode?.hardwareModel ?? 'Unknown',
                icon: Icons.memory_outlined,
              ),
              InfoTableRow(
                label: 'User ID',
                value: myNode?.userId ?? 'Unknown',
                icon: Icons.fingerprint,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textTertiary,

          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Color? titleColor;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    this.titleColor,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: iconColor ?? AppTheme.textSecondary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: titleColor ?? Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (onTap != null)
                  const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings tile with premium feature gating
class _PremiumSettingsTile extends ConsumerWidget {
  final PremiumFeature feature;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _PremiumSettingsTile({
    required this.feature,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFeature = ref.watch(hasFeatureProvider(feature));
    final info = FeatureInfo.getInfo(feature);
    final tierColor =
        (info?.minimumTier ?? SubscriptionTier.premium) == SubscriptionTier.pro
        ? AppTheme.accentOrange
        : AppTheme.primaryGreen;
    final tierName =
        (info?.minimumTier ?? SubscriptionTier.premium) == SubscriptionTier.pro
        ? 'PRO'
        : 'PREMIUM';

    final effectiveOnTap = hasFeature
        ? onTap
        : () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
          );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: effectiveOnTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Stack(
                  children: [
                    Icon(
                      icon,
                      color: hasFeature
                          ? AppTheme.textSecondary
                          : AppTheme.textTertiary.withValues(alpha: 0.5),
                    ),
                    if (!hasFeature)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: tierColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: hasFeature
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          if (!hasFeature) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tierColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tierName,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: tierColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasFeature
                            ? subtitle
                            : 'Upgrade to unlock this feature',
                        style: TextStyle(
                          fontSize: 13,
                          color: hasFeature
                              ? AppTheme.textTertiary
                              : AppTheme.textTertiary.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
