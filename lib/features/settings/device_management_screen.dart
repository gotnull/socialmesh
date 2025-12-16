import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/transport.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';

/// Screen for device management actions like reboot, shutdown, factory reset
class DeviceManagementScreen extends ConsumerStatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  ConsumerState<DeviceManagementScreen> createState() =>
      _DeviceManagementScreenState();
}

class _DeviceManagementScreenState
    extends ConsumerState<DeviceManagementScreen> {
  bool _isProcessing = false;

  Future<void> _executeAction(
    String actionName,
    Future<void> Function() action, {
    bool requiresConfirmation = true,
    String? warningMessage,
  }) async {
    if (requiresConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(actionName),
          content: Text(
            warningMessage ??
                'Are you sure you want to $actionName? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isProcessing = true);

    try {
      await action();
      if (mounted) {
        showSuccessSnackBar(context, '$actionName command sent');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final protocol = ref.watch(protocolServiceProvider);
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final isConnected = connectionStateAsync.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Device Management')),
      body: _isProcessing
          ? const Center(child: MeshLoadingIndicator(size: 48))
          : ListView(
              padding: const EdgeInsets.all(16),
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
                    () => protocol.reboot(delaySeconds: 2),
                    warningMessage:
                        'The device will reboot in 2 seconds. You will need to reconnect.',
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
                    () => protocol.shutdown(delaySeconds: 2),
                    warningMessage:
                        'The device will shut down in 2 seconds. You will need to manually power it back on.',
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
                  subtitle: 'Clear all known nodes from memory',
                  enabled: isConnected,
                  onTap: () => _executeAction(
                    'Reset Node Database',
                    () => protocol.nodeDbReset(),
                    warningMessage:
                        'This will clear all discovered nodes from the device. Nodes will be rediscovered over time.',
                  ),
                ),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.settings_backup_restore,
                  iconColor: Colors.deepOrange,
                  title: 'Factory Reset Config',
                  subtitle: 'Reset all settings to defaults (keeps node DB)',
                  enabled: isConnected,
                  onTap: () => _executeAction(
                    'Factory Reset Config',
                    () => protocol.factoryResetConfig(),
                    warningMessage:
                        'This will reset all configuration to factory defaults. '
                        'Your channels, region, and all settings will be erased. '
                        'Node database will be preserved.',
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
                    () => protocol.factoryResetDevice(),
                    warningMessage:
                        'WARNING: This will completely erase the device including:\n'
                        '• All configuration\n'
                        '• All channels\n'
                        '• All known nodes\n'
                        '• Device identity\n\n'
                        'The device will be like new out of the box.',
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
                    () => protocol.enterDfuMode(),
                    warningMessage:
                        'The device will enter Device Firmware Update (DFU) mode. '
                        'You will need to use a firmware update tool to flash new firmware or reset the device.',
                  ),
                ),
                const SizedBox(height: 32),
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
