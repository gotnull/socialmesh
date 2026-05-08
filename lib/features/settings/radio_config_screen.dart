// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/meshtastic/modem_preset_metadata.dart';
import '../../core/meshtastic/region_metadata.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/settings_primitives.dart';
import '../../core/widgets/ico_help_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../services/protocol/admin_target.dart';
import '../../providers/help_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/number_format.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/config.pb.dart' as config_pb;
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/status_banner.dart';

/// Screen for configuring LoRa radio settings
class RadioConfigScreen extends ConsumerStatefulWidget {
  const RadioConfigScreen({super.key});

  @override
  ConsumerState<RadioConfigScreen> createState() => _RadioConfigScreenState();
}

class _RadioConfigScreenState extends ConsumerState<RadioConfigScreen>
    with LifecycleSafeMixin<RadioConfigScreen> {
  bool _isLoading = false;
  bool _isSaving = false;
  config_pbenum.Config_LoRaConfig_RegionCode? _selectedRegion;
  config_pbenum.Config_LoRaConfig_ModemPreset? _selectedModemPreset;
  int _hopLimit = 3;
  bool _txEnabled = true;
  int _txPower = 0;
  // Advanced settings
  bool _usePreset = true;
  int _channelNum = 0;
  int _bandwidth = 0;
  int _spreadFactor = 0;
  int _codingRate = 0;
  bool _rxBoostedGain = false;
  double _overrideFrequency = 0.0;
  bool _ignoreMqtt = false;
  bool _okToMqtt = false;
  StreamSubscription<config_pb.Config_LoRaConfig>? _configSubscription;

  // Stable controller/focus for frequency override field to avoid
  // per-keystroke remount (matching meshtastic-ios local draft pattern).
  late final TextEditingController _freqController;
  late final FocusNode _freqFocusNode;

  // Stable controller/focus for channel number field (same pattern).
  late final TextEditingController _channelNumController;
  late final FocusNode _channelNumFocusNode;

  @override
  void initState() {
    super.initState();
    _freqController = TextEditingController();
    _freqFocusNode = FocusNode();
    _freqFocusNode.addListener(_onFreqFocusChanged);
    _channelNumController = TextEditingController();
    _channelNumFocusNode = FocusNode();
    _channelNumFocusNode.addListener(_onChannelNumFocusChanged);
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _freqFocusNode.removeListener(_onFreqFocusChanged);
    _freqFocusNode.dispose();
    _freqController.dispose();
    _channelNumFocusNode.removeListener(_onChannelNumFocusChanged);
    _channelNumFocusNode.dispose();
    _channelNumController.dispose();
    super.dispose();
  }

  /// Commit the frequency override value when the field loses focus,
  /// matching meshtastic-ios behavior where formatting applies on commit.
  /// Locale-aware parse so users on IT / DE / FR / RU / ES keyboards
  /// who type a comma decimal separator (e.g. "869,075") are accepted.
  void _onFreqFocusChanged() {
    if (!_freqFocusNode.hasFocus) {
      final parsed = NumberFormatUtils.tryParseLocaleDouble(
        _freqController.text,
      );
      final value = parsed ?? 0.0;
      setState(() => _overrideFrequency = value);
      // Normalize the displayed text on commit (always dot-separated).
      _freqController.text = value > 0 ? value.toStringAsFixed(3) : '';
    }
  }

  /// Commit the channel number value when the field loses focus.
  void _onChannelNumFocusChanged() {
    if (!_channelNumFocusNode.hasFocus) {
      final text = _channelNumController.text.trim();
      final parsed = int.tryParse(text);
      final value = parsed ?? 0;
      setState(() => _channelNum = value);
      // Normalize the displayed text on commit
      _channelNumController.text = '$value';
    }
  }

  void _applyConfig(config_pb.Config_LoRaConfig config) {
    safeSetState(() {
      _selectedRegion = config.region;
      _selectedModemPreset = config.modemPreset;
      _hopLimit = config.hopLimit > 0 ? config.hopLimit : 3;
      _txEnabled = config.txEnabled;
      _txPower = config.txPower;
      // Advanced settings
      _usePreset = config.usePreset;
      _channelNum = config.channelNum;
      _bandwidth = config.bandwidth;
      _spreadFactor = config.spreadFactor;
      _codingRate = config.codingRate;
      _rxBoostedGain = config.sx126xRxBoostedGain;
      _overrideFrequency = config.overrideFrequency;
      _ignoreMqtt = config.ignoreMqtt;
      _okToMqtt = config.configOkToMqtt;
    });
    // Seed the frequency controller from device config,
    // but only when the field is not actively being edited.
    if (!_freqFocusNode.hasFocus) {
      _freqController.text = config.overrideFrequency > 0
          ? config.overrideFrequency.toStringAsFixed(3)
          : '';
    }
    // Seed the channel number controller from device config,
    // but only when the field is not actively being edited.
    if (!_channelNumFocusNode.hasFocus) {
      _channelNumController.text = '${config.channelNum}';
    }
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
        final cached = protocol.currentLoraConfig;
        if (cached != null) {
          _applyConfig(cached);
        }
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription = protocol.loraConfigStream.listen((config) {
          if (mounted) _applyConfig(config);
        });

        // Request fresh config from device (or remote node)
        await protocol.getConfig(
          admin_pbenum.AdminMessage_ConfigType.LORA_CONFIG,
          target: target,
        );
      }
    } catch (e) {
      // Device disconnected between isConnected check and getConfig call
      // Catches both StateError (from protocol layer) and PlatformException
      // (from BLE layer) when device disconnects during the config request
      AppLogging.protocol('Radio config load aborted: $e');
    } finally {
      if (mounted) safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    // Commit any in-progress frequency override text before saving,
    // in case the user taps Save while the field still has focus.
    // Locale-aware parse: accepts both "869.075" and "869,075".
    final freqParsed = NumberFormatUtils.tryParseLocaleDouble(
      _freqController.text,
    );
    _overrideFrequency = freqParsed ?? 0.0;

    // Commit any in-progress channel number text before saving.
    final channelNumText = _channelNumController.text.trim();
    final channelNumParsed = int.tryParse(channelNumText);
    _channelNum = channelNumParsed ?? 0;

    // Capture providers and UI dependencies before any await
    final protocol = ref.read(protocolServiceProvider);
    final target = AdminTarget.fromNullable(
      ref.read(remoteAdminTargetProvider),
    );
    final settingsFuture = ref.read(settingsServiceProvider.future);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;

    safeSetState(() => _isSaving = true);
    try {
      await protocol.setLoRaConfig(
        region:
            _selectedRegion ?? config_pbenum.Config_LoRaConfig_RegionCode.UNSET,
        modemPreset:
            _selectedModemPreset ??
            config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST,
        hopLimit: _hopLimit,
        txEnabled: _txEnabled,
        txPower: _txPower,
        usePreset: _usePreset,
        channelNum: _channelNum,
        bandwidth: _bandwidth,
        spreadFactor: _spreadFactor,
        codingRate: _codingRate,
        sx126xRxBoostedGain: _rxBoostedGain,
        overrideFrequency: _overrideFrequency,
        ignoreMqtt: _ignoreMqtt,
        configOkToMqtt: _okToMqtt,
        target: target,
      );

      // Mark region as configured if a valid region was set
      if (_selectedRegion != null &&
          _selectedRegion != config_pbenum.Config_LoRaConfig_RegionCode.UNSET) {
        final settings = await settingsFuture;
        await settings.setRegionConfigured(true);
      }

      if (!mounted) return;
      showSuccessSnackBar(context, l10n.radioConfigSaved);
      if (target.isLocal) {
        ref
            .read(countdownProvider.notifier)
            .startDeviceRebootCountdown(reason: 'radio config saved');
      }
      navigator.pop();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, l10n.radioConfigSaveFailed(e.toString()));
      }
    } finally {
      safeSetState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HelpTourController(
      topicId: 'radio_config_overview',
      stepKeys: const {},
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: GlassScaffold(
          title: context.l10n.radioConfigTitle,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => ref
                  .read(helpProvider.notifier)
                  .startTour('radio_config_overview'),
              tooltip: context.l10n.radioConfigHelp,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: (_isLoading || _isSaving) ? null : _saveConfig,
                child: _isSaving
                    ? LoadingIndicator(size: 20)
                    : Text(
                        context.l10n.radioConfigSave,
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
                    SettingsSectionHeader(
                      title: context.l10n.radioConfigSectionRegion,
                    ),
                    _buildRegionSelector(),
                    SizedBox(height: AppTheme.spacing16),
                    SettingsSectionHeader(
                      title: context.l10n.radioConfigSectionModemPreset,
                    ),
                    _buildModemPresetSelector(),
                    SizedBox(height: AppTheme.spacing16),
                    SettingsSectionHeader(
                      title: context.l10n.radioConfigSectionTransmission,
                    ),
                    SettingsTile(
                      icon: Icons.cell_tower,
                      iconColor: _txEnabled ? context.accentColor : null,
                      title: context.l10n.radioConfigTxEnabled,
                      subtitle: context.l10n.radioConfigTxEnabledSubtitle,
                      trailing: ThemedSwitch(
                        value: _txEnabled,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _txEnabled = value);
                        },
                      ),
                    ),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.l10n.radioConfigHopLimit,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: context.accentColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius6,
                                  ),
                                ),
                                child: Text(
                                  '$_hopLimit',
                                  style: TextStyle(
                                    color: context.accentColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: AppTheme.spacing4),
                          Text(
                            context.l10n.radioConfigHopLimitSubtitle,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: AppTheme.spacing8),
                          SliderTheme(
                            data: SliderThemeData(
                              inactiveTrackColor: context.border,
                              thumbColor: context.accentColor,
                              overlayColor: context.accentColor.withValues(
                                alpha: 0.2,
                              ),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: _hopLimit.toDouble(),
                              min: 0,
                              max: 7,
                              divisions: 7,
                              onChanged: (value) {
                                setState(() => _hopLimit = value.toInt());
                              },
                            ),
                          ),
                          Divider(height: 24, color: context.border),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.l10n.radioConfigTxPowerOverride,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: context.accentColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius6,
                                  ),
                                ),
                                child: Text(
                                  _txPower == 0
                                      ? context.l10n.radioConfigTxPowerDefault
                                      : '${_txPower}dBm',
                                  style: TextStyle(
                                    color: context.accentColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: AppTheme.spacing4),
                          Text(
                            context.l10n.radioConfigTxPowerSubtitle,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: AppTheme.spacing8),
                          SliderTheme(
                            data: SliderThemeData(
                              inactiveTrackColor: context.border,
                              thumbColor: context.accentColor,
                              overlayColor: context.accentColor.withValues(
                                alpha: 0.2,
                              ),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: _txPower.toDouble(),
                              min: 0,
                              max: 30,
                              divisions: 30,
                              onChanged: (value) {
                                setState(() => _txPower = value.toInt());
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    SettingsSectionHeader(
                      title: context.l10n.radioConfigSectionAdvanced,
                    ),
                    _buildAdvancedSettings(),
                    const SizedBox(height: AppTheme.spacing16),
                    _buildInfoCard(),
                    const SizedBox(height: AppTheme.spacing32),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettings() {
    final bandwidthOptions = [
      (0, 'Auto'),
      (31, '31.25 kHz'),
      (62, '62.5 kHz'),
      (125, '125 kHz'),
      (250, '250 kHz'),
      (500, '500 kHz'),
    ];

    final spreadFactorOptions = [
      (0, 'Auto'),
      (7, 'SF7'),
      (8, 'SF8'),
      (9, 'SF9'),
      (10, 'SF10'),
      (11, 'SF11'),
      (12, 'SF12'),
    ];

    final codingRateOptions = [
      (0, 'Auto'),
      (5, '4/5'),
      (6, '4/6'),
      (7, '4/7'),
      (8, '4/8'),
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
        children: [
          // Use Preset toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.radioConfigUsePreset,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing2),
                    Text(
                      context.l10n.radioConfigUsePresetSubtitle,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ThemedSwitch(
                value: _usePreset,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _usePreset = value);
                },
              ),
            ],
          ),

          // Custom modem settings (only when preset disabled)
          if (!_usePreset) ...[
            Divider(height: 24, color: context.border),
            // Bandwidth
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.radioConfigBandwidth,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: context.background,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    border: Border.all(color: context.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButton<int>(
                    underline: const SizedBox.shrink(),
                    dropdownColor: context.card,
                    style: TextStyle(color: context.textPrimary),
                    value: _bandwidth,
                    items: bandwidthOptions.map((b) {
                      return DropdownMenuItem(value: b.$1, child: Text(b.$2));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _bandwidth = value);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacing12),
            // Spread Factor
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.radioConfigSpreadFactor,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: context.background,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    border: Border.all(color: context.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButton<int>(
                    underline: const SizedBox.shrink(),
                    dropdownColor: context.card,
                    style: TextStyle(color: context.textPrimary),
                    value: _spreadFactor,
                    items: spreadFactorOptions.map((s) {
                      return DropdownMenuItem(value: s.$1, child: Text(s.$2));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _spreadFactor = value);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacing12),
            // Coding Rate
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.radioConfigCodingRate,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: context.background,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    border: Border.all(color: context.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButton<int>(
                    underline: const SizedBox.shrink(),
                    dropdownColor: context.card,
                    style: TextStyle(color: context.textPrimary),
                    value: _codingRate,
                    items: codingRateOptions.map((c) {
                      return DropdownMenuItem(value: c.$1, child: Text(c.$2));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _codingRate = value);
                    },
                  ),
                ),
              ],
            ),
          ],

          Divider(height: 24, color: context.border),

          // Frequency Slot
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.radioConfigFrequencySlot,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing2),
                    Text(
                      context.l10n.radioConfigFrequencySlotSubtitle,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                child: TextFormField(
                  maxLength: 10,
                  controller: _channelNumController,
                  focusNode: _channelNumFocusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    fillColor: context.background,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      borderSide: BorderSide(color: context.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      borderSide: BorderSide(color: context.border),
                    ),
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),
          if (_channelNum == 0) ...[
            const SizedBox(height: AppTheme.spacing8),
            StatusBanner.warning(
              title:
                  'Changing your primary channel name will change ' // lint-allow: hardcoded-string
                  'your LoRa operating frequency. If you move your ' // lint-allow: hardcoded-string
                  'primary off LongFast, you will not see standard ' // lint-allow: hardcoded-string
                  'LongFast traffic even if LongFast is set as a ' // lint-allow: hardcoded-string
                  'secondary channel with the correct PSK.', // lint-allow: hardcoded-string
              margin: EdgeInsets.zero,
            ),
          ],

          Divider(height: 24, color: context.border),

          // RX Boosted Gain
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.radioConfigRxBoostedGain,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing2),
                    Text(
                      context.l10n.radioConfigRxBoostedGainSubtitle,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ThemedSwitch(
                value: _rxBoostedGain,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _rxBoostedGain = value);
                },
              ),
            ],
          ),

          Divider(height: 24, color: context.border),

          // Frequency Override
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.radioConfigFrequencyOverride,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing2),
                    Text(
                      context.l10n.radioConfigFrequencyOverrideSubtitle,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                // 120 px holds `XXXX.XXX` (8 monospace chars + padding)
                // comfortably; 100 px clipped 7-char values like
                // "869.075" against the right edge.
                width: 120,
                child: TextFormField(
                  controller: _freqController,
                  focusNode: _freqFocusNode,
                  maxLength: 10,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  // Restrict to digits + a single decimal separator
                  // (dot OR comma — locale-aware parse normalises on
                  // commit).
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    fillColor: context.background,
                    filled: true,
                    hintText: '0.0', // lint-allow: hardcoded-string
                    hintStyle: TextStyle(color: context.textTertiary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      borderSide: BorderSide(color: context.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      borderSide: BorderSide(color: context.border),
                    ),
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),

          Divider(height: 24, color: context.border),

          // Ignore MQTT
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.radioConfigIgnoreMqtt,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing2),
                    Text(
                      context.l10n.radioConfigIgnoreMqttSubtitle,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ThemedSwitch(
                value: _ignoreMqtt,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _ignoreMqtt = value);
                },
              ),
            ],
          ),

          Divider(height: 24, color: context.border),

          // Ok to MQTT
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.radioConfigOkToMqtt,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing2),
                    Text(
                      context.l10n.radioConfigOkToMqttSubtitle,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ThemedSwitch(
                value: _okToMqtt,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _okToMqtt = value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegionSelector() {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.radioConfigRegionSelectHint,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          SizedBox(height: AppTheme.spacing16),
          Container(
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              border: Border.all(color: context.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButton<config_pbenum.Config_LoRaConfig_RegionCode>(
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: context.card,
              style: TextStyle(
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
              ),
              items: kRegionMetadata.map((r) {
                final label = r.radioConfigLabel(l);
                final suffix =
                    r.code == config_pbenum.Config_LoRaConfig_RegionCode.UNSET
                    ? r.regionSelectionDescription(l)
                    : r.frequency;
                return DropdownMenuItem(
                  value: r.code,
                  child: Text(
                    '$label ($suffix)', // lint-allow: hardcoded-string
                  ),
                );
              }).toList(),
              value:
                  _selectedRegion ??
                  config_pbenum.Config_LoRaConfig_RegionCode.UNSET,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedRegion = value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModemPresetSelector() {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.radioConfigPresetMustMatch,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          SizedBox(height: AppTheme.spacing16),
          ...kModemPresetMetadata.map((p) {
            final isSelected = _selectedModemPreset == p.preset;
            return InkWell(
              onTap: () => setState(() => _selectedModemPreset = p.preset),
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
                    SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.label(l),
                            style: TextStyle(
                              color: isSelected
                                  ? context.textPrimary
                                  : context.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            p.description(l),
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
          }),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: StatusBanner.warning(
        title: context.l10n.radioConfigRebootWarning,
        margin: EdgeInsets.zero,
      ),
    );
  }
}
