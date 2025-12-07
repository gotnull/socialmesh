import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
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
        showAppSnackBar(context, '$actionName command sent');
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

    return Scaffold(
      appBar: AppBar(title: const Text('Device Management')),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(title: 'POWER'),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.refresh,
                  iconColor: theme.colorScheme.primary,
                  title: 'Reboot Device',
                  subtitle: 'Restart the device',
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

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
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
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
