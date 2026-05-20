// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/chip_selector.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/settings_primitives.dart';
import '../../models/trigger_protocol.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/map_config.dart';
import '../../core/safe_lat_lng.dart';
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
import '../../core/l10n/l10n_extension.dart';
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
  final _customWebhookUrlController = TextEditingController();
  final _geofenceRadiusController = TextEditingController();
  final _geofenceLatController = TextEditingController();
  final _geofenceLonController = TextEditingController();

  bool _enabled = false;
  WebhookMode _webhookMode = WebhookMode.ifttt;
  TriggerProtocolFilter _protocolFilter = TriggerProtocolFilter.any;
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
    _customWebhookUrlController.text = config.customWebhookUrl;
    _geofenceRadiusController.text = config.geofenceRadius.toStringAsFixed(0);
    _geofenceLatController.text = config.geofenceLat?.toStringAsFixed(6) ?? '';
    _geofenceLonController.text = config.geofenceLon?.toStringAsFixed(6) ?? '';

    safeSetState(() {
      _enabled = config.enabled;
      _webhookMode = config.webhookMode;
      _protocolFilter = config.protocolFilter;
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

  static const _iftttDisclosureKey = 'ifttt_disclosure_accepted';

  Future<void> _saveConfig() async {
    // Capture provider refs before awaits
    final l10n = context.l10n;
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

    // Show one-time disclosure before first IFTTT activation
    if (_enabled) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final accepted = prefs.getBool(_iftttDisclosureKey) ?? false;
      if (!accepted) {
        final confirmed = await AppBottomSheet.showConfirm(
          context: context,
          title: l10n.iftttConfigDataSharingTitle,
          message: l10n.iftttConfigDataSharingMsg,
          confirmLabel: l10n.iftttConfigIUnderstand,
        );
        if (confirmed != true || !mounted) return;
        await prefs.setBool(_iftttDisclosureKey, true);
      }
    }

    if (!mounted) return;

    // Require valid credentials when enabled
    if (_enabled) {
      if (_webhookMode == WebhookMode.ifttt &&
          _webhookKeyController.text.trim().isEmpty) {
        showErrorSnackBar(context, l10n.iftttConfigEnterKeyToEnable);
        return;
      }
      if (_webhookMode == WebhookMode.customUrl &&
          _customWebhookUrlController.text.trim().isEmpty) {
        showErrorSnackBar(context, l10n.webhookConfigEnterUrlToEnable);
        return;
      }
    }

    final config = IftttConfig(
      enabled: _enabled,
      webhookKey: _webhookKeyController.text.trim(),
      webhookMode: _webhookMode,
      customWebhookUrl: _customWebhookUrlController.text.trim(),
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
      protocolFilter: _protocolFilter,
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

      showSuccessSnackBar(context, l10n.iftttConfigSaved);
      Navigator.pop(context);
    } catch (e) {
      safeSetState(() => _isSaving = false);
      if (mounted) {
        showErrorSnackBar(context, l10n.iftttConfigSaveFailed);
      }
    }
  }

  Future<void> _testWebhook() async {
    final l10n = context.l10n;
    if (_webhookMode == WebhookMode.ifttt &&
        _webhookKeyController.text.trim().isEmpty) {
      showErrorSnackBar(context, l10n.iftttConfigEnterKeyFirst);
      return;
    }
    if (_webhookMode == WebhookMode.customUrl &&
        _customWebhookUrlController.text.trim().isEmpty) {
      showErrorSnackBar(context, l10n.webhookConfigEnterUrlFirst);
      return;
    }

    safeSetState(() => _isTesting = true);

    final iftttService = ref.read(iftttServiceProvider);
    final tempConfig = IftttConfig(
      enabled: true,
      webhookKey: _webhookKeyController.text.trim(),
      webhookMode: _webhookMode,
      customWebhookUrl: _customWebhookUrlController.text.trim(),
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
      protocolFilter: _protocolFilter,
    );
    await iftttService.saveConfig(tempConfig);

    final success = await iftttService.testWebhook();
    if (!mounted) return;

    safeSetState(() => _isTesting = false);

    if (success) {
      showSuccessSnackBar(context, l10n.iftttConfigTestSuccess);
    } else {
      showErrorSnackBar(context, l10n.iftttConfigTestFailed);
    }
  }

  @override
  void dispose() {
    _webhookKeyController.dispose();
    _customWebhookUrlController.dispose();
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
        title: context.l10n.iftttConfigTitle,
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
                  : Text(context.l10n.iftttConfigSave),
            )
          else
            TextButton.icon(
              onPressed: () => showPremiumInfoSheet(
                context: context,
                ref: ref,
                feature: PremiumFeature.iftttIntegration,
              ),
              icon: const Icon(
                Icons.lock,
                size: 14,
                color: SemanticColors.disabled,
              ),
              label: Text(
                context.l10n.iftttConfigSave,
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
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacing16,
                      8,
                      16,
                      8,
                    ),
                    child: PremiumExplanationCard(
                      feature: PremiumFeature.iftttIntegration,
                      title: context.l10n.iftttConfigPremiumTitle,
                      description: context.l10n.iftttConfigPremiumDesc,
                      exampleTitle: context.l10n.iftttConfigPremiumExampleTitle,
                      exampleDescription:
                          context.l10n.iftttConfigPremiumExampleDesc,
                      initiallyExpanded: true,
                    ),
                  ),
                _buildEnableTile(),
                // Only show form fields when premium AND enabled
                if (hasPremium && _enabled) ...[
                  const SizedBox(height: AppTheme.spacing16),
                  SettingsSectionHeader(
                    title: context.l10n.iftttConfigSectionWebhook,
                  ),
                  _buildWebhookSection(),
                  const SizedBox(height: AppTheme.spacing16),
                  SettingsSectionHeader(
                    title: context.l10n.iftttConfigSectionProtocolScope,
                  ),
                  _buildProtocolScopeSection(),
                  const SizedBox(height: AppTheme.spacing16),
                  SettingsSectionHeader(
                    title: context.l10n.iftttConfigSectionMessageTriggers,
                  ),
                  _buildMessageTriggers(),
                  const SizedBox(height: AppTheme.spacing16),
                  SettingsSectionHeader(
                    title: context.l10n.iftttConfigSectionNodeTriggers,
                  ),
                  _buildNodeTriggers(),
                  const SizedBox(height: AppTheme.spacing16),
                  SettingsSectionHeader(
                    title: context.l10n.iftttConfigSectionTelemetryTriggers,
                  ),
                  _buildTelemetryTriggers(),
                  const SizedBox(height: AppTheme.spacing16),
                  SettingsSectionHeader(
                    title: context.l10n.iftttConfigSectionGeofencing,
                  ),
                  _buildGeofenceSettings(),
                ],
                const SizedBox(height: AppTheme.spacing16),
                _buildInfoCard(),
                const SizedBox(height: AppTheme.spacing8),
                _buildEventNamesCard(),
                const SizedBox(height: AppTheme.spacing32),
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

    return SettingsTile(
      icon: Icons.webhook,
      iconColor: _enabled && hasPremium ? context.accentColor : null,
      title: context.l10n.iftttConfigEnable,
      subtitle: context.l10n.iftttConfigEnableSubtitle,
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
                  const SizedBox(width: AppTheme.spacing8),
                  ThemedSwitch(value: false, onChanged: null),
                ],
              ),
            ),
    );
  }

  Widget _buildWebhookSection() {
    return Column(
      children: [
        // Mode selector
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.all(AppTheme.spacing12),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _WebhookModeChip(
                  label: context.l10n.webhookModeIfttt,
                  icon: Icons.key,
                  selected: _webhookMode == WebhookMode.ifttt,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    safeSetState(() => _webhookMode = WebhookMode.ifttt);
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: _WebhookModeChip(
                  label: context.l10n.webhookModeCustomUrl,
                  icon: Icons.link,
                  selected: _webhookMode == WebhookMode.customUrl,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    safeSetState(() => _webhookMode = WebhookMode.customUrl);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        // Credential input
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_webhookMode == WebhookMode.ifttt)
                TextField(
                  maxLength: 64,
                  controller: _webhookKeyController,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: context.l10n.iftttConfigWebhookKeyLabel,
                    labelStyle: TextStyle(color: context.textSecondary),
                    hintText: context.l10n.iftttConfigWebhookKeyHint,
                    hintStyle: TextStyle(color: SemanticColors.muted),
                    helperText: context.l10n.iftttConfigWebhookKeyHelper,
                    helperStyle: TextStyle(color: context.textTertiary),
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
                    prefixIcon: Icon(Icons.key, color: context.textSecondary),
                    filled: true,
                    fillColor: context.background,
                    counterText: '',
                  ),
                )
              else
                TextField(
                  maxLength: 500,
                  controller: _customWebhookUrlController,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: context.l10n.webhookConfigCustomUrlLabel,
                    labelStyle: TextStyle(color: context.textSecondary),
                    hintText: context.l10n.webhookConfigCustomUrlHint,
                    hintStyle: TextStyle(color: SemanticColors.muted),
                    helperText: context.l10n.webhookConfigCustomUrlHelper,
                    helperStyle: TextStyle(color: context.textTertiary),
                    helperMaxLines: 2,
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
                    prefixIcon: Icon(Icons.link, color: context.textSecondary),
                    filled: true,
                    fillColor: context.background,
                    counterText: '',
                  ),
                ),
              SizedBox(height: AppTheme.spacing16),
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
                  label: Text(
                    _isTesting
                        ? context.l10n.iftttConfigTesting
                        : context.l10n.iftttConfigTestConnection,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProtocolScopeSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.iftttConfigProtocolScopeHelp,
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: AppTheme.spacing12),
          ChipSelector<TriggerProtocolFilter>(
            value: _protocolFilter,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              safeSetState(() => _protocolFilter = value);
            },
            options: [
              ChipOption(
                value: TriggerProtocolFilter.any,
                label: context.l10n.iftttConfigProtocolAny,
                icon: Icons.all_inclusive,
                color: AppTheme.primaryBlue,
              ),
              ChipOption(
                value: TriggerProtocolFilter.meshtastic,
                label: context.l10n.iftttConfigProtocolMeshtastic,
                icon: Icons.router,
                color: AccentColors.cyan,
              ),
              ChipOption(
                value: TriggerProtocolFilter.meshcore,
                label: context.l10n.iftttConfigProtocolMeshcore,
                icon: Icons.hub,
                color: AppTheme.primaryMagenta,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTriggers() {
    return Column(
      children: [
        SettingsTile(
          icon: Icons.message_outlined,
          title: context.l10n.iftttConfigMessageReceived,
          subtitle: context.l10n.iftttConfigMessageReceivedSubtitle,
          trailing: ThemedSwitch(
            value: _messageReceived,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              safeSetState(() => _messageReceived = value);
            },
          ),
        ),
        SettingsTile(
          icon: Icons.sos_outlined,
          title: context.l10n.iftttConfigSosEmergency,
          subtitle: context.l10n.iftttConfigSosEmergencySubtitle,
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
        SettingsTile(
          icon: Icons.wifi_tethering,
          title: context.l10n.iftttConfigNodeActive,
          subtitle: context.l10n.iftttConfigNodeActiveSubtitle,
          trailing: ThemedSwitch(
            value: _nodeOnline,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              safeSetState(() => _nodeOnline = value);
            },
          ),
        ),
        SettingsTile(
          icon: Icons.wifi_off_outlined,
          title: context.l10n.iftttConfigNodeInactive,
          subtitle: context.l10n.iftttConfigNodeInactiveSubtitle,
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
        SettingsTile(
          icon: Icons.battery_3_bar,
          title: context.l10n.iftttConfigBatteryLow,
          subtitle: context.l10n.iftttConfigBatteryLowSubtitle,
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
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                    const SizedBox(width: AppTheme.spacing12),
                    Text(
                      context.l10n.iftttConfigBatteryThreshold,
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
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
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
                const SizedBox(height: AppTheme.spacing8),
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
        SettingsTile(
          icon: Icons.device_thermostat,
          title: context.l10n.iftttConfigTemperatureAlert,
          subtitle: context.l10n.iftttConfigTemperatureAlertSubtitle,
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
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                    const SizedBox(width: AppTheme.spacing12),
                    Text(
                      context.l10n.iftttConfigTemperatureThreshold,
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
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
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
                const SizedBox(height: AppTheme.spacing8),
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
                      '30°C', // lint-allow: hardcoded-string
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                    Text(
                      '80°C', // lint-allow: hardcoded-string
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
        SettingsTile(
          icon: Icons.radar,
          title: context.l10n.iftttConfigPositionUpdates,
          subtitle: context.l10n.iftttConfigPositionUpdatesSubtitle,
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
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Column(
              children: [
                TextField(
                  maxLength: 10,
                  controller: _geofenceRadiusController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: context.l10n.iftttConfigGeofenceRadius,
                    labelStyle: TextStyle(color: context.textSecondary),
                    hintText: context.l10n.iftttConfigGeofenceRadiusHint,
                    hintStyle: TextStyle(color: SemanticColors.muted),
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
                    prefixIcon: Icon(Icons.radar, color: context.textSecondary),
                    suffixText: context.l10n.iftttConfigGeofenceUnitM,
                    suffixStyle: TextStyle(color: context.textSecondary),
                    filled: true,
                    fillColor: context.background,
                    counterText: '',
                  ),
                ),
                SizedBox(height: AppTheme.spacing16),
                TextField(
                  maxLength: 20,
                  controller: _geofenceLatController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: context.l10n.iftttConfigCenterLatitude,
                    labelStyle: TextStyle(color: context.textSecondary),
                    hintText: context.l10n.iftttConfigCenterLatHint,
                    hintStyle: TextStyle(color: SemanticColors.muted),
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
                      Icons.my_location,
                      color: context.textSecondary,
                    ),
                    filled: true,
                    fillColor: context.background,
                    counterText: '',
                  ),
                ),
                SizedBox(height: AppTheme.spacing16),
                TextField(
                  maxLength: 20,
                  controller: _geofenceLonController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: context.l10n.iftttConfigCenterLongitude,
                    labelStyle: TextStyle(color: context.textSecondary),
                    hintText: context.l10n.iftttConfigCenterLonHint,
                    hintStyle: TextStyle(color: SemanticColors.muted),
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
                      Icons.my_location,
                      color: context.textSecondary,
                    ),
                    filled: true,
                    fillColor: context.background,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: AppTheme.spacing16),
                // Mini map preview when coordinates are set
                Builder(
                  builder: (context) {
                    final lat = double.tryParse(_geofenceLatController.text);
                    final lon = double.tryParse(_geofenceLonController.text);
                    final radius =
                        double.tryParse(_geofenceRadiusController.text) ??
                        1000.0;
                    final point = safeLatLng(lat, lon);

                    if (point != null) {
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius8,
                            ),
                            child: SizedBox(
                              height: 150,
                              child: IgnorePointer(
                                child: MeshMapWidget(
                                  mapStyle: _mapStyle,
                                  initialCenter: point,
                                  initialZoom: _calculateZoomForRadius(radius),
                                  interactive: false,
                                  animateTiles: false,
                                  additionalLayers: [
                                    CircleLayer(
                                      circles: [
                                        CircleMarker(
                                          point: point,
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
                                          point: point,
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
                          SizedBox(height: AppTheme.spacing16),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                // Monitored node indicator
                if (_geofenceNodeNum != null && _geofenceNodeName != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing12),
                    decoration: BoxDecoration(
                      color: context.accentColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      border: Border.all(
                        color: context.accentColor.withAlpha(50),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.radar, color: context.accentColor, size: 20),
                        SizedBox(width: AppTheme.spacing12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.iftttConfigMonitoredNode,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textTertiary,
                                ),
                              ),
                              SizedBox(height: AppTheme.spacing2),
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
                  SizedBox(height: AppTheme.spacing16),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing12),
                    decoration: BoxDecoration(
                      color: AppTheme.warningYellow.withAlpha(20),
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
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
                        const SizedBox(width: AppTheme.spacing12),
                        Expanded(
                          child: Text(
                            context.l10n.iftttConfigNoNodeSelected,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing16),
                ],
                // Throttle setting
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: context.textSecondary,
                      size: 20,
                    ),
                    SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Text(
                        context.l10n.iftttConfigAlertCooldown,
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
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
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
                        items: [
                          DropdownMenuItem(
                            value: 5,
                            child: Text(context.l10n.iftttConfigCooldown5min),
                          ),
                          DropdownMenuItem(
                            value: 15,
                            child: Text(context.l10n.iftttConfigCooldown15min),
                          ),
                          DropdownMenuItem(
                            value: 30,
                            child: Text(context.l10n.iftttConfigCooldown30min),
                          ),
                          DropdownMenuItem(
                            value: 60,
                            child: Text(context.l10n.iftttConfigCooldown1hour),
                          ),
                          DropdownMenuItem(
                            value: 120,
                            child: Text(context.l10n.iftttConfigCooldown2hours),
                          ),
                          DropdownMenuItem(
                            value: 240,
                            child: Text(context.l10n.iftttConfigCooldown4hours),
                          ),
                          DropdownMenuItem(
                            value: 480,
                            child: Text(context.l10n.iftttConfigCooldown8hours),
                          ),
                          DropdownMenuItem(
                            value: 1440,
                            child: Text(
                              context.l10n.iftttConfigCooldown24hours,
                            ),
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
                SizedBox(height: AppTheme.spacing8),
                Text(
                  context.l10n.iftttConfigCooldownDesc,
                  style: context.bodySmallStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
                SizedBox(height: AppTheme.spacing16),
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
                    label: Text(context.l10n.iftttConfigPickOnMap),
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
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.accentColor.withAlpha(20),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.accentColor.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: context.accentColor, size: 20),
              SizedBox(width: AppTheme.spacing12),
              Text(
                context.l10n.iftttConfigSetupGuide,
                style: TextStyle(
                  color: context.accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildStep('1', context.l10n.iftttConfigStep1),
          _buildStep('2', context.l10n.iftttConfigStep2),
          _buildStep('3', context.l10n.iftttConfigStep3),
          _buildStep('4', context.l10n.iftttConfigStep4),
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
          SizedBox(width: AppTheme.spacing12),
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
        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
            context.l10n.iftttConfigEventNamesRef,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
            ),
          ),
          subtitle: Text(
            context.l10n.iftttConfigEventNamesSubtitle,
            style: context.bodySmallStyle?.copyWith(
              color: context.textTertiary,
            ),
          ),
          iconColor: context.textSecondary,
          collapsedIconColor: context.textSecondary,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 0, 16, 16),
              child: Column(
                children: [
                  _buildEventRow(
                    'meshtastic_message',
                    'sender, message, channel', // lint-allow: hardcoded-string
                  ),
                  _buildEventRow(
                    'meshtastic_node_online',
                    'name, nodeId, timestamp', // lint-allow: hardcoded-string
                  ),
                  _buildEventRow(
                    'meshtastic_node_offline',
                    'name, nodeId, timestamp', // lint-allow: hardcoded-string
                  ),
                  _buildEventRow(
                    'meshtastic_battery_low',
                    'name, level%, threshold%', // lint-allow: hardcoded-string
                  ),
                  _buildEventRow(
                    'meshtastic_temperature',
                    'name, temp°C, threshold°C', // lint-allow: hardcoded-string
                  ),
                  _buildEventRow(
                    'meshtastic_position',
                    'name, lat/lon, distance', // lint-allow: hardcoded-string
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
          SizedBox(width: AppTheme.spacing8),
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

class _WebhookModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _WebhookModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? context.accentColor.withAlpha(25)
              : context.background,
          borderRadius: BorderRadius.circular(AppTheme.radius10),
          border: Border.all(
            color: selected
                ? context.accentColor.withAlpha(100)
                : context.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? context.accentColor : context.textTertiary,
            ),
            const SizedBox(width: AppTheme.spacing8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? context.accentColor : context.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
