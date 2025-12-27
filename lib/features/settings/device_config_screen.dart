import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/animations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
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
  // Additional settings matching iOS
  int _buttonGpio = 0;
  int _buzzerGpio = 0;
  bool _doubleTapAsButtonPress = false;
  bool _tripleClickEnabled =
      true; // Note: protobuf is "disableTripleClick" (inverted)
  String _tzdef = '';
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
      // Additional settings
      _buttonGpio = config.buttonGpio;
      _buzzerGpio = config.buzzerGpio;
      _doubleTapAsButtonPress = config.doubleTapAsButtonPress;
      _tripleClickEnabled = !config.disableTripleClick;
      _tzdef = config.tzdef;
    });
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
      final targetNodeNum = ref.read(remoteAdminTargetProvider);
      final isRemote = targetNodeNum != null;

      // For local config, apply cached config immediately if available
      if (!isRemote) {
        final cached = protocol.currentDeviceConfig;
        if (cached != null) {
          _applyConfig(cached);
        }
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription = protocol.deviceConfigStream.listen((config) {
          if (mounted) _applyConfig(config);
        });

        // Request fresh config from device (or remote node)
        await protocol.getConfig(
          pb.AdminMessage_ConfigType.DEVICE_CONFIG,
          targetNodeNum: targetNodeNum,
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
      final targetNodeNum = ref.read(remoteAdminTargetProvider);

      await protocol.setDeviceConfig(
        role: _selectedRole ?? pb.Config_DeviceConfig_Role_.CLIENT,
        rebroadcastMode:
            _rebroadcastMode ?? pb.Config_DeviceConfig_RebroadcastMode.ALL,
        serialEnabled: _serialEnabled,
        nodeInfoBroadcastSecs: _nodeInfoBroadcastSecs,
        ledHeartbeatDisabled: _ledHeartbeatDisabled,
        doubleTapAsButtonPress: _doubleTapAsButtonPress,
        buttonGpio: _buttonGpio,
        buzzerGpio: _buzzerGpio,
        disableTripleClick: !_tripleClickEnabled,
        tzdef: _tzdef,
        targetNodeNum: targetNodeNum,
      );

      if (mounted) {
        final isRemote = targetNodeNum != null;
        showSuccessSnackBar(
          context,
          isRemote
              ? 'Configuration sent to remote node'
              : 'Device configuration saved',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remoteState = ref.watch(remoteAdminProvider);
    final isRemote = remoteState.isRemote;

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          isRemote ? 'Device (Remote)' : 'Device',
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
                      child: MeshLoadingIndicator(
                        size: 20,
                        colors: [
                          context.accentColor,
                          context.accentColor.withValues(alpha: 0.6),
                          context.accentColor.withValues(alpha: 0.3),
                        ],
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
          ? const ScreenLoadingIndicator()
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Remote admin banner
                if (isRemote) _buildRemoteAdminBanner(context, remoteState),
                const _SectionHeader(title: 'DEVICE ROLE'),
                _buildRoleSelector(),
                SizedBox(height: 16),
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
                    color: context.card,
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
                      SizedBox(height: 4),
                      Text(
                        'How often to broadcast device info',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          inactiveTrackColor: context.border,
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
                SizedBox(height: 16),
                const _SectionHeader(title: 'HARDWARE'),
                _SettingsTile(
                  icon: Icons.touch_app,
                  iconColor: _doubleTapAsButtonPress
                      ? context.accentColor
                      : null,
                  title: 'Double Tap as Button',
                  subtitle: 'Treat double tap on accelerometer as button press',
                  trailing: ThemedSwitch(
                    value: _doubleTapAsButtonPress,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _doubleTapAsButtonPress = value);
                    },
                  ),
                ),
                _SettingsTile(
                  icon: Icons.location_pin,
                  iconColor: _tripleClickEnabled ? context.accentColor : null,
                  title: 'Triple Click Ad Hoc Ping',
                  subtitle: 'Send position on triple click',
                  trailing: ThemedSwitch(
                    value: _tripleClickEnabled,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _tripleClickEnabled = value);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionHeader(title: 'GPIO'),
                _buildGpioSettings(),
                const SizedBox(height: 16),
                const _SectionHeader(title: 'DEBUG'),
                _buildTimezoneSettings(),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildRemoteAdminBanner(
    BuildContext context,
    RemoteAdminState remoteState,
  ) {
    final accentColor = context.accentColor;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(12),
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
        border: Border.all(color: accentColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.admin_panel_settings, color: accentColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remote Administration',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Configuring: ${remoteState.targetNodeName ?? '0x${remoteState.targetNodeNum!.toRadixString(16)}'}',
                  style: TextStyle(
                    color: accentColor.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpioSettings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Button GPIO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Button GPIO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<int>(
                  underline: const SizedBox.shrink(),
                  dropdownColor: context.card,
                  style: const TextStyle(color: Colors.white),
                  value: _buttonGpio,
                  items: List.generate(49, (i) {
                    return DropdownMenuItem(
                      value: i,
                      child: Text(i == 0 ? 'Unset' : 'Pin $i'),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) setState(() => _buttonGpio = value);
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'GPIO pin for user button',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          Divider(height: 24, color: context.border),
          // Buzzer GPIO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Buzzer GPIO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<int>(
                  underline: const SizedBox.shrink(),
                  dropdownColor: context.card,
                  style: const TextStyle(color: Colors.white),
                  value: _buzzerGpio,
                  items: List.generate(49, (i) {
                    return DropdownMenuItem(
                      value: i,
                      child: Text(i == 0 ? 'Unset' : 'Pin $i'),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) setState(() => _buzzerGpio = value);
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'GPIO pin for PWM buzzer',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTimezoneSettings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: context.textSecondary, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Zone',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'POSIX timezone for device display',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              fillColor: context.background,
              filled: true,
              hintText: 'e.g., EST5EDT,M3.2.0,M11.1.0',
              hintStyle: TextStyle(color: context.textTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.border),
              ),
            ),
            controller: TextEditingController(text: _tzdef),
            onChanged: (value) {
              // Limit to 63 bytes as per iOS
              if (value.length <= 63) {
                setState(() => _tzdef = value);
              }
            },
          ),
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
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select how this device should behave in the mesh',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
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
                          : context.border,
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
                            : context.textSecondary,
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
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: context.accentColor),
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
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Controls which messages this device will relay',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
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
                          : context.textSecondary,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.$2,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : context.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            m.$3,
                            style: TextStyle(
                              color: context.textTertiary,
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: context.textTertiary,
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
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textTertiary,
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
