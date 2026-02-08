// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/glass_scaffold.dart';

/// Screen for device management actions like reboot, shutdown, factory reset
class DeviceManagementScreen extends ConsumerStatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  ConsumerState<DeviceManagementScreen> createState() =>
      _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends ConsumerState<DeviceManagementScreen>
    with LifecycleSafeMixin {
  bool _isProcessing = false;

  Future<void> _executeAction(
    String actionName,
    Future<void> Function() action, {
    bool requiresConfirmation = true,
    String? warningMessage,
    bool causesDisconnect = false,
  }) async {
    AppLogging.connection(
      '🔧 DeviceManagement: $actionName started'
      '${causesDisconnect ? " (causes disconnect)" : ""}',
    );

    if (!mounted) return;

    if (requiresConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Theme.of(dialogContext).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(dialogContext).colorScheme.outline,
            ),
          ),
          title: Row(
            children: [
              Icon(
                causesDisconnect
                    ? Icons.warning_amber_rounded
                    : Icons.info_outline,
                color: causesDisconnect
                    ? AppTheme.warningYellow
                    : Theme.of(dialogContext).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  actionName,
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            warningMessage ??
                'Are you sure you want to $actionName? This action cannot be undone.',
            style: TextStyle(
              color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: causesDisconnect
                    ? AppTheme.warningYellow
                    : Theme.of(dialogContext).colorScheme.primary,
                foregroundColor: causesDisconnect ? Colors.black : Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        AppLogging.connection(
          '🔧 DeviceManagement: $actionName cancelled by user',
        );
        return;
      }
    }

    if (!mounted) return;

    safeSetState(() => _isProcessing = true);

    try {
      AppLogging.connection('🔧 DeviceManagement: Executing $actionName...');
      await action();

      if (mounted) {
        final message = causesDisconnect
            ? '$actionName - device will disconnect'
            : '$actionName command sent';
        showSuccessSnackBar(context, message);

        // Pop the screen after triggering actions that cause disconnect
        if (causesDisconnect) {
          AppLogging.connection(
            '🔧 DeviceManagement: $actionName complete — popping screen, '
            'expect disconnect shortly',
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            safeNavigatorPop();
          });
        }
      }
    } catch (e) {
      AppLogging.connection('🔧 DeviceManagement: $actionName FAILED: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Failed: $e');
      }
    } finally {
      safeSetState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final protocol = ref.watch(protocolServiceProvider);
    final isConnected = protocol.isConnected;

    return GlassScaffold(
      title: 'Device Management',
      slivers: [
        if (_isProcessing)
          const SliverFillRemaining(child: ScreenLoadingIndicator())
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                if (!isConnected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Device not connected. Connect to a device to manage it.',
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                _SectionHeader(title: 'POWER'),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.refresh,
                  iconColor: theme.colorScheme.primary,
                  title: 'Reboot Device',
                  subtitle: 'Restart the device',
                  enabled: isConnected,
                  onTap: () => _executeAction(
                    'Reboot Device',
                    () async {
                      AppLogging.connection(
                        '🔧 DeviceManagement: Sending reboot command '
                        '(delay=2s) — device will restart and BLE will drop',
                      );
                      await protocol.reboot(delaySeconds: 2);
                      AppLogging.connection(
                        '🔧 DeviceManagement: Reboot command sent — '
                        'expecting disconnect in ~2s',
                      );
                    },
                    warningMessage:
                        'The device will reboot in 2 seconds. You will be briefly disconnected while the device restarts.',
                    causesDisconnect: true,
                  ),
                ),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.power_settings_new,
                  iconColor: theme.colorScheme.secondary,
                  title: 'Shutdown Device',
                  subtitle: 'Turn off the device',
                  enabled: isConnected,
                  onTap: () => _executeAction(
                    'Shutdown Device',
                    () async {
                      AppLogging.connection(
                        '🔧 DeviceManagement: Sending shutdown command '
                        '(delay=2s) — device will power off and BLE will drop',
                      );
                      await protocol.shutdown(delaySeconds: 2);
                      AppLogging.connection(
                        '🔧 DeviceManagement: Shutdown command sent — '
                        'expecting disconnect in ~2s',
                      );
                    },
                    warningMessage:
                        'The device will shut down in 2 seconds. You will need to manually power it back on.',
                    causesDisconnect: true,
                  ),
                ),
                const SizedBox(height: 24),
                _SectionHeader(title: 'TIME'),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.access_time,
                  iconColor: theme.colorScheme.tertiary,
                  title: 'Sync Time',
                  subtitle: 'Set device time to current time',
                  enabled: isConnected,
                  onTap: () => _executeAction(
                    'Sync Time',
                    () => protocol.syncTime(),
                    requiresConfirmation: false,
                  ),
                ),
                const SizedBox(height: 24),
                _SectionHeader(title: 'RESET'),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.cleaning_services,
                  iconColor: Colors.orange,
                  title: 'Reset Node Database',
                  subtitle: 'Clear all known nodes from device and app',
                  enabled: isConnected,
                  onTap: () => _executeAction(
                    'Reset Node Database',
                    () async {
                      final nodesNotifier = ref.read(nodesProvider.notifier);
                      AppLogging.connection(
                        '🔧 DeviceManagement: Sending nodeDbReset — '
                        'will clear all discovered nodes from device',
                      );
                      await protocol.nodeDbReset();
                      AppLogging.connection(
                        '🔧 DeviceManagement: nodeDbReset sent — '
                        'clearing local nodes cache',
                      );
                      // Clear local nodes from the app's state and storage
                      nodesNotifier.clearNodes();
                    },
                    warningMessage:
                        'This will clear all discovered nodes from the device and app. Nodes will be rediscovered over time.',
                  ),
                ),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.settings_backup_restore,
                  iconColor: Colors.deepOrange,
                  title: 'Factory Reset Config',
                  subtitle: 'Reset everything except the node database',
                  enabled: isConnected,
                  onTap: () => _executeAction(
                    'Factory Reset Config',
                    () async {
                      final settingsAsync = ref.read(settingsServiceProvider);
                      final channelsNotifier = ref.read(
                        channelsProvider.notifier,
                      );
                      AppLogging.connection(
                        '🔧 DeviceManagement: Sending factoryResetConfig — '
                        'will wipe channels, region, all config but keep nodedb. '
                        'Device will reboot in ~5s',
                      );
                      await protocol.factoryResetConfig();
                      AppLogging.connection(
                        '🔧 DeviceManagement: factoryResetConfig command sent — '
                        'clearing local region + channels state',
                      );
                      // Clear local state that will be invalidated by config reset
                      if (settingsAsync.hasValue) {
                        // Region will be UNSET after config reset, so clear the configured flag
                        await settingsAsync.requireValue.setRegionConfigured(
                          false,
                        );
                        AppLogging.connection(
                          '🔧 DeviceManagement: regionConfigured cleared — '
                          'region selection will be required on next connection',
                        );
                      }
                      // Clear channels from local cache
                      channelsNotifier.clearChannels();
                      AppLogging.connection(
                        '🔧 DeviceManagement: Local channels cleared — '
                        'expecting device disconnect shortly',
                      );
                    },
                    warningMessage:
                        'This will wipe channels, region, and all settings but preserves the node database.\n\n'
                        'The device will reboot in 5 seconds. You will need to set up the region again.',
                    causesDisconnect: true,
                  ),
                ),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.delete_forever,
                  iconColor: theme.colorScheme.error,
                  title: 'Full Factory Reset',
                  subtitle: 'Erase everything and reset device',
                  enabled: isConnected,
                  onTap: () => _executeAction(
                    'Full Factory Reset',
                    () async {
                      // Capture navigator before async operations
                      final navigator = Navigator.of(context);

                      final settingsAsync = ref.read(settingsServiceProvider);
                      final nodesNotifier = ref.read(nodesProvider.notifier);
                      final channelsNotifier = ref.read(
                        channelsProvider.notifier,
                      );
                      final appInitNotifier = ref.read(
                        appInitProvider.notifier,
                      );
                      AppLogging.connection(
                        '🔧 DeviceManagement: Sending factoryResetDevice — '
                        'will WIPE EVERYTHING (config, channels, nodes, identity). '
                        'Device will reboot in ~5s',
                      );
                      await protocol.factoryResetDevice();
                      AppLogging.connection(
                        '🔧 DeviceManagement: factoryResetDevice command sent — '
                        'clearing ALL local state (region, lastDevice, nodes, channels)',
                      );
                      // Clear ALL local state - device is being wiped completely
                      if (settingsAsync.hasValue) {
                        // Region will be UNSET, clear configured flag
                        await settingsAsync.requireValue.setRegionConfigured(
                          false,
                        );
                        // Device is being wiped, clear the last device
                        await settingsAsync.requireValue.clearLastDevice();
                        AppLogging.connection(
                          '🔧 DeviceManagement: regionConfigured + lastDevice cleared',
                        );
                      }
                      // Clear nodes and channels from local cache
                      nodesNotifier.clearNodes();
                      channelsNotifier.clearChannels();
                      AppLogging.connection(
                        '🔧 DeviceManagement: Local nodes + channels cleared',
                      );

                      // CRITICAL: Set app state to needsScanner BEFORE navigating
                      // This ensures the router shows ScannerScreen instead of MainShell
                      appInitNotifier.setNeedsScanner();
                      AppLogging.connection(
                        '🔧 DeviceManagement: appInit set to needsScanner — '
                        'navigating to /app for fresh _AppRouter rebuild',
                      );

                      // Navigate via canonical /app route so _AppRouter reads
                      // needsScanner and shows Scanner. Using /scanner directly
                      // bypasses the router and can cause stale state issues.
                      if (mounted) {
                        navigator.pushNamedAndRemoveUntil(
                          '/app',
                          (route) => false,
                        );
                      }
                    },
                    warningMessage:
                        'WARNING: This will completely erase the device including:\n'
                        '• All configuration\n'
                        '• All channels\n'
                        '• All known nodes\n'
                        '• Device identity\n\n'
                        'The device will reboot in 5 seconds. You will need to pair and set it up again.',
                    causesDisconnect: false, // Navigation handled in action
                  ),
                ),
                const SizedBox(height: 24),
                _SectionHeader(title: 'FIRMWARE'),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.system_update,
                  iconColor: Colors.indigo,
                  title: 'Enter DFU Mode',
                  subtitle: 'Boot into firmware update mode',
                  enabled: isConnected,
                  onTap: () => _executeAction(
                    'Enter DFU Mode',
                    () async {
                      AppLogging.connection(
                        '🔧 DeviceManagement: Sending enterDfuMode — '
                        'device will boot into firmware update mode, BLE will drop',
                      );
                      await protocol.enterDfuMode();
                      AppLogging.connection(
                        '🔧 DeviceManagement: enterDfuMode sent — '
                        'expecting disconnect shortly',
                      );
                    },
                    warningMessage:
                        'The device will enter Device Firmware Update (DFU) mode. '
                        'You will need to use a firmware update tool to flash new firmware or reset the device.\n\n'
                        'You will be disconnected from the device.',
                    causesDisconnect: true,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = enabled ? iconColor : theme.disabledColor;
    final effectiveTextColor = enabled ? null : theme.disabledColor;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: effectiveIconColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: effectiveTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: enabled
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.disabledColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: enabled
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.disabledColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
