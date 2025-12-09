import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../utils/snackbar.dart';
import '../../providers/app_providers.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;
import '../../generated/meshtastic/mesh.pbenum.dart' as pbenum;

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
  pbenum.ModuleConfig_DetectionSensorConfig_TriggerType _triggerType =
      pbenum.ModuleConfig_DetectionSensorConfig_TriggerType.LOGIC_HIGH;

  bool _isSaving = false;
  bool _isLoading = true;

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
    final protocol = ref.read(protocolServiceProvider);

    // Only request from device if connected
    if (!protocol.isConnected) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final config = await protocol.getDetectionSensorModuleConfig();
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
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);

      // Create the detection sensor config
      final dsConfig = pb.ModuleConfig_DetectionSensorConfig()
        ..enabled = _enabled
        ..name = _name
        ..monitorPin = _monitorPin
        ..minimumBroadcastSecs = _minimumBroadcastSecs
        ..stateBroadcastSecs = _stateBroadcastSecs
        ..sendBell = _sendBell
        ..usePullup = _usePullup
        ..detectionTriggerType = _triggerType;

      final moduleConfig = pb.ModuleConfig()..detectionSensor = dsConfig;
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
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Detection Sensor'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveConfig,
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Save', style: TextStyle(color: context.accentColor)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                ],
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textTertiary,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detection Sensor',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monitor a GPIO pin and broadcast state changes to the mesh. '
                  'Use with PIR motion sensors, door/window contacts, or other binary sensors.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
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
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Enable Detection Sensor',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Monitor GPIO pin and broadcast state changes',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            ),
            trailing: ThemedSwitch(
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ),
          if (_enabled) ...[
            const Divider(height: 1, color: AppTheme.darkBorder),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Sensor Name',
                  labelStyle: const TextStyle(color: AppTheme.textSecondary),
                  hintText: 'e.g., Front Door, Motion Sensor',
                  hintStyle: TextStyle(
                    color: AppTheme.textTertiary.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: AppTheme.darkBackground,
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
        color: AppTheme.darkCard,
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
                      const Text(
                        'GPIO Pin',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The GPIO pin number to monitor',
                        style: TextStyle(
                          color: AppTheme.textTertiary,
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
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: AppTheme.textTertiary.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: AppTheme.darkBackground,
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
          const Divider(height: 1, color: AppTheme.darkBorder),
          ListTile(
            title: const Text(
              'Trigger Type',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              _getTriggerTypeDescription(_triggerType),
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(
              Icons.keyboard_arrow_down,
              color: AppTheme.textSecondary,
            ),
            onTap: () => _showTriggerTypePicker(),
          ),
          const Divider(height: 1, color: AppTheme.darkBorder),
          ListTile(
            title: const Text(
              'Use Internal Pullup',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Enable internal pullup resistor on the pin',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            ),
            trailing: ThemedSwitch(
              value: _usePullup,
              onChanged: (v) => setState(() => _usePullup = v),
            ),
          ),
          const Divider(height: 1, color: AppTheme.darkBorder),
          ListTile(
            title: const Text(
              'Send Bell Character',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Send bell (\\a) in detection messages',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
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
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Minimum Broadcast Interval',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Wait $_minimumBroadcastSecs seconds between broadcasts',
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: AppTheme.textSecondary),
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
                  icon: const Icon(Icons.add, color: AppTheme.textSecondary),
                  onPressed: _minimumBroadcastSecs < 300
                      ? () => setState(() => _minimumBroadcastSecs += 15)
                      : null,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.darkBorder),
          ListTile(
            title: const Text(
              'State Broadcast Interval',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Broadcast current state every ${_stateBroadcastSecs ~/ 60} minutes',
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: AppTheme.textSecondary),
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
                  icon: const Icon(Icons.add, color: AppTheme.textSecondary),
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

  String _getTriggerTypeDescription(
    pbenum.ModuleConfig_DetectionSensorConfig_TriggerType type,
  ) {
    switch (type) {
      case pbenum.ModuleConfig_DetectionSensorConfig_TriggerType.LOGIC_LOW:
        return 'Logic Low (active when pin is LOW)';
      case pbenum.ModuleConfig_DetectionSensorConfig_TriggerType.LOGIC_HIGH:
        return 'Logic High (active when pin is HIGH)';
      case pbenum.ModuleConfig_DetectionSensorConfig_TriggerType.FALLING_EDGE:
        return 'Falling Edge (trigger on HIGH→LOW)';
      case pbenum.ModuleConfig_DetectionSensorConfig_TriggerType.RISING_EDGE:
        return 'Rising Edge (trigger on LOW→HIGH)';
      case pbenum
          .ModuleConfig_DetectionSensorConfig_TriggerType
          .EITHER_EDGE_ACTIVE_LOW:
        return 'Either Edge (active LOW)';
      case pbenum
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
      backgroundColor: AppTheme.darkSurface,
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
                  const Text(
                    'Trigger Type',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.darkBorder),
            ...pbenum.ModuleConfig_DetectionSensorConfig_TriggerType.values.map(
              (type) {
                return ListTile(
                  title: Text(
                    _getTriggerTypeDescription(type),
                    style: TextStyle(
                      color: _triggerType == type
                          ? context.accentColor
                          : Colors.white,
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
              },
            ),
          ],
        ),
      ),
    );
  }
}
