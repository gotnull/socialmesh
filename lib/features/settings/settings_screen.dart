import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging.dart';
import '../../config/admin_config.dart';
import '../../config/revenuecat_config.dart';
import '../../core/transport.dart' show DeviceConnectionState;
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
// import '../../providers/social_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/subscription_providers.dart';
import '../../providers/signal_bookmark_provider.dart';
import '../../providers/signal_providers.dart';
import '../../providers/glyph_provider.dart';
import '../../models/subscription_models.dart';
import '../../services/storage/storage_service.dart';
import '../../services/notifications/push_notification_service.dart';
import '../../services/haptic_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../core/widgets/remote_admin_selector_sheet.dart';
import '../../core/widgets/secret_gesture_detector.dart';
import '../../core/widgets/user_avatar.dart';
import '../../providers/help_providers.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
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
import 'ifttt_config_screen.dart';
import 'theme_settings_screen.dart';
import '../automations/automations_screen.dart';
import '../automations/automation_providers.dart';
import 'canned_responses_screen.dart';
import 'canned_message_module_config_screen.dart';
import 'range_test_screen.dart';
import 'glyph_test_screen.dart';
import 'store_forward_config_screen.dart';
import 'detection_sensor_config_screen.dart';
import 'external_notification_config_screen.dart';
import 'account_subscriptions_screen.dart';
import 'linked_devices_screen.dart';
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
import '../widget_builder/widget_builder_screen.dart';
import 'debug_settings_screen.dart';
import 'screens/help_center_screen.dart';
// import '../social/screens/follow_requests_screen.dart';
import '../../core/widgets/loading_indicator.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Get all searchable settings items
  List<_SearchableSettingItem> _getSearchableSettings(
    BuildContext context,
    WidgetRef ref,
  ) {
    final settingsServiceAsync = ref.read(settingsServiceProvider);
    final purchaseState = ref.watch(purchaseStateProvider);
    final storeProductsAsync = ref.watch(storeProductsProvider);
    final storeProducts = storeProductsAsync.when(
      data: (data) => data,
      loading: () => <String, StoreProductInfo>{},
      error: (e, s) => <String, StoreProductInfo>{},
    );

    return settingsServiceAsync.maybeWhen(
      data: (settingsService) => [
        // Upgrades
        _SearchableSettingItem(
          icon: Icons.rocket_launch_rounded,
          title: 'Unlock Premium Features',
          subtitle: 'Ringtones, themes, automations, IFTTT, widgets',
          keywords: ['premium', 'upgrade', 'purchase', 'buy', 'subscription'],
          section: 'UPGRADES',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.music_note,
          title:
              storeProducts[RevenueCatConfig.ringtonePackProductId]?.title ??
              'Ringtone Pack',
          subtitle: 'Custom notification sounds',
          keywords: ['sound', 'audio', 'tone', 'music', 'alert'],
          section: 'UPGRADES',
          onTap: () {
            if (purchaseState.hasFeature(PremiumFeature.customRingtones)) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RingtoneScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        _SearchableSettingItem(
          icon: Icons.palette,
          title:
              storeProducts[RevenueCatConfig.themePackProductId]?.title ??
              'Theme Pack',
          subtitle: 'Accent colors and visual customization',
          keywords: ['color', 'accent', 'visual', 'appearance', 'dark'],
          section: 'UPGRADES',
          onTap: () {
            if (purchaseState.hasFeature(PremiumFeature.premiumThemes)) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        _SearchableSettingItem(
          icon: Icons.bolt,
          title:
              storeProducts[RevenueCatConfig.automationsPackProductId]?.title ??
              'Automations Pack',
          subtitle: 'Automated actions and triggers',
          keywords: ['auto', 'trigger', 'action', 'rule', 'automatic'],
          section: 'UPGRADES',
          onTap: () {
            if (purchaseState.hasFeature(PremiumFeature.automations)) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AutomationsScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        _SearchableSettingItem(
          icon: Icons.webhook,
          title:
              storeProducts[RevenueCatConfig.iftttPackProductId]?.title ??
              'IFTTT Pack',
          subtitle: 'Integration with external services',
          keywords: ['integration', 'webhook', 'external', 'connect'],
          section: 'UPGRADES',
          onTap: () {
            if (purchaseState.hasFeature(PremiumFeature.iftttIntegration)) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IftttConfigScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        _SearchableSettingItem(
          icon: Icons.widgets,
          title:
              storeProducts[RevenueCatConfig.widgetPackProductId]?.title ??
              'Widget Pack',
          subtitle: 'Home screen widgets',
          keywords: ['home', 'widget', 'screen', 'launcher'],
          section: 'UPGRADES',
          onTap: () {
            if (purchaseState.hasFeature(PremiumFeature.homeWidgets)) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WidgetBuilderScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),

        // Profile
        _SearchableSettingItem(
          icon: Icons.person_outline,
          title: 'Profile',
          subtitle: 'Your display name, avatar, and bio',
          keywords: ['user', 'name', 'avatar', 'account', 'bio'],
          section: 'ACCOUNT',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AccountSubscriptionsScreen(),
            ),
          ),
        ),

        // Social Notifications
        _SearchableSettingItem(
          icon: Icons.person_add_outlined,
          title: 'New followers',
          subtitle: 'Push notifications when someone follows you',
          keywords: ['social', 'notification', 'follow', 'follower'],
          section: 'SOCIAL NOTIFICATIONS',
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.favorite_outline,
          title: 'Likes',
          subtitle: 'Push notifications for post likes',
          keywords: ['social', 'notification', 'like', 'heart'],
          section: 'SOCIAL NOTIFICATIONS',
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.chat_bubble_outline,
          title: 'Comments & mentions',
          subtitle: 'Push notifications for comments and @mentions',
          keywords: ['social', 'notification', 'comment', 'mention', 'reply'],
          section: 'SOCIAL NOTIFICATIONS',
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.devices,
          title: 'Linked Devices',
          subtitle: 'Meshtastic devices connected to your profile',
          keywords: ['device', 'node', 'link', 'mesh', 'meshtastic', 'connect'],
          section: 'PROFILE',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LinkedDevicesScreen()),
          ),
        ),

        // Connection
        _SearchableSettingItem(
          icon: Icons.bluetooth,
          title: 'Auto-reconnect',
          subtitle: 'Automatically reconnect to last device',
          keywords: ['bluetooth', 'connect', 'device', 'auto'],
          section: 'CONNECTION',
          hasSwitch: true,
        ),

        // Haptic Feedback
        _SearchableSettingItem(
          icon: Icons.vibration,
          title: 'Haptic feedback',
          subtitle: 'Vibration feedback for interactions',
          keywords: ['vibration', 'haptic', 'touch', 'feedback'],
          section: 'HAPTIC FEEDBACK',
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.tune,
          title: 'Haptic Intensity',
          subtitle: 'Light, medium, or heavy feedback',
          keywords: ['vibration', 'strength', 'intensity'],
          section: 'HAPTIC FEEDBACK',
        ),

        // Animations
        _SearchableSettingItem(
          icon: Icons.animation,
          title: 'List animations',
          subtitle: 'Slide and bounce effects on lists',
          keywords: ['animation', 'motion', 'effect', 'slide', 'bounce'],
          section: 'ANIMATIONS',
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.view_in_ar,
          title: '3D effects',
          subtitle: 'Perspective transforms and depth effects',
          keywords: ['3d', 'depth', 'perspective', 'transform'],
          section: 'ANIMATIONS',
          hasSwitch: true,
        ),

        // Notifications
        _SearchableSettingItem(
          icon: Icons.notifications_outlined,
          title: 'Push notifications',
          subtitle: 'Master toggle for all notifications',
          keywords: ['notification', 'alert', 'push', 'notify'],
          section: 'NOTIFICATIONS',
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.person_add_outlined,
          title: 'New nodes notifications',
          subtitle: 'Notify when new nodes join the mesh',
          keywords: ['notification', 'node', 'join', 'new'],
          section: 'NOTIFICATIONS',
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.chat_bubble_outline,
          title: 'Direct message notifications',
          subtitle: 'Notify for private messages',
          keywords: ['notification', 'dm', 'direct', 'message', 'private'],
          section: 'NOTIFICATIONS',
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.forum_outlined,
          title: 'Channel message notifications',
          subtitle: 'Notify for channel broadcasts',
          keywords: ['notification', 'channel', 'broadcast', 'group'],
          section: 'NOTIFICATIONS',
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.volume_up_outlined,
          title: 'Notification sound',
          subtitle: 'Play sound for notifications',
          keywords: ['sound', 'audio', 'alert', 'ring'],
          section: 'NOTIFICATIONS',
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.vibration,
          title: 'Notification vibration',
          subtitle: 'Vibrate for notifications',
          keywords: ['vibrate', 'haptic', 'buzz'],
          section: 'NOTIFICATIONS',
          hasSwitch: true,
        ),

        // Messaging
        _SearchableSettingItem(
          icon: Icons.flash_on_outlined,
          title: 'Quick responses',
          subtitle: 'Show quick response bar',
          keywords: ['quick', 'response', 'reply', 'fast'],
          section: 'MESSAGING',
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.message_outlined,
          title: 'Canned Messages',
          subtitle: 'Pre-configured device messages',
          keywords: ['canned', 'preset', 'template', 'message'],
          section: 'MESSAGING',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CannedMessageModuleConfigScreen(),
            ),
          ),
        ),

        // Data & Storage
        _SearchableSettingItem(
          icon: Icons.history,
          title: 'Message history limit',
          subtitle: 'Maximum messages to keep',
          keywords: ['history', 'limit', 'storage', 'message', 'keep'],
          section: 'DATA & STORAGE',
        ),
        _SearchableSettingItem(
          icon: Icons.map_outlined,
          title: 'Offline maps',
          subtitle: 'Download maps for offline use',
          keywords: ['map', 'offline', 'download', 'cache'],
          section: 'DATA & STORAGE',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OfflineMapsScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.ios_share,
          title: 'Export data',
          subtitle: 'Export messages and settings',
          keywords: ['export', 'backup', 'download', 'save'],
          section: 'DATA & STORAGE',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DataExportScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.delete_outline,
          title: 'Clear all messages',
          subtitle: 'Delete all stored messages',
          keywords: ['clear', 'delete', 'remove', 'message', 'clean'],
          section: 'DATA & STORAGE',
        ),
        _SearchableSettingItem(
          icon: Icons.refresh,
          title: 'Reset local data',
          subtitle: 'Clear all local app data',
          keywords: ['reset', 'clear', 'local', 'data', 'factory'],
          section: 'DATA & STORAGE',
        ),

        // Device
        _SearchableSettingItem(
          icon: Icons.sync,
          title: 'Force sync',
          subtitle: 'Force configuration sync',
          keywords: ['sync', 'force', 'refresh', 'update'],
          section: 'DEVICE',
        ),
        _SearchableSettingItem(
          icon: Icons.qr_code_scanner,
          title: 'Scan for device',
          subtitle: 'Scan QR code for easy setup',
          keywords: ['scan', 'qr', 'device', 'setup', 'connect'],
          section: 'DEVICE',
        ),
        _SearchableSettingItem(
          icon: Icons.public,
          title: 'Region',
          subtitle: 'Device radio frequency region',
          keywords: ['region', 'frequency', 'country', 'radio'],
          section: 'DEVICE',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegionSelectionScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.settings,
          title: 'Device config',
          subtitle: 'Device name, role, and behavior',
          keywords: ['device', 'config', 'name', 'role', 'settings'],
          section: 'DEVICE',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DeviceConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.radio,
          title: 'Radio config',
          subtitle: 'LoRa, modem, channel settings',
          keywords: ['radio', 'lora', 'modem', 'channel', 'frequency'],
          section: 'DEVICE',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RadioConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.my_location,
          title: 'Position config',
          subtitle: 'GPS and position sharing',
          keywords: ['gps', 'position', 'location', 'share'],
          section: 'DEVICE',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PositionConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.display_settings_outlined,
          title: 'Display config',
          subtitle: 'Screen brightness and timeout',
          keywords: ['display', 'screen', 'brightness', 'oled', 'timeout'],
          section: 'DEVICE',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DisplayConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.bluetooth_searching,
          title: 'Bluetooth config',
          subtitle: 'Bluetooth settings and PIN',
          keywords: ['bluetooth', 'ble', 'pin', 'pairing'],
          section: 'DEVICE',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BluetoothConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.wifi,
          title: 'Network config',
          subtitle: 'WiFi and network settings',
          keywords: ['wifi', 'network', 'internet', 'ip', 'dhcp'],
          section: 'DEVICE',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NetworkConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.battery_saver,
          title: 'Power config',
          subtitle: 'Power saving and sleep settings',
          keywords: ['power', 'battery', 'sleep', 'save', 'energy'],
          section: 'DEVICE',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PowerConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.security,
          title: 'Security',
          subtitle: 'Access controls, managed mode',
          keywords: ['security', 'access', 'lock', 'admin', 'managed'],
          section: 'DEVICE',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SecurityConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.power_settings_new,
          title: 'Device Management',
          subtitle: 'Reboot, shutdown, factory reset',
          keywords: ['reboot', 'shutdown', 'reset', 'restart', 'factory'],
          section: 'DEVICE',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DeviceManagementScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.info_outline,
          title: 'Device info',
          subtitle: 'View connected device details',
          keywords: ['info', 'details', 'hardware', 'version'],
          section: 'DEVICE',
        ),
        _SearchableSettingItem(
          icon: Icons.qr_code_scanner,
          title: 'Import channel via QR',
          subtitle: 'Scan a Meshtastic channel QR code',
          keywords: ['qr', 'channel', 'import', 'scan'],
          section: 'DEVICE',
          onTap: () => Navigator.pushNamed(context, '/qr-import'),
        ),

        // Modules
        _SearchableSettingItem(
          icon: Icons.cloud,
          title: 'MQTT',
          subtitle: 'Configure mesh-to-internet bridge',
          keywords: ['mqtt', 'internet', 'bridge', 'server', 'broker'],
          section: 'MODULES',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MqttConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.radar,
          title: 'Range Test',
          subtitle: 'Test signal range with other nodes',
          keywords: ['range', 'test', 'signal', 'distance'],
          section: 'MODULES',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RangeTestScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.storage,
          title: 'Store & Forward',
          subtitle: 'Store and relay messages for offline nodes',
          keywords: ['store', 'forward', 'relay', 'offline', 'cache'],
          section: 'MODULES',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StoreForwardConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.sensors,
          title: 'Detection Sensor',
          subtitle: 'Configure GPIO-based motion/door sensors',
          keywords: ['sensor', 'motion', 'door', 'gpio', 'detection'],
          section: 'MODULES',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const DetectionSensorConfigScreen(),
            ),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.notifications_active,
          title: 'External Notification',
          subtitle: 'Configure buzzers, LEDs, and vibration alerts',
          keywords: ['buzzer', 'led', 'vibration', 'external', 'alert'],
          section: 'MODULES',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ExternalNotificationConfigScreen(),
            ),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.lightbulb_outline,
          title: 'Ambient Lighting',
          subtitle: 'Configure LED and RGB settings',
          keywords: ['led', 'rgb', 'light', 'ambient', 'neopixel'],
          section: 'MODULES',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AmbientLightingConfigScreen(),
            ),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.people_outline,
          title: 'PAX Counter',
          subtitle: 'WiFi/BLE device detection settings',
          keywords: ['pax', 'counter', 'wifi', 'ble', 'detection', 'people'],
          section: 'MODULES',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaxCounterConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.analytics_outlined,
          title: 'Telemetry Intervals',
          subtitle: 'Configure telemetry update frequency',
          keywords: ['telemetry', 'interval', 'frequency', 'update'],
          section: 'MODULES',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TelemetryConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.usb_rounded,
          title: 'Serial',
          subtitle: 'Serial port configuration',
          keywords: ['serial', 'usb', 'port', 'uart'],
          section: 'MODULES',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SerialConfigScreen()),
          ),
        ),

        // Telemetry Logs
        _SearchableSettingItem(
          icon: Icons.battery_charging_full,
          title: 'Device Metrics',
          subtitle: 'Battery, voltage, utilization history',
          keywords: ['battery', 'voltage', 'metrics', 'device', 'history'],
          section: 'TELEMETRY LOGS',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DeviceMetricsLogScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.thermostat,
          title: 'Environment Metrics',
          subtitle: 'Temperature, humidity, pressure logs',
          keywords: [
            'temperature',
            'humidity',
            'pressure',
            'environment',
            'weather',
          ],
          section: 'TELEMETRY LOGS',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EnvironmentMetricsLogScreen(),
            ),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.air,
          title: 'Air Quality',
          subtitle: 'PM2.5, PM10, CO2 readings',
          keywords: ['air', 'quality', 'pm25', 'pm10', 'co2', 'pollution'],
          section: 'TELEMETRY LOGS',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AirQualityLogScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.location_on_outlined,
          title: 'Position History',
          subtitle: 'GPS position logs',
          keywords: ['position', 'gps', 'location', 'history', 'track'],
          section: 'TELEMETRY LOGS',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PositionLogScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.timeline,
          title: 'Traceroute History',
          subtitle: 'Network path analysis logs',
          keywords: ['traceroute', 'path', 'network', 'hop', 'route'],
          section: 'TELEMETRY LOGS',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TraceRouteLogScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.people_alt_outlined,
          title: 'PAX Counter Logs',
          subtitle: 'Device detection history',
          keywords: ['pax', 'counter', 'log', 'detection', 'history'],
          section: 'TELEMETRY LOGS',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaxCounterLogScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.sensors,
          title: 'Detection Sensor Logs',
          subtitle: 'Sensor event history',
          keywords: ['sensor', 'detection', 'log', 'event', 'history'],
          section: 'TELEMETRY LOGS',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DetectionSensorLogScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.route,
          title: 'Routes',
          subtitle: 'Record and manage GPS routes',
          keywords: ['route', 'gps', 'track', 'record', 'path'],
          section: 'TELEMETRY LOGS',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RoutesScreen()),
          ),
        ),

        // Tools
        _SearchableSettingItem(
          icon: Icons.gps_fixed,
          title: 'GPS Status',
          subtitle: 'View detailed GPS information',
          keywords: ['gps', 'status', 'satellite', 'location', 'fix'],
          section: 'TOOLS',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GpsStatusScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.system_update,
          title: 'Firmware Update',
          subtitle: 'Check for device firmware updates',
          keywords: ['firmware', 'update', 'ota', 'upgrade', 'version'],
          section: 'TOOLS',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FirmwareUpdateScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.ios_share,
          title: 'Export Data',
          subtitle: 'Export messages, telemetry, routes',
          keywords: ['export', 'data', 'backup', 'messages', 'telemetry'],
          section: 'TOOLS',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DataExportScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.article_outlined,
          title: 'App Log',
          subtitle: 'View application debug logs',
          keywords: ['log', 'debug', 'app', 'error', 'console'],
          section: 'TOOLS',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AppLogScreen()),
          ),
        ),
        // Glyph Test - only show on Nothing Phone 3
        if (ref.watch(glyphServiceProvider).deviceModel.contains('Phone (3)'))
          _SearchableSettingItem(
            icon: Icons.lightbulb,
            title: 'Glyph Matrix Test',
            subtitle: 'Nothing Phone 3 LED patterns',
            keywords: ['glyph', 'nothing', 'led', 'test', 'light', 'matrix'],
            section: 'TOOLS',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GlyphTestScreen()),
            ),
          ),

        // About
        _SearchableSettingItem(
          icon: Icons.info,
          title: 'Socialmesh',
          subtitle: 'Meshtastic companion app',
          keywords: ['about', 'version', 'app', 'info'],
          section: 'ABOUT',
        ),
        _SearchableSettingItem(
          icon: Icons.phone_android,
          title: 'Device Info',
          subtitle: ref.watch(glyphServiceProvider).deviceModel,
          keywords: ['device', 'phone', 'model', 'hardware', 'nothing'],
          section: 'ABOUT',
        ),
        _SearchableSettingItem(
          icon: Icons.help,
          title: 'Help Center',
          subtitle: 'Interactive guides with Ico, your mesh guide',
          keywords: ['help', 'guide', 'tutorial', 'ico', 'learn', 'tour'],
          section: 'ABOUT',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: 'FAQ, troubleshooting, and contact info',
          keywords: ['help', 'support', 'faq', 'contact', 'troubleshoot'],
          section: 'ABOUT',
          onTap: () => LegalDocumentSheet.showSupport(context),
        ),
        _SearchableSettingItem(
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          subtitle: 'Legal terms and conditions',
          keywords: ['terms', 'service', 'legal', 'tos'],
          section: 'ABOUT',
          onTap: () => LegalDocumentSheet.showTerms(context),
        ),
        _SearchableSettingItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'How we handle your data',
          keywords: ['privacy', 'policy', 'data', 'gdpr'],
          section: 'ABOUT',
          onTap: () => LegalDocumentSheet.showPrivacy(context),
        ),
        _SearchableSettingItem(
          icon: Icons.source_outlined,
          title: 'Open Source Licenses',
          subtitle: 'Third-party libraries and attributions',
          keywords: ['license', 'open', 'source', 'library', 'attribution'],
          section: 'ABOUT',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const _OpenSourceLicensesScreen(),
            ),
          ),
        ),
      ],
      orElse: () => <_SearchableSettingItem>[],
    );
  }

  /// Filter settings based on search query
  List<_SearchableSettingItem> _filterSettings(
    List<_SearchableSettingItem> settings,
    String query,
  ) {
    if (query.isEmpty) return settings;

    final lowerQuery = query.toLowerCase();
    return settings.where((item) {
      // Check title
      if (item.title.toLowerCase().contains(lowerQuery)) return true;
      // Check subtitle
      if (item.subtitle?.toLowerCase().contains(lowerQuery) ?? false) {
        return true;
      }
      // Check section
      if (item.section.toLowerCase().contains(lowerQuery)) return true;
      // Check keywords
      if (item.keywords.any((k) => k.toLowerCase().contains(lowerQuery))) {
        return true;
      }
      return false;
    }).toList();
  }

  Widget _buildSearchResults(
    BuildContext context,
    List<_SearchableSettingItem> results,
  ) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              'No settings found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(fontSize: 14, color: context.textTertiary),
            ),
          ],
        ),
      );
    }

    // Group results by section
    final grouped = <String, List<_SearchableSettingItem>>{};
    for (final item in results) {
      grouped.putIfAbsent(item.section, () => []).add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final section = grouped.keys.elementAt(index);
        final items = grouped[section]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: section),
            ...items.map(
              (item) => _SettingsTile(
                icon: item.icon,
                title: item.title,
                subtitle: item.subtitle,
                trailing: item.hasSwitch
                    ? Icon(
                        Icons.toggle_on_outlined,
                        color: context.textTertiary,
                        size: 24,
                      )
                    : null,
                onTap:
                    item.onTap ??
                    () {
                      // Clear search when tapping an item without onTap
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildUpgradesSection(BuildContext context) {
    final purchaseState = ref.watch(purchaseStateProvider);
    final storeProductsAsync = ref.watch(storeProductsProvider);
    final storeProducts = storeProductsAsync.when(
      data: (data) => data,
      loading: () => <String, StoreProductInfo>{},
      error: (e, s) => <String, StoreProductInfo>{},
    );
    final accentColor = context.accentColor;

    // Count owned items
    final ownedCount = OneTimePurchases.allPurchases
        .where((p) => purchaseState.hasPurchased(p.productId))
        .length;
    final totalCount = OneTimePurchases.allPurchases.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'UPGRADES'),
        // Main Upgrades card with accent highlight
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withValues(alpha: 0.15),
                accentColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
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
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.rocket_launch_rounded,
                        color: accentColor,
                        size: 26,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unlock Premium Features',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ownedCount == totalCount
                                ? 'All features unlocked'
                                : '$ownedCount of $totalCount features unlocked',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: accentColor),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Premium feature tiles
        _PremiumFeatureTile(
          icon: Icons.music_note,
          title:
              storeProducts[RevenueCatConfig.ringtonePackProductId]?.title ??
              'Ringtone Pack',
          feature: PremiumFeature.customRingtones,
          onTap: () {
            final hasFeature = purchaseState.hasFeature(
              PremiumFeature.customRingtones,
            );
            if (hasFeature) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RingtoneScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        _PremiumFeatureTile(
          icon: Icons.palette,
          title:
              storeProducts[RevenueCatConfig.themePackProductId]?.title ??
              'Theme Pack',
          feature: PremiumFeature.premiumThemes,
          onTap: () {
            final hasFeature = purchaseState.hasFeature(
              PremiumFeature.premiumThemes,
            );
            if (hasFeature) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        _PremiumFeatureTile(
          icon: Icons.bolt,
          title:
              storeProducts[RevenueCatConfig.automationsPackProductId]?.title ??
              'Automations Pack',
          feature: PremiumFeature.automations,
          onTap: () {
            final hasFeature = purchaseState.hasFeature(
              PremiumFeature.automations,
            );
            if (hasFeature) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AutomationsScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        _PremiumFeatureTile(
          icon: Icons.webhook,
          title:
              storeProducts[RevenueCatConfig.iftttPackProductId]?.title ??
              'IFTTT Pack',
          feature: PremiumFeature.iftttIntegration,
          onTap: () {
            final hasFeature = purchaseState.hasFeature(
              PremiumFeature.iftttIntegration,
            );
            if (hasFeature) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IftttConfigScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        _PremiumFeatureTile(
          icon: Icons.widgets,
          title:
              storeProducts[RevenueCatConfig.widgetPackProductId]?.title ??
              'Widget Pack',
          feature: PremiumFeature.homeWidgets,
          onTap: () {
            final hasFeature = purchaseState.hasFeature(
              PremiumFeature.homeWidgets,
            );
            if (hasFeature) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WidgetBuilderScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
      ],
    );
  }

  /// Build the Remote Administration selector widget
  /// Shows a tappable tile that opens a bottom sheet to select target node
  Widget _buildRemoteAdminSelector(BuildContext context, WidgetRef ref) {
    final remoteState = ref.watch(remoteAdminProvider);
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final connectedDevice = ref.watch(connectedDeviceProvider);
    final accentColor = context.accentColor;

    // Only show if we have other nodes to configure
    // Filter to nodes with public keys (can accept admin messages via PKI)
    final adminableNodes = nodes.values.where((node) {
      // Exclude our own node
      if (node.nodeNum == myNodeNum) return false;
      // Node must have a public key for PKI admin messages
      return node.hasPublicKey;
    }).toList();

    // If no other nodes, don't show the selector
    if (adminableNodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'REMOTE ADMINISTRATION'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            color: remoteState.isRemote
                ? accentColor.withValues(alpha: 0.1)
                : context.card,
            borderRadius: BorderRadius.circular(12),
            border: remoteState.isRemote
                ? Border.all(color: accentColor.withValues(alpha: 0.5))
                : null,
          ),
          child: Column(
            children: [
              ListTile(
                onTap: () async {
                  final selection = await RemoteAdminSelectorSheet.show(
                    context,
                    currentTarget: remoteState.targetNodeNum,
                  );
                  if (selection != null) {
                    if (selection.isLocal) {
                      ref.read(remoteAdminProvider.notifier).clearTarget();
                    } else {
                      ref
                          .read(remoteAdminProvider.notifier)
                          .setTarget(selection.nodeNum!, selection.nodeName);
                    }
                  }
                },
                leading: Icon(
                  remoteState.isRemote
                      ? Icons.admin_panel_settings
                      : Icons.settings_remote,
                  color: remoteState.isRemote
                      ? accentColor
                      : context.textSecondary,
                ),
                title: Text(
                  remoteState.isRemote
                      ? 'Configuring Remote Node'
                      : 'Configure Device',
                  style: TextStyle(
                    color: remoteState.isRemote
                        ? accentColor
                        : context.textPrimary,
                    fontWeight: remoteState.isRemote
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Flexible(
                      child: Text(
                        remoteState.isRemote
                            ? remoteState.targetNodeName ??
                                  '0x${remoteState.targetNodeNum!.toRadixString(16)}'
                            : connectedDevice?.name ?? 'Connected Device',
                        style: TextStyle(
                          color: remoteState.isRemote
                              ? accentColor.withValues(alpha: 0.8)
                              : context.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (remoteState.isRemote) ...[
                      SizedBox(width: 6),
                      Icon(
                        Icons.lock,
                        size: 12,
                        color: accentColor.withValues(alpha: 0.7),
                      ),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${adminableNodes.length} nodes',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: remoteState.isRemote
                          ? accentColor
                          : context.textSecondary,
                    ),
                  ],
                ),
              ),
              if (remoteState.isRemote)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Remote admin requires the target node to have your public key in its Admin Keys list.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade200,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _dismissKeyboard() {
    _searchFocusNode.unfocus();
  }

  /// PIN required to access debug settings (admin only)
  static const String _debugAccessPin = '4511932';

  /// Show PIN dialog for debug settings access
  Future<bool> _showDebugAccessPinDialog() async {
    var enteredPin = '';
    var attempts = 0;
    const maxAttempts = 3;
    var showError = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          void onKeyPress(String key) {
            HapticFeedback.lightImpact();

            if (key == 'backspace') {
              if (enteredPin.isNotEmpty) {
                setDialogState(() {
                  enteredPin = enteredPin.substring(0, enteredPin.length - 1);
                  showError = false;
                });
              }
            } else if (enteredPin.length < 10) {
              setDialogState(() {
                enteredPin += key;
                showError = false;
              });

              // Auto-submit when PIN length matches
              if (enteredPin.length == _debugAccessPin.length) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (!dialogContext.mounted) return;
                  if (enteredPin == _debugAccessPin) {
                    Navigator.of(dialogContext).pop(true);
                  } else {
                    attempts++;
                    if (attempts >= maxAttempts) {
                      Navigator.of(dialogContext).pop(false);
                      if (mounted) {
                        showErrorSnackBar(
                          this.context,
                          'Too many incorrect attempts',
                        );
                      }
                    } else {
                      HapticFeedback.heavyImpact();
                      setDialogState(() {
                        enteredPin = '';
                        showError = true;
                      });
                    }
                  }
                });
              }
            }
          }

          Widget buildPinDot(int index) {
            final isFilled = index < enteredPin.length;
            final isError = showError;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 14,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled
                    ? (isError ? AppTheme.errorRed : Colors.white)
                    : Colors.transparent,
                border: Border.all(
                  color: isError
                      ? AppTheme.errorRed
                      : (isFilled ? Colors.white : Colors.white.withAlpha(100)),
                  width: 2,
                ),
              ),
            );
          }

          Widget buildNumberKey(String number) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Center(
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onKeyPress(number),
                        customBorder: const CircleBorder(),
                        splashColor: Colors.white.withAlpha(30),
                        highlightColor: Colors.white.withAlpha(15),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withAlpha(10),
                            border: Border.all(
                              color: Colors.white.withAlpha(30),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              number,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w300,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          Widget buildActionKey({
            required IconData icon,
            required VoidCallback onTap,
            Color? iconColor,
          }) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Center(
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onTap,
                        customBorder: const CircleBorder(),
                        splashColor: Colors.white.withAlpha(30),
                        highlightColor: Colors.white.withAlpha(15),
                        child: Center(
                          child: Icon(
                            icon,
                            size: 28,
                            color: iconColor ?? Colors.white.withAlpha(180),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 300,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lock icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(10),
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.white.withAlpha(200),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  const Text(
                    'Enter PIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Admin access required',
                    style: TextStyle(
                      color: Colors.white.withAlpha(130),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // PIN dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _debugAccessPin.length,
                      (index) => buildPinDot(index),
                    ),
                  ),

                  // Error message
                  SizedBox(
                    height: 32,
                    child: Center(
                      child: showError
                          ? Text(
                              'Wrong PIN · ${maxAttempts - attempts} attempts left',
                              style: TextStyle(
                                color: AppTheme.errorRed,
                                fontSize: 13,
                              ),
                            )
                          : null,
                    ),
                  ),

                  // Number pad
                  Row(
                    children: [
                      buildNumberKey('1'),
                      buildNumberKey('2'),
                      buildNumberKey('3'),
                    ],
                  ),
                  Row(
                    children: [
                      buildNumberKey('4'),
                      buildNumberKey('5'),
                      buildNumberKey('6'),
                    ],
                  ),
                  Row(
                    children: [
                      buildNumberKey('7'),
                      buildNumberKey('8'),
                      buildNumberKey('9'),
                    ],
                  ),
                  Row(
                    children: [
                      // Cancel button
                      buildActionKey(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(dialogContext).pop(false),
                        iconColor: Colors.white.withAlpha(100),
                      ),
                      buildNumberKey('0'),
                      // Backspace button
                      buildActionKey(
                        icon: Icons.backspace_outlined,
                        onTap: () => onKeyPress('backspace'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return result ?? false;
  }

  /// Handle secret gesture unlock - show PIN then navigate to debug settings
  Future<void> _onSecretGestureUnlocked() async {
    HapticFeedback.heavyImpact();

    final verified = await _showDebugAccessPinDialog();
    if (!verified || !mounted) return;

    showSuccessSnackBar(context, '🔓 Debug mode unlocked!');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DebugSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsServiceAsync = ref.watch(settingsServiceProvider);

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: HelpTourController(
        topicId: 'settings_overview',
        stepKeys: const {},
        child: Scaffold(
          backgroundColor: context.background,
          appBar: AppBar(
            backgroundColor: context.background,
            centerTitle: true,
            title: Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: 'Help',
                onPressed: () => ref
                    .read(helpProvider.notifier)
                    .startTour('settings_overview'),
              ),
            ],
          ),
          body: Column(
            children: [
              // Search bar - same design as nodes screen
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: TextStyle(color: context.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Find a setting',
                      hintStyle: TextStyle(color: context.textTertiary),
                      prefixIcon: Icon(
                        Icons.search,
                        color: context.textTertiary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: context.textTertiary,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              // Content - search results or settings list
              Expanded(
                child: _searchQuery.isNotEmpty
                    ? Builder(
                        builder: (context) {
                          final allSettings = _getSearchableSettings(
                            context,
                            ref,
                          );
                          final filteredSettings = _filterSettings(
                            allSettings,
                            _searchQuery,
                          );
                          return _buildSearchResults(context, filteredSettings);
                        },
                      )
                    : settingsServiceAsync.when(
                        loading: () => const ScreenLoadingIndicator(),
                        error: (error, stack) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading settings: $error',
                                style: TextStyle(color: context.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () =>
                                    ref.invalidate(settingsServiceProvider),
                                style:
                                    ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 16,
                                      ),
                                    ).copyWith(
                                      backgroundColor: WidgetStateProperty.all(
                                        Colors.transparent,
                                      ),
                                    ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        context.accentColor,
                                        context.accentColor.withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minHeight: 48,
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text('Retry'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        data: (settingsService) {
                          // Watch accent color for dynamic updates (triggers rebuild when changed)
                          final accentColorAsync = ref.watch(
                            accentColorProvider,
                          );
                          final _ = accentColorAsync
                              .asData
                              ?.value; // Just to trigger rebuild

                          // Get current region for display
                          final regionAsync = ref.watch(deviceRegionProvider);
                          final regionSubtitle = regionAsync.when(
                            data: (region) {
                              if (region ==
                                  config_pbenum
                                      .Config_LoRaConfig_RegionCode
                                      .UNSET) {
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
                              _buildUpgradesSection(context),

                              const SizedBox(height: 16),

                              // Profile Section - right after Premium, before Connection
                              _SectionHeader(title: 'ACCOUNT'),
                              _ProfileTile(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AccountSubscriptionsScreen(),
                                  ),
                                ),
                              ),

                              // _PrivacySettingTile(),
                              // _FollowRequestsTile(),

                              // Social Notifications Section (only for signed-in users)
                              // const _SocialNotificationsSection(),
                              const SizedBox(height: 16),

                              // Connection Section
                              _SectionHeader(title: 'CONNECTION'),
                              _SettingsTile(
                                icon: Icons.bluetooth,
                                title: 'Auto-reconnect',
                                subtitle:
                                    'Automatically reconnect to last device',
                                trailing: ThemedSwitch(
                                  value: settingsService.autoReconnect,
                                  onChanged: (value) async {
                                    HapticFeedback.selectionClick();
                                    await settingsService.setAutoReconnect(
                                      value,
                                    );
                                    setState(() {});
                                  },
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Haptic Feedback Section
                              const _SectionHeader(title: 'HAPTIC FEEDBACK'),
                              _SettingsTile(
                                icon: Icons.vibration,
                                title: 'Haptic feedback',
                                subtitle: 'Vibration feedback for interactions',
                                trailing: ThemedSwitch(
                                  value: settingsService.hapticFeedbackEnabled,
                                  onChanged: (value) async {
                                    if (value) {
                                      ref.haptics.toggle();
                                    }
                                    await settingsService
                                        .setHapticFeedbackEnabled(value);
                                    ref
                                        .read(userProfileProvider.notifier)
                                        .updatePreferences(
                                          UserPreferences(
                                            hapticFeedbackEnabled: value,
                                          ),
                                        );
                                    setState(() {});
                                  },
                                ),
                              ),
                              if (settingsService.hapticFeedbackEnabled)
                                _SettingsTile(
                                  icon: Icons.tune,
                                  title: 'Intensity',
                                  subtitle: HapticIntensity.fromValue(
                                    settingsService.hapticIntensity,
                                  ).label,
                                  onTap: () => _showHapticIntensityPicker(
                                    context,
                                    ref,
                                    settingsService,
                                  ),
                                ),

                              const SizedBox(height: 16),

                              // Animations Section
                              const _SectionHeader(title: 'ANIMATIONS'),
                              _SettingsTile(
                                icon: Icons.animation,
                                title: 'List animations',
                                subtitle: 'Slide and bounce effects on lists',
                                trailing: ThemedSwitch(
                                  value: settingsService.animationsEnabled,
                                  onChanged: (value) async {
                                    HapticFeedback.selectionClick();
                                    await settingsService.setAnimationsEnabled(
                                      value,
                                    );
                                    ref
                                        .read(userProfileProvider.notifier)
                                        .updatePreferences(
                                          UserPreferences(
                                            animationsEnabled: value,
                                          ),
                                        );
                                    ref
                                        .read(settingsRefreshProvider.notifier)
                                        .refresh();
                                    setState(() {});
                                  },
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.view_in_ar,
                                title: '3D effects',
                                subtitle:
                                    'Perspective transforms and depth effects',
                                trailing: ThemedSwitch(
                                  value: settingsService.animations3DEnabled,
                                  onChanged: (value) async {
                                    HapticFeedback.selectionClick();
                                    await settingsService
                                        .setAnimations3DEnabled(value);
                                    ref
                                        .read(userProfileProvider.notifier)
                                        .updatePreferences(
                                          UserPreferences(
                                            animations3DEnabled: value,
                                          ),
                                        );
                                    ref
                                        .read(settingsRefreshProvider.notifier)
                                        .refresh();
                                    setState(() {});
                                  },
                                ),
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
                                    await settingsService
                                        .setNotificationsEnabled(value);
                                    ref
                                        .read(userProfileProvider.notifier)
                                        .updatePreferences(
                                          UserPreferences(
                                            notificationsEnabled: value,
                                          ),
                                        );
                                    setState(() {});
                                  },
                                ),
                              ),
                              if (settingsService.notificationsEnabled) ...[
                                _SettingsTile(
                                  icon: Icons.person_add_outlined,
                                  title: 'New nodes',
                                  subtitle:
                                      'Notify when new nodes join the mesh',
                                  trailing: ThemedSwitch(
                                    value: settingsService
                                        .newNodeNotificationsEnabled,
                                    onChanged: (value) async {
                                      HapticFeedback.selectionClick();
                                      await settingsService
                                          .setNewNodeNotificationsEnabled(
                                            value,
                                          );
                                      ref
                                          .read(userProfileProvider.notifier)
                                          .updatePreferences(
                                            UserPreferences(
                                              newNodeNotificationsEnabled:
                                                  value,
                                            ),
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
                                    value: settingsService
                                        .directMessageNotificationsEnabled,
                                    onChanged: (value) async {
                                      HapticFeedback.selectionClick();
                                      await settingsService
                                          .setDirectMessageNotificationsEnabled(
                                            value,
                                          );
                                      ref
                                          .read(userProfileProvider.notifier)
                                          .updatePreferences(
                                            UserPreferences(
                                              directMessageNotificationsEnabled:
                                                  value,
                                            ),
                                          );
                                      setState(() {});
                                    },
                                  ),
                                ),
                                _SettingsTile(
                                  icon: Icons.forum_outlined,
                                  title: 'Channel messages',
                                  subtitle: 'Notify for channel broadcasts',
                                  trailing: ThemedSwitch(
                                    value: settingsService
                                        .channelMessageNotificationsEnabled,
                                    onChanged: (value) async {
                                      HapticFeedback.selectionClick();
                                      await settingsService
                                          .setChannelMessageNotificationsEnabled(
                                            value,
                                          );
                                      ref
                                          .read(userProfileProvider.notifier)
                                          .updatePreferences(
                                            UserPreferences(
                                              channelMessageNotificationsEnabled:
                                                  value,
                                            ),
                                          );
                                      setState(() {});
                                    },
                                  ),
                                ),
                                _SettingsTile(
                                  icon: Icons.volume_up_outlined,
                                  title: 'Sound',
                                  subtitle: 'Play sound with notifications',
                                  trailing: ThemedSwitch(
                                    value: settingsService
                                        .notificationSoundEnabled,
                                    onChanged: (value) async {
                                      HapticFeedback.selectionClick();
                                      await settingsService
                                          .setNotificationSoundEnabled(value);
                                      ref
                                          .read(userProfileProvider.notifier)
                                          .updatePreferences(
                                            UserPreferences(
                                              notificationSoundEnabled: value,
                                            ),
                                          );
                                      setState(() {});
                                    },
                                  ),
                                ),
                                _SettingsTile(
                                  icon: Icons.vibration,
                                  title: 'Vibration',
                                  subtitle: 'Vibrate with notifications',
                                  trailing: ThemedSwitch(
                                    value: settingsService
                                        .notificationVibrationEnabled,
                                    onChanged: (value) async {
                                      HapticFeedback.selectionClick();
                                      await settingsService
                                          .setNotificationVibrationEnabled(
                                            value,
                                          );
                                      ref
                                          .read(userProfileProvider.notifier)
                                          .updatePreferences(
                                            UserPreferences(
                                              notificationVibrationEnabled:
                                                  value,
                                            ),
                                          );
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),

                              // Messaging Section
                              _SectionHeader(title: 'MESSAGING'),
                              _SettingsTile(
                                icon: Icons.bolt,
                                title: 'Quick responses',
                                subtitle:
                                    'Manage canned responses for fast messaging',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CannedResponsesScreen(),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.message,
                                title: 'Canned Messages Module',
                                subtitle: 'Device-side canned message settings',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CannedMessageModuleConfigScreen(),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Data Section
                              const _SectionHeader(title: 'DATA & STORAGE'),
                              _SettingsTile(
                                icon: Icons.history,
                                title: 'Message history',
                                subtitle:
                                    '${settingsService.messageHistoryLimit} messages stored',
                                onTap: () => _showHistoryLimitDialog(
                                  context,
                                  settingsService,
                                ),
                              ),
                              // Message Export
                              _SettingsTile(
                                icon: Icons.download,
                                title: 'Export Messages',
                                subtitle: 'Export messages to PDF or CSV',
                              ),
                              _SettingsTile(
                                icon: Icons.delete_sweep_outlined,
                                title: 'Clear message history',
                                subtitle: 'Delete all stored messages',
                                onTap: () =>
                                    _confirmClearMessages(context, ref),
                              ),
                              _SettingsTile(
                                icon: Icons.refresh,
                                iconColor: Colors.orange,
                                title: 'Reset local data',
                                titleColor: Colors.orange,
                                subtitle:
                                    'Clear messages and nodes, keep settings',
                                onTap: () =>
                                    _confirmResetLocalData(context, ref),
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

                              // Remote Admin Selector
                              _buildRemoteAdminSelector(context, ref),

                              // Device Section
                              _SectionHeader(title: 'DEVICE'),
                              _SettingsTile(
                                icon: Icons.sync,
                                title: 'Force Sync',
                                subtitle:
                                    'Re-sync all data from connected device',
                                onTap: () => _forceSync(context, ref),
                              ),
                              _SettingsTile(
                                icon:
                                    regionAsync.whenOrNull(
                                          data: (r) =>
                                              r ==
                                              config_pbenum
                                                  .Config_LoRaConfig_RegionCode
                                                  .UNSET,
                                        ) ==
                                        true
                                    ? Icons.warning_amber_rounded
                                    : Icons.language,
                                iconColor:
                                    regionAsync.whenOrNull(
                                          data: (r) =>
                                              r ==
                                              config_pbenum
                                                  .Config_LoRaConfig_RegionCode
                                                  .UNSET,
                                        ) ==
                                        true
                                    ? Colors.orange
                                    : null,
                                title: 'Region / Frequency',
                                subtitle: regionSubtitle,
                                subtitleColor:
                                    regionAsync.whenOrNull(
                                          data: (r) =>
                                              r ==
                                              config_pbenum
                                                  .Config_LoRaConfig_RegionCode
                                                  .UNSET,
                                        ) ==
                                        true
                                    ? Colors.orange
                                    : null,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegionSelectionScreen(
                                      isInitialSetup: false,
                                    ),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.settings,
                                title: 'Device Role & Settings',
                                subtitle: 'Configure device behavior and role',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DeviceConfigScreen(),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.radio,
                                title: 'Radio Configuration',
                                subtitle: 'LoRa settings, modem preset, power',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RadioConfigScreen(),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.gps_fixed,
                                title: 'Position & GPS',
                                subtitle:
                                    'GPS mode, broadcast intervals, fixed position',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const PositionConfigScreen(),
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
                                    builder: (_) =>
                                        const BluetoothConfigScreen(),
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
                                  MaterialPageRoute(
                                    builder: (_) => const PowerConfigScreen(),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.security,
                                title: 'Security',
                                subtitle: 'Access controls, managed mode',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const SecurityConfigScreen(),
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
                                    builder: (_) =>
                                        const DeviceManagementScreen(),
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
                                onTap: () =>
                                    Navigator.pushNamed(context, '/qr-import'),
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
                                  MaterialPageRoute(
                                    builder: (_) => const MqttConfigScreen(),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.radar,
                                title: 'Range Test',
                                subtitle: 'Test signal range with other nodes',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RangeTestScreen(),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.storage,
                                title: 'Store & Forward',
                                subtitle:
                                    'Store and relay messages for offline nodes',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const StoreForwardConfigScreen(),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.sensors,
                                title: 'Detection Sensor',
                                subtitle:
                                    'Configure GPIO-based motion/door sensors',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DetectionSensorConfigScreen(),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.notifications_active,
                                title: 'External Notification',
                                subtitle:
                                    'Configure buzzers, LEDs, and vibration alerts',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ExternalNotificationConfigScreen(),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.lightbulb_outline,
                                title: 'Ambient Lighting',
                                subtitle: 'Configure LED and RGB settings',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AmbientLightingConfigScreen(),
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
                                    builder: (_) =>
                                        const PaxCounterConfigScreen(),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.analytics_outlined,
                                title: 'Telemetry Intervals',
                                subtitle:
                                    'Configure telemetry update frequency',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const TelemetryConfigScreen(),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.usb_rounded,
                                title: 'Serial',
                                subtitle: 'Serial port configuration',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SerialConfigScreen(),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Telemetry Section
                              _SectionHeader(title: 'TELEMETRY LOGS'),
                              _SettingsTile(
                                icon: Icons.battery_charging_full,
                                title: 'Device Metrics',
                                subtitle:
                                    'Battery, voltage, utilization history',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DeviceMetricsLogScreen(),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.thermostat,
                                title: 'Environment Metrics',
                                subtitle:
                                    'Temperature, humidity, pressure logs',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const EnvironmentMetricsLogScreen(),
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
                                  MaterialPageRoute(
                                    builder: (_) => const PositionLogScreen(),
                                  ),
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
                                    builder: (_) =>
                                        const DetectionSensorLogScreen(),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.route,
                                title: 'Routes',
                                subtitle: 'Record and manage GPS routes',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RoutesScreen(),
                                  ),
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
                                  MaterialPageRoute(
                                    builder: (_) => const GpsStatusScreen(),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.system_update,
                                title: 'Firmware Update',
                                subtitle: 'Check for device firmware updates',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const FirmwareUpdateScreen(),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.ios_share,
                                title: 'Export Data',
                                subtitle: 'Export messages, telemetry, routes',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DataExportScreen(),
                                  ),
                                ),
                              ),
                              _SettingsTile(
                                icon: Icons.article_outlined,
                                title: 'App Log',
                                subtitle: 'View application debug logs',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AppLogScreen(),
                                  ),
                                ),
                              ),
                              // Glyph Matrix Test - only show on Nothing Phone 3
                              Consumer(
                                builder: (context, ref, child) {
                                  final glyphService = ref.watch(
                                    glyphServiceProvider,
                                  );
                                  // Only show on Nothing Phone 3
                                  if (!glyphService.deviceModel.contains(
                                    'Phone (3)',
                                  )) {
                                    return const SizedBox.shrink();
                                  }
                                  return _SettingsTile(
                                    icon: Icons.lightbulb,
                                    title: 'Glyph Matrix Test',
                                    subtitle: 'Nothing Phone 3 LED patterns',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const GlyphTestScreen(),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 16),

                              // About Section
                              _SectionHeader(title: 'ABOUT'),
                              // Secret gesture to unlock debug settings - 7 taps with PIN
                              Consumer(
                                builder: (context, ref, child) {
                                  final appVersion = ref.watch(
                                    appVersionProvider,
                                  );
                                  final versionString = appVersion.when(
                                    data: (v) =>
                                        'Meshtastic companion app • Version $v',
                                    loading: () => 'Meshtastic companion app',
                                    error: (_, _) => 'Meshtastic companion app',
                                  );
                                  return SecretGestureDetector(
                                    pattern: SecretGesturePattern.sevenTaps,
                                    showFeedback: false,
                                    enableHaptics: true,
                                    onSecretUnlocked: _onSecretGestureUnlocked,
                                    child: _SettingsTile(
                                      icon: Icons.info,
                                      title: 'Socialmesh',
                                      subtitle: versionString,
                                    ),
                                  );
                                },
                              ),
                              _SettingsTile(
                                icon: Icons.help_outline,
                                title: 'Help & Support',
                                subtitle:
                                    'FAQ, troubleshooting, and contact info',
                                onTap: () =>
                                    LegalDocumentSheet.showSupport(context),
                              ),
                              _SettingsTile(
                                icon: Icons.description_outlined,
                                title: 'Terms of Service',
                                onTap: () =>
                                    LegalDocumentSheet.showTerms(context),
                              ),
                              _SettingsTile(
                                icon: Icons.privacy_tip_outlined,
                                title: 'Privacy Policy',
                                onTap: () =>
                                    LegalDocumentSheet.showPrivacy(context),
                              ),
                              _SettingsTile(
                                icon: Icons.source_outlined,
                                title: 'Open Source Licenses',
                                subtitle:
                                    'Third-party libraries and attributions',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const _OpenSourceLicensesScreen(),
                                  ),
                                ),
                              ),

                              // Debug Section (Admin only)
                              if (AdminConfig.isEnabled) ...[
                                const SizedBox(height: 16),
                                _SectionHeader(title: 'DEBUG'),
                                _SettingsTile(
                                  icon: Icons.bug_report,
                                  iconColor: AppTheme.warningYellow,
                                  title: 'Debug Settings',
                                  subtitle:
                                      'Mesh node playground, test notifications',
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const DebugSettingsScreen(),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),

                              // Meshtastic Powered footer
                              _MeshtasticPoweredFooter(),

                              const SizedBox(height: 32),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHapticIntensityPicker(
    BuildContext context,
    WidgetRef ref,
    SettingsService settingsService,
  ) {
    final currentIntensity = HapticIntensity.fromValue(
      settingsService.hapticIntensity,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Haptic Intensity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ),
            ...HapticIntensity.values.map((intensity) {
              final isSelected = intensity == currentIntensity;
              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? context.accentColor
                      : context.textTertiary,
                ),
                title: Text(
                  intensity.label,
                  style: TextStyle(
                    color: isSelected
                        ? context.textPrimary
                        : context.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  _hapticIntensityDescription(intensity),
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
                onTap: () async {
                  await settingsService.setHapticIntensity(intensity.value);
                  ref
                      .read(userProfileProvider.notifier)
                      .updatePreferences(
                        UserPreferences(hapticIntensity: intensity.value),
                      );
                  ref.haptics.toggle();
                  setState(() {});
                  if (context.mounted) Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _hapticIntensityDescription(HapticIntensity intensity) {
    switch (intensity) {
      case HapticIntensity.light:
        return 'Subtle feedback for a gentle touch';
      case HapticIntensity.medium:
        return 'Balanced feedback for most interactions';
      case HapticIntensity.heavy:
        return 'Strong feedback for clear confirmation';
    }
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
          color: isSelected ? context.accentColor : context.textTertiary,
        ),
        title: Text(
          '$limit messages',
          style: TextStyle(
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
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
        backgroundColor: context.card,
        title: Text(
          'Clear Messages',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Text(
          'This will delete all stored messages. This action cannot be undone.',
          style: TextStyle(color: context.textSecondary),
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
      showSuccessSnackBar(context, 'Messages cleared');
    }
  }

  Future<void> _confirmResetLocalData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: Text(
          'Reset Local Data',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Text(
          'This will clear all messages and node data, forcing a fresh sync from your device on next connection.\n\n'
          'Your settings, theme, and preferences will be kept.\n\n'
          'Use this if nodes show incorrect status or messages appear wrong.',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Clear messages
      ref.read(messagesProvider.notifier).clearMessages();

      // Clear nodes
      ref.read(nodesProvider.notifier).clearNodes();

      // Clear channels (will be re-synced from device)
      ref.read(channelsProvider.notifier).clearChannels();

      // Clear message storage
      final messageStorage = await ref.read(messageStorageProvider.future);
      await messageStorage.clearMessages();

      // Clear node storage
      final nodeStorage = await ref.read(nodeStorageProvider.future);
      await nodeStorage.clearNodes();

      if (context.mounted) {
        showSuccessSnackBar(
          context,
          'Local data reset. Reconnect to sync fresh data.',
        );
      }
    }
  }

  Future<void> _forceSync(BuildContext context, WidgetRef ref) async {
    final protocol = ref.read(protocolServiceProvider);
    final transport = ref.read(transportProvider);

    if (transport.state != DeviceConnectionState.connected) {
      showErrorSnackBar(context, 'Not connected to a device');
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        content: Row(
          children: [
            LoadingIndicator(size: 40),
            const SizedBox(width: 20),
            Text(
              'Syncing from device...',
              style: TextStyle(color: context.textPrimary),
            ),
          ],
        ),
      ),
    );

    try {
      // Clear local state first
      ref.read(messagesProvider.notifier).clearMessages();
      ref.read(nodesProvider.notifier).clearNodes();
      ref.read(channelsProvider.notifier).clearChannels();

      // Get device info for hardware model inference
      final connectedDevice = ref.read(connectedDeviceProvider);
      if (connectedDevice != null) {
        protocol.setDeviceName(connectedDevice.name);
        protocol.setBleModelNumber(transport.bleModelNumber);
        protocol.setBleManufacturerName(transport.bleManufacturerName);
      }

      // Restart protocol to re-request config from device
      await protocol.start();

      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        showSuccessSnackBar(context, 'Sync complete');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        showErrorSnackBar(context, 'Sync failed: $e');
      }
    }
  }

  Future<void> _confirmClearData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: Text(
          'Clear All Data',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Text(
          'This will delete ALL app data: messages, nodes, channels, settings, keys, signals, bookmarks, automations, widgets, and saved preferences. This action cannot be undone.',
          style: TextStyle(color: context.textSecondary),
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
      try {
        // Secure storage (channel keys, device info)
        final secureStorage = ref.read(secureStorageProvider);
        await secureStorage.clearAll();

        // Settings service
        final settingsServiceAsync = ref.read(settingsServiceProvider);
        settingsServiceAsync.whenData((settingsService) {
          settingsService.clearAll();
        });

        // Messages, nodes, channels
        final messagesNotifier = ref.read(messagesProvider.notifier);
        final nodesNotifier = ref.read(nodesProvider.notifier);
        final channelsNotifier = ref.read(channelsProvider.notifier);
        messagesNotifier.clearMessages();
        nodesNotifier.clearNodes();
        channelsNotifier.clearChannels();

        // Hidden signals (local only)
        final hiddenSignalsNotifier = ref.read(hiddenSignalsProvider.notifier);
        await hiddenSignalsNotifier.clearAll();

        // Automations - delete all one by one
        try {
          final automationsNotifier = ref.read(automationsProvider.notifier);
          final automations = ref.read(automationsProvider).value ?? [];
          for (final automation in automations) {
            await automationsNotifier.deleteAutomation(automation.id);
          }
        } catch (e) {
          AppLogging.app('Failed to clear automations: $e');
        }

        // SharedPreferences (all other cached data including hidden signals, bookmarks)
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Signal database - close and delete
        try {
          final signalService = ref.read(signalServiceProvider);
          await signalService.close();
          // Database will be recreated on next use
        } catch (e) {
          AppLogging.app('Failed to close signal database: $e');
        }

        if (context.mounted) {
          showSuccessSnackBar(context, 'All data cleared successfully');
        }
      } catch (e) {
        AppLogging.app('Error clearing data: $e');
        if (context.mounted) {
          showErrorSnackBar(context, 'Failed to clear some data: $e');
        }
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
          Text(
            'Device Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.textTertiary,

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
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
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
                Icon(icon, color: iconColor ?? context.textSecondary),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: titleColor ?? context.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: subtitleColor ?? context.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (onTap != null)
                  Icon(Icons.chevron_right, color: context.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium feature tile with owned/locked badge
class _PremiumFeatureTile extends ConsumerWidget {
  final IconData icon;
  final String title;
  final PremiumFeature feature;
  final VoidCallback? onTap;

  const _PremiumFeatureTile({
    required this.icon,
    required this.title,
    required this.feature,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchaseState = ref.watch(purchaseStateProvider);
    final hasFeature = purchaseState.hasFeature(feature);
    final accentColor = context.accentColor;
    final purchase = OneTimePurchases.getByFeature(feature);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: hasFeature
            ? Border.all(color: accentColor.withValues(alpha: 0.3), width: 1)
            : null,
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
                Icon(
                  icon,
                  color: hasFeature ? accentColor : context.textTertiary,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: hasFeature
                          ? context.textPrimary
                          : context.textSecondary,
                    ),
                  ),
                ),
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hasFeature
                        ? accentColor.withValues(alpha: 0.2)
                        : context.textTertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasFeature) ...[
                        Text(
                          'OWNED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ] else ...[
                        Icon(Icons.lock, size: 12, color: context.textTertiary),
                        SizedBox(width: 4),
                        Text(
                          purchase != null
                              ? '\$${purchase.price.toStringAsFixed(2)}'
                              : 'LOCKED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: hasFeature ? accentColor : context.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile tile showing user profile info
class _ProfileTile extends ConsumerWidget {
  final VoidCallback? onTap;

  const _ProfileTile({this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final authState = ref.watch(authStateProvider);
    final isSignedIn = authState.value != null;
    final accentColor = context.accentColor;

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return _SettingsTile(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'Set up your profile',
            onTap: onTap,
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.border.withValues(alpha: 0.3)),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Avatar
                    UserAvatar(
                      imageUrl: profile.avatarUrl,
                      initials: profile.initials,
                      size: 48,
                      borderWidth: 2,
                      borderColor: accentColor.withValues(alpha: 0.5),
                      foregroundColor: accentColor,
                      backgroundColor: context.surface,
                    ),
                    SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  profile.displayName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (profile.callsign != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    profile.callsign!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                isSignedIn ? Icons.cloud_done : Icons.cloud_off,
                                size: 12,
                                color: isSignedIn
                                    ? AccentColors.green
                                    : context.textTertiary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                isSignedIn ? 'Synced' : 'Local only',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textSecondary,
                                ),
                              ),
                              if (profile.bio != null &&
                                  profile.bio!.isNotEmpty) ...[
                                Text(
                                  ' • ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.textTertiary,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    profile.bio!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.textTertiary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: context.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => _SettingsTile(
        icon: Icons.person_outline,
        title: 'Profile',
        subtitle: 'Loading...',
        onTap: onTap,
      ),
      error: (error, stackTrace) => _SettingsTile(
        icon: Icons.person_outline,
        title: 'Profile',
        subtitle: 'Set up your profile',
        onTap: onTap,
      ),
    );
  }
}

/// Privacy setting tile for controlling private/public account
// class _PrivacySettingTile extends ConsumerWidget {
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final currentUser = ref.watch(currentUserProvider);
//     if (currentUser == null) return const SizedBox.shrink();

//     final profileAsync = ref.watch(publicProfileProvider(currentUser.uid));

//     return profileAsync.when(
//       data: (profile) {
//         if (profile == null) return const SizedBox.shrink();

//         return _SettingsTile(
//           icon: profile.isPrivate ? Icons.lock : Icons.lock_open,
//           title: 'Private account',
//           subtitle: profile.isPrivate
//               ? 'Only approved followers can see your posts'
//               : 'Anyone can follow you and see your posts',
//           trailing: ThemedSwitch(
//             value: profile.isPrivate,
//             onChanged: (value) async {
//               await setAccountPrivacy(ref, value);
//               if (context.mounted) {
//                 showSuccessSnackBar(
//                   context,
//                   value ? 'Account is now private' : 'Account is now public',
//                 );
//               }
//             },
//           ),
//         );
//       },
//       loading: () => _SettingsTile(
//         icon: Icons.lock,
//         title: 'Private account',
//         subtitle: 'Loading...',
//         trailing: const SizedBox(
//           width: 24,
//           height: 24,
//           child: CircularProgressIndicator(strokeWidth: 2),
//         ),
//       ),
//       error: (_, _) => const SizedBox.shrink(),
//     );
//   }
// }

/// Follow requests tile with badge showing pending count
// class _FollowRequestsTile extends ConsumerWidget {
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final currentUser = ref.watch(currentUserProvider);
//     if (currentUser == null) return const SizedBox.shrink();

//     final countAsync = ref.watch(pendingFollowRequestsCountProvider);

//     return countAsync.when(
//       data: (count) {
//         return _SettingsTile(
//           icon: Icons.person_add,
//           title: 'Follow requests',
//           subtitle: count == 0
//               ? 'No pending requests'
//               : '$count pending request${count == 1 ? '' : 's'}',
//           trailing: count > 0
//               ? Badge(
//                   label: Text(count > 99 ? '99+' : count.toString()),
//                   child: Icon(Icons.chevron_right, color: context.textTertiary),
//                 )
//               : Icon(Icons.chevron_right, color: context.textTertiary),
//           onTap: () => Navigator.push(
//             context,
//             MaterialPageRoute(builder: (_) => const FollowRequestsScreen()),
//           ),
//         );
//       },
//       loading: () => _SettingsTile(
//         icon: Icons.person_add,
//         title: 'Follow requests',
//         subtitle: 'Loading...',
//       ),
//       error: (_, _) => _SettingsTile(
//         icon: Icons.person_add,
//         title: 'Follow requests',
//         subtitle: 'Tap to view',
//         onTap: () => Navigator.push(
//           context,
//           MaterialPageRoute(builder: (_) => const FollowRequestsScreen()),
//         ),
//       ),
//     );
//   }
// }

/// Meshtastic Powered footer with link to meshtastic.org
class _MeshtasticPoweredFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: InkWell(
          onTap: () => _openMeshtasticWebsite(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Opacity(
              opacity: 0.7,
              child: Image.asset(
                'assets/meshtastic_powered_landscape.png',
                width: 180,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openMeshtasticWebsite(BuildContext context) {
    HapticFeedback.lightImpact();
    MeshtasticWebViewScreen.show(context);
  }
}

/// Tappable Meshtastic Powered logo that opens meshtastic.org
class _TappableMeshtasticLogo extends StatelessWidget {
  final double width;

  const _TappableMeshtasticLogo({this.width = 140});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        MeshtasticWebViewScreen.show(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Image.asset(
          'assets/meshtastic_powered_landscape.png',
          width: width,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// In-app webview for meshtastic.org
class MeshtasticWebViewScreen extends StatefulWidget {
  const MeshtasticWebViewScreen._();

  /// Show the Meshtastic website in an in-app browser
  static void show(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MeshtasticWebViewScreen._()),
    );
  }

  @override
  State<MeshtasticWebViewScreen> createState() =>
      _MeshtasticWebViewScreenState();
}

class _MeshtasticWebViewScreenState extends State<MeshtasticWebViewScreen> {
  double _progress = 0;
  String _title = 'Meshtastic';
  InAppWebViewController? _webViewController;
  bool _canGoBack = false;

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          _title,
          style: TextStyle(fontSize: 18),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_canGoBack)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _webViewController?.goBack(),
              tooltip: 'Go back',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webViewController?.reload(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          if (_progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: context.card,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 2,
            ),
          // WebView
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('https://meshtastic.org'),
              ),
              initialSettings: InAppWebViewSettings(
                transparentBackground: true,
                javaScriptEnabled: true,
                useShouldOverrideUrlLoading: false,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                iframeAllowFullscreen: true,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadStart: (controller, url) {
                if (mounted) setState(() => _progress = 0);
              },
              onProgressChanged: (controller, progress) {
                if (mounted) setState(() => _progress = progress / 100);
              },
              onLoadStop: (controller, url) async {
                if (!mounted) return;
                setState(() => _progress = 1.0);
                final canGoBack = await controller.canGoBack();
                if (mounted) setState(() => _canGoBack = canGoBack);
              },
              onTitleChanged: (controller, title) {
                if (mounted && title != null && title.isNotEmpty) {
                  setState(() => _title = title);
                }
              },
              onReceivedError: (controller, request, error) {
                AppLogging.settings('WebView error: ${error.description}');
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom themed Open Source Licenses screen
class _OpenSourceLicensesScreen extends ConsumerWidget {
  const _OpenSourceLicensesScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final appVersion = ref.watch(appVersionProvider);
    final versionString = appVersion.when(
      data: (v) => v,
      loading: () => '',
      error: (_, _) => '',
    );

    return Theme(
      // Apply dark theme to the license page
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: context.background,
        appBarTheme: AppBarTheme(
          backgroundColor: context.background,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardColor: context.card,
        listTileTheme: ListTileThemeData(
          textColor: Colors.white,
          iconColor: accentColor,
        ),
      ),
      child: LicensePage(
        applicationName: 'Socialmesh',
        applicationVersion: versionString,
        applicationIcon: const _TappableMeshtasticLogo(width: 140),
        applicationLegalese:
            '© 2024 Socialmesh\n\nThis app uses open source software. '
            'See below for the complete list of third-party licenses.',
      ),
    );
  }
}

/// Social notifications settings section (for signed-in users only)
class _SocialNotificationsSection extends ConsumerStatefulWidget {
  const _SocialNotificationsSection();

  @override
  ConsumerState<_SocialNotificationsSection> createState() =>
      _SocialNotificationsSectionState();
}

class _SocialNotificationsSectionState
    extends ConsumerState<_SocialNotificationsSection> {
  bool _isLoading = true;
  bool _followsEnabled = true;
  bool _likesEnabled = true;
  bool _commentsEnabled = true;
  bool _signalsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await PushNotificationService()
          .getNotificationSettings();
      if (mounted) {
        setState(() {
          _followsEnabled = settings['follows'] ?? true;
          _likesEnabled = settings['likes'] ?? true;
          _commentsEnabled = settings['comments'] ?? true;
          _signalsEnabled = settings['signals'] ?? true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateSetting(String type, bool value) async {
    HapticFeedback.selectionClick();

    setState(() {
      switch (type) {
        case 'follows':
          _followsEnabled = value;
          break;
        case 'likes':
          _likesEnabled = value;
          break;
        case 'comments':
          _commentsEnabled = value;
          break;
        case 'signals':
          _signalsEnabled = value;
          break;
      }
    });

    await PushNotificationService().updateNotificationSettings(
      followNotifications: type == 'follows' ? value : null,
      likeNotifications: type == 'likes' ? value : null,
      commentNotifications: type == 'comments' ? value : null,
      signalNotifications: type == 'signals' ? value : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    // Only show for signed-in users
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const _SectionHeader(title: 'SOCIAL NOTIFICATIONS'),
          _SettingsTile(
            icon: Icons.notifications_active_outlined,
            title: 'Loading...',
            subtitle: 'Fetching notification preferences',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const _SectionHeader(title: 'SOCIAL NOTIFICATIONS'),
        _SettingsTile(
          icon: Icons.person_add_outlined,
          title: 'New followers',
          subtitle: 'When someone follows you or sends a request',
          trailing: ThemedSwitch(
            value: _followsEnabled,
            onChanged: (value) => _updateSetting('follows', value),
          ),
        ),
        _SettingsTile(
          icon: Icons.favorite_outline,
          title: 'Likes',
          subtitle: 'When someone likes your posts',
          trailing: ThemedSwitch(
            value: _likesEnabled,
            onChanged: (value) => _updateSetting('likes', value),
          ),
        ),
        _SettingsTile(
          icon: Icons.chat_bubble_outline,
          title: 'Comments & mentions',
          subtitle: 'When someone comments or @mentions you',
          trailing: ThemedSwitch(
            value: _commentsEnabled,
            onChanged: (value) => _updateSetting('comments', value),
          ),
        ),
        _SettingsTile(
          icon: Icons.wifi_tethering_outlined,
          title: 'Signals',
          subtitle: 'Notify when someone posts a signal',
          trailing: ThemedSwitch(
            value: _signalsEnabled,
            onChanged: (value) => _updateSetting('signals', value),
          ),
        ),
      ],
    );
  }
}

/// Model for searchable settings item
class _SearchableSettingItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<String> keywords;
  final String section;
  final VoidCallback? onTap;
  final bool hasSwitch;

  const _SearchableSettingItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.keywords = const [],
    required this.section,
    this.onTap,
    this.hasSwitch = false,
  });
}
