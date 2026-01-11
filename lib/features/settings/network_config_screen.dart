import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/animations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/config.pb.dart' as config_pb;
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../core/widgets/loading_indicator.dart';

class NetworkConfigScreen extends ConsumerStatefulWidget {
  const NetworkConfigScreen({super.key});

  @override
  ConsumerState<NetworkConfigScreen> createState() =>
      _NetworkConfigScreenState();
}

class _NetworkConfigScreenState extends ConsumerState<NetworkConfigScreen> {
  bool _wifiEnabled = false;
  bool _ethEnabled = false;
  bool _saving = false;
  bool _loading = false;
  bool _obscurePassword = true;
  StreamSubscription<config_pb.Config_NetworkConfig>? _configSubscription;

  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ntpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ntpController.text = 'pool.ntp.org';
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _ssidController.dispose();
    _passwordController.dispose();
    _ntpController.dispose();
    super.dispose();
  }

  void _applyConfig(config_pb.Config_NetworkConfig config) {
    setState(() {
      _wifiEnabled = config.wifiEnabled;
      _ethEnabled = config.ethEnabled;
      _ssidController.text = config.wifiSsid;
      _passwordController.text = config.wifiPsk;
      _ntpController.text = config.ntpServer.isNotEmpty
          ? config.ntpServer
          : 'pool.ntp.org';
    });
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _loading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);

      // Apply cached config immediately if available
      final cached = protocol.currentNetworkConfig;
      if (cached != null) {
        _applyConfig(cached);
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription = protocol.networkConfigStream.listen((config) {
          if (mounted) _applyConfig(config);
        });

        // Request fresh config from device
        await protocol.getConfig(
          admin_pbenum.AdminMessage_ConfigType.NETWORK_CONFIG,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveConfig() async {
    final protocol = ref.read(protocolServiceProvider);

    setState(() => _saving = true);

    try {
      final ntp = _ntpController.text.trim();
      await protocol.setNetworkConfig(
        wifiEnabled: _wifiEnabled,
        wifiSsid: _ssidController.text,
        wifiPsk: _passwordController.text,
        ethEnabled: _ethEnabled,
        ntpServer: ntp.isNotEmpty ? ntp : 'pool.ntp.org',
      );

      if (mounted) {
        showSuccessSnackBar(context, 'Network configuration saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: context.background,
          title: Text(
            'Network',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _saving ? null : _saveConfig,
                child: _saving
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
        ),
        body: _loading
            ? const ScreenLoadingIndicator()
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // WiFi Section
                  const _SectionHeader(title: 'WI-FI'),

                  _SettingsTile(
                    icon: Icons.wifi,
                    iconColor: _wifiEnabled ? context.accentColor : null,
                    title: 'WiFi Enabled',
                    subtitle: 'Connect to a WiFi network',
                    trailing: ThemedSwitch(
                      value: _wifiEnabled,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _wifiEnabled = value);
                      },
                    ),
                  ),
                  if (_wifiEnabled)
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
                        children: [
                          TextField(
                            controller: _ssidController,
                            textInputAction: TextInputAction.next,
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Network Name (SSID)',
                              labelStyle: TextStyle(
                                color: context.textSecondary,
                              ),
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
                                Icons.wifi,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
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
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: context.textSecondary,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 16),

                  // Ethernet Section
                  const _SectionHeader(title: 'ETHERNET'),

                  _SettingsTile(
                    icon: Icons.settings_ethernet,
                    iconColor: _ethEnabled ? context.accentColor : null,
                    title: 'Ethernet Enabled',
                    subtitle: 'Use wired Ethernet connection',
                    trailing: ThemedSwitch(
                      value: _ethEnabled,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _ethEnabled = value);
                      },
                    ),
                  ),
                  SizedBox(height: 16),

                  // NTP Server Section
                  const _SectionHeader(title: 'TIME SYNC'),

                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NTP Server',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: _ntpController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          style: TextStyle(color: context.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'pool.ntp.org',
                            hintStyle: TextStyle(color: context.textTertiary),
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
                              Icons.access_time,
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Server used for time synchronization',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Info card
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: context.accentColor.withValues(alpha: 0.8),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Network settings are only available on devices with WiFi or Ethernet hardware support.',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
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
                    style: TextStyle(fontSize: 13, color: context.textTertiary),
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
