// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/connection_providers.dart' as conn;
import '../../providers/splash_mesh_provider.dart';
import '../../services/protocol/admin_target.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/app_bottom_sheet.dart';
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
      final confirmed = await AppBottomSheet.show<bool>(
        context: context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  causesDisconnect
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline,
                  color: causesDisconnect
                      ? AppTheme.warningYellow
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    actionName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              warningMessage ??
                  'Are you sure you want to $actionName? This action cannot be undone.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: causesDisconnect
                          ? AppTheme.warningYellow
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: causesDisconnect
                          ? Colors.black
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Confirm'),
                  ),
                ),
              ],
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
                      final target = AdminTarget.fromNullable(
                        ref.read(remoteAdminTargetProvider),
                      );
                      if (target.isLocal) {
                        final autoReconnectNotifier = ref.read(
                          autoReconnectStateProvider.notifier,
                        );
                        AppLogging.connection(
                          '🔧 DeviceManagement: Sending reboot command '
                          '(delay=2s) — device will restart and BLE will drop',
                        );
                        await protocol.reboot(delaySeconds: 2, target: target);
                        // Clear stale manualConnecting so auto-reconnect
                        // manager can handle the reboot/reconnect cycle
                        autoReconnectNotifier.setState(AutoReconnectState.idle);
                        AppLogging.connection(
                          '🔧 DeviceManagement: Reboot command sent — '
                          'expecting disconnect in ~2s, '
                          'autoReconnectState set to idle for reconnect',
                        );
                      } else {
                        AppLogging.connection(
                          '🔧 Remote Admin: Sending reboot to remote device',
                        );
                        await protocol.reboot(delaySeconds: 2, target: target);
                      }
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
                      final target = AdminTarget.fromNullable(
                        ref.read(remoteAdminTargetProvider),
                      );
                      if (target.isLocal) {
                        final autoReconnectNotifier = ref.read(
                          autoReconnectStateProvider.notifier,
                        );
                        AppLogging.connection(
                          '🔧 DeviceManagement: Sending shutdown command '
                          '(delay=2s) — device will power off and BLE will drop',
                        );
                        await protocol.shutdown(
                          delaySeconds: 2,
                          target: target,
                        );
                        // Clear stale manualConnecting so if user powers
                        // device back on, auto-reconnect isn't blocked
                        autoReconnectNotifier.setState(AutoReconnectState.idle);
                        AppLogging.connection(
                          '🔧 DeviceManagement: Shutdown command sent — '
                          'expecting disconnect in ~2s, '
                          'autoReconnectState set to idle',
                        );
                      } else {
                        AppLogging.connection(
                          '🔧 Remote Admin: Sending shutdown to remote device',
                        );
                        await protocol.shutdown(
                          delaySeconds: 2,
                          target: target,
                        );
                      }
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
                      final target = AdminTarget.fromNullable(
                        ref.read(remoteAdminTargetProvider),
                      );
                      AppLogging.connection(
                        '🔧 DeviceManagement: Sending nodeDbReset — '
                        'will clear all discovered nodes from device',
                      );
                      await protocol.nodeDbReset(target: target);
                      AppLogging.connection(
                        '🔧 DeviceManagement: nodeDbReset sent',
                      );
                      // Only clear local app state for local device
                      if (target.isLocal) {
                        final nodesNotifier = ref.read(nodesProvider.notifier);
                        AppLogging.connection(
                          '🔧 DeviceManagement: clearing local nodes cache',
                        );
                        nodesNotifier.clearNodes();
                      }
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
                      final target = AdminTarget.fromNullable(
                        ref.read(remoteAdminTargetProvider),
                      );
                      AppLogging.connection(
                        '🔧 DeviceManagement: Sending factoryResetConfig — '
                        'will wipe channels, region, all config but keep nodedb. '
                        'Device will reboot in ~5s',
                      );
                      await protocol.factoryResetConfig(target: target);
                      AppLogging.connection(
                        '🔧 DeviceManagement: factoryResetConfig command sent',
                      );
                      // Only clear local state for local device
                      if (target.isLocal) {
                        final settingsAsync = ref.read(settingsServiceProvider);
                        final channelsNotifier = ref.read(
                          channelsProvider.notifier,
                        );
                        final autoReconnectNotifier = ref.read(
                          autoReconnectStateProvider.notifier,
                        );
                        AppLogging.connection(
                          '🔧 DeviceManagement: clearing local region '
                          '+ channels state',
                        );
                        if (settingsAsync.hasValue) {
                          await settingsAsync.requireValue.setRegionConfigured(
                            false,
                          );
                          AppLogging.connection(
                            '🔧 DeviceManagement: regionConfigured cleared — '
                            'region selection will be required on next '
                            'connection',
                          );
                        }
                        channelsNotifier.clearChannels();
                        AppLogging.connection(
                          '🔧 DeviceManagement: Local channels cleared — '
                          'expecting device disconnect shortly',
                        );
                        autoReconnectNotifier.setState(AutoReconnectState.idle);
                        AppLogging.connection(
                          '🔧 DeviceManagement: autoReconnectState set '
                          'to idle (cleared stale manualConnecting '
                          'for reconnect)',
                        );
                      }
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
                      final target = AdminTarget.fromNullable(
                        ref.read(remoteAdminTargetProvider),
                      );
                      // Capture navigator before any await
                      final navigator = Navigator.of(context);

                      AppLogging.connection(
                        '🔧 DeviceManagement: Sending factoryResetDevice — '
                        'will WIPE EVERYTHING (config, channels, nodes, '
                        'identity). Device will reboot in ~5s',
                      );
                      await protocol.factoryResetDevice(target: target);
                      AppLogging.connection(
                        '🔧 DeviceManagement: factoryResetDevice command sent',
                      );

                      // Only clear local state and navigate when targeting
                      // the local device. Remote factory reset should not
                      // disconnect us or wipe local state.
                      if (!target.isLocal) return;

                      // Capture ALL providers before any more awaits
                      final settingsAsync = ref.read(settingsServiceProvider);
                      final nodesNotifier = ref.read(nodesProvider.notifier);
                      final channelsNotifier = ref.read(
                        channelsProvider.notifier,
                      );
                      final appInitNotifier = ref.read(
                        appInitProvider.notifier,
                      );
                      final deviceConnectionNotifier = ref.read(
                        conn.deviceConnectionProvider.notifier,
                      );
                      final userDisconnectedNotifier = ref.read(
                        userDisconnectedProvider.notifier,
                      );
                      final autoReconnectNotifier = ref.read(
                        autoReconnectStateProvider.notifier,
                      );

                      // CRITICAL: Follow the same disconnect-first pattern as
                      // manual disconnect (device_sheet.dart). If we navigate
                      // to Scanner while transport is still connected,
                      // Scanner's _tryAutoReconnect sees connected state,
                      // thinks "why am I here?", calls setReady() → router
                      // shows MainShell → user stranded on empty Nodes screen.

                      // 1. Set userDisconnected to prevent auto-reconnect to
                      //    the wiped device during/after disconnect
                      AppLogging.connection(
                        '🔧 DeviceManagement: Setting userDisconnected=true '
                        'to prevent auto-reconnect to wiped device',
                      );
                      userDisconnectedNotifier.setUserDisconnected(true);

                      // 2. Clear manualConnecting (stale from initial
                      //    Scanner connection) so it doesn't block anything
                      AppLogging.connection(
                        '🔧 DeviceManagement: Setting autoReconnectState '
                        'to idle (clearing stale manualConnecting)',
                      );
                      autoReconnectNotifier.setState(AutoReconnectState.idle);

                      // 3. Disconnect transport and wait for it to complete
                      AppLogging.connection(
                        '🔧 DeviceManagement: Disconnecting transport '
                        'before navigating to Scanner...',
                      );
                      await deviceConnectionNotifier.disconnect();
                      AppLogging.connection(
                        '🔧 DeviceManagement: Transport disconnected',
                      );

                      // 4. Stop protocol service
                      protocol.stop();

                      // 5. Clear ALL local state
                      AppLogging.connection(
                        '🔧 DeviceManagement: Clearing ALL local state '
                        '(region, lastDevice, nodes, channels)',
                      );
                      if (settingsAsync.hasValue) {
                        await settingsAsync.requireValue.setRegionConfigured(
                          false,
                        );
                        await settingsAsync.requireValue.clearLastDevice();
                        AppLogging.connection(
                          '🔧 DeviceManagement: regionConfigured + '
                          'lastDevice cleared',
                        );
                      }
                      nodesNotifier.clearNodes();
                      channelsNotifier.clearChannels();
                      AppLogging.connection(
                        '🔧 DeviceManagement: Local nodes + channels cleared',
                      );

                      // 6. Set app state and navigate
                      appInitNotifier.setNeedsScanner();
                      AppLogging.connection(
                        '🔧 DeviceManagement: appInit set to needsScanner — '
                        'navigating to /app for fresh _AppRouter rebuild',
                      );

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
                      final target = AdminTarget.fromNullable(
                        ref.read(remoteAdminTargetProvider),
                      );
                      AppLogging.connection(
                        '🔧 DeviceManagement: Sending enterDfuMode — '
                        'device will boot into firmware update mode, '
                        'BLE will drop',
                      );
                      await protocol.enterDfuMode(target: target);
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
