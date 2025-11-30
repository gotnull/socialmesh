import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;

/// Screen for configuring device role and basic device settings
class DeviceConfigScreen extends ConsumerStatefulWidget {
  const DeviceConfigScreen({super.key});

  @override
  ConsumerState<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends ConsumerState<DeviceConfigScreen> {
  bool _isLoading = false;
  pb.Config_DeviceConfig_Role_? _selectedRole;
  pb.Config_DeviceConfig_RebroadcastMode? _rebroadcastMode;
  bool _serialEnabled = true;
  bool _ledHeartbeatDisabled = false;
  int _nodeInfoBroadcastSecs = 900;
  StreamSubscription<pb.Config_DeviceConfig>? _configSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    super.dispose();
  }

  void _applyConfig(pb.Config_DeviceConfig config) {
    setState(() {
      _selectedRole = config.role;
      _rebroadcastMode = config.rebroadcastMode;
      _serialEnabled = config.serialEnabled;
      _ledHeartbeatDisabled = config.ledHeartbeatDisabled;
      _nodeInfoBroadcastSecs = config.nodeInfoBroadcastSecs > 0
          ? config.nodeInfoBroadcastSecs
          : 900;
    });
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);

      // Apply cached config immediately if available
      final cached = protocol.currentDeviceConfig;
      if (cached != null) {
        _applyConfig(cached);
      }

      // Listen for config response
      _configSubscription = protocol.deviceConfigStream.listen((config) {
        if (mounted) _applyConfig(config);
      });

      // Request fresh config from device
      await protocol.getConfig(pb.AdminMessage_ConfigType.DEVICE_CONFIG);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setDeviceConfig(
        role: _selectedRole,
        rebroadcastMode: _rebroadcastMode,
        serialEnabled: _serialEnabled,
        nodeInfoBroadcastSecs: _nodeInfoBroadcastSecs,
        ledHeartbeatDisabled: _ledHeartbeatDisabled,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device configuration saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Configuration'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveConfig,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(title: 'DEVICE ROLE'),
                const SizedBox(height: 8),
                _buildRoleSelector(theme),
                const SizedBox(height: 24),
                _SectionHeader(title: 'REBROADCAST'),
                const SizedBox(height: 8),
                _buildRebroadcastSelector(theme),
                const SizedBox(height: 24),
                _SectionHeader(title: 'SETTINGS'),
                const SizedBox(height: 8),
                _buildSettings(theme),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildRoleSelector(ThemeData theme) {
    final roles = [
      (
        pb.Config_DeviceConfig_Role_.CLIENT,
        'Client',
        'Standard messaging device',
        Icons.phone_android,
      ),
      (
        pb.Config_DeviceConfig_Role_.CLIENT_MUTE,
        'Client Mute',
        'Does not forward packets',
        Icons.volume_off,
      ),
      (
        pb.Config_DeviceConfig_Role_.CLIENT_HIDDEN,
        'Client Hidden',
        'Only speaks when spoken to',
        Icons.visibility_off,
      ),
      (
        pb.Config_DeviceConfig_Role_.ROUTER,
        'Router',
        'Infrastructure node for extending coverage',
        Icons.router,
      ),
      (
        pb.Config_DeviceConfig_Role_.ROUTER_CLIENT,
        'Router Client',
        'Router that also handles direct messages',
        Icons.device_hub,
      ),
      (
        pb.Config_DeviceConfig_Role_.REPEATER,
        'Repeater',
        'Simple packet repeater (no encryption)',
        Icons.repeat,
      ),
      (
        pb.Config_DeviceConfig_Role_.TRACKER,
        'Tracker',
        'GPS tracker with optimized position broadcasts',
        Icons.location_on,
      ),
      (
        pb.Config_DeviceConfig_Role_.SENSOR,
        'Sensor',
        'Telemetry sensor node',
        Icons.sensors,
      ),
      (
        pb.Config_DeviceConfig_Role_.TAK,
        'TAK',
        'Optimized for ATAK communication',
        Icons.military_tech,
      ),
      (
        pb.Config_DeviceConfig_Role_.TAK_TRACKER,
        'TAK Tracker',
        'TAK with automatic position broadcasts',
        Icons.gps_fixed,
      ),
      (
        pb.Config_DeviceConfig_Role_.LOST_AND_FOUND,
        'Lost & Found',
        'Broadcasts location for device recovery',
        Icons.search,
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select how this device should behave in the mesh',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...roles.map((r) {
              final isSelected = _selectedRole == r.$1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _selectedRole = r.$1),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withAlpha(100),
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          ? theme.colorScheme.primaryContainer.withAlpha(50)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          r.$4,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.$2,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : null,
                                ),
                              ),
                              Text(
                                r.$3,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRebroadcastSelector(ThemeData theme) {
    final modes = [
      (
        pb.Config_DeviceConfig_RebroadcastMode.ALL,
        'All',
        'Rebroadcast all observed messages',
      ),
      (
        pb.Config_DeviceConfig_RebroadcastMode.ALL_SKIP_DECODING,
        'All (Skip Decoding)',
        'Rebroadcast without decoding',
      ),
      (
        pb.Config_DeviceConfig_RebroadcastMode.LOCAL_ONLY,
        'Local Only',
        'Only rebroadcast local channel messages',
      ),
      (
        pb.Config_DeviceConfig_RebroadcastMode.KNOWN_ONLY,
        'Known Only',
        'Only rebroadcast from known nodes',
      ),
      (
        pb.Config_DeviceConfig_RebroadcastMode.NONE,
        'None',
        'Do not rebroadcast any messages',
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rebroadcast Mode',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Controls which messages this device will relay',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...modes.map((m) {
              final isSelected = _rebroadcastMode == m.$1;
              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                title: Text(m.$2),
                subtitle: Text(m.$3),
                contentPadding: EdgeInsets.zero,
                dense: true,
                onTap: () => setState(() => _rebroadcastMode = m.$1),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSettings(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              value: _serialEnabled,
              onChanged: (value) => setState(() => _serialEnabled = value),
              title: const Text('Serial Console'),
              subtitle: const Text('Enable serial port for debugging'),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            SwitchListTile(
              value: !_ledHeartbeatDisabled,
              onChanged: (value) =>
                  setState(() => _ledHeartbeatDisabled = !value),
              title: const Text('LED Heartbeat'),
              subtitle: const Text('Flash LED to indicate device is running'),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Node Info Broadcast',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'How often to broadcast device info (${_formatDuration(_nodeInfoBroadcastSecs)})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Slider(
              value: _nodeInfoBroadcastSecs.toDouble(),
              min: 300,
              max: 86400,
              divisions: 20,
              label: _formatDuration(_nodeInfoBroadcastSecs),
              onChanged: (value) {
                setState(() => _nodeInfoBroadcastSecs = value.toInt());
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    if (seconds < 86400) return '${seconds ~/ 3600}h';
    return '${seconds ~/ 86400}d';
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
