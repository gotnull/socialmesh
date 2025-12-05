import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/animations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/map_config.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../services/ifttt/ifttt_service.dart';
import 'geofence_picker_screen.dart';

/// Screen for configuring IFTTT Webhooks integration
class IftttConfigScreen extends ConsumerStatefulWidget {
  const IftttConfigScreen({super.key});

  @override
  ConsumerState<IftttConfigScreen> createState() => _IftttConfigScreenState();
}

class _IftttConfigScreenState extends ConsumerState<IftttConfigScreen> {
  final _webhookKeyController = TextEditingController();
  final _batteryThresholdController = TextEditingController();
  final _temperatureThresholdController = TextEditingController();
  final _geofenceRadiusController = TextEditingController();
  final _geofenceLatController = TextEditingController();
  final _geofenceLonController = TextEditingController();

  bool _enabled = false;
  bool _messageReceived = true;
  bool _nodeOnline = true;
  bool _nodeOffline = true;
  bool _positionUpdate = false;
  bool _batteryLow = true;
  bool _temperatureAlert = false;
  bool _sosEmergency = true;
  bool _isTesting = false;
  int? _geofenceNodeNum;
  String? _geofenceNodeName;
  int _geofenceThrottleMinutes = 30;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final iftttService = ref.read(iftttServiceProvider);
    final config = iftttService.config;

    _webhookKeyController.text = config.webhookKey;
    _batteryThresholdController.text = config.batteryThreshold.toString();
    _temperatureThresholdController.text = config.temperatureThreshold
        .toStringAsFixed(1);
    _geofenceRadiusController.text = config.geofenceRadius.toStringAsFixed(0);
    _geofenceLatController.text = config.geofenceLat?.toStringAsFixed(6) ?? '';
    _geofenceLonController.text = config.geofenceLon?.toStringAsFixed(6) ?? '';

    setState(() {
      _enabled = config.enabled;
      _messageReceived = config.messageReceived;
      _nodeOnline = config.nodeOnline;
      _nodeOffline = config.nodeOffline;
      _positionUpdate = config.positionUpdate;
      _batteryLow = config.batteryLow;
      _temperatureAlert = config.temperatureAlert;
      _sosEmergency = config.sosEmergency;
      _geofenceNodeNum = config.geofenceNodeNum;
      _geofenceNodeName = config.geofenceNodeName;
      _geofenceThrottleMinutes = config.geofenceThrottleMinutes;
    });
  }

  Future<void> _saveConfig() async {
    final iftttService = ref.read(iftttServiceProvider);

    final config = IftttConfig(
      enabled: _enabled,
      webhookKey: _webhookKeyController.text.trim(),
      messageReceived: _messageReceived,
      nodeOnline: _nodeOnline,
      nodeOffline: _nodeOffline,
      positionUpdate: _positionUpdate,
      batteryLow: _batteryLow,
      temperatureAlert: _temperatureAlert,
      sosEmergency: _sosEmergency,
      batteryThreshold: int.tryParse(_batteryThresholdController.text) ?? 20,
      temperatureThreshold:
          double.tryParse(_temperatureThresholdController.text) ?? 40.0,
      geofenceRadius: double.tryParse(_geofenceRadiusController.text) ?? 1000.0,
      geofenceLat: double.tryParse(_geofenceLatController.text),
      geofenceLon: double.tryParse(_geofenceLonController.text),
      geofenceNodeNum: _geofenceNodeNum,
      geofenceNodeName: _geofenceNodeName,
      geofenceThrottleMinutes: _geofenceThrottleMinutes,
    );

    await iftttService.saveConfig(config);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('IFTTT settings saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _testWebhook() async {
    if (_webhookKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your Webhook Key first'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isTesting = true);

    final iftttService = ref.read(iftttServiceProvider);
    final tempConfig = IftttConfig(
      enabled: true,
      webhookKey: _webhookKeyController.text.trim(),
      messageReceived: _messageReceived,
      nodeOnline: _nodeOnline,
      nodeOffline: _nodeOffline,
      positionUpdate: _positionUpdate,
      batteryLow: _batteryLow,
      temperatureAlert: _temperatureAlert,
      sosEmergency: _sosEmergency,
      batteryThreshold: int.tryParse(_batteryThresholdController.text) ?? 20,
      temperatureThreshold:
          double.tryParse(_temperatureThresholdController.text) ?? 40.0,
      geofenceRadius: double.tryParse(_geofenceRadiusController.text) ?? 1000.0,
      geofenceLat: double.tryParse(_geofenceLatController.text),
      geofenceLon: double.tryParse(_geofenceLonController.text),
      geofenceNodeNum: _geofenceNodeNum,
      geofenceNodeName: _geofenceNodeName,
      geofenceThrottleMinutes: _geofenceThrottleMinutes,
    );
    await iftttService.saveConfig(tempConfig);

    final success = await iftttService.testWebhook();

    setState(() => _isTesting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Test webhook sent! Check your IFTTT applet.'
                : 'Failed to send test webhook. Check your key.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success ? context.accentColor : AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  void dispose() {
    _webhookKeyController.dispose();
    _batteryThresholdController.dispose();
    _temperatureThresholdController.dispose();
    _geofenceRadiusController.dispose();
    _geofenceLatController.dispose();
    _geofenceLonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
          title: const Text('IFTTT Integration'),
          actions: [
            TextButton(onPressed: _saveConfig, child: const Text('Save')),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _buildEnableTile(),
            if (_enabled) ...[
              const SizedBox(height: 16),
              const _SectionHeader(title: 'WEBHOOK'),
              _buildWebhookSection(),
              const SizedBox(height: 16),
              const _SectionHeader(title: 'MESSAGE TRIGGERS'),
              _buildMessageTriggers(),
              const SizedBox(height: 16),
              const _SectionHeader(title: 'NODE STATUS TRIGGERS'),
              _buildNodeTriggers(),
              const SizedBox(height: 16),
              const _SectionHeader(title: 'TELEMETRY TRIGGERS'),
              _buildTelemetryTriggers(),
              const SizedBox(height: 16),
              const _SectionHeader(title: 'GEOFENCING'),
              _buildGeofenceSettings(),
            ],
            const SizedBox(height: 16),
            _buildInfoCard(),
            const SizedBox(height: 8),
            _buildEventNamesCard(),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildEnableTile() {
    return _SettingsTile(
      icon: Icons.webhook,
      iconColor: _enabled ? context.accentColor : null,
      title: 'Enable IFTTT',
      subtitle: 'Send events to IFTTT Webhooks service',
      trailing: ThemedSwitch(
        value: _enabled,
        onChanged: (value) {
          HapticFeedback.selectionClick();
          setState(() => _enabled = value);
        },
      ),
    );
  }

  Widget _buildWebhookSection() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _webhookKeyController,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Webhook Key',
                  labelStyle: const TextStyle(color: AppTheme.textSecondary),
                  hintText: 'e.g., cMcOnB_zaJTrZwsVvzVTHY',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  helperText: 'Copy from IFTTT Webhooks URL after /use/',
                  helperStyle: const TextStyle(color: AppTheme.textTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.darkBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.darkBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.accentColor),
                  ),
                  prefixIcon: const Icon(
                    Icons.key,
                    color: AppTheme.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppTheme.darkBackground,
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isTesting ? null : _testWebhook,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.accentColor.withAlpha(30),
                    foregroundColor: context.accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: _isTesting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.accentColor,
                          ),
                        )
                      : const Icon(Icons.send, size: 18),
                  label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageTriggers() {
    return Column(
      children: [
        _SettingsTile(
          icon: Icons.message_outlined,
          title: 'Message Received',
          subtitle: 'Trigger when a message is received',
          trailing: ThemedSwitch(
            value: _messageReceived,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _messageReceived = value);
            },
          ),
        ),
        _SettingsTile(
          icon: Icons.sos_outlined,
          title: 'SOS / Emergency',
          subtitle: 'Trigger on SOS, emergency, help, mayday keywords',
          trailing: ThemedSwitch(
            value: _sosEmergency,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _sosEmergency = value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNodeTriggers() {
    return Column(
      children: [
        _SettingsTile(
          icon: Icons.wifi_tethering,
          title: 'Node Online',
          subtitle: 'Trigger when a node comes online',
          trailing: ThemedSwitch(
            value: _nodeOnline,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _nodeOnline = value);
            },
          ),
        ),
        _SettingsTile(
          icon: Icons.wifi_off_outlined,
          title: 'Node Offline',
          subtitle: 'Trigger when a node goes offline',
          trailing: ThemedSwitch(
            value: _nodeOffline,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _nodeOffline = value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryTriggers() {
    return Column(
      children: [
        _SettingsTile(
          icon: Icons.battery_3_bar,
          title: 'Battery Low',
          subtitle: 'Trigger when battery drops below threshold',
          trailing: ThemedSwitch(
            value: _batteryLow,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _batteryLow = value);
            },
          ),
        ),
        if (_batteryLow)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _batteryThresholdController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Battery Threshold',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                hintText: '20',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.accentColor),
                ),
                prefixIcon: const Icon(
                  Icons.battery_3_bar,
                  color: AppTheme.textSecondary,
                ),
                suffixText: '%',
                suffixStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.darkBackground,
              ),
            ),
          ),
        _SettingsTile(
          icon: Icons.device_thermostat,
          title: 'Temperature Alert',
          subtitle: 'Trigger when temperature exceeds threshold',
          trailing: ThemedSwitch(
            value: _temperatureAlert,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _temperatureAlert = value);
            },
          ),
        ),
        if (_temperatureAlert)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _temperatureThresholdController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Temperature Threshold',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                hintText: '40.0',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.accentColor),
                ),
                prefixIcon: const Icon(
                  Icons.device_thermostat,
                  color: AppTheme.textSecondary,
                ),
                suffixText: '°C',
                suffixStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.darkBackground,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGeofenceSettings() {
    return Column(
      children: [
        _SettingsTile(
          icon: Icons.radar,
          title: 'Position Updates',
          subtitle: 'Trigger when node exits geofence area',
          trailing: ThemedSwitch(
            value: _positionUpdate,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _positionUpdate = value);
            },
          ),
        ),
        if (_positionUpdate)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _geofenceRadiusController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Geofence Radius',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    hintText: '1000',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.darkBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.darkBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: context.accentColor,
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.radar,
                      color: AppTheme.textSecondary,
                    ),
                    suffixText: 'm',
                    suffixStyle: const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.darkBackground,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _geofenceLatController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Center Latitude',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    hintText: '-33.8688',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.darkBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.darkBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: context.accentColor,
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.my_location,
                      color: AppTheme.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppTheme.darkBackground,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _geofenceLonController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Center Longitude',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    hintText: '151.2093',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.darkBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.darkBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: context.accentColor,
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.my_location,
                      color: AppTheme.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppTheme.darkBackground,
                  ),
                ),
                const SizedBox(height: 16),
                // Mini map preview when coordinates are set
                Builder(
                  builder: (context) {
                    final lat = double.tryParse(_geofenceLatController.text);
                    final lon = double.tryParse(_geofenceLonController.text);
                    final radius =
                        double.tryParse(_geofenceRadiusController.text) ??
                        1000.0;

                    if (lat != null && lon != null) {
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 150,
                              child: IgnorePointer(
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: LatLng(lat, lon),
                                    initialZoom: _calculateZoomForRadius(
                                      radius,
                                    ),
                                  ),
                                  children: [
                                    MapConfig.darkTileLayer(),
                                    CircleLayer(
                                      circles: [
                                        CircleMarker(
                                          point: LatLng(lat, lon),
                                          radius: radius,
                                          useRadiusInMeter: true,
                                          color: context.accentColor
                                              .withAlpha(40),
                                          borderColor: context.accentColor,
                                          borderStrokeWidth: 2,
                                        ),
                                      ],
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: LatLng(lat, lon),
                                          width: 24,
                                          height: 24,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: context.accentColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.location_on,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                // Monitored node indicator
                if (_geofenceNodeNum != null && _geofenceNodeName != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.accentColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: context.accentColor.withAlpha(50),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.radar,
                          color: context.accentColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Monitored Node',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _geofenceNodeName!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          color: AppTheme.textTertiary,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() {
                            _geofenceNodeNum = null;
                            _geofenceNodeName = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warningYellow.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.warningYellow.withAlpha(50),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.warningYellow,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'No node selected. All nodes will be monitored.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Throttle setting
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Alert Cooldown',
                        style: TextStyle(fontSize: 14, color: Colors.white),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: DropdownButton<int>(
                        value: _geofenceThrottleMinutes,
                        dropdownColor: AppTheme.darkCard,
                        underline: const SizedBox.shrink(),
                        isDense: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5 min')),
                          DropdownMenuItem(value: 15, child: Text('15 min')),
                          DropdownMenuItem(value: 30, child: Text('30 min')),
                          DropdownMenuItem(value: 60, child: Text('1 hour')),
                          DropdownMenuItem(value: 120, child: Text('2 hours')),
                          DropdownMenuItem(value: 240, child: Text('4 hours')),
                          DropdownMenuItem(value: 480, child: Text('8 hours')),
                          DropdownMenuItem(
                            value: 1440,
                            child: Text('24 hours'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _geofenceThrottleMinutes = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Minimum time between geofence alerts for the same node',
                  style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                ),
                SizedBox(height: 16),
                // Pick on Map button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openGeofencePicker,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.accentColor,
                      side: BorderSide(
                        color: context.accentColor.withAlpha(100),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Pick on Map'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Calculate appropriate zoom level for a given radius
  double _calculateZoomForRadius(double radiusMeters) {
    // Approximate zoom levels for different radii
    if (radiusMeters <= 100) return 17;
    if (radiusMeters <= 250) return 16;
    if (radiusMeters <= 500) return 15;
    if (radiusMeters <= 1000) return 14;
    if (radiusMeters <= 2000) return 13;
    if (radiusMeters <= 5000) return 12;
    if (radiusMeters <= 10000) return 11;
    return 10;
  }

  Future<void> _openGeofencePicker() async {
    final result = await Navigator.of(context).push<GeofenceResult>(
      MaterialPageRoute(
        builder: (context) => GeofencePickerScreen(
          initialLat: double.tryParse(_geofenceLatController.text),
          initialLon: double.tryParse(_geofenceLonController.text),
          initialRadius:
              double.tryParse(_geofenceRadiusController.text) ?? 1000.0,
          initialMonitoredNodeNum: _geofenceNodeNum,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _geofenceLatController.text = result.latitude.toStringAsFixed(6);
        _geofenceLonController.text = result.longitude.toStringAsFixed(6);
        _geofenceRadiusController.text = result.radiusMeters.toStringAsFixed(0);
        _geofenceNodeNum = result.monitoredNodeNum;
        _geofenceNodeName = result.monitoredNodeName;
      });
    }
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.accentColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.accentColor.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: context.accentColor, size: 20),
              SizedBox(width: 12),
              Text(
                'Setup Guide',
                style: TextStyle(
                  color: context.accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStep('1', 'Create an account at ifttt.com'),
          _buildStep('2', 'Search for "Webhooks" service and connect it'),
          _buildStep('3', 'Go to Webhooks settings to find your key'),
          _buildStep('4', 'Create applets with Webhooks as the trigger'),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: context.accentColor.withAlpha(50),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: context.accentColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventNamesCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: const Icon(Icons.code, color: AppTheme.textSecondary),
          title: const Text(
            'Event Names Reference',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          subtitle: const Text(
            'Use these names in your IFTTT applets',
            style: TextStyle(fontSize: 13, color: AppTheme.textTertiary),
          ),
          iconColor: AppTheme.textSecondary,
          collapsedIconColor: AppTheme.textSecondary,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _buildEventRow(
                    'meshtastic_message',
                    'sender, message, channel',
                  ),
                  _buildEventRow(
                    'meshtastic_node_online',
                    'name, nodeId, timestamp',
                  ),
                  _buildEventRow(
                    'meshtastic_node_offline',
                    'name, nodeId, timestamp',
                  ),
                  _buildEventRow(
                    'meshtastic_battery_low',
                    'name, level%, threshold%',
                  ),
                  _buildEventRow(
                    'meshtastic_temperature',
                    'name, temp°C, threshold°C',
                  ),
                  _buildEventRow(
                    'meshtastic_position',
                    'name, lat/lon, distance',
                  ),
                  _buildEventRow('meshtastic_sos', 'name, nodeId, location'),
                  _buildEventRow('meshtastic_test', 'app, message, timestamp'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventRow(String eventName, String params) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              eventName,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: context.accentColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              params,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiary,
              ),
            ),
          ),
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
