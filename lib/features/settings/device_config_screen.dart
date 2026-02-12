// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/logging.dart';
import '../../core/widgets/animations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../generated/meshtastic/config.pb.dart' as config_pb;
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../core/widgets/loading_indicator.dart';

/// Screen for configuring device role and basic device settings
class DeviceConfigScreen extends ConsumerStatefulWidget {
  const DeviceConfigScreen({super.key});

  @override
  ConsumerState<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends ConsumerState<DeviceConfigScreen>
    with LifecycleSafeMixin<DeviceConfigScreen> {
  bool _isLoading = false;
  config_pbenum.Config_DeviceConfig_Role? _selectedRole;
  config_pbenum.Config_DeviceConfig_RebroadcastMode? _rebroadcastMode;
  bool _serialEnabled = true;
  bool _ledHeartbeatDisabled = false;
  int _nodeInfoBroadcastSecs = 10800;
  // Additional settings matching iOS
  int _buttonGpio = 0;
  int _buzzerGpio = 0;
  bool _doubleTapAsButtonPress = false;
  bool _tripleClickEnabled =
      true; // Note: protobuf is "disableTripleClick" (inverted)
  String _tzdef = '';
  config_pbenum.Config_DeviceConfig_BuzzerMode? _buzzerMode;
  StreamSubscription<config_pb.Config_DeviceConfig>? _configSubscription;

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

  void _applyConfig(config_pb.Config_DeviceConfig config) {
    safeSetState(() {
      _selectedRole = config.role;
      _rebroadcastMode = config.rebroadcastMode;
      _serialEnabled = config.serialEnabled;
      _ledHeartbeatDisabled = config.ledHeartbeatDisabled;
      _nodeInfoBroadcastSecs = config.nodeInfoBroadcastSecs > 0
          ? config.nodeInfoBroadcastSecs
          : 10800;
      // Additional settings
      _buttonGpio = config.buttonGpio;
      _buzzerGpio = config.buzzerGpio;
      _doubleTapAsButtonPress = config.doubleTapAsButtonPress;
      _tripleClickEnabled = !config.disableTripleClick;
      _tzdef = config.tzdef;
      _buzzerMode = config.buzzerMode;
    });
  }

  Future<void> _loadCurrentConfig() async {
    // Capture providers before any await
    final protocol = ref.read(protocolServiceProvider);
    final targetNodeNum = ref.read(remoteAdminTargetProvider);

    safeSetState(() => _isLoading = true);
    try {
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
          admin_pbenum.AdminMessage_ConfigType.DEVICE_CONFIG,
          targetNodeNum: targetNodeNum,
        );
      }
    } on StateError catch (e) {
      // Device disconnected between isConnected check and getConfig call
      AppLogging.protocol('Device config load aborted: $e');
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    // Capture providers and UI dependencies before any await
    final protocol = ref.read(protocolServiceProvider);
    final targetNodeNum = ref.read(remoteAdminTargetProvider);
    final navigator = Navigator.of(context);

    safeSetState(() => _isLoading = true);
    try {
      await protocol.setDeviceConfig(
        role: _selectedRole ?? config_pbenum.Config_DeviceConfig_Role.CLIENT,
        rebroadcastMode:
            _rebroadcastMode ??
            config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
        serialEnabled: _serialEnabled,
        nodeInfoBroadcastSecs: _nodeInfoBroadcastSecs,
        ledHeartbeatDisabled: _ledHeartbeatDisabled,
        doubleTapAsButtonPress: _doubleTapAsButtonPress,
        buttonGpio: _buttonGpio,
        buzzerGpio: _buzzerGpio,
        disableTripleClick: !_tripleClickEnabled,
        tzdef: _tzdef,
        buzzerMode:
            _buzzerMode ??
            config_pbenum.Config_DeviceConfig_BuzzerMode.ALL_ENABLED,
        targetNodeNum: targetNodeNum,
      );

      if (!mounted) return;
      final isRemote = targetNodeNum != null;
      showSuccessSnackBar(
        context,
        isRemote
            ? 'Configuration sent to remote node'
            : 'Device configuration saved',
      );

      // Start global reboot countdown for local saves — banner persists
      // across navigation and auto-cancels when the device reconnects.
      // Remote admin saves don't reboot the local device.
      if (!isRemote) {
        ref
            .read(countdownProvider.notifier)
            .startDeviceRebootCountdown(reason: 'config saved');
      }

      navigator.pop();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save: $e');
      }
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remoteState = ref.watch(remoteAdminProvider);
    final isRemote = remoteState.isRemote;

    return GlassScaffold(
      title: isRemote ? 'Device (Remote)' : 'Device',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton(
            onPressed: _isLoading ? null : _saveConfig,
            child: _isLoading
                ? LoadingIndicator(size: 20)
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
      slivers: _isLoading
          ? [SliverFillRemaining(child: const ScreenLoadingIndicator())]
          : [
              SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
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
                    _buildNodeInfoBroadcastTile(),
                    SizedBox(height: 16),
                    const _SectionHeader(title: 'HARDWARE'),
                    _SettingsTile(
                      icon: Icons.touch_app,
                      iconColor: _doubleTapAsButtonPress
                          ? context.accentColor
                          : null,
                      title: 'Double Tap as Button',
                      subtitle:
                          'Treat double tap on accelerometer as button press',
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
                      iconColor: _tripleClickEnabled
                          ? context.accentColor
                          : null,
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
                    const _SectionHeader(title: 'BUZZER'),
                    _buildBuzzerModeSelector(),
                    const SizedBox(height: 16),
                    const _SectionHeader(title: 'GPIO'),
                    _buildGpioSettings(),
                    const SizedBox(height: 16),
                    const _SectionHeader(title: 'DEBUG'),
                    _buildTimezoneSettings(),
                    const SizedBox(height: 16),
                    const _SectionHeader(title: 'DANGER ZONE'),
                    _buildResetButtons(),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
    );
  }

  Widget _buildResetButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // NodeDB Reset
          InkWell(
            onTap: _showNodeDbResetDialog,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.refresh, color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset Node Database',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Clear all stored node information',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.textTertiary),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            indent: 70,
            color: context.border.withValues(alpha: 0.3),
          ),
          // Factory Reset
          InkWell(
            onTap: _showFactoryResetDialog,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.warning_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Factory Reset',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Reset device to factory defaults',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.textTertiary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNodeDbResetDialog() async {
    // Capture provider before any await
    final protocol = ref.read(protocolServiceProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.refresh, color: Colors.orange),
            const SizedBox(width: 12),
            Text(
              'Reset Node Database',
              style: TextStyle(color: dialogContext.textPrimary),
            ),
          ],
        ),
        content: Text(
          'This will clear all stored node information from the device. '
          'The mesh network will need to rediscover all nodes.\n\n'
          'Are you sure you want to continue?',
          style: TextStyle(color: dialogContext.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: dialogContext.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      try {
        await protocol.nodeDbReset();
        if (mounted) {
          showSuccessSnackBar(context, 'Node database reset initiated');
        }
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(context, 'Failed to reset: $e');
        }
      }
    }
  }

  Future<void> _showFactoryResetDialog() async {
    AppLogging.connection('🔧 DeviceConfig: Factory reset dialog opened');
    // Capture provider before any await
    final protocol = ref.read(protocolServiceProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red),
            const SizedBox(width: 12),
            Text(
              'Factory Reset',
              style: TextStyle(color: dialogContext.textPrimary),
            ),
          ],
        ),
        content: Text(
          'This will reset ALL device settings to factory defaults, '
          'including channels, configuration, and stored data.\n\n'
          'This action cannot be undone!\n\n'
          'Are you absolutely sure?',
          style: TextStyle(color: dialogContext.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: dialogContext.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Factory Reset'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      AppLogging.connection(
        '🔧 DeviceConfig: Factory reset confirmed — sending '
        'factoryResetDevice command',
      );
      try {
        await protocol.factoryResetDevice();
        AppLogging.connection(
          '🔧 DeviceConfig: factoryResetDevice command sent — '
          'device will restart, expecting disconnect shortly',
        );
        if (mounted) {
          showSuccessSnackBar(
            context,
            'Factory reset initiated - device will restart',
          );
        }
      } catch (e) {
        AppLogging.connection('🔧 DeviceConfig: factoryResetDevice FAILED: $e');
        if (mounted) {
          showErrorSnackBar(context, 'Failed to reset: $e');
        }
      }
    } else {
      AppLogging.connection('🔧 DeviceConfig: Factory reset cancelled by user');
    }
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
                  color: context.textPrimary,
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
                  style: TextStyle(color: context.textPrimary),
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
                  color: context.textPrimary,
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
                  style: TextStyle(color: context.textPrimary),
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

  Widget _buildBuzzerModeSelector() {
    final buzzerModes = [
      (
        config_pbenum.Config_DeviceConfig_BuzzerMode.ALL_ENABLED,
        'All Enabled',
        'All feedback including buttons and alerts',
        Icons.volume_up,
      ),
      (
        config_pbenum.Config_DeviceConfig_BuzzerMode.NOTIFICATIONS_ONLY,
        'Notifications Only',
        'Only notifications and alerts, not buttons',
        Icons.notifications_active,
      ),
      (
        config_pbenum.Config_DeviceConfig_BuzzerMode.DIRECT_MSG_ONLY,
        'Direct Messages Only',
        'Only direct messages and alerts',
        Icons.message,
      ),
      (
        config_pbenum.Config_DeviceConfig_BuzzerMode.SYSTEM_ONLY,
        'System Only',
        'Button presses and startup/shutdown only',
        Icons.settings_applications,
      ),
      (
        config_pbenum.Config_DeviceConfig_BuzzerMode.DISABLED,
        'Disabled',
        'All buzzer audio disabled',
        Icons.volume_off,
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: buzzerModes.asMap().entries.map((entry) {
          final index = entry.key;
          final (mode, title, subtitle, icon) = entry.value;
          final isSelected = _buzzerMode == mode;
          final isFirst = index == 0;
          final isLast = index == buzzerModes.length - 1;

          return Column(
            children: [
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: isFirst ? const Radius.circular(12) : Radius.zero,
                    bottom: isLast ? const Radius.circular(12) : Radius.zero,
                  ),
                ),
                leading: Icon(
                  icon,
                  color: isSelected
                      ? context.accentColor
                      : context.textSecondary,
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    color: isSelected
                        ? context.textPrimary
                        : context.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: context.accentColor)
                    : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _buzzerMode = mode);
                },
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 16,
                  color: context.border.withValues(alpha: 0.3),
                ),
            ],
          );
        }).toList(),
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
                        color: context.textPrimary,
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
          TextFormField(
            key: ValueKey('tzdef_$_tzdef'),
            initialValue: _tzdef,
            style: TextStyle(color: context.textPrimary),
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
        config_pbenum.Config_DeviceConfig_Role.CLIENT,
        'Client',
        'Standard messaging device',
        Icons.phone_android,
      ),
      (
        config_pbenum.Config_DeviceConfig_Role.CLIENT_MUTE,
        'Client Mute',
        'Does not forward packets',
        Icons.volume_off,
      ),
      (
        config_pbenum.Config_DeviceConfig_Role.CLIENT_HIDDEN,
        'Client Hidden',
        'Only speaks when spoken to',
        Icons.visibility_off,
      ),
      (
        config_pbenum.Config_DeviceConfig_Role.ROUTER,
        'Router',
        'Infrastructure node for extending coverage',
        Icons.router,
      ),
      (
        config_pbenum.Config_DeviceConfig_Role.ROUTER_CLIENT,
        'Router Client',
        'Router that also handles direct messages',
        Icons.device_hub,
      ),
      (
        config_pbenum.Config_DeviceConfig_Role.REPEATER,
        'Repeater',
        'Simple packet repeater (no encryption)',
        Icons.repeat,
      ),
      (
        config_pbenum.Config_DeviceConfig_Role.TRACKER,
        'Tracker',
        'GPS tracker with optimized position broadcasts',
        Icons.location_on,
      ),
      (
        config_pbenum.Config_DeviceConfig_Role.SENSOR,
        'Sensor',
        'Telemetry sensor node',
        Icons.sensors,
      ),
      (
        config_pbenum.Config_DeviceConfig_Role.TAK,
        'TAK',
        'Optimized for ATAK communication',
        Icons.military_tech,
      ),
      (
        config_pbenum.Config_DeviceConfig_Role.TAK_TRACKER,
        'TAK Tracker',
        'TAK with automatic position broadcasts',
        Icons.gps_fixed,
      ),
      (
        config_pbenum.Config_DeviceConfig_Role.LOST_AND_FOUND,
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
                      color: isSelected ? context.accentColor : context.border,
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
                                    : context.textPrimary,
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
        config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
        'All',
        'Rebroadcast all observed messages',
      ),
      (
        config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL_SKIP_DECODING,
        'All (Skip Decoding)',
        'Rebroadcast without decoding',
      ),
      (
        config_pbenum.Config_DeviceConfig_RebroadcastMode.LOCAL_ONLY,
        'Local Only',
        'Only rebroadcast local channel messages',
      ),
      (
        config_pbenum.Config_DeviceConfig_RebroadcastMode.KNOWN_ONLY,
        'Known Only',
        'Only rebroadcast from known nodes',
      ),
      (
        config_pbenum.Config_DeviceConfig_RebroadcastMode.NONE,
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
                                  ? context.textPrimary
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

  /// Broadcast interval options matching the official Meshtastic iOS app.
  /// Minimum is 3 hours (10 800 s); "Never" disables broadcasts.
  static const List<({int seconds, String label})> _broadcastIntervals = [
    (seconds: 10800, label: 'Three Hours'),
    (seconds: 14400, label: 'Four Hours'),
    (seconds: 18000, label: 'Five Hours'),
    (seconds: 21600, label: 'Six Hours'),
    (seconds: 43200, label: 'Twelve Hours'),
    (seconds: 64800, label: 'Eighteen Hours'),
    (seconds: 86400, label: 'Twenty Four Hours'),
    (seconds: 129600, label: 'Thirty Six Hours'),
    (seconds: 172800, label: 'Forty Eight Hours'),
    (seconds: 259200, label: 'Seventy Two Hours'),
    (seconds: 0, label: 'Never'),
  ];

  /// Returns the display label for the current broadcast interval,
  /// snapping legacy values to the nearest valid option.
  String _broadcastIntervalLabel(int seconds) {
    for (final option in _broadcastIntervals) {
      if (option.seconds == seconds) return option.label;
    }
    // Legacy value — snap to nearest
    final snapped = _snapToNearestInterval(seconds);
    for (final option in _broadcastIntervals) {
      if (option.seconds == snapped) return option.label;
    }
    return 'Three Hours';
  }

  int _snapToNearestInterval(int seconds) {
    if (seconds == 0) return 0;
    int closest = _broadcastIntervals.first.seconds;
    int closestDiff = (seconds - closest).abs();
    for (final option in _broadcastIntervals) {
      if (option.seconds == 0) continue;
      final diff = (seconds - option.seconds).abs();
      if (diff < closestDiff) {
        closest = option.seconds;
        closestDiff = diff;
      }
    }
    return closest;
  }

  Widget _buildNodeInfoBroadcastTile() {
    return _SettingsTile(
      icon: Icons.broadcast_on_personal,
      iconColor: _nodeInfoBroadcastSecs > 0 ? context.accentColor : null,
      title: 'Node Info Broadcast',
      subtitle: 'How often to broadcast device info',
      trailing: GestureDetector(
        onTap: _showBroadcastIntervalPicker,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _broadcastIntervalLabel(_nodeInfoBroadcastSecs),
              style: TextStyle(
                color: context.accentColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: context.textTertiary, size: 20),
          ],
        ),
      ),
      onTap: _showBroadcastIntervalPicker,
    );
  }

  void _showBroadcastIntervalPicker() {
    final effectiveValue = _snapToNearestInterval(_nodeInfoBroadcastSecs);
    showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Broadcast Interval',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'How often to broadcast node info to the mesh',
                style: TextStyle(fontSize: 13, color: context.textSecondary),
              ),
              const SizedBox(height: 12),
              ..._broadcastIntervals.map((option) {
                final isSelected = effectiveValue == option.seconds;
                return ListTile(
                  title: Text(
                    option.label,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? context.textPrimary
                          : context.textSecondary,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: context.accentColor, size: 20)
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext, option.seconds);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ).then((value) {
      if (value != null && mounted) {
        setState(() => _nodeInfoBroadcastSecs = value);
      }
    });
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
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.bodySmallStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: onTap != null
          ? Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: content,
              ),
            )
          : content,
    );
  }
}
