import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../services/storage/storage_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsServiceAsync = ref.watch(settingsServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsServiceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading settings: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(settingsServiceProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (settingsService) => ListView(
          children: [
            const ListTile(
              title: Text(
                'Connection',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            SwitchListTile(
              title: const Text('Auto-reconnect'),
              subtitle: const Text('Automatically reconnect to last device'),
              value: settingsService.autoReconnect,
              onChanged: (value) {
                settingsService.setAutoReconnect(value);
              },
            ),
            const Divider(),
            const ListTile(
              title: Text(
                'Appearance',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            SwitchListTile(
              title: const Text('Dark mode'),
              subtitle: const Text('Use dark theme'),
              value: settingsService.darkMode,
              onChanged: (value) {
                settingsService.setDarkMode(value);
              },
            ),
            const Divider(),
            const ListTile(
              title: Text(
                'Notifications',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            SwitchListTile(
              title: const Text('Enable notifications'),
              subtitle: const Text('Show notifications for new messages'),
              value: settingsService.notificationsEnabled,
              onChanged: (value) {
                settingsService.setNotificationsEnabled(value);
              },
            ),
            const Divider(),
            const ListTile(
              title: Text(
                'Data',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: const Text('Message history limit'),
              subtitle: Text('${settingsService.messageHistoryLimit} messages'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showHistoryLimitDialog(context, settingsService);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Clear all data',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => _confirmClearData(context, ref),
            ),
            const Divider(),
            const ListTile(
              title: Text(
                'About',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const ListTile(
              title: Text('Protofluff'),
              subtitle: Text('Meshtastic companion app\nVersion 1.0.0'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistoryLimitDialog(
    BuildContext context,
    SettingsService settingsService,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message History Limit'),
        content: StatefulBuilder(
          builder: (context, setState) {
            int currentValue = settingsService.messageHistoryLimit;
            return SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [50, 100, 200, 500, 1000].map((limit) {
                  final isSelected = currentValue == limit;
                  return InkWell(
                    onTap: () {
                      settingsService.setMessageHistoryLimit(limit);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Text('$limit messages'),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will delete all messages, settings, and channel keys. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear Data'),
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

      // Clear settings if available
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
}
