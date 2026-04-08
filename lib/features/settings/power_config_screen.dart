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
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../providers/splash_mesh_provider.dart';
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
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _adcFocusNode.removeListener(_onAdcFocusChanged);
    _adcFocusNode.dispose();
    _adcController.dispose();
    super.dispose();
  }

  /// Commit the ADC multiplier value when the field loses focus,
  /// matching the frequency override pattern in radio_config_screen.
  void _onAdcFocusChanged() {
    if (!_adcFocusNode.hasFocus) {
      final text = _adcController.text.trim();
      final parsed = double.tryParse(text);
      final value = (parsed != null && parsed >= 2.0 && parsed <= 6.0)
          ? parsed
          : _adcMultiplier;
      setState(() => _adcMultiplier = value);
      // Normalize the displayed text on commit
      _adcController.text = value.toStringAsFixed(2);
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

  Future<void> _saveConfig() async {
    // Commit any in-progress ADC multiplier text before saving,
    // in case the user taps Save while the field still has focus.
    final adcText = _adcController.text.trim();
    final adcParsed = double.tryParse(adcText);
    if (adcParsed != null && adcParsed >= 2.0 && adcParsed <= 6.0) {
      _adcMultiplier = adcParsed;
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
              onPressed: _saving ? null : _saveConfig,
              child: _saving
                  ? LoadingIndicator(size: 20)
                  : Text(
                      context.l10n.powerConfigSave,
                      style: TextStyle(
                        color: context.accentColor,
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
                      _SectionHeader(
                        title: context.l10n.powerConfigSectionPower,
                      ),
                      // Power saving mode toggle
                      _SettingsTile(
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
                      _SettingsTile(
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
                      _SectionHeader(
                        title: context.l10n.powerConfigSectionBattery,
                      ),
                      _SettingsTile(
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
                                _adcMultiplier = 3.2; // Default ratio
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
                                            color: context.border,
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
                                context.l10n.powerConfigAdcMultiplierHint,
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: AppTheme.spacing16),

                      // Sleep Settings Section
                      _SectionHeader(
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
