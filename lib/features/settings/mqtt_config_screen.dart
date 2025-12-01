import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;

/// Screen for configuring MQTT module settings
class MqttConfigScreen extends ConsumerStatefulWidget {
  const MqttConfigScreen({super.key});

  @override
  ConsumerState<MqttConfigScreen> createState() => _MqttConfigScreenState();
}

class _MqttConfigScreenState extends ConsumerState<MqttConfigScreen> {
  bool _isLoading = false;
  bool _enabled = false;
  final _addressController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rootController = TextEditingController(text: 'msh');
  bool _encryptionEnabled = true;
  bool _jsonEnabled = false;
  bool _tlsEnabled = false;
  bool _proxyToClientEnabled = false;
  bool _mapReportingEnabled = false;
  bool _obscurePassword = true;
  StreamSubscription<pb.ModuleConfig_MQTTConfig>? _configSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _addressController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rootController.dispose();
    super.dispose();
  }

  void _applyConfig(pb.ModuleConfig_MQTTConfig config) {
    setState(() {
      _enabled = config.enabled;
      _addressController.text = config.address;
      _usernameController.text = config.username;
      _passwordController.text = config.password;
      if (config.root.isNotEmpty) {
        _rootController.text = config.root;
      }
      _encryptionEnabled = config.encryptionEnabled;
      _jsonEnabled = config.jsonEnabled;
      _tlsEnabled = config.tlsEnabled;
      _proxyToClientEnabled = config.proxyToClientEnabled;
      _mapReportingEnabled = config.mapReportingEnabled;
    });
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);

      // Apply cached config immediately if available
      final cached = protocol.currentMqttConfig;
      if (cached != null) {
        _applyConfig(cached);
      }

      // Listen for config response
      _configSubscription = protocol.mqttConfigStream.listen((config) {
        if (mounted) _applyConfig(config);
      });

      // Request fresh config from device
      await protocol.getModuleConfig(
        pb.AdminMessage_ModuleConfigType.MQTT_CONFIG,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setMQTTConfig(
        enabled: _enabled,
        address: _addressController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        encryptionEnabled: _encryptionEnabled,
        jsonEnabled: _jsonEnabled,
        tlsEnabled: _tlsEnabled,
        root: _rootController.text,
        proxyToClientEnabled: _proxyToClientEnabled,
        mapReportingEnabled: _mapReportingEnabled,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MQTT configuration saved'),
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
        title: const Text('MQTT Configuration'),
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
                _buildEnableCard(theme),
                const SizedBox(height: 24),
                if (_enabled) ...[
                  _SectionHeader(title: 'SERVER'),
                  const SizedBox(height: 8),
                  _buildServerSettings(theme),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'AUTHENTICATION'),
                  const SizedBox(height: 8),
                  _buildAuthSettings(theme),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'OPTIONS'),
                  const SizedBox(height: 8),
                  _buildOptionsSettings(theme),
                  const SizedBox(height: 24),
                ],
                _buildInfoCard(theme),
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
        title: const Text('Enable MQTT'),
        subtitle: const Text(
          'Connect device to an MQTT broker for mesh bridging',
        ),
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
            Icons.cloud,
            color: _enabled
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildServerSettings(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Server Address',
                hintText: 'mqtt.meshtastic.org',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rootController,
              decoration: const InputDecoration(
                labelText: 'Topic Root',
                hintText: 'msh',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.topic),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _tlsEnabled,
              onChanged: (value) => setState(() => _tlsEnabled = value),
              title: const Text('Use TLS'),
              subtitle: const Text('Encrypt connection to broker'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthSettings(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Optional',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Optional',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsSettings(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              value: _encryptionEnabled,
              onChanged: (value) => setState(() => _encryptionEnabled = value),
              title: const Text('Encryption'),
              subtitle: const Text('Encrypt mesh messages over MQTT'),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            SwitchListTile(
              value: _jsonEnabled,
              onChanged: (value) => setState(() => _jsonEnabled = value),
              title: const Text('JSON Output'),
              subtitle: const Text('Publish messages in JSON format'),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            SwitchListTile(
              value: _proxyToClientEnabled,
              onChanged: (value) =>
                  setState(() => _proxyToClientEnabled = value),
              title: const Text('Proxy to Client'),
              subtitle: const Text(
                'Forward MQTT messages to connected clients',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            SwitchListTile(
              value: _mapReportingEnabled,
              onChanged: (value) =>
                  setState(() => _mapReportingEnabled = value),
              title: const Text('Map Reporting'),
              subtitle: const Text('Report position to public mesh map'),
              contentPadding: EdgeInsets.zero,
            ),
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
        child: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'MQTT allows your device to bridge the local mesh network '
                'to the internet. This enables communication with nodes '
                'that are not in direct radio range.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
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
