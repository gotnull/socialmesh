// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/config.pb.dart' as config_pb;
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../services/protocol/admin_target.dart';

/// Screen for configuring display settings
class DisplayConfigScreen extends ConsumerStatefulWidget {
  const DisplayConfigScreen({super.key});

  @override
  ConsumerState<DisplayConfigScreen> createState() =>
      _DisplayConfigScreenState();
}

class _DisplayConfigScreenState extends ConsumerState<DisplayConfigScreen>
    with LifecycleSafeMixin {
  bool _isLoading = false;
  int _screenOnSecs = 60;
  int _autoCarouselSecs = 0;
  bool _flipScreen = false;
  config_pbenum.Config_DisplayConfig_DisplayUnits? _units;
  config_pbenum.Config_DisplayConfig_DisplayMode? _displayMode;
  bool _headingBold = false;
  bool _wakeOnTapOrMotion = false;
  // New fields from iOS
  bool _use12hClock = false;
  bool _compassNorthTop = false;
  config_pbenum.Config_DisplayConfig_OledType? _oledType;
  config_pbenum.Config_DisplayConfig_CompassOrientation? _compassOrientation;
  bool _useLongNodeName = false;
  bool _enableMessageBubbles = false;
  StreamSubscription<config_pb.Config_DisplayConfig>? _configSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    super.dispose();
  }

  void _applyConfig(config_pb.Config_DisplayConfig config) {
    safeSetState(() {
      _screenOnSecs = (config.screenOnSecs > 0 ? config.screenOnSecs : 60)
          .clamp(0, 300);
      _autoCarouselSecs = config.autoScreenCarouselSecs.clamp(0, 60);
      _flipScreen = config.flipScreen;
      _units = config.units;
      _displayMode = config.displaymode;
      _headingBold = config.headingBold;
      _wakeOnTapOrMotion = config.wakeOnTapOrMotion;
      // New fields
      _use12hClock = config.use12hClock;
      _compassNorthTop = config.compassNorthTop;
      _oledType = config.oled;
      _compassOrientation = config.compassOrientation;
      _useLongNodeName = config.useLongNodeName;
      _enableMessageBubbles = config.enableMessageBubbles;
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
        final cached = protocol.currentDisplayConfig;
        if (cached != null) {
          _applyConfig(cached);
        }
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription = protocol.displayConfigStream.listen((config) {
          if (mounted) _applyConfig(config);
        });

        // Request fresh config from device
        await protocol.getConfig(
          admin_pbenum.AdminMessage_ConfigType.DISPLAY_CONFIG,
          target: target,
        );
      }
    } catch (e) {
      // Device disconnected between isConnected check and getConfig call
      // Catches both StateError (from protocol layer) and PlatformException
      // (from BLE layer) when device disconnects during the config request
      AppLogging.protocol('Display config load aborted: $e');
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    final l10n = context.l10n;
    safeSetState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );
      await protocol.setDisplayConfig(
        screenOnSecs: _screenOnSecs,
        autoScreenCarouselSecs: _autoCarouselSecs,
        flipScreen: _flipScreen,
        units: _units ?? config_pbenum.Config_DisplayConfig_DisplayUnits.METRIC,
        displayMode:
            _displayMode ??
            config_pbenum.Config_DisplayConfig_DisplayMode.DEFAULT,
        headingBold: _headingBold,
        wakeOnTapOrMotion: _wakeOnTapOrMotion,
        use12hClock: _use12hClock,
        oledType:
            _oledType ?? config_pbenum.Config_DisplayConfig_OledType.OLED_AUTO,
        compassOrientation:
            _compassOrientation ??
            config_pbenum.Config_DisplayConfig_CompassOrientation.DEGREES_0,
        compassNorthTop: _compassNorthTop,
        useLongNodeName: _useLongNodeName,
        enableMessageBubbles: _enableMessageBubbles,
        target: target,
      );

      if (mounted) {
        showSuccessSnackBar(context, l10n.displayConfigSaved);
        if (target.isLocal) {
          ref
              .read(countdownProvider.notifier)
              .startDeviceRebootCountdown(reason: 'display config saved');
        }
        safeNavigatorPop();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, l10n.displayConfigSaveFailed(e.toString()));
      }
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: context.l10n.displayConfigTitle,
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _saveConfig,
          child: Text(
            context.l10n.displayConfigSave,
            style: TextStyle(
              color: _isLoading ? SemanticColors.disabled : context.accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
      slivers: [
        if (_isLoading)
          const SliverFillRemaining(child: ScreenLoadingIndicator())
        else
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionHeader(title: context.l10n.displayConfigSectionScreen),
                const SizedBox(height: AppTheme.spacing8),
                _buildScreenSettings(),
                const SizedBox(height: AppTheme.spacing24),
                _SectionHeader(
                  title: context.l10n.displayConfigSectionTimeCompass,
                ),
                const SizedBox(height: AppTheme.spacing8),
                _buildTimeAndCompassSettings(),
                const SizedBox(height: AppTheme.spacing24),
                _SectionHeader(
                  title: context.l10n.displayConfigSectionOledType,
                ),
                const SizedBox(height: AppTheme.spacing8),
                _buildOledTypeSelector(),
                const SizedBox(height: AppTheme.spacing24),
                _SectionHeader(
                  title: context.l10n.displayConfigSectionUnitsFormat,
                ),
                const SizedBox(height: AppTheme.spacing8),
                _buildUnitsSettings(),
                const SizedBox(height: AppTheme.spacing24),
                _SectionHeader(
                  title: context.l10n.displayConfigSectionDisplayMode,
                ),
                const SizedBox(height: AppTheme.spacing8),
                _buildDisplayModeSelector(),
                const SizedBox(height: AppTheme.spacing32),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildScreenSettings() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.displayConfigScreenTimeoutLabel(
              _screenOnSecs == 0
                  ? context.l10n.displayConfigScreenTimeoutAlwaysOn
                  : context.l10n.displayConfigScreenTimeoutSeconds(
                      _screenOnSecs,
                    ),
            ),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: AppTheme.spacing4),
          Text(
            context.l10n.displayConfigScreenTimeoutDesc,
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          SliderTheme(
            data: SliderThemeData(
              inactiveTrackColor: SemanticColors.divider,
              thumbColor: context.accentColor,
              overlayColor: context.accentColor.withAlpha(30),
            ),
            child: Slider(
              value: _screenOnSecs.clamp(0, 300).toDouble(),
              min: 0,
              max: 300,
              divisions: 30,
              label: _screenOnSecs == 0
                  ? context.l10n.displayConfigScreenTimeoutAlwaysOn
                  : context.l10n.displayConfigScreenTimeoutSeconds(
                      _screenOnSecs,
                    ),
              onChanged: (value) {
                setState(() => _screenOnSecs = value.toInt());
              },
            ),
          ),
          Divider(color: context.border),
          SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.displayConfigAutoCarouselLabel(
              _autoCarouselSecs == 0
                  ? context.l10n.displayConfigAutoCarouselDisabled
                  : context.l10n.displayConfigScreenTimeoutSeconds(
                      _autoCarouselSecs,
                    ),
            ),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: AppTheme.spacing4),
          Text(
            context.l10n.displayConfigAutoCarouselDesc,
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          SliderTheme(
            data: SliderThemeData(
              inactiveTrackColor: SemanticColors.divider,
              thumbColor: context.accentColor,
              overlayColor: context.accentColor.withAlpha(30),
            ),
            child: Slider(
              value: _autoCarouselSecs.clamp(0, 60).toDouble(),
              min: 0,
              max: 60,
              divisions: 12,
              label: _autoCarouselSecs == 0
                  ? context.l10n.displayConfigAutoCarouselOff
                  : context.l10n.displayConfigScreenTimeoutSeconds(
                      _autoCarouselSecs,
                    ),
              onChanged: (value) {
                setState(() => _autoCarouselSecs = value.toInt());
              },
            ),
          ),
          Divider(color: context.border),
          const SizedBox(height: AppTheme.spacing8),
          _SettingsTile(
            icon: Icons.screen_rotation,
            title: context.l10n.displayConfigFlipScreen,
            subtitle: context.l10n.displayConfigFlipScreenSubtitle,
            trailing: ThemedSwitch(
              value: _flipScreen,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _flipScreen = value);
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          _SettingsTile(
            icon: Icons.touch_app,
            title: context.l10n.displayConfigWakeOnTap,
            subtitle: context.l10n.displayConfigWakeOnTapSubtitle,
            trailing: ThemedSwitch(
              value: _wakeOnTapOrMotion,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _wakeOnTapOrMotion = value);
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          _SettingsTile(
            icon: Icons.badge,
            title: context.l10n.displayConfigLongNodeNames,
            subtitle: context.l10n.displayConfigLongNodeNamesSubtitle,
            trailing: ThemedSwitch(
              value: _useLongNodeName,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _useLongNodeName = value);
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          _SettingsTile(
            icon: Icons.chat_bubble_outline,
            title: context.l10n.displayConfigMessageBubbles,
            subtitle: context.l10n.displayConfigMessageBubblesSubtitle,
            trailing: ThemedSwitch(
              value: _enableMessageBubbles,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _enableMessageBubbles = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeAndCompassSettings() {
    final compassOrientations = [
      (
        config_pbenum.Config_DisplayConfig_CompassOrientation.DEGREES_0,
        context.l10n.displayConfigDeg0,
      ),
      (
        config_pbenum.Config_DisplayConfig_CompassOrientation.DEGREES_90,
        context.l10n.displayConfigDeg90,
      ),
      (
        config_pbenum.Config_DisplayConfig_CompassOrientation.DEGREES_180,
        context.l10n.displayConfigDeg180,
      ),
      (
        config_pbenum.Config_DisplayConfig_CompassOrientation.DEGREES_270,
        context.l10n.displayConfigDeg270,
      ),
      (
        config_pbenum
            .Config_DisplayConfig_CompassOrientation
            .DEGREES_0_INVERTED,
        context.l10n.displayConfigDeg0Inv,
      ),
      (
        config_pbenum
            .Config_DisplayConfig_CompassOrientation
            .DEGREES_90_INVERTED,
        context.l10n.displayConfigDeg90Inv,
      ),
      (
        config_pbenum
            .Config_DisplayConfig_CompassOrientation
            .DEGREES_180_INVERTED,
        context.l10n.displayConfigDeg180Inv,
      ),
      (
        config_pbenum
            .Config_DisplayConfig_CompassOrientation
            .DEGREES_270_INVERTED,
        context.l10n.displayConfigDeg270Inv,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsTile(
            icon: Icons.access_time,
            title: context.l10n.displayConfig12hClock,
            subtitle: context.l10n.displayConfig12hClockSubtitle,
            trailing: ThemedSwitch(
              value: _use12hClock,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _use12hClock = value);
              },
            ),
          ),
          SizedBox(height: AppTheme.spacing16),
          _SettingsTile(
            icon: Icons.explore,
            title: context.l10n.displayConfigCompassNorth,
            subtitle: context.l10n.displayConfigCompassNorthSubtitle,
            trailing: ThemedSwitch(
              value: _compassNorthTop,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _compassNorthTop = value);
              },
            ),
          ),
          SizedBox(height: AppTheme.spacing16),
          Divider(color: context.border),
          SizedBox(height: AppTheme.spacing16),
          Text(
            context.l10n.displayConfigCompassOrientation,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            context.l10n.displayConfigCompassOrientationDesc,
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          SizedBox(height: AppTheme.spacing12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              border: Border.all(color: context.border),
            ),
            child:
                DropdownButton<
                  config_pbenum.Config_DisplayConfig_CompassOrientation
                >(
                  value:
                      _compassOrientation ??
                      config_pbenum
                          .Config_DisplayConfig_CompassOrientation
                          .DEGREES_0,
                  isExpanded: true,
                  underline: SizedBox(),
                  dropdownColor: context.card,
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                  items: compassOrientations.map((item) {
                    return DropdownMenuItem(
                      value: item.$1,
                      child: Text(item.$2),
                    );
                  }).toList(),
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    setState(() => _compassOrientation = value);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildOledTypeSelector() {
    final oledTypes = [
      (
        config_pbenum.Config_DisplayConfig_OledType.OLED_AUTO,
        context.l10n.displayConfigOledAuto,
        context.l10n.displayConfigOledAutoDesc,
      ),
      (
        config_pbenum.Config_DisplayConfig_OledType.OLED_SSD1306,
        'SSD1306',
        context.l10n.displayConfigOledSsd1306Desc,
      ),
      (
        config_pbenum.Config_DisplayConfig_OledType.OLED_SH1106,
        'SH1106',
        context.l10n.displayConfigOledSh1106Desc,
      ),
      (
        config_pbenum.Config_DisplayConfig_OledType.OLED_SH1107,
        'SH1107',
        context.l10n.displayConfigOledSh1107Desc,
      ),
      (
        config_pbenum.Config_DisplayConfig_OledType.OLED_SH1107_128_128,
        'SH1107 128x128', // lint-allow: hardcoded-string
        context.l10n.displayConfigOledSh1107_128Desc,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.displayConfigOledTypeTitle,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppTheme.spacing4),
          Text(
            context.l10n.displayConfigOledTypeDesc,
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: AppTheme.spacing16),
          ...oledTypes.map((item) {
            final isSelected =
                (_oledType ??
                    config_pbenum.Config_DisplayConfig_OledType.OLED_AUTO) ==
                item.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _oledType = item.$1);
                },
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacing12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    border: Border.all(
                      color: isSelected ? context.accentColor : context.border,
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected
                        ? context.accentColor.withAlpha(20)
                        : context.background,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? context.accentColor
                            : SemanticColors.disabled,
                      ),
                      SizedBox(width: AppTheme.spacing12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$2,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                            Text(
                              item.$3,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: context.accentColor),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUnitsSettings() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.displayConfigMeasurementUnits,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          _buildUnitOption(
            icon: Icons.straighten,
            title: context.l10n.displayConfigMetric,
            subtitle: context.l10n.displayConfigMetricDesc,
            isSelected:
                _units ==
                config_pbenum.Config_DisplayConfig_DisplayUnits.METRIC,
            onTap: () => setState(
              () => _units =
                  config_pbenum.Config_DisplayConfig_DisplayUnits.METRIC,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          _buildUnitOption(
            icon: Icons.square_foot,
            title: context.l10n.displayConfigImperial,
            subtitle: context.l10n.displayConfigImperialDesc,
            isSelected:
                _units ==
                config_pbenum.Config_DisplayConfig_DisplayUnits.IMPERIAL,
            onTap: () => setState(
              () => _units =
                  config_pbenum.Config_DisplayConfig_DisplayUnits.IMPERIAL,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Divider(color: context.border),
          const SizedBox(height: AppTheme.spacing8),
          _SettingsTile(
            icon: Icons.format_bold,
            title: context.l10n.displayConfigBoldHeadings,
            subtitle: context.l10n.displayConfigBoldHeadingsSubtitle,
            trailing: ThemedSwitch(
              value: _headingBold,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _headingBold = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(
            color: isSelected ? context.accentColor : context.border,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? context.accentColor.withAlpha(20)
              : context.background,
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? context.accentColor : SemanticColors.disabled,
            ),
            SizedBox(width: AppTheme.spacing12),
            Icon(
              icon,
              color: isSelected ? context.accentColor : context.textSecondary,
            ),
            SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayModeSelector() {
    final modes = [
      (
        config_pbenum.Config_DisplayConfig_DisplayMode.DEFAULT,
        context.l10n.displayConfigModeDefault,
        context.l10n.displayConfigModeDefaultDesc,
        Icons.smartphone,
      ),
      (
        config_pbenum.Config_DisplayConfig_DisplayMode.TWOCOLOR,
        context.l10n.displayConfigModeTwoColor,
        context.l10n.displayConfigModeTwoColorDesc,
        Icons.contrast,
      ),
      (
        config_pbenum.Config_DisplayConfig_DisplayMode.INVERTED,
        context.l10n.displayConfigModeInverted,
        context.l10n.displayConfigModeInvertedDesc,
        Icons.invert_colors,
      ),
      (
        config_pbenum.Config_DisplayConfig_DisplayMode.COLOR,
        context.l10n.displayConfigModeColor,
        context.l10n.displayConfigModeColorDesc,
        Icons.palette,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.displayConfigDisplayModeTitle,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppTheme.spacing4),
          Text(
            context.l10n.displayConfigDisplayModeDesc,
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: AppTheme.spacing16),
          ...modes.map((m) {
            final isSelected = _displayMode == m.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _displayMode = m.$1);
                },
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacing12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    border: Border.all(
                      color: isSelected ? context.accentColor : context.border,
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected
                        ? context.accentColor.withAlpha(20)
                        : context.background,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        m.$4,
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
                              m.$2,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                            Text(
                              m.$3,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: context.accentColor),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.textSecondary, size: 22),
        SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
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
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          color: context.textTertiary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
