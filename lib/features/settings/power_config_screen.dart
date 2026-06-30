// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/widgets/animations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/settings_primitives.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/number_format.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/config.pb.dart' as config_pb;
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../services/protocol/admin_target.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/status_banner.dart';

class PowerConfigScreen extends ConsumerStatefulWidget {
  const PowerConfigScreen({super.key});

  @override
  ConsumerState<PowerConfigScreen> createState() => _PowerConfigScreenState();
}

class _PowerConfigScreenState extends ConsumerState<PowerConfigScreen>
    with LifecycleSafeMixin {
  // adcMultiplierOverride is an unbounded float. 0 means "use the firmware's
  // built-in default for the board"; any positive value is an explicit override
  // of the voltage-divider ratio. The field accepts any value > 0 so DIY nodes
  // with non-standard dividers are not blocked. 3.2 is a common ratio used to
  // seed the field when the override toggle is first switched on.
  static const double _adcMultiplierDefault = 3.2;

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  bool _isPowerSaving = false;
  int _waitBluetoothSecs = 60;
  int _sdsSecs = 3600; // 1 hour
  int _lsSecs = 300; // 5 minutes
  double _minWakeSecs = 10;
  // New settings matching iOS
  bool _shutdownOnPowerLoss = false;
  int _shutdownAfterSecs = 0;
  bool _adcOverride = false;
  double _adcMultiplier = 0.0;
  bool _adcMultiplierInvalid = false;

  // Stable controller/focus for ADC multiplier field to avoid
  // per-keystroke remount (matching radio_config_screen frequency pattern).
  late final TextEditingController _adcController;
  late final FocusNode _adcFocusNode;

  bool _saving = false;
  bool _loading = false;
  StreamSubscription<config_pb.Config_PowerConfig>? _configSubscription;

  @override
  void initState() {
    super.initState();
    _adcController = TextEditingController();
    _adcFocusNode = FocusNode();
    _adcFocusNode.addListener(_onAdcFocusChanged);
    _adcController.addListener(_onAdcTextChanged);
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _adcFocusNode.removeListener(_onAdcFocusChanged);
    _adcController.removeListener(_onAdcTextChanged);
    _adcFocusNode.dispose();
    _adcController.dispose();
    super.dispose();
  }

  // Live validation: keep _adcMultiplier in sync with the field and flip an
  // invalid flag when the typed value is not a positive number, so the user
  // sees why Save is blocked instead of silently writing a stale value to the
  // device. The localized error string is resolved at render time; this
  // listener runs synchronously during initState's async load chain, so it
  // must not touch InheritedWidget lookups.
  void _onAdcTextChanged() {
    final raw = _adcController.text;
    final bool invalid;
    double? committed;
    if (raw.isEmpty) {
      invalid = false;
    } else {
      final parsed = NumberFormatUtils.tryParseLocaleDouble(raw);
      final valid = parsed != null && parsed > 0;
      invalid = !valid;
      if (valid) committed = parsed;
    }
    if (invalid == _adcMultiplierInvalid && committed == null) return;
    setState(() {
      _adcMultiplierInvalid = invalid;
      if (committed != null) _adcMultiplier = committed;
    });
  }

  // Locale-aware parse so users on IT / DE / FR / RU / ES keyboards who type
  // a comma decimal separator (e.g. "2,5") see the canonical dot form on
  // commit. Only normalise when the current text parses to a valid in-range
  // value; if not, leave what the user typed alone so the inline error stays
  // anchored to the actual input.
  void _onAdcFocusChanged() {
    if (_adcFocusNode.hasFocus) return;
    if (!_adcMultiplierInvalid && _adcController.text.isNotEmpty) {
      final normalised = _adcMultiplier.toStringAsFixed(2);
      if (_adcController.text != normalised) {
        _adcController.text = normalised;
      }
    }
  }

  void _applyConfig(config_pb.Config_PowerConfig config) {
    safeSetState(() {
      _isPowerSaving = config.isPowerSaving;
      _waitBluetoothSecs =
          (config.waitBluetoothSecs > 0 ? config.waitBluetoothSecs : 60).clamp(
            0,
            300,
          );
      _sdsSecs = (config.sdsSecs > 0 ? config.sdsSecs : 3600).clamp(0, 86400);
      _lsSecs = (config.lsSecs > 0 ? config.lsSecs : 300).clamp(0, 3600);
      _minWakeSecs =
          (config.minWakeSecs > 0 ? config.minWakeSecs.toDouble() : 10.0).clamp(
            1.0,
            120.0,
          );
      // New settings — clamp to slider max (3600) and treat sentinel
      // 0xFFFFFFFF as disabled
      final rawShutdown = config.onBatteryShutdownAfterSecs;
      _shutdownAfterSecs = rawShutdown >= 0xFFFFFFFF
          ? 0
          : rawShutdown.clamp(0, 3600);
      _shutdownOnPowerLoss = _shutdownAfterSecs > 0;
      _adcMultiplier = config.adcMultiplierOverride;
      _adcOverride = _adcMultiplier > 0;
    });
    // Seed the ADC controller from device config,
    // but only when the field is not actively being edited.
    if (!_adcFocusNode.hasFocus) {
      _adcController.text = _adcMultiplier > 0
          ? _adcMultiplier.toStringAsFixed(2)
          : '';
    }
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
        final cached = protocol.currentPowerConfig;
        if (cached != null) {
          _applyConfig(cached);
        }
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription = protocol.powerConfigStream.listen((config) {
          if (mounted) _applyConfig(config);
        });

        // Request fresh config from device
        await protocol.getConfig(
          admin_pbenum.AdminMessage_ConfigType.POWER_CONFIG,
          target: target,
        );
      }
    } catch (e) {
      // Device may disconnect between isConnected check and getConfig call,
      // throwing StateError or PlatformException from the BLE layer
      AppLogging.protocol('Power config load aborted: $e');
    } finally {
      safeSetState(() => _loading = false);
    }
  }

  bool get _adcInvalid => _adcOverride && _adcMultiplierInvalid;

  Future<void> _saveConfig() async {
    // Block submit when override is ON but the typed value is out of range.
    // The inline error under the field already tells the user why; haptic
    // gives the missed-tap signal without firing a redundant snackbar.
    if (_adcInvalid) {
      HapticFeedback.heavyImpact();
      return;
    }

    final protocol = ref.read(protocolServiceProvider);
    final target = AdminTarget.fromNullable(
      ref.read(remoteAdminTargetProvider),
    );

    safeSetState(() => _saving = true);

    final l10n = context.l10n;
    try {
      await protocol.setPowerConfig(
        isPowerSaving: _isPowerSaving,
        waitBluetoothSecs: _waitBluetoothSecs,
        sdsSecs: _sdsSecs,
        lsSecs: _lsSecs,
        minWakeSecs: _minWakeSecs.toInt(),
        onBatteryShutdownAfterSecs: _shutdownOnPowerLoss
            ? _shutdownAfterSecs
            : 0,
        adcMultiplierOverride: _adcOverride ? _adcMultiplier : 0.0,
        target: target,
      );

      if (mounted) {
        showSuccessSnackBar(context, l10n.powerConfigSaved);
        if (target.isLocal) {
          ref
              .read(countdownProvider.notifier)
              .startDeviceRebootCountdown(reason: 'power config saved');
        }
        safeNavigatorPop();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, l10n.powerConfigSaveFailed(e.toString()));
      }
    } finally {
      safeSetState(() => _saving = false);
    }
  }

  String _formatDuration(int seconds, {required String disabledLabel}) {
    if (seconds == 0) return disabledLabel;
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).round()} min';
    if (seconds < 86400) return '${(seconds / 3600).toStringAsFixed(1)} hr';
    return '${(seconds / 86400).toStringAsFixed(1)} days';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold(
        title: context.l10n.powerConfigTitle,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: (_saving || _adcInvalid) ? null : _saveConfig,
              child: _saving
                  ? LoadingIndicator(size: 20)
                  : Text(
                      context.l10n.powerConfigSave,
                      style: TextStyle(
                        color: _adcInvalid
                            ? context.textTertiary
                            : context.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
        slivers: _loading
            ? [SliverFillRemaining(child: const ScreenLoadingIndicator())]
            : [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Power Section
                      SettingsSectionHeader(
                        title: context.l10n.powerConfigSectionPower,
                      ),
                      // Power saving mode toggle
                      SettingsTile(
                        icon: _isPowerSaving
                            ? Icons.battery_saver
                            : Icons.battery_full,
                        iconColor: _isPowerSaving ? context.accentColor : null,
                        title: context.l10n.powerConfigPowerSaving,
                        subtitle: context.l10n.powerConfigPowerSavingSubtitle,
                        trailing: ThemedSwitch(
                          value: _isPowerSaving,
                          onChanged: (value) {
                            HapticFeedback.selectionClick();
                            setState(() => _isPowerSaving = value);
                          },
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.power_settings_new,
                        iconColor: _shutdownOnPowerLoss
                            ? context.accentColor
                            : null,
                        title: context.l10n.powerConfigShutdownOnPowerLoss,
                        subtitle:
                            context.l10n.powerConfigShutdownOnPowerLossSubtitle,
                        trailing: ThemedSwitch(
                          value: _shutdownOnPowerLoss,
                          onChanged: (value) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _shutdownOnPowerLoss = value;
                              if (value && _shutdownAfterSecs == 0) {
                                _shutdownAfterSecs = 60; // Default to 1 minute
                              }
                            });
                          },
                        ),
                      ),
                      // Shutdown After Secs slider (only show when shutdown enabled)
                      if (_shutdownOnPowerLoss)
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          padding: const EdgeInsets.all(AppTheme.spacing16),
                          decoration: BoxDecoration(
                            color: context.card,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                          ),
                          child: _buildSliderSetting(
                            title: context.l10n.powerConfigShutdownDelay,
                            subtitle:
                                context.l10n.powerConfigShutdownDelaySubtitle,
                            value: _shutdownAfterSecs.toDouble(),
                            min: 10,
                            max: 3600,
                            divisions: 36,
                            formatValue: (v) => _formatDuration(
                              v.toInt(),
                              disabledLabel: context.l10n.powerConfigDisabled,
                            ),
                            onChanged: (value) => setState(
                              () => _shutdownAfterSecs = value.toInt(),
                            ),
                          ),
                        ),
                      SizedBox(height: AppTheme.spacing16),

                      // Battery Section (ADC Multiplier)
                      SettingsSectionHeader(
                        title: context.l10n.powerConfigSectionBattery,
                      ),
                      SettingsTile(
                        icon: Icons.battery_charging_full,
                        iconColor: _adcOverride ? context.accentColor : null,
                        title: context.l10n.powerConfigAdcMultiplierOverride,
                        subtitle: context
                            .l10n
                            .powerConfigAdcMultiplierOverrideSubtitle,
                        trailing: ThemedSwitch(
                          value: _adcOverride,
                          onChanged: (value) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _adcOverride = value;
                              if (value && _adcMultiplier == 0.0) {
                                _adcMultiplier = _adcMultiplierDefault;
                                _adcController.text = _adcMultiplier
                                    .toStringAsFixed(2);
                              }
                            });
                          },
                        ),
                      ),
                      // ADC Multiplier input (only show when override enabled)
                      if (_adcOverride)
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          padding: const EdgeInsets.all(AppTheme.spacing16),
                          decoration: BoxDecoration(
                            color: context.card,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    context.l10n.powerConfigAdcMultiplier,
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: TextFormField(
                                      controller: _adcController,
                                      focusNode: _adcFocusNode,
                                      onTapOutside: (_) => FocusManager
                                          .instance
                                          .primaryFocus
                                          ?.unfocus(),
                                      maxLength: 10,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      // Restrict to digits + decimal
                                      // separators (dot OR comma).
                                      // Locale-aware parse normalises
                                      // on commit.
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9.,]'),
                                        ),
                                      ],
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: context.textPrimary,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                        fillColor: context.background,
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radius8,
                                          ),
                                          borderSide: BorderSide(
                                            color: context.border,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radius8,
                                          ),
                                          borderSide: BorderSide(
                                            color: _adcMultiplierInvalid
                                                ? SemanticColors.error
                                                : context.border,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radius8,
                                          ),
                                          borderSide: BorderSide(
                                            color: _adcMultiplierInvalid
                                                ? SemanticColors.error
                                                : context.accentColor,
                                          ),
                                        ),
                                        counterText: '',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: AppTheme.spacing4),
                              Text(
                                _adcMultiplierInvalid
                                    ? context
                                          .l10n
                                          .powerConfigAdcMultiplierRangeError
                                    : context.l10n.powerConfigAdcMultiplierHint,
                                style: TextStyle(
                                  color: _adcMultiplierInvalid
                                      ? SemanticColors.error
                                      : context.textSecondary,
                                  fontSize: 12,
                                  fontWeight: _adcMultiplierInvalid
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: AppTheme.spacing16),

                      // Sleep Settings Section
                      SettingsSectionHeader(
                        title: context.l10n.powerConfigSectionSleep,
                      ),

                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                        ),
                        padding: const EdgeInsets.all(AppTheme.spacing16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Wait Bluetooth
                            _buildSliderSetting(
                              title: context.l10n.powerConfigWaitBluetooth,
                              subtitle:
                                  context.l10n.powerConfigWaitBluetoothSubtitle,
                              value: _waitBluetoothSecs.toDouble(),
                              min: 0,
                              max: 300,
                              divisions: 30,
                              formatValue: (v) => _formatDuration(
                                v.toInt(),
                                disabledLabel: context.l10n.powerConfigDisabled,
                              ),
                              onChanged: (value) => setState(
                                () => _waitBluetoothSecs = value.toInt(),
                              ),
                            ),
                            SizedBox(height: AppTheme.spacing20),
                            Divider(height: 1, color: context.border),
                            SizedBox(height: AppTheme.spacing20),

                            // Light Sleep
                            _buildSliderSetting(
                              title: context.l10n.powerConfigLightSleep,
                              subtitle:
                                  context.l10n.powerConfigLightSleepSubtitle,
                              value: _lsSecs.toDouble(),
                              min: 0,
                              max: 3600,
                              divisions: 36,
                              formatValue: (v) => _formatDuration(
                                v.toInt(),
                                disabledLabel: context.l10n.powerConfigDisabled,
                              ),
                              onChanged: (value) =>
                                  setState(() => _lsSecs = value.toInt()),
                            ),
                            const SizedBox(height: AppTheme.spacing20),
                            Divider(height: 1, color: context.border),
                            SizedBox(height: AppTheme.spacing20),

                            // Deep Sleep
                            _buildSliderSetting(
                              title: context.l10n.powerConfigDeepSleep,
                              subtitle:
                                  context.l10n.powerConfigDeepSleepSubtitle,
                              value: _sdsSecs.toDouble(),
                              min: 0,
                              max: 86400,
                              divisions: 24,
                              formatValue: (v) => _formatDuration(
                                v.toInt(),
                                disabledLabel: context.l10n.powerConfigDisabled,
                              ),
                              onChanged: (value) =>
                                  setState(() => _sdsSecs = value.toInt()),
                            ),
                            const SizedBox(height: AppTheme.spacing20),
                            Divider(height: 1, color: context.border),
                            SizedBox(height: AppTheme.spacing20),

                            // Min Wake
                            _buildSliderSetting(
                              title: context.l10n.powerConfigMinWakeTime,
                              subtitle:
                                  context.l10n.powerConfigMinWakeTimeSubtitle,
                              value: _minWakeSecs,
                              min: 1,
                              max: 120,
                              divisions: 119,
                              formatValue: (v) => '${v.toInt()}s',
                              onChanged: (value) =>
                                  setState(() => _minWakeSecs = value),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing16),

                      // Info card
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        child: StatusBanner.warning(
                          title: context.l10n.powerConfigWarning,
                          margin: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing32),
                    ]),
                  ),
                ),
              ],
      ),
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) formatValue,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radius6),
              ),
              child: Text(
                formatValue(value),
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
          subtitle,
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        SizedBox(height: AppTheme.spacing8),
        SliderTheme(
          data: SliderThemeData(
            inactiveTrackColor: context.border,
            thumbColor: context.accentColor,
            overlayColor: context.accentColor.withValues(alpha: 0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
