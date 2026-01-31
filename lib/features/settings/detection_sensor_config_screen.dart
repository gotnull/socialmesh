import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../providers/app_providers.dart';
import '../../generated/meshtastic/module_config.pb.dart' as module_pb;
import '../../generated/meshtastic/module_config.pbenum.dart' as module_pbenum;
import '../../core/widgets/loading_indicator.dart';

/// Screen for configuring Detection Sensor module
class DetectionSensorConfigScreen extends ConsumerStatefulWidget {
  const DetectionSensorConfigScreen({super.key});

  @override
  ConsumerState<DetectionSensorConfigScreen> createState() =>
      _DetectionSensorConfigScreenState();
}

class _DetectionSensorConfigScreenState
    extends ConsumerState<DetectionSensorConfigScreen> {
  bool _enabled = false;
  String _name = '';
  int _monitorPin = 0;
  int _minimumBroadcastSecs = 45;
  int _stateBroadcastSecs = 300;
  bool _sendBell = false;
  bool _usePullup = false;
  module_pbenum.ModuleConfig_DetectionSensorConfig_TriggerType _triggerType =
      module_pbenum.ModuleConfig_DetectionSensorConfig_TriggerType.LOGIC_HIGH;

  bool _isSaving = false;
  bool _isLoading = true;
  bool _notificationsEnabled = false; // App-side notification preference

  final _nameController = TextEditingController();
  final _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    AppLogging.settings('[DetectionSensor] Loading config...');
    final protocol = ref.read(protocolServiceProvider);

    // Load app-side notification preference
    final prefs = await SharedPreferences.getInstance();
    final notifEnabled = prefs.getBool('enableDetectionNotifications') ?? false;
    if (mounted) {
      setState(() => _notificationsEnabled = notifEnabled);
    }

    // Only request from device if connected
    if (!protocol.isConnected) {
      AppLogging.settings('[DetectionSensor] Not connected, skipping load');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    AppLogging.settings('[DetectionSensor] Requesting config from device');
    try {
      final config = await protocol.getDetectionSensorModuleConfig().timeout(
        const Duration(seconds: 10),
      );
      AppLogging.settings('[DetectionSensor] Config received: $config');
      if (config != null && mounted) {
        setState(() {
          _enabled = config.enabled;
          _name = config.name;
          _monitorPin = config.monitorPin;
          _minimumBroadcastSecs = config.minimumBroadcastSecs > 0
              ? config.minimumBroadcastSecs
              : 45;
          _stateBroadcastSecs = config.stateBroadcastSecs > 0
              ? config.stateBroadcastSecs
              : 300;
          _sendBell = config.sendBell;
          _usePullup = config.usePullup;
          _triggerType = config.detectionTriggerType;
          _nameController.text = _name;
          _pinController.text = _monitorPin.toString();
          _isLoading = false;
        });
        AppLogging.settings('[DetectionSensor] Config loaded successfully');
      } else if (mounted) {
        AppLogging.settings('[DetectionSensor] Config was null');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogging.settings('[DetectionSensor] Error loading config: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnackBar(context, 'Failed to load config');
      }
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);

      // Create the detection sensor config
      final dsConfig = module_pb.ModuleConfig_DetectionSensorConfig()
        ..enabled = _enabled
        ..name = _name
        ..monitorPin = _monitorPin
        ..minimumBroadcastSecs = _minimumBroadcastSecs
        ..stateBroadcastSecs = _stateBroadcastSecs
        ..sendBell = _sendBell
        ..usePullup = _usePullup
        ..detectionTriggerType = _triggerType;

      final moduleConfig = module_pb.ModuleConfig()..detectionSensor = dsConfig;
      await protocol.setModuleConfig(moduleConfig);

      if (mounted) {
        showSuccessSnackBar(context, 'Detection Sensor configuration saved');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save config: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Detection Sensor',
      actions: [
        TextButton(
          onPressed: _isSaving ? null : _saveConfig,
          child: _isSaving
              ? LoadingIndicator(size: 20)
              : Text('Save', style: TextStyle(color: context.accentColor)),
        ),
      ],
      slivers: [
        if (_isLoading)
          const SliverFillRemaining(child: ScreenLoadingIndicator())
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Info card
                _buildInfoCard(),

                const SizedBox(height: 16),

                // Basic settings
                _buildSectionTitle('Basic Settings'),
                _buildBasicSettingsCard(),

                const SizedBox(height: 16),

                // Pin configuration (only shown if enabled)
                if (_enabled) ...[
                  _buildSectionTitle('Pin Configuration'),
                  _buildPinConfigCard(),

                  const SizedBox(height: 16),

                  // Timing settings
                  _buildSectionTitle('Timing'),
                  _buildTimingCard(),

                  const SizedBox(height: 16),

                  // Client options (app-side settings)
                  _buildSectionTitle('Client Options'),
                  _buildClientOptionsCard(),
                ],
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.textTertiary,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sensors, color: AppTheme.accentOrange, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detection Sensor',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monitor a GPIO pin and broadcast state changes to the mesh. '
                  'Use with PIR motion sensors, door/window contacts, or other binary sensors.',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Enable Detection Sensor',
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              'Monitor GPIO pin and broadcast state changes',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: ThemedSwitch(
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ),
          if (_enabled) ...[
            Divider(height: 1, color: context.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _nameController,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Sensor Name',
                  labelStyle: TextStyle(color: context.textSecondary),
                  hintText: 'e.g., Front Door, Motion Sensor',
                  hintStyle: TextStyle(
                    color: context.textTertiary.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: context.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (v) => _name = v,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPinConfigCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GPIO Pin',
                        style: TextStyle(color: context.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'The GPIO pin number to monitor',
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _pinController,
                    style: TextStyle(color: context.textPrimary),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: context.textTertiary.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: context.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (v) => _monitorPin = int.tryParse(v) ?? 0,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.border),
          ListTile(
            title: Text(
              'Trigger Type',
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              _getTriggerTypeDescription(_triggerType),
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: Icon(
              Icons.keyboard_arrow_down,
              color: context.textSecondary,
            ),
            onTap: () => _showTriggerTypePicker(),
          ),
          Divider(height: 1, color: context.border),
          ListTile(
            title: Text(
              'Use Internal Pullup',
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              'Enable internal pullup resistor on the pin',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: ThemedSwitch(
              value: _usePullup,
              onChanged: (v) => setState(() => _usePullup = v),
            ),
          ),
          Divider(height: 1, color: context.border),
          ListTile(
            title: Text(
              'Send Bell Character',
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              'Send bell (\\a) in detection messages',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: ThemedSwitch(
              value: _sendBell,
              onChanged: (v) => setState(() => _sendBell = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Minimum Broadcast Interval',
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              'Wait $_minimumBroadcastSecs seconds between broadcasts',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: context.textSecondary),
                  onPressed: _minimumBroadcastSecs > 15
                      ? () => setState(() => _minimumBroadcastSecs -= 15)
                      : null,
                ),
                Text(
                  '${_minimumBroadcastSecs}s',
                  style: TextStyle(
                    color: context.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: context.textSecondary),
                  onPressed: _minimumBroadcastSecs < 300
                      ? () => setState(() => _minimumBroadcastSecs += 15)
                      : null,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.border),
          ListTile(
            title: Text(
              'State Broadcast Interval',
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              'Broadcast current state every ${_stateBroadcastSecs ~/ 60} minutes',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: context.textSecondary),
                  onPressed: _stateBroadcastSecs > 60
                      ? () => setState(() => _stateBroadcastSecs -= 60)
                      : null,
                ),
                Text(
                  '${_stateBroadcastSecs ~/ 60}m',
                  style: TextStyle(
                    color: context.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: context.textSecondary),
                  onPressed: _stateBroadcastSecs < 1800
                      ? () => setState(() => _stateBroadcastSecs += 60)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.notifications_active,
              color: _notificationsEnabled
                  ? context.accentColor
                  : context.textSecondary,
            ),
            title: Text(
              'Enable Notifications',
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              'Show notifications when sensor events are received',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: ThemedSwitch(
              value: _notificationsEnabled,
              onChanged: (value) async {
                setState(() => _notificationsEnabled = value);
                // Save preference immediately
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('enableDetectionNotifications', value);
                AppLogging.settings(
                  '[DetectionSensor] Notifications ${value ? "enabled" : "disabled"}',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getTriggerTypeDescription(
    module_pbenum.ModuleConfig_DetectionSensorConfig_TriggerType type,
  ) {
    switch (type) {
      case module_pbenum
          .ModuleConfig_DetectionSensorConfig_TriggerType
          .LOGIC_LOW:
        return 'Logic Low (active when pin is LOW)';
      case module_pbenum
          .ModuleConfig_DetectionSensorConfig_TriggerType
          .LOGIC_HIGH:
        return 'Logic High (active when pin is HIGH)';
      case module_pbenum
          .ModuleConfig_DetectionSensorConfig_TriggerType
          .FALLING_EDGE:
        return 'Falling Edge (trigger on HIGH→LOW)';
      case module_pbenum
          .ModuleConfig_DetectionSensorConfig_TriggerType
          .RISING_EDGE:
        return 'Rising Edge (trigger on LOW→HIGH)';
      case module_pbenum
          .ModuleConfig_DetectionSensorConfig_TriggerType
          .EITHER_EDGE_ACTIVE_LOW:
        return 'Either Edge (active LOW)';
      case module_pbenum
          .ModuleConfig_DetectionSensorConfig_TriggerType
          .EITHER_EDGE_ACTIVE_HIGH:
        return 'Either Edge (active HIGH)';
      default:
        return 'Unknown';
    }
  }

  void _showTriggerTypePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Trigger Type',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: context.textTertiary),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.border),
            ...module_pbenum
                .ModuleConfig_DetectionSensorConfig_TriggerType
                .values
                .map((type) {
                  return ListTile(
                    title: Text(
                      _getTriggerTypeDescription(type),
                      style: TextStyle(
                        color: _triggerType == type
                            ? context.accentColor
                            : context.textPrimary,
                      ),
                    ),
                    trailing: _triggerType == type
                        ? Icon(Icons.check, color: context.accentColor)
                        : null,
                    onTap: () {
                      setState(() => _triggerType = type);
                      Navigator.pop(context);
                    },
                  );
                }),
          ],
        ),
      ),
    );
  }
}
