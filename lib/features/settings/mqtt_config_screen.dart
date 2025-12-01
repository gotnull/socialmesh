import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
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
      _rootController.text = config.root.isNotEmpty ? config.root : 'msh';
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
      final root = _rootController.text.trim();
      await protocol.setMQTTConfig(
        enabled: _enabled,
        address: _addressController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        encryptionEnabled: _encryptionEnabled,
        jsonEnabled: _jsonEnabled,
        tlsEnabled: _tlsEnabled,
        root: root.isNotEmpty ? root : 'msh',
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.darkBackground,
          title: const Text(
            'MQTT',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _isLoading ? null : _saveConfig,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryGreen,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
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
                  _SettingsTile(
                    icon: Icons.cloud,
                    iconColor: _enabled ? AppTheme.primaryGreen : null,
                    title: 'Enable MQTT',
                    subtitle:
                        'Connect device to an MQTT broker for mesh bridging',
                    trailing: Switch.adaptive(
                      value: _enabled,
                      activeTrackColor: AppTheme.primaryGreen,
                      inactiveTrackColor: Colors.grey.shade600,
                      thumbColor: WidgetStateProperty.all(Colors.white),
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _enabled = value);
                      },
                    ),
                  ),
                  if (_enabled) ...[
                    const SizedBox(height: 16),
                    const _SectionHeader(title: 'SERVER'),
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
                          TextField(
                            controller: _addressController,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Server Address',
                              labelStyle: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                              hintText: 'mqtt.meshtastic.org',
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              filled: true,
                              fillColor: AppTheme.darkBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.darkBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.darkBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.dns,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _rootController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Topic Root',
                              labelStyle: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                              hintText: 'msh',
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              filled: true,
                              fillColor: AppTheme.darkBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.darkBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.darkBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.topic,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.lock_outline,
                      iconColor: _tlsEnabled ? AppTheme.primaryGreen : null,
                      title: 'Use TLS',
                      subtitle: 'Encrypt connection to broker',
                      trailing: Switch.adaptive(
                        value: _tlsEnabled,
                        activeTrackColor: AppTheme.primaryGreen,
                        inactiveTrackColor: Colors.grey.shade600,
                        thumbColor: WidgetStateProperty.all(Colors.white),
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _tlsEnabled = value);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _SectionHeader(title: 'AUTHENTICATION'),
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
                          TextField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                              hintText: 'Optional',
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              filled: true,
                              fillColor: AppTheme.darkBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.darkBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.darkBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.person,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                              hintText: 'Optional',
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              filled: true,
                              fillColor: AppTheme.darkBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.darkBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.darkBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.lock,
                                color: AppTheme.textSecondary,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: AppTheme.textSecondary,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _SectionHeader(title: 'OPTIONS'),
                    _SettingsTile(
                      icon: Icons.enhanced_encryption,
                      iconColor: _encryptionEnabled
                          ? AppTheme.primaryGreen
                          : null,
                      title: 'Encryption',
                      subtitle: 'Encrypt mesh messages over MQTT',
                      trailing: Switch.adaptive(
                        value: _encryptionEnabled,
                        activeTrackColor: AppTheme.primaryGreen,
                        inactiveTrackColor: Colors.grey.shade600,
                        thumbColor: WidgetStateProperty.all(Colors.white),
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _encryptionEnabled = value);
                        },
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.data_object,
                      iconColor: _jsonEnabled ? AppTheme.primaryGreen : null,
                      title: 'JSON Output',
                      subtitle: 'Publish messages in JSON format',
                      trailing: Switch.adaptive(
                        value: _jsonEnabled,
                        activeTrackColor: AppTheme.primaryGreen,
                        inactiveTrackColor: Colors.grey.shade600,
                        thumbColor: WidgetStateProperty.all(Colors.white),
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _jsonEnabled = value);
                        },
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.swap_horiz,
                      iconColor: _proxyToClientEnabled
                          ? AppTheme.primaryGreen
                          : null,
                      title: 'Proxy to Client',
                      subtitle: 'Forward MQTT messages to connected clients',
                      trailing: Switch.adaptive(
                        value: _proxyToClientEnabled,
                        activeTrackColor: AppTheme.primaryGreen,
                        inactiveTrackColor: Colors.grey.shade600,
                        thumbColor: WidgetStateProperty.all(Colors.white),
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _proxyToClientEnabled = value);
                        },
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.map_outlined,
                      iconColor: _mapReportingEnabled
                          ? AppTheme.primaryGreen
                          : null,
                      title: 'Map Reporting',
                      subtitle: 'Report position to public mesh map',
                      trailing: Switch.adaptive(
                        value: _mapReportingEnabled,
                        activeTrackColor: AppTheme.primaryGreen,
                        inactiveTrackColor: Colors.grey.shade600,
                        thumbColor: WidgetStateProperty.all(Colors.white),
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _mapReportingEnabled = value);
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildInfoCard(),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen.withAlpha(50)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppTheme.primaryGreen,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'MQTT allows your device to bridge the local mesh network '
              'to the internet. This enables communication with nodes '
              'that are not in direct radio range.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontFamily: 'Inter',
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
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textTertiary,
                      fontFamily: 'Inter',
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
