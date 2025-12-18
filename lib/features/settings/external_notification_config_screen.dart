import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../providers/app_providers.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;

/// Screen for configuring External Notification module (buzzers, LEDs, vibration)
class ExternalNotificationConfigScreen extends ConsumerStatefulWidget {
  const ExternalNotificationConfigScreen({super.key});

  @override
  ConsumerState<ExternalNotificationConfigScreen> createState() =>
      _ExternalNotificationConfigScreenState();
}

class _ExternalNotificationConfigScreenState
    extends ConsumerState<ExternalNotificationConfigScreen> {
  // Core settings
  bool _enabled = false;
  bool _alertBell = false;
  bool _alertMessage = false;
  bool _usePwm = false;
  bool _useI2sAsBuzzer = false;

  // Primary GPIO settings
  bool _active = false;
  int _output = 0;
  int _outputMs = 0;
  int _nagTimeout = 0;

  // Optional GPIO settings
  bool _alertBellBuzzer = false;
  bool _alertBellVibra = false;
  bool _alertMessageBuzzer = false;
  bool _alertMessageVibra = false;
  int _outputBuzzer = 0;
  int _outputVibra = 0;

  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final protocol = ref.read(protocolServiceProvider);

    // Only request from device if connected
    if (!protocol.isConnected) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final config = await protocol.getExternalNotificationModuleConfig();
    if (config != null && mounted) {
      setState(() {
        _enabled = config.enabled;
        _alertBell = config.alertBell;
        _alertMessage = config.alertMessage;
        _usePwm = config.usePwm;
        _useI2sAsBuzzer = config.useI2sAsBuzzer;
        _active = config.active;
        _output = config.output;
        _outputMs = config.outputMs;
        _nagTimeout = config.nagTimeout;
        _alertBellBuzzer = config.alertBellBuzzer;
        _alertBellVibra = config.alertBellVibra;
        _alertMessageBuzzer = config.alertMessageBuzzer;
        _alertMessageVibra = config.alertMessageVibra;
        _outputBuzzer = config.outputBuzzer;
        _outputVibra = config.outputVibra;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);

      // Create the external notification config
      final extNotifConfig = pb.ModuleConfig_ExternalNotificationConfig()
        ..enabled = _enabled
        ..alertBell = _alertBell
        ..alertMessage = _alertMessage
        ..usePwm = _usePwm
        ..useI2sAsBuzzer = _useI2sAsBuzzer
        ..active = _active
        ..output = _output
        ..outputMs = _outputMs
        ..nagTimeout = _nagTimeout
        ..alertBellBuzzer = _alertBellBuzzer
        ..alertBellVibra = _alertBellVibra
        ..alertMessageBuzzer = _alertMessageBuzzer
        ..alertMessageVibra = _alertMessageVibra
        ..outputBuzzer = _outputBuzzer
        ..outputVibra = _outputVibra;

      final moduleConfig = pb.ModuleConfig()
        ..externalNotification = extNotifConfig;

      await protocol.setModuleConfig(moduleConfig);

      if (mounted) {
        showSuccessSnackBar(context, 'External notification settings saved');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final protocol = ref.watch(protocolServiceProvider);
    final isConnected = protocol.isConnected;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('External Notification'),
        backgroundColor: AppTheme.darkSurface,
        actions: [
          if (isConnected)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveConfig,
            ),
        ],
      ),
      body: _isLoading
          ? const ScreenLoadingIndicator()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!isConnected)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.warningYellow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.warningYellow.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: AppTheme.warningYellow),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Connect to a device to configure external notification settings',
                          ),
                        ),
                      ],
                    ),
                  ),

                // Options Section
                _buildSectionHeader(context, 'Options'),
                _buildCard([
                  _buildSwitch(
                    context,
                    title: 'Enabled',
                    subtitle: 'Enable external notification module',
                    value: _enabled,
                    icon: Icons.notifications_active,
                    onChanged: isConnected
                        ? (v) => setState(() => _enabled = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildSwitch(
                    context,
                    title: 'Alert on Bell',
                    subtitle:
                        'Trigger notification when receiving a bell character',
                    value: _alertBell,
                    icon: Icons.notifications,
                    onChanged: isConnected
                        ? (v) => setState(() => _alertBell = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildSwitch(
                    context,
                    title: 'Alert on Message',
                    subtitle: 'Trigger notification when receiving a message',
                    value: _alertMessage,
                    icon: Icons.message,
                    onChanged: isConnected
                        ? (v) => setState(() => _alertMessage = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildSwitch(
                    context,
                    title: 'Use PWM Buzzer',
                    subtitle: 'Use PWM output for tunes instead of on/off',
                    value: _usePwm,
                    icon: Icons.music_note,
                    onChanged: isConnected
                        ? (v) => setState(() => _usePwm = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildSwitch(
                    context,
                    title: 'Use I2S as Buzzer',
                    subtitle:
                        'Use I2S audio output for RTTTL tunes (T-Watch, T-Deck)',
                    value: _useI2sAsBuzzer,
                    icon: Icons.speaker,
                    onChanged: isConnected
                        ? (v) => setState(() => _useI2sAsBuzzer = v)
                        : null,
                  ),
                ]),

                const SizedBox(height: 24),

                // Primary GPIO Section
                _buildSectionHeader(context, 'Primary GPIO'),
                _buildCard([
                  _buildSwitch(
                    context,
                    title: 'Active High',
                    subtitle: 'Output pin is pulled high when active',
                    value: _active,
                    icon: Icons.power,
                    onChanged: isConnected
                        ? (v) => setState(() => _active = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildGpioPicker(
                    context,
                    title: 'Output GPIO Pin',
                    value: _output,
                    onChanged: isConnected
                        ? (v) => setState(() => _output = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildDurationPicker(
                    context,
                    title: 'Output Duration',
                    subtitle: 'How long to keep output active',
                    valueMs: _outputMs,
                    onChanged: isConnected
                        ? (v) => setState(() => _outputMs = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildNagTimeoutPicker(
                    context,
                    title: 'Nag Timeout',
                    subtitle: 'How often to repeat notification',
                    valueSecs: _nagTimeout,
                    onChanged: isConnected
                        ? (v) => setState(() => _nagTimeout = v)
                        : null,
                  ),
                ]),

                const SizedBox(height: 24),

                // Optional GPIO Section
                _buildSectionHeader(context, 'Optional GPIO'),
                _buildCard([
                  _buildSwitch(
                    context,
                    title: 'Buzzer on Bell',
                    subtitle: 'Alert buzzer GPIO when receiving a bell',
                    value: _alertBellBuzzer,
                    icon: Icons.volume_up,
                    onChanged: isConnected
                        ? (v) => setState(() => _alertBellBuzzer = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildSwitch(
                    context,
                    title: 'Vibra on Bell',
                    subtitle: 'Alert vibration motor when receiving a bell',
                    value: _alertBellVibra,
                    icon: Icons.vibration,
                    onChanged: isConnected
                        ? (v) => setState(() => _alertBellVibra = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildSwitch(
                    context,
                    title: 'Buzzer on Message',
                    subtitle: 'Alert buzzer GPIO when receiving a message',
                    value: _alertMessageBuzzer,
                    icon: Icons.volume_up,
                    onChanged: isConnected
                        ? (v) => setState(() => _alertMessageBuzzer = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildSwitch(
                    context,
                    title: 'Vibra on Message',
                    subtitle: 'Alert vibration motor when receiving a message',
                    value: _alertMessageVibra,
                    icon: Icons.vibration,
                    onChanged: isConnected
                        ? (v) => setState(() => _alertMessageVibra = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildGpioPicker(
                    context,
                    title: 'Buzzer GPIO Pin',
                    value: _outputBuzzer,
                    onChanged: isConnected
                        ? (v) => setState(() => _outputBuzzer = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildGpioPicker(
                    context,
                    title: 'Vibra GPIO Pin',
                    value: _outputVibra,
                    onChanged: isConnected
                        ? (v) => setState(() => _outputVibra = v)
                        : null,
                  ),
                ]),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: context.accentColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 56, color: AppTheme.darkBorder);
  }

  Widget _buildSwitch(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      secondary: Icon(icon, color: context.accentColor),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildGpioPicker(
    BuildContext context, {
    required String title,
    required int value,
    required ValueChanged<int>? onChanged,
  }) {
    return ListTile(
      leading: Icon(Icons.memory, color: context.accentColor),
      title: Text(title),
      subtitle: Text(
        value == 0 ? 'Unset' : 'GPIO $value',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
      trailing: DropdownButton<int>(
        value: value,
        underline: const SizedBox(),
        items: List.generate(49, (i) => i).map((pin) {
          return DropdownMenuItem<int>(
            value: pin,
            child: Text(pin == 0 ? 'Unset' : 'Pin $pin'),
          );
        }).toList(),
        onChanged: onChanged == null ? null : (v) => onChanged(v ?? 0),
      ),
    );
  }

  Widget _buildDurationPicker(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int valueMs,
    required ValueChanged<int>? onChanged,
  }) {
    final durations = [
      (0, 'Default'),
      (100, '100ms'),
      (250, '250ms'),
      (500, '500ms'),
      (1000, '1 second'),
      (2000, '2 seconds'),
      (5000, '5 seconds'),
    ];

    return ListTile(
      leading: Icon(Icons.timer, color: context.accentColor),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      trailing: DropdownButton<int>(
        value: durations.any((d) => d.$1 == valueMs) ? valueMs : 0,
        underline: const SizedBox(),
        items: durations.map((d) {
          return DropdownMenuItem<int>(value: d.$1, child: Text(d.$2));
        }).toList(),
        onChanged: onChanged == null ? null : (v) => onChanged(v ?? 0),
      ),
    );
  }

  Widget _buildNagTimeoutPicker(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int valueSecs,
    required ValueChanged<int>? onChanged,
  }) {
    final timeouts = [
      (0, 'Disabled'),
      (15, '15 seconds'),
      (30, '30 seconds'),
      (60, '1 minute'),
      (120, '2 minutes'),
      (300, '5 minutes'),
      (600, '10 minutes'),
    ];

    return ListTile(
      leading: Icon(Icons.repeat, color: context.accentColor),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      trailing: DropdownButton<int>(
        value: timeouts.any((t) => t.$1 == valueSecs) ? valueSecs : 0,
        underline: const SizedBox(),
        items: timeouts.map((t) {
          return DropdownMenuItem<int>(value: t.$1, child: Text(t.$2));
        }).toList(),
        onChanged: onChanged == null ? null : (v) => onChanged(v ?? 0),
      ),
    );
  }
}
