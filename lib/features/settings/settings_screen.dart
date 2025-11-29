import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../services/storage/storage_service.dart';
import '../../core/theme.dart';
import '../device/region_selection_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
        data: (settingsService) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // Connection Section
            _SectionHeader(title: 'CONNECTION'),
            _SettingsTile(
              icon: Icons.bluetooth,
              title: 'Auto-reconnect',
              subtitle: 'Automatically reconnect to last device',
              trailing: Switch(
                value: settingsService.autoReconnect,
                activeTrackColor: AppTheme.primaryGreen,
                inactiveTrackColor: AppTheme.darkBorder,
                onChanged: (value) {
                  settingsService.setAutoReconnect(value);
                },
              ),
            ),

            const SizedBox(height: 16),

            // Notifications Section
            _SectionHeader(title: 'NOTIFICATIONS'),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              title: 'Push notifications',
              subtitle: 'Show notifications for new messages',
              trailing: Switch(
                value: settingsService.notificationsEnabled,
                activeTrackColor: AppTheme.primaryGreen,
                inactiveTrackColor: AppTheme.darkBorder,
                onChanged: (value) {
                  settingsService.setNotificationsEnabled(value);
                },
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
              subtitle: 'Configure device radio frequency',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const RegionSelectionScreen(isInitialSetup: false),
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

            // About Section
            _SectionHeader(title: 'ABOUT'),
            _SettingsTile(
              icon: Icons.info,
              title: 'Protofluff',
              subtitle: 'Meshtastic companion app • Version 1.0.0',
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
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
              _InfoRow(
                label: 'Device Name',
                value: connectedDevice?.name ?? 'Not connected',
              ),
              _InfoRow(
                label: 'Connection',
                value: connectedDevice?.type.name.toUpperCase() ?? 'None',
              ),
              _InfoRow(
                label: 'Node Number',
                value: myNodeNum?.toString() ?? 'Unknown',
              ),
              _InfoRow(
                label: 'Long Name',
                value: myNode?.longName ?? 'Unknown',
              ),
              _InfoRow(
                label: 'Short Name',
                value: myNode?.shortName ?? 'Unknown',
              ),
              _InfoRow(
                label: 'Hardware',
                value: myNode?.hardwareModel ?? 'Unknown',
              ),
              _InfoRow(
                label: 'Firmware',
                value: myNode?.firmwareVersion ?? 'Unknown',
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
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? AppTheme.textSecondary),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: titleColor ?? Colors.white,
            fontFamily: 'Inter',
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textTertiary,
            fontFamily: 'Inter',
          ),
        ),
        trailing:
            trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right, color: AppTheme.textTertiary)
                : null),
        onTap: onTap,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textTertiary,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
