// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/settings_primitives.dart';

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
    final l10n = context.l10n;
    return GlassScaffold(
      title: l10n.displayConfigTitle,
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _saveConfig,
          child: Text(
            l10n.displayConfigSave,
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
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
            sliver: SliverList.list(
              children: [
                SettingsSectionHeader(title: l10n.displayConfigSectionScreen),
                _buildScreenTimingCard(),
                ..._buildScreenToggles(),
                const SizedBox(height: AppTheme.spacing16),
                SettingsSectionHeader(
                  title: l10n.displayConfigSectionTimeCompass,
                ),
                ..._buildTimeAndCompassSettings(),
                const SizedBox(height: AppTheme.spacing16),
                SettingsSectionHeader(title: l10n.displayConfigSectionOledType),
                _buildOledTypeSelector(),
                const SizedBox(height: AppTheme.spacing16),
                SettingsSectionHeader(
                  title: l10n.displayConfigSectionUnitsFormat,
                ),
                ..._buildUnitsSettings(),
                const SizedBox(height: AppTheme.spacing16),
                SettingsSectionHeader(
                  title: l10n.displayConfigSectionDisplayMode,
                ),
                _buildDisplayModeSelector(),
                const SizedBox(height: AppTheme.spacing32),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildScreenTimingCard() {
    final l10n = context.l10n;
    return FieldGroupCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.displayConfigScreenTimeoutLabel(
              _screenOnSecs == 0
                  ? l10n.displayConfigScreenTimeoutAlwaysOn
                  : l10n.displayConfigScreenTimeoutSeconds(_screenOnSecs),
            ),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.displayConfigScreenTimeoutDesc,
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
                  ? l10n.displayConfigScreenTimeoutAlwaysOn
                  : l10n.displayConfigScreenTimeoutSeconds(_screenOnSecs),
              onChanged: (value) {
                setState(() => _screenOnSecs = value.toInt());
              },
            ),
          ),
          Divider(color: context.border),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.displayConfigAutoCarouselLabel(
              _autoCarouselSecs == 0
                  ? l10n.displayConfigAutoCarouselDisabled
                  : l10n.displayConfigScreenTimeoutSeconds(_autoCarouselSecs),
            ),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.displayConfigAutoCarouselDesc,
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
                  ? l10n.displayConfigAutoCarouselOff
                  : l10n.displayConfigScreenTimeoutSeconds(_autoCarouselSecs),
              onChanged: (value) {
                setState(() => _autoCarouselSecs = value.toInt());
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildScreenToggles() {
    final l10n = context.l10n;
    return [
      _buildToggleTile(
        icon: Icons.screen_rotation,
        title: l10n.displayConfigFlipScreen,
        subtitle: l10n.displayConfigFlipScreenSubtitle,
        value: _flipScreen,
        onChanged: (value) => _flipScreen = value,
      ),
      _buildToggleTile(
        icon: Icons.touch_app,
        title: l10n.displayConfigWakeOnTap,
        subtitle: l10n.displayConfigWakeOnTapSubtitle,
        value: _wakeOnTapOrMotion,
        onChanged: (value) => _wakeOnTapOrMotion = value,
      ),
      _buildToggleTile(
        icon: Icons.badge,
        title: l10n.displayConfigLongNodeNames,
        subtitle: l10n.displayConfigLongNodeNamesSubtitle,
        value: _useLongNodeName,
        onChanged: (value) => _useLongNodeName = value,
      ),
      _buildToggleTile(
        icon: Icons.chat_bubble_outline,
        title: l10n.displayConfigMessageBubbles,
        subtitle: l10n.displayConfigMessageBubblesSubtitle,
        value: _enableMessageBubbles,
        onChanged: (value) => _enableMessageBubbles = value,
      ),
    ];
  }

  List<Widget> _buildTimeAndCompassSettings() {
    final l10n = context.l10n;
    final compassOrientations = [
      (
        config_pbenum.Config_DisplayConfig_CompassOrientation.DEGREES_0,
        l10n.displayConfigDeg0,
      ),
      (
        config_pbenum.Config_DisplayConfig_CompassOrientation.DEGREES_90,
        l10n.displayConfigDeg90,
      ),
      (
        config_pbenum.Config_DisplayConfig_CompassOrientation.DEGREES_180,
        l10n.displayConfigDeg180,
      ),
      (
        config_pbenum.Config_DisplayConfig_CompassOrientation.DEGREES_270,
        l10n.displayConfigDeg270,
      ),
      (
        config_pbenum
            .Config_DisplayConfig_CompassOrientation
            .DEGREES_0_INVERTED,
        l10n.displayConfigDeg0Inv,
      ),
      (
        config_pbenum
            .Config_DisplayConfig_CompassOrientation
            .DEGREES_90_INVERTED,
        l10n.displayConfigDeg90Inv,
      ),
      (
        config_pbenum
            .Config_DisplayConfig_CompassOrientation
            .DEGREES_180_INVERTED,
        l10n.displayConfigDeg180Inv,
      ),
      (
        config_pbenum
            .Config_DisplayConfig_CompassOrientation
            .DEGREES_270_INVERTED,
        l10n.displayConfigDeg270Inv,
      ),
    ];

    return [
      _buildToggleTile(
        icon: Icons.access_time,
        title: l10n.displayConfig12hClock,
        subtitle: l10n.displayConfig12hClockSubtitle,
        value: _use12hClock,
        onChanged: (value) => _use12hClock = value,
      ),
      _buildToggleTile(
        icon: Icons.explore,
        title: l10n.displayConfigCompassNorth,
        subtitle: l10n.displayConfigCompassNorthSubtitle,
        value: _compassNorthTop,
        onChanged: (value) => _compassNorthTop = value,
      ),
      FieldGroupCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.displayConfigCompassOrientation,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              l10n.displayConfigCompassOrientationDesc,
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: AppTheme.spacing12),
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
      ),
    ];
  }

  Widget _buildOledTypeSelector() {
    final l10n = context.l10n;
    return _buildOptionGroup<config_pbenum.Config_DisplayConfig_OledType>(
      title: l10n.displayConfigOledTypeTitle,
      description: l10n.displayConfigOledTypeDesc,
      selected:
          _oledType ?? config_pbenum.Config_DisplayConfig_OledType.OLED_AUTO,
      onSelected: (value) => _oledType = value,
      options: [
        (
          config_pbenum.Config_DisplayConfig_OledType.OLED_AUTO,
          l10n.displayConfigOledAuto,
          l10n.displayConfigOledAutoDesc,
          null,
        ),
        (
          config_pbenum.Config_DisplayConfig_OledType.OLED_SSD1306,
          'SSD1306',
          l10n.displayConfigOledSsd1306Desc,
          null,
        ),
        (
          config_pbenum.Config_DisplayConfig_OledType.OLED_SH1106,
          'SH1106',
          l10n.displayConfigOledSh1106Desc,
          null,
        ),
        (
          config_pbenum.Config_DisplayConfig_OledType.OLED_SH1107,
          'SH1107',
          l10n.displayConfigOledSh1107Desc,
          null,
        ),
        (
          config_pbenum.Config_DisplayConfig_OledType.OLED_SH1107_128_128,
          'SH1107 128x128', // lint-allow: hardcoded-string
          l10n.displayConfigOledSh1107_128Desc,
          null,
        ),
      ],
    );
  }

  List<Widget> _buildUnitsSettings() {
    final l10n = context.l10n;
    return [
      _buildOptionGroup<config_pbenum.Config_DisplayConfig_DisplayUnits>(
        title: l10n.displayConfigMeasurementUnits,
        selected:
            _units ?? config_pbenum.Config_DisplayConfig_DisplayUnits.METRIC,
        onSelected: (value) => _units = value,
        options: [
          (
            config_pbenum.Config_DisplayConfig_DisplayUnits.METRIC,
            l10n.displayConfigMetric,
            l10n.displayConfigMetricDesc,
            Icons.straighten,
          ),
          (
            config_pbenum.Config_DisplayConfig_DisplayUnits.IMPERIAL,
            l10n.displayConfigImperial,
            l10n.displayConfigImperialDesc,
            Icons.square_foot,
          ),
        ],
      ),
      _buildToggleTile(
        icon: Icons.format_bold,
        title: l10n.displayConfigBoldHeadings,
        subtitle: l10n.displayConfigBoldHeadingsSubtitle,
        value: _headingBold,
        onChanged: (value) => _headingBold = value,
      ),
    ];
  }

  Widget _buildDisplayModeSelector() {
    final l10n = context.l10n;
    return _buildOptionGroup<config_pbenum.Config_DisplayConfig_DisplayMode>(
      title: l10n.displayConfigDisplayModeTitle,
      description: l10n.displayConfigDisplayModeDesc,
      selected:
          _displayMode ??
          config_pbenum.Config_DisplayConfig_DisplayMode.DEFAULT,
      onSelected: (value) => _displayMode = value,
      options: [
        (
          config_pbenum.Config_DisplayConfig_DisplayMode.DEFAULT,
          l10n.displayConfigModeDefault,
          l10n.displayConfigModeDefaultDesc,
          Icons.smartphone,
        ),
        (
          config_pbenum.Config_DisplayConfig_DisplayMode.TWOCOLOR,
          l10n.displayConfigModeTwoColor,
          l10n.displayConfigModeTwoColorDesc,
          Icons.contrast,
        ),
        (
          config_pbenum.Config_DisplayConfig_DisplayMode.INVERTED,
          l10n.displayConfigModeInverted,
          l10n.displayConfigModeInvertedDesc,
          Icons.invert_colors,
        ),
        (
          config_pbenum.Config_DisplayConfig_DisplayMode.COLOR,
          l10n.displayConfigModeColor,
          l10n.displayConfigModeColorDesc,
          Icons.palette,
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      crossAxisAlignment: CrossAxisAlignment.start,
      trailing: ThemedSwitch(
        value: value,
        onChanged: (next) {
          HapticFeedback.selectionClick();
          setState(() => onChanged(next));
        },
      ),
    );
  }

  // One grouped card holding a single-select list: a title block, then one
  // row per option separated by dividers. Each option is
  // (value, title, subtitle, leading icon or null).
  Widget _buildOptionGroup<T>({
    required String title,
    String? description,
    required T selected,
    required ValueChanged<T> onSelected,
    required List<(T, String, String, IconData?)> options,
  }) {
    return FieldGroupCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      description,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            for (final option in options) ...[
              Divider(height: 1, color: context.border),
              _buildOptionRow(
                icon: option.$4,
                title: option.$2,
                subtitle: option.$3,
                isSelected: option.$1 == selected,
                onTap: () => setState(() => onSelected(option.$1)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow({
    required IconData? icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isSelected ? context.accentColor : context.textSecondary,
              ),
              const SizedBox(width: AppTheme.spacing12),
            ],
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
            const SizedBox(width: AppTheme.spacing12),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? context.accentColor : SemanticColors.disabled,
            ),
          ],
        ),
      ),
    );
  }
}
