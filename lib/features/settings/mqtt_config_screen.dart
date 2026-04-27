// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/time_format.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../providers/mqtt_client_proxy_providers.dart';
import '../../services/mqtt/mqtt_client_proxy_service.dart'
    show MqttProxyDiagnostics;
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/module_config.pb.dart' as module_pb;
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../services/protocol/admin_target.dart';
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
  bool _isSaving = false;
  bool _enabled = false;
  final _addressController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rootController = TextEditingController(
    text: 'msh',
  ); // lint-allow: hardcoded-string
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
    safeSetState(() {
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
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );

      // Apply cached config immediately if available (local only)
      if (target.isLocal) {
        final cached = protocol.currentMqttConfig;
        if (cached != null) {
          _applyConfig(cached);
        }
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
          target: target,
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
    safeSetState(() => _isSaving = true);
    final l10n = context.l10n;

    // Warn: MQTT on non-WiFi device without client proxy
    if (_enabled && !_proxyToClientEnabled && !_targetDeviceHasWifi()) {
      final confirmed = await AppBottomSheet.showConfirm(
        context: context,
        title: l10n.mqttConfigNoWifiTitle,
        message: l10n.mqttConfigNoWifiMsg,
        confirmLabel: l10n.mqttConfigSaveAnyway,
        isDestructive: true,
      );
      if (confirmed != true) {
        safeSetState(() => _isSaving = false);
        return;
      }
    }

    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );
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
        target: target,
      );

      if (mounted) {
        showSuccessSnackBar(context, l10n.mqttConfigSaved);
        if (target.isLocal) {
          ref
              .read(countdownProvider.notifier)
              .startDeviceRebootCountdown(reason: 'MQTT config saved');
          // Belt-and-suspender: trigger an immediate proxy refresh in
          // addition to the cache-emission path the auto-connect provider
          // already listens to. Idempotent connect makes the duplicate a
          // no-op when args match the in-flight or settled connection.
          unawaited(
            ref
                .read(mqttClientProxyControllerProvider)
                .refresh(reason: 'save-flow'),
          );
        }
        safeNavigatorPop();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, l10n.mqttConfigSaveFailed(e.toString()));
      }
    } finally {
      safeSetState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: context.l10n.mqttConfigTitle,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: (_isLoading || _isSaving) ? null : _saveConfig,
              child: _isSaving
                  ? LoadingIndicator(size: 20)
                  : Text(
                      context.l10n.mqttConfigSave,
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
                                title: context.l10n.mqttConfigDutyCycleWarning(
                                  dutyCyclePercent.toString(),
                                ),
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
                    title: context.l10n.mqttConfigEnable,
                    subtitle: context.l10n.mqttConfigEnableSubtitle,
                    trailing: ThemedSwitch(
                      value: _enabled,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _enabled = value);
                      },
                    ),
                  ),
                  if (_enabled) ...[
                    // Show advisory if device lacks WiFi hardware
                    if (!_targetDeviceHasWifi() && !_proxyToClientEnabled)
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warningYellow.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                          border: Border.all(
                            color: AppTheme.warningYellow.withValues(
                              alpha: 0.4,
                            ),
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
                                context.l10n.mqttConfigNoWifiAdvisory,
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
                    _SectionHeader(title: context.l10n.mqttConfigSectionServer),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            maxLength: 256,
                            controller: _addressController,
                            textInputAction: TextInputAction.next,
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              labelText:
                                  context.l10n.mqttConfigServerAddressLabel,
                              labelStyle: TextStyle(
                                color: context.textSecondary,
                              ),
                              hintText:
                                  context.l10n.mqttConfigServerAddressHint,
                              hintStyle: TextStyle(color: SemanticColors.muted),
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
                                Icons.dns,
                                color: context.textSecondary,
                              ),
                              counterText: '',
                            ),
                          ),
                          SizedBox(height: AppTheme.spacing16),
                          TextField(
                            maxLength: 256,
                            controller: _rootController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              labelText: context.l10n.mqttConfigTopicRootLabel,
                              labelStyle: TextStyle(
                                color: context.textSecondary,
                              ),
                              hintText: context.l10n.mqttConfigTopicRootHint,
                              hintStyle: TextStyle(color: SemanticColors.muted),
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
                                Icons.topic,
                                color: context.textSecondary,
                              ),
                              counterText: '',
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.lock_outline,
                      iconColor: _tlsEnabled ? context.accentColor : null,
                      title: context.l10n.mqttConfigUseTls,
                      subtitle: context.l10n.mqttConfigUseTlsSubtitle,
                      trailing: ThemedSwitch(
                        value: _tlsEnabled,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _tlsEnabled = value);
                        },
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing16),
                    _SectionHeader(title: context.l10n.mqttConfigSectionAuth),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            maxLength: 100,
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              labelText: context.l10n.mqttConfigUsernameLabel,
                              labelStyle: TextStyle(
                                color: context.textSecondary,
                              ),
                              hintText: context.l10n.mqttConfigOptionalHint,
                              hintStyle: TextStyle(color: SemanticColors.muted),
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
                                Icons.person,
                                color: context.textSecondary,
                              ),
                              counterText: '',
                            ),
                          ),
                          SizedBox(height: AppTheme.spacing16),
                          TextField(
                            maxLength: 64,
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              labelText: context.l10n.mqttConfigPasswordLabel,
                              labelStyle: TextStyle(
                                color: context.textSecondary,
                              ),
                              hintText: context.l10n.mqttConfigOptionalHint,
                              hintStyle: TextStyle(color: SemanticColors.muted),
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
                              counterText: '',
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing16),
                    _SectionHeader(
                      title: context.l10n.mqttConfigSectionOptions,
                    ),
                    _SettingsTile(
                      icon: Icons.enhanced_encryption,
                      iconColor: _encryptionEnabled
                          ? context.accentColor
                          : null,
                      title: context.l10n.mqttConfigEncryption,
                      subtitle: context.l10n.mqttConfigEncryptionSubtitle,
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
                      title: context.l10n.mqttConfigJsonOutput,
                      subtitle: context.l10n.mqttConfigJsonOutputSubtitle,
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
                      title: context.l10n.mqttConfigClientProxy,
                      subtitle: context.l10n.mqttConfigClientProxySubtitle,
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
                    if (_enabled || _proxyToClientEnabled)
                      _buildProxyDiagnostics(),
                    _SettingsTile(
                      icon: Icons.map_outlined,
                      iconColor: _mapReportingEnabled
                          ? context.accentColor
                          : null,
                      title: context.l10n.mqttConfigMapReporting,
                      subtitle: context.l10n.mqttConfigMapReportingSubtitle,
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
                  SizedBox(height: AppTheme.spacing16),
                  _buildInfoCard(),
                  SizedBox(height: AppTheme.spacing32),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProxyDiagnostics() {
    final diag = ref.watch(mqttProxyDiagnosticsProvider);
    final l10n = context.l10n;
    final none = l10n.mqttProxyNoneLabel;
    final dateFmt = AppTimeFormat.withDatePrefix(context, 'd MMM,');

    final showNotConnectedBanner = _proxyToClientEnabled && !diag.isConnected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: AppTheme.spacing16),
        if (showNotConnectedBanner)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: diag.lastError != null
                ? StatusBanner.error(
                    title: l10n.mqttProxyBannerNotConnectedTitle,
                    subtitle: diag.lastError!,
                  )
                : StatusBanner.warning(
                    title: l10n.mqttProxyBannerNotConnectedTitle,
                    subtitle: l10n.mqttProxyBannerNotConnectedHint,
                  ),
          ),
        _SectionHeader(title: l10n.mqttProxySectionDiagnostics),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
          ),
          child: Column(
            children: [
              _DiagRow(
                label: l10n.mqttProxyStatusLabel,
                value: diag.isConnected
                    ? l10n.mqttProxyStatusConnected
                    : l10n.mqttProxyStatusDisconnected,
                valueColor: diag.isConnected
                    ? SemanticColors.success
                    : SemanticColors.error,
              ),
              _DiagRow(
                label: l10n.mqttProxyBroker,
                value: diag.brokerHost != null
                    ? '${diag.brokerHost}:${diag.brokerPort ?? 1883}'
                    : none,
              ),
              _DiagRow(
                label: l10n.mqttProxyTls,
                value: diag.tlsEnabled
                    ? l10n.mqttProxyEnabled
                    : l10n.mqttProxyDisabled,
              ),
              _DiagRow(
                label: l10n.mqttProxyAuth,
                value: diag.hasAuth
                    ? l10n.mqttProxyConfigured
                    : l10n.mqttProxyNone,
              ),
              _DiagRow(
                label: l10n.mqttProxyTopic,
                value: diag.subscribedTopic ?? none,
              ),
              _DiagRow(
                label: l10n.mqttProxyLastConnectAttempt,
                value: diag.lastConnectAttempt != null
                    ? dateFmt.format(diag.lastConnectAttempt!)
                    : none,
              ),
              _DiagRow(
                label: l10n.mqttProxyLastConnectedAt,
                value: diag.lastConnectedAt != null
                    ? dateFmt.format(diag.lastConnectedAt!)
                    : none,
              ),
              _DiagRow(
                label: l10n.mqttProxyPublished,
                value: diag.messagesPublished.toString(),
              ),
              _DiagRow(
                label: l10n.mqttProxyRelayed,
                value: diag.messagesRelayed.toString(),
              ),
              if (diag.reconnectAttempts > 0)
                _DiagRow(
                  label: l10n.mqttProxyReconnects,
                  value: diag.reconnectAttempts.toString(),
                ),
              if (diag.lastError != null)
                _DiagRow(
                  label: l10n.mqttProxyLastError,
                  value: diag.lastError!,
                  valueColor: SemanticColors.error,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _copyProxyDiagnostics(diag),
              icon: const Icon(Icons.copy, size: 16),
              label: Text(l10n.mqttProxyCopyDiagnostics),
            ),
          ),
        ),
      ],
    );
  }

  void _copyProxyDiagnostics(MqttProxyDiagnostics diag) {
    HapticFeedback.selectionClick();
    final timePart = AppTimeFormat.timeWithSecondsPattern(context);
    final dateFmt = DateFormat('d MMM, $timePart');
    final status = diag.isConnected
        ? context.l10n.mqttProxyStatusConnected
        : context.l10n.mqttProxyStatusDisconnected;
    final broker = diag.brokerHost != null
        ? '${diag.brokerHost}:${diag.brokerPort ?? 1883}'
        : context.l10n.mqttProxyNoneLabel;
    final tls = diag.tlsEnabled
        ? context.l10n.mqttProxyEnabled
        : context.l10n.mqttProxyDisabled;
    final auth = diag.hasAuth
        ? context.l10n.mqttProxyConfigured
        : context.l10n.mqttProxyNone;
    final lastAttempt = diag.lastConnectAttempt != null
        ? dateFmt.format(diag.lastConnectAttempt!)
        : context.l10n.mqttProxyNoneLabel;
    final lastConnected = diag.lastConnectedAt != null
        ? dateFmt.format(diag.lastConnectedAt!)
        : context.l10n.mqttProxyNoneLabel;

    final buffer = StringBuffer()
      ..writeln(
        '${context.l10n.mqttProxyStatusLabel}: $status',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyBroker}: $broker',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyTls}: $tls',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyAuth}: $auth',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyLastConnectAttempt}: $lastAttempt',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyLastConnectedAt}: $lastConnected',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyPublished}: ${diag.messagesPublished}',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyRelayed}: ${diag.messagesRelayed}',
      ); // lint-allow: hardcoded-string

    if (diag.reconnectAttempts > 0) {
      buffer.writeln(
        '${context.l10n.mqttProxyReconnects}: ${diag.reconnectAttempts}',
      ); // lint-allow: hardcoded-string
    }
    if (diag.lastError != null) {
      buffer.writeln(
        '${context.l10n.mqttProxyLastError}: ${diag.lastError}',
      ); // lint-allow: hardcoded-string
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    showSuccessSnackBar(context, context.l10n.mqttProxyDiagnosticsCopied);
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.accentColor.withAlpha(20),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.accentColor.withAlpha(50)),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: context.accentColor, size: 20),
          SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Text(
              context.l10n.mqttConfigInfoText,
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _getPositionPrecisionLabel(BuildContext context, int precision) {
    final l10n = context.l10n;
    switch (precision) {
      case 12:
        return l10n.mqttConfigPrecisionWithin5_8km;
      case 13:
        return l10n.mqttConfigPrecisionWithin2_9km;
      case 14:
        return l10n.mqttConfigPrecisionWithin1_5km;
      case 15:
        return l10n.mqttConfigPrecisionWithin700m;
      default:
        return l10n.mqttConfigPrecisionUnknown;
    }
  }

  Widget _buildMapReportSettings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.mqttConfigMapReportSettingsHeader,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: context.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: AppTheme.spacing16),
          // Publish Interval
          Text(
            context.l10n.mqttConfigPublishInterval(
              _mapPublishIntervalSecs ~/ 60,
            ),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            context.l10n.mqttConfigPublishIntervalDesc,
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
          SizedBox(height: AppTheme.spacing16),
          Divider(color: context.border),
          SizedBox(height: AppTheme.spacing16),
          // Position Precision
          Text(
            context.l10n.mqttConfigPositionPrecision,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            context.l10n.mqttConfigPositionPrecisionDesc,
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
              _getPositionPrecisionLabel(
                context,
                _mapPositionPrecision.round(),
              ),
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
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 8),
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
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? context.textSecondary),
            SizedBox(width: AppTheme.spacing16),
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
                  const SizedBox(height: AppTheme.spacing2),
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

class _DiagRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DiagRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor ?? context.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
