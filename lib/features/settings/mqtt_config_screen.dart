// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/time_format.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/meshtastic/region_metadata.dart' as region_metadata;
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
    show MqttProxyDiagnostics, MqttProxyConnectionPhase, MqttProxyFailureReason;
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/module_config.pb.dart' as module_pb;
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../services/protocol/admin_target.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/settings_primitives.dart';
import '../../core/widgets/status_banner.dart';
import '../../core/mqtt/mqtt_constants.dart' show BrokerPreset;
import '../../core/mqtt/mqtt_preferences.dart';
import '../../core/utils/utf8_byte_length_formatter.dart';

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
  // App-local consent flag — sticky across sessions via SharedPreferences.
  // The radio's mapReportingEnabled gates whether map-reporting attempts
  // happen at all; this gates whether the unencrypted location is actually
  // emitted (`shouldReportLocation`) and whether the app-side proxy will
  // come up while map-reporting is on.
  bool _mapReportingOptIn = false;
  bool _obscurePassword = true;
  // Dirty-tracking gates the Save button: it stays disabled until the
  // user actually edits something. Avoids no-op saves that would still
  // trigger the radio's reboot countdown.
  bool _hasChanges = false;
  // Suppresses [_markDirty] while [_applyConfig] is mass-assigning the
  // controllers from the device's emitted MQTT config. Without this flag
  // every device-side push (cold-start cache or a fresh stream emit)
  // would synthesize a fake "user edit" via the controller listeners.
  bool _suppressDirtyTracking = false;
  // Map Report Settings
  int _mapPublishIntervalSecs = 3600;
  double _mapPositionPrecision = 14;
  StreamSubscription<module_pb.ModuleConfig_MQTTConfig>? _configSubscription;

  @override
  void initState() {
    super.initState();
    _addressController.addListener(_onAddressChanged);
    // Dirty-tracking listeners on every text controller. The
    // `_suppressDirtyTracking` guard inside [_markDirty] prevents the
    // mass-assignment in [_applyConfig] from synthesizing fake user
    // edits when the device pushes an MQTT config update.
    _addressController.addListener(_markDirty);
    _rootController.addListener(_markDirty);
    _usernameController.addListener(_markDirty);
    _passwordController.addListener(_markDirty);
    _loadMapReportingOptIn();
    _loadCurrentConfig();
  }

  /// Single listener attached to [_addressController]. Drives both:
  /// - the credential auto-fill on transition to the canonical broker, and
  /// - the rebuild that hides/shows the username/password/TLS rows when
  ///   the address transitions in/out of the default-broker bucket.
  ///
  /// Tracks the previous value via [_lastDefaultBrokerState] so the
  /// autofill fires only on a false→true transition, not on every
  /// keystroke (avoids clobbering a user mid-typing on the way to a
  /// different host).
  void _onAddressChanged() {
    final wasDefault = _lastDefaultBrokerState;
    final isDefault = _isDefaultBroker;
    _lastDefaultBrokerState = isDefault;
    if (isDefault && wasDefault == false) {
      _autofillForDefaultBroker();
    }
    if (wasDefault != isDefault && mounted) {
      // Trigger a UI rebuild so the form's conditional visibility (creds
      // hidden on default broker, TLS toggle hidden when proxy is also
      // on) re-evaluates against the new address.
      safeSetState(() {});
    }
  }

  /// Cached default-broker state from the previous [_onAddressChanged]
  /// invocation. `null` means "not seeded yet" — the very first listener
  /// fire will not trigger autofill, which lets [_applyConfig] set the
  /// address from the radio's stored config without overwriting the
  /// device-stored credentials with the public defaults.
  bool? _lastDefaultBrokerState;

  /// Whether the current address resolves to the canonical public
  /// Meshtastic broker. Match must be case-insensitive and strict
  /// (substring matches would let `mqtt.meshtastic.org.attacker.tld`
  /// inherit the public credentials and TLS-forcing behavior).
  bool get _isDefaultBroker =>
      _addressController.text.trim().toLowerCase() ==
      BrokerPreset.defaults.first.host.toLowerCase();

  /// Marks the form dirty. No-op if either [_suppressDirtyTracking] is
  /// active (we are inside [_applyConfig]) or the form is already dirty.
  void _markDirty() {
    if (_suppressDirtyTracking || _hasChanges) return;
    safeSetState(() => _hasChanges = true);
  }

  Future<void> _loadMapReportingOptIn() async {
    final value = await MqttPreferences.getMapReportingOptIn();
    if (!mounted) return;
    safeSetState(() => _mapReportingOptIn = value);
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _addressController.removeListener(_onAddressChanged);
    _addressController.removeListener(_markDirty);
    _rootController.removeListener(_markDirty);
    _usernameController.removeListener(_markDirty);
    _passwordController.removeListener(_markDirty);
    _addressController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rootController.dispose();
    super.dispose();
  }

  /// When the address transitions into a known public-broker preset,
  /// overwrite the credentials with that preset's defaults. Triggered
  /// on the false→true transition of [_isDefaultBroker], not on every
  /// keystroke, so partial typing (`m`, `mq`, …) doesn't accidentally
  /// clobber a user who is on the way to a different host.
  ///
  /// The overwrite is unconditional once on the canonical host: the
  /// AUTHENTICATION fields are hidden from the form on the default
  /// broker, so the only way to hold non-default creds for that host is
  /// to flip back to a custom hostname first. Documenting this here so
  /// the behavior isn't reverted by a future "don't clobber" patch.
  void _autofillForDefaultBroker() {
    BrokerPreset? match;
    for (final preset in BrokerPreset.defaults) {
      if (!preset.isCustom &&
          preset.host.toLowerCase() ==
              _addressController.text.trim().toLowerCase() &&
          preset.hasDefaultCredentials) {
        match = preset;
        break;
      }
    }
    if (match == null) return;
    safeSetState(() {
      _usernameController.text = match!.defaultUsername;
      _passwordController.text = match.defaultPassword;
    });
  }

  void _applyConfig(module_pb.ModuleConfig_MQTTConfig config) {
    _suppressDirtyTracking = true;
    safeSetState(() {
      _enabled = config.enabled;
      // Populate auth fields BEFORE the address so the auto-fill listener
      // attached to _addressController sees the radio's actual creds and
      // doesn't transiently clobber them with the public defaults.
      _usernameController.text = config.username;
      _passwordController.text = config.password;
      _addressController.text = config.address;
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
      _hasChanges = false;
    });
    _suppressDirtyTracking = false;
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
    final l10n = context.l10n;

    // Pre-save confirmation. Saving an MQTT config triggers a radio
    // reboot, so warn before kicking off the apply — the user has one
    // last chance to back out of an accidental tap. We do this BEFORE
    // flipping `_isSaving` so the spinner only spins for the real
    // network round-trip, not for the human deciding.
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.mqttConfigSaveConfirmTitle,
      message: l10n.mqttConfigSaveConfirmMessage,
      confirmLabel: l10n.mqttConfigSaveConfirmCta,
    );
    if (confirmed != true || !mounted) return;

    safeSetState(() => _isSaving = true);

    // Warn: MQTT on non-WiFi device without client proxy
    if (_enabled && !_proxyToClientEnabled && !_targetDeviceHasWifi()) {
      final wifiConfirmed = await AppBottomSheet.showConfirm(
        context: context,
        title: l10n.mqttConfigNoWifiTitle,
        message: l10n.mqttConfigNoWifiMsg,
        confirmLabel: l10n.mqttConfigSaveAnyway,
        isDestructive: true,
      );
      if (wifiConfirmed != true) {
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
      // Persist the user's consent decision before pushing the config to
      // the radio. The proxy provider reads this flag from
      // SharedPreferences at connect time and refuses to come up if
      // map-reporting is enabled but consent is missing.
      await MqttPreferences.setMapReportingOptIn(_mapReportingOptIn);

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
        // Only authorize the firmware to emit unencrypted location once
        // both the feature toggle and the privacy-disclaimer opt-in are
        // checked. The radio's `shouldReportLocation` field is the
        // firmware-level switch.
        shouldReportLocation: _mapReportingEnabled && _mapReportingOptIn,
        target: target,
      );

      if (mounted) {
        // Stay on the MQTT screen after save — the user wants to watch the
        // CLIENT PROXY STATUS card update with the new connection result
        // (phase + reason) without having to re-open the screen. Just
        // dismiss the keyboard so the diagnostics card scrolls into view.
        FocusScope.of(context).unfocus();
        // Reset dirty flag so the Save button greys out until the user
        // edits something else.
        safeSetState(() => _hasChanges = false);
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
              // Save is disabled while loading, in-flight, or — gated by
              // [_hasChanges] — when no edit has been made yet. Prevents
              // fat-finger no-op saves that would still trigger the radio
              // reboot countdown.
              onPressed: (_isLoading || _isSaving || !_hasChanges)
                  ? null
                  : _saveConfig,
              child: _isSaving
                  ? LoadingIndicator(size: 20)
                  : Text(
                      context.l10n.mqttConfigSave,
                      style: TextStyle(
                        color: _hasChanges
                            ? context.accentColor
                            : context.textTertiary,
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
                  SettingsTile(
                    icon: Icons.cloud,
                    iconColor: _enabled ? context.accentColor : null,
                    title: context.l10n.mqttConfigEnable,
                    subtitle: context.l10n.mqttConfigEnableSubtitle,
                    trailing: ThemedSwitch(
                      value: _enabled,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _enabled = value);
                        _markDirty();
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
                    SettingsSectionHeader(
                      title: context.l10n.mqttConfigSectionServer,
                    ),
                    FieldGroupCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            // maxLength caps the visible char count above
                            // the byte formatter so the lint gate is
                            // satisfied; the firmware-accurate limit is
                            // applied by Utf8ByteLengthFormatter
                            // (62 B = the firmware's address buffer).
                            maxLength: 256,
                            inputFormatters: const [
                              Utf8ByteLengthFormatter(62),
                            ],
                            controller: _addressController,
                            // Hostnames must never be auto-corrected /
                            // auto-capitalized. iOS otherwise turns
                            // "mqtt.ovmesh.com" → "Matt.ovmesh.com" and
                            // breaks DNS at save time.
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            enableSuggestions: false,
                            textCapitalization: TextCapitalization.none,
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
                            // Topic-root firmware buffer is 30 bytes.
                            maxLength: 256,
                            inputFormatters: const [
                              Utf8ByteLengthFormatter(30),
                            ],
                            controller: _rootController,
                            autocorrect: false,
                            enableSuggestions: false,
                            textCapitalization: TextCapitalization.none,
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
                    SettingsTile(
                      icon: Icons.lock_outline,
                      iconColor: _tlsEnabled ? context.accentColor : null,
                      title: context.l10n.mqttConfigUseTls,
                      subtitle: context.l10n.mqttConfigUseTlsSubtitle,
                      trailing: ThemedSwitch(
                        value: _tlsEnabled,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _tlsEnabled = value);
                          _markDirty();
                        },
                      ),
                    ),
                    // Username + Password are hidden on the default
                    // broker: the public credentials (`meshdev` /
                    // `large4cats`) are already auto-filled and there is
                    // no scenario in which the user should override them.
                    if (!_isDefaultBroker) ...[
                      SizedBox(height: AppTheme.spacing16),
                      SettingsSectionHeader(
                        title: context.l10n.mqttConfigSectionAuth,
                      ),
                      FieldGroupCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              // Username firmware buffer is 62 bytes.
                              maxLength: 100,
                              inputFormatters: const [
                                Utf8ByteLengthFormatter(62),
                              ],
                              controller: _usernameController,
                              autocorrect: false,
                              enableSuggestions: false,
                              textCapitalization: TextCapitalization.none,
                              textInputAction: TextInputAction.next,
                              style: TextStyle(color: context.textPrimary),
                              decoration: InputDecoration(
                                labelText: context.l10n.mqttConfigUsernameLabel,
                                labelStyle: TextStyle(
                                  color: context.textSecondary,
                                ),
                                hintText: context.l10n.mqttConfigOptionalHint,
                                hintStyle: TextStyle(
                                  color: SemanticColors.muted,
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
                                  Icons.person,
                                  color: context.textSecondary,
                                ),
                                counterText: '',
                              ),
                            ),
                            SizedBox(height: AppTheme.spacing16),
                            TextField(
                              // Password firmware buffer is 30 bytes.
                              maxLength: 64,
                              inputFormatters: const [
                                Utf8ByteLengthFormatter(30),
                              ],
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              autocorrect: false,
                              enableSuggestions: false,
                              textCapitalization: TextCapitalization.none,
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
                                hintStyle: TextStyle(
                                  color: SemanticColors.muted,
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
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: context.textSecondary,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    );
                                  },
                                ),
                                counterText: '',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ], // close `if (!_isDefaultBroker) ...[`
                    SizedBox(height: AppTheme.spacing16),
                    SettingsSectionHeader(
                      title: context.l10n.mqttConfigSectionOptions,
                    ),
                    SettingsTile(
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
                          _markDirty();
                        },
                      ),
                    ),
                    SettingsTile(
                      icon: Icons.data_object,
                      iconColor: _jsonEnabled ? context.accentColor : null,
                      title: context.l10n.mqttConfigJsonOutput,
                      subtitle: context.l10n.mqttConfigJsonOutputSubtitle,
                      trailing: ThemedSwitch(
                        value: _jsonEnabled,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _jsonEnabled = value;
                            // JSON output and Client Proxy are mutually
                            // exclusive on the radio: JSON output
                            // bypasses the encrypted proxy pipeline by
                            // definition.
                            if (value) {
                              _proxyToClientEnabled = false;
                            }
                          });
                          _markDirty();
                        },
                      ),
                    ),
                    SettingsTile(
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
                            // JSON Output and Client Proxy are mutually
                            // exclusive on the radio (JSON bypasses the
                            // encrypted proxy pipeline). TLS, however, is
                            // independent — SocialMesh's proxy fully
                            // supports TLS to the broker, so do NOT force
                            // TLS off when proxy is enabled.
                            if (value) _jsonEnabled = false;
                          });
                          _markDirty();
                        },
                      ),
                    ),
                    if (_enabled || _proxyToClientEnabled)
                      _buildProxyDiagnostics(),
                    SettingsTile(
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
                          _markDirty();
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
    final dateFmt = AppTimeFormat.withDatePrefix(
      context,
      '${AppTimeFormat.monthDayPattern(context)},',
    );

    final phaseLabel = _phaseLabel(l10n, diag.phase);
    final reasonLabel = _failureReasonLabel(l10n, diag.failureReason);
    final phaseColor = _phaseColor(diag.phase);

    // Banner shows only on real failure / disconnected states; suppress
    // it for healthy phases (connected / connecting / idle / disabled).
    final showNotConnectedBanner =
        _proxyToClientEnabled &&
        (diag.phase == MqttProxyConnectionPhase.failed ||
            diag.phase == MqttProxyConnectionPhase.disconnected ||
            diag.phase == MqttProxyConnectionPhase.missingConfig);

    final isConsentRequired =
        diag.failureReason ==
        MqttProxyFailureReason.mapReportingConsentRequired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: AppTheme.spacing16),
        if (showNotConnectedBanner)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            // Map-reporting consent gets its own warning copy that points
            // the user at the opt-in toggle instead of the generic
            // "broker unreachable" framing.
            child: isConsentRequired
                ? StatusBanner.warning(
                    title: l10n.mqttProxyBannerConsentRequiredTitle,
                    subtitle: l10n.mqttProxyBannerConsentRequiredHint,
                  )
                : diag.failureReason != MqttProxyFailureReason.none
                ? StatusBanner.error(
                    title: l10n.mqttProxyBannerNotConnectedTitle,
                    subtitle: diag.lastError ?? reasonLabel,
                  )
                : StatusBanner.warning(
                    title: l10n.mqttProxyBannerNotConnectedTitle,
                    subtitle: l10n.mqttProxyBannerNotConnectedHint,
                  ),
          ),
        SettingsSectionHeader(title: l10n.mqttProxySectionDiagnostics),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: InfoTable(
            rows: [
              InfoTableRow(
                label: l10n.mqttProxyStatusLabel,
                value: phaseLabel,
                icon: Icons.circle,
                iconColor: phaseColor,
              ),
              if (diag.failureReason != MqttProxyFailureReason.none)
                InfoTableRow(
                  label: l10n.mqttProxyReason,
                  value: reasonLabel,
                  icon: Icons.error_outline,
                  iconColor: SemanticColors.error,
                ),
              // Host on its own row so a long FQDN never wraps the port
              // onto a second line (e.g. "mqtt.meshtastic.org:8\n883").
              InfoTableRow(
                label: l10n.mqttProxyBroker,
                value: diag.brokerHost ?? none,
                icon: Icons.dns,
              ),
              InfoTableRow(
                label: l10n.mqttProxyPort,
                value: diag.brokerPort?.toString() ?? none,
                icon: Icons.numbers,
              ),
              InfoTableRow(
                label: l10n.mqttProxyTls,
                value: diag.tlsEnabled
                    ? l10n.mqttProxyEnabled
                    : l10n.mqttProxyDisabled,
                icon: Icons.lock_outline,
              ),
              InfoTableRow(
                label: l10n.mqttProxyAuth,
                value: diag.hasAuth
                    ? l10n.mqttProxyConfigured
                    : l10n.mqttProxyNone,
                icon: Icons.key_outlined,
              ),
              InfoTableRow(
                label: l10n.mqttProxyTopic,
                value: diag.subscribedTopic ?? diag.topicRoot ?? none,
                icon: Icons.topic_outlined,
              ),
              InfoTableRow(
                label: l10n.mqttProxyLastConnectAttempt,
                value: diag.lastConnectAttempt != null
                    ? dateFmt.format(diag.lastConnectAttempt!)
                    : none,
                icon: Icons.schedule,
              ),
              InfoTableRow(
                label: l10n.mqttProxyLastConnectedAt,
                value: diag.lastConnectedAt != null
                    ? dateFmt.format(diag.lastConnectedAt!)
                    : none,
                icon: Icons.check_circle_outline,
              ),
              InfoTableRow(
                label: l10n.mqttProxyLastDisconnectedAt,
                value: diag.lastDisconnectedAt != null
                    ? dateFmt.format(diag.lastDisconnectedAt!)
                    : none,
                icon: Icons.link_off,
              ),
              InfoTableRow(
                label: l10n.mqttProxyPublished,
                value: diag.messagesPublished.toString(),
                icon: Icons.upload,
              ),
              InfoTableRow(
                label: l10n.mqttProxyRelayed,
                value: diag.messagesRelayed.toString(),
                icon: Icons.download,
              ),
              // Publish-path counters — isolate where device→broker frames go.
              InfoTableRow(
                label: l10n.mqttProxyFramesReceived,
                value: diag.framesReceivedFromRadio.toString(),
                icon: Icons.cell_tower,
              ),
              InfoTableRow(
                label: l10n.mqttProxyDeferred,
                value: diag.publishesDeferred.toString(),
                icon: Icons.pending_outlined,
              ),
              InfoTableRow(
                label: l10n.mqttProxyDropped,
                value: diag.publishesDropped.toString(),
                icon: Icons.block,
                iconColor: diag.publishesDropped > 0
                    ? SemanticColors.error
                    : null,
              ),
              InfoTableRow(
                label: l10n.mqttProxyFlushed,
                value: diag.publishesFlushed.toString(),
                icon: Icons.replay,
              ),
              InfoTableRow(
                label: l10n.mqttProxyReconnects,
                value: diag.reconnectAttempts.toString(),
                icon: Icons.refresh,
              ),
              InfoTableRow(
                label: l10n.mqttProxyLastFailureAt,
                value: diag.lastFailureAt != null
                    ? dateFmt.format(diag.lastFailureAt!)
                    : none,
                icon: Icons.report_outlined,
                iconColor: diag.lastFailureAt != null
                    ? SemanticColors.error
                    : null,
              ),
              InfoTableRow(
                label: l10n.mqttProxyLastError,
                value: diag.lastError ?? none,
                icon: Icons.error_outline,
                iconColor: diag.lastError != null ? SemanticColors.error : null,
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

  String _phaseLabel(dynamic l10n, MqttProxyConnectionPhase phase) {
    switch (phase) {
      case MqttProxyConnectionPhase.disabled:
        return l10n.mqttProxyPhaseDisabled as String;
      case MqttProxyConnectionPhase.missingConfig:
        return l10n.mqttProxyPhaseMissingConfig as String;
      case MqttProxyConnectionPhase.idle:
        return l10n.mqttProxyPhaseIdle as String;
      case MqttProxyConnectionPhase.connecting:
        return l10n.mqttProxyPhaseConnecting as String;
      case MqttProxyConnectionPhase.connected:
        return l10n.mqttProxyPhaseConnected as String;
      case MqttProxyConnectionPhase.disconnected:
        return l10n.mqttProxyPhaseDisconnected as String;
      case MqttProxyConnectionPhase.failed:
        return l10n.mqttProxyPhaseFailed as String;
    }
  }

  String _failureReasonLabel(dynamic l10n, MqttProxyFailureReason reason) {
    switch (reason) {
      case MqttProxyFailureReason.none:
        return l10n.mqttProxyReasonNone as String;
      case MqttProxyFailureReason.missingHost:
        return l10n.mqttProxyReasonMissingHost as String;
      case MqttProxyFailureReason.missingTopicRoot:
        return l10n.mqttProxyReasonMissingTopicRoot as String;
      case MqttProxyFailureReason.invalidPort:
        return l10n.mqttProxyReasonInvalidPort as String;
      case MqttProxyFailureReason.dnsFailure:
        return l10n.mqttProxyReasonDnsFailure as String;
      case MqttProxyFailureReason.tcpConnectionRefused:
        return l10n.mqttProxyReasonTcpRefused as String;
      case MqttProxyFailureReason.tcpTimeout:
        return l10n.mqttProxyReasonTcpTimeout as String;
      case MqttProxyFailureReason.tlsHandshakeFailed:
        return l10n.mqttProxyReasonTlsHandshake as String;
      case MqttProxyFailureReason.tlsCertificateRejected:
        return l10n.mqttProxyReasonTlsCertificate as String;
      case MqttProxyFailureReason.authenticationFailed:
        return l10n.mqttProxyReasonAuthFailed as String;
      case MqttProxyFailureReason.protocolRejected:
        return l10n.mqttProxyReasonProtocolRejected as String;
      case MqttProxyFailureReason.brokerDisconnected:
        return l10n.mqttProxyReasonBrokerDisconnected as String;
      case MqttProxyFailureReason.clientDisposed:
        return l10n.mqttProxyReasonClientDisposed as String;
      case MqttProxyFailureReason.mapReportingConsentRequired:
        return l10n.mqttProxyReasonMapReportingConsent as String;
      case MqttProxyFailureReason.unknown:
        return l10n.mqttProxyReasonUnknown as String;
    }
  }

  Color _phaseColor(MqttProxyConnectionPhase phase) {
    switch (phase) {
      case MqttProxyConnectionPhase.connected:
        return SemanticColors.success;
      case MqttProxyConnectionPhase.connecting:
      case MqttProxyConnectionPhase.idle:
        return SemanticColors.warning;
      case MqttProxyConnectionPhase.disabled:
      case MqttProxyConnectionPhase.disconnected:
        return context.textTertiary;
      case MqttProxyConnectionPhase.missingConfig:
      case MqttProxyConnectionPhase.failed:
        return SemanticColors.error;
    }
  }

  void _copyProxyDiagnostics(MqttProxyDiagnostics diag) {
    HapticFeedback.selectionClick();
    final timePart = AppTimeFormat.timeWithSecondsPattern(context);
    final dateFmt = DateFormat(
      '${AppTimeFormat.monthDayPattern(context)}, $timePart',
    );
    final status = _phaseLabel(context.l10n, diag.phase);
    final reason = diag.failureReason == MqttProxyFailureReason.none
        ? null
        : _failureReasonLabel(context.l10n, diag.failureReason);
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
    final lastDisconnected = diag.lastDisconnectedAt != null
        ? dateFmt.format(diag.lastDisconnectedAt!)
        : context.l10n.mqttProxyNoneLabel;
    final lastFailure = diag.lastFailureAt != null
        ? dateFmt.format(diag.lastFailureAt!)
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
      ); // lint-allow: hardcoded-string
    if (reason != null) {
      buffer.writeln(
        '${context.l10n.mqttProxyReason}: $reason',
      ); // lint-allow: hardcoded-string
    }
    // Every field is emitted unconditionally (with a "None" fallback) so a
    // support dump is always complete — an absent line used to be ambiguous
    // between "healthy" and "old app version".
    buffer
      ..writeln(
        '${context.l10n.mqttProxyLastConnectAttempt}: $lastAttempt',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyLastConnectedAt}: $lastConnected',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyLastDisconnectedAt}: $lastDisconnected',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyPublished}: ${diag.messagesPublished}',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyRelayed}: ${diag.messagesRelayed}',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyFramesReceived}: '
        '${diag.framesReceivedFromRadio}',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyDeferred}: ${diag.publishesDeferred}',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyDropped}: ${diag.publishesDropped}',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyFlushed}: ${diag.publishesFlushed}',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyReconnects}: ${diag.reconnectAttempts}',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyLastFailureAt}: $lastFailure',
      ) // lint-allow: hardcoded-string
      ..writeln(
        '${context.l10n.mqttProxyLastError}: '
        '${diag.lastError ?? context.l10n.mqttProxyNoneLabel}',
      ); // lint-allow: hardcoded-string

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
    final l10n = context.l10n;
    return FieldGroupCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GDPR / CCPA consent block — must precede any
          // interval/precision controls. Once the user toggles Map
          // Reporting on, they must read and expressly opt in to the
          // privacy disclaimer before the firmware-level
          // "shouldReportLocation" can be authorized.
          Text(
            l10n.mqttConfigMapReportConsentHeader,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.mqttConfigMapReportConsentBody1,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.mqttConfigMapReportConsentBody2,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          SizedBox(height: AppTheme.spacing12),
          // Whole-row tap target: the parent Container's BoxDecoration
          // and the multi-paragraph disclaimer above produce a single
          // merged AXSwitch in the iOS accessibility tree, which steals
          // taps from a child ThemedSwitch. Wrapping the row in an
          // explicit InkWell gives the toggle its own gesture detector
          // AND lets the user tap the label text — better UX anyway.
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _mapReportingOptIn = !_mapReportingOptIn);
              _markDirty();
            },
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Switch is presentational only — the InkWell owns the
                  // tap. `onChanged: null` would render disabled, so pass
                  // a no-op closure that keeps the visual enabled state.
                  IgnorePointer(
                    child: ThemedSwitch(
                      value: _mapReportingOptIn,
                      onChanged: (_) {},
                    ),
                  ),
                  SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Text(
                      l10n.mqttConfigMapReportOptInLabel,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Interval + precision controls only render after the user has
          // expressly opted in — no point letting them tune publish
          // frequency for a broadcast they have not authorized.
          if (!_mapReportingOptIn) const SizedBox.shrink(),
          if (_mapReportingOptIn) ...[
            SizedBox(height: AppTheme.spacing16),
            Divider(color: context.border),
            SizedBox(height: AppTheme.spacing16),
            Text(
              l10n.mqttConfigMapReportSettingsHeader,
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
                  _markDirty();
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
                  _markDirty();
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
          ], // close if (_mapReportingOptIn) ...[
        ],
      ),
    );
  }
}

/// Returns the duty cycle percentage for a given LoRa region.
/// Delegates to the centralized region metadata (single source of truth
/// for regulatory data); see `lib/core/meshtastic/region_metadata.dart`.
int _dutyCycleForRegion(config_pbenum.Config_LoRaConfig_RegionCode region) =>
    region_metadata.dutyCycleForRegion(region);
