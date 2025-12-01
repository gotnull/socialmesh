import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../services/ifttt/ifttt_service.dart';

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
  bool _obscureKey = true;

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
    final theme = Theme.of(context);

    if (_webhookKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your Webhook Key first'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isTesting = true);

    // Save config first so test uses current key
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
          backgroundColor: success
              ? theme.colorScheme.primary
              : theme.colorScheme.error,
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('IFTTT Integration'),
        actions: [
          TextButton(onPressed: _saveConfig, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildEnableCard(theme),
          const SizedBox(height: 24),
          if (_enabled) ...[
            _SectionHeader(title: 'WEBHOOK'),
            const SizedBox(height: 8),
            _buildWebhookSettings(theme),
            const SizedBox(height: 24),
            _SectionHeader(title: 'MESSAGE TRIGGERS'),
            const SizedBox(height: 8),
            _buildMessageTriggers(theme),
            const SizedBox(height: 24),
            _SectionHeader(title: 'NODE STATUS TRIGGERS'),
            const SizedBox(height: 8),
            _buildNodeTriggers(theme),
            const SizedBox(height: 24),
            _SectionHeader(title: 'TELEMETRY TRIGGERS'),
            const SizedBox(height: 8),
            _buildTelemetryTriggers(theme),
            const SizedBox(height: 24),
            _SectionHeader(title: 'GEOFENCING'),
            const SizedBox(height: 8),
            _buildGeofenceSettings(theme),
            const SizedBox(height: 24),
          ],
          _buildInfoCard(theme),
          const SizedBox(height: 16),
          _buildEventNamesCard(theme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildEnableCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        value: _enabled,
        onChanged: (value) => setState(() => _enabled = value),
        title: const Text('Enable IFTTT'),
        subtitle: const Text('Send events to IFTTT Webhooks service'),
        secondary: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _enabled
                ? theme.colorScheme.primary.withAlpha(25)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.webhook,
            color: _enabled
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildWebhookSettings(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _webhookKeyController,
              obscureText: _obscureKey,
              enableInteractiveSelection: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Webhook Key',
                hintText: 'e.g., cMcOnB_zaJTrZwsVvzVTHY',
                helperText: 'Copy from IFTTT Webhooks URL after /use/',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.key),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureKey ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscureKey = !_obscureKey);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _isTesting ? null : _testWebhook,
                icon: _isTesting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTriggers(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              value: _messageReceived,
              onChanged: (value) => setState(() => _messageReceived = value),
              title: const Text('Message Received'),
              subtitle: const Text('Trigger when a message is received'),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            SwitchListTile(
              value: _sosEmergency,
              onChanged: (value) => setState(() => _sosEmergency = value),
              title: const Text('SOS / Emergency'),
              subtitle: const Text(
                'Trigger on SOS, emergency, help, mayday keywords',
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeTriggers(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              value: _nodeOnline,
              onChanged: (value) => setState(() => _nodeOnline = value),
              title: const Text('Node Online'),
              subtitle: const Text('Trigger when a node comes online'),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            SwitchListTile(
              value: _nodeOffline,
              onChanged: (value) => setState(() => _nodeOffline = value),
              title: const Text('Node Offline'),
              subtitle: const Text('Trigger when a node goes offline'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryTriggers(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              value: _batteryLow,
              onChanged: (value) => setState(() => _batteryLow = value),
              title: const Text('Battery Low'),
              subtitle: const Text(
                'Trigger when battery drops below threshold',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            if (_batteryLow) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _batteryThresholdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Battery Threshold',
                  hintText: '20',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.battery_3_bar),
                  suffixText: '%',
                ),
              ),
            ],
            const Divider(),
            SwitchListTile(
              value: _temperatureAlert,
              onChanged: (value) => setState(() => _temperatureAlert = value),
              title: const Text('Temperature Alert'),
              subtitle: const Text(
                'Trigger when temperature exceeds threshold',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            if (_temperatureAlert) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _temperatureThresholdController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Temperature Threshold',
                  hintText: '40.0',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.device_thermostat),
                  suffixText: '°C',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGeofenceSettings(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              value: _positionUpdate,
              onChanged: (value) => setState(() => _positionUpdate = value),
              title: const Text('Position Updates'),
              subtitle: const Text('Trigger when node exits geofence area'),
              contentPadding: EdgeInsets.zero,
            ),
            if (_positionUpdate) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _geofenceRadiusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Geofence Radius',
                  hintText: '1000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.radar),
                  suffixText: 'm',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _geofenceLatController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Center Latitude',
                  hintText: '-33.8688',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.my_location),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _geofenceLonController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Center Longitude',
                  hintText: '151.2093',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.my_location),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primaryContainer.withAlpha(100),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Setup Guide',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStep(theme, '1', 'Create an account at ifttt.com'),
            _buildStep(
              theme,
              '2',
              'Search for "Webhooks" service and connect it',
            ),
            _buildStep(theme, '3', 'Go to Webhooks settings to find your key'),
            _buildStep(
              theme,
              '4',
              'Create applets with Webhooks as the trigger',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(ThemeData theme, String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(50),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventNamesCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: Icon(Icons.code, color: theme.colorScheme.primary),
        title: const Text('Event Names Reference'),
        subtitle: const Text('Use these names in your IFTTT applets'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _buildEventRow(
                  'meshtastic_message',
                  'value1=sender, value2=message, value3=channel',
                ),
                _buildEventRow(
                  'meshtastic_node_online',
                  'value1=name, value2=nodeId, value3=timestamp',
                ),
                _buildEventRow(
                  'meshtastic_node_offline',
                  'value1=name, value2=nodeId, value3=timestamp',
                ),
                _buildEventRow(
                  'meshtastic_battery_low',
                  'value1=name, value2=level%, value3=threshold%',
                ),
                _buildEventRow(
                  'meshtastic_temperature',
                  'value1=name, value2=temp°C, value3=threshold°C',
                ),
                _buildEventRow(
                  'meshtastic_position',
                  'value1=name, value2=lat,lon, value3=distance',
                ),
                _buildEventRow(
                  'meshtastic_sos',
                  'value1=name, value2=nodeId, value3=location',
                ),
                _buildEventRow(
                  'meshtastic_test',
                  'value1=app, value2=message, value3=timestamp',
                ),
              ],
            ),
          ),
        ],
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
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              params,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
