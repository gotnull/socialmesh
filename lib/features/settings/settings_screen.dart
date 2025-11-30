import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../models/subscription_models.dart';
import '../../services/storage/storage_service.dart';
import '../../services/notifications/notification_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/info_table.dart';
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

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Widget _buildSubscriptionSection(BuildContext context, WidgetRef ref) {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
            fontFamily: 'Inter',
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Subscription Section
              _buildSubscriptionSection(context, ref),

              const SizedBox(height: 16),

              // Connection Section
              _SectionHeader(title: 'CONNECTION'),
              _SettingsTile(
                icon: Icons.bluetooth,
                title: 'Auto-reconnect',
                subtitle: 'Automatically reconnect to last device',
                trailing: Switch.adaptive(
                  value: settingsService.autoReconnect,
                  activeTrackColor: AppTheme.primaryGreen,
                  inactiveTrackColor: Colors.grey.shade600,
                  thumbColor: WidgetStateProperty.all(Colors.white),
                  onChanged: (value) async {
                    await settingsService.setAutoReconnect(value);
                    ref.read(settingsRefreshProvider.notifier).state++;
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
                trailing: Switch.adaptive(
                  value: settingsService.notificationsEnabled,
                  activeTrackColor: AppTheme.primaryGreen,
                  inactiveTrackColor: Colors.grey.shade600,
                  thumbColor: WidgetStateProperty.all(Colors.white),
                  onChanged: (value) async {
                    await settingsService.setNotificationsEnabled(value);
                    ref.read(settingsRefreshProvider.notifier).state++;
                  },
                ),
              ),
              if (settingsService.notificationsEnabled) ...[
                _SettingsTile(
                  icon: Icons.person_add_outlined,
                  title: 'New nodes',
                  subtitle: 'Notify when new nodes join the mesh',
                  trailing: Switch.adaptive(
                    value: settingsService.newNodeNotificationsEnabled,
                    activeTrackColor: AppTheme.primaryGreen,
                    inactiveTrackColor: Colors.grey.shade600,
                    thumbColor: WidgetStateProperty.all(Colors.white),
                    onChanged: (value) async {
                      await settingsService.setNewNodeNotificationsEnabled(
                        value,
                      );
                      ref.read(settingsRefreshProvider.notifier).state++;
                    },
                  ),
                ),
                _SettingsTile(
                  icon: Icons.chat_bubble_outline,
                  title: 'Direct messages',
                  subtitle: 'Notify for private messages',
                  trailing: Switch.adaptive(
                    value: settingsService.directMessageNotificationsEnabled,
                    activeTrackColor: AppTheme.primaryGreen,
                    inactiveTrackColor: Colors.grey.shade600,
                    thumbColor: WidgetStateProperty.all(Colors.white),
                    onChanged: (value) async {
                      await settingsService
                          .setDirectMessageNotificationsEnabled(value);
                      ref.read(settingsRefreshProvider.notifier).state++;
                    },
                  ),
                ),
                _SettingsTile(
                  icon: Icons.forum_outlined,
                  title: 'Channel messages',
                  subtitle: 'Notify for channel broadcasts',
                  trailing: Switch.adaptive(
                    value: settingsService.channelMessageNotificationsEnabled,
                    activeTrackColor: AppTheme.primaryGreen,
                    inactiveTrackColor: Colors.grey.shade600,
                    thumbColor: WidgetStateProperty.all(Colors.white),
                    onChanged: (value) async {
                      await settingsService
                          .setChannelMessageNotificationsEnabled(value);
                      ref.read(settingsRefreshProvider.notifier).state++;
                    },
                  ),
                ),
                _SettingsTile(
                  icon: Icons.volume_up_outlined,
                  title: 'Sound',
                  subtitle: 'Play sound with notifications',
                  trailing: Switch.adaptive(
                    value: settingsService.notificationSoundEnabled,
                    activeTrackColor: AppTheme.primaryGreen,
                    inactiveTrackColor: Colors.grey.shade600,
                    thumbColor: WidgetStateProperty.all(Colors.white),
                    onChanged: (value) async {
                      await settingsService.setNotificationSoundEnabled(value);
                      ref.read(settingsRefreshProvider.notifier).state++;
                    },
                  ),
                ),
                _SettingsTile(
                  icon: Icons.vibration,
                  title: 'Vibration',
                  subtitle: 'Vibrate with notifications',
                  trailing: Switch.adaptive(
                    value: settingsService.notificationVibrationEnabled,
                    activeTrackColor: AppTheme.primaryGreen,
                    inactiveTrackColor: Colors.grey.shade600,
                    thumbColor: WidgetStateProperty.all(Colors.white),
                    onChanged: (value) async {
                      await settingsService.setNotificationVibrationEnabled(
                        value,
                      );
                      ref.read(settingsRefreshProvider.notifier).state++;
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
                icon: Icons.music_note,
                title: 'Ringtone',
                subtitle: 'Customize notification sound (RTTTL)',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RingtoneScreen()),
                ),
              ),

              const SizedBox(height: 16),

              // About Section
              _SectionHeader(title: 'ABOUT'),
              _SettingsTile(
                icon: Icons.info,
                title: 'Protofluff',
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
        senderName: 'Test User',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent - check notification center'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showHistoryLimitDialog(
    BuildContext context,
    SettingsService settingsService,
  ) {
    final limits = [50, 100, 200, 500, 1000];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Message History Limit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            Container(
              height: 1,
              color: AppTheme.darkBorder.withValues(alpha: 0.3),
            ),
            for (final limit in limits)
              ListTile(
                leading: Icon(
                  settingsService.messageHistoryLimit == limit
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: settingsService.messageHistoryLimit == limit
                      ? AppTheme.primaryGreen
                      : AppTheme.textTertiary,
                ),
                title: Text(
                  '$limit messages',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                ),
                onTap: () {
                  settingsService.setMessageHistoryLimit(limit);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Messages cleared')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('All data cleared')));
      }
    }
  }

  void _showDeviceInfo(BuildContext context, WidgetRef ref) {
    final connectedDevice = ref.read(connectedDeviceProvider);
    final myNodeNum = ref.read(myNodeNumProvider);
    final nodes = ref.read(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                  fontFamily: 'Inter',
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
        ),
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
          fontFamily: 'Inter',
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
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textTertiary,
                          fontFamily: 'Inter',
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

  const _PremiumSettingsTile({
    required this.feature,
    required this.icon,
    required this.title,
    required this.subtitle,
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

    final onTap = hasFeature
        ? null
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
          onTap: onTap,
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
                              fontFamily: 'Inter',
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
                          fontFamily: 'Inter',
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
