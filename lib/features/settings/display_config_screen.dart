import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;

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
  pb.Config_DisplayConfig_DisplayUnits? _units;
  pb.Config_DisplayConfig_DisplayMode? _displayMode;
  bool _headingBold = false;
  bool _wakeOnTapOrMotion = false;
  StreamSubscription<pb.Config_DisplayConfig>? _configSubscription;

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

  void _applyConfig(pb.Config_DisplayConfig config) {
    setState(() {
      _screenOnSecs = config.screenOnSecs > 0 ? config.screenOnSecs : 60;
      _autoCarouselSecs = config.autoScreenCarouselSecs;
      _flipScreen = config.flipScreen;
      _units = config.units;
      _displayMode = config.displaymode;
      _headingBold = config.headingBold;
      _wakeOnTapOrMotion = config.wakeOnTapOrMotion;
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

      // Listen for config response
      _configSubscription = protocol.displayConfigStream.listen((config) {
        if (mounted) _applyConfig(config);
      });

      // Request fresh config from device
      await protocol.getConfig(pb.AdminMessage_ConfigType.DISPLAY_CONFIG);
    } finally {
      setState(() => _isLoading = false);
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
        units: _units ?? pb.Config_DisplayConfig_DisplayUnits.METRIC,
        displayMode:
            _displayMode ?? pb.Config_DisplayConfig_DisplayMode.DEFAULT,
        headingBold: _headingBold,
        wakeOnTapOrMotion: _wakeOnTapOrMotion,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Display configuration saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text('Display Configuration'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveConfig,
            child: Text(
              'Save',
              style: TextStyle(
                color: _isLoading ? Colors.grey : AppTheme.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(title: 'SCREEN'),
                const SizedBox(height: 8),
                _buildScreenSettings(),
                const SizedBox(height: 24),
                _SectionHeader(title: 'UNITS & FORMAT'),
                const SizedBox(height: 8),
                _buildUnitsSettings(),
                const SizedBox(height: 24),
                _SectionHeader(title: 'DISPLAY MODE'),
                const SizedBox(height: 8),
                _buildDisplayModeSelector(),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildScreenSettings() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Screen Timeout: ${_screenOnSecs == 0 ? 'Always On' : '${_screenOnSecs}s'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How long before screen turns off',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          SliderTheme(
            data: SliderThemeData(
              inactiveTrackColor: Colors.grey.shade700,
              thumbColor: AppTheme.primaryGreen,
              overlayColor: AppTheme.primaryGreen.withAlpha(30),
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
          Divider(color: AppTheme.darkBorder),
          const SizedBox(height: 8),
          Text(
            'Auto Carousel: ${_autoCarouselSecs == 0 ? 'Disabled' : '${_autoCarouselSecs}s'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Automatically cycle through screens',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          SliderTheme(
            data: SliderThemeData(
              inactiveTrackColor: Colors.grey.shade700,
              thumbColor: AppTheme.primaryGreen,
              overlayColor: AppTheme.primaryGreen.withAlpha(30),
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
          Divider(color: AppTheme.darkBorder),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.screen_rotation,
            title: 'Flip Screen',
            subtitle: 'Rotate display 180°',
            trailing: Switch.adaptive(
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
            trailing: Switch.adaptive(
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

  Widget _buildUnitsSettings() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Measurement Units',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildUnitOption(
            icon: Icons.straighten,
            title: 'Metric',
            subtitle: 'Kilometers, Celsius',
            isSelected: _units == pb.Config_DisplayConfig_DisplayUnits.METRIC,
            onTap: () => setState(
              () => _units = pb.Config_DisplayConfig_DisplayUnits.METRIC,
            ),
          ),
          const SizedBox(height: 8),
          _buildUnitOption(
            icon: Icons.square_foot,
            title: 'Imperial',
            subtitle: 'Miles, Fahrenheit',
            isSelected: _units == pb.Config_DisplayConfig_DisplayUnits.IMPERIAL,
            onTap: () => setState(
              () => _units = pb.Config_DisplayConfig_DisplayUnits.IMPERIAL,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: AppTheme.darkBorder),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.format_bold,
            title: 'Bold Headings',
            subtitle: 'Show compass headings in bold',
            trailing: Switch.adaptive(
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
            color: isSelected ? AppTheme.primaryGreen : AppTheme.darkBorder,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? AppTheme.primaryGreen.withAlpha(20)
              : AppTheme.darkBackground,
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? AppTheme.primaryGreen : Colors.grey,
            ),
            const SizedBox(width: 12),
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.primaryGreen
                  : AppTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
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
        pb.Config_DisplayConfig_DisplayMode.DEFAULT,
        'Default',
        'Standard display layout',
        Icons.smartphone,
      ),
      (
        pb.Config_DisplayConfig_DisplayMode.TWOCOLOR,
        'Two Color',
        'Optimized for two-color displays',
        Icons.contrast,
      ),
      (
        pb.Config_DisplayConfig_DisplayMode.INVERTED,
        'Inverted',
        'Dark background, light text',
        Icons.invert_colors,
      ),
      (
        pb.Config_DisplayConfig_DisplayMode.COLOR,
        'Color',
        'Full color display mode',
        Icons.palette,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Display Mode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose the display rendering mode',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : AppTheme.darkBorder,
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected
                        ? AppTheme.primaryGreen.withAlpha(20)
                        : AppTheme.darkBackground,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        m.$4,
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.$2,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                            Text(
                              m.$3,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: AppTheme.primaryGreen),
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
        Icon(icon, color: AppTheme.textSecondary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
          color: AppTheme.textTertiary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
