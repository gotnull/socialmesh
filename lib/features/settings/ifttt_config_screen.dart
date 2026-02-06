// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/map_config.dart';
import '../../core/theme.dart';
import '../../core/widgets/mesh_map_widget.dart';
import '../../core/widgets/premium_gating.dart';
import '../../models/subscription_models.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../utils/snackbar.dart';
import '../../services/ifttt/ifttt_service.dart';
import 'geofence_picker_screen.dart';
import '../../core/widgets/loading_indicator.dart';

/// Screen for configuring IFTTT Webhooks integration
class IftttConfigScreen extends ConsumerStatefulWidget {
  const IftttConfigScreen({super.key});

  @override
  ConsumerState<IftttConfigScreen> createState() => _IftttConfigScreenState();
}

class _IftttConfigScreenState extends ConsumerState<IftttConfigScreen>
    with LifecycleSafeMixin<IftttConfigScreen> {
  final _webhookKeyController = TextEditingController();
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
  bool _isSaving = false;
  int? _geofenceNodeNum;
  String? _geofenceNodeName;
  int _geofenceThrottleMinutes = 30;
  int _batteryThreshold = 20;
  double _temperatureThreshold = 40.0;
  MapTileStyle _mapStyle = MapTileStyle.dark;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadMapStyle();
  }

  void _loadConfig() {
    final iftttService = ref.read(iftttServiceProvider);
    final config = iftttService.config;

    _webhookKeyController.text = config.webhookKey;
    _geofenceRadiusController.text = config.geofenceRadius.toStringAsFixed(0);
    _geofenceLatController.text = config.geofenceLat?.toStringAsFixed(6) ?? '';
    _geofenceLonController.text = config.geofenceLon?.toStringAsFixed(6) ?? '';

    safeSetState(() {
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
      _batteryThreshold = config.batteryThreshold;
      _temperatureThreshold = config.temperatureThreshold;
    });
  }

  Future<void> _loadMapStyle() async {
    final settingsFuture = ref.read(settingsServiceProvider.future);
    final settings = await settingsFuture;
    if (!mounted) return;
    final index = settings.mapTileStyleIndex;
    if (index >= 0 && index < MapTileStyle.values.length) {
      safeSetState(() => _mapStyle = MapTileStyle.values[index]);
    }
  }

  Future<void> _saveConfig() async {
    // Capture provider refs before awaits
    final hasPremium = ref.read(
      hasFeatureProvider(PremiumFeature.iftttIntegration),
    );
    final iftttService = ref.read(iftttServiceProvider);
    final user = ref.read(currentUserProvider);
    if (_enabled && !hasPremium) {
      showPremiumInfoSheet(
        context: context,
        ref: ref,
        feature: PremiumFeature.iftttIntegration,
      );
      return;
    }

    // Require valid webhook key when IFTTT is enabled
    if (_enabled && _webhookKeyController.text.trim().isEmpty) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        'Please enter your Webhook Key to enable IFTTT',
      );
      return;
    }

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
      batteryThreshold: _batteryThreshold,
      temperatureThreshold: _temperatureThreshold,
      geofenceRadius: double.tryParse(_geofenceRadiusController.text) ?? 1000.0,
      geofenceLat: double.tryParse(_geofenceLatController.text),
      geofenceLon: double.tryParse(_geofenceLonController.text),
      geofenceNodeNum: _geofenceNodeNum,
      geofenceNodeName: _geofenceNodeName,
      geofenceThrottleMinutes: _geofenceThrottleMinutes,
    );

    safeSetState(() => _isSaving = true);

    try {
      await iftttService.saveConfig(config);

      if (!mounted) return;

      // Sync to cloud if signed in
      if (user != null) {
        ref
            .read(userProfileProvider.notifier)
            .updatePreferences(
              UserPreferences(iftttConfigJson: iftttService.toJsonString()),
            );
      }

      showSuccessSnackBar(context, 'IFTTT settings saved');
      Navigator.pop(context);
    } catch (e) {
      safeSetState(() => _isSaving = false);
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save IFTTT settings');
      }
    }
  }

  Future<void> _testWebhook() async {
    if (_webhookKeyController.text.trim().isEmpty) {
      showErrorSnackBar(context, 'Please enter your Webhook Key first');
      return;
    }

    safeSetState(() => _isTesting = true);

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
      batteryThreshold: _batteryThreshold,
      temperatureThreshold: _temperatureThreshold,
      geofenceRadius: double.tryParse(_geofenceRadiusController.text) ?? 1000.0,
      geofenceLat: double.tryParse(_geofenceLatController.text),
      geofenceLon: double.tryParse(_geofenceLonController.text),
      geofenceNodeNum: _geofenceNodeNum,
      geofenceNodeName: _geofenceNodeName,
      geofenceThrottleMinutes: _geofenceThrottleMinutes,
    );
    await iftttService.saveConfig(tempConfig);

    final success = await iftttService.testWebhook();
    if (!mounted) return;

    safeSetState(() => _isTesting = false);

    if (success) {
      showSuccessSnackBar(
        context,
        'Test webhook sent! Check your IFTTT applet.',
      );
    } else {
      showErrorSnackBar(
        context,
        'Failed to send test webhook. Check your key.',
      );
    }
  }

  @override
  void dispose() {
    _webhookKeyController.dispose();
    _geofenceRadiusController.dispose();
    _geofenceLatController.dispose();
    _geofenceLonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPremium = ref.watch(
      hasFeatureProvider(PremiumFeature.iftttIntegration),
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: 'IFTTT Integration',
        actions: [
          if (hasPremium)
            TextButton(
              onPressed: _isSaving ? null : _saveConfig,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            )
          else
            TextButton.icon(
              onPressed: () => showPremiumInfoSheet(
                context: context,
                ref: ref,
                feature: PremiumFeature.iftttIntegration,
              ),
              icon: const Icon(Icons.lock, size: 14, color: Colors.grey),
              label: Text(
                'Save',
                style: TextStyle(color: context.textSecondary),
              ),
            ),
        ],
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Premium explanation card (only shown when not premium)
                if (!hasPremium)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: PremiumExplanationCard(
                      feature: PremiumFeature.iftttIntegration,
                      title: 'Connect to 700+ Services',
                      description:
                          'Trigger smart home devices, log events to spreadsheets, send Discord/Slack messages, and more.',
                      exampleTitle: 'Node goes offline',
                      exampleDescription:
                          'Automatically turn on a smart light or send yourself a notification when your node is no longer heard.',
                      initiallyExpanded: true,
                    ),
                  ),
                _buildEnableTile(),
                // Only show form fields when premium AND enabled
                if (hasPremium && _enabled) ...[
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
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnableTile() {
    final hasPremium = ref.watch(
      hasFeatureProvider(PremiumFeature.iftttIntegration),
    );

    return _SettingsTile(
      icon: Icons.webhook,
      iconColor: _enabled && hasPremium ? context.accentColor : null,
      title: 'Enable IFTTT',
      subtitle: 'Send events to IFTTT Webhooks service',
      trailing: hasPremium
          ? ThemedSwitch(
              value: _enabled,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                safeSetState(() => _enabled = value);
              },
            )
          : GestureDetector(
              onTap: () => showPremiumInfoSheet(
                context: context,
                ref: ref,
                feature: PremiumFeature.iftttIntegration,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 16, color: context.textSecondary),
                  const SizedBox(width: 8),
                  ThemedSwitch(value: false, onChanged: null),
                ],
              ),
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
            color: context.card,
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
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Webhook Key',
                  labelStyle: TextStyle(color: context.textSecondary),
                  hintText: 'e.g., cMcOnB_zaJTrZwsVvzVTHY',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  helperText: 'Copy from IFTTT Webhooks URL after /use/',
                  helperStyle: TextStyle(color: context.textTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.accentColor),
                  ),
                  prefixIcon: Icon(Icons.key, color: context.textSecondary),
                  filled: true,
                  fillColor: context.background,
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
                      ? LoadingIndicator(size: 16)
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
              safeSetState(() => _messageReceived = value);
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
              safeSetState(() => _sosEmergency = value);
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
          title: 'Node Active',
          subtitle: 'Trigger when a node is heard recently',
          trailing: ThemedSwitch(
            value: _nodeOnline,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              safeSetState(() => _nodeOnline = value);
            },
          ),
        ),
        _SettingsTile(
          icon: Icons.wifi_off_outlined,
          title: 'Node Inactive',
          subtitle: 'Trigger when a node is not heard for a while',
          trailing: ThemedSwitch(
            value: _nodeOffline,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              safeSetState(() => _nodeOffline = value);
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
              safeSetState(() => _batteryLow = value);
            },
          ),
        ),
        if (_batteryLow)
          Container(
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
                    Icon(
                      Icons.battery_3_bar,
                      color: context.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Battery Threshold',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.accentColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_batteryThreshold%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                    activeTrackColor: context.accentColor,
                    inactiveTrackColor: context.border,
                    thumbColor: context.accentColor,
                    overlayColor: context.accentColor.withAlpha(30),
                  ),
                  child: Slider(
                    value: _batteryThreshold.toDouble(),
                    min: 5,
                    max: 50,
                    divisions: 9,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      safeSetState(() => _batteryThreshold = value.round());
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '5%',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                    Text(
                      '50%',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
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
              safeSetState(() => _temperatureAlert = value);
            },
          ),
        ),
        if (_temperatureAlert)
          Container(
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
                    Icon(
                      Icons.device_thermostat,
                      color: context.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Temperature Threshold',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.accentColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_temperatureThreshold.toStringAsFixed(0)}°C',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                    activeTrackColor: context.accentColor,
                    inactiveTrackColor: context.border,
                    thumbColor: context.accentColor,
                    overlayColor: context.accentColor.withAlpha(30),
                  ),
                  child: Slider(
                    value: _temperatureThreshold,
                    min: 30,
                    max: 80,
                    divisions: 10,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      safeSetState(() => _temperatureThreshold = value);
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '30°C',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                    Text(
                      '80°C',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
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
              safeSetState(() => _positionUpdate = value);
            },
          ),
        ),
        if (_positionUpdate)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _geofenceRadiusController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Geofence Radius',
                    labelStyle: TextStyle(color: context.textSecondary),
                    hintText: '1000',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.accentColor),
                    ),
                    prefixIcon: Icon(Icons.radar, color: context.textSecondary),
                    suffixText: 'm',
                    suffixStyle: TextStyle(color: context.textSecondary),
                    filled: true,
                    fillColor: context.background,
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _geofenceLatController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Center Latitude',
                    labelStyle: TextStyle(color: context.textSecondary),
                    hintText: '-33.8688',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.accentColor),
                    ),
                    prefixIcon: Icon(
                      Icons.my_location,
                      color: context.textSecondary,
                    ),
                    filled: true,
                    fillColor: context.background,
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _geofenceLonController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Center Longitude',
                    labelStyle: TextStyle(color: context.textSecondary),
                    hintText: '151.2093',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.accentColor),
                    ),
                    prefixIcon: Icon(
                      Icons.my_location,
                      color: context.textSecondary,
                    ),
                    filled: true,
                    fillColor: context.background,
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
                                child: MeshMapWidget(
                                  mapStyle: _mapStyle,
                                  initialCenter: LatLng(lat, lon),
                                  initialZoom: _calculateZoomForRadius(radius),
                                  interactive: false,
                                  animateTiles: false,
                                  additionalLayers: [
                                    CircleLayer(
                                      circles: [
                                        CircleMarker(
                                          point: LatLng(lat, lon),
                                          radius: radius,
                                          useRadiusInMeter: true,
                                          color: context.accentColor.withAlpha(
                                            40,
                                          ),
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
                        Icon(Icons.radar, color: context.accentColor, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monitored Node',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textTertiary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                _geofenceNodeName!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          color: context.textTertiary,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => safeSetState(() {
                            _geofenceNodeNum = null;
                            _geofenceNodeName = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
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
                        Expanded(
                          child: Text(
                            'No node selected. All nodes will be monitored.',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                // Throttle setting
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: context.textSecondary,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Alert Cooldown',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.border),
                      ),
                      child: DropdownButton<int>(
                        value: _geofenceThrottleMinutes,
                        dropdownColor: context.card,
                        underline: const SizedBox.shrink(),
                        isDense: true,
                        style: TextStyle(
                          color: context.textPrimary,
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
                            safeSetState(
                              () => _geofenceThrottleMinutes = value,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Minimum time between geofence alerts for the same node',
                  style: context.bodySmallStyle?.copyWith(
                    color: context.textTertiary,
                  ),
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
    final navigator = Navigator.of(context);
    final result = await navigator.push<GeofenceResult>(
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

    if (!mounted) return;
    if (result != null) {
      safeSetState(() {
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
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: context.bodySmallStyle?.copyWith(
                color: context.textSecondary,
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
        color: context.card,
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
          leading: Icon(Icons.code, color: context.textSecondary),
          title: Text(
            'Event Names Reference',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
            ),
          ),
          subtitle: Text(
            'Use these names in your IFTTT applets',
            style: context.bodySmallStyle?.copyWith(
              color: context.textTertiary,
            ),
          ),
          iconColor: context.textSecondary,
          collapsedIconColor: context.textSecondary,
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
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: context.accentColor,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              params,
              style: context.captionStyle?.copyWith(
                color: context.textTertiary,
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
      ),
    );
  }
}
