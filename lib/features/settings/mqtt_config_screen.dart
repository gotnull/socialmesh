// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/widgets/animations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/module_config.pb.dart' as module_pb;
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/status_banner.dart';

/// Screen for configuring MQTT module settings
class MqttConfigScreen extends ConsumerStatefulWidget {
  const MqttConfigScreen({super.key});

  @override
  ConsumerState<MqttConfigScreen> createState() => _MqttConfigScreenState();
}

class _MqttConfigScreenState extends ConsumerState<MqttConfigScreen>
    with LifecycleSafeMixin {
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
  // Map Report Settings
  int _mapPublishIntervalSecs = 3600;
  double _mapPositionPrecision = 14;
  StreamSubscription<module_pb.ModuleConfig_MQTTConfig>? _configSubscription;

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

  void _applyConfig(module_pb.ModuleConfig_MQTTConfig config) {
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
      // Map Report Settings
      final mapSettings = config.mapReportSettings;
      _mapPublishIntervalSecs = mapSettings.publishIntervalSecs > 0
          ? mapSettings.publishIntervalSecs
          : 3600;
      final precision = mapSettings.positionPrecision;
      if (precision >= 12 && precision <= 15) {
        _mapPositionPrecision = precision.toDouble();
      } else {
        _mapPositionPrecision = 14;
      }
    });
  }

  Future<void> _loadCurrentConfig() async {
    safeSetState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);

      // Apply cached config immediately if available
      final cached = protocol.currentMqttConfig;
      if (cached != null) {
        _applyConfig(cached);
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription = protocol.mqttConfigStream.listen((config) {
          if (mounted) _applyConfig(config);
        });

        // Request fresh config from device
        await protocol.getModuleConfig(
          admin_pbenum.AdminMessage_ModuleConfigType.MQTT_CONFIG,
        );
      }
    } catch (e) {
      // Device disconnected between isConnected check and getModuleConfig call
      // (PlatformException from BLE layer or StateError from protocol layer)
      AppLogging.protocol('MQTT config load aborted: $e');
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    safeSetState(() => _isLoading = true);
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
        mapPublishIntervalSecs: _mapPublishIntervalSecs,
        mapPositionPrecision: _mapPositionPrecision.round(),
      );

      if (mounted) {
        showSuccessSnackBar(context, 'MQTT configuration saved');
        safeNavigatorPop();
      }
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: 'MQTT',
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
        slivers: [
          if (_isLoading)
            const SliverFillRemaining(child: ScreenLoadingIndicator())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              sliver: SliverList.list(
                children: [
                  // Duty cycle warning
                  // EU_433, EU_868, UA_433, UA_868 have 10% duty cycle
                  Builder(
                    builder: (context) {
                      final regionAsync = ref.watch(deviceRegionProvider);
                      return regionAsync.when(
                        data: (region) {
                          final dutyCyclePercent = _dutyCycleForRegion(region);
                          if (dutyCyclePercent > 0 && dutyCyclePercent < 100) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: StatusBanner.warning(
                                title:
                                    'Your region has a $dutyCyclePercent% duty '
                                    'cycle. MQTT is not advised when you are '
                                    'duty cycle restricted — the extra traffic '
                                    'will quickly overwhelm your LoRa mesh.',
                                icon: Icons.warning_amber_rounded,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.cloud,
                    iconColor: _enabled ? context.accentColor : null,
                    title: 'Enable MQTT',
                    subtitle:
                        'Connect device to an MQTT broker for mesh bridging',
                    trailing: ThemedSwitch(
                      value: _enabled,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _enabled = value);
                      },
                    ),
                  ),
                  if (_enabled) ...[
                    SizedBox(height: 16),
                    const _SectionHeader(title: 'SERVER'),
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
                          TextField(
                            controller: _addressController,
                            textInputAction: TextInputAction.next,
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Server Address',
                              labelStyle: TextStyle(
                                color: context.textSecondary,
                              ),
                              hintText: 'mqtt.meshtastic.org',
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              filled: true,
                              fillColor: context.background,
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
                                borderSide: BorderSide(
                                  color: context.accentColor,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.dns,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          TextField(
                            controller: _rootController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Topic Root',
                              labelStyle: TextStyle(
                                color: context.textSecondary,
                              ),
                              hintText: 'msh',
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              filled: true,
                              fillColor: context.background,
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
                                borderSide: BorderSide(
                                  color: context.accentColor,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.topic,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.lock_outline,
                      iconColor: _tlsEnabled ? context.accentColor : null,
                      title: 'Use TLS',
                      subtitle: 'Encrypt connection to broker',
                      trailing: ThemedSwitch(
                        value: _tlsEnabled,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _tlsEnabled = value);
                        },
                      ),
                    ),
                    SizedBox(height: 16),
                    const _SectionHeader(title: 'AUTHENTICATION'),
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
                          TextField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: TextStyle(
                                color: context.textSecondary,
                              ),
                              hintText: 'Optional',
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              filled: true,
                              fillColor: context.background,
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
                                borderSide: BorderSide(
                                  color: context.accentColor,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.person,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(
                                color: context.textSecondary,
                              ),
                              hintText: 'Optional',
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              filled: true,
                              fillColor: context.background,
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
                                borderSide: BorderSide(
                                  color: context.accentColor,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.lock,
                                color: context.textSecondary,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: context.textSecondary,
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
                    SizedBox(height: 16),
                    const _SectionHeader(title: 'OPTIONS'),
                    _SettingsTile(
                      icon: Icons.enhanced_encryption,
                      iconColor: _encryptionEnabled
                          ? context.accentColor
                          : null,
                      title: 'Encryption',
                      subtitle: 'Encrypt mesh messages over MQTT',
                      trailing: ThemedSwitch(
                        value: _encryptionEnabled,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _encryptionEnabled = value);
                        },
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.data_object,
                      iconColor: _jsonEnabled ? context.accentColor : null,
                      title: 'JSON Output',
                      subtitle: 'Publish messages in JSON format',
                      trailing: ThemedSwitch(
                        value: _jsonEnabled,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _jsonEnabled = value);
                        },
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.phone_android,
                      iconColor: _proxyToClientEnabled
                          ? context.accentColor
                          : null,
                      title: 'MQTT Client Proxy',
                      subtitle:
                          "Use phone's network for MQTT\n(Required for devices without WiFi)",
                      trailing: ThemedSwitch(
                        value: _proxyToClientEnabled,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _proxyToClientEnabled = value;
                            // When using phone proxy, JSON and TLS are handled by
                            // the phone, not the device - disable them
                            if (value) {
                              _jsonEnabled = false;
                              _tlsEnabled = false;
                            }
                          });
                        },
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.map_outlined,
                      iconColor: _mapReportingEnabled
                          ? context.accentColor
                          : null,
                      title: 'Map Reporting',
                      subtitle: 'Report position to public mesh map',
                      trailing: ThemedSwitch(
                        value: _mapReportingEnabled,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _mapReportingEnabled = value);
                        },
                      ),
                    ),
                    if (_mapReportingEnabled) ...[_buildMapReportSettings()],
                  ],
                  SizedBox(height: 16),
                  _buildInfoCard(),
                  SizedBox(height: 32),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.accentColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.accentColor.withAlpha(50)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: context.accentColor, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'MQTT allows your device to bridge the local mesh network '
              'to the internet. This enables communication with nodes '
              'that are not in direct radio range.',
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _getPositionPrecisionLabel(int precision) {
    switch (precision) {
      case 12:
        return 'Within 5.8 km';
      case 13:
        return 'Within 2.9 km';
      case 14:
        return 'Within 1.5 km';
      case 15:
        return 'Within 700 m';
      default:
        return 'Unknown';
    }
  }

  Widget _buildMapReportSettings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MAP REPORT SETTINGS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: context.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 16),
          // Publish Interval
          Text(
            'Publish Interval: ${_mapPublishIntervalSecs ~/ 60} minutes',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How often to report position to map',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: context.accentColor,
              inactiveTrackColor: context.accentColor.withValues(alpha: 0.2),
              thumbColor: context.accentColor,
              overlayColor: context.accentColor.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _mapPublishIntervalSecs.toDouble(),
              min: 300,
              max: 14400,
              divisions: 28,
              onChanged: (value) {
                setState(() {
                  _mapPublishIntervalSecs = value.round();
                });
              },
            ),
          ),
          SizedBox(height: 16),
          Divider(color: context.border),
          SizedBox(height: 16),
          // Position Precision
          Text(
            'Position Precision',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Approximate location accuracy for map',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: context.accentColor,
              inactiveTrackColor: context.accentColor.withValues(alpha: 0.2),
              thumbColor: context.accentColor,
              overlayColor: context.accentColor.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _mapPositionPrecision,
              min: 12,
              max: 15,
              divisions: 3,
              onChanged: (value) {
                setState(() {
                  _mapPositionPrecision = value;
                });
              },
            ),
          ),
          Center(
            child: Text(
              _getPositionPrecisionLabel(_mapPositionPrecision.round()),
              style: TextStyle(
                fontSize: 13,
                color: context.accentColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns the duty cycle percentage for a given LoRa region.
/// EU and UA regions are restricted to 10%. All others are 100% (unrestricted).
int _dutyCycleForRegion(config_pbenum.Config_LoRaConfig_RegionCode region) {
  switch (region) {
    case config_pbenum.Config_LoRaConfig_RegionCode.EU_433:
    case config_pbenum.Config_LoRaConfig_RegionCode.EU_868:
    case config_pbenum.Config_LoRaConfig_RegionCode.UA_433:
    case config_pbenum.Config_LoRaConfig_RegionCode.UA_868:
      return 10;
    default:
      return 100;
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
