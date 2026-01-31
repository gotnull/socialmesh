// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/config.pb.dart' as config_pb;
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;

/// Screen for configuring display settings
class DisplayConfigScreen extends ConsumerStatefulWidget {
  const DisplayConfigScreen({super.key});

  @override
  ConsumerState<DisplayConfigScreen> createState() =>
      _DisplayConfigScreenState();
}

class _DisplayConfigScreenState extends ConsumerState<DisplayConfigScreen> {
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
    setState(() {
      _screenOnSecs = config.screenOnSecs > 0 ? config.screenOnSecs : 60;
      _autoCarouselSecs = config.autoScreenCarouselSecs;
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
    });
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);

      // Apply cached config immediately if available
      final cached = protocol.currentDisplayConfig;
      if (cached != null) {
        _applyConfig(cached);
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
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
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
      );

      if (mounted) {
        showSuccessSnackBar(context, 'Display configuration saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Display Configuration',
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _saveConfig,
          child: Text(
            'Save',
            style: TextStyle(
              color: _isLoading ? Colors.grey : context.accentColor,
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
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionHeader(title: 'SCREEN'),
                const SizedBox(height: 8),
                _buildScreenSettings(),
                const SizedBox(height: 24),
                _SectionHeader(title: 'TIME & COMPASS'),
                const SizedBox(height: 8),
                _buildTimeAndCompassSettings(),
                const SizedBox(height: 24),
                _SectionHeader(title: 'OLED SCREEN TYPE'),
                const SizedBox(height: 8),
                _buildOledTypeSelector(),
                const SizedBox(height: 24),
                _SectionHeader(title: 'UNITS & FORMAT'),
                const SizedBox(height: 8),
                _buildUnitsSettings(),
                const SizedBox(height: 24),
                _SectionHeader(title: 'DISPLAY MODE'),
                const SizedBox(height: 8),
                _buildDisplayModeSelector(),
                const SizedBox(height: 32),
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
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Screen Timeout: ${_screenOnSecs == 0 ? 'Always On' : '${_screenOnSecs}s'}',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'How long before screen turns off',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          SliderTheme(
            data: SliderThemeData(
              inactiveTrackColor: Colors.grey.shade700,
              thumbColor: context.accentColor,
              overlayColor: context.accentColor.withAlpha(30),
            ),
            child: Slider(
              value: _screenOnSecs.toDouble(),
              min: 0,
              max: 300,
              divisions: 30,
              label: _screenOnSecs == 0 ? 'Always On' : '${_screenOnSecs}s',
              onChanged: (value) {
                setState(() => _screenOnSecs = value.toInt());
              },
            ),
          ),
          Divider(color: context.border),
          SizedBox(height: 8),
          Text(
            'Auto Carousel: ${_autoCarouselSecs == 0 ? 'Disabled' : '${_autoCarouselSecs}s'}',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Automatically cycle through screens',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          SliderTheme(
            data: SliderThemeData(
              inactiveTrackColor: Colors.grey.shade700,
              thumbColor: context.accentColor,
              overlayColor: context.accentColor.withAlpha(30),
            ),
            child: Slider(
              value: _autoCarouselSecs.toDouble(),
              min: 0,
              max: 60,
              divisions: 12,
              label: _autoCarouselSecs == 0 ? 'Off' : '${_autoCarouselSecs}s',
              onChanged: (value) {
                setState(() => _autoCarouselSecs = value.toInt());
              },
            ),
          ),
          Divider(color: context.border),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.screen_rotation,
            title: 'Flip Screen',
            subtitle: 'Rotate display 180°',
            trailing: ThemedSwitch(
              value: _flipScreen,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _flipScreen = value);
              },
            ),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.touch_app,
            title: 'Wake on Tap/Motion',
            subtitle: 'Turn on screen when device is moved',
            trailing: ThemedSwitch(
              value: _wakeOnTapOrMotion,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _wakeOnTapOrMotion = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeAndCompassSettings() {
    final compassOrientations = [
      (config_pbenum.Config_DisplayConfig_CompassOrientation.DEGREES_0, '0°'),
      (config_pbenum.Config_DisplayConfig_CompassOrientation.DEGREES_90, '90°'),
      (
        config_pbenum.Config_DisplayConfig_CompassOrientation.DEGREES_180,
        '180°',
      ),
      (
        config_pbenum.Config_DisplayConfig_CompassOrientation.DEGREES_270,
        '270°',
      ),
      (
        config_pbenum
            .Config_DisplayConfig_CompassOrientation
            .DEGREES_0_INVERTED,
        '0° Inverted',
      ),
      (
        config_pbenum
            .Config_DisplayConfig_CompassOrientation
            .DEGREES_90_INVERTED,
        '90° Inverted',
      ),
      (
        config_pbenum
            .Config_DisplayConfig_CompassOrientation
            .DEGREES_180_INVERTED,
        '180° Inverted',
      ),
      (
        config_pbenum
            .Config_DisplayConfig_CompassOrientation
            .DEGREES_270_INVERTED,
        '270° Inverted',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsTile(
            icon: Icons.access_time,
            title: '12 Hour Clock',
            subtitle: 'Display time in 12-hour format (AM/PM)',
            trailing: ThemedSwitch(
              value: _use12hClock,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _use12hClock = value);
              },
            ),
          ),
          SizedBox(height: 16),
          _SettingsTile(
            icon: Icons.explore,
            title: 'Compass Always Points North',
            subtitle:
                'The compass heading outside the circle always points north',
            trailing: ThemedSwitch(
              value: _compassNorthTop,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _compassNorthTop = value);
              },
            ),
          ),
          SizedBox(height: 16),
          Divider(color: context.border),
          SizedBox(height: 16),
          Text(
            'Compass Orientation',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Adjust compass display rotation',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(8),
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
        'Auto',
        'Automatically detect OLED type',
      ),
      (
        config_pbenum.Config_DisplayConfig_OledType.OLED_SSD1306,
        'SSD1306',
        'Common 128x64 OLED',
      ),
      (
        config_pbenum.Config_DisplayConfig_OledType.OLED_SH1106,
        'SH1106',
        '132x64 OLED controller',
      ),
      (
        config_pbenum.Config_DisplayConfig_OledType.OLED_SH1107,
        'SH1107',
        '64x128 vertical OLED',
      ),
      (
        config_pbenum.Config_DisplayConfig_OledType.OLED_SH1107_128_128,
        'SH1107 128x128',
        '128x128 square OLED',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OLED Type',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Override automatic OLED detection',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
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
                        color: isSelected ? context.accentColor : Colors.grey,
                      ),
                      SizedBox(width: 12),
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
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Measurement Units',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildUnitOption(
            icon: Icons.straighten,
            title: 'Metric',
            subtitle: 'Kilometers, Celsius',
            isSelected:
                _units ==
                config_pbenum.Config_DisplayConfig_DisplayUnits.METRIC,
            onTap: () => setState(
              () => _units =
                  config_pbenum.Config_DisplayConfig_DisplayUnits.METRIC,
            ),
          ),
          const SizedBox(height: 8),
          _buildUnitOption(
            icon: Icons.square_foot,
            title: 'Imperial',
            subtitle: 'Miles, Fahrenheit',
            isSelected:
                _units ==
                config_pbenum.Config_DisplayConfig_DisplayUnits.IMPERIAL,
            onTap: () => setState(
              () => _units =
                  config_pbenum.Config_DisplayConfig_DisplayUnits.IMPERIAL,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: context.border),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.format_bold,
            title: 'Bold Headings',
            subtitle: 'Show compass headings in bold',
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
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
              color: isSelected ? context.accentColor : Colors.grey,
            ),
            SizedBox(width: 12),
            Icon(
              icon,
              color: isSelected ? context.accentColor : context.textSecondary,
            ),
            SizedBox(width: 12),
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
        'Default',
        'Standard display layout',
        Icons.smartphone,
      ),
      (
        config_pbenum.Config_DisplayConfig_DisplayMode.TWOCOLOR,
        'Two Color',
        'Optimized for two-color displays',
        Icons.contrast,
      ),
      (
        config_pbenum.Config_DisplayConfig_DisplayMode.INVERTED,
        'Inverted',
        'Dark background, light text',
        Icons.invert_colors,
      ),
      (
        config_pbenum.Config_DisplayConfig_DisplayMode.COLOR,
        'Color',
        'Full color display mode',
        Icons.palette,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Display Mode',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Choose the display rendering mode',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
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
                      SizedBox(width: 12),
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
        SizedBox(width: 12),
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
