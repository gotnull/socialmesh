// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/settings_primitives.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/config.pb.dart' as config_pb;
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../services/protocol/admin_target.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/app_bottom_sheet.dart';

class NetworkConfigScreen extends ConsumerStatefulWidget {
  const NetworkConfigScreen({super.key});

  @override
  ConsumerState<NetworkConfigScreen> createState() =>
      _NetworkConfigScreenState();
}

class _NetworkConfigScreenState extends ConsumerState<NetworkConfigScreen>
    with LifecycleSafeMixin {
  bool _wifiEnabled = false;
  bool _ethEnabled = false;
  bool _udpEnabled = false;
  bool _saving = false;
  bool _loading = false;
  bool _obscurePassword = true;
  config_pb.Config_NetworkConfig_AddressMode _addressMode =
      config_pb.Config_NetworkConfig_AddressMode.DHCP;
  StreamSubscription<config_pb.Config_NetworkConfig>? _configSubscription;

  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ntpController = TextEditingController();
  final _rsyslogController = TextEditingController();

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
    _rsyslogController.dispose();
    super.dispose();
  }

  void _applyConfig(config_pb.Config_NetworkConfig config) {
    safeSetState(() {
      _wifiEnabled = config.wifiEnabled;
      _ethEnabled = config.ethEnabled;
      _ssidController.text = config.wifiSsid;
      _passwordController.text = config.wifiPsk;
      _ntpController.text = config.ntpServer.isNotEmpty
          ? config.ntpServer
          : 'pool.ntp.org';
      _addressMode = config.addressMode;
      _rsyslogController.text = config.rsyslogServer;
      // UDP broadcast is stored as a bitmask in enabledProtocols (bit 0 = UDP_BROADCAST)
      _udpEnabled = (config.enabledProtocols & 1) != 0;
    });
  }

  Future<void> _loadCurrentConfig() async {
    safeSetState(() => _loading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );

      // Apply cached config immediately if available (local only)
      if (target.isLocal) {
        final cached = protocol.currentNetworkConfig;
        if (cached != null) {
          _applyConfig(cached);
        }
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
          target: target,
        );
      }
    } catch (e) {
      // Device disconnected between isConnected check and getConfig call
      // Catches both StateError (from protocol layer) and PlatformException
      // (from BLE layer) when device disconnects during the config request
      AppLogging.protocol('Network config load aborted: $e');
    } finally {
      safeSetState(() => _loading = false);
    }
  }

  /// Returns true if target device reports WiFi hardware support.
  /// Falls back to false when metadata is unavailable.
  bool _targetDeviceHasWifi() {
    final remoteTarget = ref.read(remoteAdminTargetProvider);
    final nodes = ref.read(nodesProvider);
    if (remoteTarget != null) {
      return nodes[remoteTarget]?.hasWifi ?? false;
    }
    final myNodeNum = ref.read(myNodeNumProvider);
    if (myNodeNum == null) return false;
    return nodes[myNodeNum]?.hasWifi ?? false;
  }

  Future<void> _saveConfig() async {
    final protocol = ref.read(protocolServiceProvider);
    final target = AdminTarget.fromNullable(
      ref.read(remoteAdminTargetProvider),
    );

    safeSetState(() => _saving = true);

    final l10n = context.l10n;

    // Guard: block WiFi on devices without WiFi hardware
    if (_wifiEnabled && !_targetDeviceHasWifi()) {
      final confirmed = await AppBottomSheet.showConfirm(
        context: context,
        title: l10n.networkConfigNoWifiTitle,
        message: l10n.networkConfigNoWifiBody,
        confirmLabel: l10n.networkConfigSaveAnyway,
        isDestructive: true,
      );
      if (confirmed != true) {
        safeSetState(() => _saving = false);
        return;
      }
    }
    try {
      final ntp = _ntpController.text.trim();
      final rsyslog = _rsyslogController.text.trim();
      await protocol.setNetworkConfig(
        wifiEnabled: _wifiEnabled,
        wifiSsid: _ssidController.text,
        wifiPsk: _passwordController.text,
        ethEnabled: _ethEnabled,
        ntpServer: ntp.isNotEmpty ? ntp : 'pool.ntp.org',
        addressMode: _addressMode,
        rsyslogServer: rsyslog,
        enabledProtocols: _udpEnabled ? 1 : 0,
        target: target,
      );

      if (mounted) {
        showSuccessSnackBar(context, l10n.networkConfigSaved);
        if (target.isLocal) {
          ref
              .read(countdownProvider.notifier)
              .startDeviceRebootCountdown(reason: 'network config saved');
        }
        safeNavigatorPop();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, l10n.networkConfigSaveFailed(e.toString()));
      }
    } finally {
      safeSetState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: context.l10n.networkConfigTitle,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _saveConfig,
              child: _saving
                  ? LoadingIndicator(size: 20)
                  : Text(
                      context.l10n.networkConfigSave,
                      style: TextStyle(
                        color: context.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
        slivers: [
          if (_loading)
            const SliverFillRemaining(child: ScreenLoadingIndicator())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              sliver: SliverList.list(
                children: [
                  // WiFi Section
                  SettingsSectionHeader(
                    title: context.l10n.networkConfigSectionWifi,
                  ),

                  // Show warning if device lacks WiFi hardware
                  if (!_targetDeviceHasWifi())
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningYellow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        border: Border.all(
                          color: AppTheme.warningYellow.withValues(alpha: 0.4),
                        ),
                      ),
                      padding: const EdgeInsets.all(AppTheme.spacing12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.warningYellow.withValues(
                              alpha: 0.9,
                            ),
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spacing10),
                          Expanded(
                            child: Text(
                              context.l10n.networkConfigNoWifiWarning,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SettingsTile(
                    icon: Icons.wifi,
                    iconColor: _wifiEnabled ? context.accentColor : null,
                    title: context.l10n.networkConfigWifiEnabled,
                    subtitle: context.l10n.networkConfigWifiEnabledSubtitle,
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
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            maxLength: 32,
                            controller: _ssidController,
                            textInputAction: TextInputAction.next,
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              labelText: context.l10n.networkConfigSsid,
                              labelStyle: TextStyle(
                                color: context.textSecondary,
                              ),
                              filled: true,
                              fillColor: context.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius8,
                                ),
                                borderSide: BorderSide(color: context.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius8,
                                ),
                                borderSide: BorderSide(color: context.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius8,
                                ),
                                borderSide: BorderSide(
                                  color: context.accentColor,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.wifi,
                                color: context.textSecondary,
                              ),
                              counterText: '',
                            ),
                          ),
                          SizedBox(height: AppTheme.spacing12),
                          TextField(
                            maxLength: 64,
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              labelText: context.l10n.networkConfigPassword,
                              labelStyle: TextStyle(
                                color: context.textSecondary,
                              ),
                              filled: true,
                              fillColor: context.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius8,
                                ),
                                borderSide: BorderSide(color: context.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius8,
                                ),
                                borderSide: BorderSide(color: context.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius8,
                                ),
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
                              counterText: '',
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: AppTheme.spacing16),

                  // Ethernet Section
                  SettingsSectionHeader(
                    title: context.l10n.networkConfigSectionEthernet,
                  ),

                  SettingsTile(
                    icon: Icons.settings_ethernet,
                    iconColor: _ethEnabled ? context.accentColor : null,
                    title: context.l10n.networkConfigEthernetEnabled,
                    subtitle: context.l10n.networkConfigEthernetEnabledSubtitle,
                    trailing: ThemedSwitch(
                      value: _ethEnabled,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _ethEnabled = value);
                      },
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing16),

                  // Address Mode Section
                  SettingsSectionHeader(
                    title: context.l10n.networkConfigSectionIpAddress,
                  ),
                  _buildAddressModeSelector(),
                  SizedBox(height: AppTheme.spacing16),

                  // NTP Server Section
                  SettingsSectionHeader(
                    title: context.l10n.networkConfigSectionTimeSync,
                  ),

                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.networkConfigNtpServer,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: AppTheme.spacing8),
                        TextField(
                          maxLength: 256,
                          controller: _ntpController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          style: TextStyle(color: context.textPrimary),
                          decoration: InputDecoration(
                            hintText:
                                'pool.ntp.org', // lint-allow: hardcoded-string
                            hintStyle: TextStyle(color: context.textTertiary),
                            filled: true,
                            fillColor: context.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius8,
                              ),
                              borderSide: BorderSide(color: context.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius8,
                              ),
                              borderSide: BorderSide(color: context.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius8,
                              ),
                              borderSide: BorderSide(
                                color: context.accentColor,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.access_time,
                              color: context.textSecondary,
                            ),
                            counterText: '',
                          ),
                        ),
                        SizedBox(height: AppTheme.spacing8),
                        Text(
                          context.l10n.networkConfigNtpServerSubtitle,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing16),

                  // UDP Broadcast Section
                  SettingsSectionHeader(
                    title: context.l10n.networkConfigSectionUdpBroadcast,
                  ),
                  SettingsTile(
                    icon: Icons.cell_tower,
                    iconColor: _udpEnabled ? context.accentColor : null,
                    title: context.l10n.networkConfigUdpBroadcast,
                    subtitle: context.l10n.networkConfigUdpBroadcastSubtitle,
                    trailing: ThemedSwitch(
                      value: _udpEnabled,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _udpEnabled = value);
                      },
                    ),
                  ),
                  if (_udpEnabled)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        border: Border.all(
                          color: context.accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      padding: const EdgeInsets.all(AppTheme.spacing12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: context.accentColor.withValues(alpha: 0.8),
                            size: 18,
                          ),
                          const SizedBox(width: AppTheme.spacing10),
                          Expanded(
                            child: Text(
                              context.l10n.networkConfigUdpBroadcastInfo,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: AppTheme.spacing16),

                  // Rsyslog Server Section
                  SettingsSectionHeader(
                    title: context.l10n.networkConfigSectionLogging,
                  ),
                  _buildRsyslogSettings(),
                  SizedBox(height: AppTheme.spacing16),

                  // Info card
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      border: Border.all(
                        color: context.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: context.accentColor.withValues(alpha: 0.8),
                          size: 20,
                        ),
                        SizedBox(width: AppTheme.spacing12),
                        Expanded(
                          child: Text(
                            context.l10n.networkConfigNoHardwareInfo,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing32),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddressModeSelector() {
    final modes = [
      (
        config_pb.Config_NetworkConfig_AddressMode.DHCP,
        context.l10n.networkConfigIpModeDhcp,
        context.l10n.networkConfigIpModeDhcpDesc,
        Icons.auto_awesome,
      ),
      (
        config_pb.Config_NetworkConfig_AddressMode.STATIC,
        context.l10n.networkConfigIpModeStatic,
        context.l10n.networkConfigIpModeStaticDesc,
        Icons.edit,
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: modes.map((m) {
          final isSelected = _addressMode == m.$1;
          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _addressMode = m.$1);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? context.accentColor
                        : context.textSecondary,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Icon(
                    m.$4,
                    color: isSelected
                        ? context.accentColor
                        : context.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.$2,
                          style: TextStyle(
                            color: isSelected
                                ? context.textPrimary
                                : context.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          m.$3,
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRsyslogSettings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.networkConfigRsyslogServer,
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          TextField(
            maxLength: 256,
            controller: _rsyslogController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText:
                  'e.g., 192.168.1.100:514', // lint-allow: hardcoded-string
              hintStyle: TextStyle(color: context.textTertiary),
              filled: true,
              fillColor: context.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.accentColor),
              ),
              prefixIcon: Icon(
                Icons.description_outlined,
                color: context.textSecondary,
              ),
              counterText: '',
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.networkConfigRsyslogServerSubtitle,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
