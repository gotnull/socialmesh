import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/animations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
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
        role: _selectedRole ?? pb.Config_DeviceConfig_Role_.CLIENT,
        rebroadcastMode:
            _rebroadcastMode ?? pb.Config_DeviceConfig_RebroadcastMode.ALL,
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
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Device',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isLoading ? null : _saveConfig,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.accentColor,
                      ),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: context.accentColor,
                        fontWeight: FontWeight.w600,
                        
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                const _SectionHeader(title: 'DEVICE ROLE'),
                _buildRoleSelector(),
                const SizedBox(height: 16),
                const _SectionHeader(title: 'REBROADCAST'),
                _buildRebroadcastSelector(),
                SizedBox(height: 16),
                const _SectionHeader(title: 'SETTINGS'),
                _SettingsTile(
                  icon: Icons.terminal,
                  iconColor: _serialEnabled ? context.accentColor : null,
                  title: 'Serial Console',
                  subtitle: 'Enable serial port for debugging',
                  trailing: ThemedSwitch(
                    value: _serialEnabled,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _serialEnabled = value);
                    },
                  ),
                ),
                _SettingsTile(
                  icon: Icons.lightbulb_outline,
                  iconColor: !_ledHeartbeatDisabled
                      ? context.accentColor
                      : null,
                  title: 'LED Heartbeat',
                  subtitle: 'Flash LED to indicate device is running',
                  trailing: ThemedSwitch(
                    value: !_ledHeartbeatDisabled,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _ledHeartbeatDisabled = !value);
                    },
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Node Info Broadcast',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _formatDuration(_nodeInfoBroadcastSecs),
                              style: TextStyle(
                                color: context.accentColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'How often to broadcast device info',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          
                        ),
                      ),
                      SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          inactiveTrackColor: AppTheme.darkBorder,
                          thumbColor: context.accentColor,
                          overlayColor: context.accentColor.withValues(
                            alpha: 0.2,
                          ),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _nodeInfoBroadcastSecs.toDouble(),
                          min: 300,
                          max: 86400,
                          divisions: 20,
                          onChanged: (value) {
                            setState(
                              () => _nodeInfoBroadcastSecs = value.toInt(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildRoleSelector() {
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select how this device should behave in the mesh',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              
            ),
          ),
          SizedBox(height: 16),
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
                          ? context.accentColor
                          : AppTheme.darkBorder,
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected
                        ? context.accentColor.withValues(alpha: 0.1)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        r.$4,
                        color: isSelected
                            ? context.accentColor
                            : AppTheme.textSecondary,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.$2,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? context.accentColor
                                    : Colors.white,
                                
                              ),
                            ),
                            Text(
                              r.$3,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: context.accentColor,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRebroadcastSelector() {
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Controls which messages this device will relay',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              
            ),
          ),
          SizedBox(height: 16),
          ...modes.map((m) {
            final isSelected = _rebroadcastMode == m.$1;
            return InkWell(
              onTap: () => setState(() => _rebroadcastMode = m.$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? context.accentColor
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.$2,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                              
                            ),
                          ),
                          Text(
                            m.$3,
                            style: const TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 13,
                              
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      
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
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
